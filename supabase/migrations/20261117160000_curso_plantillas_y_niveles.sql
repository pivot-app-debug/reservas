-- Plantillas de cursos (Victor, 2026-11-17): clases con temas y evaluación
-- para repetir un curso. Freshmeat (roller derby) se arma de la lista de
-- habilidades, no se guarda aquí. Niveles: cada habilidad es básica o
-- avanzada; `equipo.nivel_coach` fija a mano el nivel de una persona en
-- Coach ('sin', 'basicas', 'avanzadas'; null = calculado).
create table if not exists public.curso_plantillas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  tipo text not null default 'curso',
  descripcion text,
  clases jsonb not null default '[]'::jsonb,
  evaluacion jsonb not null default '{}'::jsonb,
  creado_por text,
  created_at timestamptz not null default now(),
  liga_id uuid not null default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de') references public.ligas(id)
);
create index if not exists curso_plantillas_liga on public.curso_plantillas (liga_id);
alter table public.curso_plantillas enable row level security;
revoke all on public.curso_plantillas from anon, authenticated;
grant all on public.curso_plantillas to service_role, liga_api;
create policy liga_aislada on public.curso_plantillas for all to liga_api using (liga_id = liga_actual()) with check (liga_id = liga_actual());

alter table public.coach_habilidades add column if not exists nivel text not null default 'basica';
alter table public.equipo add column if not exists nivel_coach text;
