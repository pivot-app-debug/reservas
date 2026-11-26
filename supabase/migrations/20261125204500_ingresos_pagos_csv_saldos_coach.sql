-- ============================================================
-- Ingresos especiales + pagos faltantes CSV + saldos a favor Sant y Vic
-- Fecha: 2026-11-25
-- ============================================================

-- Cuentas:
--   Banco Internacional = 9b43fb4f-d34d-45cd-9e29-896df0e9d2de
--   DeUna               = d6ad8f8f-23b1-49fb-9086-8e184da2791b
--   Efectivo            = a78785c1-33e8-4f5d-9e44-e78fc60b2e29
--   Banco Pichincha     = 0b9b1ca0-b1d4-4085-9497-14d886a32b8d

-- ────────────────────────────────────────────────────────────
-- 1. INGRESOS ESPECIALES (CSV Ingresos, sin cuotas $918)
-- ────────────────────────────────────────────────────────────

-- Año pasado: Ingresos totales hasta 31/12/2025 -> Banco Internacional
INSERT INTO public.tesoreria_movimientos (
  fecha, tipo, monto, cuenta_id, categoria, descripcion, persona, persona_nombre,
  origen, registrado_por, created_at
) VALUES
  ('2026-01-01', 'ingreso', 1402.75, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota',
   'Ingresos totales hasta el 31/12 de 2025', NULL, NULL, 'csv_ingresos', 'importacion_csv_ingresos', now());

-- Pago primera cuota patines (Dani) -> DeUna
INSERT INTO public.tesoreria_movimientos (
  fecha, tipo, monto, cuenta_id, categoria, descripcion, persona, persona_nombre,
  origen, registrado_por, created_at
) VALUES
  ('2026-02-28', 'ingreso', 20.00, 'd6ad8f8f-23b1-49fb-9086-8e184da2791b', 'cuota',
   'Pago primera cuota patines de 50$', 'Dani', 'Dani', 'csv_ingresos', 'importacion_csv_ingresos', now());

-- Patreon febrero (Robin) -> Banco Internacional
INSERT INTO public.tesoreria_movimientos (
  fecha, tipo, monto, cuenta_id, categoria, descripcion, persona, persona_nombre,
  origen, registrado_por, created_at
) VALUES
  ('2026-02-28', 'ingreso', 17.49, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'donacion',
   'Pago patreon febrero', 'Gringa la Vikinga', 'Robin', 'csv_ingresos', 'importacion_csv_ingresos', now());


-- ────────────────────────────────────────────────────────────
-- 2. PAGOS FALTANTES DEL CSV (nunca insertados en la DB)
-- ────────────────────────────────────────────────────────────

-- EFECTIVO (medio: Efectivo)
INSERT INTO public.tesoreria_movimientos (
  fecha, tipo, monto, cuenta_id, categoria, descripcion, persona, persona_nombre,
  origen, registrado_por, created_at
) VALUES
  ('2026-03-02', 'ingreso', 20, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Mensualidad marzo', 'Byron', 'Byron', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-02-23', 'ingreso', 20, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Mensualidad marzo', 'Flor', 'Flor', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-02-26', 'ingreso', 15, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Pago incluye deuda de patines', 'Dani', 'Dani', 'csv_pagos', 'importacion_csv_pagos', now());

-- BANCO PICHINCHA (medio: Transferencia Banco Pichincha)
INSERT INTO public.tesoreria_movimientos (
  fecha, tipo, monto, cuenta_id, categoria, descripcion, persona, persona_nombre,
  origen, registrado_por, created_at
) VALUES
  ('2026-01-25', 'ingreso', 15, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Lucile', 'Lucile', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-04-02', 'ingreso', 15, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Sebas', 'Sebas', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-02-06', 'ingreso', 15, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Ale', 'Ale', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-02-04', 'ingreso', 15, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad febrero', 'Darah', 'Distorsionadx', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-02-04', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad marzo', 'Darah', 'Distorsionadx', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-02-04', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad abril', 'Darah', 'Distorsionadx', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-03-30', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad febrero', 'Marce', 'Marce', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-03-30', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad marzo', 'Marce', 'Marce', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-03-30', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad abril', 'Marce', 'Marce', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-03-30', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad mayo', 'Marce', 'Marce', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-03-30', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad junio', 'Marce', 'Marce', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-05-13', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad mayo', 'Cami', 'Cami', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-07-07', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad mayo', 'Laru', 'Laru', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-07-07', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad junio', 'Laru', 'Laru', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-07-07', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad julio', 'Laru', 'Laru', 'csv_pagos', 'importacion_csv_pagos', now());

-- BANCO INTERNACIONAL (medio: Transferencia Banco Internacional)
INSERT INTO public.tesoreria_movimientos (
  fecha, tipo, monto, cuenta_id, categoria, descripcion, persona, persona_nombre,
  origen, registrado_por, created_at
) VALUES
  ('2026-01-30', 'ingreso', 15, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Robin', 'Robin', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-01-30', 'ingreso', 15, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Alejandro', 'Alejandro', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-02-26', 'ingreso', 15, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Robyn', 'Robyn', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-02-26', 'ingreso', 15, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Alejandro', 'Alejandro', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-03-03', 'ingreso', 8, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Paga mitad de cuota', 'Paulo', 'Paulo', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-03-03', 'ingreso', 10, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Paga media cuota', 'Paulo', 'Paulo', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-03-04', 'ingreso', 20, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Mensualidad marzo', 'Nadine', 'Nadine', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-03-28', 'ingreso', 20, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Mensualidad marzo', 'Robyn', 'Robyn', 'csv_pagos', 'importacion_csv_pagos', now()),
  ('2026-03-28', 'ingreso', 20, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Mensualidad marzo', 'Alejandro', 'Alejandro', 'csv_pagos', 'importacion_csv_pagos', now());


-- ────────────────────────────────────────────────────────────
-- 3. SALDOS A FAVOR SANT Y VIC (egresos manuales + 25% coaches)
--    Total deuda equipo: $860,16
--    Sant: $435,73 (egresos) + $119,13 (coach) = $554,86
--    Vic:  $186,18 (egresos) + $119,12 (coach) = $305,30
-- ────────────────────────────────────────────────────────────

INSERT INTO public.saldos_movimientos (
  username, persona_nombre, fecha, monto, concepto, tipo, aplicar, por, created_at
) VALUES
  ('Sant', 'Sant', now(), 554.86,
   'Deuda equipo: egresos CSV ($435,73) + 25% coaches ($119,13)',
   'a_favor', 'aparte', 'importacion_csv_egresos_coach', now()),
  ('Vic', 'Vic', now(), 305.30,
   'Deuda equipo: egresos CSV ($186,18) + 25% coaches ($119,12)',
   'a_favor', 'aparte', 'importacion_csv_egresos_coach', now());
