import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/tema.dart';
import 'aviso_web.dart';
import 'push.dart';

/// Versión web (Victor, 2026-11-15): en iPhone el permiso de avisos solo se
/// puede pedir con un toque, así que se muestra esta tarjeta mientras no
/// estén activados. En Android (app) no aparece.
class TarjetaActivarAvisos extends StatefulWidget {
  const TarjetaActivarAvisos({super.key, required this.api});
  final Api api;

  @override
  State<TarjetaActivarAvisos> createState() => _TarjetaActivarAvisosState();
}

class _TarjetaActivarAvisosState extends State<TarjetaActivarAvisos> {
  late String _permiso = kIsWeb ? permisoAvisosWeb() : 'granted';
  bool _pidiendo = false;

  Future<void> _activar() async {
    setState(() => _pidiendo = true);
    final r = await pedirPermisoAvisosWeb();
    if (r == 'granted') await Push.registrar(widget.api);
    if (mounted) {
      setState(() {
        _permiso = r;
        _pidiendo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final ocultar = _permiso == 'granted';
    final String texto;
    if (_permiso == 'unsupported') {
      texto = esIosWeb()
          ? 'Para recibir avisos en iPhone, agrega Pivot a tu pantalla de inicio (Compartir → Agregar a inicio) y ábrela desde ahí.'
          : 'Este navegador no permite avisos. Prueba con Chrome, Edge o Firefox.';
    } else if (_permiso == 'denied') {
      texto = 'Los avisos están bloqueados en este navegador. Actívalos en los permisos del sitio.';
    } else {
      texto = 'Activa los avisos para enterarte de entrenamientos, pagos y novedades.';
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: ocultar
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, color: p.sobreSuave),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(texto, style: TextStyle(height: 1.35, color: p.sobreSuave)),
                    ),
                    if (_permiso == 'default') ...[
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _pidiendo ? null : _activar, child: const Text('Activar')),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
