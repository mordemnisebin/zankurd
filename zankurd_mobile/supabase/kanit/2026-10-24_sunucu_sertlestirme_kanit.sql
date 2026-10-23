-- Kanıt betiği: 2026-10-24_sunucu_sertlestirme.sql (S1..S6).
--
-- CANLIYA KALICI YAZMAZ: tek transaction, sonda rollback. Göçten ÖNCE ve
-- SONRA aynı betik çalıştırılır; her bulgu için bir satır basar:
--   bulgu | beklenen_once | beklenen_sonra | gozlenen
-- `gozlenen` ilk çalıştırmada beklenen_once, ikincide beklenen_sonra ile
-- eşleşmelidir. Bir adım hata verirse satırda 'HATA: ...' görünür (diğer
-- adımlar sürer; hatalı adım kendi savepoint'inde geri alınır).
--
--   supabase db query --linked -f supabase/kanit/2026-10-24_sunucu_sertlestirme_kanit.sql
--
-- Gerçek profillerden canlı odası olmayan altısı seçilir; oda, davet, olay
-- ve arkadaşlık satırlarını bu işlem kurar, rollback hepsini siler.
-- UYARI: cleanup_stale_rooms() ve claim_push_outbox() işlem içinde BÜTÜN
-- canlı satırlara da dokunur; rollback ile geri alınır (kilitler işlem
-- boyunca tutulur, betik birkaç saniyede biter).
begin;

create temp table _kanit (
  ord int,
  bulgu text,
  beklenen_once text,
  beklenen_sonra text,
  gozlenen text
) on commit drop;

create temp table _p (n int, id uuid) on commit drop;

insert into _p
select row_number() over (order by p.id)::int, p.id
from (
  select pr.id
  from public.profiles pr
  where not exists (
    select 1
    from public.room_players rp
    join public.rooms r on r.id = rp.room_id
    where rp.player_id = pr.id and r.status in ('lobby', 'active')
  )
  order by pr.id
  limit 6
) p;

do $$
begin
  if (select count(*) from _p) < 4 then
    raise exception 'kanit: canlı odası olmayan en az 4 profil gerekli';
  end if;
end $$;

-- ---------------------------------------------------------------- S1
-- Son soru açıklandıktan sonra 1v1'de çıkış: 'forfeit' değil 'completed'.
do $$
declare
  a uuid := (select id from _p where n = 1);
  b uuid := (select id from _p where n = 2);
  v_room uuid; v_q uuid[]; v_reason text; v_status text; i int;
begin
  select array_agg(id) into v_q from (select id from public.questions limit 3) q;

  -- (a) üç sorunun üçü de açıklanmış
  insert into public.rooms (code, host_id, status, question_count, started_at,
                            current_question_index)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), a, 'active', 3,
          now(), 2)
  returning id into v_room;
  insert into public.room_players (room_id, player_id) values (v_room, a), (v_room, b);
  for i in 1..3 loop
    insert into public.room_questions (room_id, question_id, question_index,
                                       started_at, revealed_at)
    values (v_room, v_q[i], i - 1, now() - interval '1 minute', now());
  end loop;
  perform set_config('request.jwt.claims', json_build_object('sub', b)::text, true);
  perform public.leave_room(v_room);
  select status::text, ended_reason into v_status, v_reason
  from public.rooms where id = v_room;
  insert into _kanit values (1, 'S1a son soru açıklandıktan sonra çıkış',
    'finished/forfeit', 'finished/completed', v_status || '/' || coalesce(v_reason, 'null'));

  -- (b) kontrol: son soru AÇIKLANMAMIŞ -> terk hâlâ 'forfeit'
  insert into public.rooms (code, host_id, status, question_count, started_at,
                            current_question_index)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), a, 'active', 3,
          now(), 2)
  returning id into v_room;
  insert into public.room_players (room_id, player_id) values (v_room, a), (v_room, b);
  for i in 1..3 loop
    insert into public.room_questions (room_id, question_id, question_index,
                                       started_at, revealed_at)
    values (v_room, v_q[i], i - 1, now() - interval '1 minute',
            case when i < 3 then now() else null end);
  end loop;
  perform public.leave_room(v_room);
  select status::text, ended_reason into v_status, v_reason
  from public.rooms where id = v_room;
  insert into _kanit values (2, 'S1b kontrol: son soru açıklanmadan çıkış',
    'finished/forfeit', 'finished/forfeit', v_status || '/' || coalesce(v_reason, 'null'));
exception when others then
  insert into _kanit values (1, 'S1', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- S2
do $$
declare
  a uuid := (select id from _p where n = 1);
  b uuid := (select id from _p where n = 2);
  c uuid := (select id from _p where n = 3);
  d uuid := (select id from _p where n = 4);
  v_stale_lobby uuid; v_fresh_lobby uuid; v_stale_active uuid; v_fresh_active uuid;
  v_q uuid;
begin
  select id into v_q from public.questions limit 1;

  -- 20 dk önce kurulmuş, kimse gelmemiş lobi (c)
  insert into public.rooms (code, host_id, status, created_at)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), c, 'lobby',
          now() - interval '20 minutes')
  returning id into v_stale_lobby;
  insert into public.room_players (room_id, player_id, joined_at)
  values (v_stale_lobby, c, now() - interval '20 minutes');

  -- taze lobi (d): dokunulmamalı
  insert into public.rooms (code, host_id, status)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), d, 'lobby')
  returning id into v_fresh_lobby;
  insert into public.room_players (room_id, player_id) values (v_fresh_lobby, d);

  -- 20 dk önce başlamış, hiç etkinlik yok aktif oda (a, b)
  insert into public.rooms (code, host_id, status, started_at, created_at)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), a, 'active',
          now() - interval '20 minutes', now() - interval '21 minutes')
  returning id into v_stale_active;
  insert into public.room_players (room_id, player_id, joined_at)
  values (v_stale_active, a, now() - interval '21 minutes'),
         (v_stale_active, b, now() - interval '21 minutes');
  insert into public.room_questions (room_id, question_id, question_index, started_at)
  values (v_stale_active, v_q, 0, now() - interval '20 minutes');

  perform public.cleanup_stale_rooms();

  insert into _kanit
  select 3, 'S2a 20 dk hareketsiz lobi', 'lobby/null', 'finished/stale_timeout',
         (select status::text || '/' || coalesce(ended_reason, 'null')
          from public.rooms where id = v_stale_lobby);
  insert into _kanit
  select 4, 'S2b taze lobi (kontrol)', 'lobby/null', 'lobby/null',
         (select status::text || '/' || coalesce(ended_reason, 'null')
          from public.rooms where id = v_fresh_lobby);
  insert into _kanit
  select 5, 'S2c 20 dk etkinliksiz aktif oda', 'active/null', 'finished/stale_timeout',
         (select status::text || '/' || coalesce(ended_reason, 'null')
          from public.rooms where id = v_stale_active);

  -- taze aktif oda (soru az önce başladı): dokunulmamalı
  update public.rooms set status = 'finished', ended_reason = 'completed',
         finished_at = now()
  where id = v_stale_active;
  insert into public.rooms (code, host_id, status, started_at)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), a, 'active', now())
  returning id into v_fresh_active;
  insert into public.room_players (room_id, player_id) values (v_fresh_active, a), (v_fresh_active, b);
  insert into public.room_questions (room_id, question_id, question_index, started_at)
  values (v_fresh_active, v_q, 0, now());
  perform public.cleanup_stale_rooms();
  insert into _kanit
  select 6, 'S2d taze aktif oda (kontrol)', 'active/null', 'active/null',
         (select status::text || '/' || coalesce(ended_reason, 'null')
          from public.rooms where id = v_fresh_active);

  insert into _kanit
  select 7, 'S2e cleanup-stale-rooms cron takvimi', '17 * * * *', '*/5 * * * *',
         coalesce((select schedule from cron.job where jobname = 'cleanup-stale-rooms'), 'yok');
exception when others then
  insert into _kanit values (3, 'S2', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- S3
do $$
declare
  c uuid := (select id from _p where n = 3);  -- gönderen
  d uuid := (select id from _p where n = 4);  -- alıcı
  v_has_col boolean;
  v_blocked_leak boolean; v_old_invite_leak boolean; v_old_other_leak boolean;
  v_fresh_ok boolean;
begin
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'push_outbox'
      and column_name = 'from_user_id'
  ) into v_has_col;
  insert into _kanit values (8, 'S3a push_outbox.from_user_id sütunu', 'false', 'true',
                             v_has_col::text);

  -- Tetikleyici yolu: c, d'ye arkadaşlık isteği atar (satır d için kuyruklanır).
  insert into public.friend_requests (from_user_id, from_user_name, to_user_id, status)
  values (c, 'Kanit', d, 'pending');
  -- d sonradan c'yi engeller.
  insert into public.blocked_users (blocker_id, blocked_id) values (d, c);

  -- Yaş sınırı: 45 dk önceki oda daveti ve 25 sa önceki arkadaşlık bildirimi.
  insert into public.push_outbox (to_user_id, kind, title, body, created_at)
  values (d, 'room_invite', 'KANIT', 'eski davet', now() - interval '45 minutes'),
         (d, 'friend_accept', 'KANIT', 'eski diger', now() - interval '25 hours'),
         (d, 'friend_accept', 'KANIT', 'taze kontrol', now());

  create temp table _claimed on commit drop as
  select * from public.claim_push_outbox(100);

  v_blocked_leak := exists (select 1 from _claimed
    where to_user_id = d and kind = 'friend_request');
  v_old_invite_leak := exists (select 1 from _claimed where title = 'KANIT' and body = 'eski davet');
  v_old_other_leak := exists (select 1 from _claimed where title = 'KANIT' and body = 'eski diger');
  v_fresh_ok := exists (select 1 from _claimed where title = 'KANIT' and body = 'taze kontrol');

  insert into _kanit values
    (9,  'S3b engelli gönderenin isteği gönderilmeye çıkar mı', 'true', 'false', v_blocked_leak::text),
    (10, 'S3c 45 dk eski oda daveti gönderilmeye çıkar mı', 'true', 'false', v_old_invite_leak::text),
    (11, 'S3d 25 sa eski bildirim gönderilmeye çıkar mı', 'true', 'false', v_old_other_leak::text),
    (12, 'S3e taze bildirim (kontrol) çıkar mı', 'true', 'true', v_fresh_ok::text);
exception when others then
  insert into _kanit values (8, 'S3', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- S4
do $$
declare
  a uuid := (select id from _p where n = 1);
  v_key text := 'kanit_' || substr(md5(random()::text), 1, 8);
begin
  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  perform * from public.sync_mission_completion(v_key, 999999, 999999);
  insert into _kanit
  select 13, 'S4 uydurma ödül (999999 jeton / 999999 XP) saklanan', '999999/999999', '100/100',
         mc.coin_reward || '/' || mc.xp_reward
  from public.mission_completions mc
  where mc.user_id = a and mc.mission_key = v_key;
exception when others then
  insert into _kanit values (13, 'S4', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- S5
do $$
declare
  a uuid := (select id from _p where n = 2);
  v_n integer;
begin
  insert into public.analytics_events (user_id, event_name)
  select a, 'kanit_dolgu' from generate_series(1, 600);
  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  perform * from public.log_analytics_event('kanit_sinir', null);
  select count(*) into v_n from public.analytics_events
  where user_id = a and event_name = 'kanit_sinir';
  insert into _kanit values (14, 'S5 saatte 600 olaydan sonraki 601. olay yazıldı mı (satır sayısı)',
    '1', '0', v_n::text);
exception when others then
  insert into _kanit values (14, 'S5', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- S6
-- Canlı gövde süzgeci zaten taşıyor (ÖNCE de true); göç dosya geçmişini
-- eşitler. Yetki: authenticated çalıştıramaz (ÖNCE de false).
insert into _kanit
select 15, 'S6a finalize_weekly_league gövdesi ended_reason=completed süzgecini taşıyor',
       'true', 'true',
       (pg_get_functiondef('public.finalize_weekly_league(date)'::regprocedure)
          like '%ended_reason = ''completed''%')::text;
insert into _kanit
select 16, 'S6b authenticated finalize_weekly_league çalıştırabilir mi',
       'false', 'false',
       has_function_privilege('authenticated', 'public.finalize_weekly_league(date)', 'execute')::text;

select bulgu, beklenen_once, beklenen_sonra, gozlenen,
       case when gozlenen = beklenen_sonra then 'SONRA-OK'
            when gozlenen = beklenen_once then 'ONCE-DURUMU'
            else 'BEKLENMEDIK' end as durum
from _kanit
order by ord, bulgu;

rollback;
