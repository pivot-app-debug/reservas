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
- [~] 18/11 16:29 (19/11: hecha la ronda chica de Calendario, Notificaciones, Tareas, Cursos, Plan del evento, Asistencia anticipada, Equipo → Buscar, Inventario, Finanzas, cerrar sesión en web y login; queda lo de abajo) **QA por sección de Victor:** todas sus notas, textuales, en `QA_2026-11-18.md` (Calendario, tareas, cursos, plan del evento, nuevo evento, Equipo, Inventario, Finanzas, Coach, Mi Liga, cerrar sesión en web, tours, login). Varias son preguntas o rediseños grandes (Coach y Finanzas a Ajustes, planes por tipo de evento, caja de eventos, pruebas en cursos, rediseño de Coach): proponer y preguntar antes de construir. Victor todavía no testeó crear cuenta / crear liga.
- [x] 19/11 hecho: [Pivot — QA por sección](https://docs.google.com/document/d/12Exhxe8_ZH3MvM60IQtEI2kONrWcaVppOMSR8DiQnWo/edit) (id `12Exhxe8_ZH3MvM60IQtEI2kONrWcaVppOMSR8DiQnWo`, pestañas "App" y "Bugs y Nuevas funciones"). Claude lo lee con Google Drive y lo edita con el conector de Google Docs (activo desde el 19/11). Reglas de Victor: lo resuelto se borra del doc, lo que queda abierto lleva una línea "Claude (fecha):", y si cambia un título o sección de la app se actualiza también en el doc. **Trabajar el QA en un Google Doc compartido:** Victor quiere un Google Doc que Claude pueda leer y editar y donde él pueda anotar el QA sección por sección (formato de `QA_2026-11-18.md`). Crearlo el jueves con el conector de Google Drive, pasarle el contenido y el link, y desde ahí leer las notas nuevas en cada tarea.

**Decidido por Victor el 19/11 (pestaña "Preguntas de claude" del Google Doc; las dudas nuevas van ahí y lo resuelto se borra de ahí):**
- [ ] Grupo "Herramientas de la liga" en Ajustes con Mi Liga, Finanzas y Coach (se activan ahí); barra: Calendario, Equipo, Ajustes.
- [ ] Rediseño de Coach como se propuso; "Marcar habilidades", el buscador **y la lista de habilidades** pasan a Equipo.
- [ ] Tipos de evento: Entrenamiento, Partido, Reunión de equipo y Otro ("Evento" pasa a "Otro"; Otro sin plan).
- [ ] Caja de ventas: un "libro de ventas" del evento donde se eligen encargadxs (alguien del equipo o externx) y se cargan productos con precio; ventas y cierre de caja aprobado. Falta definir cómo entran lxs externxs y quién aprueba el cierre.
- [ ] Cuotas del mes: cambiar la regla (debe solo quien vino más veces que sus clases de gracia, en equipos que cobran por mes; monto y motivo). Falta: desde qué mes rige.
- [ ] Offseason: cobro proporcional a los entrenamientos que sí hay en el mes (entera / proporcional / no se cobra al crear el descanso).
- [ ] "Pedir comprobante (24 h)" en vez de rechazar; si no lo adjunta se descarta.
- [ ] Naviquinde: cada persona que marcó Asistiré (o su +1) gira su ruleta; pistas opcionales sobre la persona en la ficha del evento, si no hay pistas, wishlist. Faltan: fecha de cierre, tipo de pistas, qué ven los +1, orden y fecha del evento.
- [x] Web vieja (`js/`): obsoleta, no se adapta (la app Flutter la reemplaza).

**Esperan respuesta de Victor (propuestas del 19/11, no construir antes; las que siguen abiertas están en la pestaña "Preguntas de claude"):**
- [ ] **Coach y Finanzas a Ajustes.** Propuesta A (recomendada): en Ajustes, un grupo "Herramientas de la liga" con Mi Liga, Finanzas y Coach; cada una se activa o desactiva ahí y sale de la barra. Barra: Calendario, Equipo, Ajustes. B: solo Coach a Ajustes y Finanzas sigue en la barra para quienes la usan.
- [ ] **Rediseño de Coach.** Portada con atajos (Habilidades, Ajustes de coach, Cursos en curso y Pre-armados). La card "¿Las evaluamos?" pasa a Notificaciones del Calendario (3 días) y todo evento de Entrenamiento tiene "Evaluar". Se quita Cronograma. "Marcar habilidades" + buscador pasan a Equipo (filtros por nivel, asistencia y equipo, selección múltiple, notas de voz, quién ve el feedback en la ficha deportiva). Pregunta: ¿la lista de habilidades (crear/editar básicas y avanzadas) queda en Coach o también va a Equipo?
- [ ] **Planes según tipo de evento.** Tipos: Entrenamiento (bloques), Partido (lineups, estrategia, tareas vinculadas, caja), Reunión de equipo (temas colaborativos, links) y Otro (sin plan). Preguntas: ¿"Evento" pasa a llamarse "Otro"? ¿Crear eventos para un equipo, varios o toda la liga desde el + (revisar qué falta)?
- [ ] **Plan del entrenamiento (preguntas de Victor).** Propuesta: los bloques no pueden pasar la duración del entrenamiento (se avisa); botón "Comenzar" para quien lo da, con temporizador por bloque y pausas de agua opcionales entre bloques; si empieza tarde, "Ajustar al tiempo que queda" acorta proporcional o permite quitar bloques; "Usar un plan anterior" con buscador; aviso al equipo con los bloques (opcional por plan); varias personas pueden dar la clase; el plan puede asignarse a cualquier persona (coach, Pivot o jugadorx).
- [ ] **Caja de ventas en eventos.** En el plan de un Partido o evento: "Caja" para anotar ventas (producto, precio, cantidad, a qué cuenta: efectivo, Deuna, banco). "Cerrar caja" → un Pivot aprueba → pasan a Finanzas como ingresos del evento, con el historial. Preguntas: ¿quién anota ventas (quien tiene la tarea de la mesa, o cualquiera del evento)? ¿productos con precio fijo cargados antes?
- [ ] **Pruebas en cursos.** Cada prueba: nombre, medida (tiempo, repeticiones, vueltas o distancia), si gana más o menos, mínimo opcional; se agregan por clase en el asistente o en una columna "Pruebas" del Excel; los resultados van a la ficha deportiva. ¿Te sirve así?
- [ ] **Recompensa al aprobar un curso** (opción "Recibe una recompensa": puntos, descuento en la cuota, clases gratis o una de las recompensas de la liga). Toca dinero y puntos: confirmar antes de construir.
- [ ] **Planes de pago con descuento.** Plan "N meses por $X" (ej. 3 meses por 50 en vez de 60); al suscribirse por mes, la app sugiere el plan con el ahorro. Un plan se puede crear desde el curso y queda guardado. Confirmar.
- [ ] **Conciliar cuentas.** Propuesta: cada cuenta tiene una persona responsable; al conciliar, la diferencia se asigna a "Deuda de la persona responsable" (como "Usé plata del equipo"), "Gasto de la cuenta" (comisión o mantenimiento) o "Ajuste sin responsable". Importar el estado de cuenta (CSV del banco) queda para después. Confirmar.
- [ ] **Cuotas del mes, regla de quién debe** (toca dinero). Hoy debe toda persona Activx con `paga_cuota`='Sí' sin pago, reserva mensual, excepción ni exención, sin mirar asistencia ni clases de gracia. Propuesta: mes futuro → nadie debe; solo equipos que cobran por mes; debe si vino más veces que sus clases de gracia (A tiempo o Tarde, sin cancelados); el backend devuelve monto (con recargo si pasó el vencimiento) y motivo. Rige desde que se aprueba; pagos anteriores no cambian.
- [ ] **Rechazo por falta de comprobante.** Propuesta: en vez de rechazar, "Pedir comprobante (24 h)": queda "Esperando comprobante"; si en 24 h no lo adjunta, se descarta y tiene que volver a suscribirse. Confirmar el plazo y el texto.
- [ ] **Login y pedir acceso sin enlace.** Google con cuenta no registrada → "¿Tienes un enlace de invitación?" / "Crear mi liga" / "Pedir acceso a una liga" (elegir deporte y liga, solo se ve el nombre; los Pivots aprueban y llega una notificación para terminar la cuenta). Solo con cuenta de Google verificada. Toca permisos: confirmar.
- [ ] **Offseason con cobro proporcional** (toca dinero). Al crear la temporada de descanso: "Cuota durante el descanso: entera / proporcional / no se cobra". Pregunta: ¿proporcional a las clases que sí hay ese mes o a los días? (Ej. del 15/12 al 15/1: ~50 % de cada mes.) Si es proporcional y alguien usa su clase de gracia, se cobra según la regla elegida, no los 20 enteros. Rige solo para descansos nuevos.
- [ ] **Lenguaje de suscripción.** Propuesta de textos para quien usa la app: "Reservar clase" → "Suscribirme a esta clase"; "Pago del mes" → "Suscripción a enero"; varios meses → "Mensualidades"; "Mis pagos" → "Mis suscripciones". Preguntas: ¿también en lo que ven los Pivots (Notificaciones → "Pagos y reservas" pasa a "Suscripciones")? ¿Finanzas sigue hablando de pagos e ingresos?
- [ ] **Naviquinde / evento social** (nuevo, pestaña "Bugs y Nuevas funciones" del Doc). Propuesta: tipo de evento "Social" con módulos que se activan: Amigo secreto (sorteo en ciclo con exclusiones, "Ver mi amigo secreto" oculto por defecto), Regalo robado (tope de presupuesto), Comida compartida (categorías con meta por asistente y barras) e invitadxs +1 con enlace sin cuenta. La wishlist es por evento (cada año nueva, con opción de copiar la del año anterior), con talla, "lo que no quiero", favoritos y links; preguntas anónimas al amigo secreto. Diferencias con el plan de Gemini: la app es Flutter (no html/css/js), el catálogo de 1500 regalos sería una segunda etapa (primero wishlist libre), sin integración con Temu (no tiene API: se pega un link). Preguntas: ¿los +1 sin cuenta pueden ver la lista de asistentes? ¿quién organiza el sorteo (Pivots o quien crea el evento)?

**Pendiente de construir (sin preguntas, queda para la próxima tarea):**
- [ ] Tareas: cupos + personas fijas en recurrentes (columna nueva en `tareas_recurrentes`) y reasignar al archivar o borrar a alguien.
- [ ] Mi Liga: el buscador lleva directo al ajuste ("Puntos por asistencia - Quindes"), sin resaltar.
- [ ] Tours guiados según funciones activadas (Coach, Finanzas, reglas).
- [ ] Cursos: rediseño de Pre-armados, guardar el progreso del asistente con "Reanudar" en Notificaciones, precargar lugar y hora del calendario al elegir fecha, lista de personas por nivel.
- [ ] Finanzas: exportar .xlsx real (hoy CSV), plantilla de Excel para importar cuentas viejas, ventanas vs. bottom sheets.

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
