-- Qué datos de salud se usan (sin nombre) en la comida de los eventos
-- (Victor, 2026-11-20): JSON {"dieta": bool, "alergias": [texto]}. Vacío = nada.
alter table equipo add column if not exists comida_eventos text not null default '';
