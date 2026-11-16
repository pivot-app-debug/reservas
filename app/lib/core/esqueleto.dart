import 'package:flutter/material.dart';

import 'tema.dart';

/// Esqueletos de carga (Victor, 2026-11-16): en vez del loader en bucle, la
/// forma de lo que va a aparecer, con un brillo suave. Se usan donde se
/// carga una pantalla o una lista; el loader de Pivot queda para el inicio
/// de la app.
enum FormaEsqueleto {
  /// Filas con avatar redondo y dos líneas (personas, eventos, avisos).
  lista,

  /// Grupos de ajustes: ícono cuadrado, título y valor.
  ajustes,

  /// Tarjetas grandes (equipos, resúmenes).
  tarjetas,
}

class Esqueleto extends StatelessWidget {
  const Esqueleto({super.key, this.forma = FormaEsqueleto.lista, this.filas = 6, this.arriba});
  final FormaEsqueleto forma;
  final int filas;

  /// Espacio arriba; sin darlo, el de la barra si el cuerpo pasa por detrás.
  final double? arriba;

  @override
  Widget build(BuildContext context) {
    // Dentro de un cuerpo que pasa por detrás de la barra, padding.top ya
    // incluye la barra; si no, es 0. Sirve para los dos casos.
    final arriba = this.arriba ?? MediaQuery.paddingOf(context).top + 8;
    return Brillo(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, arriba, 16, 16),
        children: switch (forma) {
          FormaEsqueleto.lista => [for (var i = 0; i < filas; i++) _FilaLista(ancho: i.isEven ? 0.62 : 0.45)],
          FormaEsqueleto.ajustes => [
            const _Linea(ancho: 0.3, alto: 12),
            const SizedBox(height: 10),
            _Grupo(filas: (filas / 2).ceil()),
            const SizedBox(height: 20),
            const _Linea(ancho: 0.25, alto: 12),
            const SizedBox(height: 10),
            _Grupo(filas: filas ~/ 2),
          ],
          FormaEsqueleto.tarjetas => [for (var i = 0; i < filas; i++) const _Tarjeta()],
        },
      ),
    );
  }
}

/// Unas filas de carga dentro de una lista o columna (sin desplazarse).
class EsqueletoFilas extends StatelessWidget {
  const EsqueletoFilas({super.key, this.filas = 3});
  final int filas;
  @override
  Widget build(BuildContext context) => Brillo(
    child: Column(children: [for (var i = 0; i < filas; i++) _FilaLista(ancho: i.isEven ? 0.62 : 0.45)]),
  );
}

/// Brillo que recorre los bloques de izquierda a derecha, en bucle.
class Brillo extends StatefulWidget {
  const Brillo({super.key, required this.child});
  final Widget child;

  @override
  State<Brillo> createState() => _BrilloState();
}

class _BrilloState extends State<Brillo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con "reducir animaciones", quieto.
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
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, hijo) {
        final t = _c.value * 2.6 - 0.8;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [p.esqueleto, p.esqueletoBrillo, p.esqueleto],
            stops: [(t - 0.3).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.3).clamp(0.0, 1.0)],
          ).createShader(r),
          child: hijo,
        );
      },
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({this.ancho, required this.alto, this.radio = 6, this.circulo = false});
  final double? ancho;
  final double alto;
  final double radio;
  final bool circulo;

  @override
  Widget build(BuildContext context) => Container(
    width: ancho,
    height: alto,
    decoration: BoxDecoration(
      color: context.pivot.esqueleto,
      shape: circulo ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circulo ? null : BorderRadius.circular(radio),
    ),
  );
}

/// Línea de texto: [ancho] es la parte del ancho disponible (0 a 1).
class _Linea extends StatelessWidget {
  const _Linea({required this.ancho, this.alto = 12});
  final double ancho, alto;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: ancho,
      child: _Bloque(alto: alto),
    ),
  );
}

class _FilaLista extends StatelessWidget {
  const _FilaLista({required this.ancho});
  final double ancho;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        const _Bloque(ancho: 44, alto: 44, circulo: true),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Linea(ancho: ancho, alto: 13),
              const SizedBox(height: 8),
              _Linea(ancho: ancho * 0.6, alto: 11),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.filas});
  final int filas;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      border: Border.all(color: context.pivot.esqueleto),
      borderRadius: BorderRadius.circular(PivotRadios.grande),
    ),
    child: Column(
      children: [
        for (var i = 0; i < filas; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const _Bloque(ancho: 36, alto: 36, radio: 10),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Linea(ancho: i.isEven ? 0.55 : 0.4, alto: 13),
                      const SizedBox(height: 8),
                      _Linea(ancho: i.isEven ? 0.75 : 0.6, alto: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: context.pivot.esqueleto),
      borderRadius: BorderRadius.circular(PivotRadios.grande),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Linea(ancho: 0.45, alto: 16),
        SizedBox(height: 12),
        _Linea(ancho: 0.85),
        SizedBox(height: 8),
        _Linea(ancho: 0.7),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _Bloque(alto: 44, radio: 12)),
            SizedBox(width: 10),
            Expanded(child: _Bloque(alto: 44, radio: 12)),
            SizedBox(width: 10),
            Expanded(child: _Bloque(alto: 44, radio: 12)),
          ],
        ),
      ],
    ),
  );
}
