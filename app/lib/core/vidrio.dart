import 'dart:ui';

import 'package:flutter/material.dart';

import 'tema.dart';

/// Fondo de vidrio para barras: desenfoca lo que pasa por detrás.
class Vidrio extends StatefulWidget {
  const Vidrio({super.key, required this.child, this.abajo = false});
  final Widget child;

  /// Barra inferior (hoy se ve igual que las de arriba).
  final bool abajo;

  @override
  State<Vidrio> createState() => _VidrioState();
}

/// En reposo la barra de arriba es del color de la página, sin desenfoque
/// (Victor, 2026-11-16: el desenfoque tomaba el color de la tarjeta de abajo
/// y unas barras se veían rojizas y otras blancas). El vidrio aparece recién
/// cuando el contenido pasa por detrás.
class _VidrioState extends State<Vidrio> {
  ScrollNotificationObserverState? _obs;
  bool _debajo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.abajo) return;
    final o = ScrollNotificationObserver.maybeOf(context);
    if (o == _obs) return;
    _obs?.removeListener(_alScroll);
    _obs = o?..addListener(_alScroll);
  }

  void _alScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return;
    final d = n.metrics.extentBefore > 0.5;
    if (d != _debajo) setState(() => _debajo = d);
  }

  @override
  void dispose() {
    _obs?.removeListener(_alScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    // Todas las barras iguales (Victor, 2026-11-13 arriba y 2026-11-14
    // abajo): solo el desenfoque con el fondo translúcido, sin tinte,
    // degradado, reflejo ni borde.
    final vidrio = widget.abajo || _obs == null || _debajo;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        layoutBuilder: (actual, previos) => Stack(fit: StackFit.passthrough, children: [...previos, ?actual]),
        child: vidrio
            ? BackdropFilter(
                key: const ValueKey('v'),
                filter: ImageFilter.blur(sigmaX: PivotVidrio.desenfoque, sigmaY: PivotVidrio.desenfoque, tileMode: TileMode.mirror),
                child: ColoredBox(color: PivotVidrio.plano(p), child: widget.child),
              )
            : ColoredBox(key: const ValueKey('p'), color: p.fondo, child: widget.child),
      ),
    );
  }
}

/// Alto de la barra superior de vidrio (estado + toolbar) para dejar ese
/// espacio arriba del contenido cuando el cuerpo pasa por detrás
/// (`extendBodyBehindAppBar`). Se calcula con un `context` de fuera del
/// Scaffold (Victor, 2026-11-14: barras de vidrio en toda la app).
// Con `viewPadding` da lo mismo desde fuera o desde dentro del Scaffold
// (dentro, `padding.top` ya incluye la barra y quedaba un hueco: Victor,
// 2026-11-16, espacio en blanco en Reglas).
double altoBarra(BuildContext context) => MediaQuery.viewPaddingOf(context).top + kToolbarHeight;
