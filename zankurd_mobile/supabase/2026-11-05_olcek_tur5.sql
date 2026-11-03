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
-- (Eklenen sertlik) Kategori kilidi artık pg_try_advisory_xact_lock: alınamazsa
--    satır eklenmeden 'waiting' döner (istemci touch 'none' -> yeniden join).
--    Taban gövdenin TAM md5'i doğrulanır; uygulanmışlıkta yedek+md5 zinciri
--    doğrulanır; yama sonrası prosecdef/search_path/anon EXECUTE doğrulanır.
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
declare
  v_rol text;
begin
  if to_regprocedure('public.join_matchmaking(text)') is null
     or to_regprocedure('public.get_my_league()') is null
     or to_regprocedure('public.weekly_league_rollover(date)') is null
     or to_regclass('public.olcek_tur3_yedek') is null then
    raise exception 'tur5: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
  -- Yedek tablosu istemci rollerine kapalı (rollback bu satırlardaki gövdeyi
  -- çalıştırır; yazılabilir olması keyfi kod çalıştırmak demektir).
  alter table public.olcek_tur3_yedek enable row level security;
  revoke all on public.olcek_tur3_yedek from public, anon, authenticated;
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'tur5: olcek_tur3_yedek anon/authenticated erişimine açık kalıyor';
  end if;
  -- Tek uçuş, get_my_league ile weekly_league_rollover'ın AYNI advisory
  -- anahtarını kullanmasına bağlı: rollover gövdesinde formül aranır.
  v_rol := pg_get_functiondef(to_regprocedure('public.weekly_league_rollover(date)'));
  if position($k$perform pg_advisory_xact_lock(hashtextextended('league-rollover:' || v_week::text, 0));$k$ in v_rol) = 0 then
    raise exception 'tur5: weekly_league_rollover kilit anahtarı beklenenden farklı; tek uçuş anahtarı eşleşmiyor';
  end if;
end;
$tur5_onkosul$;

-- Bilinen canlı taban gövdelerinin TAM md5'i (pg_get_functiondef). Yamadan önce
-- gövde ya (a) tam bu taban olmalı -> yamalanır, ya (b) yedek satırı + md5
-- zinciri sağlam ve yama parçaları yerinde olmalı -> zaten uygulanmış, atlanır.
-- Başka her durum göçü durdurur (bağlayıcı parça aynı kalıp gövdenin başka yeri
-- değişmişse yama SÜRMEZ).
create temp table tur5_durum (imza text primary key, gerekli boolean not null) on commit drop;
do $tur5_durum$
declare
  r record;
  v_def text;
  v_yedek text;
  v_eski text;
begin
  for r in select * from (values
    ('public.join_matchmaking(text)', 'ad0d91b0b6dc7f69921bad085dec4024'),
    ('public.get_my_league()', 'c978108c3c567ecb926a2d78a6093c99')) t(imza, taban)
  loop
    v_def := pg_get_functiondef(to_regprocedure(r.imza));
    if md5(v_def) = r.taban then
      insert into tur5_durum values (r.imza, true);
      continue;
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'tur5:' || r.imza;
    v_eski := regexp_replace(coalesce(v_yedek, ''), E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yedek is null or v_eski = v_yedek
       or md5(v_eski) <> r.taban
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> r.taban
       or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') <> md5(v_def) then
      raise exception 'tur5: % gövdesi ne bilinen canlı taban ne de sağlam yamalı durumda (md5 %); canlı gövde değişmiş ya da yedek bozuk, elle incele', r.imza, md5(v_def);
    end if;
    insert into tur5_durum values (r.imza, false);
  end loop;
end;
$tur5_durum$;

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
  if v_player_id is null then$y$) from tur5_durum d where d.imza = 'public.join_matchmaking(text)' and d.gerekli;

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
    if not pg_try_advisory_xact_lock(hashtextextended('matchmaking:' || lower(v_category_name), 0)) then
      -- Kategori kilidi başkasında: BEKLEME (RPC takılmasın). Satır eklenmeden
      -- 'waiting' döner; istemcinin touch_matchmaking yoklaması 'none' görüp
      -- join'i yeniden çağırır (en geç bir yoklama aralığı sonra).
      return json_build_object('status', 'waiting');
    end if;
    v_locked := true;
    continue;
  end if;
  exit;
  end loop;$y$) from tur5_durum d where d.imza = 'public.join_matchmaking(text)' and d.gerekli;

select pg_temp.tur5_yama(
  'public.get_my_league()',
  $e$  v_zone integer;
begin
  if v_uid is null then$e$,
  $y$  v_zone integer;
  v_pending boolean := false;
begin
  if v_uid is null then$y$) from tur5_durum d where d.imza = 'public.get_my_league()' and d.gerekli;

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
  end if;$y$) from tur5_durum d where d.imza = 'public.get_my_league()' and d.gerekli;

select pg_temp.tur5_yama(
  'public.get_my_league()',
  $e$  if v_cohort is null and public.weekly_league_score(v_uid, v_week) > 0 then$e$,
  $y$  if v_cohort is null and not v_pending
     and public.weekly_league_score(v_uid, v_week) > 0 then$y$) from tur5_durum d where d.imza = 'public.get_my_league()' and d.gerekli;

-- Yama sonrası güvenlik doğrulaması: SECURITY DEFINER, sabit search_path,
-- anon EXECUTE yok; erişim açıkça yeniden kurulur (CREATE OR REPLACE sahipliği
-- ve ACL'yi korur ama göç bunu varsaymaz).
revoke all on function public.join_matchmaking(text) from public, anon;
grant execute on function public.join_matchmaking(text) to authenticated;
revoke all on function public.get_my_league() from public, anon;
grant execute on function public.get_my_league() to authenticated;
do $tur5_son$
declare
  v_imza text;
begin
  foreach v_imza in array array['public.join_matchmaking(text)', 'public.get_my_league()'] loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(v_imza)
        and p.prosecdef
        and exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
    ) then
      raise exception 'tur5: % SECURITY DEFINER + search_path değil', v_imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(v_imza), 'execute')
       or has_function_privilege('public', to_regprocedure(v_imza), 'execute') then
      raise exception 'tur5: % anon/PUBLIC EXECUTE açık', v_imza;
    end if;
  end loop;
end;
$tur5_son$;

commit;
