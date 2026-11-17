-- El coach decide si a sus jugadorxs les llega el aviso semanal de
-- novedades en su ficha deportiva (Victor, 2026-11-17).
alter table public.coaches add column if not exists avisar_novedades boolean not null default true;
