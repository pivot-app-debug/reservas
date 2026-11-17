-- Varias ligas: las tablas nuevas quedan accesibles para el rol por liga.
-- OJO: cada tabla nueva igual necesita su columna liga_id y su política
-- (ver MANIFEST, "Varias ligas").
alter default privileges in schema public grant select, insert, update, delete on tables to liga_api;
alter default privileges in schema public grant usage, select on sequences to liga_api;
alter default privileges in schema public grant execute on functions to liga_api;
