-- 2026-10-13: BİLDİRİM TESLİMATI — push_outbox kuyruğunu her dakika boşaltır.
--
-- NİÇİN: Kuyruğa yazan taraf hazırdı (arkadaşlık isteği, düello sonucu) ama
-- gerçek FCM gönderimi yalnız elle çalıştırılan `tool/send_push_outbox.py`
-- betiğindeydi ve hiçbir şey onu çalıştırmıyordu: canlıda cron işleri yalnız
-- cleanup-stale-rooms, finalize-weekly-league, expire-async-duels (2026-10-13
-- doğrulaması). Yani hiçbir bildirim ulaşmıyordu; geri dönüş kancası ölüydü.
--
-- NE YAPAR:
--   1. `public.clear_fcm_token(uuid, text)` — FCM'in "UNREGISTERED" dediği
--      jetonu o kullanıcının profilinden siler (yalnız jeton hâlâ AYNI ise;
--      uygulama jetonu o arada yenilediyse yenisine dokunmaz). Yalnız
--      service_role çalıştırır (send-push Edge Function'ı).
--   2. pg_cron işi `send-push` (her dakika): Vault'taki `send_push_url` adresine
--      `x-cron-secret: <Vault cron_secret>` başlığıyla `pg_net` üzerinden POST.
--      Ne URL ne sır SQL'de yazılıdır. İki Vault sırrından biri yoksa YA DA
--      kuyrukta bekleyen satır yoksa komut hiçbir şey yapmaz (no-op).
--   3. `enqueue_async_duel_invite_push()` — davetli (`invited_id`) bir düelloda
--      YARATICI kendi turunu bitirip sonucu yazıldığı anda davetliye
--      `async_duel_invite` bildirimi kuyruklar ("sıra sende"). Yaratıcının
--      sonucu düello başına bir kez yazılır (PK duel_id+player_id), yani
--      davetli başına tek bildirim. Engelleyen/engellenen arasında kuyruklanmaz.
--
-- BİLİNEN SINIR (dürüstlük): bugün hiçbir RPC `async_duels.invited_id`
-- doldurmuyor ve `start_async_duel` davetli düelloları rastgele eşleşmeden
-- dışlar; arkadaşa meydan okuma (v1.1) henüz yazılmadı. 3. madde o RPC
-- yazıldığında hazır bekleyen tetikleyicidir; ondan önce hiçbir satır
-- kuyruklamaz. Rastgele eşleşmede "sıra sende" bildirimi KASITLI YOK: eşleşen
-- rakip soruları `start_async_duel` yanıtıyla anında alıp oynuyor (uygulamanın
-- içinde), bekleyen yaratıcıya ise bitiş bildirimi zaten gidiyor
-- (`async_duel_result`, 2026-10-02_async_duel_server_timing.sql). Bu yüzden
-- `start_async_duel` / `answer_async_duel` bu göçte YENİDEN YAZILMAZ.
--
-- ÖN KOŞULLAR (göçten ÖNCE): `send-push` Edge Function'ı dağıtılmış, iki
-- Edge sırrı (FCM_SERVICE_ACCOUNT_JSON, CRON_SECRET) verilmiş, iki Vault sırrı
-- eklenmiş olmalı. Adımlar supabase/applied.md satırında. Vault sırları
-- sonradan da eklenebilir: o ana dek iş no-op'tur.
--
-- TEKRAR: idempotent (create or replace, drop trigger if exists, işi önce
-- kaldırıp yeniden kurar). İkinci çalıştırma aynı sonucu verir.
-- GERİ ALMA:
--   select cron.unschedule('send-push');
--   drop trigger if exists trg_async_duel_invite_push on public.async_duel_results;
--   drop function if exists public.enqueue_async_duel_invite_push();
--   drop function if exists public.clear_fcm_token(uuid, text);
-- Uygulama: supabase db query --linked -f supabase/2026-10-13_push_delivery.sql

begin;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------
-- 1) Geçersiz FCM jetonunu temizle (yalnız service_role)
-- ---------------------------------------------------------------------

create or replace function public.clear_fcm_token(p_user_id uuid, p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null or p_token is null or length(trim(p_token)) = 0 then
    return;
  end if;
  update public.profiles
  set fcm_token = null
  where id = p_user_id
    and fcm_token = p_token;
end;
$$;

revoke all on function public.clear_fcm_token(uuid, text)
  from public, anon, authenticated;
grant execute on function public.clear_fcm_token(uuid, text) to service_role;

-- ---------------------------------------------------------------------
-- 2) Davetli düello: yaratıcı turunu bitirince davetliye bildirim
-- ---------------------------------------------------------------------

create or replace function public.enqueue_async_duel_invite_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_duel public.async_duels%rowtype;
  v_name text;
begin
  select * into v_duel
  from public.async_duels d
  where d.id = new.duel_id;

  -- Yalnız davetli bir düelloda, yalnız YARATICININ sonucu için.
  if not found
     or v_duel.invited_id is null
     or new.player_id <> v_duel.creator_id then
    return new;
  end if;

  -- Engelleme (2026-10-02 M5) iki yönde de geçerli: engelli çiftin arasında
  -- bildirim de yok.
  if exists (
    select 1 from public.blocked_users b
    where (b.blocker_id = v_duel.invited_id and b.blocked_id = v_duel.creator_id)
       or (b.blocker_id = v_duel.creator_id and b.blocked_id = v_duel.invited_id)
  ) then
    return new;
  end if;

  select coalesce(nullif(btrim(left(p.display_name, 40)), ''), 'ZanKurd')
  into v_name
  from public.profiles p
  where p.id = v_duel.creator_id;
  v_name := coalesce(v_name, 'ZanKurd');

  insert into public.push_outbox (to_user_id, kind, title, body)
  values (
    v_duel.invited_id,
    'async_duel_invite',
    'ZanKurd',
    -- Sunucu alıcının arayüz dilini bilmiyor; metin iki dilli.
    'Dora te ye: ' || v_name || ' tu vexwendî pêşbirkê · Sıra sende: '
      || v_name || ' seni düelloya çağırdı'
  );
  return new;
end;
$$;

revoke all on function public.enqueue_async_duel_invite_push()
  from public, anon, authenticated;

drop trigger if exists trg_async_duel_invite_push on public.async_duel_results;
create trigger trg_async_duel_invite_push
  after insert on public.async_duel_results
  for each row
  execute function public.enqueue_async_duel_invite_push();

-- ---------------------------------------------------------------------
-- 3) Her dakika send-push Edge Function'ını çağır
-- ---------------------------------------------------------------------

select cron.unschedule('send-push')
where exists (
  select 1 from cron.job where jobname = 'send-push'
);

-- Komut: Vault'ta `send_push_url` ve `cron_secret` varsa VE gönderilmemiş
-- satır bekliyorsa tek bir POST; aksi hâlde hiçbir şey (sorgu 0 satır döner).
select cron.schedule(
  'send-push',
  '* * * * *',
  $cron$
  select net.http_post(
    url := (select s.decrypted_secret from vault.decrypted_secrets s
            where s.name = 'send_push_url' limit 1),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select s.decrypted_secret from vault.decrypted_secrets s
                        where s.name = 'cron_secret' limit 1)
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 20000
  )
  where exists (select 1 from vault.decrypted_secrets s where s.name = 'send_push_url')
    and exists (select 1 from vault.decrypted_secrets s where s.name = 'cron_secret')
    and exists (select 1 from public.push_outbox o where o.claimed_at is null)
  $cron$
);

-- ---------------------------------------------------------------------
-- Doğrulama: biri tutmazsa bütün göç geri alınır.
-- ---------------------------------------------------------------------

do $$
declare
  v_command text;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_net') then
    raise exception 'push_delivery: pg_net yüklü değil';
  end if;
  if to_regclass('vault.decrypted_secrets') is null then
    raise exception 'push_delivery: Vault (vault.decrypted_secrets) yok';
  end if;

  select j.command into v_command
  from cron.job j
  where j.jobname = 'send-push' and j.schedule = '* * * * *' and j.active;
  if v_command is null then
    raise exception 'push_delivery: send-push işi kurulmadı';
  end if;
  if v_command not like '%net.http_post%'
     or v_command not like '%vault.decrypted_secrets%'
     or v_command not like '%x-cron-secret%' then
    raise exception 'push_delivery: send-push komutu beklenen biçimde değil';
  end if;
  if v_command ~* 'https?://' then
    raise exception 'push_delivery: komutta düz URL var (Vault''tan okunmalı)';
  end if;

  if has_function_privilege('anon', 'public.clear_fcm_token(uuid,text)', 'execute')
     or has_function_privilege('authenticated', 'public.clear_fcm_token(uuid,text)', 'execute') then
    raise exception 'push_delivery: clear_fcm_token istemciye açık';
  end if;
  if not has_function_privilege('service_role', 'public.clear_fcm_token(uuid,text)', 'execute') then
    raise exception 'push_delivery: clear_fcm_token service_role''a kapalı';
  end if;

  if has_function_privilege('anon', 'public.enqueue_async_duel_invite_push()', 'execute')
     or has_function_privilege('authenticated', 'public.enqueue_async_duel_invite_push()', 'execute') then
    raise exception 'push_delivery: davet tetikleyici işlevi istemciye açık';
  end if;
  if not exists (
    select 1 from pg_trigger
    where tgname = 'trg_async_duel_invite_push'
      and tgrelid = 'public.async_duel_results'::regclass
      and not tgisinternal
  ) then
    raise exception 'push_delivery: davet tetikleyicisi yok';
  end if;

  if not exists (
    select 1 from vault.decrypted_secrets where name = 'send_push_url'
  ) or not exists (
    select 1 from vault.decrypted_secrets where name = 'cron_secret'
  ) then
    raise notice 'push_delivery: Vault sırları (send_push_url, cron_secret) henüz yok; iş sırlar eklenene dek no-op';
  end if;
end $$;

commit;
