-- Güvenlik/tutarlılık 7. tur (GPT-6 Pro alan 2 + alan 3 denetimlerinin SQL bulguları;
-- her bulgu kodda doğrulandı). Canlıda (2026-11-04, applied.md ✅).
-- Geri alma: geri_al/2026-11-06_guvenlik_tur7_geri.sql
--
-- Taban (canlı ✅): her işlevin canlı gövdesi, applied.md ✅ satırlarının sırasıyla
-- bulunan SON tanımdır (bkz. her yamanın başlığındaki dosya). Gövdeler canlıdan
-- `pg_get_functiondef` ile okunur; TAM gövdenin md5'i bilinen tabana eşitse yamalanır
-- (başka her durumda göç durur); eski gövde ve md5'i olcek_tur3_yedek'e ('tur7:<imza>')
-- alınır. Bu göç YENİ nesne yaratmaz (tablo/işlev/cron yok): yalnız 18 işlevin gövdesini
-- yamalar; bu yüzden "yaratılacak nesne zaten var" ön koşulu yoktur — uygulanmışlık
-- yalnız md5 + yedek zinciriyle denetlenir. İndeksler ayrı dosyada
-- (2026-11-06_guvenlik_tur7_indeks_concurrently.sql; transaction dışı).
--
-- Eski istemci (build 43) sözleşmesi: hiçbir RPC'nin imzası ya da dönüş biçimi
-- değişmez. Tek davranış farkı: get_async_duel_review artık yalnız çağıranın
-- CEVAPLADIĞI soruları döner (istemci boş listede bölümü gizler).
--
-- ALAN 3 (SQL/RLS/RPC)
--  1. get_async_duel_review: create_async_duel_challenge(kategori,NULL) -> cancel_my_async_duel
--     -> inceleme zinciri, tek soru oynamadan 7 sorunun doğru şıklarını açıyordu
--     (iptal 'expired' yazar; kapı 2 'expired'i bitmiş sayar). Artık yalnız çağıranın
--     cevapladığı sorular döner. İki hesapla (eşleş + süre dolsun) aynı yol da kapanır.
--  2. assign_player_tag: istemci INSERT'inde gelen dolu player_tag kabul ediliyordu; ham
--     metin UNIQUE'i '4F7K' ile 'ZK-4F7K'yi ayrı sayıyordu. İstemci rolünden (role GUC)
--     gelen etiket yok sayılıp sunucu üretir; öteki yollarda 'ZK-' öneki atılıp büyük harf.
--     redeem_referral_code girişteki 'ZK-' önekini atıp tek eşitlikle arar (taklit profil
--     gerçek sahibin ödülünü alamaz).
--  3. redeem_referral_code: ömür boyu 10 ödül sınırı, davet edilenin silinmesiyle (ON DELETE
--     CASCADE) kayboluyordu; artık referans sayımı ile davet edenin 'referral_invite'
--     jeton hareketlerinin büyüğü kullanılır.
--  4. profiles_client_insert_authority / profiles_client_write_guard / set_fcm_token:
--     istemci INSERT'te fcm_token'ı NULL, UPDATE'te eskisini korur (yalnız RPC yazar);
--     set_fcm_token token başına advisory kilit alır (eşzamanlı çift sahiplik).
--     Veritabanı düzeyinde UNIQUE indeks BİLEREK eklenmedi: mevcut kopyaları temizlemek
--     canlı veriye bakmayı gerektirir; kilit yeni yarışı kapatır.
--  5. report_question + question_reports_before_insert: UUID kimliğinin harf büyüklüğü
--     varyantları ayrı rapor sayılıyordu (tek hesap sayacı 5'e çıkarıp needsReview
--     üretebiliyordu). Tetikleyici UUID'yi küçük harfe çevirir ve tekilliği lower()
--     üzerinden denetler; RPC lower() ile eşler.
--  6. limit_suggested_question_rate: kota istemcinin verebildiği created_at'i sayıyordu
--     (NULL/eski tarih sayıma girmezdi); kullanıcı eklemelerinde created_at sunucu saatidir.
--  7. add_friend: günlük 30 ve hedef başına saatlik bekleme, silinebilir friend_requests
--     geçmişinden hesaplanıyordu (gönder -> remove_friend -> yeniden gönder iki sınırı
--     aşıyordu). Artık rate_limit_events kovaları (add_friend_day 30/24 sa,
--     add_friend_to:<hedef> 1/sa).
--  9. claim_quiz_reward: profil -> oda kilidi; acknowledge_room_result oda -> profil
--     (makbuz FK). Ödül artık önce odayı sonra profili kilitler (ortak oda -> profil sırası).
-- 10. recompute_player_score_day: gün kilidi -> toplam kilidi; ters yönde toplam -> gün
--     alan bakım yolu vardı. Artık önce oyuncunun toplam kilidi, sonra gün kilidi.
-- 11. redeem_referral_code: çağıran -> davet eden kilidi A<->B karşılıklı kullanımda
--     döngü yapıyordu; iki profil tek sorguda id sırasıyla kilitlenir.
-- 13+14. expire_async_duels: sınırsız tek-sorgu kapanış -> en çok 500 düello, SKIP LOCKED
--     (meşgul düello tüm grubu bekletmez); hükmen XP yeniden denemesi 7 günlük pencereye
--     değil, kalıcı 'xp_awarded=false' durumuna bağlı (en çok 200 satır, profili olmayan
--     kazanan hariç). (expires_at,id) kısmi indeksi ayrı dosyada.
-- 15. answers tabloları indeksleri: ayrı dosya.
-- 16. log_analytics_event: sayım + ekleme arasında kullanıcı kilidi yoktu; kullanıcı başına
--     advisory kilit (600/saat sınırı eşzamanlı çağrıda aşılamaz).
-- 18. get_my_records: best_contest_correct eski contest_entries'i okuyordu; günlük yarışma
--     sonuçları daily_event_results'a yazılıyor. İkisinin en büyüğü (bekleyen
--     solo_daily_verified göçü doğrulanmış tabloyu da ekler).
-- 20/21. (bekleyen solo_daily_verified.sql dosyasının KENDİSİNDE düzeltildi; canlıda yok.)
-- 22/23. (geri alma dosyaları düzeltildi: turnuva_sunucu_puani_geri, olcek_tur3_geri.)
--
-- ALAN 2 (yalnız SQL olanlar)
--  A. mark_room_client_ready: ücretli iki kişilik oda 'opponent_not_ready' ile bitince
--     giriş ücreti iade edilmiyordu (kalabalık dalda vardı). Aynı işlemde
--     refund_room_entry_fees(oda, null, true) (idempotent). ÖNCEKİ bitmiş odalar için geri
--     doldurma BU GÖÇTE YOK (para hareketi; ayrı karar): aday sorgusu applied.md notunda.
--  B. room_heartbeat: room_players -> rooms; set_room_ready rooms -> room_players. Sahiplik
--     devri gerekebilecekse oda satırı room_players yazımından ÖNCE kilitlenir.
--  C. join_tournament: üyelik kontrolü kilitsizdi; kullanıcı + tahsis advisory kilidi.
--
-- ATLANAN bulgular (ayrıntı applied.md satırında): 8 (düello bildirim kimliği: payload
-- tasarımı, çok işlev), 12 (soru sürümü: değişmez maç kaydı tasarımı), 17 (rebuild_..._all
-- operasyonel: dışarıdan imleçli çağrı), 19 (kalıcı rekor sütunu: şema tasarımı),
-- alan 2 'günün yarışması gün sınırı' (turun başlangıç gününü taşıyan protokol; istemci +
-- bekleyen solo_daily_verified'in sunucu seçimi).
begin;

set local lock_timeout = '10s';

do $tur7_onkosul$
begin
  if to_regprocedure('public.get_async_duel_review(uuid)') is null
     or to_regprocedure('public.assign_player_tag()') is null
     or to_regprocedure('public.redeem_referral_code(text)') is null
     or to_regprocedure('public.profiles_client_insert_authority()') is null
     or to_regprocedure('public.profiles_client_write_guard()') is null
     or to_regprocedure('public.set_fcm_token(text)') is null
     or to_regprocedure('public.report_question(text)') is null
     or to_regprocedure('public.question_reports_before_insert()') is null
     or to_regprocedure('public.limit_suggested_question_rate()') is null
     or to_regprocedure('public.add_friend(uuid,text)') is null
     or to_regprocedure('public.recompute_player_score_day(uuid,date)') is null
     or to_regprocedure('public.expire_async_duels()') is null
     or to_regprocedure('public.log_analytics_event(text,jsonb)') is null
     or to_regprocedure('public.get_my_records()') is null
     or to_regprocedure('public.mark_room_client_ready(uuid)') is null
     or to_regprocedure('public.room_heartbeat(uuid)') is null
     or to_regprocedure('public.join_tournament()') is null
     or to_regprocedure('public.claim_quiz_reward(uuid,integer,integer,integer,integer)') is null
     or to_regprocedure('public.rate_limit_hit(text,integer,interval)') is null
     or to_regprocedure('public.refund_room_entry_fees(uuid,uuid,boolean)') is null
     or to_regclass('public.daily_event_results') is null
     or to_regclass('public.olcek_tur3_yedek') is null then
    raise exception 'tur7: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
  -- Yedek tablosu istemci rollerine kapalı (rollback bu satırlardaki gövdeyi
  -- çalıştırır; yazılabilir olması keyfi kod çalıştırmak demektir).
  alter table public.olcek_tur3_yedek enable row level security;
  revoke all on public.olcek_tur3_yedek from public, anon, authenticated;
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'tur7: olcek_tur3_yedek anon/authenticated erişimine açık kalıyor';
  end if;
  if exists (
    select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
    where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
      and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
  ) then
    raise exception 'tur7: olcek_tur3_yedek sahibi dışında alıcıya açık (relacl)';
  end if;
end;
$tur7_onkosul$;

-- Bilinen canlı taban gövdelerinin TAM md5'i (pg_get_functiondef). Yamadan önce
-- gövde ya (a) tam bu taban olmalı -> yamalanır, ya (b) tam nihai md5'te ve yedek
-- satırı + md5 zinciri sağlam olmalı -> zaten uygulanmış, atlanır. Başka her durum
-- göçü durdurur. sahip / acl / ayar = yamadan önceki sahip, ACL ve proconfig;
-- yama sonrası değişmediği doğrulanır.
create temp table tur7_durum (
  imza text primary key, gerekli boolean not null, sahip oid not null, nihai text not null,
  acl text, ayar text[], secdef boolean not null
) on commit drop;
do $tur7_durum$
declare
  r record;
  v_def text;
  v_yedek text;
  v_eski text;
begin
  for r in select * from (values
    ('public.get_async_duel_review(uuid)', '8a875caecbedd7d30d66b6adc0a1f6e8', 'a0613375e4d6b1d1caf7afeab7e9fa24'),
    ('public.assign_player_tag()', '525dc573d0a970afac4e02b5f26e8b91', '574dd691268ee62817c2911c42cda022'),
    ('public.redeem_referral_code(text)', '61af049f6a36b49cdc26e0ca003df9f2', '400c043982e1083382260710293f3126'),
    ('public.profiles_client_insert_authority()', '8c4aa2ceacf0660241978d780beeb986', '7727a451b5c35fb0963aa012d876d4f3'),
    ('public.profiles_client_write_guard()', 'f40e5a00e9713cee1d4e123702c5a9c8', 'da530a981b44b12743ad87d23b4b10e9'),
    ('public.set_fcm_token(text)', '266e165fba9a3ecd878bb18554eea51a', '7b547fe95da5cb0742b1b472b7cc31d7'),
    ('public.report_question(text)', '5239073908947b58c4f8829bf5152faa', '2455cf0483e46acac4afaa6bc1cbdfdf'),
    ('public.question_reports_before_insert()', '207e48818e4a6954e217e69be835f909', '436859ce19ea7bc1493086edb14ce890'),
    ('public.limit_suggested_question_rate()', '2192d27a228063bacd73ecfcc648a892', 'c6e02a728e27819ca92d8c2c059a2c5c'),
    ('public.add_friend(uuid,text)', '4bb374c9bad3737bfa8f883b64aed284', '8e9fde34f122aa76196f7a8f418905a8'),
    ('public.recompute_player_score_day(uuid,date)', '04200daf3904d294699322833fcbfd78', '4f6e76729ecc074fe753594ec68e06bb'),
    ('public.expire_async_duels()', '96280e7fc888b2985a513a4da0fd8115', '22b49780ed1771d0b71fb2a91bfe102d'),
    ('public.log_analytics_event(text,jsonb)', 'b00d4d9533f8004ce1122eba971abbbe', '99b1d7aa149ae1a884c6bd918618e103'),
    ('public.get_my_records()', 'd585b61d2b0590f64a3b726fdc6bc429', 'dda8517e1992a1071754c776df24b9a9'),
    ('public.mark_room_client_ready(uuid)', '5ef329992125a0d1f036b11133777cbd', 'fb417701be8be271609782d29853b34e'),
    ('public.room_heartbeat(uuid)', 'd247d87086280b697e37696ef3a9d2f1', 'afda0eabc16b0e4d0ac80a3ac7d15d03'),
    ('public.join_tournament()', '4e9c2210878053f26085bf2ba07138da', '21b4605a63178416258d5798a01a4868'),
    ('public.claim_quiz_reward(uuid,integer,integer,integer,integer)', 'bae8d44148d617a1407519875986ab4e', '908d142ffef594db1c6e99a35c94578e')
  ) t(imza, taban, nihai)
  loop
    v_def := pg_get_functiondef(to_regprocedure(r.imza));
    if md5(v_def) = r.taban then
      insert into tur7_durum
      select r.imza, true, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
      from pg_proc p where p.oid = to_regprocedure(r.imza);
      continue;
    end if;
    if md5(v_def) <> r.nihai then
      raise exception 'tur7: % gövdesi ne bilinen canlı taban ne de bu sürümün nihai gövdesi (md5 %); canlı gövde değişmiş olabilir, elle incele', r.imza, md5(v_def);
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'tur7:' || r.imza;
    v_eski := regexp_replace(coalesce(v_yedek, ''), E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yedek is null or v_eski = v_yedek
       or md5(v_eski) <> r.taban
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> r.taban
       or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') <> r.nihai then
      raise exception 'tur7: % nihai gövdede ama yedek satırı/md5 zinciri sağlam değil; güvenli geri alma yok, elle incele', r.imza;
    end if;
    insert into tur7_durum
    select r.imza, false, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
    from pg_proc p where p.oid = to_regprocedure(r.imza);
  end loop;
end;
$tur7_durum$;

-- Yamalayıcı (tur6 ile aynı). Uygulanmış sayılması: yeni parça TAM BİR kez var ve
-- yeni parça çıkarıldığında eski parça kalmamış. Yamalanması: eski parça TAM BİR kez
-- var ve yeni parça YOK. Başka her durum göçü durdurur. Her yamadan önce CANLI gövde
-- (ve md5'i) yedeğe yazılır; bir işlevin birden çok yaması aynı yedek satırını paylaşır
-- (ilk yama ORİJİNALİ yazar).
create or replace function pg_temp.tur7_yama(p_imza text, p_eski text, p_yeni text)
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
    raise exception 'tur7: işlev yok: %', p_imza;
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
    raise exception 'tur7: % için bağlayıcı durumu beklenmiyor (eski % kez, yeni % kez; eski=1/yeni=0 beklenir); canlı gövde değişmiş ya da yarım yamalı, yeniden incele', p_imza, v_eski_n, v_yeni_n;
  end if;
  select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'tur7:' || p_imza;
  if v_yedek is null
     or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') is distinct from md5(v_def) then
    insert into public.olcek_tur3_yedek (ad, tanim, alindi)
    values ('tur7:' || p_imza, v_def || E'\n-- md5:' || md5(v_def), now())
    on conflict (ad) do update set tanim = excluded.tanim, alindi = excluded.alindi;
  end if;
  execute replace(v_def, p_eski, p_yeni);
  update public.olcek_tur3_yedek
  set tanim = regexp_replace(tanim, E'\n-- yama-md5:[0-9a-f]+$', '')
               || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'tur7:' || p_imza;
end;
$yama$;

-- ---------------------------------------------------------------------------
-- 1. get_async_duel_review (taban: 2026-10-24_duello_inceleme_rovans.sql)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.get_async_duel_review(uuid)',
  $e$    and theirs.question_index = o.idx - 1;

  return jsonb_build_object(
    'duel_id', v_duel.id,$e$,
  $y$    and theirs.question_index = o.idx - 1
  -- (2026-11-06) Yalnız ÇAĞIRANIN cevapladığı sorular açılır: oynanmamış sorunun doğru
  -- şıkkı, düello iptal/süre dolumuyla 'expired' olunca da sızmaz.
  where mine.duel_id is not null;

  return jsonb_build_object(
    'duel_id', v_duel.id,$y$)
from tur7_durum d
where d.imza = 'public.get_async_duel_review(uuid)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 2. assign_player_tag (taban: 2026-08-01_player_tag_trigger_permission.sql)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.assign_player_tag()',
  $e$  if new.player_tag is null or length(trim(new.player_tag)) = 0 then
    new.player_tag := public.generate_player_tag();
  end if;
  return new;$e$,
  $y$  -- (2026-11-06) İstemci rolünden (PostgREST: role GUC = authenticated/anon) gelen
  -- etiket YOK SAYILIR, sunucu üretir; ham metin UNIQUE'i '4F7K' ile 'ZK-4F7K'yi ayrı
  -- sayıyor, taklit profil gerçek sahibin kodunu kullanabiliyordu. Öteki yollarda
  -- (göç, bakım) dolu etiket tek biçime (öneksiz, büyük harf) çevrilir.
  if coalesce(current_setting('role', true), '') in ('authenticated', 'anon')
     or new.player_tag is null or length(trim(new.player_tag)) = 0 then
    new.player_tag := public.generate_player_tag();
  else
    new.player_tag := upper(regexp_replace(btrim(new.player_tag), '^ZK-', '', 'i'));
  end if;
  return new;$y$)
from tur7_durum d
where d.imza = 'public.assign_player_tag()' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 3 + 11. redeem_referral_code (taban: 2026-10-15_sosyal_ve_sertlestirme.sql)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.redeem_referral_code(text)',
  $e$  v_referrer_cap constant integer := 10;
begin$e$,
  $y$  v_referrer_cap constant integer := 10;
  v_ref_id uuid;
begin$y$)
from tur7_durum d
where d.imza = 'public.redeem_referral_code(text)' and d.gerekli;

select pg_temp.tur7_yama(
  'public.redeem_referral_code(text)',
  $e$  v_clean_code := upper(trim(p_code));$e$,
  $y$  -- (2026-11-06) Paylaşılan 'ZK-4F7K' ile yazılan '4F7K' aynı kod: önek atılır.
  v_clean_code := regexp_replace(upper(btrim(p_code)), '^ZK-', '');$y$)
from tur7_durum d
where d.imza = 'public.redeem_referral_code(text)' and d.gerekli;

select pg_temp.tur7_yama(
  'public.redeem_referral_code(text)',
  $e$  -- Satır kilidi: aynı kullanıcının eşzamanlı iki çağrısını sıraya koyar.
  select id, referred_by, player_tag
  into v_caller
  from public.profiles
  where id = v_user_id
  for update;
$e$,
  $y$  -- (2026-11-06) Davet edenin kimliği KİLİTSİZ bulunur (kesin 4 karakterli kod önce);
  -- sonra çağıran + davet eden profili TEK sorguda id sırasıyla kilitlenir: A, B'nin;
  -- B, A'nın kodunu aynı anda kullanınca çağıran -> davet eden döngüsü olmaz.
  select p.id into v_ref_id
  from public.profiles p
  where regexp_replace(upper(p.player_tag), '^ZK-', '') = v_clean_code
  order by (p.player_tag = v_clean_code) desc, p.created_at, p.id
  limit 1;

  perform 1
  from public.profiles
  where id in (v_user_id, coalesce(v_ref_id, v_user_id))
  order by id
  for update;

  select id, referred_by, player_tag
  into v_caller
  from public.profiles
  where id = v_user_id;
$y$)
from tur7_durum d
where d.imza = 'public.redeem_referral_code(text)' and d.gerekli;

select pg_temp.tur7_yama(
  'public.redeem_referral_code(text)',
  $e$  select id, display_name, player_tag
  into v_referrer
  from public.profiles
  where player_tag = v_clean_code
     or player_tag = 'ZK-' || v_clean_code
     or replace(player_tag, 'ZK-', '') = v_clean_code
  limit 1
  for update;
$e$,
  $y$  select id, display_name, player_tag
  into v_referrer
  from public.profiles
  where id = v_ref_id;
$y$)
from tur7_durum d
where d.imza = 'public.redeem_referral_code(text)' and d.gerekli;

select pg_temp.tur7_yama(
  'public.redeem_referral_code(text)',
  $e$  if (
    select count(*) from public.referral_redemptions rr
    where rr.referrer_id = v_referrer.id
  ) >= v_referrer_cap then$e$,
  $y$  -- (2026-11-06) Sınır davet edilenin silinmesinden bağımsız: kayıt sayısı ile davet
  -- edenin aldığı 'referral_invite' ödüllerinden BÜYÜĞÜ (silinen hesap kaydı düşürmez).
  if greatest(
    (select count(*) from public.referral_redemptions rr
     where rr.referrer_id = v_referrer.id),
    (select count(*) from public.coin_transactions ct
     where ct.player_id = v_referrer.id and ct.reason = 'referral_invite')
  ) >= v_referrer_cap then$y$)
from tur7_durum d
where d.imza = 'public.redeem_referral_code(text)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 4. fcm_token (taban: 2026-10-24_bildirim_seri_eposta.sql, 2026-10-15_sosyal_ve_sertlestirme.sql)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.profiles_client_insert_authority()',
  $e$    new.email_verified_address := null;$e$,
  $y$    new.email_verified_address := null;
    -- Cihaz token'ı yalnız set_fcm_token() ile yazılır (2026-11-06).
    new.fcm_token := null;$y$)
from tur7_durum d
where d.imza = 'public.profiles_client_insert_authority()' and d.gerekli;

select pg_temp.tur7_yama(
  'public.profiles_client_write_guard()',
  $e$    new.email_verified_address := old.email_verified_address;$e$,
  $y$    new.email_verified_address := old.email_verified_address;
    -- Cihaz token'ı yalnız set_fcm_token() ile yazılır (2026-11-06).
    new.fcm_token := old.fcm_token;$y$)
from tur7_durum d
where d.imza = 'public.profiles_client_write_guard()' and d.gerekli;

select pg_temp.tur7_yama(
  'public.set_fcm_token(text)',
  $e$  -- Token'ın tek sahibi çağıran olur.$e$,
  $y$  -- (2026-11-06) Aynı token'ı iki hesaba eşzamanlı yazan çağrılar sıraya girer
  -- (temizle-sonra-yaz çifte sahiplik bırakabiliyordu).
  perform pg_advisory_xact_lock(hashtextextended('fcm:' || v_token, 0));

  -- Token'ın tek sahibi çağıran olur.$y$)
from tur7_durum d
where d.imza = 'public.set_fcm_token(text)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 5. soru raporu (taban: 2026-10-02_report_question_dedupe.sql)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.report_question(text)',
  $e$   where reporter_id = v_uid
     and question_id = p_question_id
     and counted_at is null;$e$,
  $y$   where reporter_id = v_uid
     and lower(question_id) = lower(p_question_id)
     and counted_at is null;$y$)
from tur7_durum d
where d.imza = 'public.report_question(text)' and d.gerekli;

select pg_temp.tur7_yama(
  'public.question_reports_before_insert()',
  $e$  new.counted_at := null;
  if new.reporter_id is not null$e$,
  $y$  new.counted_at := null;
  -- (2026-11-06) UUID biçimli kimlik küçük harfe çevrilir: harf büyüklüğü varyantları
  -- ayrı rapor sayılıp tek hesapta report_count'u şişiremez.
  if new.question_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    new.question_id := lower(new.question_id);
  end if;
  if new.reporter_id is not null$y$)
from tur7_durum d
where d.imza = 'public.question_reports_before_insert()' and d.gerekli;

select pg_temp.tur7_yama(
  'public.question_reports_before_insert()',
  $e$         and r.question_id = new.question_id$e$,
  $y$         and lower(r.question_id) = lower(new.question_id)$y$)
from tur7_durum d
where d.imza = 'public.question_reports_before_insert()' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 6. soru önerisi kotası (taban: 2026-11-04_olcek_sertlestirme.sql)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.limit_suggested_question_rate()',
  $e$  perform pg_advisory_xact_lock(
    hashtextextended('suggest:' || new.user_id::text, 0));$e$,
  $y$  -- (2026-11-06) Kota yalnız sunucunun damgaladığı zamanı sayar: istemci created_at
  -- olarak NULL/eski tarih verip sayımdan kaçamaz.
  new.created_at := now();

  perform pg_advisory_xact_lock(
    hashtextextended('suggest:' || new.user_id::text, 0));$y$)
from tur7_durum d
where d.imza = 'public.limit_suggested_question_rate()' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 7. add_friend (taban: 2026-10-15_sosyal_ve_sertlestirme.sql + 2026-11-04 saatlik sınır)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.add_friend(uuid,text)',
  $e$  -- Hız sınırı: son 24 saatte açılmış/yenilenmiş en çok 30 istek.
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
$e$,
  $y$  -- (2026-11-06) Hedef başına saatte 1 ve günde 30 istek, silinebilir friend_requests
  -- geçmişinden DEĞİL rate_limit_events kovalarından sayılır (gönder -> remove_friend
  -- -> yeniden gönder yolu geçmişi silip iki sınırı aşıyordu).
  if not public.rate_limit_hit('add_friend_to:' || p_friend_id::text, 1, interval '1 hour') then
    return query select false, 'Friend request cooldown'::text;
    return;
  end if;
  if not public.rate_limit_hit('add_friend_day', 30, interval '24 hours') then
    return query select false, 'Too many friend requests'::text;
    return;
  end if;
$y$)
from tur7_durum d
where d.imza = 'public.add_friend(uuid,text)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 10. recompute_player_score_day (taban: 2026-11-04 olcek_sertlestirme + tur4 toplam yenileme)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.recompute_player_score_day(uuid,date)',
  $e$  perform pg_advisory_xact_lock(
    hashtextextended('score-daily:' || p_player_id::text || ':' || p_day::text, 0));$e$,
  $y$  -- (2026-11-06) Kilit sırası HER yerde oyuncu toplamı -> gün: bu işlev günü kilitleyip
  -- sonunda toplam kilidini alıyordu (ters sıra, eşzamanlı oda bitişi + bakım = deadlock).
  perform pg_advisory_xact_lock(
    hashtextextended('score-total:' || p_player_id::text, 0));
  perform pg_advisory_xact_lock(
    hashtextextended('score-daily:' || p_player_id::text || ':' || p_day::text, 0));$y$)
from tur7_durum d
where d.imza = 'public.recompute_player_score_day(uuid,date)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 13 + 14. expire_async_duels (taban: 2026-10-24_duello_sirasi.sql)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.expire_async_duels()',
  $e$    where d.status in ('open', 'matched')
      and d.expires_at <= now()
    for update of d
  ),
  decided as ($e$,
  $y$    where d.status in ('open', 'matched')
      and d.expires_at <= now()
    -- (2026-11-06) Koşu başına en çok 500 düello; meşgul (kilitli) olan atlanır, tüm
    -- kapanış grubunu bekletmez. Kalanlar 10 dk sonraki koşuda kapanır.
    order by d.expires_at, d.id
    limit 500
    for update of d skip locked
  ),
  decided as ($y$)
from tur7_durum d
where d.imza = 'public.expire_async_duels()' and d.gerekli;

select pg_temp.tur7_yama(
  'public.expire_async_duels()',
  $e$    from public.async_duels d
    where d.status = 'expired'
      and d.forfeit_loser_id is not null
      and d.expires_at >= now() - interval '7 days'
  loop$e$,
  $y$    from public.async_duels d
    where d.status = 'expired'
      and d.forfeit_loser_id is not null
      -- (2026-11-06) Yeniden deneme 7 günlük pencereye değil KALICI durumdadır:
      -- kazananın xp_awarded'ı hâlâ false ise (profili silinmediyse) denenir; en çok
      -- 200 satır, en eskiden başlayarak.
      and exists (
        select 1 from public.async_duel_results r
        where r.duel_id = d.id
          and r.player_id = case when d.forfeit_loser_id = d.creator_id
                                 then d.opponent_id else d.creator_id end
          and r.xp_awarded = false
          and exists (select 1 from public.profiles pw where pw.id = r.player_id)
      )
    order by d.expires_at, d.id
    limit 200
  loop$y$)
from tur7_durum d
where d.imza = 'public.expire_async_duels()' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 16. log_analytics_event (taban: 2026-10-24_sunucu_sertlestirme.sql)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.log_analytics_event(text,jsonb)',
  $e$  -- Kullanıcı başına saatte en çok 600 olay; fazlası SESSİZCE atılır$e$,
  $y$  -- (2026-11-06) Sayım + ekleme kullanıcı kilidi altında: 599 kayıtta iki paralel çağrı
  -- ikisi de geçip 601. kaydı yazamaz.
  perform pg_advisory_xact_lock(hashtextextended('analytics:' || v_user_id::text, 0));

  -- Kullanıcı başına saatte en çok 600 olay; fazlası SESSİZCE atılır$y$)
from tur7_durum d
where d.imza = 'public.log_analytics_event(text,jsonb)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 18. get_my_records (taban: 2026-10-24_duello_durtme.sql)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.get_my_records()',
  $e$    'best_contest_correct', (
      select max(ce.correct_count) from public.contest_entries ce
      where ce.user_id = v_uid
    )$e$,
  $y$    -- (2026-11-06) Eski contest_entries + güncel günlük yarışma sonuçlarının en büyüğü.
    'best_contest_correct', (
      select max(x.c) from (
        select ce.correct_count as c from public.contest_entries ce
        where ce.user_id = v_uid
        union all
        select der.correct_count from public.daily_event_results der
        where der.user_id = v_uid
      ) x
    )$y$)
from tur7_durum d
where d.imza = 'public.get_my_records()' and d.gerekli;

-- ---------------------------------------------------------------------------
-- A. mark_room_client_ready (taban: 2026-10-16_kalabalik_oda.sql)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.mark_room_client_ready(uuid)',
  $e$    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    return json_build_object(
      'status', 'finished',
      'reason', 'opponent_not_ready',
      'forfeited_by', v_not_ready_player_id,$e$,
  $y$    delete from public.matchmaking_queue mq
    where mq.room_id = p_room_id;

    -- (2026-11-06) Oyun hiç başlamadı: ücretli odada giriş ücretleri HERKESE iade
    -- edilir (kalabalık dalındaki ile aynı; idempotent).
    perform public.refund_room_entry_fees(p_room_id, null, true);

    return json_build_object(
      'status', 'finished',
      'reason', 'opponent_not_ready',
      'forfeited_by', v_not_ready_player_id,$y$)
from tur7_durum d
where d.imza = 'public.mark_room_client_ready(uuid)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- B. room_heartbeat (taban: 2026-11-03_rovans_oda_sahibi.sql)
-- Bilinen kalıntı (Copilot): ön okuma ile devir denetimi arasında koşul değişirse eski
-- sıra nadiren kalır; Postgres kilitlenmeyi sezip bir tarafı iptal eder, nabız 10 sn sonra
-- yeniden gelir. Her nabızda oda kilidi 50 kişilik lobiyi tek sıraya dizeceği için seçilmedi.
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.room_heartbeat(uuid)',
  $e$  c_grace constant interval := interval '45 seconds';
begin$e$,
  $y$  c_grace constant interval := interval '45 seconds';
  v_kilit_once boolean;
begin$y$)
from tur7_durum d
where d.imza = 'public.room_heartbeat(uuid)' and d.gerekli;

select pg_temp.tur7_yama(
  'public.room_heartbeat(uuid)',
  $e$  -- En çok 10 sn'de bir yazım: 50 kişilik lobide yazma yükü düşük kalır.$e$,
  $y$  -- (2026-11-06) Kilit sırası rooms -> room_players (set_room_ready ile aynı): sahiplik
  -- devri gerekebilecekse oda satırı, room_players yazımından ÖNCE kilitlenir. Çoğu
  -- çağrıda devir gerekmez ve oda satırı kilitlenmez (kilitsiz ön okuma).
  select r.status = 'lobby' and r.is_custom
         and ((r.rematch_owner_id is not null and r.host_id <> r.rematch_owner_id)
              or exists (
                select 1 from public.room_players rp
                where rp.room_id = r.id
                  and rp.player_id = r.host_id
                  and rp.left_at is null
                  and rp.last_seen_at is not null
                  and rp.last_seen_at < clock_timestamp() - c_grace))
  into v_kilit_once
  from public.rooms r
  where r.id = p_room_id;
  if coalesce(v_kilit_once, false) then
    perform 1 from public.rooms r where r.id = p_room_id for update;
  end if;

  -- En çok 10 sn'de bir yazım: 50 kişilik lobide yazma yükü düşük kalır.$y$)
from tur7_durum d
where d.imza = 'public.room_heartbeat(uuid)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- C. join_tournament (taban: migrations/20260801000000_production_baseline.sql = 2026-07-26)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.join_tournament()',
  $e$    raise exception 'Authenticated user required';
  end if;

  select coalesce(display_name, 'Lîstikvan') into v_name$e$,
  $y$    raise exception 'Authenticated user required';
  end if;

  -- (2026-11-06) Aynı hesabın eşzamanlı iki isteği sıraya girer: üyelik kilit
  -- altında yeniden okunur, iki ayrı turnuvaya kayıt olmaz.
  perform pg_advisory_xact_lock(hashtextextended('tournament-join:' || v_user::text, 0));

  select coalesce(display_name, 'Lîstikvan') into v_name$y$)
from tur7_durum d
where d.imza = 'public.join_tournament()' and d.gerekli;

select pg_temp.tur7_yama(
  'public.join_tournament()',
  $e$  -- Açık turnuva yoksa aç.
  select * into v_tournament$e$,
  $y$  -- Açık turnuva yoksa aç. (2026-11-06) Boş havuzdan turnuva açma ortak tahsis
  -- kilidiyle sıralanır (kilitlenecek satır yokken iki turnuva açılıyordu).
  perform pg_advisory_xact_lock(hashtextextended('tournament-alloc', 0));
  select * into v_tournament$y$)
from tur7_durum d
where d.imza = 'public.join_tournament()' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 9. claim_quiz_reward (taban: 2026-10-22_rakip_cikinca_odul.sql)
-- ---------------------------------------------------------------------------
select pg_temp.tur7_yama(
  'public.claim_quiz_reward(uuid,integer,integer,integer,integer)',
  $e$  perform 1 from public.profiles where id = v_player_id for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  if p_room_id is null then$e$,
  $y$  -- (2026-11-06) Profil satır kilidi oda kilidinden SONRA alınır (aşağıda).
  if p_room_id is null then$y$)
from tur7_durum d
where d.imza = 'public.claim_quiz_reward(uuid,integer,integer,integer,integer)' and d.gerekli;

select pg_temp.tur7_yama(
  'public.claim_quiz_reward(uuid,integer,integer,integer,integer)',
  $e$  if not found then
    raise exception 'Player is not in the room';
  end if;

  if v_room_status <> 'finished' then$e$,
  $y$  if not found then
    raise exception 'Player is not in the room';
  end if;

  -- (2026-11-06) Kilit sırası oda -> profil (acknowledge_room_result makbuz FK'sı ve
  -- refund yolları da bu sırada); profil satır kilidi oda kilidinden SONRA alınır.
  perform 1 from public.profiles where id = v_player_id for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  if v_room_status <> 'finished' then$y$)
from tur7_durum d
where d.imza = 'public.claim_quiz_reward(uuid,integer,integer,integer,integer)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- Yama sonrası güvenlik doğrulaması: SECURITY DEFINER (trigger olmayanlar ve
-- tetikleyici işlevleri dahil önceki hâliyle), sahip, ACL ve proconfig DEĞİŞMEDİ,
-- nihai md5 tam; tetikleyici olmayan işlevlerde anon/PUBLIC EXECUTE yok.
-- ---------------------------------------------------------------------------
do $tur7_son$
declare
  r record;
  v_tetik boolean;
begin
  for r in select * from tur7_durum loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.imza)
        and p.proowner = r.sahip
        and p.prosecdef = r.secdef
        and p.proconfig is not distinct from r.ayar
        and p.proacl::text is not distinct from r.acl
    ) then
      raise exception 'tur7: % sahip / search_path / ACL doğrulanamadı (yama bunları değiştirdi)', r.imza;
    end if;
    if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then
      raise exception 'tur7: % yama sonrası gövde beklenen nihai md5 değil', r.imza;
    end if;
    select p.prorettype = 'trigger'::regtype into v_tetik
    from pg_proc p where p.oid = to_regprocedure(r.imza);
    if not v_tetik then
      if not exists (select 1 from pg_proc p where p.oid = to_regprocedure(r.imza)
                     and p.prosecdef and p.proconfig is not null) then
        raise exception 'tur7: % SECURITY DEFINER + sabit search_path değil', r.imza;
      end if;
      if has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
         or has_function_privilege('public', to_regprocedure(r.imza), 'execute') then
        raise exception 'tur7: % anon/PUBLIC EXECUTE açık', r.imza;
      end if;
    end if;
  end loop;
end;
$tur7_son$;

commit;
