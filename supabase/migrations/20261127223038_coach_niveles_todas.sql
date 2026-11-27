-- Logros por grupo (Victor, 2026-11-27): todo nivel se completa al lograr
-- todas sus habilidades; se deja de usar la regla de porcentaje o «una».
update public.coach_niveles set regla = 'todas', porcentaje = 100 where regla is distinct from 'todas' or porcentaje is distinct from 100;
