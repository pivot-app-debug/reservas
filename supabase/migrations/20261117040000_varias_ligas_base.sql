-- Aplicada 2026-11-17 (Victor aprobó en Supabase). Aislamiento probado con una liga de prueba dentro de una transacción deshecha.
-- Base para varias ligas (Victor, 2026-11-17), fase A: aditiva y sin cambios
-- visibles. Todo lo que existe queda en Quindes Volcánicos.
--
-- Aislamiento: el servidor hablará con la base como el rol `liga_api` con un
-- JWT que lleva `liga_id`. Las políticas de RLS de ese rol solo dejan ver y
-- escribir filas de esa liga, y lo nuevo toma esa liga por defecto. Mientras
-- el servidor siga con la llave de servicio (que salta RLS), todo funciona
-- como hoy y lo nuevo cae en Quindes.

create table if not exists ligas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  slug text not null unique,
  pais text,
  moneda text,
  zona_horaria text not null default 'America/Guayaquil',
  logo text,
  creada_en timestamptz not null default now()
);
alter table ligas enable row level security;
insert into ligas (id, nombre, slug, pais, moneda)
values ('00000000-0000-4000-8000-00000000c0de', 'Quindes Volcánicos', 'quindes', 'EC', 'USD')
on conflict (id) do nothing;

-- La liga del pedido actual (del JWT), o null.
create or replace function liga_actual() returns uuid
language sql stable as $$
  select nullif(nullif(current_setting('request.jwt.claims', true), '')::json->>'liga_id', '')::uuid
$$;

-- Rol del servidor por liga (lo usa PostgREST cuando el JWT dice role=liga_api).
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'liga_api') then
    create role liga_api nologin noinherit;
  end if;
end $$;
grant liga_api to authenticator;
grant usage on schema public to liga_api;
grant select on ligas to liga_api;

do $$
declare t text;
begin
  for t in
    select tablename from pg_tables where schemaname = 'public' and tablename <> 'ligas'
  loop
    execute format('alter table public.%I add column if not exists liga_id uuid not null default coalesce(liga_actual(), %L::uuid) references ligas(id)', t, '00000000-0000-4000-8000-00000000c0de');
    execute format('create index if not exists %I on public.%I (liga_id)', t || '_liga_idx', t);
    execute format('grant select, insert, update, delete on public.%I to liga_api', t);
    execute format('drop policy if exists liga_aislada on public.%I', t);
    execute format('create policy liga_aislada on public.%I for all to liga_api using (liga_id = liga_actual()) with check (liga_id = liga_actual())', t);
  end loop;
end $$;
grant usage, select on all sequences in schema public to liga_api;
grant execute on all functions in schema public to liga_api;

-- Claves que deben ser únicas dentro de cada liga (no en toda la app).
create unique index if not exists config_app_liga_key on config_app (liga_id, key);
create unique index if not exists inventario_listas_liga_sistema on inventario_listas (liga_id, sistema);

-- Ligas: el rol por liga solo ve la suya.
drop policy if exists liga_propia on ligas;
create policy liga_propia on ligas for select to liga_api using (id = liga_actual());
