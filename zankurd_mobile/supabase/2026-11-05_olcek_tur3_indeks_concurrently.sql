-- 2026-11-05_olcek_tur3.sql ile ilgili BÜYÜK tablo indeksleri. begin/commit
-- YOK: CREATE INDEX CONCURRENTLY transaction içinde çalışmaz; psql ya da
-- `supabase db query` ile bölünmeden koşulur. Idempotent. Yazmaları bloklamaz.
-- Not: player_answers (room_id, created_at) ve room_invites (room_id,
-- created_at) EKLENMEZ: tekil kısıtların room_id öneki zaten indeksli ve oda
-- başına satır sayısı küçük; sıcak yazma tablosuna gereksiz indeks yazma yükü
-- olurdu (kod doğrulaması: 2026-11-05_olcek_tur3.sql başı).

-- cleanup_stale_rooms (5 dk'da bir): yalnız lobby/active odaları tarar;
-- bitmiş oda sayısı büyüdükçe tablo taraması gerekmez.
create index concurrently if not exists idx_rooms_open_created
  on public.rooms (created_at) where status in ('lobby', 'active');

-- Gecelik mutabakat ve sıralama sınır günü sorgusu (11-04 dosyasıyla aynı ad).
create index concurrently if not exists idx_rooms_finished_at_finished
  on public.rooms (finished_at) where status = 'finished';

-- push_outbox saklama silmesi.
create index concurrently if not exists push_outbox_terminal_created_idx
  on public.push_outbox (created_at)
  where delivery_status in ('sent', 'skipped', 'failed', 'legacy');

-- rate_limit_events süpürmesi.
create index concurrently if not exists rate_limit_events_created_idx
  on public.rate_limit_events (created_at);
