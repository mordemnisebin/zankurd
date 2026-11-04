-- İdempotency / dayanıklı yazım turu (GPT-6 Pro ALAN 2 + ALAN 5 bulgularından
-- "sunucuda işlem kimliği gerekir" diye atlananlar). Canlıda (2026-11-04, applied.md ✅).
-- Geri alma: geri_al/2026-11-07_idempotency_tur9_geri.sql
--
-- Bu göç YALNIZ YENİ nesne yaratır (1 tablo, 3 işlev); mevcut hiçbir işlevin
-- gövdesine, imzasına ya da dönüş biçimine dokunmaz. Bu yüzden tur7'deki gibi
-- "yamalanacak gövdenin tam md5'i" ön koşulu yoktur; onun yerine (a) çağrılan
-- mevcut işlevlerin varlığı ve (b) göç sonunda bu işlevlerin md5'inin DEĞİŞMEDİĞİ
-- denetlenir (canlı DB'ye bağlanmadan yazılabildiği için gövde tabanı gerekmez;
-- canlıda md5'ler göç içinde okunup göçün sonunda karşılaştırılır).
--
-- Eski istemci (build 43) sözleşmesi: award_spin_coins(), claim_extra_spin(),
-- start_async_duel(text) ve create_async_duel_challenge(text, uuid) AYNEN durur
-- ve çalışır. Yeni işlevler farklı ad (spin_wheel_once) ya da FARKLI PARAMETRE
-- SAYISI (aşırı yükleme) ile yaşar; eski çağrı (anahtarsız) hiç yeni işleve
-- düşmez. Yeni istemci anahtar üretip kalıcılaştırır; yeni işlev yoksa (PGRST202)
-- eski yola düşer.
--
-- Kusurlar ve çözümler
--  1. Günlük çark (supabase_zankurd_repository.dart awardSpinCoins): sunucuda dönüp
--     yanıtı kaybolan ilk çağrının yeniden denemesi award_spin_coins'ten "bugün
--     kullanıldı" alıyor, istemci OTOMATİK claim_extra_spin çağırıp SATIN ALINMIŞ
--     başka bir hakkı tüketiyordu. spin_wheel_once(p_idempotency_key): aynı
--     anahtarla ikinci çağrı ÖNCEKİ ödülü döndürür, hiçbir şey yazmaz; günlük
--     hak ile ek hak tek işlemde, tek kayıtla çözülür.
--  2. Düello oluşturma (async_duel_play_screen / quiz_result_screen): yanıtı kaybolan
--     start_async_duel / create_async_duel_challenge yeniden denemede yeni düello
--     açıyordu (açık düello kotasını dolduruyor). Yeni aşırı yüklemeler p_request_id
--     alır; aynı kimlikle tekrar ÖNCEKİ düelloyu (resume_my_async_duel ile güncel
--     hâliyle) döndürür.
--
-- Kayıt defteri: public.idempotent_ops (user_id, op_key) birincil anahtarlı; yalnız
-- SECURITY DEFINER işlevler yazar/okur (RLS açık, istemci rollerine hiçbir yetki yok).
-- 14 günden eski satırlar, işlevi çağıran kullanıcının kendi satırları için çağrı
-- sırasında temizlenir (tablo sınırsız büyümez; tarama kullanıcının birkaç satırıdır).
--
-- ATLANAN (ayrı göç / ayrı karar; ayrıntı applied.md): seri dondurma bakiyesi defteri
-- (anlık görüntü şeması), anlık görüntü sürümü/tombstone, ALAN 4 config kilidi
-- (canlı gövde md5'i gerekir), öğrenme hedefi sürümü, boyut sözleşmesi.
begin;

set local lock_timeout = '10s';

do $tur9_onkosul$
begin
  if to_regclass('public.profiles') is null
     or to_regprocedure('public.award_spin_coins()') is null
     or to_regprocedure('public.claim_extra_spin()') is null
     or to_regprocedure('public.start_async_duel(text)') is null
     or to_regprocedure('public.create_async_duel_challenge(text,uuid)') is null
     or to_regprocedure('public.resume_my_async_duel(uuid)') is null
     or to_regclass('auth.users') is null then
    raise exception 'tur9: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
  -- Henüz uygulanmamışken yaratılacak nesnelerden biri zaten varsa durur (geri alma
  -- yalnız bu göçün yarattığını kaldırsın; var olan sessizce ezilmesin).
  if to_regclass('public.idempotent_ops') is not null
     or to_regprocedure('public.spin_wheel_once(text)') is not null
     or to_regprocedure('public.start_async_duel(text,uuid)') is not null
     or to_regprocedure('public.create_async_duel_challenge(text,uuid,uuid)') is not null then
    raise exception 'tur9: yaratılacak nesnelerden biri zaten var; göç durdu';
  end if;
end
$tur9_onkosul$;

-- Çağrılan mevcut işlevlerin md5'i (göç sonunda değişmediği doğrulanır).
create temp table tur9_mevcut (imza text primary key, md5 text not null) on commit drop;
insert into tur9_mevcut
select s, md5(pg_get_functiondef(to_regprocedure(s))) from unnest(array[
  'public.award_spin_coins()', 'public.claim_extra_spin()',
  'public.start_async_duel(text)', 'public.create_async_duel_challenge(text,uuid)',
  'public.resume_my_async_duel(uuid)']) s;

create table public.idempotent_ops (
  user_id uuid not null references auth.users (id) on delete cascade,
  op_key text not null,
  kind text not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key (user_id, op_key)
);
alter table public.idempotent_ops enable row level security;
revoke all on table public.idempotent_ops from public, anon, authenticated;
grant all on table public.idempotent_ops to service_role;

-- 1. Çark: günlük hak, bitince satın alınmış ek hak; aynı anahtar = aynı ödül.
create function public.spin_wheel_once(p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_prev jsonb;
  v_ok boolean;
  v_amount integer;
  v_extra jsonb;
  v_result jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;
  if v_key is null or length(v_key) < 8 or length(v_key) > 200 then
    return jsonb_build_object('success', false, 'error', 'invalid key');
  end if;

  -- Aynı anahtarın eşzamanlı iki çağrısı sıraya girer; ikinci çağrı birincinin
  -- kaydını görür.
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':idem:spin:' || v_key, 0));

  select o.result into v_prev
  from public.idempotent_ops o
  where o.user_id = v_uid and o.op_key = 'spin:' || v_key;
  if found then
    return v_prev || jsonb_build_object('replayed', true);
  end if;

  delete from public.idempotent_ops
  where user_id = v_uid and created_at < now() - interval '14 days';

  -- Eski istemcinin sırası: önce günlük hak, olmazsa satın alınmış ek hak.
  select a.success, a.reward_amount into v_ok, v_amount from public.award_spin_coins() a;
  if coalesce(v_ok, false) and coalesce(v_amount, 0) > 0 then
    v_result := jsonb_build_object('success', true, 'amount', v_amount, 'kind', 'daily');
  else
    v_extra := public.claim_extra_spin();
    v_amount := coalesce((v_extra ->> 'amount')::integer, 0);
    if v_amount > 0 then
      v_result := jsonb_build_object('success', true, 'amount', v_amount, 'kind', 'extra');
    else
      -- Kesin ret: hak yok. Kayda YAZILMAZ (anahtar sonradan bir ek hak
      -- satın alınınca yeniden denenebilir; istemci kesin retle anahtarı atar).
      return jsonb_build_object('success', false, 'amount', 0, 'kind', 'none',
                                'no_spins', true);
    end if;
  end if;

  insert into public.idempotent_ops (user_id, op_key, kind, result)
  values (v_uid, 'spin:' || v_key, 'spin', v_result);
  return v_result;
end;
$function$;

-- 2a. Rastgele eşleşmeli düello: aynı istek kimliği = aynı düello.
create function public.start_async_duel(p_category text, p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_prev jsonb;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_request_id is null then
    return public.start_async_duel(p_category);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':idem:duel:' || p_request_id::text, 0));

  select o.result into v_prev
  from public.idempotent_ops o
  where o.user_id = v_uid and o.op_key = 'duel:' || p_request_id::text;
  if found then
    begin
      -- Güncel hâli (eşleşmiş olabilir); başarısızsa ilk yanıt.
      return public.resume_my_async_duel((v_prev ->> 'duel_id')::uuid);
    exception when others then
      return v_prev;
    end;
  end if;

  delete from public.idempotent_ops
  where user_id = v_uid and created_at < now() - interval '14 days';

  v_result := public.start_async_duel(p_category);
  if v_result ->> 'duel_id' is not null then
    insert into public.idempotent_ops (user_id, op_key, kind, result)
    values (v_uid, 'duel:' || p_request_id::text, 'duel', v_result);
  end if;
  return v_result;
end;
$function$;

-- 2b. Meydan okuma: aynı istek kimliği = aynı meydan okuma (aynı bağlantı kodu).
create function public.create_async_duel_challenge(
  p_category text, p_friend_id uuid, p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_prev jsonb;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_request_id is null then
    return public.create_async_duel_challenge(p_category, p_friend_id);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':idem:duel:' || p_request_id::text, 0));

  select o.result into v_prev
  from public.idempotent_ops o
  where o.user_id = v_uid and o.op_key = 'duel:' || p_request_id::text;
  if found then
    begin
      return public.resume_my_async_duel((v_prev ->> 'duel_id')::uuid);
    exception when others then
      return v_prev;
    end;
  end if;

  delete from public.idempotent_ops
  where user_id = v_uid and created_at < now() - interval '14 days';

  v_result := public.create_async_duel_challenge(p_category, p_friend_id);
  if v_result ->> 'duel_id' is not null then
    insert into public.idempotent_ops (user_id, op_key, kind, result)
    values (v_uid, 'duel:' || p_request_id::text, 'duel', v_result);
  end if;
  return v_result;
end;
$function$;

revoke all on function public.spin_wheel_once(text) from public, anon;
grant execute on function public.spin_wheel_once(text) to authenticated, service_role;
revoke all on function public.start_async_duel(text, uuid) from public, anon;
grant execute on function public.start_async_duel(text, uuid) to authenticated, service_role;
revoke all on function public.create_async_duel_challenge(text, uuid, uuid) from public, anon;
grant execute on function public.create_async_duel_challenge(text, uuid, uuid) to authenticated, service_role;

do $tur9_son$
declare
  r record;
begin
  -- Yeni işlevler: SECURITY DEFINER, sahip tablo sahibiyle aynı, sabit search_path,
  -- anon/PUBLIC kapalı, authenticated açık.
  for r in select s from unnest(array[
    'public.spin_wheel_once(text)', 'public.start_async_duel(text,uuid)',
    'public.create_async_duel_challenge(text,uuid,uuid)']) s
  loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.s)
        and p.prosecdef
        and p.proconfig = array['search_path=public, pg_temp']
        and p.proowner = (select c.relowner from pg_class c where c.oid = 'public.idempotent_ops'::regclass)
    ) then
      raise exception 'tur9: % SECURITY DEFINER / search_path / sahip doğrulanamadı', r.s;
    end if;
    if has_function_privilege('anon', r.s, 'execute')
       or has_function_privilege('public', r.s, 'execute') then
      raise exception 'tur9: % anon/PUBLIC EXECUTE açık', r.s;
    end if;
    if not has_function_privilege('authenticated', r.s, 'execute') then
      raise exception 'tur9: % authenticated EXECUTE kapalı', r.s;
    end if;
  end loop;
  -- Kayıt defteri istemci rollerine kapalı.
  if has_table_privilege('anon', 'public.idempotent_ops', 'select,insert,update,delete')
     or has_table_privilege('authenticated', 'public.idempotent_ops', 'select,insert,update,delete')
     or not (select c.relrowsecurity from pg_class c where c.oid = 'public.idempotent_ops'::regclass) then
    raise exception 'tur9: idempotent_ops anon/authenticated erişimine açık ya da RLS kapalı';
  end if;
  -- Mevcut işlevlere dokunulmadı.
  if exists (
    select 1 from tur9_mevcut m
    where md5(pg_get_functiondef(to_regprocedure(m.imza))) <> m.md5
  ) then
    raise exception 'tur9: mevcut bir işlevin gövdesi değişti (bu göç değiştirmemeliydi)';
  end if;
end
$tur9_son$;

commit;
