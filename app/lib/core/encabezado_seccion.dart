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

/// Ícono en un recuadro con degradado, como en Tareas (Victor, 2026-11-22:
/// el mismo estilo en toda la bandeja).
class IconoRecuadro extends StatelessWidget {
  const IconoRecuadro({super.key, required this.icono, this.seccion = 'organizacion', this.tamano = 56});
  final IconData icono;
  final String seccion;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final (degradado, sobre) = PivotPaleta.seccion(seccion, Theme.of(context).brightness);
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(gradient: degradado, borderRadius: BorderRadius.circular(tamano > 40 ? PivotRadios.tarjeta : PivotRadios.chip + 2)),
      child: Icon(icono, color: sobre, size: tamano * 0.54),
    );
  }
}

/// Recuadro para crear algo (tarea, curso, evento), igual en toda la bandeja.
class TarjetaCrear extends StatelessWidget {
  const TarjetaCrear({
    super.key,
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.alTocar,
    this.seccion = 'organizacion',
  });
  final IconData icono;
  final String titulo, texto, boton, seccion;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 16),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.grande)),
      child: Column(
        children: [
          IconoRecuadro(icono: icono, seccion: seccion),
          const SizedBox(height: 14),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.texto),
          ),
          const SizedBox(height: 4),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textoSecundario),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: alTocar, icon: const Icon(Icons.add_rounded), label: Text(boton)),
        ],
      ),
    );
  }
}
