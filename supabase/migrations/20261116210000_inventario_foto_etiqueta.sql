-- Inventario: foto por lista y etiqueta por fila de stock (Victor, 2026-11-16).
alter table public.inventario_listas add column if not exists foto text;
alter table public.inventario_stock add column if not exists etiqueta text;
