-- Temporadas de descanso con reglas (Victor, 2026-11-15): {congela, sinCuota}.
-- congela: el período no cuenta para subir o bajar de equipo (la ventana se
-- estira hacia atrás esos días). sinCuota: los meses completos dentro del
-- descanso no se cobran. Por defecto nada cambia (las temporadas ya creadas
-- siguen igual). Aditiva.
alter table public.temporadas_descanso add column if not exists reglas jsonb not null default '{}'::jsonb;
