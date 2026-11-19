-- Corrección retroactiva de la regla de cuotas (Victor, 2026-11-19)
-- NO EJECUTADO. Revisar con Victor antes de aplicar.
--
-- Regla vieja (bug): en Tesorería → Cuotas del mes aparecía como "debe" toda
-- persona con paga_cuota = 'Sí' y estado_miembro = 'Activx' sin reserva
-- mensual, pago, excepción ni exención del mes.
-- Regla nueva (desde noviembre 2026): mes futuro → nadie debe; solo equipos
-- que pagan por mes (_cobroEquipo modo 'mes'); debe solo quien vino a más
-- Entrenamientos del mes que sus clases de gracia.
--
-- Revisión hecha el 2026-11-19 (solo SELECT, liga Quindes Volcánicos, la única):
--   * La regla vieja solo vivía en la respuesta de `adminTesoreria/cuotasMes`
--     (se calcula al consultar, no se guarda).
--   * saldos_movimientos: 0 filas (ningún cargo ni recargo guardado).
--   * reservas con motivo 'Vino sin reserva': 0 filas.
--   * Recargos: cuotaRecargo = 0 en reglas_liga; no hay recargos cobrados.
--   * Avisos de deuda (push 'cuota_pendiente' / "Ya usaste tu clase de
--     gracia"): no se guardan en ninguna tabla (push_enviados solo tiene
--     'recordatorio_1dia'). No hay nada que borrar.
--   * cuota_excepcion / pagos / tesoreria_movimientos: solo pagos y
--     exenciones reales, ninguno creado por la regla vieja.
--
-- Resultado: NO hay filas que corregir. Este archivo deja las consultas para
-- volver a verificarlo justo antes de desplegar; si alguna devuelve filas,
-- avisar antes de tocar nada.

-- 1) Cargos automáticos de cuota en saldos (debería dar 0 filas).
select id, username, fecha, monto, concepto, tipo, por
from public.saldos_movimientos
where anulado = false and por = 'automático' and concepto ilike '%cuota%';

-- 2) Deudas creadas por "vino sin reserva" en equipos que pagan por mes
--    (no deberían existir: _deudaVinoSinReserva ya excluye modo 'mes').
select r.id, r.nombre_usuario, r.fecha_pago, r.monto, e.categoria
from public.reservas r join public.equipo e on e.username = r.nombre_usuario
where r.motivo_rechazo = 'Vino sin reserva';

-- 3) Quiénes "debían" en noviembre con la regla vieja y no con la nueva
--    (solo informativo: es lo que la pantalla mostraba mal).
with p as (
  select username, categoria from public.equipo
  where eliminado_en is null and estado_miembro = 'Activx'
    and paga_cuota ~* '^s[ií]$' and coalesce(exenta_cuota, false) = false
), ev as (
  select a_horario, tarde from public.asistencias
  where tipo_evento = 'Entrenamiento'
    and estado not in ('Evento Cancelado', 'No se entrena', 'Eliminado')
    and fecha between '2026-11-01' and least(current_date, '2026-11-30')
)
select p.username, p.categoria,
       (select count(*) from ev where upper(p.username) = any (
          string_to_array(upper(replace(coalesce(ev.a_horario, '') || ',' || coalesce(ev.tarde, ''), ' ', '')), ','))) as entrenamientos
from p
where not exists (select 1 from public.reservas r where r.nombre_usuario = p.username and r.tipo = 'mensual'
                  and r.estado in ('Confirmada', 'Pendiente') and r.validez_hasta between '2026-11-01' and '2026-11-30')
order by 2, 1;
-- Al 2026-11-19: Marce, Nadinka y Nico (Mirlxs, pagan según equipamiento, 0
-- entrenamientos) salían como "deben" y ya no; Laru (Quindes, 4
-- entrenamientos, 1 de gracia) sigue debiendo $20.

-- 4) Corrección: ninguna sentencia de cambio, porque no hay registros que
--    la regla vieja haya guardado.
