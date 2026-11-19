import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tema.dart';

/// Fondo del inicio de sesión y del asistente de crear liga (QA 2026-11-18):
/// manchas difusas del rojo de la app que se mueven muy despacio y se
/// desvanecen a transparente, así se adapta solo al modo claro u oscuro.
/// Con "reducir movimiento" queda quieto.
class FondoDinamico extends StatefulWidget {
  const FondoDinamico({super.key, required this.child});
  final Widget child;

  @override
  State<FondoDinamico> createState() => _FondoDinamicoState();
}

class _FondoDinamicoState extends State<FondoDinamico> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 36));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _Manchas(t: _c, color: p.marca, intensidad: oscuro ? 0.20 : 0.14),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Manchas extends CustomPainter {
  _Manchas({required this.t, required this.color, required this.intensidad}) : super(repaint: t);
  final Animation<double> t;
  final Color color;
  final double intensidad;

  // Cada mancha: centro base (fracción de la pantalla), recorrido, radio y fase.
  static const _manchas = [(0.15, 0.18, 0.22, 0.65, 0.0), (0.85, 0.40, 0.20, 0.55, 0.33), (0.35, 0.88, 0.25, 0.60, 0.66)];

  @override
  void paint(Canvas canvas, Size size) {
    final lado = math.max(size.width, size.height);
    // La fase sale del reloj (no del controlador): el inicio de sesión y el
    // asistente de crear liga muestran lo mismo y no salta al cambiar de pantalla.
    final ciclo = (DateTime.now().millisecondsSinceEpoch % 36000) / 36000;
    for (final (x, y, recorrido, radio, fase) in _manchas) {
      final a = (ciclo + fase) * 2 * math.pi;
      final c = Offset(size.width * (x + recorrido * math.sin(a)), size.height * (y + recorrido * 0.6 * math.cos(a * 2 + fase)));
      final r = lado * radio * (0.9 + 0.1 * math.sin(a * 3));
      // La intensidad también respira lento: va del rojo a casi transparente.
      final alfa = intensidad * (0.6 + 0.4 * math.sin(a + fase * math.pi));
      final pintura = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alfa),
            color.withValues(alpha: alfa * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawCircle(c, r, pintura);
    }
  }

  @override
  bool shouldRepaint(_Manchas old) => old.color != color || old.intensidad != intensidad || old.t != t;
}
