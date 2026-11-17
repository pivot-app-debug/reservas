-- Varias ligas: los eventos generados desde cada pista quedan en la liga de
-- esa pista, y una temporada de descanso solo frena los eventos de su liga.
do $$
declare d text;
begin
  d := pg_get_functiondef('public.regenerar_ventana_asistencias'::regproc);
  d := replace(d, 'WHERE v_fecha BETWEEN td.fecha_inicio AND td.fecha_fin', 'WHERE v_fecha BETWEEN td.fecha_inicio AND td.fecha_fin AND td.liga_id = v_venue.liga_id');
  d := replace(d, 'id_regla, info_adicional', 'id_regla, info_adicional, liga_id');
  d := replace(d, 'COALESCE(v_venue.info_adicional, '''')', 'COALESCE(v_venue.info_adicional, ''''), v_venue.liga_id');
  if d !~ 'td.liga_id = v_venue.liga_id' or d !~ 'v_venue.liga_id\s*\)' then
    raise exception 'No se pudo adaptar regenerar_ventana_asistencias';
  end if;
  execute d;
end $$;
