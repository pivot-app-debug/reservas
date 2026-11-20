-- Permisos por encargadx y comida administrable (Victor, 2026-11-20).
alter table public.social_eventos add column if not exists permisos jsonb not null default '{}'::jsonb;
comment on column public.social_eventos.permisos is 'Qué puede editar cada encargadx: {username: [fecha, amigo, comida, extras, invitados, homenaje]}. Quien crea edita todo.';
alter table public.social_comida_categorias add column if not exists falta boolean not null default false;
alter table public.social_comida_categorias add column if not exists sugerencias jsonb not null default '[]'::jsonb;
comment on column public.social_comida_categorias.falta is 'Quien está a cargo de la comida marcó que hace falta';
comment on column public.social_comida_categorias.sugerencias is 'Ideas de qué traer en esta categoría (textos cortos)';
