# Evento social (Naviquinde) — especificación acordada con Victor (19/11/2026)

La Naviquinde es la fiesta de fin de año de Quindes (19/12/2026). En Pivot se construye como un tipo de evento genérico **"Social"**, para cualquier liga y deporte. Tiene que estar en producción antes del cierre de inscripción (máximo 2 semanas antes: 05/12/2026), idealmente esta semana.

## Decidido
- Tipo de evento "Social" con módulos que se activan al crearlo: **Amigo secreto**, **Regalo robado** (tope de presupuesto y recordatorio), **Comida compartida** e **invitadxs +1**. Dos topes de presupuesto en la moneda de la liga (amigo secreto y regalo robado).
- **Asistencia:** cada persona marca Asistiré y puede sumar uno o más +1 (nombre y WhatsApp o correo). Cada +1 recibe un enlace propio (token) para entrar **sin crear cuenta**: su mini perfil, pistas/wishlist, su ruleta y la comida.
- **Fecha de cierre** de inscripción al amigo secreto: como máximo 2 semanas antes del evento. Quien se suma después no entra al amigo secreto (sí a la comida).
- **Sorteo:** al cerrar, la app arma las parejas como un ciclo (A→B→C→…→A), que funciona con cualquier cantidad, par o impar. Reglas: nadie se toca a sí mismx; una persona y su +1 nunca se tocan entre sí (en ningún sentido); a futuro, no repetir la pareja del año anterior (guardar historial por liga). Si las reglas lo hacen imposible, se avisa a quien organiza.
- **Ruleta:** cada persona (o +1) gira su propia ruleta y le revela a quién le toca. Después queda oculto bajo "Ver mi amigo secreto" (ícono de ojo).
- **Privacidad:** cada quien ve solo la ficha de la persona que le tocó (pistas y wishlist). Lxs +1 tampoco ven la lista de asistentes.
- **Pistas sobre mí:** listas de cosas que te gustan, cosas sobre ti y cosas que no quieres que te regalen, con sugerencias en chips que se agregan a la lista. **Quedan guardadas para el año siguiente** (se pueden actualizar).
- **Wishlist** (como Drawnames): se arma a partir de lo que te gusta y lo que no; talla (camiseta, medias), hasta 2 favoritos con nota, ítems con link opcional (sin integración con Temu: se pega el link). El catálogo grande de regalos con monedas (plan de Gemini, 1500 ítems) queda para una segunda etapa.
- **Preguntas anónimas** entre quien regala y su amigo secreto (segunda etapa si no llega).
- **Comida compartida:** quien organiza arma categorías (Bebidas, Salado, Snacks, Postres…) con unidad y cantidad por asistente; meta = ceil(asistentes confirmadxs + +1 × cantidad por persona); barras de avance; cada quien se anota con lo que lleva; al llegar al 100 % la categoría se cierra; si se suman +1 la meta se recalcula.
- Arquitectura: app Flutter (no html/css/js separados como decía el plan de Gemini). Colores solo de tema.dart.

## Por confirmar (pestaña "Preguntas de claude" del Google Doc)
- ¿El regalo robado necesita algo más en la app (turnos, reglas) o solo tope y recordatorio? (por defecto: solo tope y recordatorio)
- ¿Quién crea el evento social: solo Pivots o cualquiera del equipo? (por defecto: Pivots)

## Plan de Gemini (referencia, adaptado arriba)
Catálogo `currency_tiers.json` + 5 lotes de 300 regalos (id, titles es/en, price_tier, age_groups, regions, season, tags con pesos) → `gift_catalog_master.json`; wishlist con feed que aprende de "agregar"/"descartar" reordenando solo lo que queda abajo; ruleta con Lottie; puntos de participación opcionales por confirmar a tiempo o cumplir con la comida.
