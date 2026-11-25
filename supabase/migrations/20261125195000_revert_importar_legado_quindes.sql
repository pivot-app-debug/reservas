-- Revertir importación de legado Quindes (borrado físico, como si nunca se hubiera hecho)
-- Borra los saldos a favor importados (Sant, Vic)
DELETE FROM public.saldos_movimientos WHERE por = 'importacion_legado';
-- Borra los ingresos/egresos de tesorería importados
DELETE FROM public.tesoreria_movimientos WHERE registrado_por = 'importacion_legado';
