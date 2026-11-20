-- Cupo de las cosas en "Qué lleva cada quien" (Victor, 2026-11-20):
-- 'fijo' = máximo de cosas; 'persona' = 1 cosa por cada `cupo` personas.
alter table social_comida_categorias add column if not exists cupo_tipo text check (cupo_tipo in ('fijo','persona')), add column if not exists cupo numeric;
