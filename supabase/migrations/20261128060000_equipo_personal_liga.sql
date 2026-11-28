-- Personal de liga (Victor, 2026-11-27): sin equipo, sin cuota ni puntos.
alter table public.equipo add column if not exists personal_liga boolean not null default false;
