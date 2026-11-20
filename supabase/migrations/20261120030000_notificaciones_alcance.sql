-- Alcance de los avisos de eventos (Victor, 2026-11-20). SIN APLICAR.
-- `asistencias.equipos`: equipos (`equipo.categoria`) para los que es el
-- evento. NULL o vacío = toda la liga (lo de siempre). Con equipos, los
-- avisos del evento (nuevo, cambios, cancelación, recordatorios, asistencia)
-- solo llegan a personas de esos equipos, sus coaches y los Pivots; la
-- bandeja "Del equipo" tampoco muestra su asistencia a otros equipos.
-- La Edge Function `api` ya lo lee (`_equiposDeEventos`) y, mientras esta
-- columna no exista, trata todo evento como de toda la liga.
-- Aditiva: no cambia ninguna fila ni permiso existente.

alter table public.asistencias add column if not exists equipos text[];

comment on column public.asistencias.equipos is
  'Equipos (equipo.categoria) para los que es el evento. NULL o vacío = toda la liga. Lo usa el alcance de los avisos (api: _filtrarDestinatariosEvento).';
