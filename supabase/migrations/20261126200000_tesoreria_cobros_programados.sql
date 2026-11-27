-- Cobros programados del banco (Victor, 2026-11-26): mantenimiento, SMS y otras
-- comisiones que el banco cobra solo. Cada periodo genera un egreso en la cuenta.
create table if not exists public.tesoreria_cobros_programados (
  id uuid primary key default gen_random_uuid(),
  liga_id uuid default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de'::uuid) not null references ligas(id),
  cuenta_id uuid not null,
  nombre text not null,
  monto numeric not null check (monto > 0),
  frecuencia text not null default 'mensual' check (frecuencia in ('mensual', 'anual')),
  dia smallint not null default 1 check (dia between 1 and 28),
  desde date not null,
  activo boolean not null default true,
  creado_por text,
  created_at timestamptz not null default now()
);
alter table public.tesoreria_cobros_programados enable row level security;
drop policy if exists liga_aislada on public.tesoreria_cobros_programados;
create policy liga_aislada on public.tesoreria_cobros_programados for all to liga_api using (liga_id = liga_actual()) with check (liga_id = liga_actual());
grant select, insert, update, delete on public.tesoreria_cobros_programados to liga_api;
