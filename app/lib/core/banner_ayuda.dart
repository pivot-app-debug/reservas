import 'package:flutter/material.dart';

import 'tema.dart';

/// Banner de explicación arriba de cada sección (Victor, 2026-11-20): qué es,
/// cómo funciona y, si hace falta, un botón para empezar. Se puede colapsar
/// tocando el título y siempre empieza cerrado.
class BannerAyuda extends StatefulWidget {
  const BannerAyuda({super.key, required this.titulo, required this.texto, this.pasos = const [], this.boton, this.clave});
  final String titulo;
  final String texto;
  final List<(IconData, String)> pasos;

  /// Botón opcional al final (ej. "Pagar o reservar").
  final Widget? boton;

  /// Identificador del banner (ya no se recuerda si quedó abierto).
  final String? clave;

  @override
  State<BannerAyuda> createState() => _BannerAyudaState();
}

class _BannerAyudaState extends State<BannerAyuda> {
  // Siempre empieza cerrado (Victor, 2026-11-20), aunque antes lo hayas abierto.
  bool _abierto = false;

  void _alternar() => setState(() => _abierto = !_abierto);

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
            onTap: _alternar,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: p.sobreSuave),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.titulo,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.sobreSuave),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _abierto ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, color: p.sobreSuave),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_abierto
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.texto, style: TextStyle(height: 1.35, color: p.sobreSuave)),
                        for (final (i, t) in widget.pasos)
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
                        if (widget.boton != null) ...[const SizedBox(height: 14), SizedBox(width: double.infinity, child: widget.boton)],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
