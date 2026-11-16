-- Recompensas automáticas (Victor, 2026-11-15): un Pivot crea reglas que
-- premian la asistencia (racha, asistencias del mes, porcentaje del mes) con
-- puntos, clase gratis, saldo a favor o la mensualidad siguiente. Aditiva.
-- Borrar una regla es lógico (`eliminada_en`): lo ya otorgado no cambia.
create table if not exists public.reglas_recompensa (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  activa boolean not null default true,
  equipo text,                -- null = toda la liga
  condicion jsonb not null,   -- {tipo: 'racha'|'asistencias_mes'|'porcentaje_mes', valor: n}
  premio jsonb not null,      -- {puntos, claseGratis, saldo, mensualidadGratis}
  desde date not null,        -- rige desde (nunca hacia atrás)
  creada_por text,
  creada_en timestamptz not null default now(),
  eliminada_en timestamptz
);
create table if not exists public.recompensas_otorgadas (
  id uuid primary key default gen_random_uuid(),
  regla_id uuid not null references public.reglas_recompensa(id),
  username text not null,
  periodo text not null,      -- 'aaaa-mm' o 'racha:<id_evento>'
  premio jsonb,               -- lo que se dio (con ids para auditar)
  creada_en timestamptz not null default now(),
  unique (regla_id, username, periodo)
);
alter table public.reglas_recompensa enable row level security;
alter table public.recompensas_otorgadas enable row level security;
