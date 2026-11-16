import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';

/// Salud y seguros de la liga (Victor, 2026-11-14): pantalla propia en vez
/// de hoja inferior. Dos listas con nombre y teléfono de emergencias; el
/// teléfono aparece en la ficha de emergencia de quien elige esa opción.
class SaludLigaScreen extends StatefulWidget {
  const SaludLigaScreen({super.key, required this.config});
  final ConfigLiga config;

  @override
  State<SaludLigaScreen> createState() => _SaludLigaScreenState();
}

class _SaludLigaScreenState extends State<SaludLigaScreen> {
  static const _fija = 'Seguro Privado'; // abre la lista de seguros privados
  late final _atencion = [...widget.config.atencionMedica];
  late final _seguros = [...widget.config.segurosPrivados];
  late final _tels = {...widget.config.telefonosSalud};
  bool _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await widget.config.guardarReglas({'atencionMedica': _atencion, 'segurosPrivados': _seguros, 'telefonosSalud': _tels});
      m.showSnackBar(const SnackBar(content: Text('Guardado')));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Agregar (`actual` null) o editar una opción: nombre y teléfono.
  Future<void> _editar(List<String> lista, {String? actual}) async {
    final nombre = TextEditingController(text: actual ?? '');
    final tel = TextEditingController(text: actual == null ? '' : (_tels[actual] ?? ''));
    final fija = actual == _fija;
    final r = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (h) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(h).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(actual == null ? 'Nueva opción' : 'Editar opción', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(
                controller: nombre,
                enabled: !fija,
                autofocus: actual == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Nombre', helperText: fija ? 'Esta opción abre la lista de seguros privados.' : null),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tel,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono de emergencias (opcional)', hintText: 'Ej.: 911'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (actual != null && !fija) TextButton(onPressed: () => Navigator.of(h).pop('\u0000quitar'), child: const Text('Quitar')),
                  const Spacer(),
                  FilledButton(onPressed: () => Navigator.of(h).pop(nombre.text.trim()), child: const Text('Listo')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      if (r == '\u0000quitar') {
        lista.remove(actual);
        _tels.remove(actual);
        return;
      }
      final n = fija ? _fija : r;
      if (n.isEmpty) return;
      if (actual == null) {
        if (lista.contains(n)) return;
        lista.add(n);
      } else if (n != actual) {
        if (lista.contains(n)) return;
        lista[lista.indexOf(actual)] = n;
        _tels.remove(actual);
      }
      final t = tel.text.trim();
      t.isEmpty ? _tels.remove(n) : _tels[n] = t;
    });
    await _guardar();
  }

  Widget _seccion(BuildContext context, String titulo, String ayuda, List<String> lista, IconData icono) {
    final p = context.pivot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 0, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                ),
              ),
              TextButton.icon(onPressed: () => _editar(lista), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Agregar')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(ayuda, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
        ),
        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Sin opciones todavía.', style: TextStyle(color: p.textoSecundario)),
          ),
        for (final x in lista)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: p.tarjeta,
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.contador)),
                  child: Icon(icono, size: 20, color: p.marcaTexto),
                ),
                title: Text(x, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: _tels[x] == null
                    ? Text('Sin teléfono de emergencias', style: TextStyle(color: p.textoSecundario))
                    : Row(
                        children: [
                          Icon(Icons.phone_rounded, size: 14, color: p.marcaTexto),
                          const SizedBox(width: 4),
                          Text(
                            _tels[x]!,
                            style: TextStyle(fontWeight: FontWeight.w700, color: p.marcaTexto),
                          ),
                        ],
                      ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editar(lista, actual: x),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Salud y seguros', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: _guardando ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          _seccion(context, 'SISTEMAS DE ATENCIÓN', 'Salud pública o seguridad social del país.', _atencion, Icons.local_hospital_outlined),
          _seccion(context, 'SEGUROS PRIVADOS', 'Aparecen cuando alguien elige "Seguro Privado".', _seguros, Icons.shield_outlined),
          const SizedBox(height: 8),
          Text('Quitar una opción no cambia lo que ya eligió cada persona.', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
        ],
      ),
    );
  }
}
