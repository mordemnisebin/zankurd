-- Kanıt betiği: 2026-10-24_sunucu_sertlestirme.sql (S1..S6 + yetki/yol).
--
-- CANLIYA KALICI YAZMAZ: tek transaction, sonda rollback. Göçten ÖNCE ve
-- SONRA aynı betik çalıştırılır; her bulgu için bir satır basar:
--   bulgu | beklenen_once | beklenen_sonra | gozlenen | durum
-- `gozlenen` ilk çalıştırmada beklenen_once, ikincide beklenen_sonra ile
-- eşleşmelidir (durum: ONCE-DURUMU / SONRA-OK / BEKLENMEDIK). Bir adım hata
-- verirse satırda 'HATA: ...' görünür (diğer adımlar sürer; hatalı adım
-- kendi savepoint'inde geri alınır).
--
--   supabase db query --linked -f supabase/kanit/2026-10-24_sunucu_sertlestirme_kanit.sql
--
-- Gerçek profillerden canlı odası olmayan sekizi seçilir; oda, davet, mesaj,
-- olay ve arkadaşlık satırlarını bu işlem kurar, rollback hepsini siler.
-- Profil satırında fcm_token işlem içinde değiştirilir (rollback geri alır).
-- UYARI: cleanup_stale_rooms() ve claim_push_outbox() işlem içinde BÜTÜN
-- canlı satırlara da dokunur; rollback ile geri alınır (kilitler işlem
-- boyunca tutulur, betik birkaç saniyede biter).
--
-- "Kontrol" satırları kusur değil, düzeltmenin yanlış pozitif üretmediğini
-- gösterir; ÖNCE durumunda canlı (24 saatlik) eşik yüzünden zaten doğrudur.
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
  limit 8
) p;

do $$
begin
  if (select count(*) from _p) < 8 then
    raise exception 'kanit: canlı odası olmayan en az 8 profil gerekli';
  end if;
end $$;

-- ---------------------------------------------------------------- S1
-- Son soru açıklandıktan sonra 1v1'de çıkış: 'forfeit' değil 'completed';
-- kazanan normal ödül yolundan (award_room_xp) XP alır.
do $$
declare
  a uuid := (select id from _p where n = 1);
  b uuid := (select id from _p where n = 2);
  v_room uuid; v_q uuid[]; v_reason text; v_status text; i int;
  v_xp0 integer; v_xp1 integer; v_res text;
begin
  select array_agg(id) into v_q from (select id from public.questions limit 3) q;

  -- (a) üç sorunun üçü de açıklanmış; a kazanıyor (skor 500), b çıkıyor
  insert into public.rooms (code, host_id, status, question_count, started_at,
                            current_question_index)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), a, 'active', 3,
          now(), 2)
  returning id into v_room;
  insert into public.room_players (room_id, player_id, score)
  values (v_room, a, 500), (v_room, b, 100);
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

  -- (c) kazananın normal ödül yolu: award_room_xp (istemci bitişte çağırır)
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
    select coalesce(xp, 0) into v_xp0 from public.profiles where id = a;
    perform public.award_room_xp(v_room);
    select coalesce(xp, 0) into v_xp1 from public.profiles where id = a;
    v_res := case when v_xp1 > v_xp0 then 'xp_artti' else 'xp_artmadi' end;
  exception when others then
    v_res := 'HATA: ' || sqlerrm;
  end;
  insert into _kanit values (2, 'S1c kazanan award_room_xp ile XP alır',
    'HATA: Room is not completed', 'xp_artti', v_res);

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
  perform set_config('request.jwt.claims', json_build_object('sub', b)::text, true);
  perform public.leave_room(v_room);
  select status::text, ended_reason into v_status, v_reason
  from public.rooms where id = v_room;
  insert into _kanit values (3, 'S1b kontrol: son soru açıklanmadan çıkış',
    'finished/forfeit', 'finished/forfeit', v_status || '/' || coalesce(v_reason, 'null'));
exception when others then
  insert into _kanit values (1, 'S1', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- S2
-- Her senaryo KENDİ do-bloğunda (kendi savepoint'i): biri hata verirse
-- ötekiler sürer. Oda kimlikleri _r'de tutulur. Sohbet satırı
-- enforce_chat_moderation tetikleyicisinden geçer (üye + jwt kimliği
-- zorunlu, created_at'i now() yapar), bu yüzden önce oyuncu room_players'a
-- eklenir ve jwt o oyuncuya çevrilir.
create temp table _r (ad text primary key, id uuid) on commit drop;

-- S2a: 40 dk önce kurulmuş, hiç etkinlik yok (p3)
do $$
declare p3 uuid := (select id from _p where n = 3); v uuid;
begin
  insert into public.rooms (code, host_id, status, created_at)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), p3, 'lobby',
          now() - interval '40 minutes')
  returning id into v;
  insert into public.room_players (room_id, player_id, joined_at)
  values (v, p3, now() - interval '40 minutes');
  insert into _r values ('stale_lobby', v);
exception when others then
  insert into _kanit values (10, 'S2a kurulum', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- S2b: taze lobi (p4)
do $$
declare p4 uuid := (select id from _p where n = 4); v uuid;
begin
  insert into public.rooms (code, host_id, status)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), p4, 'lobby')
  returning id into v;
  insert into public.room_players (room_id, player_id) values (v, p4);
  insert into _r values ('fresh_lobby', v);
exception when others then
  insert into _kanit values (11, 'S2b kurulum', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- S2c: 40 dk önce kurulmuş AMA az önce sohbet var (p5, üye olarak yazar)
do $$
declare p5 uuid := (select id from _p where n = 5); v uuid;
begin
  insert into public.rooms (code, host_id, status, created_at)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), p5, 'lobby',
          now() - interval '40 minutes')
  returning id into v;
  insert into public.room_players (room_id, player_id, joined_at)
  values (v, p5, now() - interval '40 minutes');
  perform set_config('request.jwt.claims', json_build_object('sub', p5)::text, true);
  insert into public.room_messages (room_id, sender_id, text)
  values (v, p5, 'merheba');
  insert into _r values ('chat_lobby', v);
exception when others then
  insert into _kanit values (12, 'S2c kurulum', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- S2d: 40 dk önce kurulmuş AMA az önce davet atılmış (p7 -> p8)
do $$
declare
  p7 uuid := (select id from _p where n = 7);
  p8 uuid := (select id from _p where n = 8);
  v uuid;
begin
  insert into public.rooms (code, host_id, status, created_at)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), p7, 'lobby',
          now() - interval '40 minutes')
  returning id into v;
  insert into public.room_players (room_id, player_id, joined_at)
  values (v, p7, now() - interval '40 minutes');
  insert into public.room_invites (room_id, inviter_id, invitee_id, created_at)
  values (v, p7, p8, now() - interval '5 minutes');
  insert into _r values ('invite_lobby', v);
exception when others then
  insert into _kanit values (13, 'S2d kurulum', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- S2e: 20 dk önce kurulmuş, misafir (p4) 18 dk önce girip çıktı (satırı
-- silindi); ev sahibi (p6) lobisi açık kalmalı
do $$
declare
  p4 uuid := (select id from _p where n = 4);
  p6 uuid := (select id from _p where n = 6);
  v uuid;
begin
  insert into public.rooms (code, host_id, status, created_at)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), p6, 'lobby',
          now() - interval '20 minutes')
  returning id into v;
  insert into public.room_players (room_id, player_id, joined_at)
  values (v, p6, now() - interval '20 minutes'),
         (v, p4, now() - interval '18 minutes');
  perform set_config('request.jwt.claims', json_build_object('sub', p4)::text, true);
  perform public.leave_room(v);
  insert into _r values ('guest_lobby', v);
exception when others then
  insert into _kanit values (14, 'S2e kurulum', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- S2f: 20 dk önce başlamış, hiç etkinlik yok aktif oda (p1, p2)
do $$
declare
  p1 uuid := (select id from _p where n = 1);
  p2 uuid := (select id from _p where n = 2);
  v uuid; v_q uuid;
begin
  select id into v_q from public.questions limit 1;
  insert into public.rooms (code, host_id, status, started_at, created_at)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), p1, 'active',
          now() - interval '20 minutes', now() - interval '21 minutes')
  returning id into v;
  insert into public.room_players (room_id, player_id, joined_at)
  values (v, p1, now() - interval '21 minutes'),
         (v, p2, now() - interval '21 minutes');
  insert into public.room_questions (room_id, question_id, question_index, started_at)
  values (v, v_q, 0, now() - interval '20 minutes');
  insert into _r values ('stale_active', v);
exception when others then
  insert into _kanit values (15, 'S2f kurulum', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- S2g: 20 dk önce BÜTÜN soruları açıklanmış ama finished yapılmamış oda
do $$
declare
  p1 uuid := (select id from _p where n = 1);
  p2 uuid := (select id from _p where n = 2);
  v uuid; v_q uuid[]; i int;
begin
  select array_agg(id) into v_q from (select id from public.questions limit 3) q;
  insert into public.rooms (code, host_id, status, question_count, started_at,
                            created_at, current_question_index)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), p1, 'active', 3,
          now() - interval '22 minutes', now() - interval '23 minutes', 2)
  returning id into v;
  insert into public.room_players (room_id, player_id, score)
  values (v, p1, 300), (v, p2, 100);
  for i in 1..3 loop
    insert into public.room_questions (room_id, question_id, question_index,
                                       started_at, revealed_at)
    values (v, v_q[i], i - 1, now() - interval '20 minutes',
            now() - interval '20 minutes');
  end loop;
  insert into _r values ('final_active', v);
exception when others then
  insert into _kanit values (16, 'S2g kurulum', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- S2h: taze aktif oda: soru az önce başladı
do $$
declare
  p1 uuid := (select id from _p where n = 1);
  p2 uuid := (select id from _p where n = 2);
  v uuid; v_q uuid;
begin
  select id into v_q from public.questions limit 1;
  insert into public.rooms (code, host_id, status, started_at)
  values ('K' || upper(substr(md5(random()::text), 1, 5)), p1, 'active', now())
  returning id into v;
  insert into public.room_players (room_id, player_id) values (v, p1), (v, p2);
  insert into public.room_questions (room_id, question_id, question_index, started_at)
  values (v, v_q, 0, now());
  insert into _r values ('fresh_active', v);
exception when others then
  insert into _kanit values (17, 'S2h kurulum', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- temizlik çalışır
do $$
begin
  perform public.cleanup_stale_rooms();
exception when others then
  insert into _kanit values (18, 'S2 cleanup_stale_rooms çağrısı', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- sonuçlar (oda yoksa 'yok')
insert into _kanit
select x.ord, x.bulgu, x.once, x.sonra,
       coalesce((select r.status::text || '/' || coalesce(r.ended_reason, 'null')
                 from public.rooms r join _r on _r.id = r.id where _r.ad = x.ad),
                'yok')
from (values
  (10, 'stale_lobby',   'S2a 40 dk etkinliksiz lobi', 'lobby/null', 'finished/stale_timeout'),
  (11, 'fresh_lobby',   'S2b taze lobi (kontrol)', 'lobby/null', 'lobby/null'),
  (12, 'chat_lobby',    'S2c 40 dk önce kurulmuş ama sohbet eden lobi kapanmaz (kontrol)', 'lobby/null', 'lobby/null'),
  (13, 'invite_lobby',  'S2d 40 dk önce kurulmuş ama davet atılan lobi kapanmaz (kontrol)', 'lobby/null', 'lobby/null'),
  (14, 'guest_lobby',   'S2e misafir girip çıktı, ev sahibi lobisi açık kalır (kontrol)', 'lobby/null', 'lobby/null'),
  (15, 'stale_active',  'S2f 20 dk etkinliksiz aktif oda', 'active/null', 'finished/stale_timeout'),
  (16, 'final_active',  'S2g tüm soruları açıklanmış bayat aktif oda stale değil completed olur', 'active/null', 'finished/completed'),
  (17, 'fresh_active',  'S2h taze aktif oda (kontrol)', 'active/null', 'active/null')
) as x(ord, ad, bulgu, once, sonra)
where exists (select 1 from _r where _r.ad = x.ad);

insert into _kanit
select 19, 'S2i cleanup-stale-rooms cron takvimi', '17 * * * *', '*/5 * * * *',
       coalesce((select schedule from cron.job where jobname = 'cleanup-stale-rooms'), 'yok');

-- ---------------------------------------------------------------- S3
do $$
declare
  c uuid := (select id from _p where n = 3);  -- gönderen
  d uuid := (select id from _p where n = 4);  -- alıcı (token'lı)
  e uuid := (select id from _p where n = 5);  -- token'sız alıcı
  v_has_col boolean;
  v_blocked_leak boolean; v_old_invite_leak boolean; v_old_other_leak boolean;
  v_fresh_ok boolean; v_tokenless_burnt boolean;
begin
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'push_outbox'
      and column_name = 'from_user_id'
  ) into v_has_col;
  insert into _kanit values (20, 'S3a push_outbox.from_user_id sütunu', 'false', 'true',
                             v_has_col::text);

  update public.profiles set fcm_token = 'kanit-token' where id = d;
  update public.profiles set fcm_token = null where id = e;

  -- Tetikleyici yolu: c, d'ye arkadaşlık isteği atar (satır d için kuyruklanır).
  insert into public.friend_requests (from_user_id, from_user_name, to_user_id, status)
  values (c, 'Kanit', d, 'pending');
  -- d sonradan c'yi engeller.
  insert into public.blocked_users (blocker_id, blocked_id) values (d, c);

  -- Yaş sınırı: 45 dk önceki oda daveti ve 25 sa önceki arkadaşlık bildirimi;
  -- taze kontrol; token'sız alıcıya taze bildirim.
  insert into public.push_outbox (to_user_id, kind, title, body, created_at)
  values (d, 'room_invite', 'KANIT', 'eski davet', now() - interval '45 minutes'),
         (d, 'friend_accept', 'KANIT', 'eski diger', now() - interval '25 hours'),
         (d, 'friend_accept', 'KANIT', 'taze kontrol', now()),
         (e, 'friend_accept', 'KANIT', 'tokensiz', now());

  create temp table _claimed on commit drop as
  select * from public.claim_push_outbox(100);

  v_blocked_leak := exists (select 1 from _claimed
    where to_user_id = d and kind = 'friend_request');
  v_old_invite_leak := exists (select 1 from _claimed where title = 'KANIT' and body = 'eski davet');
  v_old_other_leak := exists (select 1 from _claimed where title = 'KANIT' and body = 'eski diger');
  v_fresh_ok := exists (select 1 from _claimed where title = 'KANIT' and body = 'taze kontrol');
  select o.claimed_at is not null into v_tokenless_burnt
  from public.push_outbox o where o.title = 'KANIT' and o.body = 'tokensiz';

  insert into _kanit values
    (21, 'S3b engelli gönderenin isteği gönderilmeye çıkar mı', 'true', 'false', v_blocked_leak::text),
    (22, 'S3c 45 dk eski oda daveti gönderilmeye çıkar mı', 'true', 'false', v_old_invite_leak::text),
    (23, 'S3d 25 sa eski bildirim gönderilmeye çıkar mı', 'true', 'false', v_old_other_leak::text),
    (24, 'S3e taze bildirim (kontrol) çıkar mı', 'true', 'true', v_fresh_ok::text),
    (25, 'S3f token''sız alıcının taze bildirimi yakıldı (claimed_at dolu) mı', 'true', 'false',
     v_tokenless_burnt::text);
exception when others then
  insert into _kanit values (20, 'S3', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- S4
-- Sunucu eşlemesi: ödül istemciden gelmez; anahtar beyaz liste; günde 3 satır.
do $$
declare
  a uuid := (select id from _p where n = 1);
  v_fake text := 'kanit_' || substr(md5(random()::text), 1, 8);
begin
  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  perform * from public.sync_mission_completion('answerCorrect:5', 999999, 999999);
  insert into _kanit
  select 30, 'S4a uydurma ödül (999999/999999) ile geçerli anahtar: saklanan jeton/XP',
         '999999/999999', '30/100',
         mc.coin_reward || '/' || mc.xp_reward
  from public.mission_completions mc
  where mc.user_id = a and mc.mission_key = 'answerCorrect:5';

  perform * from public.sync_mission_completion(v_fake, 10, 10);
  insert into _kanit values (31, 'S4b uydurma anahtar için satır yazıldı mı', 'true', 'false',
    exists (select 1 from public.mission_completions mc
            where mc.user_id = a and mc.mission_key = v_fake)::text);

  perform * from public.sync_mission_completion('answerCorrect:10', 1, 1);
  perform * from public.sync_mission_completion('answerCorrect:15', 1, 1);
  perform * from public.sync_mission_completion('completeQuiz:1', 1, 1);
  insert into _kanit values (32, 'S4c bir kullanıcının bugünkü toplam satırı (5 çağrı: 1 uydurma, 4 geçerli)',
    '5', '3',
    (select count(*) from public.mission_completions mc
     where mc.user_id = a and mc.completion_date = public.app_today())::text);
exception when others then
  insert into _kanit values (30, 'S4', '-', '-', 'HATA: ' || sqlerrm);
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
  insert into _kanit values (40, 'S5 saatte 600 olaydan sonraki 601. olay yazıldı mı (satır sayısı)',
    '1', '0', v_n::text);
exception when others then
  insert into _kanit values (40, 'S5', '-', '-', 'HATA: ' || sqlerrm);
end $$;

-- ---------------------------------------------------------------- S6
-- Canlı gövde süzgeci zaten taşıyor (ÖNCE de true); göç dosya geçmişini
-- eşitler. Yetki: authenticated çalıştıramaz (ÖNCE de false).
insert into _kanit
select 50, 'S6a finalize_weekly_league gövdesi ended_reason=completed süzgecini taşıyor',
       'true', 'true',
       (pg_get_functiondef('public.finalize_weekly_league(date)'::regprocedure)
          like '%ended_reason = ''completed''%')::text;
insert into _kanit
select 51, 'S6b authenticated finalize_weekly_league çalıştırabilir mi',
       'false', 'false',
       has_function_privilege('authenticated', 'public.finalize_weekly_league(date)', 'execute')::text;

-- ------------------------------------------------- yetki ve search_path
insert into _kanit
select 60, 'Y1 authenticated claim_push_outbox çalıştırabilir mi', 'false', 'false',
       has_function_privilege('authenticated', 'public.claim_push_outbox(integer)', 'execute')::text;
insert into _kanit
select 61, 'Y2 authenticated cleanup_stale_rooms çalıştırabilir mi', 'false', 'false',
       has_function_privilege('authenticated', 'public.cleanup_stale_rooms()', 'execute')::text;
insert into _kanit
select 62, 'Y3 anon claim_push_outbox çalıştırabilir mi', 'false', 'false',
       has_function_privilege('anon', 'public.claim_push_outbox(integer)', 'execute')::text;
-- Göçün değiştirdiği 9 SECURITY DEFINER fonksiyonundan kaçının yolu
-- 'pg_temp' içeriyor (proconfig).
insert into _kanit
select 63, 'Y4 search_path ''public, pg_temp'' olan değişen fonksiyon sayısı (9 üzerinden)', '0', '9',
       (select count(*) from pg_proc p
        where p.pronamespace = 'public'::regnamespace
          and p.proname in ('leave_room', 'cleanup_stale_rooms', 'claim_push_outbox',
                            'enqueue_friend_request_push', 'enqueue_friend_accept_push',
                            'invite_friends_to_room', 'sync_mission_completion',
                            'log_analytics_event', 'finalize_weekly_league')
          and exists (select 1 from unnest(p.proconfig) c where c like '%pg_temp%'))::text;

select bulgu, beklenen_once, beklenen_sonra, gozlenen,
       case when gozlenen = beklenen_sonra then 'SONRA-OK'
            when gozlenen = beklenen_once then 'ONCE-DURUMU'
            else 'BEKLENMEDIK' end as durum
from _kanit
order by ord, bulgu;

rollback;
