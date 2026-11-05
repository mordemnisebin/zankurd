-- 2026-11-16_w8_yonetim.sql ile ilgili indeks (alan 9 #18: admin_get_stats new_today/new_week).
-- begin/commit YOK: CREATE INDEX CONCURRENTLY transaction içinde çalışmaz; dosya
-- psql/`supabase db query` ile bölünmeden koşulmalıdır. Idempotent; yazmaları BLOKLAMAZ.
-- Göçten önce ya da sonra çalıştırılabilir. Geri alma: drop index concurrently if exists
-- public.profiles_created_at_idx;
create index concurrently if not exists profiles_created_at_idx
  on public.profiles (created_at);
