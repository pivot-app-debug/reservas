import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/cargando.dart';
import '../core/fechas.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import 'tareas_repo.dart';

/// Tareas archivadas (Pivots): quién las hizo y cómo quedó. Se pueden
/// borrar como último recurso; eso quita los puntos que dieron.
class TareasArchivadasScreen extends StatefulWidget {
  const TareasArchivadasScreen({super.key, required this.repo});
  final TareasRepo repo;

  @override
  State<TareasArchivadasScreen> createState() => _TareasArchivadasScreenState();
}

class _TareasArchivadasScreenState extends State<TareasArchivadasScreen> {
  List<Map<String, dynamic>>? _l;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.repo
        .archivadas()
        .then((l) {
          if (mounted) setState(() => _l = l);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
        });
  }

  Future<void> _eliminar(Map<String, dynamic> t) async {
    final p = context.pivot;
    final aprobadas = (t['personas'] as List? ?? const []).where((x) => x is Map && x['estado'] == 'aprobada').length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar esta tarea?'),
        content: Text(
          aprobadas == 0
              ? 'Será como si nunca hubiera existido. No se puede deshacer.'
              : 'Será como si nunca hubiera existido: se quitarán los ${t['puntos'] ?? 0} puntos a ${aprobadas == 1 ? 'la persona que la hizo' : 'las $aprobadas personas que la hicieron'}. No se puede deshacer. Si solo quieres que no se vea, déjala archivada.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Borrar', style: TextStyle(color: p.marcaTexto)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    try {
      await widget.repo.eliminarArchivada(t['idTarea'] as Object);
      if (mounted) setState(() => _l = [...?_l]..remove(t));
      m.showSnackBar(const SnackBar(content: Text('Tarea borrada.')));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo borrar. Revisa tu conexión.')));
    }
  }

  String _fecha(Object? iso) {
    final d = DateTime.tryParse('${iso ?? ''}');
    return d == null ? '' : Fechas.corta(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _l;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Tareas archivadas', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: l == null
            ? Center(key: const ValueKey('c'), child: _error == null ? const PivotCargando(centrarEnPantalla: true) : Text(_error!))
            : ListView(
                key: const ValueKey('l'),
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 32),
                children: [
                  if (l.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text('No hay tareas archivadas.', style: TextStyle(color: p.textoSecundario)),
                    ),
                  for (final t in l)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: p.tarjeta,
                        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${t['titulo']}',
                                      style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Borrar',
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(Icons.delete_outline_rounded, color: p.textoSecundario),
                                    onPressed: () => _eliminar(t),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  '${t['puntos'] ?? 0} pts',
                                  if (_fecha(t['fechaArchivado']).isNotEmpty) 'archivada el ${_fecha(t['fechaArchivado'])}',
                                ].join(' · '),
                                style: TextStyle(fontSize: 13, color: p.textoSecundario),
                              ),
                              for (final x in (t['personas'] as List? ?? const []))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${('${(x as Map)['nombreDerby'] ?? ''}').isEmpty ? x['nombre'] : x['nombreDerby']}: ${x['estado'] == 'aprobada' ? 'aprobada' : x['estado']}',
                                    style: TextStyle(fontSize: 13, color: p.texto),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
