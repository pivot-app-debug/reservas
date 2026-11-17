-- Para quién es un curso (Victor, 2026-11-17): toda la liga, equipos, un
-- nivel de Coach o personas específicas (curso individual). Cursos abiertos:
-- se repiten cada semana (`repite`: días, hora, lugar; un venue de "Días de
-- la semana") hasta que se terminan; sus temas van en `temas`.
alter table public.cursos add column if not exists para jsonb not null default '{"tipo":"todos"}'::jsonb;
alter table public.cursos add column if not exists abierto boolean not null default false;
alter table public.cursos add column if not exists repite jsonb;
alter table public.cursos add column if not exists venue_repite uuid;
alter table public.cursos add column if not exists temas jsonb not null default '[]'::jsonb;
