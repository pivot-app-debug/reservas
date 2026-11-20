-- Al marcar Asistiré en una fiesta, cada quien elige si participa del amigo
-- secreto y del regalo robado (Victor, 2026-11-20). Sin fila = participa.
create table if not exists social_participacion (
  id_evento text not null,
  clave text not null,
  liga_id text,
  amigo boolean not null default true,
  robado boolean not null default true,
  respondido_en timestamptz not null default now(),
  primary key (id_evento, clave)
);
alter table social_participacion enable row level security;
