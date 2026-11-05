-- 2026-11-16 (W4, GPT-6 Pro ALAN 4 #3): Apple iptali başarısız olan silinmiş hesapların
-- jetonlarını her 15 dakikada yeniden dener.
--
-- NİÇİN: apple-revoke Edge işlevinin `sweep` eylemi (x-cron-secret) apple_auth_tokens'taki
-- YETİM satırları (sahibi auth.users'ta artık yok; bkz. 2026-11-16_w4_apple_hesap_silme.sql)
-- Apple'da iptal eder; başarıda satırı siler. Çağıran yok olursa iptal edilemeyen jeton
-- sonsuza dek kalır (en çok 20 deneme, sonra elle incelenir).
--
-- NASIL ÇAĞRILIR: avatar-sweep/send-push ile AYNI desen: pg_cron + pg_net; URL Vault'taki
-- `apple_revoke_url` adından (apple-revoke işlevinin tam adresi), sır MEVCUT Vault
-- `cron_secret` adından (`x-cron-secret`; Edge tarafında CRON_SECRET). Ne URL ne sır SQL'de
-- yazılıdır. Vault sırlarından biri yoksa iş no-op'tur.
--
-- ÖN KOŞULLAR (göçten ÖNCE): (1) 2026-11-16_w4_apple_hesap_silme.sql uygulanmış,
-- (2) apple-revoke Edge işlevi YENİ sürümle (sweep eylemli) ve verify_jwt=false ile
-- dağıtılmış (config.toml: `supabase functions deploy apple-revoke`), (3) Vault'a
-- `apple_revoke_url` eklenmiş (Vault sırları sonradan da eklenebilir: o ana dek iş no-op).
-- 'apple-iptal-yeniden' adlı iş HENÜZ olmamalı (yeniden uygulamayı reddeder).
-- Geri alma: geri_al/2026-11-16_w4_apple_cron_geri.sql
begin;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
begin
  if to_regclass('vault.decrypted_secrets') is null then
    raise exception 'apple_cron: Vault (vault.decrypted_secrets) yok';
  end if;
  if to_regprocedure('public.apple_orphan_tokens(integer)') is null then
    raise exception 'apple_cron: önce 2026-11-16_w4_apple_hesap_silme.sql uygulanmalı';
  end if;
  if exists (select 1 from cron.job where jobname = 'apple-iptal-yeniden') then
    raise exception 'göç zaten uygulanmış: apple-iptal-yeniden işi var';
  end if;
end
$$;

select cron.schedule(
  'apple-iptal-yeniden',
  '*/15 * * * *',
  $cron$
  select net.http_post(
    url := (select s.decrypted_secret from vault.decrypted_secrets s
            where s.name = 'apple_revoke_url' limit 1),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select s.decrypted_secret from vault.decrypted_secrets s
                        where s.name = 'cron_secret' limit 1)
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  )
  where exists (select 1 from vault.decrypted_secrets s where s.name = 'apple_revoke_url')
    and exists (select 1 from vault.decrypted_secrets s where s.name = 'cron_secret')
    and exists (select 1 from public.apple_auth_tokens t
                where not exists (select 1 from auth.users u where u.id = t.user_id))
  $cron$
);

do $$
declare
  v_command text;
begin
  select j.command into v_command
  from cron.job j
  where j.jobname = 'apple-iptal-yeniden' and j.schedule = '*/15 * * * *' and j.active;
  if v_command is null then
    raise exception 'apple_cron: iş kurulmadı';
  end if;
  if v_command not like '%net.http_post%'
     or v_command not like '%vault.decrypted_secrets%'
     or v_command not like '%x-cron-secret%' then
    raise exception 'apple_cron: komut beklenen biçimde değil';
  end if;
  if v_command ~* 'https?://' then
    raise exception 'apple_cron: komutta düz URL var (Vault''tan okunmalı)';
  end if;
end
$$;

commit;
