# Evento social (Naviquinde) — especificación acordada con Victor (19/11/2026)

La Naviquinde es la fiesta de fin de año de Quindes (19/12/2026). En Pivot se construye como un tipo de evento genérico **"Social"**, para cualquier liga y deporte. Tiene que estar en producción antes del cierre de inscripción (máximo 2 semanas antes: 05/12/2026), idealmente esta semana.

## Decidido
- Tipo de evento "Social" con módulos que se activan al crearlo: **Amigo secreto**, **Regalo robado** (tope de presupuesto y recordatorio), **Comida compartida** e **invitadxs +1**. Dos topes de presupuesto en la moneda de la liga (amigo secreto y regalo robado).
- **Asistencia:** cada persona marca Asistiré y puede sumar uno o más +1 (nombre y WhatsApp o correo). Cada +1 recibe un enlace propio (token) para entrar **sin crear cuenta**: su mini perfil, pistas/wishlist, su ruleta y la comida.
- **Fecha de cierre** de inscripción al amigo secreto: por defecto 2 semanas antes del evento; quien organiza puede elegir cualquier fecha hasta 1 día antes (Victor, 20/11), con aviso si queda a menos de 2 semanas. Quien se suma después no entra al amigo secreto (sí a la comida).
- **Sorteo:** al cerrar, la app arma las parejas como un ciclo (A→B→C→…→A), que funciona con cualquier cantidad, par o impar. Reglas: nadie se toca a sí mismx; una persona y su +1 nunca se tocan entre sí (en ningún sentido); quien organiza puede marcar parejas que no se pueden tocar (Victor, 20/11); a futuro, no repetir la pareja del año anterior (guardar historial por liga). Si las reglas lo hacen imposible, se avisa a quien organiza.
- **Ruleta:** cada persona (o +1) gira su propia ruleta y le revela a quién le toca. Después queda oculto bajo "Ver mi amigo secreto" (ícono de ojo).
- **Privacidad:** cada quien ve solo la ficha de la persona que le tocó (pistas y wishlist). Lxs +1 tampoco ven la lista de asistentes.
- **Pistas sobre mí:** listas de cosas que te gustan, cosas sobre ti y cosas que no quieres que te regalen, con sugerencias en chips que se agregan a la lista. **Quedan guardadas para el año siguiente** (se pueden actualizar).
- **Wishlist** (como Drawnames): se arma a partir de lo que te gusta y lo que no; talla (camiseta, medias), hasta 2 favoritos con nota, ítems con link opcional (sin integración con Temu: se pega el link). Además, link opcional a una wishlist en otra app (Wishdeck, Amazon u otra; Victor, 20/11). El catálogo grande de regalos con monedas (plan de Gemini, 1500 ítems) queda para una segunda etapa.
- **Preguntas anónimas** entre quien regala y su amigo secreto (segunda etapa si no llega).
- **Comida compartida:** quien organiza arma categorías (Bebidas, Salado, Snacks, Postres…) con unidad y cantidad por asistente; meta = ceil(asistentes confirmadxs + +1 × cantidad por persona); barras de avance; cada quien se anota con lo que lleva; al llegar al 100 % la categoría se cierra; si se suman +1 la meta se recalcula.
- Arquitectura: app Flutter (no html/css/js separados como decía el plan de Gemini). Colores solo de tema.dart.

## Por confirmar (pestaña "Preguntas de claude" del Google Doc)
- ¿El regalo robado necesita algo más en la app (turnos, reglas) o solo tope y recordatorio? (por defecto: solo tope y recordatorio)
- ¿Quién crea el evento social: solo Pivots o cualquiera del equipo? (por defecto: Pivots)

## Plan de Gemini (referencia, adaptado arriba)
Catálogo `currency_tiers.json` + 5 lotes de 300 regalos (id, titles es/en, price_tier, age_groups, regions, season, tags con pesos) → `gift_catalog_master.json`; wishlist con feed que aprende de "agregar"/"descartar" reordenando solo lo que queda abajo; ruleta con Lottie; puntos de participación opcionales por confirmar a tiempo o cumplir con la comida.

## Segunda versión: "Social o fiesta" (Victor, 20/11/2026) — reemplaza lo de arriba donde choque
- El tipo "Social" pasa a llamarse **"Social o fiesta"** y se arma **por piezas, como un rompecabezas**: un asistente paso a paso pregunta qué vas a armar y propone piezas, que se pueden prender, apagar y editar después.
- **Plantillas de inicio** (solo preseleccionan piezas): Fiesta; Festividad de temporada (Navidad, Año nuevo, Halloween, Día de muertos, Pascua o una que la persona escriba; cada una con sugerencias propias, por ejemplo Día de muertos: colada morada y guaguas de pan; Halloween: disfraces; Año nuevo: bebidas); Cumpleaños; Aniversario de la liga; Despedida o bienvenida; Personalizado. Se pueden combinar: una fiesta de Navidad con amigo secreto y además homenaje a alguien que cumple años ese día.
- **Piezas:** Comida y bebida compartida (categorías y "qué trae cada quien", con metas por asistente); Playlist colaborativa (link de Spotify u otro); Amigo secreto (lo ya hecho); Regalo robado (con reglas de plantilla editables); Dress code o disfraces; Lista de "qué traer" personalizada; Homenaje (personas homenajeadas, mensajes de todxs para ellas, regalo entre todxs); Premios o reconocimientos; +1 con enlace.
- **Regalo entre todxs:** la app solo anota quién aporta cuánto y quién compra, con un tope. **No pasa por Finanzas** ni deja movimientos en las cuentas del equipo.
- **Quién crea:** cualquier persona de la liga, sin permiso. Elige a quién invita (su equipo, varios equipos, toda la liga o personas sueltas) y puede sumar encargadxs, que también editan.
- **Aprobación:** un Pivot aprueba antes de que se publique en el calendario. Nunca lo aprueba una persona homenajeada ni alguien que no deba enterarse. Si todos los Pivots son homenajeadxs o no deben enterarse, el evento se publica sin aprobación (decisión de Claude, Victor pidió ayuda con esto el 20/11).
- **Sorpresa:** al crear o al editar se eligen las personas homenajeadas y quiénes no deben enterarse. Ellas ven el evento como uno normal (nombre neutro, lugar y hora) sin el motivo, el homenaje, los regalos ni los mensajes, y no saben que es sorpresa. El resto ve "Sorpresa para X" y todo el detalle. Si el evento ya existe se puede editar para agregar el homenaje y la sorpresa.
- La Naviquinde es una "Festividad de temporada: Navidad" con amigo secreto, regalo robado, comida y +1.
