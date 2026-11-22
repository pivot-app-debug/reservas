import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/encabezado_seccion.dart';

import '../ajustes/herramientas_liga.dart';
import '../core/fechas.dart';
import '../core/tema.dart';
import '../sesion/sesion.dart';
import 'coach_screen.dart' show EvaluarScreen, tituloPendiente;

/// "Vinieron N personas… ¿Las evaluamos?" (Victor, 2026-11-19): salió de la
/// portada de Coach y va en Notificaciones del Calendario. Cada evento se
/// muestra hasta 3 días (hoy y los dos anteriores); después se evalúa desde
/// el detalle del entrenamiento ("Evaluar").
class TarjetasPorEvaluar extends StatefulWidget {
  const TarjetasPorEvaluar({super.key, required this.sesion});
  final Sesion sesion;

  /// Eventos por evaluar de los últimos 3 días (de `getCoach.pendientes`).
  static List<Map<String, dynamic>> vigentes(Map<String, dynamic>? d) {
    final desde = Fechas.iso(Fechas.hoy().subtract(const Duration(days: 2)));
    return [
      for (final x in (d?['pendientes'] as List? ?? const []))
        if (((x as Map)['evaluados'] as num? ?? 0) < (x['total'] as num? ?? 0) && '${x['fecha']}'.compareTo(desde) >= 0) Map<String, dynamic>.from(x),
    ];
  }

  @override
  State<TarjetasPorEvaluar> createState() => _TarjetasPorEvaluarState();
}

class _TarjetasPorEvaluarState extends State<TarjetasPorEvaluar> {
  List<Map<String, dynamic>> _l = const [];
  Sesion get s => widget.sesion;

  /// Las que quitaste con la X (Victor, 2026-11-22): no vuelven a salir.
  static const _pref = 'evaluar.descartados';
  static String _clave(Map<String, dynamic> y) => '${y['id_evento'] ?? y['idEvento'] ?? y['id'] ?? ''}|${y['fecha'] ?? ''}|${y['equipo'] ?? ''}';

  Future<void> _descartar(Map<String, dynamic> y) async {
    setState(
      () => _l = [
        for (final x in _l)
          if (_clave(x) != _clave(y)) x,
      ],
    );
    final pr = await SharedPreferences.getInstance();
    final l = {...?pr.getStringList(_pref), _clave(y)}.toList();
    await pr.setStringList(_pref, l.length > 100 ? l.sublist(l.length - 100) : l);
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!FuncionesLiga.usaCoach(s)) return;
    try {
      final r = await s.api.get('getCoach');
      if (r['exito'] == false || !mounted) return;
      final pr = await SharedPreferences.getInstance();
      final fuera = (pr.getStringList(_pref) ?? const <String>[]).toSet();
      if (!mounted) return;
      setState(
        () => _l = [
          for (final y in TarjetasPorEvaluar.vigentes(r))
            if (!fuera.contains(_clave(y))) y,
        ],
      );
    } catch (_) {}
  }

  Future<void> _evaluar(Map<String, dynamic> y) async {
    await EvaluarScreen.abrir(context, s, y);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _l;
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: l.isEmpty
            ? const SizedBox(key: ValueKey('vacio'), width: double.infinity)
            // Discreta, como el resto de Novedades (Victor, 2026-11-20).
            : Column(
                key: ValueKey(l.length),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EncabezadoSeccion(titulo: 'Por evaluar', icono: Icons.rate_review_outlined, cantidad: l.length),
                  for (final y in l)
                    Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: ListTile(
                        leading: Icon(Icons.groups_outlined, color: p.marcaTexto),
                        title: Text(tituloPendiente(y), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_frase(y)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(onPressed: () => _evaluar(y), child: const Text('Evaluar')),
                            IconButton(
                              tooltip: 'Quitar',
                              icon: Icon(Icons.close_rounded, size: 20, color: p.textoSecundario),
                              onPressed: () => _descartar(y),
                            ),
                          ],
                        ),
                        onTap: () => _evaluar(y),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  static String _frase(Map<String, dynamic> x) {
    final total = (x['total'] as num).toInt();
    final faltan = total - (x['evaluados'] as num? ?? 0).toInt();
    return '${total == 1 ? 'Vino 1 persona' : 'Vinieron $total personas'} de tus equipos${faltan == total ? '' : ' · faltan $faltan'}';
  }
}
