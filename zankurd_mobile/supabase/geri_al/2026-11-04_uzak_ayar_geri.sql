-- GERİ ALMA: 2026-11-04_uzak_ayar.sql
-- Tabloyu kaldırır. İstemci tablo yoksa önbellek/varsayılana düşer (her şey
-- açık, zorunlu güncelleme yok), yani geri alma güvenlidir.
begin;

drop policy if exists app_runtime_config_read on public.app_runtime_config;
drop table if exists public.app_runtime_config;

commit;
