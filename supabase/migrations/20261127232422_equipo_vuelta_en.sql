-- Vuelta de un viaje, lesión o ausencia con motivo (Victor, 2026-11-27): los
-- días de inactividad se cuentan desde la última asistencia real o desde la
-- vuelta, lo más reciente (antes, al volver de un viaje largo se pasaba a
-- Inactivx de inmediato).
alter table public.equipo add column if not exists vuelta_en date;
