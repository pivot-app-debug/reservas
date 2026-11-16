-- Planes de pago (Victor, 2026-11-16): N meses o N clases con precio propio,
-- para equipos o personas. Los de clases dan créditos al aprobarse el pago.
create table if not exists public.planes (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  tipo text not null check (tipo in ('meses', 'clases')),
  cantidad int not null check (cantidad between 1 and 100),
  precio numeric not null check (precio >= 0),
  vence_meses int not null default 3 check (vence_meses between 1 and 24),
  equipos text[],
  personas text[],
  activo boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.plan_creditos (
  id uuid primary key default gen_random_uuid(),
  username text not null,
  plan_id uuid references public.planes(id) on delete set null,
  reserva_id uuid,
  nombre text not null default '',
  total int not null,
  usadas int not null default 0,
  vence date not null,
  created_at timestamptz not null default now()
);
create index if not exists plan_creditos_username on public.plan_creditos(username);
alter table public.reservas add column if not exists plan_id uuid;
alter table public.reservas add column if not exists plan_credito_id uuid;
alter table public.planes enable row level security;
alter table public.plan_creditos enable row level security;
revoke all on public.planes, public.plan_creditos from anon, authenticated;
