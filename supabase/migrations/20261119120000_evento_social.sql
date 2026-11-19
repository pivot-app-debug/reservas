-- Evento social (Naviquinde, Victor 2026-11-19; ver NAVIQUINDE.md).
-- Un evento de tipo "Social" (asistencias.tipo_evento = 'Social') tiene una
-- fila en social_eventos con los módulos activos. Todo se lee y escribe por
-- la Edge Function `api` (acciones social*), nunca directo desde el cliente.
-- `clave` identifica a quien participa: el username de la cuenta, o
-- 'inv:<id>' para unx invitadx +1 (entra sin cuenta, con su token).

create table if not exists public.social_eventos (
  id_evento text primary key,
  amigo_secreto boolean not null default true,
  regalo_robado boolean not null default false,
  comida boolean not null default true,
  invitados boolean not null default true,
  tope_amigo numeric,
  tope_robado numeric,
  recordatorio_robado text,
  cierre date,
  sorteado_en timestamptz,
  sorteado_por text,
  creado_por text,
  created_at timestamptz not null default now(),
  liga_id uuid not null default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de') references public.ligas(id)
);

create table if not exists public.social_invitados (
  id uuid primary key default gen_random_uuid(),
  id_evento text not null references public.social_eventos(id_evento) on delete cascade,
  anfitrion text not null,
  nombre text not null,
  contacto text,
  token text not null unique,
  created_at timestamptz not null default now(),
  liga_id uuid not null default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de') references public.ligas(id)
);
create index if not exists social_invitados_evento on public.social_invitados (id_evento);

-- Pistas sobre mí y wishlist: por persona (no por evento), quedan para el año siguiente.
create table if not exists public.social_perfiles (
  liga_id uuid not null default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de') references public.ligas(id),
  clave text not null,
  gustos jsonb not null default '[]'::jsonb,
  sobre_mi jsonb not null default '[]'::jsonb,
  no_regalar jsonb not null default '[]'::jsonb,
  tallas jsonb not null default '{}'::jsonb,
  wishlist jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (liga_id, clave)
);

-- Sorteo del amigo secreto: quién le regala a quién. `anio` sirve de
-- historial para no repetir la pareja del año anterior en la misma liga.
create table if not exists public.social_sorteo (
  id_evento text not null references public.social_eventos(id_evento) on delete cascade,
  da text not null,
  recibe text not null,
  anio int not null,
  revelado_en timestamptz,
  liga_id uuid not null default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de') references public.ligas(id),
  primary key (id_evento, da)
);
create index if not exists social_sorteo_liga_anio on public.social_sorteo (liga_id, anio);

create table if not exists public.social_comida_categorias (
  id uuid primary key default gen_random_uuid(),
  id_evento text not null references public.social_eventos(id_evento) on delete cascade,
  nombre text not null,
  unidad text not null default 'porciones',
  por_persona numeric not null default 1,
  orden int not null default 0,
  liga_id uuid not null default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de') references public.ligas(id)
);
create index if not exists social_comida_categorias_evento on public.social_comida_categorias (id_evento);

create table if not exists public.social_comida_aportes (
  id uuid primary key default gen_random_uuid(),
  categoria_id uuid not null references public.social_comida_categorias(id) on delete cascade,
  clave text not null,
  nombre text not null,
  cantidad numeric not null,
  detalle text,
  created_at timestamptz not null default now(),
  liga_id uuid not null default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de') references public.ligas(id)
);
create index if not exists social_comida_aportes_categoria on public.social_comida_aportes (categoria_id);

do $$
declare t text;
begin
  foreach t in array array['social_eventos', 'social_invitados', 'social_perfiles', 'social_sorteo', 'social_comida_categorias', 'social_comida_aportes'] loop
    execute format('create index if not exists %I on public.%I (liga_id)', t || '_liga', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant all on public.%I to service_role, liga_api', t);
    execute format('drop policy if exists liga_aislada on public.%I', t);
    execute format('create policy liga_aislada on public.%I for all to liga_api using (liga_id = liga_actual()) with check (liga_id = liga_actual())', t);
  end loop;
end $$;
