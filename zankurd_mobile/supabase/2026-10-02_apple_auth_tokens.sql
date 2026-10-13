-- 2026-10-02: "Sign in with Apple" yenileme jetonunu hesap silinene dek
-- sunucuda saklar (App Store Review Guideline 5.1.1(v): hesap silerken Apple
-- bağlantısı da iptal edilmeli).
--
-- NİÇİN BİR TABLO: Apple'ın girişte verdiği `authorizationCode` tek
-- kullanımlık ve ~5 dakikalıktır; hesap günler sonra silinirken elde yoktur.
-- Girişten hemen sonra `apple-revoke` Edge Function'ı (supabase/functions/
-- apple-revoke) kodu `/auth/token` ile takas edip kalıcı `refresh_token`ı
-- bu tabloya yazar; silme anında aynı fonksiyon onu `/auth/revoke` ile iptal
-- edip satırı siler.
--
-- GÜVENLİK: jeton hassastır. RLS açık, İSTEMCİ ROLLERİNE (anon, authenticated)
-- HİÇBİR yetki ve politika yok; yalnız service_role (Edge Function) okur/yazar.
-- `auth.users` silinince satır cascade ile gider (iptal başarısız olsa bile
-- hesap silme engellenmez; uygulama bunu kayda geçirip devam eder).
--
-- DAĞITIM: önce bu migration, sonra `supabase functions deploy apple-revoke`
-- (bkz. fonksiyonun dosya başı). Migration uygulanmadan fonksiyon
-- `register` çağrısında 500 (`store_failed`) döner; istemci bunu yutar.
--
-- GERİ ALMA: `drop table public.apple_auth_tokens;`

begin;

create table if not exists public.apple_auth_tokens (
  user_id uuid primary key references auth.users (id) on delete cascade,
  refresh_token text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.apple_auth_tokens enable row level security;
revoke all on table public.apple_auth_tokens from public, anon, authenticated;
grant select, insert, update, delete on table public.apple_auth_tokens to service_role;

do $$
begin
  if not (select c.relrowsecurity from pg_class c
          where c.oid = 'public.apple_auth_tokens'::regclass) then
    raise exception 'apple_auth_tokens: RLS kapalı';
  end if;
  if has_table_privilege('authenticated', 'public.apple_auth_tokens', 'select')
     or has_table_privilege('authenticated', 'public.apple_auth_tokens', 'insert')
     or has_table_privilege('anon', 'public.apple_auth_tokens', 'select') then
    raise exception 'apple_auth_tokens istemciye açık';
  end if;
  if exists (select 1 from pg_policies
             where schemaname = 'public' and tablename = 'apple_auth_tokens') then
    raise exception 'apple_auth_tokens politika taşımamalı';
  end if;
  if not has_table_privilege('service_role', 'public.apple_auth_tokens', 'insert') then
    raise exception 'service_role yazamıyor';
  end if;
end $$;

commit;
