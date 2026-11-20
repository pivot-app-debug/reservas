/// Tipos de evento de "Nuevo evento" (Victor, 2026-11-19). El valor es lo que
/// se guarda (`venues.tipo_icono` → `asistencias.tipo_evento`); el texto
/// visible puede ser otro para no romper los eventos ya guardados:
/// 'Evento' se muestra como "Otro", y 'Otro' (escribir un tipo propio) como
/// "Personalizado". 'Social' activa el evento social (NAVIQUINDE.md) y se
/// muestra como "Social o fiesta" (Victor, 2026-11-20); se crea con su propio
/// asistente (`CrearSocialScreen`), abierto a cualquier persona de la liga.
const kTipoSocial = 'Social';
const kTipoReunion = 'Reunión de equipo';
const kTiposEventoBase = ['Entrenamiento', 'Partido', kTipoReunion, kTipoSocial, 'Evento', 'Otro'];

/// Texto visible de un tipo guardado.
String etiquetaTipoEvento(String valor) => switch (valor) {
  'Evento' => 'Otro',
  kTipoSocial => 'Social o fiesta',
  _ => valor,
};

/// Texto de la opción en el selector de "Nuevo evento".
String etiquetaOpcionTipo(String valor) => valor == 'Otro' ? 'Personalizado' : etiquetaTipoEvento(valor);
