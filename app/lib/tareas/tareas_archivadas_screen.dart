import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/cargando.dart';
import '../core/fechas.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import 'tareas_repo.dart';

/// Tareas archivadas (Pivots, solo lectura): quién las hizo y cómo quedó.
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
                              Text(
                                '${t['titulo']}',
                                style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
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
