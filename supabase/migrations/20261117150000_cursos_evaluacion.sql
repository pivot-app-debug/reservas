-- Evaluación de cursos por temas (Victor, 2026-11-17): cada clase tiene
-- temas cortos (habilidades de la lista); la evaluación junta los temas con
-- nota del 1 al 10 y un mínimo por tema (5 por defecto). Al aprobar, la
-- persona solo cambia de equipo si el curso lo dice (`cambia_equipo`).
alter table public.cursos add column if not exists evaluacion jsonb not null default '{}'::jsonb;
alter table public.cursos add column if not exists cambia_equipo boolean not null default false;
update public.cursos set cambia_equipo = true where equipo_destino is not null;
alter table public.curso_inscripciones add column if not exists notas jsonb;
