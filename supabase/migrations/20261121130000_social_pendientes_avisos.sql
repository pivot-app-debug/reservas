-- Avisos de pendientes de una fiesta (Victor, 2026-11-21): 1 vez por pendiente y
-- un recordatorio 2 días antes del cierre si sigue pendiente.
create table if not exists social_pendientes_avisos (
  id uuid primary key default gen_random_uuid(),
  liga_id uuid default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de'::uuid) not null references ligas(id),
  id_evento text not null,
  clave text not null,
  tipo text not null,
  enviado_en timestamptz not null default now(),
  recordado_en timestamptz,
  unique (liga_id, id_evento, clave, tipo)
);
alter table social_pendientes_avisos enable row level security;
create policy liga_aislada on social_pendientes_avisos for all to liga_api using (liga_id = liga_actual()) with check (liga_id = liga_actual());
grant select, insert, update, delete on social_pendientes_avisos to liga_api;
