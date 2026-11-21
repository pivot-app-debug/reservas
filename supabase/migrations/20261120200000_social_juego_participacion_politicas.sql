-- Las tablas nuevas de la fiesta no tenían la política por liga: con RLS y sin
-- política, la API no podía leer ni guardar (Victor, 2026-11-20: "¿Participas?"
-- se preguntaba cada vez). liga_id pasa a uuid como en el resto.
alter table social_participacion alter column liga_id type uuid using coalesce(liga_id, '00000000-0000-4000-8000-00000000c0de')::uuid;
alter table social_participacion alter column liga_id set default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de'::uuid);
alter table social_participacion alter column liga_id set not null;
alter table social_regalo_juego alter column liga_id type uuid using coalesce(liga_id, '00000000-0000-4000-8000-00000000c0de')::uuid;
alter table social_regalo_juego alter column liga_id set default coalesce(liga_actual(), '00000000-0000-4000-8000-00000000c0de'::uuid);
alter table social_regalo_juego alter column liga_id set not null;
create policy liga_aislada on social_participacion for all to liga_api using (liga_id = liga_actual()) with check (liga_id = liga_actual());
create policy liga_aislada on social_regalo_juego for all to liga_api using (liga_id = liga_actual()) with check (liga_id = liga_actual());
