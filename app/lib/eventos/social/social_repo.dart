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

  Future<void> anotarComida(String categoriaId, num cantidad, String detalle) =>
      _post('socialAnotarComida', {'categoriaId': categoriaId, 'cantidad': cantidad, 'detalle': detalle});

  Future<void> quitarAporte(String id) => _post('socialQuitarAporte', {'id': id});

  Future<Map<String, dynamic>> sortear({bool rehacer = false}) => _post('socialSortear', {'rehacer': rehacer});
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
  bool get asiste => yo['asiste'] == true;

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
  PerfilSocial({List<String>? gustos, List<String>? sobreMi, List<String>? noRegalar, Map<String, String>? tallas, List<ItemDeseo>? wishlist})
    : gustos = gustos ?? [],
      sobreMi = sobreMi ?? [],
      noRegalar = noRegalar ?? [],
      tallas = tallas ?? {},
      wishlist = wishlist ?? [];

  final List<String> gustos, sobreMi, noRegalar;
  final Map<String, String> tallas;
  final List<ItemDeseo> wishlist;

  static List<String> _l(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];

  factory PerfilSocial.desde(Object? v) {
    final m = v is Map ? v : const {};
    return PerfilSocial(
      gustos: _l(m['gustos']),
      sobreMi: _l(m['sobreMi']),
      noRegalar: _l(m['noRegalar']),
      tallas: {for (final e in ((m['tallas'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
      wishlist: [for (final x in (m['wishlist'] as List? ?? const [])) ItemDeseo.desde(x as Map)],
    );
  }

  bool get vacio => gustos.isEmpty && sobreMi.isEmpty && noRegalar.isEmpty && tallas.isEmpty && wishlist.isEmpty;

  Map<String, Object?> aJson() => {
    'gustos': gustos,
    'sobreMi': sobreMi,
    'noRegalar': noRegalar,
    'tallas': tallas,
    'wishlist': [for (final w in wishlist) w.aJson()],
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
