# Pendientes al día (limpiado el 2026-11-22)

La lista del 17/11 quedó en `PENDIENTES_HISTORIAL_2026-11-17.md` (y la anterior en `PENDIENTES_HISTORIAL.md`). Aquí solo lo que falta. Lo nuevo de cada ronda está en el Google Doc "Pivot — QA por sección" (pestañas Cambios, Bugs y Propuestas de claude).

## Ya hecho (sale de la lista)
Cursos en la barra; cada pestaña recuerda dónde estabas; notificaciones casi obligatorias; QA en Google Doc; regla de cuotas por asistencia; "Pedir comprobante (24 h)"; offseason con cuota proporcional; avisos solo para personas activas; Coach y habilidades a Equipo (las habilidades ahora se gestionan en la ficha deportiva); Social o fiesta y Naviquinde; tipos de evento "Reunión de equipo" y "Otro"; lenguaje de suscripción para quien usa la app y en las notificaciones; web vieja descartada.

## Quedó desactualizado
- "Herramientas de la liga" en Ajustes y "Coach y Finanzas a Ajustes": lo reemplaza el plan de **Liga** (pestañas Comunidad, Equipos, Redes, Inventario, Finanzas y Coach; Ajustes pasa a Mi perfil). Esperando que Victor apruebe el boceto.
- Preguntas de Naviquinde y de lenguaje de suscripción: ya respondidas.

## Próxima sesión (Victor, 2026-11-27)
- [x] Secretos `ONESIGNAL_APP_ID` y `ONESIGNAL_API_KEY` borrados en Supabase (2026-11-27). Opcional: borrar la app en onesignal.com.
- [ ] **Habilidades** (detalle en el doc de QA, pestaña Pendientes): arreglar el duplicado al crear una habilidad y pasar a logros por grupo.

## A. Pendientes chicos (sin dinero ni permisos)
- [ ] Cambiar la talla en una suscripción ya hecha con las listas de equipamiento de cada liga (hoy solo patines).
- [ ] Requisito de equipo "tener aprobado tal curso".
- [ ] Plan del evento para un nivel de Coach (hoy por equipo o toda la liga).
- [ ] Comunicados que se envían al momento guardados para que aparezcan en la campana (hoy solo los programados).
- [x] Qué llevar (equipamiento): resumen 1, 2 o 3 h antes (22/11).
- [ ] Verificar: suscripción a una clase aprobada → la persona queda "Asistiré" en ese evento.
- [ ] Mi Liga: el buscador lleva directo al ajuste.
- [ ] Tours guiados según las funciones activadas (Coach, Finanzas, reglas).
- [ ] Tareas: cupos y personas fijas en recurrentes; reasignar al archivar o borrar a alguien.
- [ ] Cursos: "Mi progreso" para quien está inscritx; rediseño de Pre-armados; "Reanudar" el asistente; precargar lugar y hora; lista de personas por nivel.
- [ ] Finanzas: exportar .xlsx real (hoy CSV) y plantilla para importar cuentas viejas.
- [ ] Inventario: fotos y etiqueta por artículo.

## B. Tocan dinero o permisos (confirmar con Victor antes de construir)
- [ ] Precios de clases y cupones en un solo lugar.
- [ ] Desactivar cobros, planes y cupones por liga.
- [ ] Tipos de equipo: revisar qué falta tras las reglas por equipo (pasa a la pestaña Equipos de Liga).
- [ ] Datos sensibles: al menos una persona debe poder verlos; cada persona elige qué Pivots ven su emergencia y domicilio.
- [ ] Rectificaciones: elegir a qué Pivots se envían.
- [ ] Recompensa al aprobar un curso (puntos, descuento, clases gratis o recompensa de la liga).
- [ ] Planes de pago con descuento ("3 meses por $50").
- [ ] Conciliar cuentas con una persona responsable.
- [ ] Caja de ventas en eventos (externxs con enlace; cierre aprobado por un Pivot).
- [ ] Login: pedir acceso a una liga sin enlace.

## C. Grandes
- [ ] Zona horaria por liga (hoy horarios, notificaciones y cron usan la hora de Ecuador).
- [ ] Pruebas en cursos y plan del entrenamiento con "Comenzar" (temporizador por bloque).
- [ ] Partidos y torneos (roller derby): posiciones, line-ups, statsbook de WFTDA.
- [ ] Crear tu liga, lo que falta; directorio "Ligas en Pivot".
- [ ] Versión de escritorio.

## D. Antes de Play Store (al final, orden de Victor)
- [ ] QA completo con Chrome, usuario por usuario (necesita una cuenta de prueba por rol).
- [ ] Seguridad (permisos de Pivot, fugas de datos, advisors de Supabase, RLS en todas las tablas) y escalabilidad (consultas grandes, índices, prueba de carga).
- [ ] Legal: aviso de Tesorería revisado por abogado.
- [ ] Pruebas automáticas de totales en Tesorería.
- [x] Migración de cuentas a pivot.app.support@gmail.com (cerrada el 2026-11-27; OneSignal dado de baja).
- [ ] Probar en teléfonos reales (también que cada notificación abra su pantalla).
- [ ] Dos versiones (prueba y producción) y Play Store.
