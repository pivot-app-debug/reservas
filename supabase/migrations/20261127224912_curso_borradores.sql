-- Curso a medio armar (Victor, 2026-11-27): un borrador por Pivot, para
-- «Reanudar» el asistente desde Cursos o desde Notificaciones.
create table if not exists public.curso_borradores (
  id uuid primary key default gen_random_uuid(),
  creado_por text not null,
  username text,
  datos jsonb not null,
  actualizado_en timestamptz not null default now(),
  liga_id uuid not null default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de') references public.ligas(id),
  unique (liga_id, creado_por)
);
create index if not exists curso_borradores_username on public.curso_borradores (liga_id, username);
alter table public.curso_borradores enable row level security;
revoke all on public.curso_borradores from anon, authenticated;
grant all on public.curso_borradores to service_role, liga_api;
create policy liga_aislada on public.curso_borradores for all to liga_api using (liga_id = liga_actual()) with check (liga_id = liga_actual());
