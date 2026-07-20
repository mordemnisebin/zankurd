-- 2026-07-21 denetimi: eski oda/kuyruk temizliği.
-- HENÜZ CANLIYA UYGULANMADI. Uygulama: Supabase SQL Editor.
-- pg_cron uzantısı Studio'dan etkinleştirilmiş olmalı (Database > Extensions).

-- 1) Temizlik fonksiyonu: 24 saatten eski, bitmemiş odaları ve
--    10 dakikadan eski matchmaking kuyruğu kayıtlarını siler.
create or replace function public.cleanup_stale_rooms()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Oyuncu cevapları / oda oyuncuları FK ile odaya bağlıysa önce onlar.
  delete from public.player_answers
  where room_id in (
    select id from public.rooms
    where created_at < now() - interval '24 hours'
      and coalesce(status, '') <> 'finished'
  );

  delete from public.room_players
  where room_id in (
    select id from public.rooms
    where created_at < now() - interval '24 hours'
      and coalesce(status, '') <> 'finished'
  );

  delete from public.rooms
  where created_at < now() - interval '24 hours'
    and coalesce(status, '') <> 'finished';

  delete from public.matchmaking_queue
  where created_at < now() - interval '10 minutes';
end;
$$;

revoke all on function public.cleanup_stale_rooms() from public;

-- 2) Saatlik cron (pg_cron yüklüyse):
-- select cron.schedule(
--   'cleanup-stale-rooms',
--   '17 * * * *',
--   $$select public.cleanup_stale_rooms()$$
-- );
