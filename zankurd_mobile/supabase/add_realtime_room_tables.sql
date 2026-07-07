-- ============================================================
-- Realtime Publication Patch — rooms & room_players
-- ============================================================
-- Kök neden: supabase_realtime publication'ında yalnızca
-- matchmaking_queue vardı. rooms ve room_players ekli değil
-- olduğundan host, katılan oyuncunun realtime bildirimini göremiyordu.
--
-- Bu patch idempotent: tablo zaten publication'daysa duplicate_object
-- hatası yakalanıp yok sayılır.
--
-- Uygulama: Supabase Dashboard → SQL Editor'de çalıştır.
-- ============================================================

do $$
begin
  alter publication supabase_realtime add table public.rooms;
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  alter publication supabase_realtime add table public.room_players;
exception
  when duplicate_object then null;
end
$$;

-- Not: RLS policy'leri zaten tanımlı. Realtime, mevcut SELECT
-- policy'lerini kullanarak erişim kontrolü yapar.
