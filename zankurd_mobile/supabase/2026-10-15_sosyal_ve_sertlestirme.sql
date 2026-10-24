-- 2026-10-15: SOSYAL YÜZEY + SERTLEŞTİRME — arkadaşlık yaşam döngüsü, engel
-- temizliği, liderlik bütünlüğü, FCM sahipliği, sınırsız girdi, sırayla düello.
--
-- NİÇİN: Canlı sunucu (2026-10-15) ve istemci denetimi on iki ayrı kusur buldu;
-- hiçbiri hata vermiyor, hepsi sessiz:
--   * `questions` ve `player_answers` üzerinde anon/authenticated'a MAINTAIN
--     açıktı (LOCK TABLE ... ACCESS EXCLUSIVE ile tabloyu kilitleyebilir).
--   * `quiz_public_questions` görünümü istemciye "permission denied" veriyor,
--     yani hiçbir istemci çağrısı onu kullanamıyor; ölü yüzey.
--   * Liderlik, bitmiş HER odanın skorunu topluyordu (terk edilen/süresi dolan
--     odalar dahil) ve eşit puanda sıra belirsizdi: sabitlenen "benim sıram"
--     listedeki konumla tutmayabiliyordu.
--   * `advance_tournament` bitmiş turnuvanın `finished_at`ini her dakika yeniden
--     damgalıyordu (resolve_expired_tournament_matches sonsuza dek çağırır).
--   * Engel/bildirim arkadaşlığı ve bekleyen istekleri SİLMİYORDU: engellediğin
--     kişi arkadaş listende kalıyor, bekleyen isteği kabul edilebiliyordu.
--   * Arkadaşı silmek ve gönderilmiş isteği geri çekmek için RPC yoktu; karşı
--     taraftan bana gelmiş bekleyen isteğe `add_friend` ikinci bir bekleyen
--     satır açıyordu; hedef profil denetimi ve istek hız sınırı yoktu.
--   * Reddedilmiş isteği yeniden göndermek ON CONFLICT UPDATE yolundan geçtiği
--     için bildirim tetikleyicisi (yalnız INSERT) hiç ateşlenmiyordu.
--   * Aynı FCM token iki profilde durabiliyordu (cihazı devralan hesap
--     öncekinin bildirimlerini alırdı); çıkışta token temizlenmiyordu.
--   * `redeem_referral_code`: sınırsız ödül (bir davet eden kişi sınırsız
--     hesap açtırıp ödül toplayabilir) ve hiç oynamamış hesap da ödül alıyordu.
--   * `suggested_questions` ve `log_analytics_event` sınırsız boyutta girdi
--     kabul ediyordu.
--   * Sırayla düello: yarım bırakılan düello gelen kutusunda ölü bir "Yarım
--     kaldı" satırıydı (devam edilemiyordu), 5'lik açık-düello sınırı süresi
--     dolmuş ama henüz süpürülmemiş düelloları da sayıyordu, kimsenin almadığı
--     düello geri çekilemiyordu.
--
-- Her CREATE OR REPLACE, CANLI tanımdan (pg_get_functiondef, 2026-10-15)
-- türetildi; güvenlik nitelikleri (SECURITY DEFINER, search_path, auth.uid()
-- denetimleri, ACL) korundu. Yeni RPC'ler add_friend ile aynı ACL'yi alır:
-- PUBLIC/anon yok, authenticated + service_role.
--
-- İSTEMCİ UYUMU: mevcut imzalar ve dönüş biçimleri değişmedi. Yeni RPC'ler
-- (remove_friend, cancel_friend_request, list_sent_friend_requests,
-- clear_my_fcm_token, resume_my_async_duel, cancel_my_async_duel) yokken
-- istemci (PGRST202) ilgili eylemi sessizce gizler; uygulama göçten önce de
-- sonra da çalışır.
--
-- TEKRAR: idempotent (create or replace, drop ... if exists, CHECK yalnız
-- yoksa eklenir, revoke/grant tekrarı zararsız).
-- GERİ ALMA: bu dosyanın başında anılan her fonksiyonun önceki gövdesi
-- ilgili eski göçte durur (2026-10-02_blocking_enforcement.sql, 2026-10-13_
-- friend_challenge.sql, 2026-10-02_referral_redemption_ledger.sql ...); yeni
-- fonksiyonlar `drop function if exists` ile kaldırılır; CHECK'ler `drop
-- constraint` ile.
-- Uygulama: supabase db query --linked -f supabase/2026-10-15_sosyal_ve_sertlestirme.sql
-- (Bu dosya canlıya UYGULANMADI; Docker olmadığından yerelde de çalıştırılmadı.
--  Bkz. supabase/applied.md.)

begin;

-- ---------------------------------------------------------------------
-- 1) MAINTAIN yetkisini istemci rollerinden al
-- ---------------------------------------------------------------------
-- Postgres 17'nin MAINTAIN yetkisi VACUUM/ANALYZE/REINDEX/CLUSTER ve LOCK TABLE
-- içindir. Canlıda anon ve authenticated tüm public tablolarda bu yetkiye
-- sahipti; REST üzerinden kullanılamasa da doğrudan bağlantıda bir istemci
-- rolü `questions`i ACCESS EXCLUSIVE kilitleyebilir. İstemcinin hiçbir
-- meşru işi bu yetkiyi gerektirmez.

revoke maintain on public.questions, public.player_answers
  from anon, authenticated;

do $$
declare
  v_table text;
begin
  for v_table in
    select format('%I.%I', n.nspname, c.relname)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
  loop
    execute format('revoke maintain on %s from anon, authenticated', v_table);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 2) Ölü görünüm: quiz_public_questions
-- ---------------------------------------------------------------------
-- security_invoker görünümü, altındaki `questions` tablosunda istemciye SELECT
-- verilmediği için her çağrıda "permission denied" döner. İstemci çağrısı da
-- kaldırıldı (supabase_zankurd_repository.dart). Hiçbir fonksiyon ona bağlı
-- değil (canlı gövdelerde aranıp doğrulandı).

drop view if exists public.quiz_public_questions;

-- ---------------------------------------------------------------------
-- 3) Liderlik bütünlüğü
-- ---------------------------------------------------------------------
-- (a) Yalnız NORMAL biten odalar sayılır (ended_reason = 'completed').
--     stale_timeout / host_left / forfeit ile kapanan odalarda oyuncular
--     soruların küçük bir kısmını oynamış olabilir; skorları sıralamaya
--     girmemeli. ended_reason sütunu 2026-08-12'de geldi; ondan önce biten
--     53 odada NULL (hepsi normal bitiş) — onlar da sayılır.
-- (b) Eşit puan/seri/oda sayısında son bakış player_id: liste sırası
--     belirlenimli olur ve `get_my_leaderboard_rank` (row_number) listedeki
--     konumla aynı sırayı üretir.

create or replace function public.get_leaderboard(
  p_days integer default '-1'::integer,
  p_limit integer default 10
)
returns table(
  player_id uuid,
  display_name text,
  total_score bigint,
  best_streak bigint,
  rooms_played bigint,
  avatar_icon text,
  avatar_color text,
  avatar_url text,
  avatar_frame text,
  showcase_title text
)
language sql
stable security definer
set search_path to 'public'
as $function$
  select
    rp.player_id,
    coalesce(p.display_name, 'Oyuncu'),
    coalesce(sum(rp.score), 0),
    coalesce(max(rp.streak), 0),
    count(distinct rp.room_id),
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  left join public.profiles p on p.id = rp.player_id
  where r.status = 'finished'
    -- Yalnız normal biten odalar (2026-10-15); NULL = sütundan önceki odalar.
    and coalesce(r.ended_reason, 'completed') = 'completed'
    -- Engelleme (2026-10-02 M5): engellediğim oyuncular MENİM listemde yok.
    -- Yalnız çağıranın engelleri uygulanır (tek yön); liste kişiye göre
    -- değişir ama başkasının engel bilgisi sızmaz.
    and not exists (
      select 1 from public.blocked_users b
      where b.blocker_id = auth.uid()
        and b.blocked_id = rp.player_id
    )
    and (p_days <= 0 or r.finished_at >= now() - make_interval(days => p_days))
  group by
    rp.player_id, p.display_name, p.avatar_icon, p.avatar_color,
    p.avatar_url, p.avatar_frame, p.showcase_title
  having coalesce(sum(rp.score), 0) > 0
  order by coalesce(sum(rp.score), 0) desc,
    coalesce(max(rp.streak), 0) desc,
    count(distinct rp.room_id) desc,
    rp.player_id asc
  limit least(greatest(p_limit, 1), 100);
$function$;

create or replace function public.get_my_leaderboard_rank(
  p_days integer default '-1'::integer
)
returns table(
  rank bigint,
  player_id uuid,
  display_name text,
  total_score bigint,
  best_streak bigint,
  rooms_played bigint,
  avatar_icon text,
  avatar_color text,
  avatar_url text,
  avatar_frame text,
  showcase_title text
)
language sql
stable security definer
set search_path to 'public'
as $function$
  with board as (
    select
      rp.player_id,
      coalesce(p.display_name, 'Oyuncu') as display_name,
      coalesce(sum(rp.score), 0) as total_score,
      coalesce(max(rp.streak), 0) as best_streak,
      count(distinct rp.room_id) as rooms_played,
      p.avatar_icon,
      p.avatar_color,
      p.avatar_url,
      p.avatar_frame,
      p.showcase_title
    from public.room_players rp
    join public.rooms r on r.id = rp.room_id
    left join public.profiles p on p.id = rp.player_id
    where r.status = 'finished'
      -- get_leaderboard ile aynı oda süzgeci ve engel süzgeci (sıra
      -- numaraları tutarlı kalsın).
      and coalesce(r.ended_reason, 'completed') = 'completed'
      and not exists (
        select 1 from public.blocked_users b
        where b.blocker_id = auth.uid()
          and b.blocked_id = rp.player_id
      )
      and (p_days <= 0
        or r.finished_at >= now() - make_interval(days => p_days))
    group by
      rp.player_id, p.display_name, p.avatar_icon, p.avatar_color,
      p.avatar_url, p.avatar_frame, p.showcase_title
    having coalesce(sum(rp.score), 0) > 0
  ),
  ordered as (
    select
      b.*,
      row_number() over (
        order by
          b.total_score desc,
          b.best_streak desc,
          b.rooms_played desc,
          b.player_id asc
      ) as row_no
    from board b
  )
  select
    o.row_no as rank,
    o.player_id,
    o.display_name,
    o.total_score,
    o.best_streak,
    o.rooms_played,
    o.avatar_icon,
    o.avatar_color,
    o.avatar_url,
    o.avatar_frame,
    o.showcase_title
  from ordered o
  where o.player_id = auth.uid()
  limit 1;
$function$;

-- ---------------------------------------------------------------------
-- 4) advance_tournament: bitmiş turnuvaya dokunma
-- ---------------------------------------------------------------------
-- resolve_expired_tournament_matches süresi dolmuş maçı olan HER turnuvayı
-- (bitmiş olanlar dahil, sonsuza dek) advance_tournament'a verir. Bitmiş
-- turnuvada son turun tamamı 'completed' olduğundan fonksiyon son dala düşüp
-- `finished_at = now()` ile bitiş zamanını her çağrıda ileri alıyordu.

create or replace function public.advance_tournament(p_tournament_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_round int;
  v_pending int;
  v_winners uuid[];
  v_i int;
  v_slot int := 0;
  v_hours int;
begin
  -- Bitmiş turnuva değiştirilmez (şampiyon ve finished_at sabit kalır).
  if exists (
    select 1 from public.tournaments
    where id = p_tournament_id and status = 'finished'
  ) then
    return;
  end if;

  select round_hours into v_hours from public.tournaments
   where id = p_tournament_id;

  select max(round) into v_round from public.tournament_matches
   where tournament_id = p_tournament_id;
  if v_round is null then return; end if;

  select count(*) into v_pending from public.tournament_matches
   where tournament_id = p_tournament_id
     and round = v_round
     and status <> 'completed';
  if v_pending > 0 then return; end if;

  select array_agg(winner_id order by slot) into v_winners
    from public.tournament_matches
   where tournament_id = p_tournament_id
     and round = v_round
     and winner_id is not null;

  if v_winners is null or array_length(v_winners, 1) <= 1 then
    update public.tournaments
       set status = 'finished',
           finished_at = now(),
           champion_id = case
             when v_winners is null then null else v_winners[1] end
     where id = p_tournament_id;
    return;
  end if;

  v_i := 1;
  while v_i <= array_length(v_winners, 1) loop
    insert into public.tournament_matches (
      tournament_id, round, slot, player_one, player_two, deadline
    ) values (
      p_tournament_id, v_round + 1, v_slot,
      v_winners[v_i], v_winners[v_i + 1],
      now() + make_interval(hours => coalesce(v_hours, 24))
    );
    v_slot := v_slot + 1;
    v_i := v_i + 2;
  end loop;

  update public.tournament_matches
     set status = 'completed', winner_id = player_one
   where tournament_id = p_tournament_id
     and round = v_round + 1
     and player_two is null;
end;
$function$;

-- ---------------------------------------------------------------------
-- 5) Engel arkadaşlığı ve bekleyen istekleri de siler
-- ---------------------------------------------------------------------
-- Eskiden engel yalnız `blocked_users`a satır ekliyordu: engellenen kişi
-- arkadaş listesinde kalıyor, ona gelen/ondan gelen bekleyen istek de
-- duruyordu. `sever_social_ties` iki yönde arkadaşlık satırlarını ve her
-- durumdaki arkadaş isteklerini siler; istemciye KAPALI iç yardımcıdır
-- (yalnız aşağıdaki SECURITY DEFINER fonksiyonlar çağırır).

create or replace function public.sever_social_ties(p_a uuid, p_b uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  delete from public.friends
  where (user_id = p_a and friend_id = p_b)
     or (user_id = p_b and friend_id = p_a);

  delete from public.friend_requests
  where (from_user_id = p_a and to_user_id = p_b)
     or (from_user_id = p_b and to_user_id = p_a);
end;
$function$;

revoke all on function public.sever_social_ties(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.block_player(p_blocked_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_blocked_id = auth.uid() then
    raise exception 'cannot_block_self';
  end if;
  insert into public.blocked_users (blocker_id, blocked_id)
  values (auth.uid(), p_blocked_id)
  on conflict do nothing;

  -- Engel arkadaşlığı ve bekleyen istekleri iki yönde de kaldırır.
  perform public.sever_social_ties(auth.uid(), p_blocked_id);
end;
$function$;

create or replace function public.report_player_profile(
  p_reported_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;

  -- Kendini bildirmek anlamsız; sessizce başarı dönmek yerine açıkça
  -- reddedilir ki istemci hatayı gösterebilsin.
  if v_uid = p_reported_id then
    return jsonb_build_object('success', false, 'error', 'cannot report self');
  end if;

  if p_reported_id is null
     or not exists (select 1 from public.profiles where id = p_reported_id)
  then
    return jsonb_build_object('success', false, 'error', 'unknown profile');
  end if;

  insert into public.profile_reports (reporter_id, reported_id, reason)
  values (v_uid, p_reported_id, coalesce(nullif(btrim(p_reason), ''), 'unspecified'))
  on conflict (reporter_id, reported_id) do update
    set reason = excluded.reason,
        created_at = now();

  -- Bildiren kişi için engeli de kur: bildirdiği avatarı/adı bir daha
  -- görmek zorunda kalmamalı. Apple 1.2'nin "engelleme" maddesi ile
  -- "bildirme" maddesi kullanıcı gözünde tek bir eylemdir.
  insert into public.blocked_users (blocker_id, blocked_id)
  values (v_uid, p_reported_id)
  on conflict do nothing;

  -- Otomatik engel de block_player ile aynı temizliği yapar (2026-10-15).
  perform public.sever_social_ties(v_uid, p_reported_id);

  return jsonb_build_object('success', true);
end;
$function$;

-- ---------------------------------------------------------------------
-- 6) remove_friend / cancel_friend_request / list_sent_friend_requests
-- ---------------------------------------------------------------------
-- Arkadaşı silmek ve gönderilmiş isteği geri çekmek için sunucu yolu yoktu.
-- Silme iki yönü birden kaldırır (friends iki satır tutar) ve aradaki eski
-- istek satırlarını da temizler ki yeniden eklemek temiz başlasın.
-- İptal satırı SİLMEZ, 'cancelled' yapar: silseydik `created_at` tabanlı
-- hız sınırı (add_friend) iptal-yeniden gönder döngüsüyle aşılırdı.
-- list_sent_friend_requests: "gönderdim" durumu yerel bellekte değil sunucuda
-- durmalı (ekran kapanıp açılınca ya da başka cihazda kaybolmasın).

create or replace function public.remove_friend(p_friend_id uuid)
returns table(success boolean, message text)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_rows int;
begin
  if v_uid is null then
    return query select false, 'Authenticated user required'::text;
    return;
  end if;

  delete from public.friends
  where (user_id = v_uid and friend_id = p_friend_id)
     or (user_id = p_friend_id and friend_id = v_uid);
  get diagnostics v_rows = row_count;

  delete from public.friend_requests
  where (from_user_id = v_uid and to_user_id = p_friend_id)
     or (from_user_id = p_friend_id and to_user_id = v_uid);

  if v_rows = 0 then
    return query select false, 'Not friends'::text;
    return;
  end if;

  return query select true, 'Friend removed'::text;
end;
$function$;

create or replace function public.cancel_friend_request(p_target_id uuid)
returns table(success boolean, message text)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_rows int;
begin
  if v_uid is null then
    return query select false, 'Authenticated user required'::text;
    return;
  end if;

  -- Yalnız KENDİ gönderdiğim, hâlâ bekleyen istek.
  update public.friend_requests
  set status = 'cancelled'
  where from_user_id = v_uid
    and to_user_id = p_target_id
    and status = 'pending';
  get diagnostics v_rows = row_count;

  if v_rows = 0 then
    return query select false, 'Request not found'::text;
    return;
  end if;

  return query select true, 'Request cancelled'::text;
end;
$function$;

create or replace function public.list_sent_friend_requests()
returns table(
  id uuid,
  to_user_id uuid,
  to_user_name text,
  created_at timestamp with time zone
)
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return;
  end if;

  return query
  select
    fr.id,
    fr.to_user_id,
    coalesce(nullif(btrim(p.display_name), ''), 'Yarîzan'),
    fr.created_at
  from public.friend_requests fr
  left join public.profiles p on p.id = fr.to_user_id
  where fr.from_user_id = v_uid
    and fr.status = 'pending'
  order by fr.created_at desc;
end;
$function$;

revoke all on function public.remove_friend(uuid) from public, anon;
revoke all on function public.cancel_friend_request(uuid) from public, anon;
revoke all on function public.list_sent_friend_requests() from public, anon;
grant execute on function public.remove_friend(uuid) to authenticated, service_role;
grant execute on function public.cancel_friend_request(uuid) to authenticated, service_role;
grant execute on function public.list_sent_friend_requests() to authenticated, service_role;

-- ---------------------------------------------------------------------
-- 7) add_friend: karşılıklı istek, profil denetimi, hız sınırı
-- ---------------------------------------------------------------------
--   * Karşı taraf bana ZATEN bekleyen istek göndermişse yeni satır açma:
--     o isteği kabul et (iki yön friends satırı, accept_friend_request ile
--     aynı kimlik kaynağı = profiller). Eskiden iki bekleyen satır doğuyor,
--     iki taraf da "kabul"e basmak zorunda kalıyordu.
--   * Hedef profil yoksa 'Friend not found' (istemci false = genel hata
--     metni gösterir; FK ihlali yerine temiz ret).
--   * 24 saatte en çok 30 yeni istek: 'Too many friend requests'.
--   * Reddedilmiş/iptal edilmiş isteğin aynı kişiye 1 saat içinde yeniden
--     gönderilmesi 'Friend request cooldown' (8. bölümdeki yeniden-gönder
--     bildirimi taciz aracına dönmesin).

create or replace function public.add_friend(
  p_friend_id uuid,
  p_friend_name text
)
returns table(success boolean, message text)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid;
  v_display_name text;
  v_friend_display_name text;
  v_rows int;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return query select false, 'Authenticated user required'::text;
    return;
  end if;

  if v_user_id = p_friend_id then
    return query select false, 'Cannot add yourself as friend'::text;
    return;
  end if;

  -- Engelleme (2026-10-02 M5): iki yönden biri engelliyse istek gitmez.
  -- Mesaj genel tutuldu; engellenen kişi engellendiğini anlamasın.
  if exists (
    select 1 from blocked_users b
    where (b.blocker_id = v_user_id and b.blocked_id = p_friend_id)
       or (b.blocker_id = p_friend_id and b.blocked_id = v_user_id)
  ) then
    return query select false, 'Friend request blocked'::text;
    return;
  end if;

  -- Hedef profil gerçekten var mı (2026-10-15).
  select display_name into v_friend_display_name
  from profiles where id = p_friend_id;
  if not found then
    return query select false, 'Friend not found'::text;
    return;
  end if;

  if exists (
    select 1 from friends
    where (user_id = v_user_id and friend_id = p_friend_id)
       or (user_id = p_friend_id and friend_id = v_user_id)
  ) then
    return query select false, 'Already friends'::text;
    return;
  end if;

  -- Kimlik yalnız sunucudan. `p_friend_name` bilerek kullanılmıyor:
  -- istemciden gelen ad başka birinin adı olabilir. İmza, çağıran
  -- istemciler kırılmasın diye korundu.
  select display_name into v_display_name from profiles where id = v_user_id;

  -- Karşı taraf bana zaten bekleyen istek göndermiş: kabul et, ikinci
  -- bekleyen satır açma.
  if exists (
    select 1 from friend_requests
    where from_user_id = p_friend_id
      and to_user_id = v_user_id
      and status = 'pending'
  ) then
    insert into friends (user_id, friend_id, friend_name)
    values
      (v_user_id, p_friend_id,
       coalesce(nullif(btrim(v_friend_display_name), ''), 'Yarîzan')),
      (p_friend_id, v_user_id,
       coalesce(nullif(btrim(v_display_name), ''), 'Yarîzan'))
    on conflict do nothing;

    update friend_requests
    set status = 'accepted'
    where status = 'pending'
      and ((from_user_id = p_friend_id and to_user_id = v_user_id)
        or (from_user_id = v_user_id and to_user_id = p_friend_id));

    return query select true, 'Friend request accepted'::text;
    return;
  end if;

  if exists (
    select 1 from friend_requests
    where from_user_id = v_user_id
      and to_user_id = p_friend_id
      and status = 'pending'
  ) then
    return query select false, 'Friend request already pending'::text;
    return;
  end if;

  -- Hız sınırı: son 24 saatte açılmış/yenilenmiş en çok 30 istek.
  if (
    select count(*) from friend_requests
    where from_user_id = v_user_id
      and created_at > now() - interval '24 hours'
  ) >= 30 then
    return query select false, 'Too many friend requests'::text;
    return;
  end if;

  -- Reddedilmiş/iptal edilmiş isteği hemen yeniden göndermek yok.
  if exists (
    select 1 from friend_requests
    where from_user_id = v_user_id
      and to_user_id = p_friend_id
      and created_at > now() - interval '1 hour'
  ) then
    return query select false, 'Friend request cooldown'::text;
    return;
  end if;

  insert into friend_requests (from_user_id, from_user_name, to_user_id, status)
  values (
    v_user_id,
    coalesce(nullif(btrim(v_display_name), ''), 'Yarîzan'),
    p_friend_id,
    'pending'
  )
  on conflict (from_user_id, to_user_id) do update
     set status = 'pending',
         from_user_name = excluded.from_user_name,
         created_at = now()
   where friend_requests.status is distinct from 'pending';

  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    -- Gerçekten hiçbir şey yazılmadı. Eskiden burada da TRUE dönülüyordu.
    return query select false, 'Friend request already pending'::text;
    return;
  end if;

  return query select true, 'Friend request sent'::text;
end;
$function$;

-- ---------------------------------------------------------------------
-- 8) Yeniden gönderilen istek de bildirim üretsin
-- ---------------------------------------------------------------------
-- `trg_friend_request_push` yalnız AFTER INSERT'tir. Reddedilen/iptal edilen
-- isteğin yeniden gönderilmesi ON CONFLICT ... DO UPDATE yolundan geçer, yani
-- INSERT tetikleyicisi ateşlenmez ve alıcıya bildirim kuyruklanmaz. INSERT
-- tetikleyicisinin WHEN koşulu OLD'a bakamadığı için ikinci bir UPDATE
-- tetikleyicisi eklenir; aynı işlev, aynı kuyruk satırı.

drop trigger if exists trg_friend_request_push_resend on public.friend_requests;
create trigger trg_friend_request_push_resend
  after update of status on public.friend_requests
  for each row
  when (old.status is distinct from 'pending' and new.status = 'pending')
  execute function public.enqueue_friend_request_push();

-- ---------------------------------------------------------------------
-- 9) FCM token sahipliği
-- ---------------------------------------------------------------------
-- Aynı cihaz farklı bir hesaba geçince token iki profilde birden duruyor,
-- bildirim yeni sahibe değil de eski hesaba da gidiyordu. set_fcm_token artık
-- aynı token'ı başka profillerden siler; çıkışta çağrılan
-- clear_my_fcm_token() cihazın token'ını bırakır. 4096 karakter üst sınırı
-- (FCM token'ları ~150-200 karakter; canlı en uzun 142).

create or replace function public.set_fcm_token(p_token text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_token text;
begin
  if v_uid is null then return; end if;
  if p_token is null or length(trim(p_token)) = 0 then
    update public.profiles set fcm_token = null where id = v_uid;
    return;
  end if;
  v_token := trim(p_token);
  -- Aşırı uzun değer token değildir; CHECK'e çarpıp hata vermek yerine yok say.
  if char_length(v_token) > 4096 then return; end if;

  -- Token'ın tek sahibi çağıran olur.
  update public.profiles
  set fcm_token = null
  where fcm_token = v_token and id <> v_uid;

  update public.profiles set fcm_token = v_token where id = v_uid;
end;
$function$;

create or replace function public.clear_my_fcm_token()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is null then return; end if;
  update public.profiles set fcm_token = null where id = auth.uid();
end;
$function$;

revoke all on function public.clear_my_fcm_token() from public, anon;
grant execute on function public.clear_my_fcm_token() to authenticated, service_role;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_fcm_token_len'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_fcm_token_len
      check (char_length(fcm_token) <= 4096) not valid;
  end if;
end $$;
alter table public.profiles validate constraint profiles_fcm_token_len;

-- ---------------------------------------------------------------------
-- 10) Davet ödülü sömürüsü
-- ---------------------------------------------------------------------
--   * Davet eden başına ömür boyu 10 ödül ('limit_reached'): sınırsız hesap
--     açtırıp coin biriktirmek kapanır. Davet edenin satırı zaten FOR UPDATE
--     kilitli olduğundan sayım yarışa karşı güvenli.
--   * Kodu kullanan hesabın en az bir tamamlanmış oda ya da tek kişilik tur
--     ödülü olmalı ('not_active'): hiç oynamamış hesap ödül alamaz.
--     Kanıt: coin_transactions'ta solo_round / quiz_complete:* kaydı ya da
--     ended_reason='completed' bir odada oyuncu satırı.

create or replace function public.redeem_referral_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid;
  v_clean_code text;
  v_referrer record;
  v_caller record;
  v_rows integer;
  v_reward_amount constant integer := 100;
  v_referrer_cap constant integer := 10;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'unauthenticated';
  end if;

  -- Misafir (anonymous identity) veya kimliği olmayan oturum ödül alamaz.
  -- `auth.users.is_anonymous` sürümden sürüme yok; identities yeter.
  if not exists (
       select 1
       from auth.identities i
       where i.user_id = v_user_id
         and i.provider is distinct from 'anonymous'
     )
  then
    return jsonb_build_object(
      'success', false,
      'error', 'not_verified',
      'message', 'Referral requires a verified account'
    );
  end if;

  v_clean_code := upper(trim(p_code));
  if v_clean_code = '' then
    raise exception 'invalid_code';
  end if;

  -- Satır kilidi: aynı kullanıcının eşzamanlı iki çağrısını sıraya koyar.
  select id, referred_by, player_tag
  into v_caller
  from public.profiles
  where id = v_user_id
  for update;

  if not found then
    raise exception 'profile_not_found';
  end if;

  if v_caller.referred_by is not null
     or exists (
       select 1 from public.referral_redemptions rr
       where rr.user_id = v_user_id
     )
  then
    return jsonb_build_object(
      'success', false,
      'error', 'already_redeemed',
      'message', 'Referral code already used'
    );
  end if;

  select id, display_name, player_tag
  into v_referrer
  from public.profiles
  where player_tag = v_clean_code
     or player_tag = 'ZK-' || v_clean_code
     or replace(player_tag, 'ZK-', '') = v_clean_code
  limit 1
  for update;

  if not found then
    return jsonb_build_object(
      'success', false,
      'error', 'code_not_found',
      'message', 'Invalid referral code'
    );
  end if;

  if v_referrer.id = v_user_id then
    return jsonb_build_object(
      'success', false,
      'error', 'own_code',
      'message', 'Cannot use own code'
    );
  end if;

  -- Davet eden başına ömür boyu ödül sınırı.
  if (
    select count(*) from public.referral_redemptions rr
    where rr.referrer_id = v_referrer.id
  ) >= v_referrer_cap then
    return jsonb_build_object(
      'success', false,
      'error', 'limit_reached',
      'message', 'Referral limit reached'
    );
  end if;

  -- Kodu kullanan hesap hiç oynamış olmalı.
  if not exists (
       select 1 from public.coin_transactions ct
       where ct.player_id = v_user_id
         and (ct.reason = 'solo_round' or ct.reason like 'quiz_complete:%')
     )
     and not exists (
       select 1
       from public.room_players rp
       join public.rooms r on r.id = rp.room_id
       where rp.player_id = v_user_id
         and r.status = 'finished'
         and r.ended_reason = 'completed'
     )
  then
    return jsonb_build_object(
      'success', false,
      'error', 'not_active',
      'message', 'Play a round before using a referral code'
    );
  end if;

  -- Ödülün gerçek kapısı: PK çakışırsa ikinci ödül verilmez.
  insert into public.referral_redemptions (user_id, referrer_id)
  values (v_user_id, v_referrer.id)
  on conflict (user_id) do nothing;

  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    return jsonb_build_object(
      'success', false,
      'error', 'already_redeemed',
      'message', 'Referral code already used'
    );
  end if;

  update public.profiles
  set referred_by = v_referrer.id,
      updated_at = now()
  where id = v_user_id;

  insert into public.coin_transactions (player_id, amount, reason)
  values
    (v_user_id, v_reward_amount, 'referral_welcome'),
    (v_referrer.id, v_reward_amount, 'referral_invite');

  return jsonb_build_object(
    'success', true,
    'coins_awarded', v_reward_amount,
    'referrer_name', coalesce(v_referrer.display_name, 'Heval')
  );
end;
$function$;

-- ---------------------------------------------------------------------
-- 11) Sınırsız girdi
-- ---------------------------------------------------------------------
-- suggested_questions: soru metni 500, her şık 200, açıklama 1000 karakter.
-- (Canlıda tablo boş; NOT VALID + VALIDATE yine de kilit süresini kısa tutar.)
-- log_analytics_event: olay adı ≤ 64 karakter, parametreler ≤ 4096 bayt;
-- aşan çağrı hata verir (istemci analitiği yutar, kullanıcıya yansımaz).

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'suggested_questions_prompt_len'
      and conrelid = 'public.suggested_questions'::regclass
  ) then
    alter table public.suggested_questions
      add constraint suggested_questions_prompt_len
      check (char_length(prompt) <= 500) not valid;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'suggested_questions_options_len'
      and conrelid = 'public.suggested_questions'::regclass
  ) then
    alter table public.suggested_questions
      add constraint suggested_questions_options_len
      check (
        char_length(option_a) <= 200
        and char_length(option_b) <= 200
        and char_length(option_c) <= 200
        and char_length(option_d) <= 200
      ) not valid;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'suggested_questions_explanation_len'
      and conrelid = 'public.suggested_questions'::regclass
  ) then
    alter table public.suggested_questions
      add constraint suggested_questions_explanation_len
      check (char_length(explanation) <= 1000) not valid;
  end if;
end $$;

alter table public.suggested_questions
  validate constraint suggested_questions_prompt_len;
alter table public.suggested_questions
  validate constraint suggested_questions_options_len;
alter table public.suggested_questions
  validate constraint suggested_questions_explanation_len;

create or replace function public.log_analytics_event(
  p_event_name text,
  p_event_params jsonb default null::jsonb
)
returns table(success boolean, message text)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid;
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

  insert into analytics_events (user_id, event_name, event_params)
  values (v_user_id, p_event_name, p_event_params);

  return query select true, 'Event logged'::text;
end;
$function$;

-- ---------------------------------------------------------------------
-- 12) Sırayla düello: devam, sınır, geri çekme
-- ---------------------------------------------------------------------
-- (a) resume_my_async_duel(p_duel_id): yarım bırakılan düelloya (yaratıcı ya
--     da rakip olarak) kaldığı sorudan devam. Yanıt biçimi
--     accept_async_duel_challenge'ın yeniden-açılış yanıtıyla aynı
--     (questions + answered + finished); süre sunucuda ölçüldüğünden
--     (answer_async_duel) geç dönmek avantaj sağlamaz.
-- (b) Açık-düello sınırı (5) süresi dolmuş ama henüz süpürülmemiş
--     (expire_async_duels henüz çalışmamış) düelloları saymaz. start_async_duel
--     ve create_async_duel_challenge'da aynı sayım.
-- (c) cancel_my_async_duel(p_duel_id): kimsenin katılmadığı kendi açık
--     düellomu geri çek. Düello silinmez, 'expired' olur ve sınırdan düşer
--     (cevaplar ve sonuçlar korunur; XP talebi doğal süre dolumuyla aynı).
--     Ücretli giriş yok (async_duels'ta ücret sütunu yok), iade gerekmez.

create or replace function public.resume_my_async_duel(p_duel_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_duel public.async_duels%rowtype;
  v_other_name text;
  v_invited_name text;
  v_answered integer;
  v_finished boolean;
  v_is_creator boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_duel
  from public.async_duels
  where id = p_duel_id;

  if not found or (v_duel.creator_id <> v_uid
                   and v_duel.opponent_id is distinct from v_uid) then
    raise exception 'Duel not found';
  end if;

  if v_duel.status = 'expired'
     or (v_duel.status <> 'completed' and now() > v_duel.expires_at) then
    raise exception 'Duel expired';
  end if;

  v_is_creator := (v_duel.creator_id = v_uid);

  select p.display_name into v_other_name
  from public.profiles p
  where p.id = case when v_is_creator then v_duel.opponent_id
                    else v_duel.creator_id end;

  if v_is_creator and v_duel.invited_id is not null then
    select p.display_name into v_invited_name
    from public.profiles p
    where p.id = v_duel.invited_id;
  end if;

  select count(*)::integer into v_answered
  from public.async_duel_answers a
  where a.duel_id = v_duel.id and a.player_id = v_uid;

  select exists (
    select 1 from public.async_duel_results r
    where r.duel_id = v_duel.id and r.player_id = v_uid
  ) into v_finished;

  return jsonb_build_object(
    'duel_id', v_duel.id,
    'role', case when v_is_creator then 'creator' else 'opponent' end,
    'opponent_name', v_other_name,
    'expires_at', v_duel.expires_at,
    'questions', public.async_duel_questions_payload(v_duel.question_ids),
    'answered', v_answered,
    'finished', v_finished,
    'challenge_code', case when v_is_creator then v_duel.challenge_code
                           else null end,
    'invited_name', v_invited_name
  );
end;
$function$;

create or replace function public.cancel_my_async_duel(p_duel_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_duel public.async_duels%rowtype;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_duel
  from public.async_duels
  where id = p_duel_id
  for update;

  if not found or v_duel.creator_id <> v_uid then
    raise exception 'Duel not found';
  end if;

  -- Yalnız kimsenin almadığı açık düello geri çekilir.
  if v_duel.opponent_id is not null or v_duel.status <> 'open' then
    raise exception 'Duel not cancellable';
  end if;

  update public.async_duels
  set status = 'expired',
      expires_at = least(expires_at, now())
  where id = p_duel_id;

  return true;
end;
$function$;

revoke all on function public.resume_my_async_duel(uuid) from public, anon;
revoke all on function public.cancel_my_async_duel(uuid) from public, anon;
grant execute on function public.resume_my_async_duel(uuid) to authenticated, service_role;
grant execute on function public.cancel_my_async_duel(uuid) to authenticated, service_role;

-- start_async_duel: canlı gövde birebir; tek fark açık-düello sayımındaki
-- `expires_at > now()`.
create or replace function public.start_async_duel(p_category text default null::text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_category_input text;
  v_category_id uuid;
  v_duel public.async_duels%rowtype;
  v_open_count integer;
  v_question_ids uuid[];
  v_question_count integer;
  v_role text;
  v_opponent_name text;
  v_questions jsonb;
  v_duel_id uuid;
  v_expires_at timestamptz;
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

  -- Aynı oyuncunun ağ tekrarı/çift dokunuşunu sıraya koyar; iki farklı
  -- oyuncu arasındaki eşleşme satır kilidiyle (aşağıda FOR UPDATE SKIP
  -- LOCKED) zaten güvenli.
  perform pg_advisory_xact_lock(hashtextextended('async-duel:' || v_uid::text, 0));

  select d.* into v_duel
  from public.async_duels d
  where d.status = 'open'
    and d.creator_id <> v_uid
    and d.invited_id is null
    -- Bağlantı/arkadaş meydan okumaları (2026-10-13_friend_challenge.sql)
    -- rastgele eşleşmeye ASLA girmez.
    and d.challenge_code is null
    and d.expires_at > now()
    -- Engelleme (2026-10-02 M5): aramızda iki yönden biri engelliyse bu
    -- düelloya eşleşmem (hata yok, sıradaki uygun düelloya bakılır;
    -- join_matchmaking ile aynı davranış).
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = v_uid and b.blocked_id = d.creator_id)
         or (b.blocker_id = d.creator_id and b.blocked_id = v_uid)
    )
    and (v_category_id is null or d.category_id = v_category_id)
    -- Yalnız açanın kendi turunu BİTİRDİĞİ düellolar eşleşir. Aksi hâlde
    -- ikinci oyuncu 7 soruyu oynar ama sonuç yerine "bekleniyor" görürdü;
    -- tasarımın vaadi, ikinci oyuncunun sonucu hemen görmesidir. Turunu
    -- yarıda bırakan açanın düellosu eşleşmez, 48 saatte süresi dolar.
    and exists (
      select 1
      from public.async_duel_results r
      where r.duel_id = d.id
        and r.player_id = d.creator_id
    )
  order by d.created_at asc
  limit 1
  for update skip locked;

  if found then
    -- Rakibe kendi 48 saati verilir: açık düellonun süresi açanın
    -- penceresiydi; 47. saatte eşleşen biri oynarken "Duel expired"
    -- alırdı.
    update public.async_duels
    set opponent_id = v_uid,
        status = 'matched',
        matched_at = now(),
        expires_at = greatest(expires_at, now() + interval '48 hours')
    where id = v_duel.id
    returning expires_at into v_expires_at;

    v_duel_id := v_duel.id;
    v_question_ids := v_duel.question_ids;
    v_role := 'opponent';

    select p.display_name into v_opponent_name
    from public.profiles p
    where p.id = v_duel.creator_id;
  else
    -- Süresi dolmuş ama henüz süpürülmemiş düellolar sayılmaz (2026-10-15).
    select count(*) into v_open_count
    from public.async_duels
    where creator_id = v_uid
      and status = 'open'
      and expires_at > now();

    if v_open_count >= 5 then
      raise exception 'Too many open duels';
    end if;

    -- `rnd` bir kez hesaplanır (SELECT listesinde); ORDER BY onu yeniden
    -- ÇAĞIRMAZ, aynı değeri kullanır — seçilen 7 soru ile array_agg'in
    -- verdiği sıra böylece birebir aynı kalır (index 0..6 bu sırayla).
    --
    -- Düello sorusu istemcide ATLANAMAZ: 7 soru iki oyuncuya aynı sırayla
    -- gider, cevaplar index'le eşleşir. Oda akışında istemci oynanamaz bir
    -- soruyu listeden düşürebiliyor (QuestionContentPolicy
    -- .isPlayableWithHiddenAnswer); düelloda düşürse index kayardı. Aynı
    -- süzgeç bu yüzden burada, seçimden ÖNCE uygulanır:
    --   * gizli kategoriler: lib/src/config/category_visibility.dart
    --     `hiddenCategoryIds` ile birebir aynı liste (bekçi:
    --     test/async_duel_sql_contract_test.dart);
    --   * yalnız metin soruları: görsel soruda 20 saniyelik sayaç görsel
    --     yüklenirken işler, yavaş bağlantıdaki oyuncu haksız yere kaybeder;
    --   * şıkları eksiksiz sorular: istemci boş şıkkı listeden çıkarır,
    --     aradaki bir boşluk A-D harf eşlemesini kaydırırdı;
    --   * doğru şıkkı geçerli sorular: answer_async_duel correct_option'ı
    --     cevapla ham karşılaştırır; 'a' ya da NULL taşıyan soru kimseye
    --     doğru yazdırmazdı.
    select array_agg(picked.id order by picked.rnd) into v_question_ids
    from (
      select q.id, random() as rnd
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
      order by rnd
      limit 7
    ) picked;

    v_question_count := coalesce(array_length(v_question_ids, 1), 0);
    if v_question_count < 7 then
      raise exception 'No questions';
    end if;

    insert into public.async_duels (
      category_id, question_ids, creator_id, status
    ) values (
      v_category_id, v_question_ids, v_uid, 'open'
    )
    returning id, expires_at into v_duel_id, v_expires_at;

    v_role := 'creator';
    v_opponent_name := null;
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'index', ord.idx - 1,
      'id', q.id,
      'category_name', coalesce(c.name, 'Ziman'),
      'prompt', q.prompt,
      'option_a', q.option_a,
      'option_b', q.option_b,
      'option_c', q.option_c,
      'option_d', q.option_d,
      'question_type', q.question_type,
      'image_url', q.image_url,
      'difficulty', q.difficulty
    ) order by ord.idx
  )
  into v_questions
  from unnest(v_question_ids) with ordinality as ord(question_id, idx)
  join public.questions q on q.id = ord.question_id
  left join public.categories c on c.id = q.category_id;

  return jsonb_build_object(
    'duel_id', v_duel_id,
    'role', v_role,
    'opponent_name', v_opponent_name,
    'expires_at', v_expires_at,
    'questions', coalesce(v_questions, '[]'::jsonb)
  );
end;
$function$;

-- create_async_duel_challenge: canlı gövde birebir; tek fark aynı sayım.
create or replace function public.create_async_duel_challenge(
  p_category text default null::text,
  p_friend_id uuid default null::uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
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

  -- Davet edilecek kişi: KABUL EDİLMİŞ arkadaş (friends tablosunda iki
  -- satır tutulur, benim satırım yeter) ve iki yönde de engelsiz. Engel,
  -- 2026-10-02_blocking_enforcement.sql ile aynı ilkeyle ifşa edilmez:
  -- engelli de arkadaş değil gibi 'Not a friend' alır.
  if p_friend_id is not null then
    if p_friend_id = v_uid
       or not exists (
         select 1 from public.friends f
         where f.user_id = v_uid and f.friend_id = p_friend_id
       )
       or exists (
         select 1 from public.blocked_users b
         where (b.blocker_id = v_uid and b.blocked_id = p_friend_id)
            or (b.blocker_id = p_friend_id and b.blocked_id = v_uid)
       ) then
      raise exception 'Not a friend';
    end if;

    select p.display_name into v_invited_name
    from public.profiles p
    where p.id = p_friend_id;
  end if;

  -- start_async_duel ile AYNI advisory kilit: ikisinin açık-düello sayımı
  -- aynı oyuncu için sıraya girer (çift dokunuş / iki RPC yarışı 5 sınırını
  -- aşamasın).
  perform pg_advisory_xact_lock(hashtextextended('async-duel:' || v_uid::text, 0));

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
  select array_agg(picked.id order by picked.rnd) into v_question_ids
  from (
    select q.id, random() as rnd
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
    order by rnd
    limit 7
  ) picked;

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
        category_id, question_ids, creator_id, invited_id, challenge_code, status
      ) values (
        v_category_id, v_question_ids, v_uid, p_friend_id, v_code, 'open'
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
    'invited_name', v_invited_name
  );
end;
$function$;

-- ---------------------------------------------------------------------
-- Doğrulama bloğu: tek bir koşul tutmazsa göç geri alınır.
-- ---------------------------------------------------------------------
do $$
declare
  v_fn text;
  v_def text;
begin
  -- MAINTAIN hiçbir public tabloda istemci rollerinde kalmadı.
  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
      and (has_table_privilege('anon', c.oid, 'MAINTAIN')
           or has_table_privilege('authenticated', c.oid, 'MAINTAIN'))
  ) then
    raise exception 'sosyal_sertlestirme: MAINTAIN hâlâ açık';
  end if;

  if to_regclass('public.quiz_public_questions') is not null then
    raise exception 'sosyal_sertlestirme: quiz_public_questions silinmedi';
  end if;

  -- Yeni RPC'ler: authenticated'a açık, anon'a kapalı.
  foreach v_fn in array array[
    'public.remove_friend(uuid)',
    'public.cancel_friend_request(uuid)',
    'public.list_sent_friend_requests()',
    'public.clear_my_fcm_token()',
    'public.resume_my_async_duel(uuid)',
    'public.cancel_my_async_duel(uuid)'
  ] loop
    if has_function_privilege('anon', v_fn::regprocedure, 'execute') then
      raise exception 'sosyal_sertlestirme: % anon''a açık', v_fn;
    end if;
    if not has_function_privilege('authenticated', v_fn::regprocedure, 'execute') then
      raise exception 'sosyal_sertlestirme: % authenticated''a kapalı', v_fn;
    end if;
  end loop;

  -- İç yardımcı istemciye kapalı.
  if has_function_privilege('anon', 'public.sever_social_ties(uuid,uuid)'::regprocedure, 'execute')
     or has_function_privilege('authenticated', 'public.sever_social_ties(uuid,uuid)'::regprocedure, 'execute') then
    raise exception 'sosyal_sertlestirme: sever_social_ties istemciye açık';
  end if;

  -- Değiştirilen fonksiyonlar anon'a AÇILMADI (CREATE OR REPLACE ACL'yi korur).
  foreach v_fn in array array[
    'public.get_leaderboard(integer,integer)',
    'public.get_my_leaderboard_rank(integer)',
    'public.block_player(uuid)',
    'public.report_player_profile(uuid,text)',
    'public.add_friend(uuid,text)',
    'public.set_fcm_token(text)',
    'public.redeem_referral_code(text)',
    'public.log_analytics_event(text,jsonb)',
    'public.start_async_duel(text)',
    'public.create_async_duel_challenge(text,uuid)',
    'public.advance_tournament(uuid)'
  ] loop
    if has_function_privilege('anon', v_fn::regprocedure, 'execute') then
      raise exception 'sosyal_sertlestirme: % anon''a açık', v_fn;
    end if;
  end loop;

  v_def := pg_get_functiondef('public.get_leaderboard(integer,integer)'::regprocedure);
  if v_def not like '%ended_reason%' or v_def not like '%rp.player_id asc%' then
    raise exception 'sosyal_sertlestirme: get_leaderboard süzgeç/bağ kırıcı taşımıyor';
  end if;
  v_def := pg_get_functiondef('public.get_my_leaderboard_rank(integer)'::regprocedure);
  if v_def not like '%ended_reason%' or v_def not like '%b.player_id asc%' then
    raise exception 'sosyal_sertlestirme: get_my_leaderboard_rank süzgeç/bağ kırıcı taşımıyor';
  end if;

  v_def := pg_get_functiondef('public.advance_tournament(uuid)'::regprocedure);
  if v_def not like '%status = ''finished''%' then
    raise exception 'sosyal_sertlestirme: advance_tournament bitmiş turnuva korumasız';
  end if;

  v_def := pg_get_functiondef('public.block_player(uuid)'::regprocedure);
  if v_def not like '%sever_social_ties%' then
    raise exception 'sosyal_sertlestirme: block_player ilişkileri temizlemiyor';
  end if;
  v_def := pg_get_functiondef('public.report_player_profile(uuid,text)'::regprocedure);
  if v_def not like '%sever_social_ties%' then
    raise exception 'sosyal_sertlestirme: report_player_profile ilişkileri temizlemiyor';
  end if;

  v_def := pg_get_functiondef('public.add_friend(uuid,text)'::regprocedure);
  if v_def not like '%Too many friend requests%'
     or v_def not like '%Friend not found%'
     or v_def not like '%Friend request accepted%' then
    raise exception 'sosyal_sertlestirme: add_friend yeni dalları taşımıyor';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgname = 'trg_friend_request_push_resend' and not tgisinternal
  ) then
    raise exception 'sosyal_sertlestirme: yeniden-gönder tetikleyicisi yok';
  end if;

  v_def := pg_get_functiondef('public.set_fcm_token(text)'::regprocedure);
  if v_def not like '%id <> v_uid%' then
    raise exception 'sosyal_sertlestirme: set_fcm_token token sahipliğini devretmiyor';
  end if;

  v_def := pg_get_functiondef('public.redeem_referral_code(text)'::regprocedure);
  if v_def not like '%limit_reached%' or v_def not like '%not_active%' then
    raise exception 'sosyal_sertlestirme: redeem_referral_code sınırları taşımıyor';
  end if;

  v_def := pg_get_functiondef('public.log_analytics_event(text,jsonb)'::regprocedure);
  if v_def not like '%event_name_too_long%' or v_def not like '%event_params_too_large%' then
    raise exception 'sosyal_sertlestirme: log_analytics_event boyut sınırı taşımıyor';
  end if;

  foreach v_fn in array array[
    'public.start_async_duel(text)',
    'public.create_async_duel_challenge(text,uuid)'
  ] loop
    v_def := pg_get_functiondef(v_fn::regprocedure);
    if v_def not like '%expires_at > now()%' or v_def not like '%Too many open duels%' then
      raise exception 'sosyal_sertlestirme: % açık-düello sayımı süresi dolanı saymıyor', v_fn;
    end if;
  end loop;

  -- CHECK kısıtları var ve doğrulanmış.
  if (
    select count(*) from pg_constraint
    where conname in (
      'profiles_fcm_token_len',
      'suggested_questions_prompt_len',
      'suggested_questions_options_len',
      'suggested_questions_explanation_len'
    ) and convalidated
  ) <> 4 then
    raise exception 'sosyal_sertlestirme: CHECK kısıtları eksik ya da doğrulanmamış';
  end if;
end $$;

commit;
