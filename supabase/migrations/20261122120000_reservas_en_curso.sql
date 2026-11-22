-- Reserva sin terminar (Victor, 2026-11-22): quien llegó al paso de pago y
-- cerró la app recibe un aviso a los 30 minutos (una sola vez).
create table if not exists reservas_en_curso (
  id uuid primary key default gen_random_uuid(),
  liga_id uuid default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de'::uuid) not null references ligas(id),
  nombre text not null,
  detalle text,
  clases jsonb,
  creado_en timestamptz not null default now(),
  avisado_en timestamptz,
  unique (liga_id, nombre)
);
alter table reservas_en_curso enable row level security;
create policy liga_aislada on reservas_en_curso for all to liga_api using (liga_id = liga_actual()) with check (liga_id = liga_actual());
grant select, insert, update, delete on reservas_en_curso to liga_api;
