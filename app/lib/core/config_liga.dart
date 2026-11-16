import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../sesion/sesion.dart';
import 'api.dart';
import 'iconos_marca.dart';
import 'pagos.dart';
import 'moneda.dart';

/// Ajustes de la liga (`getConfigLiga`, Victor 2026-11-13): canal para
/// escribir a las personas, cómo se resuelven los pedidos de Pivots, país,
/// zona horaria y precios. Se carga una vez por sesión.
class ConfigLiga extends ChangeNotifier {
  ConfigLiga._(this.sesion);
  final Sesion sesion;
  static ConfigLiga? _instancia;
  static ConfigLiga de(Sesion s) {
    if (_instancia == null || !identical(_instancia!.sesion, s)) _instancia = ConfigLiga._(s)..cargar();
    return _instancia!;
  }

  String canal = 'whatsapp';
  String solicitudesPivots = 'otro';
  String pais = 'EC';
  String zonaHoraria = 'America/Guayaquil';
  String moneda = r'$';
  num? precioPorClase;
  num? precioMensual;
  String logo = '';

  /// Formas de pago (Cobros, Victor 2026-11-13): lista editable de medios
  /// genéricos. Sin configurar, los del club de siempre.
  Map<String, dynamic>? formasPago;
  List<MedioPago> get medios => formasPago == null
      ? MedioPago.porDefecto
      : [
          for (final m in (formasPago!['medios'] as List? ?? const []))
            if (m is Map<String, dynamic>) MedioPago(m),
        ];
  List<MedioPago> get mediosActivos => medios.where((m) => m.activo).toList();

  /// WhatsApp para comprobantes de la liga cargada (o el del club).
  static String get whatsappActual => _instancia?.whatsappComprobante ?? Pagos.whatsapp;
  String get whatsappComprobante => '${formasPago?['whatsapp'] ?? ''}'.isNotEmpty ? '${formasPago!['whatsapp']}' : Pagos.whatsapp;

  /// Reglas que un Pivot cambia en Mi Liga (`reglas_liga`).
  Map<String, dynamic> reglas = const {};
  int get toleranciaMin => (reglas['toleranciaMin'] as num?)?.toInt() ?? 15;
  int get rectificacionDias => (reglas['rectificacionDias'] as num?)?.toInt() ?? 7;
  int get eventosMinPersonas => (reglas['eventosMinPersonas'] as num?)?.toInt() ?? 5;

  int get cuotaVenceDia => (reglas['cuotaVenceDia'] as num?)?.toInt() ?? 0;
  int get cuotaGraciaDias => (reglas['cuotaGraciaDias'] as num?)?.toInt() ?? 0;
  num get cuotaRecargo => (reglas['cuotaRecargo'] as num?) ?? 0;
  bool get recargoPorcentaje => reglas['cuotaRecargoTipo'] == 'porcentaje';
  bool get recargoMensual => reglas['cuotaRecargoModo'] == 'mensual';

  /// Día hasta el que se paga a tiempo (incluido); sin fecha guardada, el 15 (igual que el servidor).
  int get diaFechaLimite => cuotaVenceDia >= 1 && cuotaVenceDia <= 28 ? cuotaVenceDia : 15;

  /// Recompensas por pagar a tiempo (Victor, 2026-11-15). Sin guardar: 1 punto.
  Map<String, dynamic> get recompensaPago {
    final x = reglas['recompensaPago'];
    return x is Map<String, dynamic> ? x : const {'activa': true, 'puntos': 1, 'claseGratis': false, 'saldo': 0};
  }

  bool get rankingVisible => reglas['rankingVisible'] != false;

  /// Tipos de evento que agregó la liga (Mi Liga → Reglas → Tipos de evento).
  List<String> get tiposEventoExtra => [for (final x in (reglas['tiposEventoExtra'] as List? ?? const [])) '$x'];

  /// Lista de siempre + los de la liga, sin repetir.
  List<String> tiposEvento(List<String> base) => [...base, ...tiposEventoExtra.where((t) => !base.contains(t))];

  /// Reparto por defecto de los fondos de viaje: [{min: % asistencia, pct: % del fondo}].
  List<Map<String, dynamic>> get repartoViaje {
    final l = reglas['repartoViaje'];
    if (l is List && l.isNotEmpty) {
      return [
        for (final x in l)
          if (x is Map) Map<String, dynamic>.from(x),
      ];
    }
    return const [
      {'min': 90, 'pct': 50},
      {'min': 35, 'pct': 50},
    ];
  }

  /// Reservas (antes fijas): clases visibles, cierre antes de empezar,
  /// cupón al cancelar y cierre de reservas sin aprobar.
  int get reservaClasesVisibles => (reglas['reservaClasesVisibles'] as num?)?.toInt() ?? 6;
  int get reservaCierraHoras => (reglas['reservaCierraHoras'] as num?)?.toInt() ?? 2;
  int get cuponCancelarMin => (reglas['cuponCancelarMin'] as num?)?.toInt() ?? 60;
  int get sinAprobarHoras => (reglas['sinAprobarHoras'] as num?)?.toInt() ?? 2;

  /// Cobro por equipo (Victor, 2026-11-15), mismo criterio que `_cobroEquipo` del servidor.
  Map<String, dynamic> cobroEquipo(String equipo) {
    final c = (reglas['cobroEquipos'] as Map?)?[equipo];
    if (c is Map && c['modo'] != null) return Map<String, dynamic>.from(c);
    return {'modo': equipo == 'Quindes' || graciaPorEquipo.containsKey(equipo) ? 'mes' : 'segun_equipamiento', 'precioMensual': null, 'precioClase': null};
  }

  /// Clases de gracia por equipo: null = no aplica a ese equipo; 0 = paga antes.
  Map<String, int> get graciaPorEquipo => {
    for (final e in ((reglas['graciaClases'] as Map?) ?? const {'Quindes': 1}).entries) '${e.key}': (e.value as num?)?.toInt() ?? 0,
  };
  int? graciaClases(String equipo) => graciaPorEquipo[equipo];

  /// Salud: opciones de "Dónde te atiendes" y seguros privados (Mi Liga, por país).
  static const atencionPorDefecto = ['MSP (Ministerio de Salud Pública)', 'IESS', 'Seguro Privado'];
  static const segurosPorDefecto = ['Saludsa', 'Ecuasanitas', 'Humana', 'BMI del Ecuador', 'Confiamed', 'BUPA Ecuador', 'Pan American Life', 'CruzBlanca'];
  List<String> get atencionMedica => [for (final x in (reglas['atencionMedica'] as List?) ?? atencionPorDefecto) '$x'];

  /// Teléfono de emergencias de una opción de atención o seguro (si la liga lo puso).
  String? telefonoSalud(String opcion) {
    final t = ((reglas['telefonosSalud'] as Map?) ?? const {})[opcion];
    return t == null || '$t'.trim().isEmpty ? null : '$t'.trim();
  }

  Map<String, String> get telefonosSalud => {for (final e in ((reglas['telefonosSalud'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'};

  List<String> get segurosPrivados => [for (final x in (reglas['segurosPrivados'] as List?) ?? segurosPorDefecto) '$x'];

  /// Días sin venir para verse como inactivx (lo usan Equipo y Calendario).
  static int diasInactividad = 30;
  bool cargado = false;

  void _leer(Map<String, dynamic> r) {
    canal = '${r['canal'] ?? canal}';
    solicitudesPivots = '${r['solicitudesPivots'] ?? solicitudesPivots}';
    pais = '${r['pais'] ?? pais}';
    zonaHoraria = '${r['zonaHoraria'] ?? zonaHoraria}';
    moneda = Moneda.s = '${r['moneda'] ?? moneda}';
    precioPorClase = num.tryParse('${r['precioPorClase']}');
    precioMensual = num.tryParse('${r['precioMensual']}');
    logo = '${r['logo'] ?? ''}';
    formasPago = r['formasPago'] is Map<String, dynamic> ? r['formasPago'] as Map<String, dynamic> : null;
    if (r['reglas'] is Map<String, dynamic>) reglas = r['reglas'] as Map<String, dynamic>;
    diasInactividad = (reglas['inactividadDias'] as num?)?.toInt() ?? 30;
    cargado = true;
    notifyListeners();
  }

  Future<void> cargar() async {
    try {
      final r = await sesion.api.get('getConfigLiga', {if (sesion.adminToken != null) 'adminToken': sesion.adminToken});
      if (r['exito'] != false) _leer(r);
    } catch (_) {}
  }

  /// Guarda reglas de la liga (`adminReglasLiga`). Lanza ApiException si falla.
  Future<void> guardarReglas(Map<String, Object?> cambios) async {
    final r = await sesion.api.post('adminReglasLiga', {'adminToken': sesion.adminToken, 'reglas': jsonEncode(cambios)});
    if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo guardar.'}');
    if (r['reglas'] is Map<String, dynamic>) reglas = r['reglas'] as Map<String, dynamic>;
    diasInactividad = (reglas['inactividadDias'] as num?)?.toInt() ?? 30;
    notifyListeners();
  }

  /// Guarda solo lo que se pasa. Lanza ApiException si falla.
  Future<void> guardar(Map<String, Object?> cambios) async {
    final r = await sesion.api.post('adminGuardarConfigLiga', {'adminToken': sesion.adminToken, ...cambios});
    if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo guardar.'}');
    _leer(r);
  }

  // Sin SMS (Victor, 2026-11-13): si la liga no usa ninguna app, "Solo teléfono" (llamar).
  static const canales = {'whatsapp': 'WhatsApp', 'telegram': 'Telegram', 'signal': 'Signal', 'telefono': 'Solo teléfono'};
  String get nombreCanal => canales[canal] ?? 'WhatsApp';
  String get nombreCanalCorto => canal == 'telefono' ? 'Llamar' : nombreCanal;

  static IconData iconoDe(String c) => switch (c) {
    'telegram' => IconosMarca.telegram,
    'signal' => IconosMarca.signal,
    'telefono' => Icons.call_outlined,
    _ => IconosMarca.whatsapp,
  };
  IconData get icono => iconoDe(canal);

  /// Enlace para escribirle a un número completo ("+593998690423").
  Uri enlace(String telefono, {String texto = ''}) {
    final n = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    final sinMas = n.replaceFirst('+', '');
    final t = Uri.encodeComponent(texto);
    return switch (canal) {
      'telegram' => Uri.parse('https://t.me/+$sinMas'),
      'signal' => Uri.parse('https://signal.me/#p/+$sinMas'),
      'telefono' => Uri.parse('tel:+$sinMas'),
      _ => Uri.parse('https://wa.me/$sinMas${texto.isEmpty ? '' : '?text=$t'}'),
    };
  }

  Future<void> escribir(String telefono, {String texto = ''}) => launchUrl(enlace(telefono, texto: texto), mode: LaunchMode.externalApplication);
}

/// Un medio de pago de la liga (billetera virtual, cuenta bancaria, efectivo,
/// enlace de pago u otro). El `nombre` queda guardado en cada pago.
class MedioPago {
  MedioPago(this.m);
  final Map<String, dynamic> m;
  String get id => '${m['id'] ?? ''}';
  String get nombre => '${m['nombre'] ?? 'Medio de pago'}';
  String get tipo => '${m['tipo'] ?? 'otro'}';
  String get color => '${m['color'] ?? 'gris'}';
  String get logo => '${m['logo'] ?? ''}';
  String get enlace => '${m['enlace'] ?? ''}';
  String get indicaciones => '${m['indicaciones'] ?? ''}';
  String? get cuentaId => m['cuentaId'] as String?;
  bool get activo => m['activo'] != false;
  List<(String, String)> get datos => [
    for (final d in (m['datos'] as List? ?? const []))
      if (d is List && d.length == 2) ('${d[0]}', '${d[1]}'),
  ];

  static const tipos = {
    'billetera': ('Billetera virtual', Icons.account_balance_wallet_outlined),
    'banco': ('Cuenta bancaria', Icons.account_balance_outlined),
    'efectivo': ('Efectivo', Icons.payments_outlined),
    'enlace': ('Enlace de pago', Icons.link_rounded),
    'otro': ('Otro', Icons.more_horiz_rounded),
  };
  IconData get icono => tipos[tipo]?.$2 ?? Icons.payments_outlined;
  String get nombreTipo => tipos[tipo]?.$1 ?? 'Otro';

  /// Los del club antes de configurar nada.
  static final porDefecto = [
    MedioPago({'id': 'deuna', 'nombre': 'Billetera virtual', 'tipo': 'billetera', 'color': 'verde', 'enlace': Pagos.deuna}),
    MedioPago({
      'id': 'transferencia',
      'nombre': Pagos.banco,
      'tipo': 'banco',
      'color': 'azul',
      'datos': [
        for (final (e, v) in Pagos.cuenta) [e, v],
      ],
    }),
  ];
}
