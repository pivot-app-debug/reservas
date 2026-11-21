import 'package:flutter/material.dart';

/// Plantillas y piezas del "Social o fiesta" (Victor, 2026-11-20; NAVIQUINDE.md,
/// "Segunda versión"). Una plantilla solo preselecciona piezas y trae
/// sugerencias: todo se puede prender, apagar y editar después.

/// Piezas que se prenden o apagan. Las cuatro primeras de la lista
/// `piezasModulo` se guardan como columnas (amigo_secreto, regalo_robado,
/// comida, invitados); el resto va en `social_eventos.piezas`.
enum Pieza {
  comida('Qué lleva cada quien', 'Comida, bebida y cosas para la fiesta: cada quien se anota con lo que lleva y todxs ven qué falta', Icons.restaurant_rounded),
  playlist('Playlist colaborativa', 'Un enlace de Spotify u otra app para que todxs sumen canciones', Icons.queue_music_rounded),
  amigoSecreto('Amigo secreto', 'Se sortea a quién le regala cada persona; cada quien deja pistas y su wishlist', Icons.redeem_rounded),
  regaloRobado('Regalo robado', 'Tope, recordatorio y reglas del juego', Icons.card_giftcard_rounded),
  dress('Dress code o disfraces', 'Cómo venir vestidxs', Icons.checkroom_rounded),
  // Ya no se elige: pasó a ser secciones de "¿Qué llevamos?" (Victor, 2026-11-20).
  traer('Lista de qué traer', 'Cosas que hacen falta; cada quien se anota', Icons.checklist_rtl_rounded),
  homenaje('Homenaje', 'Mensajes de todxs y regalo entre todxs para alguien', Icons.favorite_border_rounded),
  premios('Premios o reconocimientos', 'Lista de premios y a quién', Icons.emoji_events_outlined),
  invitados('+1 con enlace', 'Cada persona puede sumar invitadxs, que entran sin cuenta', Icons.person_add_alt_1_outlined);

  const Pieza(this.titulo, this.texto, this.icono);
  final String titulo, texto;
  final IconData icono;

  bool get esModulo => this == comida || this == amigoSecreto || this == regaloRobado || this == invitados;
}

class CategoriaSugerida {
  const CategoriaSugerida(this.nombre, this.unidad, this.porPersona);
  final String nombre, unidad;
  final num porPersona;
}

/// Sugerencias propias de cada plantilla o festividad.
class Sugerencias {
  const Sugerencias({
    this.piezas = const {},
    this.nombre = '',
    this.comida = _comidaBase,
    this.dress = const [],
    this.traer = const [],
    this.premios = const [],
    this.playlist = '',
    this.sorpresa = false,
  });
  final Set<Pieza> piezas;
  final String nombre;
  final List<CategoriaSugerida> comida;
  final List<String> dress, traer, premios;
  final String playlist;

  /// Sugerir homenaje y sorpresa (cumpleaños, despedida).
  final bool sorpresa;
}

const _comidaBase = [
  CategoriaSugerida('Bebidas', 'litros', 1),
  CategoriaSugerida('Salado', 'porciones', 2),
  CategoriaSugerida('Acompañantes', 'porciones', 2),
  CategoriaSugerida('Snacks', 'porciones', 2),
  CategoriaSugerida('Postres', 'porciones', 2),
];

class Plantilla {
  const Plantilla(this.id, this.titulo, this.texto, this.icono, this.sugerencias);
  final String id, titulo, texto;
  final IconData icono;
  final Sugerencias sugerencias;
}

const kPlantillas = [
  Plantilla(
    'fiesta',
    'Fiesta',
    'Para celebrar porque sí',
    Icons.celebration_outlined,
    Sugerencias(
      piezas: {Pieza.comida, Pieza.playlist, Pieza.invitados},
      nombre: 'Fiesta de la liga',
      traer: ['Hielo', 'Vasos y platos', 'Parlante'],
      playlist: 'Música para bailar',
    ),
  ),
  Plantilla('festividad', 'Festividad de temporada', 'Navidad, Año nuevo, Halloween, Pascua u otra', Icons.event_available_outlined, Sugerencias()),
  Plantilla(
    'cumpleanos',
    'Cumpleaños',
    'Con homenaje y, si quieres, sorpresa',
    Icons.cake_outlined,
    Sugerencias(
      piezas: {Pieza.comida, Pieza.playlist, Pieza.homenaje},
      nombre: 'Cumpleaños',
      comida: [CategoriaSugerida('Pastel', 'porciones', 2), CategoriaSugerida('Bebidas', 'litros', 1), CategoriaSugerida('Snacks', 'porciones', 2)],
      traer: ['Velas', 'Globos', 'Tarjeta para firmar'],
      sorpresa: true,
    ),
  ),
  Plantilla(
    'aniversario',
    'Aniversario de la liga',
    'Para celebrar otro año juntxs',
    Icons.military_tech_outlined,
    Sugerencias(
      piezas: {Pieza.comida, Pieza.playlist, Pieza.premios, Pieza.invitados},
      nombre: 'Aniversario de la liga',
      traer: ['Fotos de la liga', 'Camiseta de la liga'],
      dress: ['Con la camiseta de la liga', 'Colores de la liga'],
      premios: ['Mejor compañerx', 'Revelación de la temporada', 'Más años en la liga', 'Espíritu de equipo'],
    ),
  ),
  Plantilla(
    'despedida',
    'Despedida o bienvenida',
    'Para alguien que se va o que llega',
    Icons.waving_hand_outlined,
    Sugerencias(piezas: {Pieza.comida, Pieza.homenaje}, nombre: 'Despedida', traer: ['Fotos juntxs', 'Tarjeta para firmar'], sorpresa: true),
  ),
  Plantilla('personalizado', 'Personalizado', 'Eliges todo desde cero', Icons.extension_outlined, Sugerencias(comida: [])),
];

class Festividad {
  const Festividad(this.nombre, this.icono, this.sugerencias);
  final String nombre;
  final IconData icono;
  final Sugerencias sugerencias;
}

const kFestividades = [
  Festividad(
    'Navidad',
    Icons.park_outlined,
    Sugerencias(
      piezas: {Pieza.comida, Pieza.amigoSecreto, Pieza.regaloRobado, Pieza.invitados},
      nombre: 'Fiesta de Navidad',
      comida: [
        CategoriaSugerida('Bebidas', 'litros', 1),
        CategoriaSugerida('Platos salados', 'porciones', 2),
        CategoriaSugerida('Acompañantes', 'porciones', 2),
        CategoriaSugerida('Postres navideños', 'porciones', 2),
        CategoriaSugerida('Snacks', 'porciones', 2),
      ],
      dress: ['Suéter navideño', 'Rojo y verde', 'Gorro de Navidad'],
      traer: ['Adornos', 'Vasos y platos', 'Hielo'],
      playlist: 'Villancicos y música para bailar',
    ),
  ),
  Festividad(
    'Año nuevo',
    Icons.auto_awesome_outlined,
    Sugerencias(
      piezas: {Pieza.comida, Pieza.playlist, Pieza.dress, Pieza.invitados},
      nombre: 'Fiesta de Año nuevo',
      comida: [
        CategoriaSugerida('Bebidas', 'litros', 1),
        CategoriaSugerida('Brindis', 'botellas', 0.2),
        CategoriaSugerida('Bocaditos', 'porciones', 2),
        CategoriaSugerida('Uvas para las 12', 'racimos', 0.1),
      ],
      dress: ['Algo dorado', 'De blanco', 'Algo amarillo'],
      traer: ['Hielo', 'Gorros y matracas', 'Vasos'],
      playlist: 'Para bailar hasta la medianoche',
    ),
  ),
  Festividad(
    'Halloween',
    Icons.dark_mode_outlined,
    Sugerencias(
      piezas: {Pieza.dress, Pieza.comida, Pieza.playlist, Pieza.premios, Pieza.invitados},
      nombre: 'Fiesta de Halloween',
      comida: [CategoriaSugerida('Bebidas', 'litros', 1), CategoriaSugerida('Snacks de miedo', 'porciones', 2), CategoriaSugerida('Dulces', 'bolsas', 0.3)],
      dress: ['Disfraz libre', 'Disfraz en grupo', 'Personajes de terror'],
      traer: ['Calabazas', 'Decoración de miedo'],
      premios: ['Mejor disfraz', 'Disfraz más original', 'Disfraz más terrorífico'],
      playlist: 'Canciones de miedo',
    ),
  ),
  Festividad(
    'Pascua',
    Icons.egg_outlined,
    Sugerencias(
      piezas: {Pieza.comida, Pieza.traer},
      nombre: 'Pascua',
      comida: [
        CategoriaSugerida('Fanesca', 'porciones', 2),
        CategoriaSugerida('Huevos de chocolate', 'unidades', 2),
        CategoriaSugerida('Bebidas', 'litros', 1),
      ],
      dress: ['Orejas de conejo', 'Colores pastel'],
      traer: ['Huevos para esconder', 'Canastas'],
    ),
  ),
];

/// Festividad escrita por la persona: sugerencias generales.
const kFestividadOtra = Sugerencias(piezas: {Pieza.comida, Pieza.playlist, Pieza.invitados});

Sugerencias sugerenciasDe(String plantilla, String? festividad) {
  if (plantilla == 'festividad') {
    for (final f in kFestividades) {
      if (f.nombre == festividad) return f.sugerencias;
    }
    return kFestividadOtra;
  }
  return kPlantillas.firstWhere((p) => p.id == plantilla, orElse: () => kPlantillas.last).sugerencias;
}

const kSugerenciasNeutras = ['Reunión del equipo', 'Junta de la liga', 'Entrenamiento especial', 'Salida del equipo'];

/// Reglas de siempre del regalo robado (igual que `PLANTILLA_REGALO_ROBADO`
/// del servidor): sirven de punto de partida para editarlas.
/// Reglas escritas del regalo robado según las opciones del juego (Victor,
/// 2026-11-20). Igual que `plantillaReglasRobado` en social_juego.ts.
String reglasRegaloRobado({int robosMax = 3, bool devolver = false, bool turnoFinal = true}) => [
  '1. Cada persona trae un regalo envuelto y sin nombre. Solo juega quien trajo regalo.',
  '2. Todos los regalos se ponen juntos en una pila.',
  '3. Se sortea el orden de los turnos.',
  '4. En tu turno eliges: abres un regalo de la pila o robas uno que ya esté abierto.',
  devolver
      ? '5. Si te roban, vuelves a elegir: abres uno de la pila o robas otro (también puedes recuperar el que te quitaron).'
      : '5. Si te roban, vuelves a elegir: abres uno de la pila o robas otro, pero no el que te acaban de quitar.',
  robosMax > 0
      ? '6. Un mismo regalo se puede robar como máximo $robosMax ${robosMax == 1 ? 'vez' : 'veces'}. Al llegar a ese número se queda con esa persona.'
      : '6. Un regalo se puede robar todas las veces que se quiera.',
  turnoFinal
      ? '7. El juego termina cuando se abre el último regalo de la pila. Quien tuvo el primer turno puede, al final, cambiar su regalo por otro que todavía se pueda robar.'
      : '7. El juego termina cuando se abre el último regalo de la pila.',
  '8. Lo importante es pasarla bien juntxs: nada de enojos por un regalo.',
].join('\n');

final kReglasRegaloRobado = reglasRegaloRobado();

/// Íconos del Social o fiesta en el calendario (Victor, 2026-11-20). La clave
/// la manda el servidor (`socialIcono`): la que eligió quien organiza para una
/// festividad propia, o la de la festividad o la plantilla.
const kIconosSocial = <String, IconData>{
  'fiesta': Icons.celebration_rounded,
  'navidad': Icons.park_rounded,
  'anio_nuevo': Icons.auto_awesome_rounded,
  'halloween': Icons.dark_mode_rounded,
  'pascua': Icons.egg_rounded,
  'cumple': Icons.cake_rounded,
  'aniversario': Icons.emoji_events_rounded,
  'despedida': Icons.waving_hand_rounded,
  'regalo': Icons.card_giftcard_rounded,
  'musica': Icons.music_note_rounded,
  'baile': Icons.nightlife_rounded,
  'comida': Icons.restaurant_rounded,
  'bebida': Icons.local_bar_rounded,
  'flor': Icons.local_florist_rounded,
  'corazon': Icons.favorite_rounded,
  'estrella': Icons.star_rounded,
  'sol': Icons.wb_sunny_rounded,
  'nieve': Icons.ac_unit_rounded,
  'mascara': Icons.theater_comedy_rounded,
  'bandera': Icons.flag_rounded,
  'deporte': Icons.sports_rounded,
  'viaje': Icons.luggage_rounded,
};

IconData iconoSocial(String? clave) => kIconosSocial[clave] ?? Icons.celebration_rounded;
