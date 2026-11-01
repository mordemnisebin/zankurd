-- G15 güvenli geri durdurma: eski V1 tüketimi geri açılmaz; lease/ack verisi
-- korunur. Tam şema/ACL geri dönüşü değildir; V1'e dönüş ayrı canlı inceleme
-- ve açık sahip onayı gerektirir. Birden çok kez uygulanabilir.
begin;
update public.push_delivery_v2_config set enabled = false where singleton;
revoke all on function public.claim_push_outbox(integer)
  from public, anon, authenticated, service_role;
do $pause$
declare r record;
begin
  for r in select jobid from cron.job where jobname = 'send-push' loop
    perform cron.alter_job(r.jobid, active := false);
  end loop;
end;
$pause$;
commit;
