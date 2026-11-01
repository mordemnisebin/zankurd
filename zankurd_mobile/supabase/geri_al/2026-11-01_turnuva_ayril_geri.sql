-- Geri alma: 2026-11-01_turnuva_ayril.sql
-- `leave_tournament` kaldırılır; istemci fonksiyon yokluğunda (42883/PGRST202)
-- "Ayrıl" eylemini gizler. Verilere dokunulmaz.
begin;

drop function if exists public.leave_tournament();

commit;
