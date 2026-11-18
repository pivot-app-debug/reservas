-- Estado de las notificaciones de cada persona (Victor, 2026-11-18): la app
-- lo informa al abrirse; los Pivots ven en Equipo quién las tiene apagadas.
alter table public.equipo add column if not exists avisos text;
alter table public.equipo add column if not exists avisos_en timestamptz;
comment on column public.equipo.avisos is 'activos | pendiente | bloqueados | instalar | sin_soporte (lo informa la app)';
