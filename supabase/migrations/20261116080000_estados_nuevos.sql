-- Estados nuevos (Victor, 2026-11-15): Enfermedad, Situación personal y Otro.
-- Qué hace cada uno (congela el equipo, exime de cuota) vive en
-- config_app.reglas_liga.estados. Aditiva: solo amplía la lista permitida.
alter table public.equipo drop constraint if exists equipo_estado_miembro_check;
alter table public.equipo add constraint equipo_estado_miembro_check
  check (estado_miembro = any (array['Activx', 'Ausente', 'Técnico', 'Lesionadx', 'De viaje', 'Enfermedad', 'Situación personal', 'Otro']));
