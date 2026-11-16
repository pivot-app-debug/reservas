-- Cursos (freshmeat) con try out (Victor, 2026-11-16).
create table if not exists public.cursos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  descripcion text,
  precio numeric not null default 0,
  cupo int,
  fechas jsonb not null default '[]'::jsonb,   -- [{"fecha":"2026-12-01","hora":"19:00","lugar":"CCI"}], la última es el try out
  equipo_destino text,
  estado text not null default 'abierto' check (estado in ('abierto', 'cerrado', 'terminado')),
  created_at timestamptz not null default now()
);
create table if not exists public.curso_inscripciones (
  id uuid primary key default gen_random_uuid(),
  curso_id uuid not null references public.cursos(id) on delete cascade,
  username text not null,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'confirmada', 'cancelada')),
  reserva_id uuid,
  resultado text check (resultado in ('aprobado', 'no_aprobado')),
  equipo_final text,
  created_at timestamptz not null default now(),
  unique (curso_id, username)
);
alter table public.reservas add column if not exists curso_id uuid;
alter table public.cursos enable row level security;
alter table public.curso_inscripciones enable row level security;
revoke all on public.cursos, public.curso_inscripciones from anon, authenticated;
