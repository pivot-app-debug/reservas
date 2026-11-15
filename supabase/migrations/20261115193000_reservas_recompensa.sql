-- Recompensas por pagar a tiempo (Victor, 2026-11-15): lo que se dio al
-- aprobar la cuota (puntos, clase gratis, saldo a favor y su movimiento),
-- para deshacer exactamente eso si la reserva se cancela. Aditiva.
alter table public.reservas add column if not exists recompensa jsonb;
