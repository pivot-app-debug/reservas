# Contexto y Reglas del Proyecto: Pivot

## 1. Stack Tecnológico
- **Frontend:** Flutter (Dart)
- **Backend / Base de datos:** Supabase (PostgreSQL, Auth, Storage, Edge Functions)
- **Control de versiones:** Git & GitHub
- **Entorno de desarrollo:** Trabajo en paralelo con Claude Code y Google Antigravity, por lo que debés mantener estricta compatibilidad con las reglas y convenciones existentes en el repositorio (`CLAUDE.md`, `GEMINI.md` o documentación en `/docs` si existen).

## 2. Arquitectura y Convenciones de Código
- **Antes de escribir código:** Revisá siempre `pubspec.yaml`, la estructura de `lib/` y cualquier archivo de reglas (`CLAUDE.md` / `GEMINI.md`) para respetar el gestor de estado, patrón de carpetas, naming conventions y paquetes ya instalados. No agregues dependencias nuevas sin consultar.
- **Calidad de código:** Después de modificar archivos `.dart`, ejecutá `flutter analyze` para verificar que no haya errores de tipos, imports rotos o warnings críticos.
- **Manejo de secretos:** Nunca hardcodees API keys, URLs privadas de Supabase ni tokens en el código fuente. Verificá que `.env` o archivos de configuración sensibles estén en `.gitignore`.

## 3. Uso de Conectores (MCP) y Herramientas CLI
Tenés acceso tanto a servidores **MCP** (Supabase, GitHub, etc.) como a la terminal local. Usalos con este criterio:
- **Supabase (MCP + CLI):**
  - Usá el MCP de Supabase para inspeccionar esquemas, tablas, políticas RLS y datos antes de asumir nombres de columnas o tipos.
  - Para cambios de esquema, creá archivos de migración limpios en `supabase/migrations/` y verificá con `supabase db push` o el MCP correspondiente.
- **GitHub (MCP + Git CLI):**
  - Revisá `git status` y la rama actual antes de hacer cambios grandes.
  - Usá el MCP de GitHub para consultar issues, PRs o estado del repositorio remoto cuando haga falta.
  - Mantené commits atómicos y descriptivos en español o inglés según el historial del repo (`git log -n 5`).

## 4. Protocolo de Seguridad y Confirmación
- **Ejecución autónoma:** Podés leer archivos, buscar en el proyecto, correr `flutter analyze`, `flutter pub get`, `git status` y hacer consultas de lectura en MCP sin pedir permiso.
- **Pedir confirmación explícita antes de:**
  1. Ejecutar migraciones destructivas en Supabase (`DROP`, `TRUNCATE`, borrado de columnas o cambios en políticas RLS de producción).
  2. Hacer `git push` a `main`/`master` o force push.
  3. Compilar builds pesados (`flutter build apk`, `ios`, `web`) salvo que se te pida explícitamente.

## 5. Flujo de Trabajo Esperado
1. **Entender:** Inspeccioná los archivos afectados y el esquema de Supabase involucrado.
2. **Planificar:** Si la tarea toca más de 2 archivos o involucra base de datos + UI, explicá brevemente el plan antes de ejecutar.
3. **Implementar y Verificar:** Aplicá los cambios, corré `flutter analyze` y resumí qué archivos tocaste y si quedó algún paso manual pendiente.

## 6. Fuentes de verdad del proyecto (este repo)
- **Reglas Antigravity:** `.gemini/rules/pivot.md` — flujo obligatorio (`git pull origin main` antes de cada tarea, leer MANIFEST.md, actualizar MANIFEST.md y CHANGELOG.md al terminar, commit+push en español, migraciones de Supabase solo con aprobación previa).
- **MANIFEST.md:** estado actual de la arquitectura (leer SIEMPRE antes de cambios).
- **CHANGELOG.md:** historial de cambios (actualizar al terminar cada tarea).
- **PENDIENTES.md:** lista de tareas pendientes categorizada.
- **HOJA_DE_RUTA.md:** roadmap de la app Android Flutter.
- **Stack del app:** Flutter en `app/`, módulos en `app/lib/` (`actividad/`, `ajustes/`, `coach/`, `core/`, `cursos/`, `equipo/`, `eventos/`, `finanzas/`, `liga/`, `pivots/`, `push/`, `reservas/`, `sesion/`, `tareas/`); backend Supabase en `supabase/` (Edge Function `api`, migraciones en `supabase/migrations/`).
- **Lenguaje:** español neutro, sin voseo, sin pronombres femeninos, "Pivot"/"Pivots" reemplaza a admin/administradorxs.
