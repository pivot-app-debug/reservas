-- Foto por artículo del inventario (Victor, 2026-11-26).
alter table public.inventario_stock add column if not exists foto text;
