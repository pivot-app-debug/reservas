import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/cargando.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../equipo/equipo_repo.dart';
import '../eventos/widgets_comunes.dart';

/// Personas archivadas por un Pivot (web "Usuarios"): se pueden restaurar.
/// Quien borró su propia cuenta no aparece como restaurable.
class ArchivadasScreen extends StatefulWidget {
  const ArchivadasScreen({super.key, required this.repo});
  final EquipoRepo repo;

  @override
  State<ArchivadasScreen> createState() => _ArchivadasScreenState();
}

class _ArchivadasScreenState extends State<ArchivadasScreen> {
  List<Map<String, dynamic>>? _l;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final l = await widget.repo.archivadas();
      if (mounted) setState(() => _l = l);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
    }
  }

  Future<void> _restaurar(Map<String, dynamic> x) async {
    final m = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿Restaurar a ${x['nombreDerby']}?'),
        content: const Text('Vuelve a aparecer en Equipo con su historial.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repo.restaurar('${x['nombre']}');
      m.showSnackBar(SnackBar(content: Text('${x['nombreDerby']} volvió al equipo')));
      await _cargar();
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo restaurar.')));
    }
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
        title: const Text('Personas archivadas', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: l == null
            ? Center(key: const ValueKey('c'), child: _error == null ? const PivotCargando(centrarEnPantalla: true) : Text(_error!))
            : ListView(
                key: const ValueKey('l'),
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 32),
                children: [
                  Text('Quienes salieron de Equipo. Su historial se conserva.', style: TextStyle(color: p.textoSecundario)),
                  const SizedBox(height: 8),
                  if (l.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text('No hay personas archivadas.', style: TextStyle(color: p.textoSecundario)),
                    ),
                  for (final x in l)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AvatarPersona(nombre: '${x['nombreDerby']}', tamano: 40),
                      title: Text('${x['nombreDerby']}'),
                      subtitle: Text(x['eliminadoPor'] == 'admin' ? 'Archivadx por un Pivot' : 'Borró su cuenta'),
                      trailing: x['eliminadoPor'] == 'admin' ? TextButton(onPressed: () => _restaurar(x), child: const Text('Restaurar')) : null,
                    ),
                ],
              ),
      ),
    );
  }
}
