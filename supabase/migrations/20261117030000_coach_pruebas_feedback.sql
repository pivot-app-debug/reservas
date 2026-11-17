-- Coach etapa 3 (Victor, 2026-11-16): pruebas que se repiten por persona,
-- feedback 1–10 por tema al terminar un evento y recordatorios al coach.
create table if not exists coach_pruebas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  unidad text not null default 'vueltas',
  mas_es_mejor boolean not null default true,
  personas text[] not null default '{}',          -- vacío = todxs lxs de sus equipos
  activa boolean not null default true,
  visible text not null default 'jugadorx' check (visible in ('yo','coaches','pivots','jugadorx')),
  creado_por text not null,
  created_at timestamptz not null default now()
);
create table if not exists coach_marcas (
  id uuid primary key default gen_random_uuid(),
  prueba_id uuid not null references coach_pruebas(id) on delete cascade,
  username text not null,
  valor numeric not null,
  id_evento text,
  fecha date not null,
  coach text not null,
  creado_en timestamptz not null default now()
);
create index if not exists coach_marcas_persona on coach_marcas (username, prueba_id, fecha);
create table if not exists coach_feedback (
  id uuid primary key default gen_random_uuid(),
  id_evento text not null,
  fecha date not null,
  username text not null,
  tema text not null default 'General',
  nota int check (nota between 1 and 10),
  comentario text,
  por_voz boolean not null default false,
  visible text not null default 'yo' check (visible in ('yo','coaches','pivots','jugadorx')),
  coach text not null,
  creado_en timestamptz not null default now()
);
create index if not exists coach_feedback_persona on coach_feedback (username, tema, fecha);
create index if not exists coach_feedback_evento on coach_feedback (id_evento, coach);
create table if not exists coach_recordatorios (
  id_evento text not null,
  coach text not null,
  etapa int not null,                              -- 1 = a las 2 horas, 2 = al día siguiente
  enviado_en timestamptz not null default now(),
  primary key (id_evento, coach, etapa)
);
alter table coach_pruebas enable row level security;
alter table coach_marcas enable row level security;
alter table coach_feedback enable row level security;
alter table coach_recordatorios enable row level security;
