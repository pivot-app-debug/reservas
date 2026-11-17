-- Curso (varias clases, con clínicas y evaluación final opcionales) o
-- clínica (una sola sesión) (Victor, 2026-11-17). Cada fecha de `fechas`
-- puede traer tipo ('clase' | 'clinica' | 'evaluacion'), titulo y termina.
alter table public.cursos add column if not exists tipo text not null default 'curso';
