-- Blindaje de Finanzas (auditoría 2026-11-26, Victor aprobó). Solo agrega columnas e índices.
-- pagos: se puede anular (antes solo se anulaba el movimiento y la fila seguía contando
-- como pagada) y guarda qué reserva o saldo creó, para deshacerlo junto.
alter table public.pagos add column if not exists anulado boolean not null default false;
alter table public.pagos add column if not exists anulado_por text;
alter table public.pagos add column if not exists anulado_en timestamptz;
alter table public.pagos add column if not exists motivo_anulacion text;
alter table public.pagos add column if not exists reserva_id uuid;
alter table public.pagos add column if not exists saldo_movimiento_id uuid;

-- tesoreria_movimientos: mes que paga una cuota (antes solo vivía en el texto).
alter table public.tesoreria_movimientos add column if not exists periodo_mes smallint;
alter table public.tesoreria_movimientos add column if not exists periodo_anio smallint;
create index if not exists tesoreria_mov_cuota_periodo_idx
  on public.tesoreria_movimientos (persona, periodo_anio, periodo_mes)
  where not anulado and categoria = 'cuota';

-- Relleno: periodo de las cuotas que ya existen ("Mensualidad abril", "Cuota 4/2026").
update public.tesoreria_movimientos m set periodo_mes = x.mes, periodo_anio = x.anio
from (
  select id,
    coalesce(
      (regexp_match(lower(descripcion), 'cuota\s+(\d{1,2})/\d{4}'))[1]::int,
      array_position(array['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'],
        (regexp_match(lower(descripcion), 'mensualidad\s+([a-z]+)'))[1])
    ) as mes,
    coalesce((regexp_match(lower(descripcion), 'cuota\s+\d{1,2}/(\d{4})'))[1]::int, extract(year from fecha)::int) as anio
  from public.tesoreria_movimientos
  where categoria = 'cuota' and periodo_mes is null
) x
where m.id = x.id and x.mes is not null;
