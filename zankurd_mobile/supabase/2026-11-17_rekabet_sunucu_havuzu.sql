-- 2.1.2 W10: REKABETÇİ MODLAR İÇİN SUNUCU-YALNIZ SORU HAVUZU. YAZILDI, CANLIYA UYGULANMADI.
-- Geri alma: geri_al/2026-11-17_rekabet_sunucu_havuzu_geri.sql
--
-- Kusur (W2'den KALAN açık): günün yarışması / oda / düello / turnuva soruları sunum anında
-- sunucudan gelir ve doğru şık cevaptan sonra döner; ama sorunun METNİ yerel paketteki
-- bankada da bulunduğundan, değiştirilmiş bir istemci sunulan metni yerel bankada bulup
-- doğru cevabı anında okuyabilir (cevap anahtarlı bir paketle kapanmaz). Kapanış yolu:
-- rekabetçi modların soruları PAKETTE OLMAYAN sorulardan gelsin. Yeni üretilen sorular
-- (paket 4, 2026-11-17_yeni_sorular_4.sql) `questions.server_only = true` ile eklenir ve
-- hiçbir yerel pakette yoktur; bu göç rekabetçi seçimi o havuza yöneltir.
--
-- Eklemeli ve geriye uyumludur (build 45 bayrak KAPALIYKEN hiçbir şeyi fark etmemeli):
--  * Şema: questions.server_only (varsayılan false), questions.prompt_tr / options_tr
--    (sunucu satırının Türkçe karşılığı; doldurma paket 4'ün işi), app_runtime_config.
--    competitive_server_only_pool (varsayılan FALSE) + seçim indeksi.
--  * Seçim: rekabetçi seçimin TEK ortak kapısı weighted_question_pick'tir (oda + hızlı
--    eşleşme = start_room_game, düello = start_async_duel / create_async_duel_challenge,
--    turnuva = start_tournament_match, meydan okuma/rövanş hep onu çağırır). Gövdesi tek
--    satır yamalanır: aday kimlikleri önce _w10_competitive_pool'dan geçer. Bayrak kapalıyken
--    bu işlev adayları AYNEN döndürür (seçim davranışı eskisiyle aynı). Solo / öğrenme
--    seçimi weighted_question_pick'i HİÇ çağırmaz; bu göçle değişmez.
--  * Günün yarışması seti (_w2_daily_set) bayrak açıkken ve sunucu-yalnız havuz >= 30 soruysa
--    yalnız o havuzdan seçer (aşağıda gerekçe).
--  * Sunum yanıtları (günlük present, düello present_v2, turnuva/düello soru yükü, oda v2)
--    `prompt_tr` / `options_tr` alanlarını da taşır (yoksa null); eski istemci bilinmeyen
--    anahtarı yok sayar.
--
-- BAYRAK `app_runtime_config.competitive_server_only_pool` (varsayılan false):
-- build 45 istemcisi sunulan soruyu yerel bankada eşlemeye çalışır (bulamazsa o soruyu
-- gösteremez / atlar). Bu yüzden bayrak ANCAK min_supported_build_* 46'ya çekilince açılır
-- (applied.md notu). Sıra: göç, 2.1.2 (build 46) yayılır, min build 46, sonra bayrak.
--
-- EŞİK VE DÜŞÜŞ (açık karar): bir kategoride sunucu-yalnız aday sayısı tur başına gereken
-- soru sayısının 3 katından azsa (ör. 10 soruluk odada < 30; Ziman'da paket 4 yok) O
-- kategorinin TÜM onaylı adayları havuzda kalır; yeterliyse yalnız sunucu-yalnız olanlar.
-- Karışık/çoklu kategori havuzunda kural kategori başına uygulanır. Süzgeç sonunda aday
-- sayısı gereken sayının altına düşerse (ör. küçük havuz) süzgeç hiç uygulanmaz.
-- GÜNLÜK yarışma kategori seçmez: bayrak açık VE sunucu-yalnız geçerli soru >= 30 ise set
-- yalnız sunucu-yalnız sorulardan çıkar (Ziman günlük sette bulunmaz: yerel banka eşlemesine
-- açık soru kalmaz). Bugünün seti önceden seçilmişse (verified_daily_question_sets) o gün
-- değişmez; yeni kural ertesi günün setinden başlar.
--
-- Göç düzeni: 2026-11-06_guvenlik_tur7.sql ile aynı. Altı işlevin TAM gövde md5'i bilinen
-- tabana (canlı = göç zinciri) eşitse yamalanır; tam nihai md5'teyse yedek satırı + md5
-- zinciri sağlamsa atlanır; başka her durum göçü durdurur. Eski gövde ve md5'i
-- olcek_tur3_yedek'e ('w10:<imza>'). Yeni nesne yalnız iki yardımcı + sütun/indeks.
begin;

set local lock_timeout = '10s';

do $w10_onkosul$
begin
  if to_regclass('public.questions') is null
     or to_regclass('public.categories') is null
     or to_regclass('public.app_runtime_config') is null
     or to_regclass('public.olcek_tur3_yedek') is null
     or to_regprocedure('public.weighted_question_pick(uuid[],uuid[],integer)') is null
     or to_regprocedure('public.async_duel_questions_payload(uuid[])') is null
     or to_regprocedure('public.present_async_duel_question_v2(uuid,integer)') is null
     or to_regprocedure('public._w2_daily_set(date)') is null
     or to_regprocedure('public.present_verified_daily_question(uuid,integer)') is null
     or to_regprocedure('public.get_room_questions_v2(uuid)') is null then
    raise exception 'w10: beklenen canlı nesneler eksik (2026-11-16_rekabet_sunum.sql ve room_duel_guards uygulanmış olmalı)';
  end if;
  alter table public.olcek_tur3_yedek enable row level security;
  revoke all on public.olcek_tur3_yedek from public, anon, authenticated;
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'w10: olcek_tur3_yedek anon/authenticated erişimine açık kalıyor';
  end if;
end;
$w10_onkosul$;

-- ---------------------------------------------------------------------------
-- 1. Şema (eklemeli; paket 4 göçü aynı üç sütun satırını `if not exists` ile içerir)
-- ---------------------------------------------------------------------------
alter table public.questions add column if not exists server_only boolean not null default false;
-- Sunucu satırının Türkçe karşılığı. prompt_tr: soru metni. options_tr: A, B, C, D
-- sırasıyla şıkların Türkçesi (jsonb dizi; şık sayısı kadar eleman).
alter table public.questions add column if not exists prompt_tr text;
alter table public.questions add column if not exists options_tr jsonb;
do $w10_kisit$
begin
  if not exists (select 1 from pg_constraint
                 where conrelid = 'public.questions'::regclass and conname = 'questions_options_tr_shape') then
    alter table public.questions add constraint questions_options_tr_shape
      check (options_tr is null
        or (jsonb_typeof(options_tr) = 'array' and jsonb_array_length(options_tr) between 2 and 4));
  end if;
end;
$w10_kisit$;
alter table public.app_runtime_config
  add column if not exists competitive_server_only_pool boolean not null default false;

-- Seçim indeksi (kategori + sunucu-yalnız + onaylı). Tablo birkaç bin satır; düz CREATE
-- INDEX milisaniyedir, ayrı CONCURRENTLY dosyası gerekmez.
create index if not exists questions_server_only_pool_idx
  on public.questions (category_id, server_only, is_approved);

-- ---------------------------------------------------------------------------
-- 2. Yardımcılar (istemciye kapalı)
-- ---------------------------------------------------------------------------
-- Rekabetçi aday süzgeci. Bayrak kapalıyken adayları AYNEN döndürür.
create or replace function public._w10_competitive_pool(p_candidate_ids uuid[], p_count integer)
returns uuid[]
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_on boolean;
  v_need integer := greatest(coalesce(p_count, 0), 1);
  v_kept uuid[];
begin
  select coalesce(c.competitive_server_only_pool, false) into v_on
  from public.app_runtime_config c where c.id = 1;
  if not coalesce(v_on, false) or coalesce(cardinality(p_candidate_ids), 0) = 0 then
    return coalesce(p_candidate_ids, '{}'::uuid[]);
  end if;
  -- Kategori başına: sunucu-yalnız aday sayısı >= 3 x gereken ise yalnız onlar; değilse
  -- kategorinin tüm adayları (ör. Ziman'da sunucu-yalnız soru yok).
  with cand as (
    select d.id, d.category_id, d.server_only
    from unnest(p_candidate_ids) as x(id)
    join public.questions d on d.id = x.id
  ),
  kat as (
    select category_id, count(*) filter (where server_only) as n
    from cand group by category_id
  )
  select array_agg(c.id) into v_kept
  from cand c
  join kat k on k.category_id is not distinct from c.category_id
  where c.server_only or k.n < v_need * 3;
  if coalesce(cardinality(v_kept), 0) < v_need then
    return p_candidate_ids;
  end if;
  return v_kept;
end;
$function$;

-- Günlük set: bayrak açık VE geçerli sunucu-yalnız soru >= 30 (10 x 3).
create or replace function public._w10_daily_server_only()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select coalesce((select c.competitive_server_only_pool from public.app_runtime_config c where c.id = 1), false)
    and (select count(*) from public.questions q join public.categories c on c.id = q.category_id
         where q.server_only and q.is_approved = true and c.is_active = true
           and q.correct_option in ('A', 'B', 'C', 'D')
           and coalesce(q.question_type, 'multiple_choice') in ('multiple_choice', 'true_false')
           and btrim(coalesce(q.prompt, '')) <> ''
           and btrim(coalesce(q.option_a, '')) not in ('', '-')
           and btrim(coalesce(q.option_b, '')) not in ('', '-')
           and (q.question_type = 'true_false' and q.correct_option in ('A', 'B')
             or coalesce(q.question_type, 'multiple_choice') = 'multiple_choice'
               and btrim(coalesce(q.option_c, '')) not in ('', '-')
               and btrim(coalesce(q.option_d, '')) not in ('', '-'))) >= 30;
$function$;

revoke all on function public._w10_competitive_pool(uuid[], integer) from public, anon, authenticated;
revoke all on function public._w10_daily_server_only() from public, anon, authenticated;
grant execute on function public._w10_competitive_pool(uuid[], integer) to service_role;
grant execute on function public._w10_daily_server_only() to service_role;

-- ---------------------------------------------------------------------------
-- 3. Altı işlevin yamalanması
-- ---------------------------------------------------------------------------
create temp table w10_durum (
  imza text primary key, gerekli boolean not null, sahip oid not null, nihai text not null,
  acl text, ayar text[], secdef boolean not null
) on commit drop;
do $w10_durum$
declare
  r record;
  v_def text;
  v_yedek text;
  v_eski text;
begin
  for r in select * from (values
    ('public.weighted_question_pick(uuid[],uuid[],integer)', '7a1ef55c1469b3414848bab693e46351', 'ff16787bfbe83192235dc6fd29bd14d5'),
    ('public.async_duel_questions_payload(uuid[])', '6140895944fc55f188e026252276aadb', 'daaaf734cc07dd012c1a611e9daddcea'),
    ('public.present_async_duel_question_v2(uuid,integer)', 'fe8a45c3b0c994966a7ee646ccac0440', '67a5fb9e6bc0b2d91758a992c0a8c485'),
    ('public._w2_daily_set(date)', 'd11065c8d9738e84c63953fb6c84d0a1', 'bab1959ced6d4999b6ff9ebea30770c3'),
    ('public.present_verified_daily_question(uuid,integer)', '1e9fc25dfbc839ffd14aa91317a99d1e', 'f2deef5e4a14d8b980e6d45ea151681e'),
    ('public.get_room_questions_v2(uuid)', '288a39c607fcccfb21f59619464f19e7', '66f904a2bc7a4c71b61f592e4205c053')
  ) t(imza, taban, nihai)
  loop
    v_def := pg_get_functiondef(to_regprocedure(r.imza));
    if md5(v_def) = r.taban then
      insert into w10_durum
      select r.imza, true, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
      from pg_proc p where p.oid = to_regprocedure(r.imza);
      continue;
    end if;
    if md5(v_def) <> r.nihai then
      raise exception 'w10: % gövdesi ne bilinen canlı taban ne de bu sürümün nihai gövdesi (md5 %); canlı gövde değişmiş olabilir, elle incele', r.imza, md5(v_def);
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w10:' || r.imza;
    v_eski := regexp_replace(coalesce(v_yedek, ''), E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yedek is null or v_eski = v_yedek
       or md5(v_eski) <> r.taban
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> r.taban
       or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') <> r.nihai then
      raise exception 'w10: % nihai gövdede ama yedek satırı/md5 zinciri sağlam değil; güvenli geri alma yok, elle incele', r.imza;
    end if;
    insert into w10_durum
    select r.imza, false, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
    from pg_proc p where p.oid = to_regprocedure(r.imza);
  end loop;
end;
$w10_durum$;

create or replace function pg_temp.w10_yama(p_imza text, p_eski text, p_yeni text)
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
    raise exception 'w10: işlev yok: %', p_imza;
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
    raise exception 'w10: % için bağlayıcı durumu beklenmiyor (eski % kez, yeni % kez; eski=1/yeni=0 beklenir); canlı gövde değişmiş ya da yarım yamalı, yeniden incele', p_imza, v_eski_n, v_yeni_n;
  end if;
  select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w10:' || p_imza;
  if v_yedek is null
     or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') is distinct from md5(v_def) then
    insert into public.olcek_tur3_yedek (ad, tanim, alindi)
    values ('w10:' || p_imza, v_def || E'\n-- md5:' || md5(v_def), now())
    on conflict (ad) do update set tanim = excluded.tanim, alindi = excluded.alindi;
  end if;
  execute replace(v_def, p_eski, p_yeni);
  update public.olcek_tur3_yedek
  set tanim = regexp_replace(tanim, E'\n-- yama-md5:[0-9a-f]+$', '')
               || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'w10:' || p_imza;
end;
$yama$;

-- 3.1 weighted_question_pick (taban: 2026-10-18_oda_kod_kategori.sql) — TEK ortak kapı.
select pg_temp.w10_yama(
  'public.weighted_question_pick(uuid[],uuid[],integer)',
  $e$    from unnest(coalesce(p_candidate_ids, '{}'::uuid[])) as x(id)$e$,
  $y$    from unnest(public._w10_competitive_pool(p_candidate_ids, p_count)) as x(id)$y$)
from w10_durum d
where d.imza = 'public.weighted_question_pick(uuid[],uuid[],integer)' and d.gerekli;

-- 3.2 async_duel_questions_payload (taban: 2026-10-13_friend_challenge.sql): düello + turnuva
-- soru yükü Türkçe karşılığı da taşır.
select pg_temp.w10_yama(
  'public.async_duel_questions_payload(uuid[])',
  $e$      'difficulty', q.difficulty
    ) order by ord.idx$e$,
  $y$      'difficulty', q.difficulty,
      'prompt_tr', q.prompt_tr,
      'options_tr', q.options_tr
    ) order by ord.idx$y$)
from w10_durum d
where d.imza = 'public.async_duel_questions_payload(uuid[])' and d.gerekli;

-- 3.3 present_async_duel_question_v2 (taban: 2026-11-01_room_duel_guards.sql)
select pg_temp.w10_yama(
  'public.present_async_duel_question_v2(uuid,integer)',
  $e$    'difficulty', q.difficulty) into question$e$,
  $y$    'difficulty', q.difficulty,
    'prompt_tr', q.prompt_tr, 'options_tr', q.options_tr) into question$y$)
from w10_durum d
where d.imza = 'public.present_async_duel_question_v2(uuid,integer)' and d.gerekli;

-- 3.4 _w2_daily_set (taban: 2026-11-16_rekabet_sunum.sql)
select pg_temp.w10_yama(
  'public._w2_daily_set(date)',
  $e$    where q.is_approved = true and c.is_active = true
      and q.correct_option in ('A', 'B', 'C', 'D')$e$,
  $y$    where q.is_approved = true and c.is_active = true
      -- (2026-11-17) Bayrak açık ve sunucu-yalnız havuz yeterliyse yalnız o havuz.
      and (q.server_only or not (select public._w10_daily_server_only()))
      and q.correct_option in ('A', 'B', 'C', 'D')$y$)
from w10_durum d
where d.imza = 'public._w2_daily_set(date)' and d.gerekli;

-- 3.5 present_verified_daily_question (taban: 2026-11-16_rekabet_sunum.sql)
select pg_temp.w10_yama(
  'public.present_verified_daily_question(uuid,integer)',
  $e$    'difficulty', q.difficulty) into v_question$e$,
  $y$    'difficulty', q.difficulty,
    'prompt_tr', q.prompt_tr, 'options_tr', q.options_tr) into v_question$y$)
from w10_durum d
where d.imza = 'public.present_verified_daily_question(uuid,integer)' and d.gerekli;

-- 3.6 get_room_questions_v2 (taban: 2026-11-16_rekabet_sunum.sql): içeriği AÇIK satırlara
-- Türkçe karşılık eklenir (gizli satırın kimliği opak: eşleşme olmaz, sızıntı olmaz).
select pg_temp.w10_yama(
  'public.get_room_questions_v2(uuid)',
  $e$        public._w2_opaque_id(p_room_id::text, coalesce((row_data ->> 'index')::integer, 0))::text));
    end if;$e$,
  $y$        public._w2_opaque_id(p_room_id::text, coalesce((row_data ->> 'index')::integer, 0))::text));
    elsif coalesce(row_data ->> 'prompt', '') <> '' then
      row_data := row_data || coalesce((
        select jsonb_build_object('prompt_tr', q.prompt_tr, 'options_tr', q.options_tr)
        from public.questions q where q.id = (row_data ->> 'id')::uuid), '{}'::jsonb);
    end if;$y$)
from w10_durum d
where d.imza = 'public.get_room_questions_v2(uuid)' and d.gerekli;

-- ---------------------------------------------------------------------------
-- 4. Son denetim: sahip / ACL / search_path değişmedi, nihai md5 tam, anon/PUBLIC kapalı;
--    yardımcılar istemciye kapalı.
-- ---------------------------------------------------------------------------
do $w10_son$
declare
  r record;
  v_imza text;
begin
  for r in select * from w10_durum loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.imza)
        and p.proowner = r.sahip
        and p.prosecdef = r.secdef
        and p.proconfig is not distinct from r.ayar
        and p.proacl::text is not distinct from r.acl
    ) then
      raise exception 'w10: % sahip / search_path / ACL doğrulanamadı (yama bunları değiştirdi)', r.imza;
    end if;
    if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then
      raise exception 'w10: % yama sonrası gövde beklenen nihai md5 değil', r.imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
       or has_function_privilege('public', to_regprocedure(r.imza), 'execute') then
      raise exception 'w10: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
  foreach v_imza in array array['public._w10_competitive_pool(uuid[],integer)', 'public._w10_daily_server_only()'] loop
    if has_function_privilege('anon', v_imza, 'execute') or has_function_privilege('authenticated', v_imza, 'execute')
       or has_function_privilege('public', v_imza, 'execute') then
      raise exception 'w10: yardımcı % istemciye açık', v_imza;
    end if;
  end loop;
end;
$w10_son$;

commit;
