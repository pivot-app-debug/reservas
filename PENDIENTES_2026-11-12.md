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
- (nada todavía)

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
