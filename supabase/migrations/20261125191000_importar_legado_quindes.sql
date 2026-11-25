-- Importar legado Quindes (hojas Ingresos, Egresos, Resumen del spreadsheet Quindes)
-- Victor aprobó: egresos son plata de bolsillo de Sant y Vic que el equipo les debe
-- (van a saldos_movimientos como a favor, no a tesoreria_cuentas).
-- Ingresos y Pagos.csv van a tesoreria_movimientos con su cuenta según medio de pago.

-- Cuentas existentes (verificadas en tesoreria_cuentas):
--   Banco Internacional: 9b43fb4f-d34d-45cd-9e29-896df0e9d2de (banco)
--   Efectivo:            a78785c1-33e8-4f5d-9e44-e78fc60b2e29 (efectivo)
--   DeUna:               d6ad8f8f-23b1-49fb-9086-8e184da2791b (deuna)

-- ─── INGRESOS (Ingresos.csv) ───
-- Total: $2.358,24 (cuadra con el resumen)
-- Medio Mixto -> Banco Internacional (según indicación de Victor)
-- Medio Transferencia (Dani) -> DeUna (según indicación de Victor)
-- Medio Transferencia (Robin/Gringa la Vikinga) -> Banco Internacional

INSERT INTO public.tesoreria_movimientos (
  fecha, tipo, monto, cuenta_id, categoria, descripcion, persona, persona_nombre,
  origen, registrado_por, creado_en
) VALUES
  -- Año pasado: ingresos totales hasta 31/12/2025
  ('2026-01-01', 'ingreso', 1402.75, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Ingresos totales hasta el 31/12 de 2025', NULL, NULL, 'manual', 'importacion_legado', now()),
  -- Cuotas (Ale, Vic)
  ('2026-03-01', 'ingreso', 918.00, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Cuotas', NULL, NULL, 'manual', 'importacion_legado', now()),
  -- Pago primera cuota patines de 50$ (Dani) -> DeUna
  ('2026-02-28', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Pago primera cuota patines de 50$', 'Dani', 'Dani', 'manual', 'importacion_legado', now()),
  -- Pago patreon febrero (Robin / Gringa la Vikinga) -> Banco Internacional
  ('2026-02-28', 'ingreso', 17.49, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'donacion', 'Pago patreon febrero', 'Gringa la Vikinga', 'Robin', 'manual', 'importacion_legado', now());

-- ─── PAGOS (Pagos.csv) ───
-- Cada fila es un pago individual de cuota, adjudicado a la persona.
-- Mapeo de medio de pago:
--   "Transferencia Banco Pichincha" / "De una!" / "DeUna" -> cuenta DeUna (d6ad8f8f-...)
--   "Transferencia Banco Internacional" -> cuenta Banco Internacional (9b43fb4f-...)
--   "Efectivo" -> cuenta Efectivo (a78785c1-...)
--   "No Aplica" o medio vacío -> se ignora (no se registra)
-- Personas no encontradas en Equipo.csv: se dejan sin persona (persona = NULL)

INSERT INTO public.tesoreria_movimientos (
  fecha, tipo, monto, cuenta_id, categoria, descripcion, persona, persona_nombre,
  origen, registrado_por, creado_en
) VALUES
  -- Febrero 2026
  ('2026-02-21', 'ingreso', 15.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Laru', 'Laru', 'manual', 'importacion_legado', now()),
  ('2026-01-25', 'ingreso', 15.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Lucile', 'Lucile', 'manual', 'importacion_legado', now()),
  ('2026-01-30', 'ingreso', 15.00, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Gringa la Vikinga', 'Robin', 'manual', 'importacion_legado', now()),
  ('2026-01-30', 'ingreso', 15.00, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Transferencia Robin', NULL, NULL, 'manual', 'importacion_legado', now()),
  ('2026-04-02', 'ingreso', 15.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Sebas', 'Sebas', 'manual', 'importacion_legado', now()),
  ('2026-02-21', 'ingreso', 15.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Laru', 'Laru', 'manual', 'importacion_legado', now()),
  ('2026-02-26', 'ingreso', 15.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Pago de Robin y Alejandro', 'Gringa la Vikinga', 'Robin', 'manual', 'importacion_legado', now()),
  ('2026-02-26', 'ingreso', 15.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Pago incluye deuda de patines', 'Dani', 'Dani', 'manual', 'importacion_legado', now()),
  ('2026-02-26', 'ingreso', 15.00, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Nicolás Alejandro', 'Alejandro', 'manual', 'importacion_legado', now()),
  ('2026-03-03', 'ingreso', 8.00, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Paga mitad de cuota', 'Paulo', 'Paulo', 'manual', 'importacion_legado', now()),
  ('2026-03-30', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Pagos 02 y 03. Adelanta 04, 05 y 06 del 2026', 'Marce', 'Marce', 'manual', 'importacion_legado', now()),
  ('2026-03-30', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Pagos 02 y 03. Adelanta 04, 05 y 06 del 2026', 'Marce', 'Marce', 'manual', 'importacion_legado', now()),
  ('2026-03-30', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Pagos 02 y 03. Adelanta 04, 05 y 06 del 2026', 'Marce', 'Marce', 'manual', 'importacion_legado', now()),
  ('2026-03-30', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Pagos 02 y 03. Adelanta 04, 05 y 06 del 2026', 'Marce', 'Marce', 'manual', 'importacion_legado', now()),
  ('2026-03-30', 'ingreso', 15.00, NULL, 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Lucile', 'Lucile', 'manual', 'importacion_legado', now()),
  ('2026-02-04', 'ingreso', 15.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Pago adelantado USD 45', 'Darah', 'Darah', 'manual', 'importacion_legado', now()),
  ('2026-02-04', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Pago adelantado USD 45', 'Darah', 'Darah', 'manual', 'importacion_legado', now()),
  ('2026-02-04', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Pago adelantado USD 45', 'Darah', 'Darah', 'manual', 'importacion_legado', now()),
  ('2026-02-04', 'ingreso', 20.00, NULL, 'cuota', NULL, 'Darah', 'Darah', 'manual', 'importacion_legado', now()),
  ('2026-02-06', 'ingreso', 15.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Ale', 'Ale', 'manual', 'importacion_legado', now()),
  ('2026-04-01', 'ingreso', 20.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Media cuota por operacion', 'Nadinka', 'Nadinka', 'manual', 'importacion_legado', now()),
  ('2026-03-13', 'ingreso', 20.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Ale', 'Ale', 'manual', 'importacion_legado', now()),
  ('2026-04-13', 'ingreso', 10.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Paga cuota reducida por acuerdo', 'Cami', 'Cami', 'manual', 'importacion_legado', now()),
  ('2026-04-13', 'ingreso', 20.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', NULL, 'Laru', 'Laru', 'manual', 'importacion_legado', now()),
  ('2026-03-02', 'ingreso', 20.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'a sant', 'Lucile', 'Lucile', 'manual', 'importacion_legado', now()),
  ('2026-03-02', 'ingreso', 20.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', NULL, 'Byron', 'Byron', 'manual', 'importacion_legado', now()),
  ('2026-02-23', 'ingreso', 20.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', '(pago de una pero fue media cuota', 'Flor', 'Flor', 'manual', 'importacion_legado', now()),
  ('2026-03-28', 'ingreso', 20.00, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', NULL, 'Gringa la Vikinga', 'Robyn', 'manual', 'importacion_legado', now()),
  ('2026-03-28', 'ingreso', 20.00, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', NULL, 'Nicolás Alejandro', 'Alejandro', 'manual', 'importacion_legado', now()),
  ('2026-03-03', 'ingreso', 10.00, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Paga media cuota', 'Paulo', 'Paulo', 'manual', 'importacion_legado', now()),
  ('2026-04-04', 'ingreso', 20.00, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', NULL, 'Nadinka', 'Nadinka', 'manual', 'importacion_legado', now()),
  ('2026-04-01', 'ingreso', 20.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', NULL, 'Nadinka', 'Nadinka', 'manual', 'importacion_legado', now()),
  ('2026-04-13', 'ingreso', 10.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Pago media cuota', 'Cami', 'Cami', 'manual', 'importacion_legado', now()),
  ('2026-04-13', 'ingreso', 20.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', NULL, 'Laru', 'Laru', 'manual', 'importacion_legado', now()),
  ('2026-04-15', 'ingreso', 20.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', NULL, 'Ale', 'Ale', 'manual', 'importacion_legado', now()),
  ('2026-04-06', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Anticipo USD 10 en enero y transfiere 30', 'Darah', 'Darah', 'manual', 'importacion_legado', now()),
  ('2026-05-04', 'ingreso', 20.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Cancelado a Sant', 'Ale', 'Ale', 'manual', 'importacion_legado', now()),
  ('2026-04-06', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', NULL, 'Darah', 'Darah', 'manual', 'importacion_legado', now()),
  ('2026-05-13', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', NULL, 'Cami', 'Cami', 'manual', 'importacion_legado', now()),
  ('2026-04-20', 'ingreso', 20.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'a Sant', 'Lucile', 'Lucile', 'manual', 'importacion_legado', now()),
  ('2026-06-04', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Anticipo USD 60 (Junio, Julio y Agosto 2026)', 'Darah', 'Darah', 'manual', 'importacion_legado', now()),
  ('2026-06-04', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', NULL, 'Darah', 'Darah', 'manual', 'importacion_legado', now()),
  ('2026-06-04', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', NULL, 'Darah', 'Darah', 'manual', 'importacion_legado', now()),
  ('2026-05-15', 'ingreso', 20.00, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'a Sant', 'Lucile', 'Lucile', 'manual', 'importacion_legado', now()),
  ('2026-07-08', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'a sant', 'Cami', 'Cami', 'manual', 'importacion_legado', now()),
  ('2026-06-15', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', NULL, 'Ale', 'Ale', 'manual', 'importacion_legado', now()),
  ('2026-07-07', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', 'Transferido a DeUna USD 80 incluyendo pago de Laru', 'Ale', 'Ale', 'manual', 'importacion_legado', now()),
  ('2026-07-07', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', NULL, 'Laru', 'Laru', 'manual', 'importacion_legado', now()),
  ('2026-07-07', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', NULL, 'Laru', 'Laru', 'manual', 'importacion_legado', now()),
  ('2026-07-07', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', NULL, 'Laru', 'Laru', 'manual', 'importacion_legado', now()),
  ('2026-06-15', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota', NULL, 'Ale', 'Ale', 'manual', 'importacion_legado', now());

-- ─── EGRESOS (Egresos.csv) ───
-- Total: $621,91 (plata de bolsillo de Sant y Vic que el equipo les debe)
-- Se registran en saldos_movimientos como "a favor" (monto positivo = el equipo les debe a la persona)
-- Cuando dice "Sant, Vic" se divide el monto entre los dos.
-- Fechas sin registro: se usa el día 1 del mes indicado.

INSERT INTO public.saldos_movimientos (
  username, persona_nombre, fecha, monto, concepto, tipo, aplicar, por, creado_en
) VALUES
  ('Sant', 'Sant', '2026-01-01', 311.25, 'Pagos a Coaches', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Sant', 'Sant', '2026-02-01', 2.35, 'Ubers fresh', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-02-01', 2.35, 'Ubers fresh', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Sant', 'Sant', '2026-02-01', 6.80, 'anuncios reclutamiento', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Sant', 'Sant', '2026-03-01', 1.25, 'Uber lunes 9 de marzo', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-03-01', 1.25, 'Uber lunes 9 de marzo', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Sant', 'Sant', '2026-03-01', 1.25, 'Uber miércoles 11', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-03-01', 1.25, 'Uber miércoles 11', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Sant', 'Sant', '2026-04-01', 20.00, 'Media cuota nadinka y flor marzo', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-06-01', 50.00, 'Mantenimiento de botiquín y compra de nuevos insumos', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Sant', 'Sant', '2026-06-01', 16.50, 'Pago anuncios mirlxs mayo', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-06-01', 20.00, 'Pago de Claude para optimización del equipo', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-06-01', 2.775, 'Uber mirlxs', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Sant', 'Sant', '2026-06-01', 2.775, 'Uber mirlxs', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-06-01', 2.63, 'Uber mirlxs', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Sant', 'Sant', '2026-06-01', 2.63, 'Uber mirlxs', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Sant', 'Sant', '2026-06-01', 20.00, 'Pago de fb anuncios junio', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Sant', 'Sant', '2026-06-01', 0.925, 'Uber 26/06/22', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-06-01', 0.925, 'Uber 26/06/22', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-06-01', 5.00, 'Credito claude emergencia', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-07-01', 20.00, 'Claude', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Sant', 'Sant', '2026-07-01', 20.00, 'Anuncios julio', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Sant', 'Sant', '2026-08-01', 30.00, 'Anuncios agosto', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-08-01', 20.00, 'Claude Agosto', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-08-01', 10.00, 'Claude tokens de emergencia', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-08-01', 5.00, 'Claude tokens de emergencia', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-08-01', 5.00, 'Claude tokens de emergencia', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-10-01', 20.00, 'Claude Octubre', 'a_favor', 'aparte', 'importacion_legado', now()),
  ('Vic', 'Vic', '2026-11-01', 20.00, 'Claude noviembre', 'a_favor', 'aparte', 'importacion_legado', now());
