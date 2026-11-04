-- 2026-11-08: AVATAR SÜPÜRME — silinmiş kullanıcıların herkese açık `avatars`
-- fotoğraflarını saatlik siler.
--
-- NİÇİN: build 43 istemcisi hesap silerken yalnız `delete_my_account` çağırır;
-- RPC içindeki `DELETE FROM storage.objects` fiziksel dosyayı silmez (yedek yol,
-- hatası yutulur) ve yeni istemcide de Storage silme hatası yutulur. Kova herkese
-- açık olduğundan silinmiş kullanıcıların fotoğrafları kalabilirdi. `avatar-sweep`
-- Edge Function'ı (service role) `auth.users`/`profiles`'ta karşılığı olmayan
-- `<uid>/` klasörlerini Storage API'siyle siler (bkz. functions/avatar-sweep).
--
-- NASIL ÇAĞRILIR: `send-push` ile AYNI desen (2026-10-13_push_delivery.sql):
-- pg_cron saatte bir `pg_net` ile POST eder; URL Vault'taki `avatar_sweep_url`
-- adından, sır MEVCUT Vault `cron_secret` adından (`x-cron-secret` başlığı;
-- Edge tarafında CRON_SECRET) okunur. Ne URL ne sır SQL'de yazılıdır. Vault
-- sırlarından biri yoksa iş no-op'tur (0 satır döner).
--
-- ÖN KOŞULLAR (göçten ÖNCE): `avatar-sweep` Edge Function'ı dağıtılmış
-- (`supabase functions deploy avatar-sweep`; CRON_SECRET zaten send-push için
-- tanımlı) ve Vault'a `avatar_sweep_url` eklenmiş olmalı (Vault sırları sonradan
-- da eklenebilir: o ana dek iş no-op). 'avatar-supurme' adlı iş HENÜZ olmamalı
-- (yeniden uygulamayı reddeder).
-- Geri alma: geri_al/2026-11-08_avatar_supurme_geri.sql
-- Uygulama: supabase db query --linked -f supabase/2026-11-08_avatar_supurme.sql

begin;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
begin
  if to_regclass('vault.decrypted_secrets') is null then
    raise exception 'avatar_supurme: Vault (vault.decrypted_secrets) yok';
  end if;
  if exists (select 1 from cron.job where jobname = 'avatar-supurme') then
    raise exception 'göç zaten uygulanmış: avatar-supurme işi var';
  end if;
end
$$;

select cron.schedule(
  'avatar-supurme',
  '17 * * * *',
  $cron$
  select net.http_post(
    url := (select s.decrypted_secret from vault.decrypted_secrets s
            where s.name = 'avatar_sweep_url' limit 1),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select s.decrypted_secret from vault.decrypted_secrets s
                        where s.name = 'cron_secret' limit 1)
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  )
  where exists (select 1 from vault.decrypted_secrets s where s.name = 'avatar_sweep_url')
    and exists (select 1 from vault.decrypted_secrets s where s.name = 'cron_secret')
  $cron$
);

do $$
declare
  v_command text;
begin
  select j.command into v_command
  from cron.job j
  where j.jobname = 'avatar-supurme' and j.schedule = '17 * * * *' and j.active;
  if v_command is null then
    raise exception 'avatar_supurme: iş kurulmadı';
  end if;
  if v_command not like '%net.http_post%'
     or v_command not like '%vault.decrypted_secrets%'
     or v_command not like '%x-cron-secret%' then
    raise exception 'avatar_supurme: komut beklenen biçimde değil';
  end if;
  if v_command ~* 'https?://' then
    raise exception 'avatar_supurme: komutta düz URL var (Vault''tan okunmalı)';
  end if;
end
$$;

commit;
