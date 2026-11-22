-- Pantalla que abre el aviso de suscripción sin terminar (Victor, 2026-11-22).
alter table reservas_en_curso add column if not exists pantalla text;
