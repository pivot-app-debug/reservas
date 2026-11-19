-- "Pedir comprobante (24 h)" (Victor, 2026-11-19): en vez de rechazar por
-- falta de comprobante, el Pivot da 24 h para adjuntarlo. Si llega esta hora
-- sin comprobante, la solicitud se descarta sola (cron horario y al consultar).
-- Aditiva: null = sin plazo (como hasta ahora).
alter table public.reservas add column if not exists comprobante_limite timestamptz;

create index if not exists reservas_comprobante_limite_idx
  on public.reservas (comprobante_limite)
  where comprobante_limite is not null and estado = 'Pendiente';
