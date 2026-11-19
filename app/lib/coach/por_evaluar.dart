import 'package:flutter/material.dart';

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
      setState(() => _l = TarjetasPorEvaluar.vigentes(r));
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
            : Padding(
                key: ValueKey(l.length),
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.grande)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            tituloPendiente(l.first),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.sobreSuave),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _frase(l.first),
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.25, color: p.sobreSuave),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(onPressed: () => _evaluar(l.first), icon: const Icon(Icons.rate_review_rounded), label: const Text('Evaluar')),
                        ],
                      ),
                    ),
                    for (final y in l.skip(1))
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: const Icon(Icons.history_rounded),
                        title: Text(tituloPendiente(y)),
                        subtitle: Text('${(y['total'] as num).toInt() - (y['evaluados'] as num? ?? 0).toInt()} sin evaluar'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _evaluar(y),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  static String _frase(Map<String, dynamic> x) {
    final total = (x['total'] as num).toInt();
    final faltan = total - (x['evaluados'] as num? ?? 0).toInt();
    return '${total == 1 ? 'Vino 1 persona' : 'Vinieron $total personas'} de tus equipos. ${faltan == total ? (total == 1 ? '¿La evaluamos?' : '¿Las evaluamos?') : 'Faltan $faltan por evaluar.'}';
  }
}
