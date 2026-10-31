-- YALNIZ tek kullanımlık yerel Supabase/test DB. Canlıda ÇALIŞTIRMA.
-- Oturumda önceden SET zankurd.test_database = 'local-only'; gerekir.
-- V2 migration kurulmuş, gate kapalı ve en az2 yerel test profili olmalı.
-- Ağ yok: wake tetikleyicisi bu transaction içinde kapatılır; sonunda ROLLBACK.
begin;
do $guard$
begin
  if current_setting('zankurd.test_database', true) is distinct from 'local-only'
     or (inet_server_addr() is not null and not (
       inet_server_addr() <<= '127.0.0.0/8'::inet or inet_server_addr() = '::1'::inet)) then
    raise exception 'Yalnız yerel test veritabanı; canlı bağlantıda dur';
  end if;
  if exists (select 1 from public.push_delivery_v2_config where enabled) then
    raise exception 'Smoke öncesi V2 kapısı kapalı olmalı';
  end if;
  if exists (select 1 from public.claim_push_outbox_v2(20)) then
    raise exception 'Kapalı gate iş döndürdü';
  end if;
end;
$guard$;
alter table public.push_outbox disable trigger trg_push_outbox_wake_v2;
-- Bu transaction içinde Vault/pg_net'e gidebilecek tek işlevi sayaçla değiştir.
-- PostgreSQL hem işlev gövdesini hem geçici tabloyu ROLLBACK ile geri alır.
create temporary table token_wakes (n integer) on commit drop;
create or replace function public.wake_push_delivery_v2()
returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $stub$begin
  insert into pg_temp.token_wakes values (1);
  return true;
end;$stub$;
-- Test dışı yerel satırlar claim edilmesin; bütün değişiklikler rollback olur.
update public.push_outbox set delivery_status = 'legacy';
update public.push_delivery_v2_config set enabled = true;

do $smoke$
declare
  a uuid;
  b uuid;
  j uuid;
  lease uuid;
  lease2 uuid;
  result record;
begin
  select id into a from public.profiles order by id limit 1;
  select id into b from public.profiles where id <> a order by id limit 1;
  if a is null or b is null then raise exception '2 yerel test profili gerekli'; end if;
  update public.profiles set push_social = true, push_duel = true, fcm_token = 'local-test-token'
    where id in (a,b);
  -- Yerel test çiftini başlangıçta engelsiz yap; rollback geri getirir.
  delete from public.blocked_users
    where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a);

  -- Başarı + aynı ack idempotency + farklı outcome reddi; sent yeniden seçilmez.
  insert into public.push_outbox(to_user_id,from_user_id,kind,title,body)
    values(b,a,'friend_request','test','test') returning id into j;
  select * into result from public.claim_push_outbox_v2(20);
  if result.job_id is distinct from j or result.attempt_count <> 1 then raise exception 'claim shape'; end if;
  lease := result.claim_token;
  if result.data->>'from_user_id' is distinct from a::text then raise exception 'sender metadata'; end if;
  if result.expires_at is distinct from (select created_at + interval '24 hours' from public.push_outbox where id=j) then raise exception 'fixed expiry'; end if;
  if not public.finish_push_outbox(j,lease,'sent')
     or not public.finish_push_outbox(j,lease,'sent')
     or public.finish_push_outbox(j,lease,'failed') then raise exception 'terminal ack fence'; end if;
  if exists(select 1 from public.claim_push_outbox_v2(20)) then raise exception 'sent replay'; end if;

  -- Retry backoff kalıcı, aynı retry ack güvenli; süreden önce tekrar verilmez.
  insert into public.push_outbox(to_user_id,from_user_id,kind,title,body)
    values(b,a,'room_invite','test','test') returning id into j;
  select * into result from public.claim_push_outbox_v2(20); lease := result.claim_token;
  if not public.finish_push_outbox(j,lease,'retry','UNAVAILABLE',120)
     or not public.finish_push_outbox(j,lease,'retry','UNAVAILABLE',120) then raise exception 'retry ack'; end if;
  if exists(select 1 from public.claim_push_outbox_v2(20)) then raise exception 'backoff ignored'; end if;
  update public.push_outbox set next_attempt_at = now() - interval '1 second' where id=j;
  select * into result from public.claim_push_outbox_v2(20); lease2 := result.claim_token;
  if result.expires_at is distinct from (select created_at + interval '30 minutes' from public.push_outbox where id=j) then raise exception 'retry extended expiry'; end if;
  if lease2 is null or lease2 = lease or result.attempt_count <> 2 then raise exception 'retry re-claim'; end if;
  if public.finish_push_outbox(j,lease,'sent') then raise exception 'stale lease ack'; end if;
  -- Süreç çökerse expired lease yeni kimlikle kurtarılır.
  update public.push_outbox set lease_until = now() - interval '1 second' where id=j;
  select * into result from public.claim_push_outbox_v2(20);
  if result.claim_token = lease2 or result.attempt_count <> 3 then raise exception 'lease recovery'; end if;
  perform public.finish_push_outbox(j,result.claim_token,'sent');

  -- Token olmayan iş yanmaz, boş token da bekler; token gelince seçilir.
  update public.profiles set fcm_token = null where id=b;
  insert into public.push_outbox(to_user_id,from_user_id,kind,title,body)
    values(b,a,'friend_request','test','test') returning id into j;
  if exists(select 1 from public.claim_push_outbox_v2(20)) then raise exception 'no token claim'; end if;
  if (select delivery_status from public.push_outbox where id=j) <> 'pending' then raise exception 'no token lost'; end if;
  update public.profiles set fcm_token='local-test-token' where id=b;
  select * into result from public.claim_push_outbox_v2(20);
  if result.job_id is distinct from j then raise exception 'new token pending recovery'; end if;
  perform public.finish_push_outbox(j,result.claim_token,'sent');

  -- Tercihler, iki yönde engel, yaş ve eski claim sınırı.
  update public.profiles set push_social=false where id=b;
  insert into public.push_outbox(to_user_id,from_user_id,kind,title,body)
    values(b,a,'friend_request','test','test');
  if exists(select 1 from public.claim_push_outbox_v2(20)) then raise exception 'social privacy'; end if;
  update public.profiles set push_social=true,push_duel=false where id=b;
  insert into public.push_outbox(to_user_id,from_user_id,kind,title,body)
    values(b,a,'async_duel_invite','test','test');
  if exists(select 1 from public.claim_push_outbox_v2(20)) then raise exception 'duel privacy'; end if;
  update public.profiles set push_duel=true where id=b;
  insert into public.blocked_users(blocker_id,blocked_id) values(a,b);
  insert into public.push_outbox(to_user_id,from_user_id,kind,title,body)
    values(b,a,'friend_request','test','test');
  if exists(select 1 from public.claim_push_outbox_v2(20)) then raise exception 'outbound block'; end if;
  delete from public.blocked_users where blocker_id=a and blocked_id=b;
  insert into public.blocked_users(blocker_id,blocked_id) values(b,a);
  insert into public.push_outbox(to_user_id,from_user_id,kind,title,body)
    values(b,a,'friend_request','test','test');
  if exists(select 1 from public.claim_push_outbox_v2(20)) then raise exception 'inbound block'; end if;
  delete from public.blocked_users where blocker_id=b and blocked_id=a;
  insert into public.push_outbox(to_user_id,kind,title,body,created_at) values
    (b,'room_invite','test','test',now()-interval '31 minutes'),
    (b,'friend_request','test','test',now()-interval '25 hours');
  insert into public.push_outbox(to_user_id,kind,title,body,claimed_at)
    values(b,'friend_request','test','test',now());
  if exists(select 1 from public.claim_push_outbox_v2(20)) then raise exception 'age or legacy replay'; end if;

  -- Sekizinci geçici hata terminal; aynı ack yine true; dokuzuncu send yok.
  insert into public.push_outbox(to_user_id,kind,title,body,attempt_count)
    values(b,'friend_request','test','test',7) returning id into j;
  select * into result from public.claim_push_outbox_v2(20);
  if result.attempt_count <> 8 then raise exception 'attempt eight'; end if;
  if not public.finish_push_outbox(j,result.claim_token,'retry','UNAVAILABLE',120)
     or not public.finish_push_outbox(j,result.claim_token,'retry','UNAVAILABLE',120) then raise exception 'exhausted ack'; end if;
  if (select delivery_status from public.push_outbox where id=j) <> 'failed' then raise exception 'attempt limit'; end if;
end;
$smoke$;

-- Diğer senaryolardan kalan işler bu denetimi etkileyemez.
update public.push_outbox set delivery_status = 'legacy';
truncate pg_temp.token_wakes;
create function pg_temp.register_token(p_id uuid) returns void language plpgsql as $$
begin
  update public.profiles set fcm_token = null where id = p_id;
  update public.profiles set fcm_token = 'local-test-token' where id = p_id;
end;$$;
do $token$
declare a uuid; b uuid; job uuid;
begin
  select id into strict a from public.profiles order by id limit 1;
  select id into strict b from public.profiles where id<>a order by id limit 1;
  update public.profiles set fcm_token=null,push_social=true where id in (a,b);
  insert into public.push_outbox(to_user_id,from_user_id,kind,title,body)
    values(b,a,'friend_request','test','test') returning id into job;
  perform pg_temp.register_token(a);
  update public.push_delivery_v2_config set enabled=false;
  perform pg_temp.register_token(b);
  update public.profiles set fcm_token=' ' where id=b;
  update public.push_delivery_v2_config set enabled=true;
  if exists (select from pg_temp.token_wakes) then raise exception 'unrelated token or disabled gate woke'; end if;

  update public.profiles set fcm_token='local-test-token' where id=b;
  if (select count(*) from pg_temp.token_wakes) <> 1 then raise exception 'first token missing wake'; end if;
  update public.profiles set fcm_token='local-test-token' where id=b;
  update public.profiles set fcm_token='local-test-rotated' where id=b;
  update public.profiles set push_social=push_social where id=b;
  if (select count(*) from pg_temp.token_wakes) <> 1 then raise exception 'repeat or unrelated update woke'; end if;

  update public.push_outbox set delivery_status='retry', next_attempt_at=now()+interval '1 hour' where id=job;
  perform pg_temp.register_token(b);
  update public.push_outbox set delivery_status='leased', next_attempt_at=now(),
    claimed_at=now(), claim_token=gen_random_uuid(), lease_until=now()+interval '1 minute' where id=job;
  perform pg_temp.register_token(b);
  update public.push_outbox set delivery_status='pending', lease_until=null, claim_token=null where id=job;
  perform pg_temp.register_token(b); -- Eski claim'de token yok.
  update public.push_outbox set claimed_at=null, attempt_count=8 where id=job;
  perform pg_temp.register_token(b);
  update public.push_outbox set attempt_count=0,created_at=now()-interval '25 hours' where id=job;
  perform pg_temp.register_token(b);
  update public.push_outbox set created_at=now() where id=job;
  insert into public.blocked_users(blocker_id,blocked_id) values(a,b);
  perform pg_temp.register_token(b);
  delete from public.blocked_users where blocker_id=a and blocked_id=b;
  update public.profiles set push_social=false where id=b;
  perform pg_temp.register_token(b);
  update public.profiles set push_social=true where id=b;
  update public.push_outbox set kind='room_invite',
    data=jsonb_build_object('invite_id',gen_random_uuid(),'room_id',gen_random_uuid()) where id=job;
  perform pg_temp.register_token(b); -- Kapanmış/yenilenmiş kimlik.
  if (select count(*) from pg_temp.token_wakes) <> 1 then raise exception 'ineligible job woke'; end if;
end;
$token$;
rollback;
