-- Aviso del cambio de equipo y pedido de revisión (Victor, 2026-11-16).
alter table public.equipo add column if not exists aviso_cambio_equipo jsonb;
alter table public.equipo add column if not exists revision_cambio jsonb;
alter table public.equipo add column if not exists equipo_fijo_hasta date;
