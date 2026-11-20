import 'fechas.dart';

/// Meses y periodos sin cobro (Victor, 2026-11-20), en `reglas_liga.periodosSinCobro`.
/// Mismo criterio que el servidor (`_periodosSinCobro`, `_pctClaseEn`, `_factorCuotaMes`):
/// - por mes: ese mes no se cobra la cuota ni las clases sueltas, y se marca
///   Asistiré sin suscripción;
/// - por periodo: las clases sueltas de esas fechas valen [clasesPct] % (0 = no
///   se cobran) y, con la cuota proporcional, cada entrenamiento del mes dentro
///   del periodo pesa ese mismo % en la cuota.
/// [equipos] vacío = toda la liga. Rige desde que se crea; lo ya pagado no cambia.
class PeriodoSinCobro {
  const PeriodoSinCobro({
    required this.id,
    required this.porMes,
    this.meses = const [],
    this.desde,
    this.hasta,
    this.clasesPct = 0,
    this.cuotaProporcional = true,
    this.equipos = const [],
  });

  final String id;
  final bool porMes;

  /// Primer día de cada mes elegido (solo [porMes]).
  final List<DateTime> meses;
  final DateTime? desde, hasta;
  final int clasesPct;
  final bool cuotaProporcional;
  final List<String> equipos;

  static PeriodoSinCobro? desdeMapa(Object? x) {
    if (x is! Map) return null;
    final equipos = [for (final e in (x['equipos'] as List? ?? const [])) '$e'];
    if (x['tipo'] == 'mes') {
      final meses = <DateTime>[
        for (final m in (x['meses'] as List? ?? const []))
          if (RegExp(r'^\d{4}-\d{2}$').hasMatch('$m')) DateTime(int.parse('$m'.substring(0, 4)), int.parse('$m'.substring(5, 7))),
      ]..sort();
      if (meses.isEmpty) return null;
      return PeriodoSinCobro(id: '${x['id'] ?? ''}', porMes: true, meses: meses, equipos: equipos);
    }
    final d = Fechas.desdeIso(x['desde']), h = Fechas.desdeIso(x['hasta']);
    if (x['tipo'] != 'periodo' || d == null || h == null) return null;
    return PeriodoSinCobro(
      id: '${x['id'] ?? ''}',
      porMes: false,
      desde: d,
      hasta: h,
      clasesPct: (x['clasesPct'] as num?)?.toInt() ?? 0,
      cuotaProporcional: x['cuota'] != 'entera',
      equipos: equipos,
    );
  }

  static List<PeriodoSinCobro> lista(Object? l) => [for (final x in (l is List ? l : const [])) ?desdeMapa(x)];

  static String claveMes(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

  Map<String, Object?> aMapa() => {
    if (id.isNotEmpty) 'id': id,
    'tipo': porMes ? 'mes' : 'periodo',
    if (porMes) 'meses': [for (final m in meses) claveMes(m)],
    if (!porMes) ...{'desde': Fechas.iso(desde!), 'hasta': Fechas.iso(hasta!), 'clasesPct': clasesPct, 'cuota': cuotaProporcional ? 'proporcional' : 'entera'},
    'equipos': equipos,
  };

  bool aplicaA(String? equipo) => equipos.isEmpty || equipos.contains(equipo ?? '');

  bool incluyeMes(DateTime mes) => porMes && meses.any((m) => m.year == mes.year && m.month == mes.month);

  bool incluyeDia(DateTime d) {
    if (porMes) return incluyeMes(d);
    final x = Fechas.soloDia(d);
    return !x.isBefore(desde!) && !x.isAfter(hasta!);
  }

  /// Ya terminó: queda como historial y no se edita.
  bool get terminado {
    final hoy = Fechas.hoy();
    return porMes ? meses.every((m) => m.year * 12 + m.month < hoy.year * 12 + hoy.month) : hasta!.isBefore(hoy);
  }

  static String fechaCorta(DateTime d) => '${d.day}/${d.month}${d.year != Fechas.hoy().year ? '/${d.year}' : ''}';

  static String _unir(List<String> l) => l.length <= 1 ? l.join() : '${l.sublist(0, l.length - 1).join(', ')} y ${l.last}';

  /// "Diciembre" / "Diciembre y enero" / "Del 19/11 al 15/12".
  String get titulo => porMes
      ? _unir([for (final (i, m) in meses.indexed) i == 0 ? Fechas.mesNombre(m) : Fechas.mes(m)]) +
            (meses.any((m) => m.year != Fechas.hoy().year) ? ' ${meses.last.year}' : '')
      : 'Del ${fechaCorta(desde!)} al ${fechaCorta(hasta!)}';

  /// Qué pasa con el dinero, en una línea.
  String get detalle => porMes
      ? 'No se cobra la cuota ni las clases sueltas; se puede marcar Asistiré sin suscripción'
      : '${clasesPct == 0 ? 'Las clases no se cobran' : 'Las clases se cobran al $clasesPct %'}; '
            '${cuotaProporcional ? 'la cuota mensual es proporcional' : 'la cuota mensual no cambia'}';

  /// Aviso para quien se suscribe: "Diciembre no se cobra", "Del 19/11 al 15/12 las clases no se cobran".
  String get aviso => porMes
      ? '$titulo no se ${meses.length == 1 ? 'cobra' : 'cobran'}.'
      : '$titulo las clases ${clasesPct == 0 ? 'no se cobran' : 'se cobran al $clasesPct %'}'
            '${cuotaProporcional ? ' y la cuota mensual baja en proporción' : ''}.';

  /// % que se cobra de una clase de esa fecha con estos periodos (100 = normal).
  /// Sin [equipo], la lista ya viene filtrada (la del servidor para quien pregunta).
  static int pctClase(List<PeriodoSinCobro> l, DateTime? fecha, {String? equipo}) {
    if (fecha == null) return 100;
    var pct = 100;
    for (final p in l) {
      if ((equipo != null && !p.aplicaA(equipo)) || !p.incluyeDia(fecha)) continue;
      final v = p.porMes ? 0 : p.clasesPct;
      if (v < pct) pct = v;
    }
    return pct;
  }

  /// El mes no se cobra (cuota ni clases) con estos periodos.
  static bool mesSinCobro(List<PeriodoSinCobro> l, DateTime mes, {String? equipo}) => l.any((p) => (equipo == null || p.aplicaA(equipo)) && p.incluyeMes(mes));
}
