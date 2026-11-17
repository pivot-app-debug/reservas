-- Sección Coach (Victor, 2026-11-16). Solo el servidor (service role) lee y
-- escribe: RLS activo sin políticas.
create table if not exists coaches (
  username text primary key,
  estado text not null default 'pendiente' check (estado in ('pendiente','aprobado','rechazado')),
  equipos text[] not null default '{}',          -- vacío = todos los equipos
  mensaje text,
  pedido_en timestamptz not null default now(),
  resuelto_por text,
  resuelto_en timestamptz
);

-- Lista de habilidades de la liga: parte de las de WFTDA y se puede editar.
create table if not exists coach_habilidades (
  id uuid primary key default gen_random_uuid(),
  categoria text not null,
  nombre text not null,
  orden int not null default 0,
  activa boolean not null default true,
  created_at timestamptz not null default now()
);

-- Evaluación de una habilidad: cada registro queda (historial).
create table if not exists coach_evaluaciones (
  id uuid primary key default gen_random_uuid(),
  username text not null,
  habilidad_id uuid not null references coach_habilidades(id) on delete cascade,
  nivel text not null check (nivel in ('no','proceso','logrado')),
  coach text not null,
  creado_en timestamptz not null default now()
);
create index if not exists coach_evaluaciones_persona on coach_evaluaciones (username, habilidad_id, creado_en desc);

-- Notas sobre una persona (escritas o dictadas). visible: quién más las ve.
create table if not exists coach_notas (
  id uuid primary key default gen_random_uuid(),
  username text not null,
  coach text not null,
  texto text not null,
  por_voz boolean not null default false,
  visible text not null default 'yo' check (visible in ('yo','coaches','pivots','jugadorx')),
  id_evento text,
  creado_en timestamptz not null default now()
);
create index if not exists coach_notas_persona on coach_notas (username, creado_en desc);

-- Cronograma: qué se ve en cada evento del calendario.
create table if not exists coach_planes (
  id_evento text primary key,
  fecha date not null,
  coach text not null,
  bloques jsonb not null default '[]',             -- [{"titulo","minutos","detalle"}]
  compartido boolean not null default false,        -- lxs jugadorxs ven "qué veremos"
  actualizado_en timestamptz not null default now()
);

alter table coaches enable row level security;
alter table coach_habilidades enable row level security;
alter table coach_evaluaciones enable row level security;
alter table coach_notas enable row level security;
alter table coach_planes enable row level security;

-- Lista base (habilidades de WFTDA, nombres propios de la liga; editable).
insert into coach_habilidades (categoria, nombre, orden)
select * from (values
  ('Postura y equilibrio', 'Postura derby', 10),
  ('Postura y equilibrio', 'Patinar en un pie (ambos)', 11),
  ('Postura y equilibrio', 'Cruces hacia adelante', 12),
  ('Postura y equilibrio', 'Patinar hacia atrás', 13),
  ('Caídas', 'Caída en una rodilla (ambas)', 20),
  ('Caídas', 'Caída en dos rodillas', 21),
  ('Caídas', 'Caída completa (de lado)', 22),
  ('Caídas', 'Levantarse rápido después de caer', 23),
  ('Frenos', 'Plow (snowplow)', 30),
  ('Frenos', 'T-stop', 31),
  ('Frenos', 'Hockey stop', 32),
  ('Frenos', 'Freno hacia atrás (plow invertido)', 33),
  ('Frenos', 'Tomahawk', 34),
  ('Transiciones y agilidad', 'Transiciones (giro de frente a espalda y viceversa)', 40),
  ('Transiciones y agilidad', 'Saltos', 41),
  ('Transiciones y agilidad', 'Esquivar y cambiar de línea', 42),
  ('Transiciones y agilidad', 'Pasos laterales', 43),
  ('Contacto', 'Recibir contacto', 50),
  ('Contacto', 'Dar bloqueos legales', 51),
  ('Contacto', 'Contacto en pack', 52),
  ('Trabajo en equipo', 'Patinar en pack', 60),
  ('Trabajo en equipo', 'Pace line y paredes', 61),
  ('Trabajo en equipo', 'Comunicación en pista', 62),
  ('Resistencia', 'Vueltas en 5 minutos (27 o más)', 70),
  ('Reglas', 'Conoce las reglas y penalidades', 80)
) as v(categoria, nombre, orden)
where not exists (select 1 from coach_habilidades);
