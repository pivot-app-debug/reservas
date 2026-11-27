-- Tareas recurrentes con personas fijas (Victor, 2026-11-26): se asignan solas en cada repetición.
alter table public.tareas_recurrentes add column if not exists personas_fijas text[] not null default '{}';
