import 'package:flutter/material.dart';

import 'tema.dart';

/// Logo de un equipo de fondo en una tarjeta (Victor, 2026-11-16): a la
/// derecha, con un fundido suave hacia la izquierda, para que se note de
/// qué equipo es sin ocupar espacio. Sin logo, solo el contenido.
class FondoLogo extends StatelessWidget {
  const FondoLogo({super.key, required this.url, required this.child, this.opacidad = 0.22, this.ancho = 0.55});
  final String? url;
  final Widget child;
  final double opacidad;

  /// Parte de la tarjeta que ocupa el logo, desde la derecha.
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final u = url ?? '';
    if (u.isEmpty) return child;
    final p = context.pivot;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: ancho,
                heightFactor: 1,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      p.texto.withValues(alpha: opacidad),
                      p.texto.withValues(alpha: 0),
                    ],
                  ).createShader(r),
                  child: Image.network(u, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
