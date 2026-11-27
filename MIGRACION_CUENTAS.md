# Migración de cuentas a la cuenta de Google de Pivot

Correo de Pivot: **pivot.app.support@gmail.com** (antes la cuenta se llamaba `pivot.app.suppor`; se le cambió el nombre en noviembre de 2026).
Victor hace estos pasos a mano. Al terminar cada servicio, avisar a Claude para que actualice lo que haga falta en el código.

## Estado (2026-11-27): migración cerrada
| Servicio | Estado |
|---|---|
| GitHub | **Hecho.** Repositorio transferido a la cuenta de Pivot `pivot-app-debug` (cuenta personal, sin organización): `pivot-app-debug/reservas`. App de Claude instalada en esa cuenta. Enlace de descargas de la app actualizado. |
| Supabase | **Hecho.** El proyecto `uusbnreitoobqssizbfq` (mismo proyecto, mismas claves) está en la organización «Pivot» de la cuenta de Pivot. La cuenta vieja ya no es Owner (2026-11-27). Conector de Claude y `SUPABASE_ACCESS_TOKEN` con la cuenta nueva. |
| Web y dominio | **Hecho.** La web se publica en Firebase Hosting (`pivot-d65f4.web.app`). `app.quindesvolcanicos.com` y `reservas.quindesvolcanicos.com` redirigen ahí desde Cloudflare. |
| Google Cloud / Firebase | En la cuenta de Pivot (proyectos `pivot-d65f4` y «Pivot Login», ex mirlxs-app). **Hecho.** La cuenta vieja ya no es Owner de «Pivot Login» (2026-11-27). |
| OneSignal | **Dado de baja** (2026-11-27). No se migró: los avisos van solo por Firebase (app Android y web Flutter). Quitado del servidor y de la web vieja; secretos `ONESIGNAL_APP_ID` y `ONESIGNAL_API_KEY` borrados de Supabase. Opcional: borrar la app en onesignal.com. |
| Tareas programadas de Claude | **Revisado.** «Leer documento» (pausada) no usa el repo; «Pivot: pendientes del jueves» ya corrió y no vuelve a correr. Se dejan como están. |
| Repo `reservas-backups` | Fuera de la migración: sigue en la cuenta vieja `quindesvolcanicosrd-sys`. |

La guía de abajo queda como referencia de cómo se hizo cada paso.

---

## 1. GitHub (hecho)
El repositorio era `quindesvolcanicosrd-sys/reservas` y se transfirió directamente a la cuenta `pivot-app-debug` (sin crear organización): ahora es `pivot-app-debug/reservas`. La web ya no depende de GitHub Pages: sale de Firebase Hosting.

1. Abrir una ventana privada del navegador y crear una cuenta de GitHub en github.com/signup con pivot.app.support@gmail.com. Activar la verificación en dos pasos.
2. Con esa cuenta, crear una organización gratuita: github.com/organizations/plan → "Free". Nombre sugerido: `pivot-app` (o el que esté libre).
3. En la organización: Settings → Member privileges → dejar activado "Allow members to create repositories" (no hace falta tocar nada más).
4. Desde la cuenta actual (`quindesvolcanicosrd-sys`), invitar a la cuenta nueva como colaboradora del repositorio: repositorio → Settings → Collaborators → Add people. Aceptar la invitación desde el correo nuevo.
5. Agregar la cuenta actual como miembro (Owner) de la organización nueva: organización → People → Invite member. Aceptar desde la cuenta actual. Así ambas cuentas pueden mover el repositorio.
6. Antes de transferir, anotar en un lugar seguro los nombres de los secretos: repositorio → Settings → Secrets and variables → Actions. Hoy son `FIRMA_CLAVE`, `FIRMA_JKS_B` y `SUPABASE_ACCESS_TOKEN`. Tener a mano sus valores por si hay que volver a cargarlos (el archivo de firma de Android y su clave sobre todo).
7. Transferir: repositorio → Settings → General → abajo, "Transfer ownership" → elegir la organización nueva → escribir el nombre del repositorio para confirmar.
8. En el repositorio ya transferido, revisar:
   1. Settings → Secrets and variables → Actions: que sigan los tres secretos. Si falta alguno, volver a crearlo con el mismo nombre.
   2. Settings → Pages: que siga el dominio `app.quindesvolcanicos.com` y "Enforce HTTPS" activado. Si no aparece, escribirlo de nuevo y guardar.
   3. Settings → Actions → General: que las acciones estén permitidas y con permiso de lectura y escritura ("Read and write permissions").
9. En el DNS del dominio no hay que cambiar nada si el registro apunta a `github.io` de forma genérica. Si el CNAME apunta a `quindesvolcanicosrd-sys.github.io`, cambiarlo por `<organización-nueva>.github.io`.
10. Hacer un cambio pequeño (o "Re-run" del último workflow en la pestaña Actions) y confirmar que los tres workflows terminan en verde.
11. Avisar a Claude para actualizar en el código el enlace de descargas de la app (`app/lib/core/actualizacion.dart`). Hecho el 2026-11-27: apunta a `pivot-app-debug`.
12. Reconectar el acceso de Claude a GitHub con el repositorio en su nueva ubicación (claude.ai → conectar GitHub e instalar la app de Claude en la organización nueva).

## 2. Supabase (hecho)
1. Entrar a supabase.com con "Continue with Google" usando pivot.app.support@gmail.com.
2. Crear una organización nueva (plan Free o el que tenga hoy el proyecto; si el proyecto está en un plan pago, la organización nueva debe tener el mismo plan).
3. En la organización nueva: Team → Invite → invitar la cuenta actual de Supabase como Owner. Aceptar desde la cuenta actual.
4. Desde la cuenta actual: abrir el proyecto → Project Settings → General → "Transfer project" → elegir la organización nueva → confirmar.
5. La URL del proyecto y las claves (anon/publishable y service_role) no cambian con la transferencia. Revisar en Project Settings → API que sean las mismas.
6. Crear un token de acceso nuevo desde la cuenta nueva (Account → Access Tokens) y reemplazar el secreto `SUPABASE_ACCESS_TOKEN` en GitHub (ver última sección). Después borrar el token viejo.
7. Reconectar el acceso de Claude a Supabase con la cuenta nueva.

## 3. Firebase
1. Entrar a console.firebase.google.com con la cuenta actual y abrir el proyecto de Pivot.
2. Engranaje → Users and permissions → "Add member" → pivot.app.support@gmail.com → rol **Owner**.
3. Aceptar la invitación desde el correo nuevo.
4. Confirmar en console.cloud.google.com (mismo proyecto) → IAM que la cuenta nueva aparece como Owner.
5. Si el proyecto tiene facturación, en Billing pasar la cuenta de facturación a la cuenta nueva o agregarla como administradora.
6. No hace falta cambiar `google-services.json` ni claves: el proyecto es el mismo.
7. Recién cuando todo funcione, decidir si se quita la cuenta vieja (opcional).

## 4. OneSignal (dado de baja el 2026-11-27, no se migró)
Pasos que quedaron sin usar, como referencia.

1. Entrar a onesignal.com con la cuenta actual y abrir la app de Pivot.
2. Settings → Team Members → "Invite" → pivot.app.support@gmail.com → rol **Admin**.
3. Aceptar desde el correo nuevo y crear la contraseña.
4. Para pasar la propiedad: Organization → Settings → transferir la organización a la cuenta nueva (si la opción no aparece, escribir a soporte de OneSignal desde la cuenta actual pidiendo el cambio de dueño).
5. El App ID y la REST API key no cambian. Si se genera una REST API key nueva, actualizarla (ver última sección).

## 5. Dónde actualizar secretos o claves si algo cambia
- **GitHub → Settings → Secrets and variables → Actions:** `SUPABASE_ACCESS_TOKEN` (token nuevo de Supabase), `FIRMA_JKS_B` y `FIRMA_CLAVE` (firma de Android; no cambian, solo volver a cargarlos si se perdieron).
- **Supabase → Edge Functions → Secrets:** la clave de OneSignal (REST API key) y cualquier clave de Firebase que usen las funciones. Cambiarlas solo si se generaron nuevas.
- **Código de la app:** el enlace de descargas en `app/lib/core/actualizacion.dart` (ya apunta a `pivot-app-debug`). La URL y la clave pública de Supabase y el App ID de OneSignal no cambian con la transferencia.
- **Firebase:** sin cambios en `google-services.json` mientras sea el mismo proyecto.
- Si una clave se vuelve a generar, avisar a Claude para buscar en el código y en los secretos dónde se usa.
