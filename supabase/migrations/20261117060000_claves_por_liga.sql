-- Varias ligas: los ajustes (config_app) y las listas de sistema del
-- inventario son únicos dentro de cada liga, no en toda la app.
alter table config_app drop constraint if exists config_app_pkey;
alter table config_app add primary key using index config_app_liga_key;
alter table inventario_listas drop constraint if exists inventario_listas_sistema_key;
