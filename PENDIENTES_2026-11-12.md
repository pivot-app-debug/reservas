# Pendientes al día (reescrito el 2026-11-17, 19:00)

La lista anterior (rondas del 8 al 17 de noviembre, con muchos puntos ya hechos sin marcar) quedó en `PENDIENTES_HISTORIAL.md`. Aquí solo lo que falta, revisado contra el CHANGELOG y la HOJA_DE_RUTA.

## AC. Para el jueves 2026-11-19, 6 p. m. (tarea programada, pedido de Victor 2026-11-17 18:40)
Trabajar lo de esta sección y lo que Victor mande desde el 17/11 a las 18:45 (se anota aquí, al final de esta sección, y en la Bandeja de Claude Docs, sección Nuevo).

**Ideas y faltantes chicos (de las rondas del 17/11):**
- [ ] Cambiar la talla en una reserva ya hecha con las listas de equipamiento de cada liga (hoy solo patines).
- [ ] Requisito de equipo "tener aprobado tal curso".
- [ ] Plan del evento para un nivel de Coach (hoy por equipo o toda la liga).
- [ ] Comunicados inmediatos (push enviado al momento) guardados para que aparezcan en la campana (hoy solo los programados).
- [ ] Sección Recompensas y motivación en Mi Liga (quedó pendiente de la revisión del 15/11) y el asistente "+ Nueva regla".

**Del documento original "Cambios" (confirmar con Victor si siguen):**
- [ ] Rectificaciones: elegir a qué Pivots se envían (como en las excepciones).
- [ ] Qué llevar: aviso 1 h antes por defecto, cada Pivot puede cambiarlo a 2 o 3 h.
- [ ] Pago por clase aprobado: la persona queda "Asistiré" en ese evento; si no puede ir, "Cancelar o reagendar". Verificar en la app.
- [ ] Precios de clases y cupones en un solo lugar.
- [ ] Datos sensibles: si la liga los activa, al menos una persona debe poder verlos; cada persona elige qué Pivots ven sus datos de emergencia y domicilio.
- [ ] Inventario: fotos y etiqueta por artículo (las fotos por lista ya están).
- [ ] Zona horaria: se guarda en Ajustes de la liga, pero horarios, push y cron siguen con la hora de Ecuador. Aplicarla por liga.
- [ ] Desactivar cobros, planes y cupones por liga.
- [ ] Tipos de equipo (cobro por mes o por clase, equipamiento propio obligatorio, quién marca Asistiré, cancelar/reagendar): revisar qué falta tras las reglas por equipo.

**Anotado después de las 18:45 del 17/11:**
- [x] 18:54 Cursos en la barra para quien puede tomarlos, aviso y punto rojo (hecho el mismo día).
- [ ] 18:59 **Lo que ve la persona de su progreso** (aprobado 19:02: la Ficha deportiva es el histórico de cursos aprobados y habilidades logradas; Cursos es el progreso del curso en curso; al terminar un curso, su resultado pasa a la ficha): en cada curso en el que está inscrita, "Mi progreso" con clases a las que fue (X de Y), temas vistos y por ver, y al evaluarse su nota por tema frente al mínimo, si aprobó, y el comentario del coach si lo dejó visible para la persona. La Ficha deportiva (Ajustes) sigue siendo el historial completo de habilidades, con lo que se evaluó en cursos, entrenamientos y partidos, y desde el curso hay un enlace "Ver mi ficha deportiva". Coach sigue igual (lo que evalúa y lo que ve el coach). Solo se muestra lo que el coach marcó como visible para Usuarios.
- [x] 19:12 (hecho 19:14, Victor pidió hacerlo ya) **Cada pestaña recuerda dónde estabas:** al cambiar de pestaña y volver, sigues en la pantalla que tenías abierta (ej. creando un curso, vas a Equipo y vuelves a Calendario: sigues en el curso). Solo vuelve al inicio de la pestaña si tocas de nuevo el ícono de la pestaña en la que ya estás, o si vas atrás con el gesto o la flecha. Hoy `_irAPestana` en `inicio_shell.dart` vacía la pila de la pestaña al salir: quitar eso y dejar el vaciado solo al tocar la pestaña actual.
- [x] 18/11 11:24 Notificaciones casi obligatorias en web y Android (hecho el mismo día).
- [ ] 18/11 11:29 **Personas inactivas sin notificaciones:** que la app no les envíe notificaciones a quienes están inactivxs. Confirmar con Victor: si incluye archivadxs, lesionadxs o de viaje; si se cortan todas o solo las de eventos y asistencia (¿pagos pendientes sí?); y que a ellxs tampoco les salga la pantalla de "Activa las notificaciones".
- [ ] 18/11 16:29 **QA por sección de Victor:** todas sus notas, textuales, en `QA_2026-11-18.md` (Calendario, tareas, cursos, plan del evento, nuevo evento, Equipo, Inventario, Finanzas, Coach, Mi Liga, cerrar sesión en web, tours, login). Varias son preguntas o rediseños grandes (Coach y Finanzas a Ajustes, planes por tipo de evento, caja de eventos, pruebas en cursos, rediseño de Coach): proponer y preguntar antes de construir. Victor todavía no testeó crear cuenta / crear liga.
- [ ] 18/11 16:29 **Trabajar el QA en un Google Doc compartido:** Victor quiere un Google Doc que Claude pueda leer y editar y donde él pueda anotar el QA sección por sección (formato de `QA_2026-11-18.md`). Crearlo el jueves con el conector de Google Drive, pasarle el contenido y el link, y desde ahí leer las notas nuevas en cada tarea.

## Grandes etapas que faltan (HOJA_DE_RUTA)
- [ ] **Partidos y torneos (roller derby):** posiciones, line-ups y reportes por partido; importar el statsbook oficial (.xlsx de WFTDA) y carga a mano (por jam: puntos, jammer, line-up; penalidades por persona). Después torneos, merch y cronogramas.
- [ ] **Crear tu liga, lo que falta:** canal de comunicación, reglas de equipo, listas de equipamiento y roles del deporte en el paso a paso; directorio "Ligas en Pivot" y panel del dueño de Pivot.
- [ ] **Versión de escritorio:** listas y detalle lado a lado, menú lateral, atajos de teclado.
- [ ] **Mi Liga web:** "Estado actual del equipo" y "Usuarios" no se pasan a la app (decidido).

## Antes de la beta cerrada y de Play Store (orden de Victor)
- [ ] **Seguridad:** revisar que ninguna función de Pivot sea accesible o editable por quien no es Pivot; buscar fugas de datos personales o de la liga; avisos de seguridad y rendimiento de Supabase (advisors); RLS en todas las tablas.
- [ ] **Escalabilidad:** consultas que pueden pasar de 1000 filas, índices por usuario, evento, fecha y `liga_id`, prueba de carga ("Asistiré" a la vez), monitoreo de errores y del plan de Supabase. (Las tres consultas más pesadas ya se arreglaron el 12/11.)
- [ ] **Legal:** política y aviso de Tesorería revisados por abogado (borrador en `AVISO_LEGAL_TESORERIA_BORRADOR.md`, sin publicar).
- [ ] **Pruebas automáticas de totales** en Tesorería.
- [ ] **Migración de cuentas** a pivot.app.suppor@gmail.com (guía en `MIGRACION_CUENTAS.md`, empieza por GitHub; los pasos los hace Victor).
- [ ] **Probar en teléfonos reales:** velocidad, desenfoque, iPhone con la web agregada a la pantalla de inicio (notificaciones).
- [ ] **Dos versiones** (prueba y producción) y luego **Play Store**.
