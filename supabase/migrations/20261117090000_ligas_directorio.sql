-- Crear una liga y directorio "Ligas en Pivot" (Victor, 2026-11-17).
alter table ligas add column if not exists deporte text not null default 'roller_derby';
alter table ligas add column if not exists ciudad text;
alter table ligas add column if not exists visible boolean not null default true;
alter table ligas add column if not exists contacto jsonb not null default '{}';
alter table ligas add column if not exists mostrar_comunidad boolean not null default false;
alter table ligas add column if not exists creada_por text;
create table if not exists pivot_duenos (email text primary key, creado_en timestamptz not null default now());
alter table pivot_duenos enable row level security;
grant select, insert, update, delete on ligas, pivot_duenos to service_role;
update ligas set ciudad = 'Quito' where id = '00000000-0000-4000-8000-00000000c0de' and ciudad is null;
-- (El correo del dueño de Pivot se cargó a mano, no va en el repositorio.)
notify pgrst, 'reload schema';
