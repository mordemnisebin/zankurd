-- 2026-10-24 sunucu sertleştirme (güvenlik/dayanıklılık denetimi, altı bulgu).
--
-- S1  leave_room: son soru açıklandıktan sonra 1v1'de çıkış 'forfeit' değil
--     'completed' biter (kalabalık odadaki crowd_room_member_leave koruması).
--     Kusur: kaybeden son açıklamadan sonra çıkıp kazananın XP/jeton/lig
--     puanını silebiliyordu (forfeit odaları award_room_xp, lig ve ödül
--     talebinde sayılmaz).
-- S2  cleanup_stale_rooms + cron: hayalet oda oyuncuyu 24 saat kilitliyordu
--     (join_matchmaking mevcut canlı odayı döndürür, join_room_by_code
--     'already in another live room' der). Lobi 30 dk etkinliksiz (kuruluş,
--     katılım, sohbet, davet) -> kapanır; aktif oda 10 dk etkinliksiz ->
--     'stale_timeout', AMA son soru açıklanmışsa 'completed' (kazanç
--     kaybolmasın). İş her 5 dk çalışır (eskiden saatte bir).
-- S3  push_outbox: gönderen sütunu (from_user_id) eklendi; claim_push_outbox
--     alıcı gönderen sonradan engellemişse ya da satır eskiyse (oda daveti
--     30 dk, öteki 24 sa) göndermeden kapatır. Async düello tetikleyicisine
--     DOKUNULMADI (from_user_id null kalır; engel denetimi tetikleyicide).
-- S4  sync_mission_completion: anahtar 14 görev şablonuna karşı beyaz liste,
--     ödül sunucudaki sabit eşlemeden (istemci değerleri yok sayılır, imza
--     korunur), kullanıcı başına günde en çok 3 satır; bilinmeyen anahtar
--     sessizce başarı döner, yazılmaz.
-- Yetki/yol: claim_push_outbox ve cleanup_stale_rooms açıkça public/anon/
--     authenticated'dan alındı; değişen SECURITY DEFINER gövdeleri
--     `search_path = public, pg_temp` kullanır.
-- S5  log_analytics_event: kullanıcı başına saatte 600 olay sınırı.
-- S6  finalize_weekly_league: 2026-10-16_son_bosluklar.sql tanımı
--     `ended_reason = 'completed'` süzgecini kaybetmişti (terk edilmiş
--     maçlar lig skoruna giriyordu); canlı gövde süzgeci taşıyor, bu göç
--     dosya geçmişini canlıyla eşitler. Yetki geri alma satırı korunur.
--
-- Gövdeler CANLI tanımlardan (pg_get_functiondef, 2026-10-24) kopyalandı,
-- yalnız yukarıdaki değişikliklerle. Kanıt betiği:
-- supabase/kanit/2026-10-24_sunucu_sertlestirme_kanit.sql (begin...rollback,
-- ÖNCE ve SONRA çalıştırılır).
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-24_sunucu_sertlestirme.sql

begin;


-- S1 --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.leave_room(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_final_revealed boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select r.* into v_room
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where r.id = p_room_id
    and rp.player_id = v_uid
  for update of r;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  -- Tekrarlanan çıkış terminal maçın tarihsel üyeliğini değiştirmez.
  if v_room.status not in ('lobby', 'active') then
    return json_build_object(
      'status', v_room.status,
      'reason', coalesce(v_room.ended_reason, 'already_finished'),
      'forfeited_by', v_room.forfeited_by
    );
  end if;

  -- Kalabalık oda (is_custom ve max_players > 2): ayrılma mantığı ortak
  -- yardımcıda (lobide host devri, oyunda left_at, aktif < 2 ise erken bitiş).
  -- Aşağıdaki eski 2 kişilik yol DEĞİŞMEDEN kalır (yalnız iade çağrıları eklendi).
  if v_room.is_custom and v_room.max_players > 2 then
    return public.crowd_room_member_leave(p_room_id, v_uid);
  end if;

  update public.room_players rp
  set is_ready = false
  where rp.room_id = p_room_id
    and rp.player_id = v_uid;

  if v_room.status = 'active' then
    -- Son soru açıklandıktan sonra (bütün sorular bitti) çıkış maçı
    -- terketme sayılmaz: skorlar kesinleşti, kazanan 'completed' odanın XP,
    -- jeton ve lig puanını alır. crowd_room_member_leave ile aynı koruma;
    -- kaybeden son anda çıkıp kazananın ödülünü engelleyemez. İade YOK
    -- (havuz ödül talebiyle dağıtılır; ayrılan havuza katılmaz).
    select count(*) = v_room.question_count
           and bool_and(rq.revealed_at is not null)
    into v_final_revealed
    from public.room_questions rq
    where rq.room_id = p_room_id;
    v_final_revealed := coalesce(v_final_revealed, false);

    if v_final_revealed then
      update public.rooms r
      set
        status = 'finished',
        current_question_index = r.question_count,
        finished_at = coalesce(r.finished_at, now()),
        ended_reason = 'completed',
        forfeited_by = null
      where r.id = p_room_id;

      delete from public.matchmaking_queue mq
      where mq.room_id = p_room_id;

      return json_build_object(
        'status', 'finished',
        'reason', 'completed',
        'forfeited_by', null
      );
    end if;

    update public.rooms
    set
      status = 'finished',
      finished_at = coalesce(finished_at, now()),
      ended_reason = 'forfeit',
      forfeited_by = v_uid
    where id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    -- Ayrılan kaybeder; haksız yere oyunsuz kalan rakibin giriş ücreti iade.
    perform public.refund_room_entry_fees(p_room_id, v_uid);

    return json_build_object(
      'status', 'finished',
      'reason', 'forfeit',
      'forfeited_by', v_uid
    );
  end if;

  if v_room.status = 'lobby' and v_room.host_id = v_uid then
    update public.rooms
    set
      status = 'finished',
      finished_at = coalesce(finished_at, now()),
      ended_reason = 'host_left',
      forfeited_by = null
    where id = p_room_id;

    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    perform public.refund_room_entry_fees(p_room_id, null);

    return json_build_object(
      'status', 'finished',
      'reason', 'host_left',
      'forfeited_by', null
    );
  end if;

  if v_room.status = 'lobby' then
    -- Lobiden çıkan misafir kendi giriş ücretini geri alır (satır silinmeden önce).
    perform public.refund_room_entry_fee(p_room_id, v_uid);

    delete from public.room_players rp
    where rp.room_id = p_room_id
      and rp.player_id = v_uid;
    return json_build_object(
      'status', 'left',
      'reason', 'guest_left',
      'forfeited_by', null
    );
  end if;

  return json_build_object(
    'status', v_room.status,
    'reason', coalesce(v_room.ended_reason, 'already_finished'),
    'forfeited_by', v_room.forfeited_by
  );
end;
$function$;

-- S2 --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cleanup_stale_rooms()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_room record;
  v_on_time_ready_count integer;
  v_not_ready_player_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));

  for v_room in
    select
      r.id,
      r.status,
      r.client_ready_deadline,
      (r.is_custom and r.max_players > 2) as is_crowd,
      -- Bütün sorular açıklanmış ama oda finished yapılmamış mı (son
      -- soru sonrası kapanış çağrısı kaybolmuş / oyuncu çıkmış)?
      coalesce((
        select count(*) = r.question_count
               and bool_and(rq.revealed_at is not null)
        from public.room_questions rq
        where rq.room_id = r.id
      ), false) as final_revealed,
      (
        r.status = 'active'
        and r.client_ready_deadline is not null
        and clock_timestamp() >= r.client_ready_deadline
        and exists (
          select 1
          from public.room_questions rq
          where rq.room_id = r.id
            and rq.question_index = coalesce(r.current_question_index, 0)
            and rq.started_at is null
        )
        and (
          select count(*)
          from public.room_players rp
          where rp.room_id = r.id
            and rp.quiz_ready_at is not null
            and rp.quiz_ready_at <= r.client_ready_deadline
            and (not (r.is_custom and r.max_players > 2) or rp.left_at is null)
        ) < 2
      ) as ready_deadline_expired
    from public.rooms r
    where (
      -- Lobi: 30 dk hiçbir etkinlik yoksa kapanır (eskiden 24 saat: hayalet
      -- oda oyuncuyu bir gün kilitliyordu). Etkinlik = kuruluş, son katılım,
      -- son sohbet mesajı, son davet. Davet atmak/sohbet süreyi yeniler;
      -- misafirin ayrılması room_players satırını sildiğinden joined_at
      -- kaybolur, bu yüzden eşik 30 dk ve tek başına joined_at'e bağlı değil.
      -- (rooms'ta updated_at benzeri sütun yok: canlı katalogdan doğrulandı.)
      r.status = 'lobby'
      and greatest(
        r.created_at,
        (select max(rp.joined_at) from public.room_players rp
         where rp.room_id = r.id),
        (select max(m.created_at) from public.room_messages m
         where m.room_id = r.id),
        (select max(i.created_at) from public.room_invites i
         where i.room_id = r.id)
      ) < now() - interval '30 minutes'
    ) or (
      r.status = 'active'
      and (
        -- Aktif oda: başlangıçtan, soru başlatma/açıklama ya da cevap
        -- etkinliğinden bu yana 10 dk geçtiyse bayat (soru süresi 30 sn;
        -- 10 dk hiçbir şey olmayan oda terk edilmiştir).
        greatest(
          coalesce(r.started_at, r.created_at),
          (select max(rq.started_at) from public.room_questions rq
           where rq.room_id = r.id),
          (select max(rq.revealed_at) from public.room_questions rq
           where rq.room_id = r.id),
          (select max(pa.created_at) from public.player_answers pa
           where pa.room_id = r.id)
        ) < now() - interval '10 minutes'
        or (
          r.client_ready_deadline is not null
          and clock_timestamp() >= r.client_ready_deadline
          and exists (
            select 1
            from public.room_questions rq
            where rq.room_id = r.id
              and rq.question_index = coalesce(r.current_question_index, 0)
              and rq.started_at is null
          )
          and (
            select count(*)
            from public.room_players rp
            where rp.room_id = r.id
              and rp.quiz_ready_at is not null
              and rp.quiz_ready_at <= r.client_ready_deadline
              and (not (r.is_custom and r.max_players > 2) or rp.left_at is null)
          ) < 2
        )
      )
    )
    order by r.id
    for update of r skip locked
  loop
    v_not_ready_player_id := null;

    if v_room.ready_deadline_expired then
      select count(*)::integer
      into v_on_time_ready_count
      from public.room_players rp
      where rp.room_id = v_room.id
        and rp.quiz_ready_at is not null
        and rp.quiz_ready_at <= v_room.client_ready_deadline
        and (not v_room.is_crowd or rp.left_at is null);

      -- Kalabalık odada suçlu tek kişi yoktur: forfeited_by null kalır.
      if v_on_time_ready_count = 1 and not v_room.is_crowd then
        select rp.player_id into v_not_ready_player_id
        from public.room_players rp
        where rp.room_id = v_room.id
          and (
            rp.quiz_ready_at is null
            or rp.quiz_ready_at > v_room.client_ready_deadline
          )
        order by rp.player_id
        limit 1;
      end if;

      update public.rooms r
      set
        status = 'finished',
        finished_at = coalesce(r.finished_at, clock_timestamp()),
        ended_reason = 'opponent_not_ready',
        forfeited_by = v_not_ready_player_id
      where r.id = v_room.id;

      -- Oyun hiç başlamadı: herkese giriş ücreti iadesi (hazır süresinde
      -- düşenler dahil).
      perform public.refund_room_entry_fees(v_room.id, null, true);
    elsif v_room.status = 'active' and v_room.final_revealed then
      -- Son soru açıklanmış: oyun bitmiş sayılır, kazanç kaybolmasın.
      -- 'stale_timeout' award_room_xp / lig / ödül talebini kapatırdı.
      -- İade YOK (havuz ödül talebiyle dağıtılır).
      update public.rooms r
      set
        status = 'finished',
        current_question_index = r.question_count,
        finished_at = coalesce(r.finished_at, clock_timestamp()),
        ended_reason = 'completed',
        forfeited_by = null
      where r.id = v_room.id;
    else
      update public.rooms r
      set
        status = 'finished',
        finished_at = coalesce(r.finished_at, clock_timestamp()),
        ended_reason = 'stale_timeout',
        forfeited_by = null
      where r.id = v_room.id;

      -- Bayat oda: ücret ne ödül ne iade oluyordu. Aktif kalan herkese iade
      -- (oyundan kendi ayrılanlar kaybeder).
      perform public.refund_room_entry_fees(v_room.id, null);
    end if;
  end loop;

  delete from public.matchmaking_queue mq
  where (
    mq.room_id is null
    and mq.joined_at < now() - interval '10 minutes'
  ) or exists (
    select 1
    from public.rooms terminal_room
    where terminal_room.id = mq.room_id
      and terminal_room.status not in ('lobby', 'active')
  );
end;
$function$;

-- Zamanlayıcı: saatlik iş yerine her 5 dakikada (idempotent: aynı isimli iş
-- varsa kaldırılır, yeniden kurulur).
select cron.unschedule('cleanup-stale-rooms')
where exists (select 1 from cron.job where jobname = 'cleanup-stale-rooms');

select cron.schedule(
  'cleanup-stale-rooms',
  '*/5 * * * *',
  $$select public.cleanup_stale_rooms()$$
);

-- S3 --------------------------------------------------------------------
alter table public.push_outbox add column if not exists from_user_id uuid;

comment on column public.push_outbox.from_user_id is
  'Bildirimi tetikleyen kullanıcı (engel denetimi için). Async düello davetinde null.';

CREATE OR REPLACE FUNCTION public.claim_push_outbox(p_limit integer DEFAULT 20)
 RETURNS TABLE(job_id uuid, to_user_id uuid, kind text, title text, body text, fcm_token text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  -- 1) Yalnız YAŞ ya da ENGEL yüzünden anlamsızlaşan satırlar GÖNDERİLMEDEN
  --    kapatılır (claimed_at yazılır, çağırana dönmez). Oda daveti 30 dk,
  --    öteki türler (kind null dahil) 24 saat sonra anlamsızdır; alıcı ile
  --    gönderen arasında (iki yönde) engel varsa bildirim sızmasın.
  --    from_user_id null ise (düello daveti) engel denetimi tetikleyicide
  --    yapılır. Tek çağrıda en çok 500 satır.
  update public.push_outbox o
  set claimed_at = now()
  where o.id in (
    select d.id
    from public.push_outbox d
    where d.claimed_at is null
      and (
        d.created_at < now() - case
          when coalesce(d.kind, '') = 'room_invite' then interval '30 minutes'
          else interval '24 hours'
        end
        or (
          d.from_user_id is not null
          and exists (
            select 1 from public.blocked_users b
            where (b.blocker_id = d.to_user_id and b.blocked_id = d.from_user_id)
               or (b.blocker_id = d.from_user_id and b.blocked_id = d.to_user_id)
          )
        )
      )
    order by d.created_at
    limit 500
    for update skip locked
  );

  -- 2) Gönderilecek seçim: yaş/engel koşulları burada da tekrarlanır
  --    (adım 1 sınırlı ya da kilitli satırı atlamış olabilir) ve YALNIZ
  --    profili + fcm_token'ı olanlar işaretlenir. Profili/token'ı olmayanın
  --    bildirimi yanmaz; token gelince gider, yoksa yaştan düşer.
  return query
  with picked as (
    select o.id
    from public.push_outbox o
    join public.profiles pr on pr.id = o.to_user_id
    where o.claimed_at is null
      and nullif(pr.fcm_token, '') is not null
      and o.created_at >= now() - case
        when coalesce(o.kind, '') = 'room_invite' then interval '30 minutes'
        else interval '24 hours'
      end
      and not (
        o.from_user_id is not null
        and exists (
          select 1 from public.blocked_users b
          where (b.blocker_id = o.to_user_id and b.blocked_id = o.from_user_id)
             or (b.blocker_id = o.from_user_id and b.blocked_id = o.to_user_id)
        )
      )
    order by o.created_at
    limit greatest(1, least(coalesce(p_limit, 20), 100))
    for update of o skip locked
  ),
  marked as (
    update public.push_outbox o
    set claimed_at = now()
    from picked
    where o.id = picked.id
    returning o.id, o.to_user_id, o.kind, o.title, o.body
  )
  select
    marked.id,
    marked.to_user_id,
    marked.kind,
    marked.title,
    marked.body,
    p.fcm_token
  from marked
  join public.profiles p on p.id = marked.to_user_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.enqueue_friend_request_push()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_name text := coalesce(nullif(trim(new.from_user_name), ''), 'ZanKurd');
begin
  insert into public.push_outbox (to_user_id, kind, title, body, from_user_id)
  values (
    new.to_user_id,
    'friend_request',
    'ZanKurd',
    v_name || ' ji te re daxwaza hevaltiyê şand · '
      || v_name || ' sana arkadaşlık isteği gönderdi',
    new.from_user_id
  );
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.enqueue_friend_accept_push()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_name text;
begin
  select coalesce(nullif(trim(p.display_name), ''), 'ZanKurd')
  into v_name
  from public.profiles p
  where p.id = new.to_user_id;

  insert into public.push_outbox (to_user_id, kind, title, body, from_user_id)
  values (
    new.from_user_id,
    'friend_accept',
    'ZanKurd',
    coalesce(v_name, 'ZanKurd') || ' daxwaza hevaltiya te qebûl kir · '
      || coalesce(v_name, 'ZanKurd') || ' arkadaşlık isteğini kabul etti',
    new.to_user_id
  );
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.invite_friends_to_room(p_room_id uuid, p_friend_ids uuid[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_ids uuid[];
  v_friend uuid;
  v_count integer := 0;
  v_active integer;
  v_cap integer;
  v_recent integer;
  v_name text;
  v_prev timestamptz;
  v_push boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_room_id is null or p_friend_ids is null
     or coalesce(array_length(p_friend_ids, 1), 0) = 0 then
    return 0;
  end if;

  -- Yinelenenleri ve null'ları at; çağrı başına en çok 20 kişi.
  select coalesce(array_agg(distinct x), '{}') into v_ids
  from unnest(p_friend_ids) as x
  where x is not null and x <> v_uid;
  if coalesce(array_length(v_ids, 1), 0) > 20 then
    raise exception 'Too many invitees';
  end if;

  select r.id, r.status, r.is_custom, r.max_players, r.host_id into v_room
  from public.rooms r
  where r.id = p_room_id
  for share;

  -- Odayı kuran ya da odada AKTİF olan her oyuncu davet edebilir; lobi
  -- dışında (başladı/bitti) davet anlamsız.
  if not found
     or v_room.status <> 'lobby'
     or not exists (
       select 1 from public.room_players rp
       where rp.room_id = p_room_id
         and rp.player_id = v_uid
         and rp.left_at is null
     ) then
    raise exception 'Room not found or already started';
  end if;

  select count(*)::integer into v_active
  from public.room_players rp
  where rp.room_id = p_room_id and rp.left_at is null;

  -- Sınır önce ayrı hesaplanır: PL/pgSQL `IF` koşulunu ilk THEN'de
  -- keser; koşul içindeki `CASE … THEN` göçü sözdizimi hatasıyla
  -- düşürüyordu (canlıda rollback'li duman testi, 2026-10-18).
  v_cap := case
    when v_room.is_custom and v_room.max_players > 2 then v_room.max_players
    else 2
  end;
  if v_active >= v_cap then
    raise exception 'Room is full';
  end if;

  -- Saatte en çok 100 davet (yeniden davet satırı tazeler, sayıma girer).
  select count(*)::integer into v_recent
  from public.room_invites i
  where i.inviter_id = v_uid
    and i.created_at > now() - interval '1 hour';
  if v_recent + array_length(v_ids, 1) > 100 then
    raise exception 'Too many invites';
  end if;

  select coalesce(nullif(btrim(left(p.display_name, 40)), ''), 'ZanKurd')
  into v_name
  from public.profiles p
  where p.id = v_uid;
  v_name := coalesce(v_name, 'ZanKurd');

  foreach v_friend in array v_ids loop
    -- Kabul edilmiş arkadaş, iki yönde engelsiz, odada değil. Aksi halde
    -- sessizce atlanır (engel ifşa edilmez; dönen sayı gerçek davetleri söyler).
    if not exists (
         select 1 from public.friends f
         where f.user_id = v_uid and f.friend_id = v_friend
       )
       or exists (
         select 1 from public.blocked_users b
         where (b.blocker_id = v_uid and b.blocked_id = v_friend)
            or (b.blocker_id = v_friend and b.blocked_id = v_uid)
       )
       -- Davetli ile oda SAHİBİ arasında (her iki yönde) engel varsa da
       -- atlanır: katılımda zaten reddedilirdi, ölü davet kartı üretme.
       or exists (
         select 1 from public.blocked_users b
         where (b.blocker_id = v_room.host_id and b.blocked_id = v_friend)
            or (b.blocker_id = v_friend and b.blocked_id = v_room.host_id)
       )
       or exists (
         select 1 from public.room_players rp
         where rp.room_id = p_room_id
           and rp.player_id = v_friend
           and rp.left_at is null
       )
       -- Odadan çıkarılanı yalnız oda SAHİBİ yeniden davet edebilir
       -- (2026-10-22); başka üyenin daveti katılımda reddedilirdi.
       or (v_uid is distinct from v_room.host_id and exists (
         select 1 from public.room_kicks k
         where k.room_id = p_room_id
           and k.player_id = v_friend
       )) then
      continue;
    end if;

    -- Sahibin daveti çıkarmayı geri alır: yanlışlıkla çıkarılan aynı odaya
    -- daveti kabul ederek ya da kodla dönebilir.
    if v_uid = v_room.host_id then
      delete from public.room_kicks k
      where k.room_id = p_room_id
        and k.player_id = v_friend;
    end if;

    -- Bildirim yalnız yeni ya da 2 dakikadan eski davette kuyruklanır:
    -- yeniden dokunuş telefonu titretip durmasın.
    select i.created_at into v_prev
    from public.room_invites i
    where i.room_id = p_room_id and i.invitee_id = v_friend;
    v_push := v_prev is null or v_prev < now() - interval '2 minutes';

    insert into public.room_invites (room_id, inviter_id, invitee_id)
    values (p_room_id, v_uid, v_friend)
    on conflict (room_id, invitee_id) do update
      set inviter_id = excluded.inviter_id,
          status = 'pending',
          created_at = now();

    if v_push then
      insert into public.push_outbox (to_user_id, kind, title, body, from_user_id)
      values (
        v_friend,
        'room_invite',
        'ZanKurd',
        -- Sunucu alıcının arayüz dilini bilmiyor; metin iki dilli
        -- (enqueue_async_duel_invite_push ile aynı kalıp).
        v_name || ' te vedixwîne odeyê · ' || v_name
          || ' seni odaya davet etti',
        v_uid
      );
    end if;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$function$;

-- S4 --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_mission_completion(p_mission_key text, p_coin_reward integer, p_xp_reward integer)
 RETURNS TABLE(success boolean, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_id UUID;
  v_today DATE;
  v_coin INTEGER;
  v_rows INTEGER;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  -- İstemci ödülü GÜVENİLMEZ: p_coin_reward / p_xp_reward yok sayılır (imza
  -- eski sürümler için korunur), ödül sunucudaki sabit eşlemeden gelir.
  -- Anahtarlar lib/src/models/daily_mission.dart'taki 14 şablonun
  -- missionKey'idir (tür:hedef ya da playCategory:<slug>); jeton değerleri
  -- şablonun coinReward'ıdır, XP hepsinde 100.
  v_coin := CASE p_mission_key
    WHEN 'answerCorrect:5' THEN 30
    WHEN 'answerCorrect:10' THEN 50
    WHEN 'answerCorrect:15' THEN 75
    WHEN 'completeQuiz:1' THEN 25
    WHEN 'completeQuiz:3' THEN 60
    WHEN 'useWildcard:1' THEN 20
    WHEN 'useWildcard:2' THEN 40
    WHEN 'keepStreak:1' THEN 30
    WHEN 'playCategory:ziman' THEN 25
    WHEN 'playCategory:cand' THEN 25
    WHEN 'playCategory:dirok' THEN 25
    WHEN 'playCategory:edebiyat' THEN 25
    WHEN 'playCategory:cografya' THEN 25
    WHEN 'playCategory:muzik' THEN 25
    ELSE NULL
  END;

  -- Bilinmeyen anahtar: sessizce başarı döner ama HİÇBİR ŞEY yazılmaz
  -- (sahte anahtarla sınırsız satır üretilemez).
  IF v_coin IS NULL THEN
    RETURN QUERY SELECT TRUE, 'Mission completion synced'::TEXT;
    RETURN;
  END IF;

  v_today := public.app_today();

  -- Günde en çok 3 görev (forDay 3 görev üretir). Sayım ile ekleme arasında
  -- aynı kullanıcının eşzamanlı çağrısı sınırı aşmasın diye kullanıcı kilidi.
  PERFORM pg_advisory_xact_lock(
    hashtextextended('mission-sync:' || v_user_id::text, 0));

  SELECT count(*)::integer INTO v_rows
  FROM public.mission_completions mc
  WHERE mc.user_id = v_user_id
    AND mc.completion_date = v_today
    AND mc.mission_key <> p_mission_key;

  IF v_rows < 3 THEN
    INSERT INTO public.mission_completions (
      user_id, mission_key, completion_date, coin_reward, xp_reward
    )
    VALUES (v_user_id, p_mission_key, v_today, v_coin, 100)
    ON CONFLICT (user_id, mission_key, completion_date) DO NOTHING;
  END IF;

  RETURN QUERY SELECT TRUE, 'Mission completion synced'::TEXT;
END;
$function$;

-- S5 --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_analytics_event(p_event_name text, p_event_params jsonb DEFAULT NULL::jsonb)
 RETURNS TABLE(success boolean, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_user_id uuid;
  v_recent integer;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return query select false, 'Authenticated user required'::text;
    return;
  end if;

  if p_event_name is null or char_length(p_event_name) > 64 then
    raise exception 'event_name_too_long';
  end if;
  if p_event_params is not null
     and octet_length(p_event_params::text) > 4096 then
    raise exception 'event_params_too_large';
  end if;

  -- Kullanıcı başına saatte en çok 600 olay; fazlası SESSİZCE atılır
  -- (istemci yeniden denemesin diye başarı döner). Sayım
  -- idx_analytics_events_user_timestamp (user_id, event_timestamp desc)
  -- üzerinden en çok 600 satırda durur.
  select count(*)::integer into v_recent
  from (
    select 1
    from public.analytics_events e
    where e.user_id = v_user_id
      and e.event_timestamp > now() - interval '1 hour'
    limit 600
  ) recent;
  if v_recent >= 600 then
    return query select true, 'Event logged'::text;
    return;
  end if;

  insert into public.analytics_events (user_id, event_name, event_params)
  values (v_user_id, p_event_name, p_event_params);

  return query select true, 'Event logged'::text;
end;
$function$;

-- S6 --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.finalize_weekly_league(p_week date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_week date := coalesce(p_week, public.league_week_start(now() - interval '1 day'));
  v_from timestamptz := (v_week::timestamp at time zone 'Europe/Istanbul');
  v_to   timestamptz := ((v_week + 7)::timestamp at time zone 'Europe/Istanbul');
  v_count int := 0;
begin
  insert into public.league_weeks (week_start, status)
  values (v_week, 'finalizing')
  on conflict (week_start) do update set status = 'finalizing';

  -- Önceki hafta kademesi (yoksa bronz)
  create temporary table if not exists _prev_tier on commit drop as
  select player_id, tier
  from public.league_memberships
  where week_start = (v_week - 7);

  -- Bu haftanın skorları (yalnız başarıyla tamamlanmış maçlar)
  create temporary table if not exists _week_scores on commit drop as
  select
    rp.player_id,
    coalesce(sum(rp.score), 0)::bigint as weekly_score
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  where r.status = 'finished'
    and r.ended_reason = 'completed'
    and r.finished_at >= v_from
    and r.finished_at < v_to
    and rp.player_id is not null
  group by rp.player_id;

  -- Sıralama + kademe yaz
  delete from public.league_memberships where week_start = v_week;

  insert into public.league_memberships (
    week_start, player_id, tier, weekly_score, weekly_rank,
    previous_tier, promoted, relegated
  )
  select
    v_week,
    s.player_id,
    public.league_tier_for_rank(s.rnk::int),
    s.weekly_score,
    s.rnk::int,
    coalesce(p.tier, 'bronz'),
    public.league_tier_for_rank(s.rnk::int) = 'zer' and coalesce(p.tier, 'bronz') <> 'zer'
      or public.league_tier_for_rank(s.rnk::int) = 'ziv' and coalesce(p.tier, 'bronz') = 'bronz',
    public.league_tier_for_rank(s.rnk::int) = 'bronz' and coalesce(p.tier, 'bronz') in ('zer', 'ziv')
      or public.league_tier_for_rank(s.rnk::int) = 'ziv' and coalesce(p.tier, 'bronz') = 'zer'
  from (
    select
      player_id,
      weekly_score,
      rank() over (order by weekly_score desc, player_id) as rnk
    from _week_scores
  ) s
  left join _prev_tier p on p.player_id = s.player_id;

  get diagnostics v_count = row_count;

  update public.league_weeks
  set status = 'closed', finalized_at = now()
  where week_start = v_week;

  return jsonb_build_object(
    'week_start', v_week,
    'players', v_count,
    'status', 'closed'
  );
end;
$function$;

-- create or replace yetkileri korur ama yeniden tanımlayan her göç bu satırı
-- taşımalı (test/lig_kapanisi_yetki_test.dart).
revoke execute on function public.finalize_weekly_league(date) from public, anon, authenticated;

-- Canlıda zaten yalnız postgres/service_role'e açık (send-push service_role
-- ile çağırır); create or replace ileride yetkiyi geri getirmesin diye açık.
revoke execute on function public.claim_push_outbox(integer) from public, anon, authenticated;
revoke execute on function public.cleanup_stale_rooms() from public, anon, authenticated;

commit;
