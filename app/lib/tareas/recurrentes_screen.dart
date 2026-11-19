import 'package:flutter/material.dart';

import '../ajustes/componentes.dart';
import '../core/tema.dart';
import 'tareas_modelos.dart';
import 'tareas_repo.dart';
import 'tareas_widgets.dart';
import '../eventos/widgets_comunes.dart' show TextoDeslizante;

/// Tareas recurrentes (Pivots) como tarjetas que se deslizan de lado dentro
/// de Tareas (Victor, 2026-11-13: no como subsección). Tocar una la edita,
/// pausa, reanuda o termina sin borrar el historial.
class RecurrentesScreen extends StatefulWidget {
  const RecurrentesScreen({super.key, required this.repo, this.inicial});
  final TareasRepo repo;

  /// Ya pedidas al abrir Tareas, para que aparezcan junto con todo (2026-11-17).
  final Future<List<Recurrente>>? inicial;

  @override
  State<RecurrentesScreen> createState() => _RecurrentesScreenState();
}

class _RecurrentesScreenState extends State<RecurrentesScreen> {
  late Future<List<Recurrente>> _f = widget.inicial ?? widget.repo.recurrentes();

  void _recargar() => setState(() => _f = widget.repo.recurrentes());

  Future<void> _hacer(Future<void> Function() accion, String ok) async {
    final hecho = await guardarConAviso(context, accion, ok: ok);
    if (hecho && mounted) _recargar();
  }

  Future<void> _opciones(Recurrente r) async {
    final v = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (c) => HojaBase(
        titulo: r.titulo,
        ayuda: '${r.area} · ${textoPuntos(r.puntos)} · ${r.cupos == 1 ? '1 cupo' : '${r.cupos} cupos'}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(leading: const Icon(Icons.edit_rounded), title: const Text('Editar'), onTap: () => Navigator.pop(c, 'editar')),
            ListTile(
              leading: CirculoPausa(icono: r.pausada ? Icons.play_arrow_rounded : Icons.pause_rounded),
              title: Text(r.pausada ? 'Reanudar' : 'Pausar'),
              // Reanudar sin subtítulo (Victor, QA 2026-11-18).
              subtitle: r.pausada ? null : const Text('Deja de crearse hasta que la reanudes.'),
              onTap: () => Navigator.pop(c, r.pausada ? 'activa' : 'pausada'),
            ),
            ListTile(
              leading: Icon(Icons.stop_circle_outlined, color: context.pivot.marcaTexto),
              title: Text('Terminar', style: TextStyle(color: context.pivot.marcaTexto)),
              subtitle: const Text('La tarea se dará por terminada y no volverá a aparecer'),
              onTap: () => Navigator.pop(c, 'terminada'),
            ),
          ],
        ),
      ),
    );
    if (v == null || !mounted) return;
    if (v == 'editar') return _editar(r);
    if (v == 'terminada') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Terminar la recurrente?'),
          content: const Text('Deja de crearse. Si la que está en curso no la tomó nadie, también se quita.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Terminar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _hacer(() => widget.repo.estadoPlantilla(r.id, v), switch (v) {
      'activa' => 'Recurrente reanudada',
      'pausada' => 'Recurrente pausada',
      _ => 'Recurrente terminada',
    });
  }

  Future<void> _editar(Recurrente r) async {
    final titulo = await editarTexto(
      context,
      titulo: 'Título',
      valor: r.titulo,
      maxLength: maxTituloTarea,
      validar: (v) => v.length < 3 ? 'Escribe al menos 3 caracteres.' : (v.length > maxTituloTarea ? 'Usa hasta $maxTituloTarea caracteres.' : null),
    );
    if (titulo == null || !mounted) return;
    final notas = await editarTexto(context, titulo: 'Detalles', valor: r.notas, lineas: 6, maxLength: 1000);
    if (notas == null || !mounted) return;
    final area = await elegirOpciones(
      context,
      titulo: 'Áreas',
      ayuda: 'Puedes elegir una o varias.',
      multi: true,
      opciones: [for (final a in AreaTarea.lista) a.nombre],
      valor: r.area,
    );
    if (area == null || !mounted) return;
    final puntos = await editarTexto(
      context,
      titulo: 'Puntos',
      valor: '${r.puntos}',
      teclado: TextInputType.number,
      maxLength: 3,
      validar: (v) => int.tryParse(v) == null ? 'Escribe un número.' : null,
    );
    if (puntos == null || !mounted) return;
    final cupos = await editarTexto(
      context,
      titulo: 'Cupos',
      valor: '${r.cupos}',
      teclado: TextInputType.number,
      maxLength: 2,
      validar: (v) => (int.tryParse(v) ?? 0) < 1 ? 'Al menos 1.' : null,
    );
    if (cupos == null || !mounted) return;
    await _hacer(
      () =>
          widget.repo.editarPlantilla(r, titulo: titulo, notas: notas, area: area.isEmpty ? r.area : area, puntos: int.parse(puntos), cupos: int.parse(cupos)),
      'Cambios guardados en esta y las siguientes',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return FutureBuilder<List<Recurrente>>(
      future: _f,
      builder: (context, s) {
        final l = s.data ?? const <Recurrente>[];
        if (s.connectionState != ConnectionState.done || s.hasError || l.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                'RECURRENTES',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: p.textoSecundario),
              ),
            ),
            SizedBox(
              height: 124,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: l.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _tarjeta(l[i]),
              ),
            ),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Widget _tarjeta(Recurrente r) {
    final p = context.pivot;
    return SizedBox(
      width: 230,
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        child: InkWell(
          borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
          onTap: () => _opciones(r),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Pausada: ícono dentro de un círculo rojo (Victor, QA 2026-11-18).
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: r.pausada
                          ? const CirculoPausa(key: ValueKey('pausa'), tamano: 24)
                          : IconosAreas(key: const ValueKey('areas'), areas: r.areas, tamano: 22),
                    ),
                    const Spacer(),
                    PillPuntos(puntos: r.puntos, completo: true),
                  ],
                ),
                const SizedBox(height: 10),
                TextoDeslizante(
                  texto: r.titulo,
                  alineacion: TextAlign.start,
                  estilo: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                ),
                const Spacer(),
                Text(
                  '${r.pausada ? 'Pausada · ' : ''}${r.frecuencia} · ${r.cupos == 1 ? '1 cupo' : '${r.cupos} cupos'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: p.textoSecundario),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
