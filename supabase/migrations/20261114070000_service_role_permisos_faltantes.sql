-- Arreglo (2026-11-14): el servidor (service_role) había perdido SELECT,
-- INSERT, UPDATE y DELETE sobre estas tablas ("permission denied" al crear
-- una temporada de descanso, rectificaciones, excepciones de cuota y
-- asistencia anticipada). La clave pública (anon) no recibe nada nuevo.
grant select, insert, update, delete on table public.temporadas_descanso to service_role;
grant select, insert, update, delete on table public.rectificaciones_asistencia to service_role;
grant select, insert, update, delete on table public.solicitudes_excepcion to service_role;
grant select, insert, update, delete on table public.reglas_asistencia to service_role;
