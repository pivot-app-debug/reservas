# Migración de cuentas a la cuenta de Google de Pivot

Correo nuevo: **pivot.app.suppor@gmail.com** (así, con "suppor").
Victor hace estos pasos a mano. Al terminar cada servicio, avisar en la Bandeja para que Claude actualice lo que haga falta en el código.

## Orden recomendado
1. GitHub (repositorio, web y descargas de la app).
2. Supabase (base de datos y funciones).
3. Firebase (avisos push de Android).
4. OneSignal (avisos push).
5. Revisar secretos y claves (última sección).

Hacer un servicio por vez y probar la app antes de pasar al siguiente.

---

## 1. GitHub
Hoy el repositorio es `quindesvolcanicosrd-sys/reservas`. La web sale de GitHub Pages con el dominio `app.quindesvolcanicos.com`.

1. Abrir una ventana privada del navegador y crear una cuenta de GitHub en github.com/signup con pivot.app.suppor@gmail.com. Activar la verificación en dos pasos.
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
11. Avisar a Claude para actualizar en el código el enlace de descargas de la app (`app/lib/core/actualizacion.dart`), que todavía nombra a `quindesvolcanicosrd-sys`. GitHub redirige el enlace viejo, pero conviene cambiarlo.
12. Reconectar el acceso de Claude a GitHub con el repositorio en su nueva ubicación (claude.ai → conectar GitHub e instalar la app de Claude en la organización nueva).

## 2. Supabase
1. Entrar a supabase.com con "Continue with Google" usando pivot.app.suppor@gmail.com.
2. Crear una organización nueva (plan Free o el que tenga hoy el proyecto; si el proyecto está en un plan pago, la organización nueva debe tener el mismo plan).
3. En la organización nueva: Team → Invite → invitar la cuenta actual de Supabase como Owner. Aceptar desde la cuenta actual.
4. Desde la cuenta actual: abrir el proyecto → Project Settings → General → "Transfer project" → elegir la organización nueva → confirmar.
5. La URL del proyecto y las claves (anon/publishable y service_role) no cambian con la transferencia. Revisar en Project Settings → API que sean las mismas.
6. Crear un token de acceso nuevo desde la cuenta nueva (Account → Access Tokens) y reemplazar el secreto `SUPABASE_ACCESS_TOKEN` en GitHub (ver última sección). Después borrar el token viejo.
7. Reconectar el acceso de Claude a Supabase con la cuenta nueva.

## 3. Firebase
1. Entrar a console.firebase.google.com con la cuenta actual y abrir el proyecto de Pivot.
2. Engranaje → Users and permissions → "Add member" → pivot.app.suppor@gmail.com → rol **Owner**.
3. Aceptar la invitación desde el correo nuevo.
4. Confirmar en console.cloud.google.com (mismo proyecto) → IAM que la cuenta nueva aparece como Owner.
5. Si el proyecto tiene facturación, en Billing pasar la cuenta de facturación a la cuenta nueva o agregarla como administradora.
6. No hace falta cambiar `google-services.json` ni claves: el proyecto es el mismo.
7. Recién cuando todo funcione, decidir si se quita la cuenta vieja (opcional).

## 4. OneSignal
1. Entrar a onesignal.com con la cuenta actual y abrir la app de Pivot.
2. Settings → Team Members → "Invite" → pivot.app.suppor@gmail.com → rol **Admin**.
3. Aceptar desde el correo nuevo y crear la contraseña.
4. Para pasar la propiedad: Organization → Settings → transferir la organización a la cuenta nueva (si la opción no aparece, escribir a soporte de OneSignal desde la cuenta actual pidiendo el cambio de dueño).
5. El App ID y la REST API key no cambian. Si se genera una REST API key nueva, actualizarla (ver última sección).

## 5. Dónde actualizar secretos o claves si algo cambia
- **GitHub → Settings → Secrets and variables → Actions:** `SUPABASE_ACCESS_TOKEN` (token nuevo de Supabase), `FIRMA_JKS_B` y `FIRMA_CLAVE` (firma de Android; no cambian, solo volver a cargarlos si se perdieron).
- **Supabase → Edge Functions → Secrets:** la clave de OneSignal (REST API key) y cualquier clave de Firebase que usen las funciones. Cambiarlas solo si se generaron nuevas.
- **Código de la app:** el enlace de descargas en `app/lib/core/actualizacion.dart` (cambia con GitHub). La URL y la clave pública de Supabase y el App ID de OneSignal no cambian con la transferencia.
- **Firebase:** sin cambios en `google-services.json` mientras sea el mismo proyecto.
- Si una clave se vuelve a generar, avisar a Claude para buscar en el código y en los secretos dónde se usa.
