-- 2026-09-02: profiles tablosunda anonim enumeration açığını kapatma.
-- Referans: docs/pentest-raporu.md (Bulgu 2.1 - ORTA seviye)
--
-- Pentest bulgusu:
-- Anon token ile `GET /rest/v1/profiles?select=id` yapılarak tüm kayıtlar (342+ kullanıcı)
-- dışarıdan taranabilmekteydi.
--
-- Misafir kullanıcılar (guest) Supabase anonim oturumu (signInAnonymously) ile
-- `authenticated` rolü almaktadır. Liderlik tablosu ise güvenlikli view/RPC ile
-- çalışır. Dolayısıyla `anon` (oturum açmamış dış istemci) rolünün doğrudan
-- `profiles` tablosunu SELECT edebilmesine gerek yoktur.

-- 1. profiles üzerindeki eski/geniş kapsamlı olası anonim okuma politikalarını temizle
drop policy if exists "Public profiles are viewable by everyone" on public.profiles;
drop policy if exists "Profiles are viewable by everyone" on public.profiles;
drop policy if exists "Allow public read on profiles" on public.profiles;
drop policy if exists "Profiles are readable by everyone" on public.profiles;

-- 2. Yalnızca oturum açmış (authenticated, anonim misafirler dahil) kullanıcıların
-- oyun içi etkileşimler (1v1, oda listesi, arkadaşlar vb.) için okuma yapabilmesini sağla
drop policy if exists "Profiles are readable by signed-in users" on public.profiles;
create policy "Profiles are readable by signed-in users"
  on public.profiles for select
  to authenticated
  using (true);

-- 3. anon rolünün doğrudan profiles tablosunu listeleme yetkisini kaldır
revoke select on public.profiles from anon;

-- 4. FCM token zaten gizlenmişti, teyit et:
revoke select (fcm_token) on public.profiles from anon, authenticated;
