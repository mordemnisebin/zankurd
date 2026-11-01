-- G15: V1 cron'un durması, eski manuel/Edge worker'ın claimed_at tüketimini
-- durdurmaz. Mevcut V2 adayından SONRA, worker dağıtımından ÖNCE uygulanır.
-- CANLIYA UYGULANMADI. Yeni kuyruk/fonksiyon gövdesi yok; yalnız kapalı geçiş.
begin;

do $preflight$
begin
  if to_regclass('public.push_delivery_v2_config') is null
     or to_regprocedure('public.claim_push_outbox_v2(integer)') is null
     or to_regprocedure('public.finish_push_outbox(uuid,uuid,text,text,integer)') is null
     or to_regprocedure('public.claim_push_outbox(integer)') is null then
    raise exception 'push_v2_cutover: önce denetlenmiş V2 adayı kurulmalı';
  end if;
end;
$preflight$;

-- Önceden başlamış claim işleminin bitmesini bekler; geçmiş claim'leri ASLA
-- sıfırlamaz. Çalışmakta olan FCM çağrısı bu transaction ile iptal edilemez.
lock table public.push_outbox in share row exclusive mode;
update public.push_delivery_v2_config set enabled = false where singleton;
revoke all on function public.claim_push_outbox(integer)
  from public, anon, authenticated, service_role;

do $pause$
declare r record;
begin
  for r in select jobid from cron.job where jobname = 'send-push' loop
    perform cron.alter_job(r.jobid, active := false);
  end loop;
  -- Üst rolden miras veya yanlış sahiplik revoke'u etkisiz bırakırsa dur.
  if has_function_privilege('service_role', 'public.claim_push_outbox(integer)', 'EXECUTE')
     or has_function_privilege('anon', 'public.claim_push_outbox(integer)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.claim_push_outbox(integer)', 'EXECUTE') then
    raise exception 'push_v2_cutover: V1 yetkisi hâlâ açık; rol sahipliğini incele';
  end if;
end;
$pause$;

commit;
