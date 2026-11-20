-- "¿Qué llevamos?" (Victor, 2026-11-20): comida y qué traer en una sola lista de secciones.
alter table public.social_comida_categorias add column if not exists modo text not null default 'meta';
alter table public.social_comida_categorias add column if not exists total numeric;
alter table public.social_comida_categorias add column if not exists origen_item text;
comment on column public.social_comida_categorias.modo is 'meta: asistentes x por_persona en la unidad | cada: cada persona lleva por_persona cosas | total: total fijo | libre: sin meta';
alter table public.social_comida_aportes add column if not exists para_todxs boolean;
comment on column public.social_comida_aportes.para_todxs is 'true: lo lleva para todxs; false: solo para sí; null: sin indicar';

-- Pasar los ítems de "Qué traer" a secciones (libres) con lo que cada quien anotó.
insert into public.social_comida_categorias (id_evento, liga_id, nombre, unidad, por_persona, orden, modo, origen_item)
select se.id_evento, se.liga_id, it->>'texto', 'cosas', 1,
       coalesce((select max(orden) from public.social_comida_categorias c where c.id_evento = se.id_evento), -1) + o::int, 'libre', it->>'id'
from public.social_eventos se, jsonb_array_elements(coalesce(se.piezas->'traer'->'items', '[]'::jsonb)) with ordinality as x(it, o)
where coalesce(it->>'texto', '') <> ''
  and not exists (select 1 from public.social_comida_categorias c where c.id_evento = se.id_evento and c.origen_item = it->>'id');

insert into public.social_comida_aportes (categoria_id, clave, nombre, cantidad, detalle, liga_id, created_at)
select c.id, a.clave, a.nombre, 1, a.detalle, a.liga_id, a.created_at
from public.social_traer_anotes a
join public.social_comida_categorias c on c.id_evento = a.id_evento and c.origen_item = a.item
where not exists (select 1 from public.social_comida_aportes x where x.categoria_id = c.id and x.clave = a.clave and coalesce(x.detalle,'') = coalesce(a.detalle,''));

update public.social_eventos set comida = true, piezas = piezas - 'traer' where piezas ? 'traer';
