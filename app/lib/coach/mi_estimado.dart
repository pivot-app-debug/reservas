import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../finanzas/tesoreria_repo.dart' show plata;
import '../sesion/sesion.dart';

/// Lo que lleva cada entrenadorx este mes (Victor, 2026-11-26): el servidor ya
/// lo calculaba con la regla de Pago a entrenadorxs; aquí solo lo suyo. Si la
/// liga no usa la regla, no se muestra nada.
class MiEstimado extends StatefulWidget {
  const MiEstimado({super.key, required this.sesion});
  final Sesion sesion;

  @override
  State<MiEstimado> createState() => _MiEstimadoState();
}

class _MiEstimadoState extends State<MiEstimado> {
  Map<String, dynamic>? _r;

  @override
  void initState() {
    super.initState();
    widget.sesion.api.get('getMiPagoCoach').then((r) {
      if (mounted && r['exito'] != false) setState(() => _r = r);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final r = _r;
    final e = r?['estimado'] is Map ? Map<String, dynamic>.from(r!['estimado'] as Map) : null;
    final ver = r != null && r['activa'] == true;
    final monto = (e?['monto'] as num?) ?? 0;
    final horario = (e?['horario'] as num?)?.toInt() ?? 0, tarde = (e?['tarde'] as num?)?.toInt() ?? 0;
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !ver
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Material(
                color: p.suave,
                borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.savings_outlined, color: p.sobreSuave),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Como entrenadorx, este mes llevas ${plata(monto)}',
                              style: TextStyle(fontWeight: FontWeight.w800, color: p.sobreSuave),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              // Con contexto (Victor, 2026-11-27): de dónde sale el número.
                              'Es tu parte de lo que la liga cobra este mes, según la regla de Pago a entrenadorxs: '
                              '${horario == 1 ? '1 entrenamiento a horario' : '$horario entrenamientos a horario'}'
                              '${tarde > 0 ? (tarde == 1 ? ' y 1 con retraso' : ' y $tarde con retraso') : ''}. '
                              'Es un estimado: cambia con los pagos que entren hasta fin de mes.',
                              style: TextStyle(fontSize: 12.5, height: 1.3, color: p.sobreSuave),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
