-- Cupón manual de descuento para una persona (Victor, 2026-11-16): % para su próximo pago, se usa una vez.
alter table public.equipo add column if not exists cupon_descuento int check (cupon_descuento between 1 and 100);
alter table public.reservas add column if not exists descuento_pct int;
alter table public.reservas add column if not exists descuento_monto numeric;
