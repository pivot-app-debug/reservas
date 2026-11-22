-- Devolución de saldo a favor (Victor, 2026-11-21).
alter table saldos_movimientos drop constraint saldos_movimientos_tipo_check;
alter table saldos_movimientos add constraint saldos_movimientos_tipo_check check (tipo = any (array['cargo','abono','prestamo','a_favor','aplicado','devolucion']));
