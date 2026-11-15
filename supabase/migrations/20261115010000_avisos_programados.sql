-- Avisos de los Pivots al equipo, ahora o programados (Victor, 2026-11-14).
create table if not exists public.avisos_programados (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  mensaje text not null,
  destino jsonb not null default '"todos"'::jsonb,
  enviar_en timestamptz not null,
  creado_por text,
  enviado_en timestamptz,
  cancelado_en timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists avisos_programados_pendientes on public.avisos_programados (enviar_en) where enviado_en is null and cancelado_en is null;
alter table public.avisos_programados enable row level security;
grant select, insert, update, delete on public.avisos_programados to service_role;
