-- Regalo robado en vivo (Victor, 2026-11-20): un estado por evento (pila, orden, turnos, regalos, historial).
create table if not exists social_regalo_juego (
  id_evento text primary key,
  liga_id text,
  estado jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table social_regalo_juego enable row level security;
