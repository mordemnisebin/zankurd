-- Ölçek denetimi 5. tur (Gemini Flash denetimi; her bulgu kodda doğrulandı).
-- CANLIYA UYGULANMADI (applied.md ⏳). Geri alma: geri_al/2026-11-05_olcek_tur5_geri.sql
--
-- Taban (canlı ✅): join_matchmaking = 2026-10-18_oda_kod_kategori.sql gövdesi +
-- 2026-11-04_olcek_sertlestirme.sql + 2026-11-05_olcek_tur3.sql yamaları;
-- get_my_league = 2026-11-05_haftalik_lig.sql. Gövdeler canlıdan
-- `pg_get_functiondef` ile okunup bağlayıcı metin TAM BİR kez bulunursa
-- yamalanır (idempotent; canlı gövde değişmişse göç durur); eski gövde ve md5'i
-- olcek_tur3_yedek'e ('tur5:<imza>') alınır.
--
-- 1. join_matchmaking: ikinci geçiş matchmaking:<kategori> kilidini TUTARKEN
--    pg_sleep(0.03) (en çok 5 kez) uyuyordu; yük altında bir kategorinin bütün
--    arayanlarını seri hale getiriyordu. Artık uyku YALNIZ kilitsiz geçişlerdedir
--    (kilitli aday -> 30 ms bekle, yeniden ara; en çok 5 kez); kilit alınınca
--    kilit altında TEK, uykusuz arama yapılır ve bulunamazsa bekleme satırı
--    eklenir. "İkisi de görmeden ikisi de bekler" yarışı eskisi gibi kilit
--    altındaki aramayla kapanır (kategori kilidini alan, öncekinin commit'ini
--    görür). Çift eşleşme yok: aday `for update skip locked`, rakip satırın
--    room_id'si aynı işlemde dolar. KALAN PENCERE: kilit altında aramanın
--    tam o anda bir kalp atışının satır kilidine denk gelmesi (milisaniye
--    altı; yalnız kuyrukta tek bekleyen varken önemli). O durumda iki oyuncu
--    bekler; istemci 20 sn'lik iptalden sonra join'i yeniden çağırır, kimse
--    sonsuza dek beklemez (eskisi bu pencereyi kilit altında 150 ms uyuyarak
--    kapatıyordu, bedeli bütün arayanların seri beklemesiydi).
-- 2. get_my_league: cron geciktiğinde her çağrı geçen haftayı kapatmaya
--    kalkıp haftanın ilk dakikalarında yığılıyordu. Artık tek uçuş:
--    pg_try_advisory_xact_lock('league-rollover:<hafta>', rollover ile AYNI
--    anahtar). Kilidi alan kapatır (rollover idempotent: weekly_league_closed
--    satırı); alamayan kapatmayı atlar, mevcut veriyi döndürür ve kademe henüz
--    güncellenmediği için yeni küme ataması YAPMAZ (eski kademeyle yanlış
--    kümeye girilmesin); sonraki çağrı kapanmış haftayı görür.
begin;

set local lock_timeout = '10s';

do $tur5_onkosul$
begin
  if to_regprocedure('public.join_matchmaking(text)') is null
     or to_regprocedure('public.get_my_league()') is null
     or to_regprocedure('public.weekly_league_rollover(date)') is null
     or to_regclass('public.olcek_tur3_yedek') is null then
    raise exception 'tur5: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
end;
$tur5_onkosul$;

-- Yamalayıcı. Uygulanmış sayılması: yeni parça TAM BİR kez var ve yeni parça
-- çıkarıldığında eski parça kalmamış (eski parça yeninin alt metni olabilir).
-- Yamalanması: eski parça TAM BİR kez var ve yeni parça YOK. Başka her durum
-- (yarım yama, çift bağlayıcı, değişmiş gövde) göçü durdurur. Her yamadan
-- önce CANLI gövde (ve md5'i) yedeğe yazılır (bayat yedek kalmaz); yamadan
-- sonraki gövdenin md5'i de eklenir, geri alma yalnız o gövdeyi geri çevirir.
create or replace function pg_temp.tur5_yama(p_imza text, p_eski text, p_yeni text)
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
    raise exception 'tur5: işlev yok: %', p_imza;
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
    raise exception 'tur5: % için bağlayıcı durumu beklenmiyor (eski % kez, yeni % kez; eski=1/yeni=0 beklenir); canlı gövde değişmiş ya da yarım yamalı, yeniden incele', p_imza, v_eski_n, v_yeni_n;
  end if;
  -- Bir işlevin birden çok yaması aynı yedek satırını paylaşır: ilk yama ORİJİNAL
  -- gövdeyi yazar; sonraki yamalar (canlı gövdenin md5'i satırdaki son yama-md5
  -- ile aynıysa, yani zincir bizim) satırı ezmez. Zincir bizim değilse (bayat
  -- satır) yedek yeniden yazılır.
  select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'tur5:' || p_imza;
  if v_yedek is null
     or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') is distinct from md5(v_def) then
    insert into public.olcek_tur3_yedek (ad, tanim, alindi)
    values ('tur5:' || p_imza, v_def || E'\n-- md5:' || md5(v_def), now())
    on conflict (ad) do update set tanim = excluded.tanim, alindi = excluded.alindi;
  end if;
  execute replace(v_def, p_eski, p_yeni);
  update public.olcek_tur3_yedek
  set tanim = regexp_replace(tanim, E'\n-- yama-md5:[0-9a-f]+$', '')
               || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'tur5:' || p_imza;
end;
$yama$;

select pg_temp.tur5_yama(
  'public.join_matchmaking(text)',
  $e$  v_pass integer;
begin
  if v_player_id is null then$e$,
  $y$  v_pass integer;
  v_locked boolean := false;
begin
  if v_player_id is null then$y$);

select pg_temp.tur5_yama(
  'public.join_matchmaking(text)',
  $e$  if v_opponent is null and v_pass = 1 then
    -- İkinci geçiş: kategori kilidi (kendi satırından SONRA ama hiçbir satır
    -- kilidi beklemeden; bayat silme skip locked, rakip arama skip locked).
    perform pg_advisory_xact_lock(hashtextextended('matchmaking:' || lower(v_category_name), 0));
    continue;
  end if;
  if v_opponent is null and v_pass < 6 and exists (
    select 1
    from public.matchmaking_queue w
    where upper(w.category_name) = upper(v_category_name)
      and w.player_id <> v_player_id
      and w.room_id is null
      and (
          (w.last_seen_at is null
            and w.joined_at >= now() - interval '40 seconds')
          or coalesce(w.last_seen_at > now() - interval '12 seconds', false)
        )
  ) then
    -- Aday var ama kilitli (kalp atışı/başka eşleşme): kısa bekle, yeniden ara.
    perform pg_sleep(0.03);
    continue;
  end if;
  exit;
  end loop;$e$,
  $y$  if v_opponent is null and not v_locked then
    -- (2026-11-05 tur5) KİLİT ALTINDA UYUMA YOK. Önce kilitsiz geçişlerde
    -- (kilitli aday varsa kısa bekleyip yeniden ara; en çok 5 x 30 ms) ara;
    -- aday kalmayınca/bitince kategori kilidini al ve kilit altında TEK kez,
    -- uyumadan ara. Kategori sırası yalnız "ara + ekle" kadar sürer.
    if v_pass < 6 and exists (
      select 1
      from public.matchmaking_queue w
      where upper(w.category_name) = upper(v_category_name)
        and w.player_id <> v_player_id
        and w.room_id is null
        and (
            (w.last_seen_at is null
              and w.joined_at >= now() - interval '40 seconds')
            or coalesce(w.last_seen_at > now() - interval '12 seconds', false)
          )
    ) then
      perform pg_sleep(0.03);
      continue;
    end if;
    perform pg_advisory_xact_lock(hashtextextended('matchmaking:' || lower(v_category_name), 0));
    v_locked := true;
    continue;
  end if;
  exit;
  end loop;$y$);

select pg_temp.tur5_yama(
  'public.get_my_league()',
  $e$  v_zone integer;
begin
  if v_uid is null then$e$,
  $y$  v_zone integer;
  v_pending boolean := false;
begin
  if v_uid is null then$y$);

select pg_temp.tur5_yama(
  'public.get_my_league()',
  $e$    perform public.weekly_league_rollover(v_week - 7);
  end if;$e$,
  $y$    -- (2026-11-05 tur5) tek uçuş: kilidi alan kapatır, ötekiler atlar.
    if pg_try_advisory_xact_lock(
         hashtextextended('league-rollover:' || (v_week - 7)::text, 0)) then
      perform public.weekly_league_rollover(v_week - 7);
    else
      v_pending := true;
    end if;
  end if;$y$);

select pg_temp.tur5_yama(
  'public.get_my_league()',
  $e$  if v_cohort is null and public.weekly_league_score(v_uid, v_week) > 0 then$e$,
  $y$  if v_cohort is null and not v_pending
     and public.weekly_league_score(v_uid, v_week) > 0 then$y$);

commit;
