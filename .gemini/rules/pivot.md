# Reglas del proyecto Pivot — Antigravity

## Quién es Victor
- Desarrolla la app Pivot junto con asistentes de IA (Claude, Antigravity).
- Trabaja por chat: describe tareas, bugs o nuevas funciones y el agente ejecuta todo.
- Nunca ejecuta comandos en la terminal por su cuenta — el agente hace push, commit, etc.
- Trabaja en paralelo desde Claude (web/móvil) y desde Antigravity (PC). El punto de sincronización entre ambos es GitHub (`pivot-app-debug/reservas`, rama `main`).

---

## Flujo de trabajo obligatorio

### Antes de cada tarea
1. **Siempre hacer `git pull origin main`** para traer los cambios más recientes (pueden venir de Claude).
2. **Leer MANIFEST.md** antes de cualquier cambio. Es la fuente de verdad del estado actual de la arquitectura.
3. **Leer el Google Doc de QA** cuando la tarea lo requiera: https://docs.google.com/document/d/12Exhxe8_ZH3MvM60IQtEI2kONrWcaVppOMSR8DiQnWo/edit

### Durante cada tarea
- **Nunca mandar código entero.** Si son cambios pequeños: indicar exactamente qué buscar y qué reemplazar (find/replace).
- **Nunca hacer nada sin avisarle a Victor primero.** Siempre confirmar qué se va a hacer antes de hacerlo, aunque diga que es urgente.
- Si la tarea toca datos sensibles, dinero, permisos, textos legales o contradice una decisión anterior → parar y preguntar.
- Las **migraciones de Supabase** siempre requieren aprobación de Victor antes de ejecutarlas.

### Al terminar cada tarea
1. **Actualizar MANIFEST.md** con los cambios realizados.
2. **Actualizar CHANGELOG.md** con la fecha y descripción del cambio.
3. **Hacer commit y push** a `origin/main` con un mensaje descriptivo en español.
4. Si algo del QA Doc quedó resuelto → borrar la nota de Victor en el doc.
5. Responder con `Antigravity (fecha):` indicando qué quedó hecho, qué falta o qué pregunta hay.

---

## Arquitectura del proyecto

### Estructura general
- **Repo:** `pivot-app-debug/reservas`
- **Clone local:** `C:\Users\Victor Del Bono\Documents\GitHub\reservas`
- **App Flutter (Android nativa):** `app/` → estructura en `app/lib/` con módulos: `actividad/`, `ajustes/`, `coach/`, `core/`, `cursos/`, `equipo/`, `eventos/`, `finanzas/`, `liga/`, `pivots/`, `push/`, `reservas/`, `sesion/`, `tareas/`
- **Web (PWA legacy, congelada):** archivos en la raíz (`index.html`, `js/`, `css/`)
- **Backend:** Supabase (Postgres + Edge Function `api`)
- **Mini-SPAs:** `inscripcion/` y `registro-express/`
- **Sistemas OBSOLETOS (nunca tocar ni referenciar):** Railway, Google Sheets, Apps Script (GAS), `forwardToGAS`, `GAS_URL`

### Reglas de código (Flutter)
- Colores **solo** en `tema.dart` — nunca hardcodeados en otros archivos.
- Transiciones siempre suaves: fade/slide, nunca cortes abruptos.
- Formularios con muchos campos → subsección (`pantallaFormulario`). Formularios cortos → `hojaFormulario` (panel desde abajo).
- `BannerAyuda` siempre empieza cerrado (colapsable).

### Reglas de código (Web legacy — si se toca)
- Colores **solo** en `colors.css` — nunca en HTML, JS, ni otros CSS.
- Bordes y estilos globales en un solo CSS, nunca hardcodeados.

---

## Lenguaje y texto en la app

- **Español neutro** siempre. Sin voseo (nunca: "debés", "podés", "tenés", "querés", "dejalo", "escribilo", "elegí").
- **Sin pronombres femeninos** ni en la app ni en los chats. Todo neutro, preferentemente sin pronombres (ej: "admins", no "las admins").
- **Sin términos de roller derby** en secciones genéricas (Pivot sirve a cualquier deporte). Solo usar términos de derby donde la función sea derby-específica.
- **"Pivot"** (singular) y **"Pivots"** (plural) reemplaza a "admin/administradorxs" en toda la app.
- **Español neutro, sport-neutral, sin género.**

---

## Sobre la app Pivot

- **Nombre del producto:** Pivot (antes "Mirlxs — Reservas"). El rebrand ya está aplicado.
- **"Mirlxs"** sigue siendo el nombre del equipo de patinaje real (categoría B). No confundir con la marca Pivot.
- **"Quindes"** es la categoría A del mismo club (Quindes Volcánicos RD, Quito, Ecuador).
- **Ligas:** Pivot está pensado para cualquier liga de cualquier deporte del mundo (una sola base de datos Supabase compartida, con aislamiento por `liga_id`).
- **App nativa Android:** Flutter, `com.pivotapp.coach`, Play Store (beta cerrada pendiente). iOS queda como web app por ahora.
- **Login:** Google Sign-In. El PIN se está deprecando; se agregará email+contraseña pronto.
- **Cuenta Pivot dedicada:** `pivot.app.support@gmail.com` (antes `pivot.app.suppor`; se cambió el nombre en nov. 2026).
- **GitHub:** `pivot-app-debug/reservas` (cuenta de Pivot, sin organización; transferido en nov. 2026).

---

## Google Doc de QA y pendientes

- **URL:** https://docs.google.com/document/d/12Exhxe8_ZH3MvM60IQtEI2kONrWcaVppOMSR8DiQnWo/edit
- Victor anota tareas, bugs y propuestas por sección (de arriba hacia abajo).
- El agente responde debajo de cada nota con `Antigravity (fecha):` indicando si quedó hecho, qué falta o qué pregunta tiene.
- Lo resuelto se borra del doc; lo que queda a medias lleva ✅ en lo hecho.
- Las preguntas del agente van en la pestaña "Preguntas de claude" del doc.
- Cuando un cambio renombra secciones/títulos de la app → actualizar también ese doc.

---

## Archivos clave del repo

| Archivo | Propósito |
|---|---|
| `MANIFEST.md` | Estado actual de la arquitectura (leer SIEMPRE antes de cambios) |
| `CHANGELOG.md` | Historial de cambios (actualizar SIEMPRE al terminar) |
| `PENDIENTES.md` | Lista de tareas pendientes categorizada |
| `HOJA_DE_RUTA.md` | Roadmap de la app Android Flutter |
| `NAVIQUINDE.md` | Especificación del evento Social/Fiesta |
| `ux-decisions.md` | Decisiones de comportamiento/interacción de UX |
| `MIGRACION_CUENTAS.md` | Guía de migración de cuentas a pivot.app.support@gmail.com |

---

## Git — comandos que usa el agente (Victor nunca los ejecuta)

```
# Antes de cada tarea:
git pull origin main

# Al terminar:
git add -A
git commit -m "descripción clara en español"
git push origin main
```
