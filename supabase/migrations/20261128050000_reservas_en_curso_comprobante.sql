-- Comprobante obligatorio (Victor, 2026-11-27): con qué pagó, cuándo salió a pagar y el aviso de antes del entrenamiento.
alter table public.reservas_en_curso add column if not exists medio_nombre text, add column if not exists pago_en timestamptz, add column if not exists aviso_previo_en timestamptz;
