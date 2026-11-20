import 'dart:convert';

import '../core/api.dart';
import '../core/fechas.dart';
import '../eventos/anticipada.dart';
import '../sesion/sesion.dart';
import '../core/moneda.dart';
import '../core/periodos_sin_cobro.dart';

/// Fase 3: reservas y pagos desde el "+", con la misma lógica que la web
/// (js/reservas.js: `cargarFechas()`, `actualizarTotalS4()`,
/// `confirmarReserva()`). El servidor pone el precio y aplica solo la clase
/// a favor o el cupón (`guardarReserva`); acá se calcula igual para mostrarlo.
enum TipoReserva { clase, mes }

class FechaClase {
  FechaClase({
    required this.id,
    required this.fecha,
    required this.hora,
    required this.lugar,
    required this.disponible,
    required this.razon,
    required this.tallaAgotada,
  });

  final String id;
  final DateTime? fecha;
  final String hora;
  final String lugar;
  final bool disponible;
  final String razon;

  /// No hay patines de tu talla, pero se puede elegir otra para esa fecha.
  final bool tallaAgotada;

  bool get elegible => disponible || tallaAgotada;
}

class MesReserva {
  const MesReserva(this.mes, {required this.pagado, this.pasado = false, this.sinCobro = false});
  final DateTime mes; // primer día del mes
  final bool pagado;
  final bool pasado; // adeudado de antes del mes actual

  /// Mes sin cobro de su equipo (Victor, 2026-11-20): no se elige ni se paga.
  final bool sinCobro;
}

class Precios {
  const Precios(
    this.porClase,
    this.mensual, {
    this.venceDia = 0,
    this.graciaDias = 0,
    this.recargo = 0,
    this.recargoPorcentaje = false,
    this.recargoMensual = false,
    this.descuentoPct = 0,
    this.factorPorMes = const {},
    this.periodos = const [],
  });

  /// Meses y periodos sin cobro que le tocan (ya filtrados por su equipo; Victor, 2026-11-20).
  final List<PeriodoSinCobro> periodos;

  /// % que se cobra de una clase de esa fecha (100 = precio normal, 0 = no se cobra).
  int pctClase(DateTime? fecha) => PeriodoSinCobro.pctClase(periodos, fecha);

  /// Ese mes no se cobra (ni la cuota ni las clases).
  bool sinCobro(DateTime mes) => PeriodoSinCobro.mesSinCobro(periodos, mes);

  /// La cuota de `mes` baja por un periodo sin cobro (si no, por un descanso).
  bool porPeriodo(DateTime mes) {
    final ini = DateTime(mes.year, mes.month), fin = DateTime(mes.year, mes.month + 1, 0);
    return periodos.any((p) => !p.porMes && p.cuotaProporcional && !p.desde!.isAfter(fin) && !p.hasta!.isBefore(ini));
  }

  /// Avisos para la pantalla de suscribirse: los que no terminaron.
  List<String> get avisos => [
    for (final p in periodos)
      if (!p.terminado) p.aviso,
  ];

  /// Meses con cuota proporcional por un descanso ('aaaa-mm' → fracción de la
  /// mensualidad; Victor, 2026-11-19). Lo calcula el servidor.
  final Map<String, double> factorPorMes;

  /// Mensualidad de `mes`, ya proporcional si un descanso la reduce (sin recargo).
  double mensualDe(DateTime mes) {
    final f = factorPorMes['${mes.year}-${mes.month.toString().padLeft(2, '0')}'];
    return f == null ? mensual : double.parse((mensual * f).toStringAsFixed(2));
  }

  /// Cupón manual de un Pivot: % para el próximo pago (Victor, 2026-11-16).
  final int descuentoPct;
  final double porClase;
  final double mensual;

  /// Vencimiento de la cuota (Mi Liga → Cobros): 0 = no vence.
  final int venceDia;
  final int graciaDias;
  final double recargo;

  /// Recargo en % de la mensualidad (si no, monto fijo) y si se suma otra
  /// vez por cada mes de atraso (Victor, 2026-11-16).
  final bool recargoPorcentaje, recargoMensual;

  /// Recargo si la cuota de `mes` se paga hoy (mismo cálculo que `_recargoCuota` del servidor).
  double recargoPara(DateTime mes, DateTime hoy) {
    if (venceDia <= 0 || recargo <= 0) return 0;
    final ultimo = DateTime(mes.year, mes.month + 1, 0).day;
    final diaLimite = (venceDia + graciaDias).clamp(1, ultimo);
    final limite = DateTime(mes.year, mes.month, diaLimite);
    if (!DateTime(hoy.year, hoy.month, hoy.day).isAfter(limite)) return 0;
    var veces = 1;
    if (recargoMensual) {
      final dif = (hoy.year * 12 + hoy.month) - (mes.year * 12 + mes.month) - (hoy.day <= diaLimite ? 1 : 0);
      veces = 1 + (dif > 0 ? dif : 0);
    }
    final uno = recargoPorcentaje ? mensualDe(mes) * recargo / 100 : recargo;
    return double.parse((uno * veces).toStringAsFixed(2));
  }
}

/// Cómo queda el total con los descuentos (`actualizarTotalS4()`).
class Total {
  const Total({
    required this.cantidad,
    required this.aFavor,
    required this.cupon,
    required this.cobradas,
    required this.monto,
    required this.precio,
    this.recargos = 0,
    this.recargo = 0,
    this.saldo = 0,
    this.descuento = 0,
    this.mensualidades = 0,
    this.proporcional = false,
    this.sinCobro = 0,
  });

  /// Suma de las mensualidades sin recargo y si alguna es proporcional por un
  /// descanso (Victor, 2026-11-19). En clases: suma de las cobradas y si alguna
  /// va con el % de un periodo sin cobro (Victor, 2026-11-20).
  final double mensualidades;
  final bool proporcional;

  /// Clases elegidas que no se cobran por un mes o periodo sin cobro.
  final int sinCobro;

  /// Cupón manual aplicado (monto), en la primera cuota o clase cobrada.
  final double descuento;

  /// Saldo con el equipo aplicado: positivo = a favor usado (descuenta),
  /// negativo = deuda que se paga junto con la cuota (suma).
  final double saldo;

  /// Cuotas con recargo por pagar después del vencimiento y cuánto suman.
  final int recargos;
  final double recargo;
  final int cantidad;
  final int aFavor; // clases a favor por entrenamientos cancelados
  final int cupon; // 0 o 1
  final int cobradas;
  final double monto;
  final double precio;
}

/// Plan de pago (Victor, 2026-11-16): N meses o N clases con precio propio.
class PlanPago {
  PlanPago(Map m)
    : id = '${m['id']}',
      nombre = '${m['nombre'] ?? ''}',
      tipo = '${m['tipo'] ?? 'meses'}',
      cantidad = (m['cantidad'] as num?)?.toInt() ?? 1,
      precio = (m['precio'] as num?)?.toDouble() ?? 0,
      venceMeses = (m['venceMeses'] as num?)?.toInt() ?? 3;
  final String id, nombre, tipo;
  final int cantidad, venceMeses;
  final double precio;
  bool get deClases => tipo == 'clases';
  String get detalle => deClases
      ? '$cantidad ${cantidad == 1 ? 'clase' : 'clases'} por ${ReservasRepo.dinero(precio)} · vence en $venceMeses ${venceMeses == 1 ? 'mes' : 'meses'}'
      : '$cantidad ${cantidad == 1 ? 'mes' : 'meses'} por ${ReservasRepo.dinero(precio)}';
}

class ResultadoReserva {
  const ResultadoReserva({required this.guardados, required this.fallidos, required this.mensajeWhatsapp, this.ids = const []});

  /// Reservas con monto a pagar: a ellas se liga el comprobante.
  final List<String> ids;
  final List<String> guardados;
  final List<String> fallidos;
  final String mensajeWhatsapp;
}

/// Una reserva activa (clase o mes) para "Mis reservas" y "Cancelar o
/// reagendar". `clave` es lo que espera el servidor: el id del evento o el
/// nombre del mes.
class ReservaActiva {
  const ReservaActiva({
    required this.clave,
    required this.mensual,
    required this.estado,
    this.dia,
    this.mes,
    this.hora = '',
    this.lugar = '',
    this.talla = '',
    this.protecciones = '',
    this.id = '',
    this.faltaComprobante = false,
    this.comprobanteLimite,
  });
  final String clave;

  /// Id de la reserva y si falta su comprobante de pago; `comprobanteLimite` =
  /// "Esperando comprobante": hasta cuándo tiene para adjuntarlo (Victor, 2026-11-19).
  final String id;
  final bool faltaComprobante;
  final DateTime? comprobanteLimite;
  final bool mensual;
  final String estado;
  final DateTime? dia; // clase
  final DateTime? mes; // mensual: primer día del mes
  final String hora;
  final String lugar;

  /// Equipamiento del club reservado para esa clase ('' o 'No' = ninguno).
  final String talla, protecciones;
  bool get conPatines => talla.isNotEmpty && talla.toLowerCase() != 'no';
  bool get conProtecciones => protecciones.isNotEmpty && protecciones.toLowerCase() != 'no';

  String get titulo => mensual
      ? 'Suscripción a ${ReglaAnticipada.nombreMes(mes!).toLowerCase()}'
      : dia == null
      ? clave
      : '${Fechas.dia(dia!)[0].toUpperCase()}${Fechas.dia(dia!).substring(1)} ${Fechas.corta(dia!)}';

  String get detalle => mensual ? 'Suscripción mensual' : [if (hora.isNotEmpty) hora, if (lugar.isNotEmpty) lugar].join(' · ');

  /// "Reserva confirmada" / "Clase a favor" / "Reserva pendiente" (web).
  String get textoEstado => estado == 'Confirmada' ? 'Reserva confirmada' : (estado == 'Reagendar' ? 'Clase a favor' : 'Reserva pendiente');

  /// Una clase a favor ya no se cancela ni se reagenda (web: sin botón).
  bool get gestionable => estado != 'Reagendar';

  static ReservaActiva? desde(Map<String, dynamic> r) {
    final estado = (r['estado'] ?? '').toString();
    if (estado == 'Cancelada' || estado == 'Crédito usado') return null;
    final hoy = Fechas.hoy();
    if (r['tipo'] == 'plan' || r['tipo'] == 'curso') return null; // compra de un plan o curso, no una clase
    final id = '${r['id'] ?? ''}';
    final falta = estado == 'Pendiente' && (num.tryParse('${r['monto'] ?? ''}') ?? 0) > 0 && r['comprobante_subido_en'] == null;
    final limite = falta ? DateTime.tryParse('${r['comprobante_limite'] ?? ''}')?.toLocal() : null;
    if (r['tipo'] == 'mensual') {
      final v = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch('${r['validezHasta'] ?? ''}');
      final nombre = (r['fecha'] ?? r['mes_texto'] ?? '').toString();
      if (v == null || nombre.isEmpty) return null;
      final fin = DateTime(int.parse(v[3]!), int.parse(v[2]!), int.parse(v[1]!));
      if (fin.isBefore(hoy)) return null;
      return ReservaActiva(
        clave: nombre,
        mensual: true,
        estado: estado,
        mes: DateTime(fin.year, fin.month),
        id: id,
        faltaComprobante: falta,
        comprobanteLimite: limite,
      );
    }
    final dia = Fechas.desdeIso(r['fechaCalendario']);
    if (dia != null && dia.isBefore(hoy)) return null;
    return ReservaActiva(
      clave: '${r['fecha']}',
      mensual: false,
      estado: estado,
      dia: dia,
      hora: (r['horaInicio'] ?? '').toString(),
      lugar: (r['donde'] ?? '').toString(),
      talla: (r['talla'] ?? '').toString(),
      protecciones: (r['protecciones'] ?? '').toString(),
      id: id,
      faltaComprobante: falta,
      comprobanteLimite: limite,
    );
  }
}

class ReservasRepo {
  ReservasRepo(this.sesion);
  final Sesion sesion;
  Api get _api => sesion.api;

  Map<String, dynamic> get _d => sesion.datos;

  static bool _usa(Object? v) {
    final t = (v ?? '').toString().trim().toLowerCase();
    return t.isNotEmpty && t != 'no';
  }

  bool get necesitaPatines => _usa(_d['necesitaPatines']);
  bool get necesitaProtecciones => _usa(_d['necesitaProtecciones']);
  String get talla => (_d['talla'] ?? '').toString();

  /// Equipamiento solo para esta reserva (Victor, 2026-11-16, como la web
  /// vieja): sin protecciones, solo muñequeras, otra talla… null = el del perfil.
  bool? patinesEsta;
  String? tallaEsta, protecEsta;

  /// Lo que usa de la liga solo para esta reserva {listaId: talla o piezas}
  /// (Victor, 2026-11-17: listas que arma cada liga). null = el del perfil.
  Map<String, String>? equipoEsta;
  bool get _pat => patinesEsta ?? necesitaPatines;
  String get _tal => tallaEsta ?? talla;
  String get _pro => protecEsta ?? (necesitaProtecciones ? (_d['necesitaProtecciones'] ?? '').toString() : 'No');
  bool get cambiadoParaEsta => patinesEsta != null || tallaEsta != null || protecEsta != null || equipoEsta != null;

  /// Equipamiento del club: solo reserva por clase (`canPayMonthly()`).
  bool get necesitaEquipo => necesitaPatines || necesitaProtecciones || _otrasDeLiga > 0;

  /// Cuántas cosas usa de la liga además de patines y protecciones (Victor,
  /// 2026-11-17: listas que arma cada liga).
  int get _otrasDeLiga {
    // Solo para esta reserva: ya viene sin patines ni protecciones.
    if (equipoEsta != null) return equipoEsta!.length;
    final eq = _d['equipoLiga'];
    if (eq is! Map) return 0;
    final sistema = (necesitaPatines ? 1 : 0) + (necesitaProtecciones ? 1 : 0);
    return (eq.length - sistema).clamp(0, 99);
  }

  bool get _exenta {
    final e = _d['exenta_cuota'];
    return e == true || e == 'true' || _d['estado_miembro'] == 'Técnico' || _d['estado_miembro'] == 'Lesionadx';
  }

  String get _categoria => (_d['categoria'] ?? '').toString().toLowerCase();

  /// Qué reservas ofrece el "+" (doc Fase 3, validado por Victor 2026-11-07):
  /// Quindes → por mes; Mirlxs con equipo del club → por clase; Mirlxs con
  /// equipo propio → por clase o por mes. Exentas, Técnico y Lesionadx no pagan.
  /// Con el cobro de su equipo cargado (Mi Liga → Reglas), manda ese.
  List<TipoReserva> get opciones {
    if (_exenta) return const [];
    switch (sesion.modoCobro) {
      case 'mes':
        return const [TipoReserva.mes];
      case 'clase':
        return const [TipoReserva.clase];
      case 'elige':
        return const [TipoReserva.clase, TipoReserva.mes];
      case 'sin_cobro':
        return const [];
      case 'segun_equipamiento':
        return necesitaEquipo ? const [TipoReserva.clase] : const [TipoReserva.clase, TipoReserva.mes];
    }
    if (_categoria == 'quindes') return necesitaEquipo ? const [] : const [TipoReserva.mes];
    if (_categoria == 'mirlxs' || _categoria.isEmpty) {
      return necesitaEquipo ? const [TipoReserva.clase] : const [TipoReserva.clase, TipoReserva.mes];
    }
    return const [];
  }

  /// "Patines talla 38 y protecciones (Rodilleras)" o null con equipo propio.
  String? get resumenEquipo {
    final partes = [
      if (_pat) 'patines talla $_tal',
      if (_usa(_pro)) _pro.toLowerCase() == 'sí' ? 'protecciones completas' : 'protecciones (${_pro.toLowerCase()})',
      if (_otrasDeLiga > 0) _otrasDeLiga == 1 ? 'tu equipamiento de la liga' : 'tus $_otrasDeLiga cosas de la liga',
    ];
    if (partes.isEmpty) return null;
    final t = partes.join(' y ');
    return t[0].toUpperCase() + t.substring(1);
  }

  /// Saldo propio con el equipo (Tesorería), ya descontado lo apartado en reservas pendientes.
  Future<double> miSaldo() async => (await miSaldoDetalle()).saldo;

  /// Saldo y la deuda de clases que pasaron a deuda (se cobra sí o sí en la próxima reserva).
  Future<({double saldo, double deudaClases})> miSaldoDetalle() async {
    try {
      final r = await _api.get('getMiSaldo');
      return (saldo: (r['saldo'] as num?)?.toDouble() ?? 0, deudaClases: (r['deudaClases'] as num?)?.toDouble() ?? 0);
    } catch (_) {
      return (saldo: 0.0, deudaClases: 0.0);
    }
  }

  Future<Precios> precios() async {
    final r = await _api.get('getPreciosClases');
    double n(Object? v) => double.tryParse('${v ?? ''}') ?? 0;
    final c = r['cuota'] is Map ? r['cuota'] as Map : const {};
    return Precios(
      n(r['precioPorClase']),
      n(r['precioMensual']),
      venceDia: (c['venceDia'] as num?)?.toInt() ?? 0,
      graciaDias: (c['graciaDias'] as num?)?.toInt() ?? 0,
      recargo: n(c['recargo']),
      recargoPorcentaje: c['recargoTipo'] == 'porcentaje',
      recargoMensual: c['recargoModo'] == 'mensual',
      descuentoPct: (r['descuentoPct'] as num?)?.toInt() ?? 0,
      factorPorMes: {
        for (final e in ((r['factorPorMes'] as Map?) ?? const {}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toDouble(),
      },
      periodos: PeriodoSinCobro.lista(r['periodosSinCobro']),
    );
  }

  Future<bool> cuponDisponible() async {
    try {
      final r = await _api.get('getCuponDisponible', {'nombre': sesion.nombre});
      return r['cuponDisponible'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Próximos entrenamientos con sus cupos (`getFechasDisponibles`).
  Future<List<FechaClase>> fechas() async {
    final lista = await _api.getLista('getFechasDisponibles', {
      'nombre': sesion.nombre,
      'talla': _pat ? _tal : '',
      'necesitaProtecciones': _pro,
      if (equipoEsta != null) 'equipo': jsonEncode(equipoEsta),
    });
    final agotada = 'sin patines talla $_tal disponibles';
    return [
      for (final f in lista.whereType<Map<String, dynamic>>())
        FechaClase(
          id: '${f['fecha']}',
          fecha: Fechas.desdeIso(f['fechaCalendario']),
          hora: (f['horaInicio'] ?? '').toString(),
          lugar: (f['donde'] ?? '').toString(),
          disponible: f['disponible'] == true,
          razon: (f['razon'] ?? '').toString(),
          tallaAgotada: f['disponible'] != true && _pat && (f['razon'] ?? '').toString().trim().toLowerCase() == agotada,
        ),
    ];
  }

  /// Cambiar la talla o las protecciones de una reserva de clase hecha.
  Future<void> cambiarTalla(ReservaActiva r, String talla) async {
    final res = await _api.post('actualizarTallaReserva', {'nombre': sesion.nombre, 'fecha': r.clave, 'tallaNueva': talla});
    if (res['exito'] == false) throw ApiException('${res['error'] ?? 'No se pudo guardar.'}');
  }

  Future<void> cambiarProtecciones(ReservaActiva r, String protecciones) async {
    final res = await _api.post('actualizarProtecReserva', {'nombre': sesion.nombre, 'fecha': r.clave, 'protecNueva': protecciones});
    if (res['exito'] == false) throw ApiException('${res['error'] ?? 'No se pudo guardar.'}');
  }

  /// Tallas con patines libres para una fecha (`getTallasDisponiblesParaFecha`).
  Future<List<String>> tallasLibres(String idEvento) async {
    final lista = await _api.getLista('getTallasDisponiblesParaFecha', {'fecha': idEvento, 'nombreExcluir': sesion.nombre});
    return [
      for (final t in lista.whereType<Map<String, dynamic>>())
        if ((int.tryParse('${t['disponibles']}') ?? 0) > 0) '${t['talla']}',
    ];
  }

  /// 12 meses desde el actual (más los adeudados de antes, como en la web) y
  /// cuáles ya están pagados o pendientes de revisión.
  List<MesReserva> meses(Cuota c, {Precios? precios}) {
    bool libre(DateTime m) => precios?.sinCobro(m) ?? false;
    final hoy = Fechas.hoy();
    final actual = DateTime(hoy.year, hoy.month);
    final res = <MesReserva>[];
    // Adeudados: desde el mes siguiente a la última cuota hasta el anterior al actual.
    DateTime? ultimo;
    for (final m in [for (var i = -12; i < 0; i++) DateTime(hoy.year, hoy.month + i)]) {
      if (c.mesPagado(m.month, m.year)) ultimo = m;
    }
    if (ultimo != null) {
      for (var m = DateTime(ultimo.year, ultimo.month + 1); m.isBefore(actual); m = DateTime(m.year, m.month + 1)) {
        if (!libre(m)) res.add(MesReserva(m, pagado: false, pasado: true));
      }
    }
    for (var i = 0; i < 12; i++) {
      final m = DateTime(hoy.year, hoy.month + i);
      res.add(MesReserva(m, pagado: c.mesPagado(m.month, m.year), sinCobro: libre(m)));
    }
    return res;
  }

  /// Mes que se preselecciona: el actual, o el siguiente si ya está pagado
  /// (`_evFabReservaMesActual()`), más los adeudados.
  Set<DateTime> preseleccion(List<MesReserva> meses) {
    final sel = {
      for (final m in meses)
        if (m.pasado) m.mes,
    };
    final libre = meses.where((m) => !m.pasado && !m.pagado && !m.sinCobro).firstOrNull;
    if (libre != null) sel.add(libre.mes);
    return sel;
  }

  Total total({
    required TipoReserva tipo,
    required int cantidad,
    required Precios p,
    required int creditos,
    required bool cupon,
    Iterable<DateTime> meses = const [],
    Iterable<DateTime?> fechasClases = const [],
    DateTime? hoy,
    double saldo = 0,
    double deudaObligatoria = 0,
  }) {
    if (tipo == TipoReserva.mes) {
      final h = hoy ?? DateTime.now();
      final rec = [for (final m in meses) p.recargoPara(m, h)].where((r) => r > 0).toList();
      final suma = rec.fold<double>(0, (a, b) => a + b);
      // Cada mes con su mensualidad (proporcional si hay descanso).
      final mensualidades = meses.length == cantidad ? meses.fold<double>(0, (a, m) => a + p.mensualDe(m)) : cantidad * p.mensual;
      final base = mensualidades + suma;
      // Sin elegir usar o pagar el saldo, igual se suma lo que pasó a deuda.
      final primero = meses.isEmpty ? 0.0 : p.mensualDe(meses.first) + p.recargoPara(meses.first, h);
      final desc = cantidad == 0 ? 0.0 : double.parse((primero * p.descuentoPct / 100).toStringAsFixed(2));
      final s = saldo == 0 && deudaObligatoria > 0 ? -deudaObligatoria : saldo;
      final resto = base - desc;
      final aplicado = cantidad == 0 ? 0.0 : (s > 0 ? (s < resto ? s : resto) : s);
      return Total(
        cantidad: cantidad,
        aFavor: 0,
        cupon: 0,
        cobradas: cantidad,
        monto: double.parse((resto - aplicado).toStringAsFixed(2)),
        precio: p.mensual,
        recargos: rec.length,
        recargo: suma,
        saldo: aplicado,
        descuento: desc,
        mensualidades: mensualidades,
        proporcional: meses.any((m) => p.mensualDe(m) != p.mensual),
      );
    }
    // Clases en un mes o periodo sin cobro (Victor, 2026-11-20): las que no se
    // cobran no gastan clases a favor ni el cupón; las demás valen su %.
    final pcts = fechasClases.length == cantidad ? [for (final f in fechasClases) p.pctClase(f)] : List.filled(cantidad, 100);
    final pagables = [
      for (final x in pcts)
        if (x > 0) x,
    ];
    final aFavor = creditos < pagables.length ? creditos : pagables.length;
    final conCupon = cupon && pagables.length > aFavor ? 1 : 0;
    final cobradas = pagables.length - aFavor - conCupon;
    final precioDe = [for (final x in pagables.skip(aFavor + conCupon)) double.parse((p.porClase * x / 100).toStringAsFixed(2))];
    final subtotal = precioDe.fold<double>(0, (a, b) => a + b);
    // Clases que pasaron a deuda: se pagan con la primera clase cobrada.
    final deuda = cobradas > 0 ? deudaObligatoria : 0.0;
    final desc = cobradas > 0 ? double.parse((precioDe.first * p.descuentoPct / 100).toStringAsFixed(2)) : 0.0;
    return Total(
      cantidad: cantidad,
      aFavor: aFavor,
      cupon: conCupon,
      cobradas: cobradas,
      monto: double.parse((subtotal + deuda - desc).toStringAsFixed(2)),
      precio: p.porClase,
      saldo: -deuda,
      descuento: desc,
      sinCobro: cantidad - pagables.length,
      mensualidades: subtotal,
      proporcional: pagables.skip(aFavor + conCupon).any((x) => x < 100),
    );
  }

  static String dinero(double v) => '${Moneda.s}${v.toStringAsFixed(2)}';

  /// Reservas activas (clases que no pasaron y cuotas sin vencer), las más próximas primero.
  static List<ReservaActiva> activas(Cuota c) {
    final lista = [for (final r in c.reservas) ?ReservaActiva.desde(r)];
    lista.sort((a, b) => (a.dia ?? a.mes ?? DateTime(9999)).compareTo(b.dia ?? b.mes ?? DateTime(9999)));
    return lista;
  }

  /// Devuelve true si el cupón volvió a quedar disponible (la reserva lo
  /// usó y se canceló con al menos 1 hora de anticipación).
  Future<bool> cancelar(ReservaActiva r) async {
    final res = await _api.post('cancelarReserva', {'nombre': sesion.nombre, 'fecha': r.clave, if (r.mensual) 'anio': '${r.mes!.year}'});
    if (res['exito'] != true) throw ApiException('${res['error'] ?? 'No se pudo cancelar.'}');
    return res['cuponRestaurado'] == true;
  }

  /// Cambia una clase por otra fecha (id de evento) o un mes por otro.
  Future<void> reagendar(ReservaActiva r, {String? evento, DateTime? mes}) async {
    final res = await _api.post('reagendarReserva', {
      'nombre': sesion.nombre,
      'fechaAnterior': r.clave,
      'fechaNueva': mes != null ? Fechas.mesNombre(mes) : evento,
      if (r.mensual) 'anioAnterior': '${r.mes!.year}',
      if (mes != null) 'anioNuevo': '${mes.year}',
    });
    if (res['exito'] != true) throw ApiException('${res['error'] ?? 'No se pudo cambiar la fecha.'}');
  }

  /// Guarda cada clase o mes (`guardarReserva`), la nota de pago y el
  /// resumen por correo, y marca "Asistiré" en las clases reservadas.
  /// Planes que puede comprar y clases de plan que le quedan.
  Future<({List<PlanPago> planes, int clases, DateTime? vence})> misPlanes() async {
    try {
      final r = await _api.get('getMisPlanes');
      final c = (r['clases'] as Map?) ?? const {};
      return (
        planes: [for (final p in (r['planes'] as List? ?? const [])) PlanPago(p as Map)],
        clases: (c['restantes'] as num?)?.toInt() ?? 0,
        vence: DateTime.tryParse('${c['vence'] ?? ''}'),
      );
    } catch (_) {
      return (planes: <PlanPago>[], clases: 0, vence: null);
    }
  }

  /// Compra de un plan de clases: queda pendiente hasta que un Pivot apruebe el pago.
  Future<ResultadoReserva> comprarPlan(PlanPago p, {String? medio, String? medioNombre}) async {
    try {
      final r = await _api.post('comprarPlan', {'planId': p.id, 'medio': ?medio, 'medioNombre': ?medioNombre});
      if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo guardar'}');
      return ResultadoReserva(
        guardados: ['Plan ${p.nombre}'],
        fallidos: const [],
        mensajeWhatsapp: '',
        ids: [if (r['id'] != null && p.precio > 0) '${r['id']}'],
      );
    } catch (_) {
      return ResultadoReserva(guardados: const [], fallidos: ['Plan ${p.nombre}'], mensajeWhatsapp: '');
    }
  }

  Future<ResultadoReserva> confirmar({
    String? planId,
    required TipoReserva tipo,
    required List<FechaClase> clases,
    required List<DateTime> meses,
    required Map<String, String> tallaPorFecha,
    required Total total,
    Precios? precios,
    String? medio,
    String? medioNombre,
  }) async {
    final tallaBase = _pat ? _tal : 'No';
    final protec = _usa(_pro) ? _pro : 'No';
    final email = (_d['email'] ?? '').toString();
    final guardados = <String>[];
    final ids = <String>[];
    final fallidos = <String>[];
    final etiquetas = <String, String>{};

    if (tipo == TipoReserva.mes) {
      for (final m in meses) {
        final nombre = Fechas.mesNombre(m);
        final etiqueta = ReglaAnticipada.nombreMes(m);
        etiquetas[nombre] = etiqueta;
        try {
          final r = await _api.post('guardarReserva', {
            'nombre': sesion.nombre,
            'fecha': nombre,
            'anio': '${m.year}',
            'talla': tallaBase,
            'protecciones': protec,
            if (equipoEsta != null) 'equipo': jsonEncode(equipoEsta),
            'monto': total.precio.toStringAsFixed(2),
            'email': email,
            'medio': ?medio,
            'medioNombre': ?medioNombre,
            if (total.saldo != 0) 'saldo': total.saldo > 0 ? 'usar' : 'pagar',
            'planId': ?planId,
          });
          if (r['exito'] == false) throw ApiException('${r['mensaje'] ?? r['error'] ?? 'No se pudo guardar'}');
          guardados.add(etiqueta);
          if (r['id'] != null && ((r['monto'] as num?) ?? 0) > 0) ids.add('${r['id']}');
        } catch (_) {
          fallidos.add(etiqueta);
        }
      }
    } else {
      var aFavor = total.aFavor, cupon = total.cupon;
      for (final c in clases) {
        // No se cobra por un mes o periodo sin cobro: no gasta clase a favor ni cupón.
        final sinCobro = (precios?.pctClase(c.fecha) ?? 100) == 0;
        final gratis = !sinCobro && (aFavor > 0 || cupon > 0);
        if (gratis && aFavor > 0) {
          aFavor--;
        } else if (gratis) {
          cupon--;
        }
        final etiqueta = _etiquetaClase(c);
        try {
          final r = await _api.post('guardarReserva', {
            'nombre': sesion.nombre,
            'fecha': c.id,
            'talla': tallaPorFecha[c.id] ?? tallaBase,
            'protecciones': protec,
            if (equipoEsta != null) 'equipo': jsonEncode(equipoEsta),
            'monto': gratis || sinCobro ? '0.00' : total.precio.toStringAsFixed(2),
            'email': email,
            if (!gratis && !sinCobro) 'medio': ?medio,
            if (!gratis && !sinCobro) 'medioNombre': ?medioNombre,
          });
          if (r['exito'] == false) throw ApiException('${r['mensaje'] ?? r['error'] ?? 'No se pudo guardar'}');
          guardados.add(etiqueta);
          if (r['id'] != null && ((r['monto'] as num?) ?? 0) > 0) ids.add('${r['id']}');
          // Como la web cuando se reserva desde Eventos: queda "Asistiré".
          _api.post('marcarAsistenciaUsuario', {'nombre': sesion.nombre, 'idEvento': c.id, 'estado': 'Asistiré'}).catchError((_) => <String, dynamic>{});
        } catch (_) {
          fallidos.add(etiqueta);
        }
      }
    }

    if (guardados.isNotEmpty) {
      // Aviso a admins: pago pendiente de revisión.
      if (total.monto > 0) {
        final n = guardados.length;
        _api
            .post('avisarPagoPendiente', {
              'nombre': sesion.nombre,
              'monto': total.monto.toStringAsFixed(2),
              'detalle': tipo == TipoReserva.mes ? '$n ${n == 1 ? 'mes' : 'meses'}' : '$n ${n == 1 ? 'clase' : 'clases'}',
            })
            .catchError((_) => <String, dynamic>{});
      }
    }

    return ResultadoReserva(guardados: guardados, fallidos: fallidos, mensajeWhatsapp: _mensaje(tipo, guardados, total.monto), ids: ids);
  }

  /// Sube la captura del pago y la liga a esas reservas (Victor, 2026-11-14).
  /// No se guarda copia en el teléfono.
  Future<void> subirComprobante(List<String> ids, List<int> jpeg) async {
    final r = await _api.post('subirComprobante', {'ids': ids.join(','), 'base64Data': 'data:image/jpeg;base64,${base64Encode(jpeg)}'});
    if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo subir.'}');
  }

  static String _etiquetaClase(FechaClase c) {
    final f = c.fecha;
    final dia = f == null ? c.id : '${Fechas.dia(f)[0].toUpperCase()}${Fechas.dia(f).substring(1)} ${Fechas.corta(f)}';
    return [dia, if (c.hora.isNotEmpty) c.hora, if (c.lugar.isNotEmpty) c.lugar].join(' - ');
  }

  static String etiquetaClase(FechaClase c) => _etiquetaClase(c);

  /// Mismo mensaje que la web (`_pagoArmarResumen()`).
  String _mensaje(TipoReserva tipo, List<String> items, double monto) {
    final hoy = Fechas.hoy();
    final equipo = resumenEquipo;
    final linea = equipo == null ? 'Llevaré mi propio equipamiento.' : 'Necesitaré ${equipo[0].toLowerCase()}${equipo.substring(1)}.';
    final bloque = tipo == TipoReserva.mes
        ? '${items.length == 1 ? '*Mes reservado*' : '*Meses reservados*'}\n${items.map((m) => '- $m').join('\n')}'
        : '*Clases reservadas*\n${items.map((m) => '- $m').join('\n')}';
    return '¡Hola! Mi nombre de usuario es *${sesion.nombre}* y acabo de realizar mi pago de *${dinero(monto)}* el día ${hoy.day} de ${Fechas.mes(hoy)} de ${hoy.year}.\n'
        '$bloque\n$linea\n*Mi mail es: ${_d['email'] ?? ''}*\nTe envío el comprobante adjunto. Si no lo ves, por favor solicítalo. ¡Gracias!';
  }
}
