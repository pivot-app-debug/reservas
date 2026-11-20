import 'package:flutter/material.dart';

import 'tema.dart';

/// Banner de explicación arriba de cada sección de Actividad (Victor,
/// 2026-11-20): qué es, cómo funciona y, si hace falta, un botón para empezar.
/// Mismo estilo que "¿Qué es un curso?".
class BannerAyuda extends StatelessWidget {
  const BannerAyuda({super.key, required this.titulo, required this.texto, this.pasos = const [], this.boton});
  final String titulo;
  final String texto;
  final List<(IconData, String)> pasos;

  /// Botón opcional al final (ej. "Pagar o reservar").
  final Widget? boton;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.sobreSuave),
          ),
          const SizedBox(height: 4),
          Text(texto, style: TextStyle(height: 1.35, color: p.sobreSuave)),
          for (final (i, t) in pasos)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(i, size: 18, color: p.sobreSuave),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t, style: TextStyle(height: 1.35, color: p.sobreSuave)),
                  ),
                ],
              ),
            ),
          if (boton != null) ...[const SizedBox(height: 14), SizedBox(width: double.infinity, child: boton)],
        ],
      ),
    );
  }
}
