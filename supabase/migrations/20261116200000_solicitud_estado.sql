-- Pedido de estado (Lesionadx, Enfermedad, Situación personal, Otro) que
-- aprueba un Pivot (Victor, 2026-11-16). null = sin pedido pendiente.
alter table public.equipo add column if not exists solicitud_estado text;
alter table public.equipo add column if not exists solicitud_estado_en timestamptz;
