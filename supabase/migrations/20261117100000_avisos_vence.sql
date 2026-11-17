-- Hasta cuándo se ve un comunicado en Notificaciones (Victor, 2026-11-17).
-- null = 3 días desde que se envió.
alter table public.avisos_programados add column if not exists vence_en timestamptz;
