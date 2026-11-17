-- Planes del evento por equipo (Victor, 2026-11-17): uno por equipo ('' =
-- toda la liga) y quién lo da (`da`, usernames). Un plan sin evento
-- (id_evento null) queda guardado sin fecha, por ejemplo al cancelar.
alter table public.coach_planes drop constraint if exists coach_planes_pkey;
alter table public.coach_planes add column if not exists id uuid not null default gen_random_uuid();
alter table public.coach_planes add primary key (id);
alter table public.coach_planes alter column id_evento drop not null;
alter table public.coach_planes alter column fecha drop not null;
alter table public.coach_planes add column if not exists equipo text not null default '';
alter table public.coach_planes add column if not exists da text[] not null default '{}';
create unique index if not exists coach_planes_evento_equipo on public.coach_planes (liga_id, id_evento, equipo);
