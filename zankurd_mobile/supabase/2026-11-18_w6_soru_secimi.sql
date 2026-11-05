-- 2.1.2 W6 (ChatGPT Pro alan 6 #2, alan 9 #1): SORU SEÇİMİ. YAZILDI, CANLIYA UYGULANMADI.
-- Geri alma: geri_al/2026-11-18_w6_soru_secimi_geri.sql
--
-- Bu göç iki işlevin gövdesini yamalar (tur7 ile aynı düzen:
-- TAM gövde md5 ön koşulu + olcek_tur3_yedek 'w6:<imza>' + yama md5 zinciri; ya hep
-- ya hiç). Eski istemci (build 45) sözleşmesi: imza ve dönüş biçimi DEĞİŞMEZ.
--
--  1. start_room_game (alan 6 #2). Oda soru seçimindeki "son 14 günde görülen" kümesinin
--     ikinci kolu, oynanan odalarda `room_questions`a yazılmış HER soruyu görülmüş sayıyordu;
--     oysa satırlar oda başlarken önceden yazılır (started_at/revealed_at NULL) ve oda
--     yarıda kalırsa ya da 10 sorunun yalnız birkaçı oynanırsa hiç gösterilmemiş sorular
--     "görülmüş" sayılıp oyuncuları gereksiz yere dışlıyor, taze havuzu daraltıyordu.
--     Artık yalnız GERÇEKTEN sunulan (started_at ya da revealed_at dolu) sorular sayılır.
--  2. prepare_verified_solo_questions (alan 9 #1). Her çağrı uygun bütün havuzu (~7.000
--     satır, her satırda 5-6 `btrim` süzgeci) `random()` ile SIRALIYORDU; indeks kullanılamaz.
--     Yeni: rastgele bir uuid eşiğinden (birincil anahtar indeksi) kimlik sırasıyla en çok
--     5 x p_limit uygun satır okunur (eşikten sonrası biterse baştan tamamlanır), bu küçük
--     kümeden `random()` ile p_limit seçilir. Kimlikler uuid5/uuid4 karması olduğundan kimlik
--     sırası içerikle ilişkisizdir (komşu soru aynı konu değildir); 5 x p_limit'ten az uygun
--     satırı olan kategoride (küçük havuz) tüm havuz taranır, davranış eskisiyle aynıdır.
--     Süzgeçler, hata iletileri ve bilet yazımı AYNI.
begin;

set local lock_timeout = '10s';

-- `server_only` (2026-11-17_rekabet_sunucu_havuzu.sql ile AYNI tanım, idempotent): sütun
-- henüz yoksa (göç sırası) burada oluşur; varsa hiçbir şey yapmaz. Solo seçim bu soruları
-- dışlar (aşağıda).
alter table public.questions add column if not exists server_only boolean not null default false;

do $w6_onkosul$
begin
  if to_regprocedure('public.start_room_game(uuid)') is null
     or to_regprocedure('public.prepare_verified_solo_questions(text,integer)') is null
     or to_regclass('public.olcek_tur3_yedek') is null then
    raise exception 'w6: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
  alter table public.olcek_tur3_yedek enable row level security;
  revoke all on public.olcek_tur3_yedek from public, anon, authenticated;
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'w6: olcek_tur3_yedek anon/authenticated erişimine açık kalıyor';
  end if;
end;
$w6_onkosul$;

-- Bilinen canlı taban gövdelerinin TAM md5'i (pg_get_functiondef):
--   start_room_game(uuid)                          taban 2026-10-18_oda_kod_kategori.sql
--   prepare_verified_solo_questions(text,integer)  taban 2026-11-01_solo_daily_verified.sql
-- Gövde ya tam bu taban (yamalanır) ya tam nihai md5 + sağlam yedek/md5 zinciri
-- (zaten uygulanmış, atlanır) olmalı; başka her durum göçü durdurur.
create temp table w6_durum (
  imza text primary key, gerekli boolean not null, sahip oid not null, nihai text not null,
  acl text, ayar text[], secdef boolean not null
) on commit drop;
do $w6_durum$
declare
  r record;
  v_def text;
  v_yedek text;
  v_eski text;
begin
  for r in select * from (values
    ('public.start_room_game(uuid)', '918cef7cf52cde1d9dd3994ef2383c0e', '19ed6e01a674cbc526bd3f9129c03400'),
    ('public.prepare_verified_solo_questions(text,integer)', 'a20a15d07f5ad79871fa5fa4a4b889bb', 'ea49c4455504e3ea44bea08c8f821bd6')
  ) t(imza, taban, nihai)
  loop
    v_def := pg_get_functiondef(to_regprocedure(r.imza));
    if md5(v_def) = r.taban then
      insert into w6_durum
      select r.imza, true, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
      from pg_proc p where p.oid = to_regprocedure(r.imza);
      continue;
    end if;
    if md5(v_def) <> r.nihai then
      raise exception 'w6: % gövdesi ne bilinen canlı taban ne de bu sürümün nihai gövdesi (md5 %); canlı gövde değişmiş olabilir, elle incele', r.imza, md5(v_def);
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w6:' || r.imza;
    v_eski := regexp_replace(coalesce(v_yedek, ''), E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yedek is null or v_eski = v_yedek
       or md5(v_eski) <> r.taban
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> r.taban
       or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') <> r.nihai then
      raise exception 'w6: % nihai gövdede ama yedek satırı/md5 zinciri sağlam değil; güvenli geri alma yok, elle incele', r.imza;
    end if;
    insert into w6_durum
    select r.imza, false, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
    from pg_proc p where p.oid = to_regprocedure(r.imza);
  end loop;
end;
$w6_durum$;

-- Yamalayıcı (tur7 ile aynı): eski parça TAM BİR kez ve yeni parça YOK ise yamalar;
-- yeni parça TAM BİR kez ve eski parça kalmamışsa uygulanmış sayar; başka durum durdurur.
-- Yamadan önce CANLI gövde (md5'iyle) yedeğe yazılır.
create or replace function pg_temp.w6_yama(p_imza text, p_eski text, p_yeni text)
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
    raise exception 'w6: işlev yok: %', p_imza;
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
    raise exception 'w6: % için yama durumu beklenmiyor (eski % kez, yeni % kez; eski=1/yeni=0 beklenir); canlı gövde değişmiş ya da yarım yamalı, yeniden incele', p_imza, v_eski_n, v_yeni_n;
  end if;
  select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w6:' || p_imza;
  if v_yedek is null
     or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') is distinct from md5(v_def) then
    insert into public.olcek_tur3_yedek (ad, tanim, alindi)
    values ('w6:' || p_imza, v_def || E'\n-- md5:' || md5(v_def), now())
    on conflict (ad) do update set tanim = excluded.tanim, alindi = excluded.alindi;
  end if;
  execute replace(v_def, p_eski, p_yeni);
  update public.olcek_tur3_yedek
  set tanim = regexp_replace(tanim, E'\n-- yama-md5:[0-9a-f]+$', '')
               || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'w6:' || p_imza;
end;
$yama$;

-- ---------------------------------------------------------------------------
-- 1. start_room_game: yalnız gerçekten sunulan sorular "görülmüş" sayılır.
-- ---------------------------------------------------------------------------
select pg_temp.w6_yama(
  'public.start_room_game(uuid)',
  $e$      join public.room_questions seen_rq
        on seen_rq.room_id = seen_r.id
      where greatest($e$,
  $y$      join public.room_questions seen_rq
        on seen_rq.room_id = seen_r.id
      -- (2026-11-18, W6) Yalnız GERÇEKTEN sunulan sorular: satırlar oda başlarken
      -- önceden yazılır; sunulmadan kalan (yarım oda, forfeit) sorular görülmüş sayılıp
      -- oyuncuyu gereksiz yere dışlıyordu.
      where (seen_rq.started_at is not null or seen_rq.revealed_at is not null)
        and greatest($y$)
from w6_durum d
where d.imza = 'public.start_room_game(uuid)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 2. prepare_verified_solo_questions: kimlik indeksinden küçük aday kümesi + random().
-- ---------------------------------------------------------------------------
select pg_temp.w6_yama(
  'public.prepare_verified_solo_questions(text,integer)',
  $e$  select array_agg(id order by seed) into v_ids from (
    select q.id, random() as seed from public.questions q
    join public.categories c on c.id = q.category_id
    where q.is_approved = true and c.is_active = true
      and (p_category is null or p_category = 'Tevlihev' or c.name = p_category)
      and q.correct_option in ('A','B','C','D')
      and btrim(coalesce(q.prompt, '')) <> ''
      and btrim(coalesce(q.option_a, '')) not in ('', '-')
      and btrim(coalesce(q.option_b, '')) not in ('', '-')
      and (q.question_type = 'true_false' and q.correct_option in ('A','B')
        or coalesce(q.question_type, 'multiple_choice') = 'multiple_choice'
          and btrim(coalesce(q.option_c, '')) not in ('', '-')
          and btrim(coalesce(q.option_d, '')) not in ('', '-'))
    order by seed limit p_limit
  ) selected;$e$,
  $y$  -- (2026-11-18, W6) Bütün havuzu random() ile sıralamak yerine: rastgele bir uuid
  -- eşiğinden (birincil anahtar indeksi) en çok 5 x p_limit uygun soru okunur; eşikten
  -- sonrası biterse baştan tamamlanır; p_limit bu küçük kümeden random() ile seçilir.
  -- server_only sorular (yalnız sunucuda tutulan rekabet havuzu; yerel bankada yok)
  -- solo'da DIŞLANIR: build 45 ve yeni istemci solo'da yerel bankada olmayan soruyu
  -- oynatamaz (alan 6 #5).
  -- Eşik `(select p from pivot)` skaler alt sorgusudur: planlayıcı onu birincil anahtar
  -- indeksinde aralık koşulu (Index Cond) olarak kullanır; `from ..., pivot` birleşimi
  -- bunu yapamaz ve bütün indeksi taratır (PGlite EXPLAIN: 6.951 satır -> 284).
  with pivot as materialized (select gen_random_uuid() as p),
  tail_part as materialized (
    select q.id from public.questions q
    join public.categories c on c.id = q.category_id
    where q.id >= (select p from pivot)
      and q.is_approved = true and c.is_active = true
      and q.server_only = false
      and (p_category is null or p_category = 'Tevlihev' or c.name = p_category)
      and q.correct_option in ('A','B','C','D')
      and btrim(coalesce(q.prompt, '')) <> ''
      and btrim(coalesce(q.option_a, '')) not in ('', '-')
      and btrim(coalesce(q.option_b, '')) not in ('', '-')
      and (q.question_type = 'true_false' and q.correct_option in ('A','B')
        or coalesce(q.question_type, 'multiple_choice') = 'multiple_choice'
          and btrim(coalesce(q.option_c, '')) not in ('', '-')
          and btrim(coalesce(q.option_d, '')) not in ('', '-'))
    order by q.id limit p_limit * 5
  ),
  head_part as (
    select q.id from public.questions q
    join public.categories c on c.id = q.category_id
    where q.id < (select p from pivot)
      and q.is_approved = true and c.is_active = true
      and q.server_only = false
      and (p_category is null or p_category = 'Tevlihev' or c.name = p_category)
      and q.correct_option in ('A','B','C','D')
      and btrim(coalesce(q.prompt, '')) <> ''
      and btrim(coalesce(q.option_a, '')) not in ('', '-')
      and btrim(coalesce(q.option_b, '')) not in ('', '-')
      and (q.question_type = 'true_false' and q.correct_option in ('A','B')
        or coalesce(q.question_type, 'multiple_choice') = 'multiple_choice'
          and btrim(coalesce(q.option_c, '')) not in ('', '-')
          and btrim(coalesce(q.option_d, '')) not in ('', '-'))
    order by q.id
    limit greatest(0, p_limit * 5 - (select count(*) from tail_part))
  )
  select array_agg(id order by seed) into v_ids from (
    select w.id, random() as seed
    from (select id from tail_part union all select id from head_part) w
    order by seed limit p_limit
  ) selected;$y$)
from w6_durum d
where d.imza = 'public.prepare_verified_solo_questions(text,integer)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- Yama sonrası güvenlik doğrulaması: sahip, ACL, proconfig, SECURITY DEFINER DEĞİŞMEDİ;
-- nihai md5 tam; anon/PUBLIC EXECUTE yok.
-- ---------------------------------------------------------------------------
do $w6_son$
declare
  r record;
begin
  for r in select * from w6_durum loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.imza)
        and p.proowner = r.sahip
        and p.prosecdef = r.secdef
        and p.proconfig is not distinct from r.ayar
        and p.proacl::text is not distinct from r.acl
    ) then
      raise exception 'w6: % sahip / search_path / ACL doğrulanamadı (yama bunları değiştirdi)', r.imza;
    end if;
    if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then
      raise exception 'w6: % yama sonrası gövde beklenen nihai md5 değil', r.imza;
    end if;
    if not exists (select 1 from pg_proc p where p.oid = to_regprocedure(r.imza)
                   and p.prosecdef and p.proconfig is not null) then
      raise exception 'w6: % SECURITY DEFINER + sabit search_path değil', r.imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
       or has_function_privilege('public', to_regprocedure(r.imza), 'execute') then
      raise exception 'w6: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
end;
$w6_son$;

commit;
