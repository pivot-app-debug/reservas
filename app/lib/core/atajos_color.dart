import 'package:flutter/material.dart';

import 'tema.dart';

/// Un atajo de Liga o Entreno (Victor, 2026-11-27, opción B): ícono en un
/// cuadrado de color, nombre y una línea con lo que hay adentro, para saber
/// qué pasa sin entrar.
class AtajoColor {
  const AtajoColor({required this.icono, required this.color, required this.titulo, required this.alTocar, this.detalle, this.punto = false});
  final IconData icono;
  final Color color;
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
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: a.color, borderRadius: BorderRadius.circular(13)),
                  child: Icon(a.icono, color: PivotPaleta.sobreSeccion),
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
                  Expanded(child: tarjeta(atajos[i])),
                  const SizedBox(width: 10),
                  Expanded(child: i + 1 < atajos.length ? tarjeta(atajos[i + 1]) : const SizedBox.shrink()),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
