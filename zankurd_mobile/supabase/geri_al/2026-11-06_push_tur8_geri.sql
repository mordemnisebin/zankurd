-- GERİ ALMA: 2026-11-06_push_tur8.sql
-- Yalnız göçün yarattığı tek parametreli clear_my_fcm_token(text) kaldırılır;
-- sıfır parametreli sürüme dokunulmaz. Yeni istemci tek parametreli sürüm yokken
-- (PGRST202) eskisine düşer, yani geri alma güvenlidir.
begin;

drop function if exists public.clear_my_fcm_token(text);

do $tur8_geri$
begin
  if to_regprocedure('public.clear_my_fcm_token(text)') is not null then
    raise exception 'tur8 geri: clear_my_fcm_token(text) kaldırılamadı';
  end if;
  if to_regprocedure('public.clear_my_fcm_token()') is null then
    raise exception 'tur8 geri: clear_my_fcm_token() bulunamadı';
  end if;
end
$tur8_geri$;

commit;
