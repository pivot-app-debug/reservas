-- "Quién lo ve" acepta varios valores separados por coma (jugadorx, pivots,
-- coaches) o 'yo' (Victor, 2026-11-20: las evaluaciones fallaban al guardar).
alter table coach_notas drop constraint if exists coach_notas_visible_check;
alter table coach_notas add constraint coach_notas_visible_check check (visible ~ '^(yo|((jugadorx|pivots|coaches),?)+)$');
alter table coach_pruebas drop constraint if exists coach_pruebas_visible_check;
alter table coach_pruebas add constraint coach_pruebas_visible_check check (visible ~ '^(yo|((jugadorx|pivots|coaches),?)+)$');
alter table coach_feedback drop constraint if exists coach_feedback_visible_check;
alter table coach_feedback add constraint coach_feedback_visible_check check (visible ~ '^(yo|((jugadorx|pivots|coaches),?)+)$');
