-- 2.1.2 W1: sunucu güvenliği / ödül / moderasyon (ChatGPT Pro denetimi alan 1, 2, 4 SQL
-- bulguları; her biri güncel kodda doğrulandı). CANLIYA UYGULANMADI.
-- Geri alma: geri_al/2026-11-16_w1_odul_moderasyon_geri.sql
-- Yerel test: node tool/test_w1_odul_moderasyon_local.mjs <pglite index.js>
--
-- Taban (canlı ✅): her işlevin canlı gövdesi, applied.md ✅ satırlarının sırasıyla
-- bulunan SON tanımdır. TAM gövdenin md5'i bilinen tabana eşitse yamalanır (başka her
-- durumda göç durur); eski gövde ve md5'i olcek_tur3_yedek'e ('w1:<imza>') alınır.
-- Eski istemci (build 45) sözleşmesi: hiçbir mevcut RPC'nin imzası ya da dönüş biçimi
-- değişmez; davranış farkı yalnız hileyi kapatır. Yeni nesneler: 2 sütun, 1 indeks,
-- admin_reward_contributor/4 bağımsız değişkenli aşırı yüklemesi, turnuva kısıtlı
-- tetikleyicisi (hepsi eklemeli).
--
-- BULGULAR (ALAN 1)
--  #2  claim_verified_solo_reward: p_limit=1 ya da hepsi boş/yanlış turdan taban 4 jeton
--      veriyordu (4 + doğru + seri). Artık: en az 5 soru (ilk oturum 5 soruluk), en az
--      1 doğru, toplam süre >= soru sayısı saniye; aksi hâlde 0 jeton ('not_eligible').
--      Sonuç reward_result'a yazılır (tekrar çağrı aynı yanıtı verir).
--  #11 redeem_referral_code: kanıt olarak aranan coin_transactions 'solo_round' kaydı
--      artık yalnız yukarıdaki koşulu geçen turlardan doğar; boş turla davet ödülü kapanır.
--      Kısıtlı çağıran ya da kısıtlı davet eden ödül akışına giremez.
--  #1  claim_share_reward: paylaşımın kendisi sunucuda doğrulanamaz (işletim sistemi
--      paylaşım sayfası). Günlük tek 25 jeton artık o gün DOĞRULANMIŞ bir oyun etkinliğine
--      bağlı: en az 5 soruluk ve >=1 doğrulu doğrulanmış tur, solo/oda ödülü kaydı ya da
--      bitmiş bir düello. Doğrudan RPC'yle boş hesap günde 25 jeton alamaz.
--  #5  Kısıtlı hesap: solo ödülü, paylaşım ödülü, davet ödülü, haftalık lig ve turnuva
--      katılımı artık user_is_restricted'a bakar (turnuva: tournament_entries BEFORE INSERT
--      tetikleyicisi, tek merkezî kapı). Oda üyeliği/düello/sohbet 11-13 göçünde vardı.
--  #6  admin_reward_contributor: kalıcı request_id + benzersiz indeks; aynı istek tekrar
--      gelirse ikinci ödeme yok. 3 bağımsız değişkenli eski imza 10 dk'lık dilimden türeyen
--      belirleyici kimlikle aynı korumayı alır.
--  #7  spend_coins_once: aynı anahtar farklı tutar/neden ile gelirse 'idempotency_key_mismatch'.
--  #10 record_activity(true): kullanıcı başına günde en çok 30 solo sayacı artışı.
--  ATLANAN: #8 (mission_completions'ı okuyan YOK: ne bakiye ne XP ne arayüz; salt kayıt),
--      #9 (aynı kayıt, istemci yanıtı yok sayar), #12 (create_async_duel_challenge /
--      start_async_duel sarmalayıcıları W2'nin soru-kimliği gizleme göçüyle AYNI gövdeleri
--      yamalıyor; çakışma olmasın diye oraya bırakıldı), #3/#4 W2.
-- ALAN 2: #8 turnuva (tetikleyici + admin_moderate_user açık turnuva kaydını siler),
--      #10 get_my_league (kısıtlı atanmaz/listelenmez), #11 ack_my_league_result (yalnız
--      GÖSTERİLEN en yeni sonucu kapatır), #12 get_my_league telafi kapanışı cron'dan
--      (00:05) sonra 00:10'da. #1/#2.. istemci/W2/W3.
-- ALAN 4 (SQL): #8 push_delivery_v2_allowed claim anında arkadaşlık isteği 'pending' /
--      kabul 'accepted' durumunu yeniden denetler (iptal/silinen istek bildirimi gitmez),
--      #14 ana bildirim anahtarı kapalıyken (push_duel ve push_social ikisi de kapalı)
--      yönetici push'u gitmez, #22 yönetici bildirim tercihi kapalıysa / yönetici değilse
--      kuyruktaki iş gönderilmez, #15 admin_enqueue_push hatayı artık WARNING olarak
--      günlüğe yazar (asıl işlem yine bozulmaz). #2 YANLIŞ: arkadaşlık isteği/kabul
--      tetikleyicileri from_user_id'yi 10-24 sunucu sertleştirmesinden beri dolduruyor
--      (enqueue_friend_request_push/accept, from_user_id = new.from_user_id / new.to_user_id);
--      düello bildirimleri engeli kuyruğa yazarken denetliyor. Atlandı.
begin;

set local lock_timeout = '10s';

do $w1_onkosul$
begin
  if to_regprocedure('public.user_is_restricted(uuid)') is null
     or to_regprocedure('public.claim_verified_solo_reward(uuid)') is null
     or to_regprocedure('public.claim_share_reward()') is null
     or to_regprocedure('public.redeem_referral_code(text)') is null
     or to_regprocedure('public.spend_coins_once(integer,text,text)') is null
     or to_regprocedure('public.record_activity(boolean)') is null
     or to_regprocedure('public.admin_reward_contributor(uuid,integer,text)') is null
     or to_regprocedure('public.admin_moderate_user(uuid,text,integer,text)') is null
     or to_regprocedure('public.admin_assert()') is null
     or to_regprocedure('public.admin_log(text,text,text,jsonb)') is null
     or to_regprocedure('public._admin_credit_coins(uuid,integer,text)') is null
     or to_regprocedure('public.get_my_league()') is null
     or to_regprocedure('public.ack_my_league_result()') is null
     or to_regprocedure('public.push_delivery_v2_allowed(uuid,uuid,text,timestamptz,jsonb)') is null
     or to_regprocedure('public.admin_enqueue_push()') is null
     or to_regclass('public.olcek_tur3_yedek') is null
     or to_regclass('public.usage_daily_active') is null
     or to_regclass('public.admin_contributor_rewards') is null
     or to_regclass('public.tournament_entries') is null
     or to_regclass('public.tournaments') is null
     or to_regclass('public.friend_requests') is null
     or to_regclass('public.admins') is null
     or to_regclass('public.admin_notify_prefs') is null
     or to_regclass('public.async_duel_results') is null
     or to_regclass('public.verified_quiz_sessions') is null
     or to_regclass('public.idempotent_spends') is null
     or to_regclass('public.weekly_league_members') is null then
    raise exception 'w1: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
  -- Yedek tablosu istemci rollerine kapalı (geri alma bu satırlardaki gövdeyi
  -- çalıştırır; yazılabilir olması keyfi kod çalıştırmak demektir).
  alter table public.olcek_tur3_yedek enable row level security;
  revoke all on public.olcek_tur3_yedek from public, anon, authenticated;
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'w1: olcek_tur3_yedek anon/authenticated erişimine açık kalıyor';
  end if;
  if exists (
    select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
    where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
      and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
  ) then
    raise exception 'w1: olcek_tur3_yedek sahibi dışında alıcıya açık (relacl)';
  end if;
end;
$w1_onkosul$;

-- Bilinen canlı taban gövdelerinin TAM md5'i (pg_get_functiondef). Yamadan önce gövde
-- ya (a) tam bu taban olmalı -> yamalanır, ya (b) tam nihai md5'te ve yedek satırı + md5
-- zinciri sağlam olmalı -> zaten uygulanmış, atlanır. Başka her durum göçü durdurur.
-- Taban kaynakları: claim_verified_solo_reward 2026-11-01_solo_daily_verified.sql;
-- claim_share_reward 2026-11-01_paylasim_odulu.sql; redeem_referral_code 10-15 gövdesi +
-- 2026-11-06_guvenlik_tur7 yamaları (tur7 nihai md5'i); spend_coins_once 2026-09-22;
-- record_activity / admin_reward_contributor / admin_moderate_user / admin_enqueue_push
-- 2026-11-12_yonetim_paneli.sql; get_my_league 11-05_haftalik_lig + tur5 yaması (tur5 nihai
-- md5'i); ack_my_league_result 11-05_haftalik_lig; push_delivery_v2_allowed 10-31_push_delivery_v2.
create temp table w1_durum (
  imza text primary key, gerekli boolean not null, sahip oid not null, nihai text not null,
  acl text, ayar text[], secdef boolean not null
) on commit drop;
do $w1_durum$
declare
  r record;
  v_def text;
  v_yedek text;
  v_eski text;
begin
  for r in select * from (values
    ('public.claim_verified_solo_reward(uuid)', '59a7f6bd99579a61432a3f130205f365', 'a2a323a59194de777594d1b6bbecfac8'),
    ('public.claim_share_reward()', '25158efdb59ff51916a39c3f47a67a8f', '98723fccd5bb2f0f02cff8b5cba5d28f'),
    ('public.redeem_referral_code(text)', '400c043982e1083382260710293f3126', '0f05b43313c943134f5f5ea72da39849'),
    ('public.spend_coins_once(integer,text,text)', '0510d92fa5d2d86b7817f6c1c0263276', 'a5f795df27c7e85da04151f6debdaee2'),
    ('public.record_activity(boolean)', '213973cf0b805c29f1a96bda2b23d576', '466ceb76c6f4a0d92e9828e97f75748e'),
    ('public.admin_reward_contributor(uuid,integer,text)', 'ef990db65b2d25b97f956ed8536c9b21', '0fc058a09e4f1ccfdec58f82cedbf881'),
    ('public.admin_moderate_user(uuid,text,integer,text)', 'ab0fb04a8936631e77f9d9cc31ec19eb', '08cfef04f7c2b9cc7c6ce2ecac6abb49'),
    ('public.get_my_league()', 'a72570e3764fe2fdc2b79b08d56bb590', '4ba17fd5d02410a0323ae3f2205a3678'),
    ('public.ack_my_league_result()', '97d52b0436d2211d9ff1e8039d176819', 'aff413a44b6316035ce11a52e8934912'),
    ('public.push_delivery_v2_allowed(uuid,uuid,text,timestamptz,jsonb)', '6c76d4b1316d5b132f80b1bed3fff4f5', '6dce80a850953a17eb1fe5e48d98b464'),
    ('public.admin_enqueue_push()', '5cefdc089e4cd5ec2cc2614f8aac083c', '9f85119fe9e6a4d89f2fd9ebb143b2d1')
  ) t(imza, taban, nihai)
  loop
    v_def := pg_get_functiondef(to_regprocedure(r.imza));
    if md5(v_def) = r.taban then
      insert into w1_durum
      select r.imza, true, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
      from pg_proc p where p.oid = to_regprocedure(r.imza);
      continue;
    end if;
    if md5(v_def) <> r.nihai then
      raise exception 'w1: % gövdesi ne bilinen canlı taban ne de bu sürümün nihai gövdesi (md5 %); canlı gövde değişmiş olabilir, elle incele', r.imza, md5(v_def);
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w1:' || r.imza;
    v_eski := regexp_replace(coalesce(v_yedek, ''), E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yedek is null or v_eski = v_yedek
       or md5(v_eski) <> r.taban
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> r.taban
       or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') <> r.nihai then
      raise exception 'w1: % nihai gövdede ama yedek satırı/md5 zinciri sağlam değil; güvenli geri alma yok, elle incele', r.imza;
    end if;
    insert into w1_durum
    select r.imza, false, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
    from pg_proc p where p.oid = to_regprocedure(r.imza);
  end loop;
end;
$w1_durum$;

-- Yamalayıcı (tur7 ile aynı): yeni parça TAM BİR kez var ve yeni parça çıkarıldığında
-- eski parça kalmamışsa uygulanmış sayılır; eski parça TAM BİR kez var ve yeni parça YOK
-- ise yamalanır; başka her durum göçü durdurur. Yamadan önce CANLI gövde yedeğe yazılır
-- (ilk yama ORİJİNALİ yazar; aynı işlevin sonraki yamaları aynı satırı paylaşır).
create or replace function pg_temp.w1_yama(p_imza text, p_eski text, p_yeni text)
returns void language plpgsql as $yama$
declare
  v_oid regprocedure := to_regprocedure(p_imza);
  v_def text;
  v_eski_n integer;
  v_yeni_n integer;
  v_kalan_n integer;
  v_yedek text;
begin
  if v_oid is null then
    raise exception 'w1: işlev yok: %', p_imza;
  end if;
  v_def := pg_get_functiondef(v_oid);
  v_eski_n := (length(v_def) - length(replace(v_def, p_eski, ''))) / length(p_eski);
  v_yeni_n := (length(v_def) - length(replace(v_def, p_yeni, ''))) / length(p_yeni);
  v_kalan_n := (length(replace(v_def, p_yeni, ''))
                - length(replace(replace(v_def, p_yeni, ''), p_eski, ''))) / length(p_eski);
  if v_yeni_n = 1 and v_kalan_n = 0 then
    return; -- zaten uygulanmış
  end if;
  if v_yeni_n <> 0 or v_eski_n <> 1 then
    raise exception 'w1: % için bağlayıcı durumu beklenmiyor (eski % kez, yeni % kez; eski=1/yeni=0 beklenir); canlı gövde değişmiş ya da yarım yamalı, yeniden incele', p_imza, v_eski_n, v_yeni_n;
  end if;
  select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w1:' || p_imza;
  if v_yedek is null
     or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') is distinct from md5(v_def) then
    insert into public.olcek_tur3_yedek (ad, tanim, alindi)
    values ('w1:' || p_imza, v_def || E'\n-- md5:' || md5(v_def), now())
    on conflict (ad) do update set tanim = excluded.tanim, alindi = excluded.alindi;
  end if;
  execute replace(v_def, p_eski, p_yeni);
  update public.olcek_tur3_yedek
  set tanim = regexp_replace(tanim, E'\n-- yama-md5:[0-9a-f]+$', '')
               || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'w1:' || p_imza;
end;
$yama$;

-- ---------------------------------------------------------------------------
-- Yeni (eklemeli) nesneler
-- ---------------------------------------------------------------------------
-- record_activity sayacı için kullanıcı-gün başına solo artış sayısı (#10).
alter table public.usage_daily_active
  add column if not exists solo_n smallint not null default 0;

-- #6: kalıcı istek kimliği. Eski satırlarda NULL; benzersizlik yalnız doluysa.
alter table public.admin_contributor_rewards
  add column if not exists request_id uuid;
create unique index if not exists admin_contributor_rewards_request_uidx
  on public.admin_contributor_rewards (request_id) where request_id is not null;

-- #6: istemci kimliğiyle idempotent katkı ödülü. Aynı kimlik + aynı kullanıcı/tutar =
-- önceki sonuç (ikinci ödeme yok); aynı kimlik farklı kullanıcı/tutar = request_id_conflict.
create or replace function public.admin_reward_contributor(
  p_user_id uuid, p_coins integer, p_note text, p_request_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_prev public.admin_contributor_rewards%rowtype;
begin
  perform public.admin_assert();
  if p_request_id is null then
    raise exception 'bad_request_id' using errcode = '22023';
  end if;
  if p_coins is null or p_coins not between 1 and 5000 then
    raise exception 'bad_coins' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('admin-contributor-reward:' || p_request_id::text, 0));
  select * into v_prev from public.admin_contributor_rewards where request_id = p_request_id;
  if found then
    if v_prev.user_id is distinct from p_user_id or v_prev.coins is distinct from p_coins then
      raise exception 'request_id_conflict' using errcode = '22023';
    end if;
    return;
  end if;
  if not exists (select 1 from public.suggested_questions where user_id = p_user_id) then
    raise exception 'not_a_contributor' using errcode = 'P0002';
  end if;
  perform public._admin_credit_coins(p_user_id, p_coins, 'admin_contributor_reward');
  insert into public.admin_contributor_rewards (user_id, coins, granted_by, request_id)
  values (p_user_id, p_coins, auth.uid(), p_request_id);
  perform public.admin_log('contributor_reward', 'user', p_user_id::text,
    jsonb_build_object('coins', p_coins, 'note', p_note,
      'label', (select pr.display_name from public.profiles pr where pr.id = p_user_id)));
end;
$fn$;
revoke all on function public.admin_reward_contributor(uuid, integer, text, uuid) from public, anon, authenticated;
grant execute on function public.admin_reward_contributor(uuid, integer, text, uuid) to authenticated;

-- #5 (alan 2 #8): kısıtlı hesap turnuvaya yazılamaz. join_tournament gövdesi
-- değişmez; tablo yazma yolu tek kapıdan korunur (botlar user_is_restricted=false).
create or replace function public.w1_guard_tournament_entry()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if public.user_is_restricted(new.player_id) then
    raise exception 'account_restricted' using errcode = '42501';
  end if;
  return new;
end;
$fn$;
revoke all on function public.w1_guard_tournament_entry() from public, anon, authenticated;
drop trigger if exists trg_w1_tournament_entries_restricted on public.tournament_entries;
create trigger trg_w1_tournament_entries_restricted
  before insert on public.tournament_entries
  for each row execute function public.w1_guard_tournament_entry();

-- ---------------------------------------------------------------------------
-- 1. claim_verified_solo_reward (#2)
-- ---------------------------------------------------------------------------
select pg_temp.w1_yama(
  'public.claim_verified_solo_reward(uuid)',
  $e$  v_earned integer; v_amount integer; v_result jsonb;$e$,
  $y$  v_earned integer; v_amount integer; v_result jsonb;
  v_secs numeric; v_n integer;$y$)
from w1_durum d
where d.imza = 'public.claim_verified_solo_reward(uuid)' and d.gerekli;

select pg_temp.w1_yama(
  'public.claim_verified_solo_reward(uuid)',
  $e$  if not found then raise exception 'Profile missing'; end if;
  select coalesce(sum(amount), 0) into v_earned from public.coin_transactions$e$,
  $y$  if not found then raise exception 'Profile missing'; end if;
  -- (2026-11-16 W1) Kısıtlı (engelli/askıdaki) hesap ödül almaz.
  if public.user_is_restricted(auth.uid()) then
    return jsonb_build_object('amount', 0, 'account_restricted', true);
  end if;
  -- (2026-11-16 W1) Taban ödül YOK: en az 5 soru (ilk oturum 5 soruluk), en az 1 doğru
  -- ve toplam süre en az soru sayısı kadar saniye. Tek soruluk / boş cevaplı / anında
  -- biten tur 4 jeton (ve davet ödülü kanıtı) üretemez. Sonuç kaydedilir (tekrar çağrı
  -- aynı yanıtı verir).
  v_n := cardinality(v_session.question_ids);
  v_secs := extract(epoch from (v_session.completed_at - v_session.started_at));
  if v_n < 5 or v_session.correct_count < 1 or v_secs < v_n then
    v_result := jsonb_build_object('amount', 0, 'daily_cap', 45, 'cap_reached', false,
      'session_id', v_session.id, 'not_eligible', true);
    update public.verified_quiz_sessions set reward_result = v_result where id = v_session.id;
    return v_result;
  end if;
  select coalesce(sum(amount), 0) into v_earned from public.coin_transactions$y$)
from w1_durum d
where d.imza = 'public.claim_verified_solo_reward(uuid)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 2. claim_share_reward (#1, #5)
-- ---------------------------------------------------------------------------
select pg_temp.w1_yama(
  'public.claim_share_reward()',
  $e$  c_reward constant integer := 25;
begin$e$,
  $y$  c_reward constant integer := 25;
  v_from timestamptz := public.app_today()::timestamp at time zone 'Europe/Istanbul';
begin$y$)
from w1_durum d
where d.imza = 'public.claim_share_reward()' and d.gerekli;

select pg_temp.w1_yama(
  'public.claim_share_reward()',
  $e$  insert into public.share_reward_claims (player_id, claim_date)
  values (v_uid, v_today)$e$,
  $y$  -- (2026-11-16 W1) Kısıtlı hesap ödül almaz.
  if public.user_is_restricted(v_uid) then
    return query select false, 0, 'account_restricted'::text;
    return;
  end if;

  -- (2026-11-16 W1) Paylaşımın kendisi sunucuda doğrulanamaz; ödül o gün DOĞRULANMIŞ bir
  -- oyun etkinliğine bağlanır: >=5 soruluk ve >=1 doğrulu doğrulanmış tur, solo/oda ödülü
  -- kaydı ya da bitmiş düello. Etkinliksiz doğrudan RPC günde 25 jeton alamaz.
  if not (
    exists (
      select 1 from public.verified_quiz_sessions s
      where s.user_id = v_uid
        and s.completed_at >= v_from and s.completed_at < v_from + interval '1 day'
        and s.correct_count >= 1 and cardinality(s.question_ids) >= 5)
    or exists (
      select 1 from public.coin_transactions ct
      where ct.player_id = v_uid
        and ct.created_at >= v_from and ct.created_at < v_from + interval '1 day'
        and (ct.reason = 'solo_round' or ct.reason like 'quiz_complete:%'))
    or exists (
      select 1 from public.async_duel_results r
      where r.player_id = v_uid
        and r.finished_at >= v_from and r.finished_at < v_from + interval '1 day')
  ) then
    return query select false, 0, 'No verified play today'::text;
    return;
  end if;

  insert into public.share_reward_claims (player_id, claim_date)
  values (v_uid, v_today)$y$)
from w1_durum d
where d.imza = 'public.claim_share_reward()' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 3. redeem_referral_code (#11, #5)
-- ---------------------------------------------------------------------------
select pg_temp.w1_yama(
  'public.redeem_referral_code(text)',
  $e$  -- (2026-11-06) Paylaşılan 'ZK-4F7K' ile yazılan '4F7K' aynı kod: önek atılır.$e$,
  $y$  -- (2026-11-16 W1) Kısıtlı (engelli/askıdaki) hesap davet ödülü akışına giremez.
  if public.user_is_restricted(v_user_id) then
    return jsonb_build_object(
      'success', false,
      'error', 'account_restricted',
      'message', 'Account restricted'
    );
  end if;

  -- (2026-11-06) Paylaşılan 'ZK-4F7K' ile yazılan '4F7K' aynı kod: önek atılır.$y$)
from w1_durum d
where d.imza = 'public.redeem_referral_code(text)' and d.gerekli;

select pg_temp.w1_yama(
  'public.redeem_referral_code(text)',
  $e$  where id = v_ref_id;

  if not found then$e$,
  $y$  where id = v_ref_id;

  -- (2026-11-16 W1) Kısıtlı davet eden ödül dağıtamaz; durumu sızmasın diye kod yokmuş gibi.
  if not found or public.user_is_restricted(v_ref_id) then$y$)
from w1_durum d
where d.imza = 'public.redeem_referral_code(text)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 4. spend_coins_once (#7)
-- ---------------------------------------------------------------------------
select pg_temp.w1_yama(
  'public.spend_coins_once(integer,text,text)',
  $e$  v_key text;
  v_result jsonb;
begin$e$,
  $y$  v_key text;
  v_result jsonb;
  v_prev record;
begin$y$)
from w1_durum d
where d.imza = 'public.spend_coins_once(integer,text,text)' and d.gerekli;

select pg_temp.w1_yama(
  'public.spend_coins_once(integer,text,text)',
  $e$  if exists (
    select 1
      from public.idempotent_spends
     where player_id = v_uid
       and idempotency_key = v_key
  ) then
    return jsonb_build_object('success', true, 'idempotent', true);
  end if;$e$,
  $y$  select s.amount, s.reason into v_prev
    from public.idempotent_spends s
   where s.player_id = v_uid
     and s.idempotency_key = v_key;
  if found then
    -- (2026-11-16 W1) Aynı anahtar başka tutar/nedenle gelirse "başarı" değil: istemci
    -- anahtarı yeniden kullanıyor demektir, harcama yapılmadı.
    if v_prev.amount is distinct from p_amount or v_prev.reason is distinct from p_reason then
      return jsonb_build_object('success', false, 'error', 'idempotency_key_mismatch');
    end if;
    return jsonb_build_object('success', true, 'idempotent', true);
  end if;$y$)
from w1_durum d
where d.imza = 'public.spend_coins_once(integer,text,text)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 5. record_activity (#10)
-- ---------------------------------------------------------------------------
select pg_temp.w1_yama(
  'public.record_activity(boolean)',
  $e$  if coalesce(p_solo, false) then
    insert into public.usage_mode_counter (day, mode, shard, n)$e$,
  $y$  if coalesce(p_solo, false) then
    -- (2026-11-16 W1) Kullanıcı başına günde en çok 30 artış: doğrudan RPC ile sayaç
    -- sınırsız şişirilemez (gerçek oyuncu günde 30 solo turdan çok oynamaz).
    update public.usage_daily_active a set solo_n = a.solo_n + 1
     where a.day = v_day and a.user_id = v_uid and a.solo_n < 30;
    if not found then
      return;
    end if;
    insert into public.usage_mode_counter (day, mode, shard, n)$y$)
from w1_durum d
where d.imza = 'public.record_activity(boolean)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 6. admin_reward_contributor (3 bağımsız değişkenli eski imza) (#6)
-- ---------------------------------------------------------------------------
select pg_temp.w1_yama(
  'public.admin_reward_contributor(uuid,integer,text)',
  $e$AS $function$
begin
  perform public.admin_assert();$e$,
  $y$AS $function$
declare
  v_req uuid;
begin
  perform public.admin_assert();$y$)
from w1_durum d
where d.imza = 'public.admin_reward_contributor(uuid,integer,text)' and d.gerekli;

select pg_temp.w1_yama(
  'public.admin_reward_contributor(uuid,integer,text)',
  $e$  perform public._admin_credit_coins(p_user_id, p_coins, 'admin_contributor_reward');
  insert into public.admin_contributor_rewards (user_id, coins, granted_by)
  values (p_user_id, p_coins, auth.uid());$e$,
  $y$  -- (2026-11-16 W1) İstemci kimliği yok: aynı yönetici + kullanıcı + tutar için 10 dk'lık
  -- dilimden türeyen belirleyici kimlik; yanıt kaybolup yeniden gönderilen aynı istek ikinci
  -- ödeme üretmez. Kimlik gönderen yeni istemci 4 bağımsız değişkenli imzayı kullanır.
  v_req := md5(auth.uid()::text || ':' || p_user_id::text || ':' || p_coins::text || ':'
               || floor(extract(epoch from clock_timestamp()) / 600)::text)::uuid;
  perform pg_advisory_xact_lock(hashtextextended('admin-contributor-reward:' || v_req::text, 0));
  if exists (select 1 from public.admin_contributor_rewards where request_id = v_req) then
    return;
  end if;
  perform public._admin_credit_coins(p_user_id, p_coins, 'admin_contributor_reward');
  insert into public.admin_contributor_rewards (user_id, coins, granted_by, request_id)
  values (p_user_id, p_coins, auth.uid(), v_req);$y$)
from w1_durum d
where d.imza = 'public.admin_reward_contributor(uuid,integer,text)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 7. admin_moderate_user: engel/askı, açık turnuvadaki bekleyen kaydı da siler (alan 2 #8)
-- ---------------------------------------------------------------------------
select pg_temp.w1_yama(
  'public.admin_moderate_user(uuid,text,integer,text)',
  $e$    update public.profile_reports set handled_at = now()
     where reported_id = p_user_id and handled_at is null;$e$,
  $y$    update public.profile_reports set handled_at = now()
     where reported_id = p_user_id and handled_at is null;
    -- (2026-11-16 W1) Kısıtlanan hesap henüz BAŞLAMAMIŞ (açık) turnuvadan çıkarılır;
    -- başlamış turnuvada eşleşme kayıtlarına dokunulmaz.
    if p_action in ('block', 'suspend') then
      delete from public.tournament_entries e
       using public.tournaments t
       where e.tournament_id = t.id and t.status = 'open' and e.player_id = p_user_id;
    end if;$y$)
from w1_durum d
where d.imza = 'public.admin_moderate_user(uuid,text,integer,text)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 8. get_my_league (alan 2 #10, #12) + ack_my_league_result (#11)
-- ---------------------------------------------------------------------------
select pg_temp.w1_yama(
  'public.get_my_league()',
  $e$     and not exists (
       select 1 from public.weekly_league_closed c where c.week_start = v_week - 7
     ) then$e$,
  $y$     and not exists (
       select 1 from public.weekly_league_closed c where c.week_start = v_week - 7
     )
     -- (2026-11-16 W1) Telafi kapanışı planlı cron'dan (pazartesi 00:05) ÖNCE değil, 00:10'dan
     -- sonra: gecikmiş son gün puanı kesinleşmiş sıralamaya girmeden kapanmasın.
     and now() >= (v_week::timestamp at time zone 'Europe/Istanbul') + interval '10 minutes' then$y$)
from w1_durum d
where d.imza = 'public.get_my_league()' and d.gerekli;

select pg_temp.w1_yama(
  'public.get_my_league()',
  $e$  if v_cohort is null and not v_pending
     and public.weekly_league_score(v_uid, v_week) > 0 then$e$,
  $y$  if v_cohort is null and not v_pending
     and not public.user_is_restricted(v_uid)
     and public.weekly_league_score(v_uid, v_week) > 0 then$y$)
from w1_durum d
where d.imza = 'public.get_my_league()' and d.gerekli;

select pg_temp.w1_yama(
  'public.get_my_league()',
  $e$        where r.player_id = v_uid
          or not exists (
            select 1 from public.blocked_users b
            where b.blocker_id = v_uid and b.blocked_id = r.player_id
          )
      ), '[]'::jsonb),$e$,
  $y$        where (r.player_id = v_uid
          or not exists (
            select 1 from public.blocked_users b
            where b.blocker_id = v_uid and b.blocked_id = r.player_id
          ))
          -- (2026-11-16 W1) Kısıtlı hesaplar küme listesinde görünmez.
          and not public.user_is_restricted(r.player_id)
      ), '[]'::jsonb),$y$)
from w1_durum d
where d.imza = 'public.get_my_league()' and d.gerekli;

select pg_temp.w1_yama(
  'public.ack_my_league_result()',
  $e$  where m.player_id = auth.uid() and m.outcome is not null and not m.result_seen;$e$,
  $y$  -- (2026-11-16 W1) get_my_league yalnız EN YENİ okunmamış sonucu gösterir (LIMIT 1);
  -- kapatma da yalnız onu "görüldü" yapar, daha eski okunmamış sonuçlar sırayla gelir.
  where m.player_id = auth.uid() and m.outcome is not null and not m.result_seen
    and m.week_start = (
      select max(x.week_start) from public.weekly_league_members x
      where x.player_id = auth.uid() and x.outcome is not null and not x.result_seen);$y$)
from w1_durum d
where d.imza = 'public.ack_my_league_result()' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 9. push_delivery_v2_allowed (alan 4 #8, #14, #22) + admin_enqueue_push (#15)
-- ---------------------------------------------------------------------------
select pg_temp.w1_yama(
  'public.push_delivery_v2_allowed(uuid,uuid,text,timestamptz,jsonb)',
  $e$      and not (coalesce(p_kind, '') in ('friend_request', 'friend_accept', 'room_invite')
               and not pr.push_social)$e$,
  $y$      and not (coalesce(p_kind, '') in ('friend_request', 'friend_accept', 'room_invite')
               and not pr.push_social)
      -- (2026-11-16 W1) Yönetici push'ları: alıcı hâlâ yönetici, ilgili bildirim tercihi
      -- açık (kuyruğa girdikten sonra kapatılmış olabilir) ve ana bildirim anahtarı kapalı
      -- DEĞİL (istemci ana anahtarı kapatınca push_duel ve push_social'ı birlikte kapatır).
      and (coalesce(p_kind, '') not like 'admin\_%' or (
            (pr.push_duel or pr.push_social)
            and exists (select 1 from public.admins a where a.user_id = p_to_user_id)
            and not exists (
              select 1 from public.admin_notify_prefs n
              where n.admin_id = p_to_user_id and not n.enabled
                and n.kind = case p_kind when 'admin_suggestion' then 'suggestion'
                                         when 'admin_report' then 'report' end)))
      -- (2026-11-16 W1) Arkadaşlık bildirimi claim anında da geçerli olmalı: iptal edilmiş /
      -- reddedilmiş / silinmiş isteğin ya da geri alınmış kabulün bildirimi gönderilmez.
      and (p_from_user_id is null
           or coalesce(p_kind, '') not in ('friend_request', 'friend_accept')
           or exists (
             select 1 from public.friend_requests fr
             where (p_kind = 'friend_request' and fr.status = 'pending'
                    and fr.from_user_id = p_from_user_id and fr.to_user_id = p_to_user_id)
                or (p_kind = 'friend_accept' and fr.status = 'accepted'
                    and fr.from_user_id = p_to_user_id and fr.to_user_id = p_from_user_id)))$y$)
from w1_durum d
where d.imza = 'public.push_delivery_v2_allowed(uuid,uuid,text,timestamptz,jsonb)' and d.gerekli;

select pg_temp.w1_yama(
  'public.admin_enqueue_push()',
  $e$exception when others then
  -- Bildirim kaydı asıl işlemi (öneri/şikâyet kaydı) ASLA bozmaz.
  return new;$e$,
  $y$exception when others then
  -- Bildirim kaydı asıl işlemi (öneri/şikâyet kaydı) ASLA bozmaz; ama hata artık
  -- sessiz değil (2026-11-16 W1): sunucu günlüğünde WARNING olarak görünür.
  raise warning 'admin_enqueue_push: % (%)', sqlerrm, sqlstate;
  return new;$y$)
from w1_durum d
where d.imza = 'public.admin_enqueue_push()' and d.gerekli;

-- ---------------------------------------------------------------------------
-- Yama sonrası güvenlik doğrulaması: SECURITY DEFINER, sahip, ACL ve proconfig DEĞİŞMEDİ,
-- nihai md5 tam; yeni işlevlerde anon/PUBLIC EXECUTE yok.
-- ---------------------------------------------------------------------------
do $w1_son$
declare
  r record;
begin
  for r in select * from w1_durum loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.imza)
        and p.proowner = r.sahip
        and p.prosecdef = r.secdef
        and p.proconfig is not distinct from r.ayar
        and p.proacl::text is not distinct from r.acl
    ) then
      raise exception 'w1: % sahip / search_path / ACL doğrulanamadı (yama bunları değiştirdi)', r.imza;
    end if;
    if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then
      raise exception 'w1: % yama sonrası gövde beklenen nihai md5 değil', r.imza;
    end if;
    if not exists (select 1 from pg_proc p where p.oid = to_regprocedure(r.imza)
                   and p.prosecdef and p.proconfig is not null) then
      raise exception 'w1: % SECURITY DEFINER + sabit search_path değil', r.imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
       or has_function_privilege('public', to_regprocedure(r.imza), 'execute') then
      raise exception 'w1: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
  -- Yeni işlevler.
  for r in select unnest(array[
      'public.admin_reward_contributor(uuid,integer,text,uuid)',
      'public.w1_guard_tournament_entry()']) as imza
  loop
    if not exists (select 1 from pg_proc p where p.oid = to_regprocedure(r.imza)
                   and p.prosecdef and p.proconfig is not null) then
      raise exception 'w1: % SECURITY DEFINER + sabit search_path değil', r.imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
       or has_function_privilege('public', to_regprocedure(r.imza), 'execute') then
      raise exception 'w1: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
  if has_function_privilege('authenticated', 'public.w1_guard_tournament_entry()'::regprocedure, 'execute')
     or not has_function_privilege('authenticated', 'public.admin_reward_contributor(uuid,integer,text,uuid)'::regprocedure, 'execute') then
    raise exception 'w1: yeni işlevlerin authenticated EXECUTE durumu beklenen değil';
  end if;
end;
$w1_son$;

commit;
