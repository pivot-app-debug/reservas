import 'social_repo.dart';

/// "Tu parte" en "Qué lleva cada quien" (Victor, 2026-11-20).
///
/// A cada persona le toca lo que come o toma una persona en cada sección de
/// comida (porciones) o bebida (litros). Lo que llevas para todxs se mide en
/// personas que alcanza y compensa entre secciones: con una sola cosa que
/// rinda bastante puedes cubrir el 100 %. Las secciones de cosas (hielo,
/// decoración) y las libres no cuentan.
extension ParteSocial on EstadoSocial {
  int get _personas => ((conteo['total'] as num?) ?? 0).toInt();

  /// Cuánto le toca a una persona en esta sección, en su unidad.
  num refDe(CategoriaComida c) {
    if (c.modo == 'total') return _personas > 0 ? (c.total ?? c.meta) / _personas : 0;
    if (c.porCosa) {
      if (c.limite > 0 && _personas > 0) return (c.limite / _personas).clamp(0.1, 10);
      if (c.meta > 0 && _personas > 0) return (c.meta / _personas).clamp(0.1, 10);
      return 1;
    }
    return c.porPersona > 0 ? c.porPersona : 1;
  }

  /// Secciones que cuentan para tu parte (comida, bebida y cosas que se llevan como vasos o adornos).
  List<CategoriaComida> get seccionesParte => [
    for (final c in comida)
      if (refDe(c) > 0) c,
  ];

  bool cuentaParaParte(CategoriaComida c) => seccionesParte.any((s) => s.id == c.id);

  /// Cuánto de tu parte cubre [cantidad] en [c] (1 = 100 %).
  double parteDe(CategoriaComida c, num cantidad) {
    final n = seccionesParte.length;
    if (n == 0 || !cuentaParaParte(c)) return 0;
    final ref = refDe(c);
    if (ref <= 0) return 0;
    return cantidad / ref / n;
  }

  /// Secciones de comida y bebida específicamente.
  List<CategoriaComida> get seccionesComidaBebida => [
    for (final c in comida)
      if (c.enPorciones || c.liquida) c,
  ];

  /// Si falta cubrir comida o bebida en el evento (para alertar si todxs llevan solo cosas).
  bool get faltaComidaGeneral => seccionesComidaBebida.any((c) => !c.cerrada && (c.falta || (c.meta > 0 && c.aportado < c.meta)));

  /// Qué lleva una persona (Asistencia, Victor 2026-11-21).
  List<String> llevaDe(String usuario) {
    final u = usuario.trim().toLowerCase();
    return [
      for (final c in comida)
        for (final a in c.aportes)
          if ('${a['usuario'] ?? ''}'.trim().toLowerCase() == u) '${a['detalle'] ?? ''}'.isEmpty ? c.nombre : '${a['detalle']}',
    ];
  }

  /// Cuánto de su parte cubrió una persona (para quien organiza).
  double parteDeUsuario(String usuario) {
    final u = usuario.trim().toLowerCase();
    var s = 0.0;
    for (final c in seccionesParte) {
      for (final a in c.aportes) {
        if ('${a['usuario'] ?? ''}'.trim().toLowerCase() == u && a['paraTodxs'] != false) s += parteDe(c, (a['cantidad'] as num?) ?? 0);
      }
    }
    return s;
  }

  /// Lo que ya cubriste con lo que llevas para todxs (1 = 100 %).
  double get miParte {
    var s = 0.0;
    for (final c in seccionesParte) {
      for (final a in c.aportes) {
        if (a['mio'] == true && a['paraTodxs'] != false) s += parteDe(c, (a['cantidad'] as num?) ?? 0);
      }
    }
    return s;
  }
}

/// Lo que suele rendir algo que se lleva a una fiesta.
typedef Rendimiento = ({String texto, num? personas, num? litros});

const _tabla = <(List<String>, String, num?, num?)>[
  (['pollo entero', 'pollo asado', 'pollo horneado', 'pollo al horno', 'pollo'], 'Un pollo entero', 4, null),
  (['pavo'], 'Un pavo', 10, null),
  (['pernil'], 'Un pernil', 15, null),
  (['lasana', 'lasagna'], 'Una bandeja de lasaña', 6, null),
  (['pizza familiar', 'pizza grande'], 'Una pizza grande', 4, null),
  (['pizza mediana'], 'Una pizza mediana', 3, null),
  (['pizza'], 'Una pizza', 3, null),
  (['cheesecake'], 'Un cheesecake', 8, null),
  (['torta', 'pastel', 'cake', 'bizcocho'], 'Una torta', 10, null),
  (['panetone', 'paneton', 'pan de pascua'], 'Un panetón', 6, null),
  (['brownie'], 'Una bandeja de brownies', 8, null),
  (['empanada'], 'Una docena de empanadas', 6, null),
  (['ensalada'], 'Una ensalada grande', 6, null),
  (['papa frita', 'dorito', 'chifl', 'snack', 'nacho'], 'Una funda grande de snacks', 4, null),
  (['galleta'], 'Un paquete de galletas', 4, null),
  (['six pack', 'sixpack'], 'Un six pack', null, 2.1),
  (['cerveza'], 'Una cerveza', null, 0.35),
  (['vino', 'champan', 'champagne', 'espumante'], 'Una botella de vino', null, 0.75),
  (['ron', 'whisky', 'vodka', 'tequila', 'aguardiente', 'pisco', 'gin'], 'Una botella de licor', null, 0.75),
  (['gaseosa', 'cola', 'soda'], 'Una gaseosa grande', null, 3),
  (['jugo'], 'Un jugo', null, 1),
];

const _numeros = {'un': 1, 'una': 1, 'uno': 1, 'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5, 'seis': 6};

String _normal(String s) {
  const de = 'áéíóúüñ', a = 'aeiouun';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = de.indexOf(ch);
    b.write(i >= 0 ? a[i] : (RegExp(r'[a-z0-9.,]').hasMatch(ch) ? ch : ' '));
  }
  // Singular simple, igual para el texto y para la tabla.
  return b
      .toString()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) {
        if (w.length > 3 && w.endsWith('s')) w = w.substring(0, w.length - 1);
        if (w.length > 4 && w.endsWith('e')) w = w.substring(0, w.length - 1);
        return w;
      })
      .join(' ');
}

/// Cuánto suele rendir lo que escribió la persona, o null si no se reconoce.
/// Entiende "2 pollos", "dos pizzas" y litros escritos ("gaseosa 3 litros").
Rendimiento? rendimientoDe(String texto) {
  final crudo = texto.toLowerCase();
  final l = RegExp(r'(\d+(?:[.,]\d+)?)\s*(ml|l|lt|lts|litros?)\b').firstMatch(crudo);
  if (l != null) {
    final v = num.tryParse(l.group(1)!.replaceAll(',', '.'));
    if (v != null && v > 0) return (texto: 'Escribiste ${l.group(0)}', personas: null, litros: l.group(2) == 'ml' ? v / 1000 : v);
  }
  final t = ' ${_normal(texto)} ';
  for (final (claves, nombre, personas, litros) in _tabla) {
    for (final k in claves) {
      final i = t.indexOf(' ${_normal(k)} ');
      if (i < 0) continue;
      final antes = t.substring(0, i).trim().split(' ');
      final veces = int.tryParse(antes.last) ?? _numeros[antes.last] ?? 1;
      return (texto: veces > 1 ? 'Eso' : nombre, personas: personas == null ? null : personas * veces, litros: litros == null ? null : litros * veces);
    }
  }
  return null;
}

/// Cosas de uso personal: solo con estas tiene sentido preguntar "¿Para quién?"
/// (Victor, 2026-11-20). Comida, bebida, servilletas o adornos son para todxs.
bool esDeUsoPersonal(String texto) {
  const claves = ['vaso', 'plato', 'cubierto', 'cuchara', 'tenedor', 'cuchillo', 'taza', 'copa', 'sorbete', 'pajilla', 'popote'];
  final t = ' ${_normal(texto)} ';
  return claves.any((k) => t.contains(' ${_normal(k)}'));
}
