-- 2026-10-29: Codex denetimi sunucu düzeltmeleri (hata #3, #10; içerik #10).
--
-- Bu dosya UYGULANMADI; uygulama: supabase db query --linked -f \
--   supabase/2026-10-29_codex_denetim_duzeltmeleri.sql
-- Önce/sonra kanıtı: supabase/kanit/2026-10-29_codex_denetim_kanit.sql
-- (begin…rollback; canlıya kalıcı yazmaz).
--
-- 1) refund_room_entry_fee: İADE ANAHTARI HER KATILIMA ÖZEL.
--    Kusur (hata #3): giriş ücreti her katılımda `room_entry_fee` satırıyla
--    alınır ama iade anahtarı yalnız oda+oyuncu idi
--    (`room_entry_refund:room=<oda>:player=<oyuncu>`, benzersiz indeks).
--    Aynı ücretli lobiye gir→çık→tekrar gir→çık yapan oyuncu iki kez
--    ödeyip YALNIZ BİR kez iade alıyordu: ikinci iade ON CONFLICT DO NOTHING
--    ile sessizce atlanıyordu. Düzeltme: anahtara room_players.joined_at
--    eklenir (`...:at=<mikrosaniye>`); aynı katılımın tekrarı (yarış, tekrar
--    çağrı) aynı anahtarla çakışıp yine tek iade verir, yeni katılım yeni
--    anahtar alır. Eski anahtarla yazılmış iade (bu göçten önce) aynı
--    katılımdan SONRA yazıldıysa o katılım zaten iade edilmiş sayılır
--    (göç öncesi tekrar çağrıda çift iade olmasın).
--
-- 2) join_room_by_code: MEVCUT ÜYELİK BAKİYE KONTROLÜNDEN ÖNCE.
--    Kusur (hata #10): bakiye kontrolü üyelik kontrolünden önceydi. Son
--    jetonlarıyla katılan oyuncunun başarı yanıtı kaybolur da tekrar
--    denerse bakiyesi (artık 0) yetmediği için "Insufficient coins"
--    alıyor, zaten üye olduğu hâlde mevcut odayı alamıyordu. Düzeltme:
--    ayrılmış-satır reddi ve etkin-üye dönüşü bakiye kontrolünden önceye
--    alındı; bakiye yalnız YENİ katılıma uygulanır. Başka her şey
--    2026-10-22_odadan_cikarma.sql ile aynıdır (gövde oradan taşındı).
--
-- 3) Mitanni başkenti (hat_0094) emekli: hat_0084 ile aynı olgu (yerelde
--    retired_question_ids.dart 2026-10-29 bloğu). is_approved=false geri
--    alınabilir. Kimlik: uuid5(5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77,
--    'zankurd-local:hat_0094') = c593666a-a8fe-5f3d-a011-c038192c6237.
--
-- İdempotent: create or replace + koşullu update.

begin;

create or replace function public.refund_room_entry_fee(
  p_room_id uuid,
  p_player_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_fee integer;
  v_joined timestamptz;
  v_reason text;
  v_legacy text;
  v_inserted integer;
begin
  select coalesce(r.entry_fee, 0) into v_fee
  from public.rooms r
  where r.id = p_room_id;

  if not found or v_fee <= 0 then
    return 0;
  end if;

  -- Yalnız ücreti gerçekten ödemiş olan üye (ücret girişte düşer).
  select rp.joined_at into v_joined
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.player_id = p_player_id;

  if not found then
    return 0;
  end if;

  v_legacy := 'room_entry_refund:room=' || p_room_id::text
    || ':player=' || p_player_id::text;
  -- Her katılımın kendi anahtarı: aynı katılımın tekrarı çakışır, yeni
  -- katılım (gir→çık→gir) yeni anahtar alır.
  v_reason := v_legacy || ':at='
    || (extract(epoch from v_joined) * 1000000)::bigint::text;

  -- Göç öncesi eski anahtarla bu katılım için zaten iade verilmişse tekrar
  -- verilmez.
  if exists (
    select 1
    from public.coin_transactions ct
    where ct.player_id = p_player_id
      and ct.reason = v_legacy
      and ct.created_at >= v_joined
  ) then
    return 0;
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (p_player_id, v_fee, v_reason)
  on conflict (player_id, reason) where reason like 'room_entry_refund:%'
  do nothing;

  get diagnostics v_inserted = row_count;

  return case when v_inserted > 0 then v_fee else 0 end;
end;
$function$;

revoke all on function public.refund_room_entry_fee(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.refund_room_entry_fee(uuid, uuid)
  to service_role;

CREATE OR REPLACE FUNCTION public.join_room_by_code(p_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_existing_room_id uuid;
  v_player_count integer;
  v_user_coins integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  perform 1 from public.profiles where id = v_uid for update;

  select r.id into v_existing_room_id
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where rp.player_id = v_uid
    and rp.left_at is null
    and r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1;

  select
    r.id,
    r.code,
    r.host_id,
    r.question_count,
    coalesce(r.seconds_per_question, 20) as seconds_per_question,
    coalesce(r.entry_fee, 0) as entry_fee,
    r.is_custom,
    r.max_players,
    public.room_category_label(r.category_ids, c.name) as category_name
  into v_room
  from public.rooms r
  left join public.categories c on c.id = r.category_id
  where r.status = 'lobby'
    and (
      upper(r.code) = upper(btrim(p_code))
      or (
        regexp_replace(btrim(p_code), '[\s-]', '', 'g') ~ '^[0-9]{6}$'
        and r.code = regexp_replace(btrim(p_code), '[\s-]', '', 'g')
      )
    )
  order by r.created_at desc, r.id desc
  limit 1
  for update of r;

  if not found then
    raise exception 'Room not found or already started';
  end if;

  if v_existing_room_id is not null
     and v_existing_room_id <> v_room.id then
    raise exception 'Player is already in another live room';
  end if;

  -- 2026-10-29 (Codex denetimi): MEVCUT ÜYELİK bakiye kontrolünden ÖNCE.
  -- Son jetonlarıyla katılan oyuncunun başarı yanıtı kaybolur da tekrar
  -- denerse, bakiyesi artık yetmediği için "Insufficient coins" ile
  -- reddediliyordu; oysa zaten üyeydi ve ücreti ödemişti. Üyelik varsa
  -- ücret yeniden istenmez, mevcut oda döndürülür.
  -- Satır var ama left_at dolu: oyuncu ayrılmış. Canlıda left_at yalnız
  -- oyun BAŞLADIKTAN sonra yazılır (crowd_room_member_leave/mark_room_client_ready,
  -- lobide ayrılan satırı silinir) ve katılım yalnız 'lobby' odayı çözer;
  -- yani bu durum erişilemez. Yine de ayrılmış birine sessizce "başarılı"
  -- dönmek yerine normal hata verilir (giriş ücreti ayrılışta iade edilmediği
  -- için yeniden etkinleştirmek çift ücret riskidir).
  if exists (
    select 1
    from public.room_players rp
    where rp.room_id = v_room.id
      and rp.player_id = v_uid
      and rp.left_at is not null
  ) then
    raise exception 'Room not found or already started';
  end if;

  if exists (
    select 1
    from public.room_players rp
    where rp.room_id = v_room.id
      and rp.player_id = v_uid
      and rp.left_at is null
  ) then
    return json_build_object(
      'room_id', v_room.id,
      'code', v_room.code,
      'host_id', v_room.host_id,
      'question_count', v_room.question_count,
      'seconds_per_question', v_room.seconds_per_question,
      'entry_fee', v_room.entry_fee,
      'max_players', v_room.max_players,
      'is_custom', v_room.is_custom,
      'category_name', v_room.category_name
    );
  end if;

  -- Bakiye kontrolü kilit alındıktan sonra yapılır
  if v_room.entry_fee > 0 then
    select coalesce(sum(amount), 0)::integer
    into v_user_coins
    from public.coin_transactions
    where player_id = v_uid;

    if v_user_coins < v_room.entry_fee then
      raise exception 'Insufficient coins for room entry fee';
    end if;
  end if;

  -- Kapasite kontrolü: kalabalık odada aktif oyuncu sayısı

  -- Engelleme (2026-10-02 M5): oda sahibi ya da odadaki biriyle aramızda
  -- HER İKİ YÖNDE engel varsa katılım reddedilir. Mesaj bilerek mevcut
  -- "bulunamadı" mesajıdır: engelleyen kişinin odasını arayan bir kullanıcı
  -- engellendiğini öğrenmemeli; istemci bunu zaten `notFound`a eşler.
  if exists (
    select 1
    from public.blocked_users b
    where (b.blocker_id = v_uid
           and (b.blocked_id = v_room.host_id
                or exists (select 1 from public.room_players m
                           where m.room_id = v_room.id
                             and m.player_id = b.blocked_id)))
       or (b.blocked_id = v_uid
           and (b.blocker_id = v_room.host_id
                or exists (select 1 from public.room_players m
                           where m.room_id = v_room.id
                             and m.player_id = b.blocker_id)))
  ) then
    raise exception 'Room not found or already started';
  end if;

  -- Odadan çıkarılan (2026-10-22 kick_room_player) aynı odaya kodla geri
  -- giremez. Mesaj engeldeki gibi "bulunamadı": oda sahibi çıkarıldığını
  -- ikinci kez söylemez, istemci bunu zaten `notFound`a eşler.
  if exists (
    select 1 from public.room_kicks k
    where k.room_id = v_room.id
      and k.player_id = v_uid
  ) then
    raise exception 'Room not found or already started';
  end if;
  if v_room.is_custom and v_room.max_players > 2 then
    select count(*)::integer into v_player_count
    from public.room_players rp
    where rp.room_id = v_room.id
      and rp.left_at is null;

    if v_player_count >= v_room.max_players then
      raise exception 'Room is full';
    end if;
  else
    -- 2 kişilik oda kuralı
    select count(*)::integer into v_player_count
    from public.room_players rp
    where rp.room_id = v_room.id;

    if v_player_count >= 2 then
      raise exception 'Room is full';
    end if;
  end if;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room.id, v_uid, false);

  if v_room.entry_fee > 0 then
    insert into public.coin_transactions (player_id, amount, reason)
    values (v_uid, -v_room.entry_fee, 'room_entry_fee');
  end if;

  delete from public.matchmaking_queue mq
  where mq.player_id = v_uid
    and mq.room_id is null;

  return json_build_object(
    'room_id', v_room.id,
    'code', v_room.code,
    'host_id', v_room.host_id,
    'question_count', v_room.question_count,
    'seconds_per_question', v_room.seconds_per_question,
    'entry_fee', v_room.entry_fee,
    'max_players', v_room.max_players,
    'is_custom', v_room.is_custom,
    'category_name', v_room.category_name
  );
end;
$function$;

revoke all on function public.join_room_by_code(text) from public, anon;
grant execute on function public.join_room_by_code(text)
  to authenticated, service_role;

update public.questions
   set is_approved = false
 where id = 'c593666a-a8fe-5f3d-a011-c038192c6237'  -- hat_0094
   and is_approved;

-- Doğrulama: yetkiler yerinde mi?
do $$
begin
  if has_function_privilege('authenticated',
       'public.refund_room_entry_fee(uuid, uuid)', 'execute')
     or has_function_privilege('anon',
       'public.refund_room_entry_fee(uuid, uuid)', 'execute') then
    raise exception 'refund_room_entry_fee istemciye açık olmamalı';
  end if;
  if has_function_privilege('anon', 'public.join_room_by_code(text)', 'execute')
     or not has_function_privilege('authenticated',
       'public.join_room_by_code(text)', 'execute') then
    raise exception 'join_room_by_code yetkisi yanlış';
  end if;
end $$;

commit;
