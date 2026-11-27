import 'package:flutter/material.dart';

import 'tema.dart';

/// Un atajo de Liga o Entreno (Victor, 2026-11-27, opción B): ícono en un
/// recuadro con el degradado de su sección (los rojos, vinos y rosas de la
/// app, `PivotPaleta.seccion`), nombre y una línea con lo que hay adentro,
/// para saber qué pasa sin entrar. Íconos de Material Symbols redondeados y
/// llenos, como los de la bandeja.
class AtajoColor {
  const AtajoColor({required this.icono, required this.seccion, required this.titulo, required this.alTocar, this.detalle, this.punto = false});
  final IconData icono;

  /// Clave de `PivotPaleta.seccion` (da el degradado y el color del ícono).
  final String seccion;
  final String titulo;

  /// Lo que hay adentro ("2 préstamos", "$1.848 en cuentas"). Null: cargando.
  final String? detalle;
  final bool punto;
  final VoidCallback alTocar;
}

/// Grilla de 2 columnas con los atajos.
class GrillaAtajos extends StatelessWidget {
  const GrillaAtajos({super.key, required this.atajos});
  final List<AtajoColor> atajos;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final brillo = Theme.of(context).brightness;
    Widget tarjeta(AtajoColor a) => Material(
      color: p.tarjeta,
      borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: a.alTocar,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Badge(
                isLabelVisible: a.punto,
                smallSize: 10,
                backgroundColor: p.marca,
                child: Builder(
                  builder: (context) {
                    final (degradado, sobre) = PivotPaleta.seccion(a.seccion, brillo);
                    return Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(gradient: degradado, borderRadius: BorderRadius.circular(PivotRadios.chip + 2)),
                      child: Icon(a.icono, color: sobre, fill: 1, weight: 500, size: 24),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      a.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: p.texto),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        a.detalle ?? ' ',
                        key: ValueKey(a.detalle),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, height: 1.25, color: p.textoSecundario),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < atajos.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Si queda una sola, ocupa todo el ancho.
                  Expanded(child: tarjeta(atajos[i])),
                  if (i + 1 < atajos.length) ...[const SizedBox(width: 10), Expanded(child: tarjeta(atajos[i + 1]))],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
