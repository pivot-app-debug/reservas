import 'dart:convert';

import '../../core/api.dart';

/// Acceso a las acciones `social*` del backend (evento Social, NAVIQUINDE.md).
/// Sirve para una cuenta del equipo (token de sesión + `idEvento`) y para unx
/// invitadx +1 sin cuenta (`invitadoToken`). Nada se guarda en el teléfono:
/// las pistas, la wishlist y el amigo secreto se piden cada vez.
class SocialRepo {
  SocialRepo.miembro(this.api, {required String idEvento, String? adminToken}) : _base = {'idEvento': idEvento, 'adminToken': adminToken}, esInvitado = false;

  SocialRepo.invitado(this.api, String invitadoToken) : _base = {'invitadoToken': invitadoToken}, esInvitado = true;

  final Api api;
  final Map<String, Object?> _base;
  final bool esInvitado;

  Future<Map<String, dynamic>> _post(String accion, [Map<String, Object?> extra = const {}]) async {
    final r = await api.post(accion, {..._base, ...extra});
    if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo guardar.'}');
    return r;
  }

  Future<EstadoSocial> cargar() async {
    final r = await api.get('socialGet', _base);
    if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo cargar el evento.'}');
    return EstadoSocial(r);
  }

  Future<Map<String, dynamic>> guardarConfig(Map<String, Object?> config, List<Map<String, Object?>> categorias) =>
      _post('socialGuardarConfig', {'config': jsonEncode(config), 'categorias': jsonEncode(categorias)});

  /// El +1 escribe su nombre al abrir su enlace.
  Future<void> nombrarme(String nombre) => _post('socialInvitadoNombre', {'nombre': nombre});

  Future<Map<String, dynamic>> agregarInvitado(String nombre, String contacto) async {
    final r = await _post('socialAgregarInvitado', {'nombre': nombre, 'contacto': contacto});
    return Map<String, dynamic>.from(r['invitado'] as Map);
  }

  Future<void> quitarInvitado(String id) => _post('socialQuitarInvitado', {'id': id});

  Future<PerfilSocial> guardarPerfil(PerfilSocial p) async {
    final r = await _post('socialGuardarPerfil', {'perfil': jsonEncode(p.aJson())});
    return PerfilSocial.desde(r['perfil']);
  }

  Future<FichaAmigo> revelar() async {
    final r = await _post('socialRevelar');
    return FichaAmigo(Map<String, dynamic>.from(r['ficha'] as Map));
  }

  Future<void> anotarComida(String categoriaId, num cantidad, String detalle, {bool? paraTodxs}) =>
      _post('socialAnotarComida', {'categoriaId': categoriaId, 'cantidad': cantidad, 'detalle': detalle, 'paraTodxs': ?paraTodxs});

  Future<void> quitarAporte(String id) => _post('socialQuitarAporte', {'id': id});

  /// Quien está a cargo de la comida: agrega, cambia o quita una categoría,
  /// marca "Hace falta" y deja sugerencias (Victor, 2026-11-20).
  Future<void> editarComida({
    String? categoriaId,
    String? nombre,
    String? unidad,
    num? porPersona,
    bool? falta,
    List<String>? sugerencias,
    String? modo,
    num? total,
    bool borrar = false,
  }) => _post('socialComidaEditar', {
    'modo': ?modo,
    'total': ?total,
    'categoriaId': ?categoriaId,
    'nombre': ?nombre,
    'unidad': ?unidad,
    'porPersona': ?porPersona,
    'falta': ?falta,
    if (sugerencias != null) 'sugerencias': jsonEncode(sugerencias),
    if (borrar) 'accion': 'borrar',
  });

  Future<Map<String, dynamic>> sortear({bool rehacer = false}) => _post('socialSortear', {'rehacer': rehacer});

  /// Guarda lo que se editó en el asistente ("Social o fiesta"). `reenviar`:
  /// vuelve a mandarlo a aprobar después de que un Pivot pidió cambios.
  Future<Map<String, dynamic>> guardar(Map<String, Object?> datos, {bool reenviar = false}) =>
      _post('socialGuardarConfig', {'datos': jsonEncode(datos), 'reenviar': reenviar});

  Future<void> anotarTraer(String item, String detalle) => _post('socialAnotarTraer', {'item': item, 'detalle': detalle});

  Future<void> quitarTraer(String id) => _post('socialQuitarTraer', {'id': id});

  /// Mensaje para una persona homenajeada (vacío lo borra).
  Future<void> mensaje(String para, String texto) => _post('socialMensaje', {'para': para, 'texto': texto});

  /// Regalo entre todxs: solo anota cuánto aportas (0 lo quita). No pasa por Finanzas.
  Future<void> aportarRegalo(num monto) => _post('socialAportarRegalo', {'monto': monto});

  Future<void> liberarMensajes() => _post('socialLiberarMensajes');

  /// Crea un "Social o fiesta" (cualquier persona de la liga). Devuelve el
  /// id del evento, si quedó publicado y el mensaje para mostrar.
  static Future<Map<String, dynamic>> crear(Api api, Map<String, Object?> datos, {String? adminToken}) async {
    final r = await api.post('socialCrear', {'datos': jsonEncode(datos), 'adminToken': ?adminToken});
    if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo crear el evento.'}');
    return r;
  }

  /// Personas y equipos de la liga para elegir a quién invitar, homenajear o sumar como encargadx.
  static Future<EquipoSocial> equipo(Api api, {String? adminToken}) async {
    final r = await api.get('socialEquipo', {'adminToken': ?adminToken});
    if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo cargar la liga.'}');
    return EquipoSocial(r);
  }
}

class PersonaSocial {
  const PersonaSocial({required this.username, required this.nombre, this.equipo = '', this.foto = ''});
  final String username, nombre, equipo, foto;
}

class EquipoSocial {
  EquipoSocial(Map<String, dynamic> r)
    : personas = [
        for (final x in (r['personas'] as List? ?? const []))
          if (x is Map) PersonaSocial(username: '${x['username']}', nombre: '${x['nombre']}', equipo: '${x['equipo'] ?? ''}', foto: '${x['foto'] ?? ''}'),
      ],
      equipos = [for (final x in (r['equipos'] as List? ?? const [])) '$x'],
      yo = r['yo'] as String?,
      miEquipo = r['miEquipo'] as String?;

  final List<PersonaSocial> personas;
  final List<String> equipos;
  final String? yo, miEquipo;

  String nombreDe(String u) => personas.where((p) => p.username == u).firstOrNull?.nombre ?? u;
}

/// Respuesta de `socialGet`, con lecturas tipadas de lo que usa la interfaz.
class EstadoSocial {
  EstadoSocial(this.raw);
  final Map<String, dynamic> raw;

  Map<String, dynamic>? get social => raw['social'] is Map ? Map<String, dynamic>.from(raw['social'] as Map) : null;
  bool get configurado => social != null;
  Map<String, dynamic> get evento => Map<String, dynamic>.from((raw['evento'] as Map?) ?? const {});
  Map<String, dynamic> get yo => Map<String, dynamic>.from((raw['yo'] as Map?) ?? const {});
  Map<String, dynamic> get conteo => Map<String, dynamic>.from((raw['conteo'] as Map?) ?? const {});
  Map<String, dynamic>? get admin => raw['admin'] is Map ? Map<String, dynamic>.from(raw['admin'] as Map) : null;
  bool get esPivot => raw['esPivot'] == true;

  /// Quien creó el evento, sus encargadxs o un Pivot (que no esté en las listas de la sorpresa).
  bool get organiza => raw['organiza'] == true;

  /// Puede administrar la comida: organiza y (crea el evento, es Pivot o está a cargo de la comida).
  bool get puedeComida {
    if (!organiza) return false;
    final m = editable?['misPermisos'];
    return m is! List || m.contains('comida');
  }

  bool get esInvitadx => raw['tipo'] == 'invitado';

  /// 'organiza' | 'completa' | 'neutral' (homenajeadx o "no debe enterarse": lo ve como un evento normal).
  String get vista => '${raw['vista'] ?? 'completa'}';
  String get titulo => '${social?['titulo'] ?? ''}';
  String? get sorpresa => social?['sorpresa'] as String?;
  String get descripcion => '${social?['descripcion'] ?? ''}';

  /// 'publicado' | 'por_aprobar' | 'rechazado'.
  String get estadoAprobacion => '${social?['estado'] ?? 'publicado'}';
  String get rechazoMotivo => '${social?['rechazoMotivo'] ?? ''}';
  Map<String, dynamic>? get playlist => social?['playlist'] is Map ? Map<String, dynamic>.from(social!['playlist'] as Map) : null;
  Map<String, dynamic>? get dress => social?['dress'] is Map ? Map<String, dynamic>.from(social!['dress'] as Map) : null;
  List<Map<String, dynamic>>? get premios =>
      social?['premios'] is List ? [for (final x in social!['premios'] as List) Map<String, dynamic>.from(x as Map)] : null;
  String get reglasRobado => '${social?['reglasRobado'] ?? ''}';
  bool get reglasPorDefecto => social?['reglasPorDefecto'] != false;
  List<Map<String, dynamic>> get traer => [for (final x in (raw['traer'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

  /// Quien organiza y lxs encargadxs, con su contacto (solo gente de la liga).
  List<Map<String, dynamic>> get aCargo => [for (final x in (raw['aCargo'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

  Map<String, dynamic>? get homenaje => raw['homenaje'] is Map ? Map<String, dynamic>.from(raw['homenaje'] as Map) : null;
  List<Map<String, dynamic>>? get paraTi => raw['paraTi'] is List ? [for (final x in raw['paraTi'] as List) Map<String, dynamic>.from(x as Map)] : null;

  /// Configuración completa para editar (solo quien organiza).
  Map<String, dynamic>? get editable => raw['editable'] is Map ? Map<String, dynamic>.from(raw['editable'] as Map) : null;
  bool get asiste => yo['asiste'] == true;

  /// +1 que todavía no escribió su nombre.
  bool get necesitaNombre => yo['necesitaNombre'] == true;

  bool modulo(String k) => social?[k] == true;
  bool get sorteado => social?['sorteado'] == true;
  bool get inscripcionAbierta => social?['inscripcionAbierta'] == true;
  DateTime? get cierre => DateTime.tryParse('${social?['cierre'] ?? ''}');
  num? get topeAmigo => social?['topeAmigo'] as num?;
  num? get topeRobado => social?['topeRobado'] as num?;
  String get recordatorioRobado => '${social?['recordatorioRobado'] ?? ''}';

  List<Map<String, dynamic>> get misInvitados => [for (final x in (raw['misInvitados'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
  PerfilSocial get perfil => PerfilSocial.desde(raw['perfil']);
  String get estadoAmigo => '${(raw['amigo'] as Map?)?['estado'] ?? ''}';
  FichaAmigo? get ficha => (raw['amigo'] as Map?)?['ficha'] is Map ? FichaAmigo(Map<String, dynamic>.from((raw['amigo'] as Map)['ficha'] as Map)) : null;
  List<CategoriaComida> get comida => [for (final x in (raw['comida'] as List? ?? const [])) CategoriaComida(Map<String, dynamic>.from(x as Map))];
}

class CategoriaComida {
  CategoriaComida(this.raw);
  final Map<String, dynamic> raw;
  String get id => '${raw['id']}';
  String get nombre => '${raw['nombre']}';
  String get unidad => '${raw['unidad']}';
  num get porPersona => (raw['porPersona'] as num?) ?? 0;
  num get meta => (raw['meta'] as num?) ?? 0;
  num get aportado => (raw['aportado'] as num?) ?? 0;
  bool get cerrada => raw['cerrada'] == true;
  bool get falta => raw['falta'] == true;

  /// 'meta' | 'cada' (cada persona lleva N cosas) | 'total' | 'libre'.
  String get modo => '${raw['modo'] ?? 'meta'}';
  num? get total => raw['total'] as num?;

  /// Lo mío: cosas anotadas (cada/libre) o cantidad (meta/total).
  num get mias => (raw['mias'] as num?) ?? 0;
  bool get porCosa => modo == 'cada' || modo == 'libre';
  List<String> get sugerencias => [for (final x in (raw['sugerencias'] as List? ?? const [])) '$x'];
  double get avance => meta <= 0 ? 0 : (aportado / meta).clamp(0, 1).toDouble();
  List<Map<String, dynamic>> get aportes => [for (final x in (raw['aportes'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}

class ItemDeseo {
  ItemDeseo({required this.texto, this.nota = '', this.link = '', this.favorito = false});
  String texto, nota, link;
  bool favorito;

  factory ItemDeseo.desde(Map m) =>
      ItemDeseo(texto: '${m['texto'] ?? ''}', nota: '${m['nota'] ?? ''}', link: '${m['link'] ?? ''}', favorito: m['favorito'] == true);
  Map<String, Object?> aJson() => {'texto': texto, 'nota': nota, 'link': link, 'favorito': favorito};
}

/// Pistas sobre mí + tallas + wishlist. Quedan guardadas para el año siguiente.
class PerfilSocial {
  PerfilSocial({
    List<String>? gustos,
    List<String>? sobreMi,
    List<String>? noRegalar,
    Map<String, String>? tallas,
    List<ItemDeseo>? wishlist,
    this.wishlistLink = '',
  }) : gustos = gustos ?? [],
       sobreMi = sobreMi ?? [],
       noRegalar = noRegalar ?? [],
       tallas = tallas ?? {},
       wishlist = wishlist ?? [];

  final List<String> gustos, sobreMi, noRegalar;
  final Map<String, String> tallas;
  final List<ItemDeseo> wishlist;

  /// Wishlist externa opcional (Wishdeck, Amazon u otra).
  String wishlistLink;

  static List<String> _l(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];

  factory PerfilSocial.desde(Object? v) {
    final m = v is Map ? v : const {};
    return PerfilSocial(
      gustos: _l(m['gustos']),
      sobreMi: _l(m['sobreMi']),
      noRegalar: _l(m['noRegalar']),
      tallas: {for (final e in ((m['tallas'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
      wishlist: [for (final x in (m['wishlist'] as List? ?? const [])) ItemDeseo.desde(x as Map)],
      wishlistLink: '${m['wishlistLink'] ?? ''}',
    );
  }

  bool get vacio => gustos.isEmpty && sobreMi.isEmpty && noRegalar.isEmpty && tallas.isEmpty && wishlist.isEmpty && wishlistLink.isEmpty;

  Map<String, Object?> aJson() => {
    'gustos': gustos,
    'sobreMi': sobreMi,
    'noRegalar': noRegalar,
    'tallas': tallas,
    'wishlist': [for (final w in wishlist) w.aJson()],
    'wishlistLink': wishlistLink,
  };
}

/// Ficha de la persona que te tocó en el amigo secreto.
class FichaAmigo {
  FichaAmigo(this.raw);
  final Map<String, dynamic> raw;
  String get nombre => '${raw['nombre'] ?? ''}';
  String get foto => '${raw['foto'] ?? ''}';
  String? get invitadxDe => raw['invitadxDe'] as String?;
  PerfilSocial get perfil => PerfilSocial.desde(raw);
}
