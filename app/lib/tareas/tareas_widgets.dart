import 'package:flutter/material.dart';

import '../ajustes/componentes.dart';
import '../core/tema.dart';
import '../eventos/widgets_comunes.dart' show AvatarPersona;
import 'tareas_modelos.dart';

/// Piezas comunes de las tarjetas de tareas (home, disponibles, recurrentes,
/// archivadas y carrusel): avatares, íconos de áreas y pill de puntos.

class HeroOpcional extends StatelessWidget {
  const HeroOpcional({super.key, required this.tag, required this.child});
  final String? tag;
  final Widget child;

  @override
  Widget build(BuildContext context) => tag == null ? child : Hero(tag: tag!, child: child);
}

/// Pill de puntos. [completo] muestra "3 puntos" (tarjetas de tareas); si no,
/// la versión corta "+3" (timeline).
class PillPuntos extends StatelessWidget {
  const PillPuntos({super.key, required this.puntos, this.completo = false});
  final int puntos;
  final bool completo;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.boton)),
      child: Text(
        puntos == 0 ? 'Sin puntos' : (completo ? textoPuntos(puntos) : '+$puntos'),
        maxLines: 1,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: p.sobreSuave),
      ),
    );
  }
}

/// "+N" en una pill suave, tocable.
class _Mas extends StatelessWidget {
  const _Mas({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.boton)),
      child: Text(
        texto,
        maxLines: 1,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.sobreSuave),
      ),
    );
  }
}

/// Envuelve [child] para que al tocarlo abra la lista completa (sin pisar el
/// toque de la tarjeta).
Widget _tocable(BuildContext context, {required bool activo, required VoidCallback alTocar, required Widget child}) {
  if (!activo) return child;
  return Material(
    type: MaterialType.transparency,
    child: InkWell(
      borderRadius: BorderRadius.circular(PivotRadios.boton),
      onTap: alTocar,
      child: Padding(padding: const EdgeInsets.all(2), child: child),
    ),
  );
}

/// Hasta 3 avatares superpuestos de quienes tienen la tarea + "+N". Tocar el
/// "+N" (o la pila, con [siempreAbre]) muestra la lista completa.
class PilaAvatares extends StatelessWidget {
  const PilaAvatares({super.key, required this.personas, this.tamano = 24, this.siempreAbre = false});
  final List<PersonaTarea> personas;
  final double tamano;
  final bool siempreAbre;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final v = personas.take(3).toList();
    final resto = personas.length - v.length;
    final lado = tamano + 4; // AvatarPersona con borde suma 2 px por lado
    final paso = lado * 0.62;
    final pila = SizedBox(
      width: lado + (v.length - 1) * paso,
      height: lado,
      child: Stack(
        children: [
          for (final (i, x) in v.indexed)
            Positioned(
              left: i * paso,
              child: AvatarPersona(nombre: x.nombreMostrar, foto: x.foto, tamano: tamano, borde: p.tarjeta),
            ),
        ],
      ),
    );
    return _tocable(
      context,
      activo: resto > 0 || siempreAbre,
      alTocar: () => mostrarPersonasTarea(context, personas),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pila,
          if (resto > 0) ...[const SizedBox(width: 4), _Mas(texto: '+$resto')],
        ],
      ),
    );
  }
}

/// Ícono de un área con su degradado.
class IconoArea extends StatelessWidget {
  const IconoArea({super.key, required this.area, this.tamano = 24});
  final AreaTarea area;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final (degradado, sobre) = PivotPaleta.seccion(area.seccion, Theme.of(context).brightness);
    return Semantics(
      label: area.nombre,
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(gradient: degradado, borderRadius: BorderRadius.circular(PivotRadios.chip)),
        child: Icon(area.icono, size: tamano * 0.6, color: sobre),
      ),
    );
  }
}

/// Hasta 3 íconos de áreas + "+N áreas"; al tocar el "+N" se ven todas.
class IconosAreas extends StatelessWidget {
  const IconosAreas({super.key, required this.areas, this.tamano = 24});
  final List<String> areas;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final v = areas.take(3).toList();
    final resto = areas.length - v.length;
    return _tocable(
      context,
      activo: resto > 0,
      alTocar: () => mostrarAreasTarea(context, areas),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, a) in v.indexed) ...[if (i > 0) const SizedBox(width: 4), IconoArea(area: AreaTarea.de(a), tamano: tamano)],
          if (resto > 0) ...[const SizedBox(width: 6), _Mas(texto: resto == 1 ? '+1 área' : '+$resto áreas')],
        ],
      ),
    );
  }
}

/// Ventana con todas las personas de una tarea (y su estado, si lo hay).
Future<void> mostrarPersonasTarea(BuildContext context, List<PersonaTarea> personas) {
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    builder: (c) {
      final p = c.pivot;
      return HojaBase(
        titulo: personas.length == 1 ? '1 persona' : '${personas.length} personas',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final x in personas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    AvatarPersona(nombre: x.nombreMostrar, foto: x.foto, tamano: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            x.nombreMostrar,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.texto),
                          ),
                          if (textoEstadoPersona(x.estado).isNotEmpty)
                            Text(textoEstadoPersona(x.estado), style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Ventana con todas las áreas de una tarea.
Future<void> mostrarAreasTarea(BuildContext context, List<String> areas) {
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    builder: (c) {
      final p = c.pivot;
      return HojaBase(
        titulo: areas.length == 1 ? '1 área' : '${areas.length} áreas',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final a in areas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    IconoArea(area: AreaTarea.de(a), tamano: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        a,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.texto),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Indicador de recurrente pausada: ícono dentro de un círculo rojo de la app.
class CirculoPausa extends StatelessWidget {
  const CirculoPausa({super.key, this.icono = Icons.pause_rounded, this.tamano = 28});
  final IconData icono;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(color: p.marca, shape: BoxShape.circle),
      child: Icon(icono, size: tamano * 0.62, color: p.sobreMarca),
    );
  }
}
