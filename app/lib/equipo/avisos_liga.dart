import 'package:flutter/foundation.dart';

import '../core/navegacion.dart';
import '../core/vistos.dart';
import '../eventos/eventos_repo.dart';
import '../eventos/modelos.dart';
import '../sesion/sesion.dart';
import 'cosas_para_llevar.dart';
import 'equipo_modelos.dart';
import 'equipo_repo.dart';

/// Avisos de Liga (Victor, 2026-11-22): alguien que se fue de viaje o está
/// lesionadx y no viste, y (Pivots) cosas para llevar hoy o mañana. El punto
/// va en el avatar o el aviso, en su pestaña y en Liga en la barra de abajo.
class AvisosLiga extends ChangeNotifier {
  AvisosLiga._(this.sesion) {
    _equipo.addListener(_recalcular);
    Vistos.instancia.addListener(_recalcular);
    EventosRepo.actual?.addListener(_alCambiarEventos);
    _cargarCosas();
  }

  static AvisosLiga? _uno;
  static AvisosLiga? get actual => _uno;
  static AvisosLiga de(Sesion s) {
    if (_uno?.sesion != s) _uno = AvisosLiga._(s);
    return _uno!;
  }

  final Sesion sesion;
  EquipoRepo get _equipo => EquipoRepo.de(sesion);

  List<(Evento, List<(String, String)>)> cosas = const [];
  DateTime? _cosasEn;

  /// Clave del estado de una persona; null si no hay nada que avisar.
  static String? clave(Integrante p) {
    if (p.deViaje) return 'viaje:${p.username.toLowerCase()}:${p.viajeDesde?.toIso8601String() ?? ''}';
    if (p.lesionadx) return 'lesion:${p.username.toLowerCase()}';
    return null;
  }

  String get claveCosas => 'llevar:${[for (final (e, l) in cosas) '${e.id}-${l.length}'].join(',')}';

  /// Sin punto por viaje o lesión (Victor, 2026-11-22: con la notificación
  /// alcanza); queda solo el de cosas para llevar.
  bool nueva(Integrante p) {
    return false;
  }

  bool get cosasNuevas => cosas.isNotEmpty && !Vistos.instancia.visto(claveCosas);
  bool get personasNuevas => false;
  bool get comunidad => personasNuevas || cosasNuevas;
  bool get inventario => cosasNuevas;

  void verPersona(Integrante p) {
    final c = clave(p);
    if (c != null) Vistos.instancia.marcar([c]);
  }

  void verCosas() {
    if (cosas.isNotEmpty) Vistos.instancia.marcar([claveCosas]);
  }

  void _alCambiarEventos() {
    // Sin pedir de más: como mucho cada 5 minutos.
    if (_cosasEn != null && DateTime.now().difference(_cosasEn!) < const Duration(minutes: 5)) return;
    _cargarCosas();
  }

  Future<void> _cargarCosas() async {
    final ev = EventosRepo.actual;
    if (ev == null || !sesion.esAdmin) return;
    _cosasEn = DateTime.now();
    cosas = await CosasParaLlevar.cargar(ev);
    _recalcular();
  }

  void _recalcular() {
    Navegacion.puntoLiga.value = comunidad;
    notifyListeners();
  }
}
