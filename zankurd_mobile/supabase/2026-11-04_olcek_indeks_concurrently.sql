-- İSTEĞE BAĞLI (büyük canlı veritabanı için): 2026-11-04_olcek_sertlestirme.sql
-- ile ilgili indeksleri tablo yazmalarını BLOKLAMADAN kurar. begin/commit YOK:
-- CREATE INDEX CONCURRENTLY transaction içinde çalışmaz; dosya psql/`supabase db
-- query` ile bölünmeden, otomatik transaction olmadan koşulmalıdır. Idempotent.
-- Küçük veritabanında (≈100 profil) gerekmez; sıralama sınır günü sorgusunu ve
-- sohbet geçmişini hızlandırır.
create index concurrently if not exists idx_rooms_finished_at_finished
  on public.rooms (finished_at) where status = 'finished';
create index concurrently if not exists idx_room_messages_room_created
  on public.room_messages (room_id, created_at);
