-- Equipamiento armado por cada liga (Victor, 2026-11-17): cualquier lista
-- del inventario puede ser "para entrenar" (la persona la usa de la liga);
-- lo que cada persona usa queda en `equipo.equipo_liga` {listaId: talla o
-- piezas}; cada equipo pide equipamiento propio con `requisitos.propio`
-- [listaId]. Las columnas viejas (necesita_patines, talla,
-- necesita_protecciones, patinesPropios…) siguen sincronizadas.
alter table public.inventario_listas add column if not exists para_entrenar boolean not null default false;
update public.inventario_listas set para_entrenar = true where sistema in ('patines', 'protecciones');

alter table public.equipo add column if not exists equipo_liga jsonb not null default '{}'::jsonb;
update public.equipo e set equipo_liga =
  (case when e.necesita_patines = 'Sí' then coalesce((
     select jsonb_build_object(l.id::text, coalesce(e.talla, '')) from public.inventario_listas l
     where l.sistema = 'patines' and l.liga_id = e.liga_id limit 1), '{}'::jsonb) else '{}'::jsonb end)
  ||
  (case when coalesce(e.necesita_protecciones, 'No') not in ('No', '') then coalesce((
     select jsonb_build_object(l.id::text, case when e.necesita_protecciones = 'Sí' then '' else e.necesita_protecciones end) from public.inventario_listas l
     where l.sistema = 'protecciones' and l.liga_id = e.liga_id limit 1), '{}'::jsonb) else '{}'::jsonb end);

update public.config_tiers t set requisitos = coalesce(t.requisitos, '{}'::jsonb) || jsonb_build_object('propio', (
  select coalesce(jsonb_agg(l.id::text), '[]'::jsonb) from public.inventario_listas l
  where l.liga_id = t.liga_id and (
    (l.sistema = 'patines' and (t.requisitos ->> 'patinesPropios') = 'true') or
    (l.sistema = 'protecciones' and (t.requisitos ->> 'proteccionesPropias') = 'true'))));

alter table public.reservas add column if not exists equipo jsonb;
