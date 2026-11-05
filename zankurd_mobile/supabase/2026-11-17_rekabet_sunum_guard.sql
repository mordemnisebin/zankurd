-- 2.1.2 W2 GUARD: eski (cevap anahtarı sızdıran) rekabetçi yolların KAPATILMASI.
-- YAZILDI, CANLIYA UYGULANMADI. SIRA: 2026-11-16_rekabet_sunum.sql önce; bu göç ancak
-- 2.1.2 istemcisi (yeni RPC'leri kullanan) mağazalarda YAYILDIKTAN SONRA uygulanır:
-- build 45 ve öncesi günlük yarışmayı eski yoldan başlatır; bu göçten sonra o yol
-- 'Daily rounds start with start_verified_daily_v2' ile reddedilir (eski istemci günlük
-- sıralamaya yazamaz, solo/oda/düello çalışır). Geri alma: geri_al/2026-11-17_rekabet_sunum_guard_geri.sql
--
-- Ne kapanır:
--  1. start_verified_quiz(.., p_daily => true): günlük tur artık yalnız start_verified_daily_v2
--     ile başlar (kimlik listesini istemci getiremez). [gövde yaması]
--  2. get_verified_daily_question_ids(): authenticated EXECUTE geri alınır (10 gerçek kimlik
--     sunumdan önce verilmez). [yalnız ACL]
--  3. get_room_questions(uuid): gizli (sunulmamış) sorunun kimliği opak sıra belirteci olur.
--     [gövde yaması]
--  4. _guard_20261101_hide_duel_content(jsonb): start/create/accept/resume_async_duel (ve tur9
--     aşırı yüklemeleri) gizli sorunun kimliği opak belirteç olur. [gövde yaması; dört dış
--     sarmalayıcı aynı yardımcıyı çağırır]
--  5. room_questions tablosundan authenticated/anon SELECT geri alınır: katılımcı RLS ile
--     doğrudan tablodan TÜM gerçek soru kimliklerini okuyabiliyordu (istemci tabloyu hiç
--     sorgulamaz; tüm RPC'ler SECURITY DEFINER). Göç, room_questions'a başvuran
--     SECURITY INVOKER işlev/görünüm varsa DURUR.
--
-- Her gövde yaması: TAM gövde md5 ön koşulu (aşağıdaki değerler PGlite'ta göç zincirinden
-- yeniden kurularak hesaplanır; test: tool/test_rekabet_sunum_guard_local.mjs doğrular),
-- olcek_tur3_yedek ('w2:<imza>'), yama md5 zinciri, sahip/ACL/search_path/anon son denetimi,
-- ya hep ya hiç. CANLIDA ÖNCE: select md5(pg_get_functiondef('<imza>'::regprocedure)) —
-- taban ya da nihai md5'e eşit olmalı (uyuşmazsa göç kendisi durur).
begin;

set local lock_timeout = '10s';

do $w2g_onkosul$
begin
  if to_regprocedure('public._w2_opaque_id(text,integer)') is null
     or to_regprocedure('public.start_verified_daily_v2()') is null
     or to_regprocedure('public.get_room_questions_v2(uuid)') is null
     or to_regprocedure('public.start_async_duel_masked(text,uuid)') is null
     or to_regprocedure('public.get_verified_daily_question_ids()') is null
     or to_regprocedure('public._guard_20261101_hide_duel_content(jsonb)') is null
     or to_regclass('public.room_questions') is null
     or to_regclass('public.olcek_tur3_yedek') is null then
    raise exception 'w2 guard: beklenen canlı nesneler eksik (2026-11-16_rekabet_sunum.sql uygulandı mı?); göçü uygulamadan önce incele';
  end if;
  alter table public.olcek_tur3_yedek enable row level security;
  revoke all on public.olcek_tur3_yedek from public, anon, authenticated;
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'w2 guard: olcek_tur3_yedek anon/authenticated erişimine açık kalıyor';
  end if;
  if exists (
    select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
    where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
      and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
  ) then
    raise exception 'w2 guard: olcek_tur3_yedek sahibi dışında alıcıya açık (relacl)';
  end if;
  -- room_questions SELECT geri alınacak: SECURITY INVOKER bir işlev ya da görünüm bu tabloyu
  -- okuyorsa (istemci rolüyle) kırılırdı.
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and not p.prosecdef and p.prosrc ilike '%room_questions%'
  ) then
    raise exception 'w2 guard: room_questions okuyan SECURITY INVOKER işlev var; SELECT geri alınamaz, elle incele';
  end if;
  if exists (
    select 1 from pg_views v where v.schemaname = 'public' and v.definition ilike '%room_questions%'
  ) then
    raise exception 'w2 guard: room_questions okuyan görünüm var; SELECT geri alınamaz, elle incele';
  end if;
end;
$w2g_onkosul$;

create temp table w2g_durum (
  imza text primary key, gerekli boolean not null, sahip oid not null, nihai text not null,
  acl text, ayar text[], secdef boolean not null
) on commit drop;
do $w2g_durum$
declare
  r record;
  v_def text;
  v_yedek text;
  v_eski text;
begin
  for r in select * from (values
    ('public.start_verified_quiz(uuid,uuid[],boolean,uuid)', 'fe6fdc90e98784766eba52df38868bc1', '503b195df0bea45d8153f255ab2fce05'),
    ('public.get_room_questions(uuid)', '47f01a336b38daa3b3b7462bf01084ba', '8012be19dba044fe1a337dc20131c9b4'),
    ('public._guard_20261101_hide_duel_content(jsonb)', 'd92dba6ec954a6a2d8963319a4585d93', 'd83de49fa8b5fc54e3878d4a4c1e0f10')
  ) t(imza, taban, nihai)
  loop
    v_def := pg_get_functiondef(to_regprocedure(r.imza));
    if md5(v_def) = r.taban then
      insert into w2g_durum
      select r.imza, true, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
      from pg_proc p where p.oid = to_regprocedure(r.imza);
      continue;
    end if;
    if md5(v_def) <> r.nihai then
      raise exception 'w2 guard: % gövdesi ne bilinen canlı taban ne de bu sürümün nihai gövdesi (md5 %); canlı gövde değişmiş olabilir, elle incele', r.imza, md5(v_def);
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w2:' || r.imza;
    v_eski := regexp_replace(coalesce(v_yedek, ''), E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yedek is null or v_eski = v_yedek
       or md5(v_eski) <> r.taban
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> r.taban
       or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') <> r.nihai then
      raise exception 'w2 guard: % nihai gövdede ama yedek satırı/md5 zinciri sağlam değil; güvenli geri alma yok, elle incele', r.imza;
    end if;
    insert into w2g_durum
    select r.imza, false, p.proowner, r.nihai, p.proacl::text, p.proconfig, p.prosecdef
    from pg_proc p where p.oid = to_regprocedure(r.imza);
  end loop;
end;
$w2g_durum$;

create or replace function pg_temp.w2g_yama(p_imza text, p_eski text, p_yeni text)
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
    raise exception 'w2 guard: işlev yok: %', p_imza;
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
    raise exception 'w2 guard: % için bağlayıcı durumu beklenmiyor (eski % kez, yeni % kez; eski=1/yeni=0 beklenir); canlı gövde değişmiş ya da yarım yamalı, yeniden incele', p_imza, v_eski_n, v_yeni_n;
  end if;
  select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w2:' || p_imza;
  if v_yedek is null
     or substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$') is distinct from md5(v_def) then
    insert into public.olcek_tur3_yedek (ad, tanim, alindi)
    values ('w2:' || p_imza, v_def || E'\n-- md5:' || md5(v_def), now())
    on conflict (ad) do update set tanim = excluded.tanim, alindi = excluded.alindi;
  end if;
  execute replace(v_def, p_eski, p_yeni);
  update public.olcek_tur3_yedek
  set tanim = regexp_replace(tanim, E'\n-- yama-md5:[0-9a-f]+$', '')
               || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'w2:' || p_imza;
end;
$yama$;

-- 1. Günlük tur eski yoldan başlamaz.
select pg_temp.w2g_yama(
  'public.start_verified_quiz(uuid,uuid[],boolean,uuid)',
  $e$  then raise exception 'Invalid round'; end if;
$e$,
  $y$  then raise exception 'Invalid round'; end if;
  -- (2.1.2 guard) Günlük tur yalnız start_verified_daily_v2 ile: sunucu soruları seçer, kimlik istemciden gelmez.
  if p_daily then raise exception 'Daily rounds start with start_verified_daily_v2'; end if;
$y$)
from w2g_durum d
where d.imza = 'public.start_verified_quiz(uuid,uuid[],boolean,uuid)' and d.gerekli;

-- 3. Oda: gizli sorunun kimliği opak belirteç.
select pg_temp.w2g_yama(
  'public.get_room_questions(uuid)',
  $e$return next jsonb_build_object('id', row_data->>'id',
$e$,
  $y$return next jsonb_build_object('id', public._w2_opaque_id(p_room_id::text, question_position)::text,
$y$)
from w2g_durum d
where d.imza = 'public.get_room_questions(uuid)' and d.gerekli;

-- 4. Düello: dört dış sarmalayıcının ortak yardımcısı gizli kimliği opaklaştırır.
select pg_temp.w2g_yama(
  'public._guard_20261101_hide_duel_content(jsonb)',
  $e$jsonb_build_object('id', q->>'id',
$e$,
  $y$jsonb_build_object('id', public._w2_opaque_id(coalesce(p_payload->>'duel_id', ''), (ord - 1)::integer)::text,
$y$)
from w2g_durum d
where d.imza = 'public._guard_20261101_hide_duel_content(jsonb)' and d.gerekli;

-- 2. Günün 10 gerçek kimliğini veren işlev istemciye kapanır (v2 kendi yardımcısını kullanır).
revoke execute on function public.get_verified_daily_question_ids() from public, anon, authenticated;
grant execute on function public.get_verified_daily_question_ids() to service_role;

-- 5. Katılımcı doğrudan tablodan gerçek soru kimliklerini okuyamaz.
revoke select on public.room_questions from anon, authenticated;

do $w2g_son$
declare r record;
begin
  for r in select * from w2g_durum loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.imza)
        and p.proowner = r.sahip
        and p.prosecdef = r.secdef
        and p.proconfig is not distinct from r.ayar
        and p.proacl::text is not distinct from r.acl
    ) then
      raise exception 'w2 guard: % sahip / search_path / ACL doğrulanamadı (yama bunları değiştirdi)', r.imza;
    end if;
    if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then
      raise exception 'w2 guard: % yama sonrası gövde beklenen nihai md5 değil (bulunan %)', r.imza, md5(pg_get_functiondef(to_regprocedure(r.imza)));
    end if;
    if has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
       or has_function_privilege('public', to_regprocedure(r.imza), 'execute') then
      raise exception 'w2 guard: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
  if has_function_privilege('authenticated', 'public.get_verified_daily_question_ids()', 'execute')
     or has_function_privilege('anon', 'public.get_verified_daily_question_ids()', 'execute') then
    raise exception 'w2 guard: get_verified_daily_question_ids hâlâ istemciye açık';
  end if;
  if has_table_privilege('authenticated', 'public.room_questions', 'select')
     or has_table_privilege('anon', 'public.room_questions', 'select') then
    raise exception 'w2 guard: room_questions SELECT hâlâ istemciye açık';
  end if;
  -- Yeni yol çalışmaya devam etmeli: v2 işlevleri çağıran role açık.
  if not has_function_privilege('authenticated', 'public.start_verified_daily_v2()', 'execute')
     or not has_function_privilege('authenticated', 'public.get_room_questions_v2(uuid)', 'execute') then
    raise exception 'w2 guard: yeni yol (v2) authenticated için kapalı';
  end if;
end;
$w2g_son$;

commit;
