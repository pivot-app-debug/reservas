import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Detalle animado de los eventos especiales (Victor, 2026-11-21 y 22): luces
/// en Navidad, fuegos artificiales en Año Nuevo, un huevo que salta en
/// Pascua, la luna en Halloween, confeti en cumpleaños y fiestas, y cielo con
/// estrellas y estrellas fugaces en el offseason. Si el evento ya pasó, la
/// animación queda congelada (`animada: false`).
class DecoFiesta extends StatefulWidget {
  const DecoFiesta({super.key, required this.clave, this.animada = true, this.fuerte = false});

  /// Sobre un fondo festivo fuerte: colores claros que se vean.
  final bool fuerte;

  /// 'navidad' | 'anio_nuevo' | 'pascua' | 'halloween' | 'cumple' | 'offseason';
  /// cualquier otra fiesta lleva confeti.
  final String clave;
  final bool animada;

  @override
  State<DecoFiesta> createState() => _DecoFiestaState();
}

class _DecoFiestaState extends State<DecoFiesta> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.clave == 'offseason' ? 6 : 4),
    value: 0.37,
  );

  void _ajustar() {
    if (widget.animada && !_c.isAnimating) _c.repeat();
    if (!widget.animada && _c.isAnimating) _c.stop();
  }

  @override
  void initState() {
    super.initState();
    _ajustar();
  }

  @override
  void didUpdateWidget(DecoFiesta old) {
    super.didUpdateWidget(old);
    _ajustar();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    if (MediaQuery.disableAnimationsOf(context)) _c.stop();
    final clave = widget.clave;
    return RepaintBoundary(
      child: switch (clave) {
        'pascua' || 'halloween' => AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = _c.value;
            final salto = clave == 'pascua' ? -(math.sin(t * math.pi * 4).abs()) * 10 : math.sin(t * math.pi * 2) * 4;
            return Align(
              alignment: const Alignment(0.92, 0.85),
              child: Transform.translate(
                offset: Offset(0, salto),
                child: Icon(
                  clave == 'pascua' ? Icons.egg_rounded : Icons.dark_mode_rounded,
                  size: 26,
                  color: (widget.fuerte ? PivotPaleta.confetiFuerte[0] : p.marca).withValues(alpha: widget.fuerte ? 0.55 : 0.35),
                ),
              ),
            );
          },
        ),
        _ => CustomPaint(
          painter: _Pintor(_c, clave, widget.fuerte ? PivotPaleta.confetiFuerte.take(3).toList() : [p.marca, p.marcaTexto, p.sobreSuave], widget.fuerte),
        ),
      },
    );
  }
}

class _Pintor extends CustomPainter {
  _Pintor(this.reloj, this.clave, this.colores, this.fuerte) : super(repaint: reloj);
  final Animation<double> reloj;
  final bool fuerte;
  final String clave;
  final List<Color> colores;

  static double _azar(int i, int k) => ((math.sin(i * 12.9898 + k * 78.233) * 43758.5453) % 1 + 1) % 1;

  @override
  void paint(Canvas canvas, Size size) {
    final t = reloj.value;
    switch (clave) {
      case 'navidad':
        const n = 9;
        final cable = Paint()
          ..color = colores[2].withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        final camino = Path()..moveTo(0, 4);
        for (var i = 0; i <= n; i++) {
          final x = size.width * i / n;
          camino.quadraticBezierTo(x - size.width / n / 2, 12, x, 4);
        }
        canvas.drawPath(camino, cable);
        for (var i = 0; i < n; i++) {
          final x = size.width * (i + 0.5) / n;
          final brillo = 0.35 + 0.65 * ((math.sin((t * 2 + i / 3) * math.pi * 2) + 1) / 2);
          canvas.drawCircle(Offset(x, 10), 3.2, Paint()..color = colores[i % colores.length].withValues(alpha: brillo * 0.8));
        }
      case 'anio_nuevo':
        for (final (i, c) in [(0, Offset(size.width * 0.86, size.height * 0.3)), (1, Offset(size.width * 0.72, size.height * 0.62))]) {
          final f = (t + i * 0.5) % 1;
          final r = 6 + f * 22;
          final pintura = Paint()..color = colores[i].withValues(alpha: (1 - f) * 0.55);
          for (var k = 0; k < 10; k++) {
            final a = k / 10 * math.pi * 2;
            canvas.drawCircle(c + Offset(math.cos(a) * r, math.sin(a) * r), 1.8, pintura);
          }
        }
      case 'offseason':
        // Estrellas que titilan y, de vez en cuando, una estrella fugaz.
        for (var i = 0; i < 22; i++) {
          final x = _azar(i, 1) * size.width, y = _azar(i, 2) * size.height;
          final brillo = 0.25 + 0.75 * ((math.sin((t * 3 + _azar(i, 3)) * math.pi * 2) + 1) / 2);
          canvas.drawCircle(Offset(x, y), 0.8 + _azar(i, 4) * 1.2, Paint()..color = PivotPaleta.estrella.withValues(alpha: brillo * 0.9));
        }
        // Estrella fugaz (Victor, 2026-11-22: la anterior saltaba): una por
        // vuelta, entra y sale con suavidad y la cola crece y se achica.
        const dura = 0.22, empieza = 0.55;
        final f = (t - empieza) / dura;
        if (f > 0 && f < 1) {
          final k = Curves.easeInOut.transform(f);
          final opacidad = math.sin(f * math.pi);
          final cabeza = Offset(size.width * (0.2 + 0.55 * k), size.height * (0.12 + 0.35 * k));
          final largo = 18 + 26 * math.sin(f * math.pi);
          final dir = const Offset(0.84, 0.54);
          final cola = cabeza - dir * largo;
          canvas.drawLine(
            cola,
            cabeza,
            Paint()
              ..shader = LinearGradient(
                colors: [
                  PivotPaleta.estrella.withValues(alpha: 0),
                  PivotPaleta.estrella.withValues(alpha: 0.8 * opacidad),
                ],
              ).createShader(Rect.fromPoints(cola, cabeza))
              ..strokeWidth = 1.4
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawCircle(cabeza, 1.6, Paint()..color = PivotPaleta.estrella.withValues(alpha: 0.9 * opacidad));
        }
      default:
        // Confeti que cae (cumpleaños y fiestas en general).
        for (var i = 0; i < 18; i++) {
          final y = ((_azar(i, 1) + t) % 1) * (size.height + 12) - 6;
          final x = _azar(i, 2) * size.width + math.sin((t * 2 + _azar(i, 3)) * math.pi * 2) * 6;
          final pintura = Paint()
            ..color = (fuerte ? PivotPaleta.confetiFuerte : PivotPaleta.confeti)[i % PivotPaleta.confeti.length].withValues(alpha: fuerte ? 0.9 : 0.55);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate((t * 4 + _azar(i, 4)) * math.pi * 2);
          canvas.drawRect(const Rect.fromLTWH(-2.5, -1.5, 5, 3), pintura);
          canvas.restore();
        }
    }
  }

  @override
  bool shouldRepaint(_Pintor old) => old.clave != clave || old.fuerte != fuerte;
}
