-- İlerleme anlık görüntüsü şema sürümü 2 + yapısal ret (2.1.2 veri güvenliği).
-- Geri alma: geri_al/2026-11-10_ilerleme_sema_v3_geri.sql
--
-- NİÇİN (GPT-6 Pro ALAN 5, tur9'da "anlık görüntü sürümü/boyut sözleşmesi" diye
-- atlananlar):
--  1. `words` alanı sürüm artmadan eklenmişti. Alanı bilmeyen eski istemci
--     bütün görüntüyü yeniden yazıp kelime yedeğini silebiliyordu; sunucu
--     "daha eski şemalı yazım daha yeni şemalı kaydı ezemez" kuralını hiçbir
--     yolda uygulamıyordu. İstemci şimdi sürümü 2'ye çıkardı (seri dondurma
--     defteri, öğrenme hedefi zamanı, kelime silme işaretleri); bu göç sunucu
--     yarısıdır.
--  2. Sunucu boyut sınırını (262.144 bayt) İSTİSNA ile reddediyordu; istemci
--     bunu hata sayıp bütün yedeği (seri, rozet, kelime) bırakıyordu. Yeni
--     işlev reddi YAPISAL döner (`too_large`), istemci çekirdeği bölüp yeniden
--     gönderir.
--
-- NE EKLER (YALNIZ YENİ nesne; mevcut hiçbir işlevin gövdesine dokunmaz):
--   * public.progress_snapshot_version(jsonb): görüntünün `v` alanı (yoksa 0).
--   * public.player_progress_schema_guard() + player_progress üzerinde BEFORE UPDATE
--     tetikleyicisi: HER yoldan (save_my_progress, save_my_progress_v2, v3, doğrudan
--     SQL) gelen yazımda yeni sürüm eskisinden KÜÇÜKSE yazımı hata ile durdurur.
--     Bu, eski istemcinin (build 45 ve öncesi) ve koşulsuz yazan eski
--     `save_my_progress`'in v2 kaydı ezmesine karşı arka kapıyı kapatır.
--   * public.save_my_progress_v3(jsonb, timestamptz): v2 ile aynı sürüm denetimi
--     (iyimser eşzamanlılık) + yapısal ret: {ok:false, stale_schema:true} ve
--     {ok:false, too_large:true, bytes, limit}. Aynı advisory kilit anahtarını
--     kullanır, yani v2 ile aralarında yarış yoktur.
--
-- Eski istemci sözleşmesi (build 45 ve öncesi): save_my_progress,
-- save_my_progress_v2 ve get_my_progress AYNEN durur. Eski istemci bir v2 kaydı
-- okuyunca (`v` > 1) kaydı ayrıştırmaz ve yazmaz (istemcide zaten böyle:
-- ProgressSnapshot.tryParse) — yerel kullanımı sürer, yalnız bulut yedeği
-- güncellemeye kadar durur; yazarsa (yarışta) tetikleyici durdurur. Yeni
-- işlev yokken (PGRST202) yeni istemci v2'ye düşer.
--
-- Bu göç YENİ nesne yarattığı için tur7'deki "yamalanacak gövdenin md5'i" ön koşulu
-- ve olcek_tur3_yedek yedeği gerekmez (tur9 ile aynı gerekçe); onun yerine
-- çağrılan mevcut işlevlerin md5'i göç içinde okunup SONDA değişmediği denetlenir.
begin;

set local lock_timeout = '10s';

do $sema_onkosul$
begin
  if to_regclass('public.player_progress') is null
     or to_regclass('public.profiles') is null
     or to_regprocedure('public.get_my_progress()') is null
     or to_regprocedure('public.save_my_progress(jsonb)') is null
     or to_regprocedure('public.save_my_progress_v2(jsonb,timestamptz)') is null then
    raise exception 'sema_v3: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
  -- Yaratılacak nesnelerden biri zaten varsa durur (geri alma yalnız bu göçün
  -- yarattığını kaldırsın).
  if to_regprocedure('public.progress_snapshot_version(jsonb)') is not null
     or to_regprocedure('public.player_progress_schema_guard()') is not null
     or to_regprocedure('public.save_my_progress_v3(jsonb,timestamptz)') is not null
     or exists (
       select 1 from pg_trigger t
       where t.tgrelid = 'public.player_progress'::regclass
         and t.tgname = 'player_progress_schema_guard' and not t.tgisinternal) then
    raise exception 'sema_v3: yaratılacak nesnelerden biri zaten var; göç durdu';
  end if;
end
$sema_onkosul$;

-- Çağrılan/yanında yaşayan mevcut işlevlerin md5'i (sonda değişmediği doğrulanır).
create temp table sema_mevcut (imza text primary key, md5 text not null) on commit drop;
insert into sema_mevcut
select s, md5(pg_get_functiondef(to_regprocedure(s))) from unnest(array[
  'public.get_my_progress()', 'public.save_my_progress(jsonb)',
  'public.save_my_progress_v2(jsonb,timestamptz)']) s;

-- Görüntünün şema sürümü: `v` sayı değilse ya da yoksa 0 (en eski).
create function public.progress_snapshot_version(p_snapshot jsonb)
returns integer
language sql
immutable
set search_path to 'public', 'pg_temp'
as $function$
  select case
    when p_snapshot is not null
         and jsonb_typeof(p_snapshot -> 'v') = 'number'
      then least(greatest(floor((p_snapshot ->> 'v')::numeric), 0), 1000)::integer
    else 0
  end;
$function$;

-- Arka kapı: hangi işlev yazarsa yazsın, daha eski şemalı görüntü daha yeni
-- şemalı kaydı ezemez.
create function public.player_progress_schema_guard()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
begin
  if public.progress_snapshot_version(new.snapshot)
     < public.progress_snapshot_version(old.snapshot) then
    raise exception 'Progress snapshot schema is older than the stored one';
  end if;
  return new;
end;
$function$;

create trigger player_progress_schema_guard
  before update of snapshot on public.player_progress
  for each row execute function public.player_progress_schema_guard();

create function public.save_my_progress_v3(
  p_snapshot jsonb,
  p_expected_updated_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_cur timestamptz;
  v_stored jsonb;
  v_bytes integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_snapshot is null or jsonb_typeof(p_snapshot) <> 'object' then
    raise exception 'Invalid snapshot';
  end if;

  -- Boyut reddi YAPISAL: istemci çekirdeği bölüp yeniden gönderir.
  v_bytes := octet_length(p_snapshot::text);
  if v_bytes > 262144 then
    return jsonb_build_object(
      'ok', false, 'too_large', true, 'bytes', v_bytes, 'limit', 262144);
  end if;

  perform 1 from public.profiles where id = v_uid;
  if not found then
    raise exception 'Profile missing';
  end if;

  -- v2 ile AYNI kilit: iki sürüm birbirine karşı da sıraya girer.
  perform pg_advisory_xact_lock(
    hashtextextended('progress:' || v_uid::text, 0));

  select updated_at, snapshot into v_cur, v_stored
  from public.player_progress
  where player_id = v_uid;

  if found then
    -- Daha eski şema daha yeniyi ezemez (tetikleyici de aynı kuralı uygular).
    if public.progress_snapshot_version(p_snapshot)
       < public.progress_snapshot_version(v_stored) then
      return jsonb_build_object(
        'ok', false,
        'stale_schema', true,
        'stored_version', public.progress_snapshot_version(v_stored),
        'updated_at', v_cur
      );
    end if;
    if p_expected_updated_at is null
       or date_trunc('milliseconds', v_cur)
          <> date_trunc('milliseconds', p_expected_updated_at) then
      return jsonb_build_object(
        'ok', false,
        'conflict', true,
        'updated_at', v_cur
      );
    end if;
  end if;

  insert into public.player_progress (player_id, snapshot, updated_at)
  values (v_uid, p_snapshot, v_now)
  on conflict (player_id) do update
    set snapshot = excluded.snapshot,
        updated_at = excluded.updated_at;

  return jsonb_build_object('ok', true, 'updated_at', v_now);
end;
$function$;

revoke all on function public.save_my_progress_v3(jsonb, timestamptz)
  from public, anon;
grant execute on function public.save_my_progress_v3(jsonb, timestamptz)
  to authenticated;
revoke all on function public.progress_snapshot_version(jsonb) from public, anon, authenticated;
revoke all on function public.player_progress_schema_guard() from public, anon, authenticated;

do $sema_son$
declare
  v_owner oid := (select c.relowner from pg_class c where c.oid = 'public.player_progress'::regclass);
begin
  -- v3: SECURITY DEFINER, sabit search_path, tablo sahibiyle aynı sahip,
  -- anon/PUBLIC kapalı, authenticated açık.
  if not exists (
    select 1 from pg_proc p
    where p.oid = to_regprocedure('public.save_my_progress_v3(jsonb,timestamptz)')
      and p.prosecdef
      and p.proconfig = array['search_path=public, pg_temp']
      and p.proowner = v_owner
  ) then
    raise exception 'sema_v3: save_my_progress_v3 SECURITY DEFINER / search_path / sahip doğrulanamadı';
  end if;
  if has_function_privilege('anon', 'public.save_my_progress_v3(jsonb,timestamptz)', 'execute')
     or has_function_privilege('public', 'public.save_my_progress_v3(jsonb,timestamptz)', 'execute')
     or not has_function_privilege('authenticated', 'public.save_my_progress_v3(jsonb,timestamptz)', 'execute') then
    raise exception 'sema_v3: save_my_progress_v3 EXECUTE ACL beklenen değil';
  end if;
  -- Yardımcı ve tetikleyici işlevi: sabit search_path, sahip aynı, istemci
  -- rollerine (anon/authenticated/PUBLIC) kapalı.
  if exists (
    select 1 from pg_proc p
    where p.oid in (
            to_regprocedure('public.progress_snapshot_version(jsonb)'),
            to_regprocedure('public.player_progress_schema_guard()'))
      and (p.proconfig is distinct from array['search_path=public, pg_temp']
           or p.proowner <> v_owner)
  ) then
    raise exception 'sema_v3: yardımcı/tetikleyici işlev search_path ya da sahip beklenen değil';
  end if;
  if has_function_privilege('anon', 'public.progress_snapshot_version(jsonb)', 'execute')
     or has_function_privilege('authenticated', 'public.progress_snapshot_version(jsonb)', 'execute')
     or has_function_privilege('public', 'public.progress_snapshot_version(jsonb)', 'execute')
     or has_function_privilege('anon', 'public.player_progress_schema_guard()', 'execute')
     or has_function_privilege('authenticated', 'public.player_progress_schema_guard()', 'execute')
     or has_function_privilege('public', 'public.player_progress_schema_guard()', 'execute') then
    raise exception 'sema_v3: yardımcı/tetikleyici işlevi istemci rollerine açık';
  end if;
  -- Tetikleyici var, etkin, BEFORE UPDATE ve satır başına.
  if not exists (
    select 1 from pg_trigger t
    where t.tgrelid = 'public.player_progress'::regclass
      and t.tgname = 'player_progress_schema_guard'
      and t.tgenabled = 'O'
      and (t.tgtype & 2) = 2      -- BEFORE
      and (t.tgtype & 16) = 16    -- UPDATE
      and (t.tgtype & 1) = 1      -- ROW
  ) then
    raise exception 'sema_v3: player_progress_schema_guard tetikleyicisi beklenen değil';
  end if;
  -- Tablo istemci rollerine hâlâ kapalı.
  if has_table_privilege('anon', 'public.player_progress', 'select,insert,update,delete')
     or has_table_privilege('authenticated', 'public.player_progress', 'select,insert,update,delete') then
    raise exception 'sema_v3: player_progress anon/authenticated erişimine açık';
  end if;
  -- Mevcut işlevlere dokunulmadı.
  if exists (
    select 1 from sema_mevcut m
    where md5(pg_get_functiondef(to_regprocedure(m.imza))) <> m.md5
  ) then
    raise exception 'sema_v3: mevcut bir işlevin gövdesi değişti (bu göç değiştirmemeliydi)';
  end if;
end
$sema_son$;

commit;
