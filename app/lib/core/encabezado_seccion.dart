import 'package:flutter/material.dart';

import 'tema.dart';

/// Título de cada bloque en Novedades y listas parecidas (Victor, 2026-11-20:
/// mismo estilo y jerarquía en todo): ícono, nombre y, si hay, cuántos.
class EncabezadoSeccion extends StatelessWidget {
  const EncabezadoSeccion({super.key, required this.titulo, required this.icono, this.cantidad});
  final String titulo;
  final IconData icono;
  final int? cantidad;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Icon(icono, size: 20, color: p.marcaTexto),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.texto),
            ),
          ),
          if (cantidad != null)
            Text(
              '$cantidad',
              style: TextStyle(fontWeight: FontWeight.w700, color: p.textoSecundario),
            ),
        ],
      ),
    );
  }
}
