-- Bildirim denetimi (GPT-6 Pro ALAN 4) sunucu tarafı. UYGULANMADI (⏳).
-- Geri alma: geri_al/2026-11-06_push_tur8_geri.sql
--
-- A. clear_my_fcm_token() yalnız kullanıcı kimliğine bakıp jetonu siler: aynı
--    hesabın ikinci cihazı T2'yi kaydettikten sonra birinci cihazın çıkışı T2'yi de
--    kaldırır; ikinci cihaz yeniden kayıt tetikleyene kadar push alamaz.
--    Çözüm: YENİ aşırı yükleme clear_my_fcm_token(p_token text) — yalnız
--    `fcm_token = p_token` ise siler. Sıfır parametreli mevcut işlev DEĞİŞMEZ
--    (build 43 istemcileri onu çağırır; bu göç onun gövdesine dokunmaz, bu yüzden
--    md5/yedek ön koşulu gerekmez). Yeni istemci jetonu bilirse tek parametreli
--    sürümü çağırır; sunucuda yoksa (PGRST202) eskisine düşer.
--
-- NOT (kapsam dışı, bkz. applied.md): config satırı kilidi (expire_async_duels /
-- wake_push_delivery_v2) ve arkadaşlık isteği outbox sürümü, canlı gövdelerin
-- `pg_get_functiondef` md5 ön koşulunu gerektirir; canlı DB'ye bağlanılmadan
-- yazılamaz, koordinatörün canlı okumasıyla ayrı göçte yapılır.
begin;

set local lock_timeout = '10s';

do $tur8_onkosul$
begin
  if to_regclass('public.profiles') is null
     or to_regprocedure('public.clear_my_fcm_token()') is null
     or to_regprocedure('public.set_fcm_token(text)') is null then
    raise exception 'tur8: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
  -- Henüz uygulanmamışken yaratılacak işlev zaten varsa durur (geri alma yalnız
  -- bu göçün yarattığını kaldırsın; var olan sessizce ezilmesin).
  if to_regprocedure('public.clear_my_fcm_token(text)') is not null then
    raise exception 'tur8: clear_my_fcm_token(text) zaten var; göç durdu';
  end if;
end
$tur8_onkosul$;

create function public.clear_my_fcm_token(p_token text)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
begin
  if auth.uid() is null or p_token is null or btrim(p_token) = '' then
    return;
  end if;
  -- Yalnız bu cihazın jetonu: başka cihazın sonradan yazdığı jeton korunur.
  update public.profiles
  set fcm_token = null
  where id = auth.uid() and fcm_token = btrim(p_token);
end;
$function$;

revoke all on function public.clear_my_fcm_token(text) from public, anon;
grant execute on function public.clear_my_fcm_token(text) to authenticated, service_role;

do $tur8_son$
begin
  if not exists (
    select 1 from pg_proc p
    where p.oid = to_regprocedure('public.clear_my_fcm_token(text)')
      and p.prosecdef
      and p.proconfig = array['search_path=public, pg_temp']
  ) then
    raise exception 'tur8: clear_my_fcm_token(text) SECURITY DEFINER / search_path doğrulanamadı';
  end if;
  if has_function_privilege('anon', 'public.clear_my_fcm_token(text)', 'execute')
     or has_function_privilege('public', 'public.clear_my_fcm_token(text)', 'execute') then
    raise exception 'tur8: clear_my_fcm_token(text) anon/PUBLIC EXECUTE açık';
  end if;
  if not has_function_privilege('authenticated', 'public.clear_my_fcm_token(text)', 'execute') then
    raise exception 'tur8: clear_my_fcm_token(text) authenticated EXECUTE kapalı';
  end if;
  -- Mevcut sıfır parametreli sürüm olduğu gibi duruyor.
  if to_regprocedure('public.clear_my_fcm_token()') is null then
    raise exception 'tur8: clear_my_fcm_token() kayboldu';
  end if;
end
$tur8_son$;

commit;
