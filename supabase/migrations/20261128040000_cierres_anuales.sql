-- Cierre anual de cuentas (Victor, 2026-11-27). Pendiente de aplicar.
create table if not exists public.cierres_anuales (
  id uuid primary key default gen_random_uuid(),
  liga_id uuid not null default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de'::uuid),
  anio int not null,
  cerrado_en timestamptz not null default now(),
  cerrado_por text not null,
  resumen jsonb not null default '{}'::jsonb,
  unique (liga_id, anio)
);
alter table public.cierres_anuales enable row level security;
drop policy if exists liga_aislada on public.cierres_anuales;
create policy liga_aislada on public.cierres_anuales for all to liga_api using (liga_id = liga_actual()) with check (liga_id = liga_actual());
