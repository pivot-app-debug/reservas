import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/esqueleto.dart';
import '../core/moneda.dart';
import '../core/selector_plazo.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../sesion/sesion.dart';

/// Planes de pago (Victor, 2026-11-16): N meses o N clases con precio
/// propio, para todos, algunos equipos o algunas personas. Quitar un plan lo
/// desactiva: lo ya comprado sigue valiendo.
class PlanesScreen extends StatefulWidget {
  const PlanesScreen({super.key, required this.sesion});
  final Sesion sesion;

  @override
  State<PlanesScreen> createState() => _PlanesScreenState();
}

class _PlanesScreenState extends State<PlanesScreen> {
  List<Map<String, dynamic>>? _planes;
  List<String> _equipos = const [];

  /// Personas de la liga (usuario → nombre), para planes de algunas personas.
  Map<String, String> _gente = const {};
  String? _error;

  Sesion get s => widget.sesion;

  @override
  void initState() {
    super.initState();
    _llamar({'accion': 'listar'});
    s.api.get('getTiers', {'adminToken': s.adminToken}).then((r) {
      if (mounted) setState(() => _equipos = [for (final t in (r['tiers'] as List? ?? const [])) '${(t as Map)['nombre']}']);
    }, onError: (_) {});
    s.api.get('adminGetRosterEquipo', {'adminToken': s.adminToken}).then((r) {
      if (!mounted) return;
      setState(() {
        _gente = {
          for (final x in (r['personas'] as List? ?? const []))
            if (x is Map) '${x['nombre']}': '${(x['nombreDerby'] ?? '').toString().isEmpty ? x['nombre'] : x['nombreDerby']}',
        };
      });
    }, onError: (_) {});
  }

  Future<bool> _llamar(Map<String, Object?> p) async {
    try {
      final r = await s.api.post('adminPlanes', {'adminToken': s.adminToken, ...p});
      if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo guardar.'}');
      if (mounted) {
        setState(
          () => _planes = [
            for (final x in (r['planes'] as List? ?? const []))
              if (x is Map<String, dynamic> && x['activo'] != false) x,
          ],
        );
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      if (_planes == null) {
        setState(() => _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
      }
      return false;
    }
  }

  Future<void> _editar([Map<String, dynamic>? x]) async {
    final ok = await Navigator.of(context).push<Map<String, Object?>>(
      MaterialPageRoute(
        builder: (_) => _EditorPlan(plan: x, equipos: _equipos, gente: _gente),
      ),
    );
    if (ok == null) return;
    if (await _llamar({'accion': 'guardar', 'plan': ok}) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan guardado')));
    }
  }

  Future<void> _quitar(Map<String, dynamic> x) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿Quitar "${x['nombre']}"?'),
        content: const Text('Ya no se podrá comprar. Quien ya lo compró lo sigue usando.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Quitar')),
        ],
      ),
    );
    if (si == true) await _llamar({'accion': 'borrar', 'id': x['id']});
  }

  String _detalle(Map<String, dynamic> x) {
    final n = (x['cantidad'] as num?)?.toInt() ?? 1;
    final precio = (x['precio'] as num?) ?? 0;
    final clases = x['tipo'] == 'clases';
    final para = [...((x['equipos'] as List?) ?? const []), for (final u in ((x['personas'] as List?) ?? const [])) _gente['$u'] ?? '$u'];
    return [
      clases ? '$n ${n == 1 ? 'clase' : 'clases'}' : '$n ${n == 1 ? 'mes' : 'meses'}',
      '${Moneda.s}${precio % 1 == 0 ? precio.toInt() : precio}',
      if (clases) 'vence en ${x['venceMeses']} meses',
      para.isEmpty ? 'para todos' : 'para ${para.join(', ')}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _planes;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Planes de pago', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: l == null
          ? null
          : FloatingActionButton.extended(onPressed: _editar, icon: const Icon(Icons.add_rounded), label: const Text('Nuevo plan')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: l == null
            ? (_error == null ? const Esqueleto(key: ValueKey('c')) : Center(key: const ValueKey('e'), child: Text(_error!)))
            : ListView(
                key: const ValueKey('l'),
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Text(
                    'Paquetes con precio propio: por ejemplo 3 meses con descuento o 10 clases. Se eligen al reservar.',
                    style: TextStyle(fontSize: 15, height: 1.4, color: p.texto),
                  ),
                  const SizedBox(height: 14),
                  if (l.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        'Todavía no hay planes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.textoSecundario),
                      ),
                    ),
                  for (final x in l)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: p.tarjeta,
                        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: Icon(x['tipo'] == 'clases' ? Icons.confirmation_number_outlined : Icons.calendar_month_outlined, color: p.marcaTexto),
                          title: Text('${x['nombre']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(_detalle(x)),
                          onTap: () => _editar(x),
                          trailing: IconButton(tooltip: 'Quitar', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _quitar(x)),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EditorPlan extends StatefulWidget {
  const _EditorPlan({this.plan, required this.equipos, this.gente = const {}});
  final Map<String, dynamic>? plan;
  final List<String> equipos;
  final Map<String, String> gente;

  @override
  State<_EditorPlan> createState() => _EditorPlanState();
}

class _EditorPlanState extends State<_EditorPlan> {
  late final Map<String, dynamic> o = widget.plan ?? const {};
  late final _nombre = TextEditingController(text: '${o['nombre'] ?? ''}');
  late final _precio = TextEditingController(text: o['precio'] == null ? '' : '${o['precio']}');
  late String _tipo = '${o['tipo'] ?? 'meses'}';
  late int _cantidad = (o['cantidad'] as num?)?.toInt() ?? 3, _vence = (o['venceMeses'] as num?)?.toInt() ?? 3;
  late final Set<String> _equipos = {...((o['equipos'] as List?) ?? const []).map((e) => '$e')};
  late final Set<String> _personas = {...((o['personas'] as List?) ?? const []).map((e) => '$e')};

  /// Elegir personas con buscador (Victor, 2026-11-17).
  Future<void> _elegirPersonas() async {
    final sel = {..._personas};
    var q = '';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          final l = widget.gente.entries.where((e) => '${e.value} ${e.key}'.toLowerCase().contains(q.toLowerCase())).toList()
            ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
          return SizedBox(
            height: MediaQuery.sizeOf(c).height * 0.8,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    onChanged: (v) => set(() => q = v),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar persona'),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final e in l)
                        CheckboxListTile(
                          value: sel.contains(e.key),
                          title: Text(e.value),
                          subtitle: e.value == e.key ? null : Text('@${e.key}'),
                          onChanged: (v) => set(() => v == true ? sel.add(e.key) : sel.remove(e.key)),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: () => Navigator.of(c).pop(true), child: Text(sel.isEmpty ? 'Sin personas' : 'Listo (${sel.length})')),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok == true) {
      setState(() {
        _personas
          ..clear()
          ..addAll(sel);
      });
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _precio.dispose();
    super.dispose();
  }

  num? get _monto => num.tryParse(_precio.text.replaceAll(',', '.'));

  String get _ejemplo {
    final m = _monto;
    if (m == null) return 'Escribe el precio para ver cómo queda.';
    final s = '${Moneda.s}${m % 1 == 0 ? m.toInt() : m}';
    if (_tipo == 'clases') {
      return 'Paga $s una vez y tiene $_cantidad ${_cantidad == 1 ? 'clase' : 'clases'} para reservar sin pagar cada una, durante $_vence ${_vence == 1 ? 'mes' : 'meses'} desde que se aprueba el pago.';
    }
    final mes = m / _cantidad;
    return 'Paga $s y quedan pagados $_cantidad ${_cantidad == 1 ? 'mes' : 'meses'} seguidos (${Moneda.s}${mes.toStringAsFixed(2)} por mes, sin recargo).';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final valido = _nombre.text.trim().isNotEmpty && _monto != null;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: Text(widget.plan == null ? 'Nuevo plan' : 'Editar plan', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          TextField(
            controller: _nombre,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Trimestral o Pack de 10 clases'),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'meses', label: Text('Meses')),
              ButtonSegment(value: 'clases', label: Text('Clases')),
            ],
            selected: {_tipo},
            onSelectionChanged: (x) => setState(() {
              _tipo = x.first;
              if (_tipo == 'meses' && _cantidad > 12) _cantidad = 12;
            }),
          ),
          const SizedBox(height: 10),
          SelectorNumero(
            valor: _cantidad,
            min: 1,
            max: _tipo == 'meses' ? 12 : 100,
            etiqueta: _tipo == 'meses' ? (_cantidad == 1 ? 'mes' : 'meses') : (_cantidad == 1 ? 'clase' : 'clases'),
            alCambiar: (v) => setState(() => _cantidad = v.toInt()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _precio,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(labelText: 'Precio total', prefixText: '${Moneda.s} '),
          ),
          if (_tipo == 'clases') ...[
            const SizedBox(height: 14),
            Text(
              'Las clases vencen a los',
              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
            ),
            SelectorNumero(valor: _vence, min: 1, max: 24, etiqueta: _vence == 1 ? 'mes' : 'meses', alCambiar: (v) => setState(() => _vence = v.toInt())),
          ],
          const SizedBox(height: 14),
          Text(
            'Para quién',
            style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
          ),
          const SizedBox(height: 2),
          Text('Sin elegir nada, es para todos. Puedes combinar equipos y personas.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _equipos.isEmpty && _personas.isEmpty,
                onSelected: (_) => setState(() {
                  _equipos.clear();
                  _personas.clear();
                }),
              ),
              for (final e in widget.equipos)
                FilterChip(label: Text(e), selected: _equipos.contains(e), onSelected: (v) => setState(() => v ? _equipos.add(e) : _equipos.remove(e))),
            ],
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_search_rounded),
            title: Text(_personas.isEmpty ? 'Personas específicas' : '${_personas.length} ${_personas.length == 1 ? 'persona' : 'personas'}'),
            subtitle: _personas.isEmpty
                ? const Text('Para darle este plan solo a algunas personas')
                : Text([for (final u in _personas) widget.gente[u] ?? u].join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: widget.gente.isEmpty ? null : _elegirPersonas,
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(_ejemplo),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
              child: Text(_ejemplo, style: TextStyle(height: 1.4, color: p.sobreSuave)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: valido
                ? () => Navigator.of(context).pop(<String, Object?>{
                    'id': o['id'],
                    'nombre': _nombre.text.trim(),
                    'tipo': _tipo,
                    'cantidad': _cantidad,
                    'precio': _monto,
                    'venceMeses': _vence,
                    'equipos': _equipos.toList(),
                    'personas': _personas.toList(),
                  })
                : null,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
