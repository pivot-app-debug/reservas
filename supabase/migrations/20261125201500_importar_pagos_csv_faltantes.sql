-- ============================================================
-- Insertar pagos del CSV que faltaban en tesorería
-- Cuentas:
--   Banco Pichincha    = 0b9b1ca0-b1d4-4085-9497-14d886a32b8d  (Transferencia Banco Pichincha)
--   DeUna              = d6ad8f8f-23b1-49fb-9086-8e184da2791b  (De una!)
--   Banco Internacional= 9b43fb4f-d34d-45cd-9e29-896df0e9d2de  (Transferencia Banco Internacional)
--   Efectivo           = a78785c1-33e8-4f5d-9e44-e78fc60b2e29  (Efectivo)
-- ============================================================

-- EFECTIVO (medio: Efectivo)
INSERT INTO public.tesoreria_movimientos (
  fecha, tipo, monto, cuenta_id, categoria, descripcion, persona, persona_nombre,
  origen, registrado_por, creado_en
) VALUES
  ('2026-03-02', 'ingreso', 20, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Mensualidad marzo', 'Byron', 'Byron', 'csv_pagos', 'importacion_csv', now()),
  ('2026-02-23', 'ingreso', 20, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Mensualidad marzo', 'Flor', 'Flor', 'csv_pagos', 'importacion_csv', now()),
  ('2026-02-26', 'ingreso', 15, 'a78785c1-33e8-4f5d-9e44-e78fc60b2e29', 'cuota', 'Pago incluye deuda de patines', 'Dani', 'Dani', 'csv_pagos', 'importacion_csv', now());

-- BANCO PICHINCHA (medio: Transferencia Banco Pichincha)
INSERT INTO public.tesoreria_movimientos (
  fecha, tipo, monto, cuenta_id, categoria, descripcion, persona, persona_nombre,
  origen, registrado_por, creado_en
) VALUES
  ('2026-01-25', 'ingreso', 15, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Lucile', 'Lucile', 'csv_pagos', 'importacion_csv', now()),
  ('2026-02-06', 'ingreso', 15, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Ale', 'Ale', 'csv_pagos', 'importacion_csv', now()),
  ('2026-02-04', 'ingreso', 15, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad febrero', 'Darah', 'Distorsionadx', 'csv_pagos', 'importacion_csv', now()),
  ('2026-02-04', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad marzo', 'Darah', 'Distorsionadx', 'csv_pagos', 'importacion_csv', now()),
  ('2026-02-04', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad abril', 'Darah', 'Distorsionadx', 'csv_pagos', 'importacion_csv', now()),
  ('2026-02-28', 'ingreso', 15, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Sebas', 'Sebas', 'csv_pagos', 'importacion_csv', now()),
  ('2026-03-30', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad febrero', 'Marce', 'Marce', 'csv_pagos', 'importacion_csv', now()),
  ('2026-03-30', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad marzo', 'Marce', 'Marce', 'csv_pagos', 'importacion_csv', now()),
  ('2026-03-30', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad abril', 'Marce', 'Marce', 'csv_pagos', 'importacion_csv', now()),
  ('2026-03-30', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad mayo', 'Marce', 'Marce', 'csv_pagos', 'importacion_csv', now()),
  ('2026-03-30', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad junio', 'Marce', 'Marce', 'csv_pagos', 'importacion_csv', now()),
  ('2026-05-13', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad mayo', 'Cami', 'Cami', 'csv_pagos', 'importacion_csv', now()),
  ('2026-07-07', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad mayo', 'Laru', 'Laru', 'csv_pagos', 'importacion_csv', now()),
  ('2026-07-07', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad junio', 'Laru', 'Laru', 'csv_pagos', 'importacion_csv', now()),
  ('2026-07-07', 'ingreso', 20, '0b9b1ca0-b1d4-4085-9497-14d886a32b8d', 'cuota', 'Mensualidad julio', 'Laru', 'Laru', 'csv_pagos', 'importacion_csv', now());

-- DEUNA (medio: De una!)
-- Nota: Los pagos de Darah (04-06 y 06-04), Ale (06-15 x2), Cami (07-08) y Ale (07-07)
-- ya están activos en la base de datos, por lo que no se vuelven a insertar aquí.
-- No hay pagos nuevos de DeUna pendientes de insertar.

-- BANCO INTERNACIONAL (medio: Transferencia Banco Internacional)
INSERT INTO public.tesoreria_movimientos (
  fecha, tipo, monto, cuenta_id, categoria, descripcion, persona, persona_nombre,
  origen, registrado_por, creado_en
) VALUES
  ('2026-01-30', 'ingreso', 15, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Robin', 'Robin', 'csv_pagos', 'importacion_csv', now()),
  ('2026-01-30', 'ingreso', 15, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Alejandro', 'Alejandro', 'csv_pagos', 'importacion_csv', now()),
  ('2026-02-26', 'ingreso', 15, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Robyn', 'Robyn', 'csv_pagos', 'importacion_csv', now()),
  ('2026-02-26', 'ingreso', 15, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Cuota corresponde a $15 en ese entonces', 'Alejandro', 'Alejandro', 'csv_pagos', 'importacion_csv', now()),
  ('2026-03-03', 'ingreso', 8, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Paga mitad de cuota', 'Paulo', 'Paulo', 'csv_pagos', 'importacion_csv', now()),
  ('2026-03-03', 'ingreso', 10, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Paga media cuota', 'Paulo', 'Paulo', 'csv_pagos', 'importacion_csv', now()),
  ('2026-03-04', 'ingreso', 20, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Mensualidad marzo', 'Nadine', 'Nadine', 'csv_pagos', 'importacion_csv', now()),
  ('2026-03-28', 'ingreso', 20, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Mensualidad marzo', 'Robyn', 'Robyn', 'csv_pagos', 'importacion_csv', now()),
  ('2026-03-28', 'ingreso', 20, '9b43fb4f-d34d-45cd-9e29-896df0e9d2de', 'cuota', 'Mensualidad marzo', 'Alejandro', 'Alejandro', 'csv_pagos', 'importacion_csv', now());
