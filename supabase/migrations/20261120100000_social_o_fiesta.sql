-- "Social o fiesta" (Victor, 2026-11-20; NAVIQUINDE.md, "Segunda versión").
-- SIN APLICAR: Victor la pega en el editor SQL. Requiere 20261119120000_evento_social.sql
-- (y conviene 20261120030000_notificaciones_alcance.sql para invitar por equipos).
-- Aditiva: solo agrega columnas, tablas, índices y políticas. No borra ni cambia filas.
--
-- Cualquier persona de la liga crea un "Social o fiesta" (el valor guardado
-- sigue siendo asistencias.tipo_evento = 'Social'), armado por piezas. Un
-- Pivot lo aprueba antes de que se vea en el calendario (`aprobado_en`); nunca
-- una persona homenajeada ni alguien que no debe enterarse. Sorpresa: esas
-- personas ven el evento con `nombre_neutro`, sin homenaje, mensajes ni regalo
-- (lo filtra la Edge Function `api`, social.ts / social_reglas.ts).
-- La Edge Function ya funciona sin esta migración (todo evento social cuenta
-- como publicado y sin piezas nuevas); crear uno nuevo desde la app la necesita.

-- `aprobado_en` nace con now(): los eventos sociales que ya existen quedan
-- publicados (los creó un Pivot). La función siempre escribe este campo al crear.
alter table public.social_eventos add column if not exists aprobado_en timestamptz default now();
alter table public.social_eventos add column if not exists aprobado_por text;
alter table public.social_eventos add column if not exists rechazado_en timestamptz;
alter table public.social_eventos add column if not exists rechazo_motivo text;
alter table public.social_eventos add column if not exists creador text;                       -- username de quien lo creó
alter table public.social_eventos add column if not exists encargados text[] not null default '{}';
alter table public.social_eventos add column if not exists plantilla text;                     -- fiesta | festividad | cumpleanos | aniversario | despedida | personalizado
alter table public.social_eventos add column if not exists festividad text;                    -- Navidad, Año nuevo, Halloween, Día de muertos, Pascua u otra
alter table public.social_eventos add column if not exists nombre text;
alter table public.social_eventos add column if not exists nombre_neutro text;                 -- lo que ven homenajeadxs y quienes no deben enterarse
alter table public.social_eventos add column if not exists descripcion text;
alter table public.social_eventos add column if not exists para jsonb;                         -- {tipo: equipos|liga|personas, valores: []}
alter table public.social_eventos add column if not exists piezas jsonb not null default '{}'::jsonb; -- playlist, dress, traer, premios, homenaje
alter table public.social_eventos add column if not exists sorpresa boolean not null default false;
alter table public.social_eventos add column if not exists homenajeados text[] not null default '{}';
alter table public.social_eventos add column if not exists no_enterarse text[] not null default '{}';
alter table public.social_eventos add column if not exists mensajes_liberados_en timestamptz;
alter table public.social_eventos add column if not exists regalo_tope numeric;                -- regalo entre todxs: solo se anota, nunca pasa por Finanzas
alter table public.social_eventos add column if not exists regalo_compra text;                 -- username de quien compra
alter table public.social_eventos add column if not exists reglas_robado text;                 -- null = plantilla de la app
alter table public.social_eventos add column if not exists recordatorio_enviado_en timestamptz;
alter table public.social_eventos add column if not exists actualizado_en timestamptz;

create index if not exists social_eventos_por_aprobar on public.social_eventos (liga_id) where aprobado_en is null;

-- Lista "qué traer": las cosas las arma quien organiza (social_eventos.piezas.traer);
-- aquí se anota quién lleva cada una.
create table if not exists public.social_traer_anotes (
  id uuid primary key default gen_random_uuid(),
  id_evento text not null references public.social_eventos(id_evento) on delete cascade,
  item text not null,
  clave text not null,
  nombre text not null,
  detalle text,
  created_at timestamptz not null default now(),
  liga_id uuid not null default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de') references public.ligas(id)
);
create index if not exists social_traer_anotes_evento on public.social_traer_anotes (id_evento);

-- Homenaje: mensajes de todxs para cada persona homenajeada. Ella los lee
-- después del evento o cuando quien organiza los libera.
create table if not exists public.social_mensajes (
  id uuid primary key default gen_random_uuid(),
  id_evento text not null references public.social_eventos(id_evento) on delete cascade,
  para text not null,
  clave text not null,
  nombre text not null,
  texto text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  liga_id uuid not null default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de') references public.ligas(id),
  unique (id_evento, para, clave)
);
create index if not exists social_mensajes_evento on public.social_mensajes (id_evento);

-- Regalo entre todxs: quién aporta cuánto. Es solo una anotación: no crea
-- movimientos ni pasa por Finanzas.
create table if not exists public.social_regalo_aportes (
  id uuid primary key default gen_random_uuid(),
  id_evento text not null references public.social_eventos(id_evento) on delete cascade,
  clave text not null,
  nombre text not null,
  monto numeric not null,
  created_at timestamptz not null default now(),
  liga_id uuid not null default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de') references public.ligas(id),
  unique (id_evento, clave)
);
create index if not exists social_regalo_aportes_evento on public.social_regalo_aportes (id_evento);

do $$
declare t text;
begin
  foreach t in array array['social_traer_anotes', 'social_mensajes', 'social_regalo_aportes'] loop
    execute format('create index if not exists %I on public.%I (liga_id)', t || '_liga', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant all on public.%I to service_role, liga_api', t);
    execute format('drop policy if exists liga_aislada on public.%I', t);
    execute format('create policy liga_aislada on public.%I for all to liga_api using (liga_id = liga_actual()) with check (liga_id = liga_actual())', t);
  end loop;
end $$;
