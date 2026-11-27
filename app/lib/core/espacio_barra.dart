import 'package:flutter/material.dart';

/// Subsecciones dentro de una pestaña (Victor, 2026-11-22: en la ficha de
/// emergencia lo último quedaba tapado por la barra de abajo y parecía que no
/// se podía bajar más). La barra de vidrio va encima del contenido; en la
/// pantalla principal de cada pestaña eso está bien, pero en las que se abren
/// encima el final de la lista quedaba debajo. Aquí esas pantallas terminan
/// justo arriba de la barra.
class EspacioBarraAbajo extends StatelessWidget {
  const EspacioBarraAbajo({super.key, this.route, required this.child});

  /// Sin route, la de la pantalla (para rutas propias con PageRouteBuilder).
  final ModalRoute<dynamic>? route;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = route ?? ModalRoute.of(context);
    if (r == null || r.isFirst) return child;
    final raiz = Navigator.maybeOf(context, rootNavigator: true);
    if (raiz == null || r.navigator == raiz) return child;
    // Siempre el mismo árbol (Padding + removePadding), aunque el alto sea 0:
    // con el teclado abierto el alto pasa a 0 y, si aquí se devolvía `child`
    // solo, la pantalla se volvía a crear y perdía su estado (bug, Victor
    // 2026-11-27: un medio de pago nuevo no se guardaba).
    final abajo = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: abajo),
      child: MediaQuery.removePadding(context: context, removeBottom: true, child: child),
    );
  }
}

/// La transición de siempre, con [EspacioBarraAbajo] para cada pantalla.
class TransicionConBarra extends PageTransitionsBuilder {
  const TransicionConBarra(this.base);
  final PageTransitionsBuilder base;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      base.buildTransitions(route, context, animation, secondaryAnimation, EspacioBarraAbajo(route: route, child: child));
}
