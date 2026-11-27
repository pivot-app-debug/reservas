-- Niveles de habilidades propios de cada liga (Victor, 2026-11-27): en vez de
-- básica y avanzada fijos, una lista en orden con su regla para completarse.
-- coach_habilidades.nivel guarda la clave del nivel. Las dos de siempre quedan
-- con la misma regla de antes (básicas: 80 %; avanzadas: lograr una), así que
-- nadie cambia de nivel.
create table if not exists public.coach_niveles (
  id uuid primary key default gen_random_uuid(),
  liga_id uuid default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de'::uuid) not null references ligas(id),
  clave text not null,
  nombre text not null,
  orden int not null default 1,
  regla text not null default 'porcentaje' check (regla in ('porcentaje', 'todas', 'una')),
  porcentaje int not null default 80 check (porcentaje between 1 and 100),
  created_at timestamptz not null default now(),
  unique (liga_id, clave)
);
alter table public.coach_niveles enable row level security;
drop policy if exists liga_aislada on public.coach_niveles;
create policy liga_aislada on public.coach_niveles for all to liga_api using (liga_id = liga_actual()) with check (liga_id = liga_actual());
grant select, insert, update, delete on public.coach_niveles to liga_api;

insert into public.coach_niveles (liga_id, clave, nombre, orden, regla, porcentaje)
select l.id, x.clave, x.nombre, x.orden, x.regla, x.porcentaje
from public.ligas l
cross join (values ('basica', 'Habilidades básicas', 1, 'porcentaje', 80), ('avanzada', 'Habilidades avanzadas', 2, 'una', 80)) as x(clave, nombre, orden, regla, porcentaje)
on conflict (liga_id, clave) do nothing;
