-- Notificaciones de entrenador (Victor, 2026-11-26): personas a las que cada entrenadorx no les manda avisos.
alter table public.coaches add column if not exists sin_avisos text[] not null default '{}';
