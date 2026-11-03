-- 2026-11-04: MEYDAN OKUMA BAĞLANTISI SÜRESİ — 24 saat -> 7 gün.
--
-- Kusur: bağlantıyla paylaşılan meydan okuma (`create_async_duel_challenge`)
-- yeni satırı `async_duels.expires_at` varsayılanıyla (now()+24 saat,
-- 2026-10-24_duello_sirasi.sql) açıyordu. Rakip bağlantıyı bir gün sonra
-- açınca "süresi doldu" görüyordu; davet sessizce ölüyordu (hata yok,
-- `expire_async_duels` işi zaten doğru yapıyordu). Sıra süresi kısa kalmalı
-- (24 saat, rövanş/hükmen kuralları), ama DAVETİN ömrü uzun olmalı.
--
-- Değişen tek şey: INSERT'e açık `expires_at = now() + interval '7 days'`.
-- Gövde CANLI (✅) tanımdan, 2026-10-24_duello_inceleme_rovans.sql'den alındı.
-- Kabul (`accept_async_duel_challenge`) süreyi zaten now()+24 saat yapar —
-- kabulden sonra her oyuncunun sırası 24 saat sürer; hatırlatma
-- (`expire_async_duels`, bitmesine 4 saat kala) expires_at'e bağlıdır, 7 günlük
-- davette de bitmeden 4 saat önce çalışır. `start_async_duel` (rastgele
-- eşleşme) varsayılanı değişmez: 24 saat.
--
-- SIRA: 2026-11-01_room_duel_guards.sql'den ÖNCE uygulanır. O göç bu işlevi
-- `_guard_20261101_*` adıyla yedekleyip sarmalar; sonradan çalışırsa
-- sarmalayıcıyı ezip içerik gizlemeyi kaldırırdı. Aşağıdaki kapı bunu
-- durdurur (sarmalayıcı varsa göç hata verir).
--
-- İdempotent. Uygulama: `supabase db query --linked -f supabase/2026-11-04_meydan_okuma_suresi.sql`
-- Geri alma: supabase/geri_al/2026-11-04_meydan_okuma_suresi_geri.sql

begin;

do $gate$
begin
  if to_regprocedure('public._guard_20261101_create_async_duel_challenge(text,uuid)') is not null then
    raise exception 'room_duel_guards uygulanmis: bu goc sarmalayiciyi ezerdi; guard govdesini 7 gune guncelleyin';
  end if;
end
$gate$;

create or replace function public.create_async_duel_challenge(p_category text DEFAULT NULL::text, p_friend_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_category_input text;
  v_category_id uuid;
  v_open_count integer;
  v_question_ids uuid[];
  v_question_count integer;
  v_invited_name text := null;
  v_duel_id uuid;
  v_expires_at timestamptz;
  v_code text;
  v_attempt integer := 0;
  v_non_friend boolean := false;     -- 2026-10-24: son 7 günde birlikte oynadığımız arkadaş olmayan
  v_recent_invites integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  v_category_input := nullif(btrim(coalesce(p_category, '')), '');
  if v_category_input is not null then
    select c.id into v_category_id
    from public.categories c
    where upper(c.name) = upper(v_category_input)
      and c.is_active = true
    limit 1;

    if v_category_id is null then
      raise exception 'No questions';
    end if;
  end if;

  -- start_async_duel ile AYNI advisory kilit: ikisinin açık-düello sayımı
  -- aynı oyuncu için sıraya girer (çift dokunuş / iki RPC yarışı 5 sınırını
  -- aşamasın).
  perform pg_advisory_xact_lock(hashtextextended('async-duel:' || v_uid::text, 0));

  -- Davet edilecek kişi (KİLİTTEN SONRA denetlenir: kilit beklenirken konan
  -- engel ya da kalkan arkadaşlık güncel okunur): KABUL EDİLMİŞ arkadaş (friends tablosunda iki
  -- satır tutulur, benim satırım yeter) ve iki yönde de engelsiz. Engel,
  -- 2026-10-02_blocking_enforcement.sql ile aynı ilkeyle ifşa edilmez:
  -- engelli de arkadaş değil gibi 'Not a friend' alır.
  if p_friend_id is not null then
    -- Engel (iki yön) HER ZAMAN 'Not a friend' (ifşa edilmez).
    if p_friend_id = v_uid
       or exists (
         select 1 from public.blocked_users b
         where (b.blocker_id = v_uid and b.blocked_id = p_friend_id)
            or (b.blocker_id = p_friend_id and b.blocked_id = v_uid)
       ) then
      raise exception 'Not a friend';
    end if;

    -- 2026-10-24 rövanş istisnası: arkadaş değilse bile, son 7 günde ikimiz
    -- birlikte BİTMİŞ (completed / expired, hükmen dahil) bir düello
    -- oynadıysak davet geçer. Aksi 'Not a friend'. Günlük sınır kilitten
    -- sonra denetlenir (aşağıda).
    if not exists (
         select 1 from public.friends f
         where f.user_id = v_uid and f.friend_id = p_friend_id
       ) then
      if not public.async_duel_recent_pair(v_uid, p_friend_id) then
        raise exception 'Not a friend';
      end if;
      v_non_friend := true;
    end if;

    select p.display_name into v_invited_name
    from public.profiles p
    where p.id = p_friend_id;
    -- Profili olmayan (silinmiş) hesaba davet olmaz.
    if not found then
      raise exception 'Not a friend';
    end if;
  end if;

  -- Sahte "geçmiş düello" ile spam olmasın: arkadaş olmayan aynı kişiye
  -- son 24 saatte en çok 3 davet (arkadaşlar için yeni sınır YOK).
  if v_non_friend then
    select count(*) into v_recent_invites
    from public.async_duels d
    where d.creator_id = v_uid
      and d.invited_id = p_friend_id
      and d.created_at > now() - interval '24 hours';
    if v_recent_invites >= 3 then
      raise exception 'Too many invites';
    end if;
  end if;


  -- Süresi dolmuş ama henüz süpürülmemiş düellolar sayılmaz (2026-10-15).
  select count(*) into v_open_count
  from public.async_duels
  where creator_id = v_uid
    and status = 'open'
    and expires_at > now();

  if v_open_count >= 5 then
    raise exception 'Too many open duels';
  end if;

  -- Soru seçimi start_async_duel'inkiyle BİREBİR aynı süzgeç (gerekçe orada:
  -- 2026-09-28_async_duels.sql). `rnd` bir kez hesaplanır; sıra =
  -- array_agg sırası = istemcideki index 0..6.
  select public.weighted_question_pick(
    (select array_agg(cand.id) from (
    select q.id
    from public.questions q
    join public.categories c on c.id = q.category_id
    where q.is_approved = true
      and c.is_active = true
      and (v_category_id is null or q.category_id = v_category_id)
      and btrim(coalesce(q.prompt, '')) <> ''
      and btrim(coalesce(q.option_a, '')) not in ('', '-')
      and btrim(coalesce(q.option_b, '')) not in ('', '-')
      and (
        (
          coalesce(q.question_type, 'multiple_choice') = 'multiple_choice'
          and btrim(coalesce(q.option_c, '')) not in ('', '-')
          and btrim(coalesce(q.option_d, '')) not in ('', '-')
          and q.correct_option in ('A', 'B', 'C', 'D')
        )
        or (
          q.question_type = 'true_false'
          and btrim(coalesce(q.option_c, '')) in ('', '-')
          and btrim(coalesce(q.option_d, '')) in ('', '-')
          and q.correct_option in ('A', 'B')
        )
      )
    ) cand),
    '{}'::uuid[],
    7
  ) into v_question_ids;

  v_question_count := coalesce(array_length(v_question_ids, 1), 0);
  if v_question_count < 7 then
    raise exception 'No questions';
  end if;

  -- Kod çakışması (UNIQUE) 31^8'de pratikte yok; yine de birkaç kez dener.
  loop
    v_attempt := v_attempt + 1;
    v_code := public.generate_async_duel_challenge_code();
    begin
      insert into public.async_duels (
        category_id, question_ids, creator_id, invited_id, challenge_code, status,
        expires_at   -- 2026-11-04: tek fark; davet 7 gün açık kalır
      ) values (
        v_category_id, v_question_ids, v_uid, p_friend_id, v_code, 'open',
        now() + interval '7 days'
      )
      returning id, expires_at into v_duel_id, v_expires_at;
      exit;
    exception
      when unique_violation then
        if v_attempt >= 8 then
          raise;
        end if;
    end;
  end loop;

  return jsonb_build_object(
    'duel_id', v_duel_id,
    'role', 'creator',
    'opponent_name', null,
    'expires_at', v_expires_at,
    'questions', public.async_duel_questions_payload(v_question_ids),
    'challenge_code', v_code,
    'invited_name', v_invited_name,
    'invited_id', case when v_invited_name is not null then p_friend_id
                       else null end
  );
end;
$function$
;

revoke all on function public.create_async_duel_challenge(text, uuid)
  from public, anon;
grant execute on function public.create_async_duel_challenge(text, uuid)
  to authenticated;

commit;
