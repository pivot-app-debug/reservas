import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../ajustes/componentes.dart';
import '../core/api.dart';
import '../core/esqueleto.dart';
import '../core/fechas.dart';
import '../core/pronombres.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../eventos/eventos_repo.dart';
import '../eventos/modelos.dart';
import '../eventos/widgets_comunes.dart';
import '../sesion/sesion.dart';

/// Sección Coach (Victor, 2026-11-16): sus jugadorxs con su ficha deportiva
/// (habilidades de WFTDA editables y notas escritas o dictadas) y el
/// cronograma de lo que se ve en cada evento del calendario. Sin datos de
/// salud: solo el estado que ve el equipo.

AppBar _barra(String titulo, {List<Widget>? acciones, PreferredSizeWidget? abajo}) => AppBar(
  backgroundColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  flexibleSpace: const Vidrio(child: SizedBox.expand()),
  title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
  actions: acciones,
  bottom: abajo,
);

String _error(Object e) => e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.';

// ─── Pestaña Coach ─────────────────────────────────────────────────────────

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, required this.sesion, required this.eventos});
  final Sesion sesion;
  final EventosRepo eventos;
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  Map<String, dynamic>? _d;
  String? _error_;
  String _vista = 'jugadorxs';
  String _q = '';
  Sesion get s => widget.sesion;

  @override
  void initState() {
    super.initState();
    _cargar();
    widget.eventos.cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await s.api.get('getCoach');
      if (r['exito'] == false) throw ApiException('${r['error']}');
      if (mounted) setState(() => _d = r);
    } catch (e) {
      if (mounted) setState(() => _error_ = _error(e));
    }
  }

  List<Map<String, dynamic>> get _jugadorxs => [for (final x in (_d?['jugadorxs'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
  Map<String, Map<String, dynamic>> get _planes => {
    for (final x in (_d?['planes'] as List? ?? const [])) '${(x as Map)['id_evento']}': Map<String, dynamic>.from(x),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _barra(
        'Coach',
        acciones: [
          IconButton(
            tooltip: 'Lista de habilidades',
            icon: const Icon(Icons.checklist_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabilidadesScreen(sesion: s))),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _d == null
            ? (_error_ == null ? const Esqueleto(key: ValueKey('c')) : Center(key: const ValueKey('e'), child: Text(_error_!)))
            : ListView(
                key: const ValueKey('l'),
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 32 + MediaQuery.paddingOf(context).bottom),
                children: [
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'jugadorxs', icon: Icon(Icons.groups_rounded), label: Text('Jugadorxs')),
                      ButtonSegment(value: 'cronograma', icon: Icon(Icons.view_timeline_outlined), label: Text('Cronograma')),
                    ],
                    selected: {_vista},
                    onSelectionChanged: (v) => setState(() => _vista = v.first),
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _vista == 'jugadorxs'
                        ? KeyedSubtree(key: const ValueKey('j'), child: _listaJugadorxs(context))
                        : KeyedSubtree(key: const ValueKey('k'), child: _cronograma(context)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _listaJugadorxs(BuildContext context) {
    final p = context.pivot;
    final total = (_d?['totalHabilidades'] as num?)?.toInt() ?? 0;
    final q = _q.trim().toLowerCase();
    final l = _jugadorxs.where((x) => q.isEmpty || '${x['nombre']} ${x['username']}'.toLowerCase().contains(q)).toList();
    final equipos = [for (final e in (_d?['equipos'] as List? ?? const [])) '$e'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(equipos.isEmpty ? 'Todos los equipos' : equipos.join(' · '), style: TextStyle(fontSize: 13, color: p.textoSecundario)),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar jugadorx'),
        ),
        const SizedBox(height: 8),
        if (l.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text('No hay jugadorxs en tus equipos.', style: TextStyle(color: p.textoSecundario)),
            ),
          ),
        for (final x in l)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AvatarPersona(nombre: '${x['nombre']}', foto: '${x['foto'] ?? ''}', tamano: 44),
            title: Text('${x['nombre']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              [
                '${x['equipo']}',
                if ('${x['estado']}' != 'Activx') conPronombres('${x['estado']}', x['pronombres']),
                '${x['asistencias30']} ${x['asistencias30'] == 1 ? 'asistencia' : 'asistencias'} en 30 días',
                if (total > 0) '${x['logradas']} de $total habilidades',
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FichaDeportivaScreen(sesion: s, username: '${x['username']}', nombre: '${x['nombre']}'),
                ),
              );
              _cargar();
            },
          ),
      ],
    );
  }

  Widget _cronograma(BuildContext context) {
    final p = context.pivot;
    final hoy = Fechas.hoy();
    final hasta = hoy.add(const Duration(days: 45));
    final evs = [
      for (final e in widget.eventos.eventos)
        if (!e.cancelado && !e.fecha.isBefore(hoy) && e.fecha.isBefore(hasta)) e,
    ]..sort((a, b) => '${Fechas.iso(a.fecha)} ${a.horaInicio}'.compareTo('${Fechas.iso(b.fecha)} ${b.horaInicio}'));
    final planes = _planes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elige qué se ve en cada evento del calendario. Puedes compartirlo para que el equipo lo vea en el evento.',
          style: TextStyle(fontSize: 14, height: 1.35, color: p.texto),
        ),
        const SizedBox(height: 10),
        if (evs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text('No hay eventos en las próximas semanas.', style: TextStyle(color: p.textoSecundario)),
            ),
          ),
        for (final e in evs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: p.tarjeta,
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(
                  planes.containsKey(e.id) ? Icons.assignment_turned_in_outlined : Icons.assignment_outlined,
                  color: planes.containsKey(e.id) ? p.marcaTexto : p.textoSecundario,
                ),
                title: Text('${Fechas.dia(e.fecha)} ${Fechas.corta(e.fecha)} · ${e.horaInicio}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([e.tipo, e.lugar, _resumenPlan(planes[e.id])].where((x) => x.isNotEmpty).join(' · ')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final ok = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => PlanEventoScreen(sesion: s, evento: e, plan: planes[e.id], otros: planes.values.toList()),
                    ),
                  );
                  if (ok == true) _cargar();
                },
              ),
            ),
          ),
      ],
    );
  }

  static String _resumenPlan(Map<String, dynamic>? x) {
    if (x == null) return 'Sin plan';
    final b = (x['bloques'] as List? ?? const []);
    final min = b.fold<int>(0, (a, y) => a + ((y as Map)['minutos'] as num? ?? 0).toInt());
    return '${b.length} ${b.length == 1 ? 'bloque' : 'bloques'}${min > 0 ? ' · $min min' : ''}${x['compartido'] == true ? ' · compartido' : ''}';
  }
}

// ─── Cronograma: plan de un evento ─────────────────────────────────────────

class PlanEventoScreen extends StatefulWidget {
  const PlanEventoScreen({super.key, required this.sesion, required this.evento, this.plan, this.otros = const []});
  final Sesion sesion;
  final Evento evento;
  final Map<String, dynamic>? plan;
  final List<Map<String, dynamic>> otros;
  @override
  State<PlanEventoScreen> createState() => _PlanEventoScreenState();
}

class _PlanEventoScreenState extends State<PlanEventoScreen> {
  late final List<Map<String, dynamic>> _bloques = [for (final b in (widget.plan?['bloques'] as List? ?? const [])) Map<String, dynamic>.from(b as Map)];
  late bool _compartido = widget.plan?['compartido'] == true;
  bool _guardando = false;

  Future<void> _bloque([int? i]) async {
    final b = i == null ? null : _bloques[i];
    final titulo = TextEditingController(text: '${b?['titulo'] ?? ''}');
    final detalle = TextEditingController(text: '${b?['detalle'] ?? ''}');
    var minutos = (b?['minutos'] as num?)?.toInt() ?? 15;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(c).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i == null ? 'Nuevo bloque' : 'Editar bloque', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: titulo,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Qué se hace', hintText: 'Ej. Calentamiento, frenos, scrimmage'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detalle,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Detalle (opcional)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('Duración')),
                  IconButton(onPressed: minutos <= 5 ? null : () => set(() => minutos -= 5), icon: const Icon(Icons.remove_rounded)),
                  Text('$minutos min', style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(onPressed: minutos >= 240 ? null : () => set(() => minutos += 5), icon: const Icon(Icons.add_rounded)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Listo')),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || titulo.text.trim().isEmpty) return;
    setState(() {
      final n = {'titulo': titulo.text.trim(), 'detalle': detalle.text.trim(), 'minutos': minutos};
      if (i == null) {
        _bloques.add(n);
      } else {
        _bloques[i] = n;
      }
    });
  }

  Future<void> _copiar() async {
    final otros = widget.otros.where((x) => x['id_evento'] != widget.evento.id).toList();
    final x = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Copiar el plan de otro evento', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            for (final o in otros)
              ListTile(
                leading: const Icon(Icons.content_copy_rounded),
                title: Text(_fechaDe(o)),
                subtitle: Text(
                  [for (final b in (o['bloques'] as List? ?? const [])) '${(b as Map)['titulo']}'].join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(c).pop(o),
              ),
          ],
        ),
      ),
    );
    if (x == null) return;
    setState(() {
      _bloques
        ..clear()
        ..addAll([for (final b in (x['bloques'] as List? ?? const [])) Map<String, dynamic>.from(b as Map)]);
    });
  }

  static String _fechaDe(Map o) {
    final d = DateTime.tryParse('${o['fecha']}');
    return d == null ? '${o['fecha']}' : '${Fechas.dia(d)} ${Fechas.corta(d)}';
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final r = await widget.sesion.api.post('coachGuardar', {
        'accion': 'plan',
        'idEvento': widget.evento.id,
        'fecha': Fechas.iso(widget.evento.fecha),
        'bloques': jsonEncode(_bloques),
        'compartido': _compartido,
      });
      if (r['exito'] == false) throw ApiException('${r['error']}');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final e = widget.evento;
    final min = _bloques.fold<int>(0, (a, b) => a + ((b['minutos'] as num?) ?? 0).toInt());
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _barra(
        'Plan del evento',
        acciones: [
          if (widget.otros.any((x) => x['id_evento'] != e.id))
            IconButton(tooltip: 'Copiar de otro evento', onPressed: _copiar, icon: const Icon(Icons.content_copy_rounded)),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(
            '${e.tipo} · ${Fechas.dia(e.fecha)} ${Fechas.corta(e.fecha)} · ${e.horaInicio}',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.texto),
          ),
          Text(e.lugar, style: TextStyle(color: p.textoSecundario)),
          const SizedBox(height: 14),
          if (_bloques.isEmpty)
            Text('Agrega los bloques del entrenamiento en orden: calentamiento, ejercicios, juego…', style: TextStyle(color: p.textoSecundario)),
          for (var i = 0; i < _bloques.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: p.tarjeta,
                borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: p.suave,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(color: p.sobreSuave, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text('${_bloques[i]['titulo']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(['${_bloques[i]['minutos']} min', if ('${_bloques[i]['detalle'] ?? ''}'.isNotEmpty) '${_bloques[i]['detalle']}'].join(' · ')),
                  onTap: () => _bloque(i),
                  trailing: PopupMenuButton<String>(
                    onSelected: (a) => setState(() {
                      final b = _bloques.removeAt(i);
                      if (a == 'subir') _bloques.insert(i - 1, b);
                      if (a == 'bajar') _bloques.insert(i + 1, b);
                    }),
                    itemBuilder: (_) => [
                      if (i > 0) const PopupMenuItem(value: 'subir', child: Text('Subir')),
                      if (i < _bloques.length - 1) const PopupMenuItem(value: 'bajar', child: Text('Bajar')),
                      const PopupMenuItem(value: 'quitar', child: Text('Quitar')),
                    ],
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: _bloque, icon: const Icon(Icons.add_rounded), label: const Text('Agregar bloque')),
          ),
          if (min > 0)
            Text(
              'Total: $min minutos',
              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
            ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('El equipo ve qué veremos'),
            subtitle: const Text('Aparece en el detalle del evento.'),
            value: _compartido,
            onChanged: (v) => setState(() => _compartido = v),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _guardando ? null : _guardar, child: Text(_bloques.isEmpty && widget.plan != null ? 'Quitar el plan' : 'Guardar')),
        ],
      ),
    );
  }
}

/// "Qué veremos" en el detalle de un evento: lo ve el equipo si el coach lo
/// compartió; un coach lo ve siempre y puede editarlo.
class PlanEnEvento extends StatefulWidget {
  const PlanEnEvento({super.key, required this.sesion, required this.evento});
  final Sesion sesion;
  final Evento evento;
  @override
  State<PlanEnEvento> createState() => _PlanEnEventoState();
}

class _PlanEnEventoState extends State<PlanEnEvento> {
  Map<String, dynamic>? _r;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.sesion.api.get('getPlanEvento', {'idEvento': widget.evento.id});
      if (mounted && r['exito'] != false) setState(() => _r = r);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final plan = _r?['plan'] as Map?;
    final esCoach = _r?['esCoach'] == true;
    final bloques = (plan?['bloques'] as List? ?? const []);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      alignment: Alignment.topCenter,
      child: plan == null && !esCoach
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment_outlined, color: p.marcaTexto),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            esCoach ? 'Plan del evento' : 'Qué veremos',
                            style: TextStyle(fontWeight: FontWeight.w800, color: p.texto),
                          ),
                        ),
                        if (esCoach)
                          TextButton(
                            onPressed: () async {
                              final ok = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => PlanEventoScreen(
                                    sesion: widget.sesion,
                                    evento: widget.evento,
                                    plan: plan == null ? null : Map<String, dynamic>.from(plan),
                                  ),
                                ),
                              );
                              if (ok == true) _cargar();
                            },
                            child: Text(plan == null ? 'Armar' : 'Editar'),
                          ),
                      ],
                    ),
                    if (bloques.isEmpty) Text('Todavía sin plan.', style: TextStyle(color: p.textoSecundario)),
                    for (final b in bloques)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '• ${(b as Map)['titulo']}${(b['minutos'] as num? ?? 0) > 0 ? ' (${b['minutos']} min)' : ''}',
                          style: TextStyle(color: p.texto),
                        ),
                      ),
                    if (esCoach && plan != null && plan['compartido'] != true)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Solo lo ven lxs coaches.', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Ficha deportiva ───────────────────────────────────────────────────────

const _niveles = {'no': 'Aún no', 'proceso': 'En proceso', 'logrado': 'Logrado'};

const _visibles = {
  'yo': ('Solo yo', Icons.lock_outline_rounded),
  'coaches': ('Coaches', Icons.sports_rounded),
  'pivots': ('Coaches y Pivots', Icons.shield_outlined),
  'jugadorx': ('También lx jugadorx', Icons.visibility_outlined),
};

class FichaDeportivaScreen extends StatefulWidget {
  const FichaDeportivaScreen({super.key, required this.sesion, this.username, this.nombre});
  final Sesion sesion;

  /// Sin username: la propia (desde Ajustes).
  final String? username;
  final String? nombre;
  @override
  State<FichaDeportivaScreen> createState() => _FichaDeportivaScreenState();
}

class _FichaDeportivaScreenState extends State<FichaDeportivaScreen> {
  Map<String, dynamic>? _d;
  String? _error_;
  Sesion get s => widget.sesion;
  bool get _puedeEditar => _d?['puedeEditar'] == true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await s.api.get('getFichaDeportiva', {'username': ?widget.username, if (s.adminToken != null) 'adminToken': s.adminToken});
      if (r['exito'] == false) throw ApiException('${r['error']}');
      if (mounted) setState(() => _d = r);
    } catch (e) {
      if (mounted) setState(() => _error_ = _error(e));
    }
  }

  Future<bool> _guardar(Map<String, Object?> q) async {
    try {
      final r = await s.api.post('coachGuardar', {'username': _d?['username'], ...q});
      if (r['exito'] == false) throw ApiException('${r['error']}');
      await _cargar();
      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(e))));
      return false;
    }
  }

  Future<void> _evaluar(Map h) async {
    final n = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('${h['nombre']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            for (final x in _niveles.entries)
              ListTile(
                leading: Icon(x.key == h['nivel'] ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                title: Text(x.value),
                onTap: () => Navigator.of(c).pop(x.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (n == null || n == h['nivel']) return;
    await _guardar({'accion': 'evaluar', 'habilidadId': h['id'], 'nivel': n});
  }

  Future<void> _nuevaNota() async {
    final r = await showModalBottomSheet<(String, bool, String)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _EditorNota(),
    );
    if (r == null) return;
    if (await _guardar({'accion': 'nota', 'texto': r.$1, 'porVoz': r.$2, 'visible': r.$3}) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nota guardada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final d = _d;
    final habs = [for (final h in (d?['habilidades'] as List? ?? const [])) Map<String, dynamic>.from(h as Map)];
    final logradas = habs.where((h) => h['nivel'] == 'logrado').length;
    final categorias = <String, List<Map<String, dynamic>>>{};
    for (final h in habs) {
      (categorias['${h['categoria']}'] ??= []).add(h);
    }
    final notas = [for (final n in (d?['notas'] as List? ?? const [])) Map<String, dynamic>.from(n as Map)];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _barra(widget.username == null ? 'Mi ficha deportiva' : (widget.nombre ?? 'Ficha deportiva')),
      floatingActionButton: _puedeEditar
          ? FloatingActionButton.extended(onPressed: _nuevaNota, icon: const Icon(Icons.mic_none_rounded), label: const Text('Nota'))
          : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: d == null
            ? (_error_ == null ? const Esqueleto(key: ValueKey('c'), forma: FormaEsqueleto.ajustes) : Center(key: const ValueKey('e'), child: Text(_error_!)))
            : ListView(
                key: const ValueKey('l'),
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Dato(valor: '$logradas de ${habs.length}', texto: 'habilidades logradas'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Dato(valor: '${d['asistencias30']}', texto: 'asistencias en 30 días'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(PivotRadios.chip),
                    child: LinearProgressIndicator(
                      value: habs.isEmpty ? 0 : logradas / habs.length,
                      minHeight: 8,
                      backgroundColor: p.apagadoFondo,
                      color: p.marca,
                    ),
                  ),
                  if (_puedeEditar)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Toca una habilidad para marcar cómo va. Cada cambio queda en su historial.',
                        style: TextStyle(fontSize: 13, color: p.textoSecundario),
                      ),
                    ),
                  for (final c in categorias.entries) ...[
                    const SizedBox(height: 18),
                    Text(
                      c.key.toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                    ),
                    const SizedBox(height: 4),
                    for (final h in c.value)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('${h['nombre']}', style: const TextStyle(fontSize: 15)),
                        subtitle: h['fecha'] == null ? null : Text('Desde el ${Fechas.corta(DateTime.parse('${h['fecha']}').toLocal())}'),
                        trailing: _Nivel(nivel: h['nivel'] as String?),
                        onTap: _puedeEditar ? () => _evaluar(h) : null,
                      ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'NOTAS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                  ),
                  const SizedBox(height: 6),
                  if (notas.isEmpty)
                    Text(
                      _puedeEditar ? 'Todavía no hay notas. Toca "Nota" para escribir o dictar una.' : 'Todavía no hay notas para ti.',
                      style: TextStyle(color: p.textoSecundario),
                    ),
                  for (final n in notas)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${n['texto']}', style: TextStyle(height: 1.35, color: p.texto)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (n['porVoz'] == true) ...[Icon(Icons.mic_none_rounded, size: 14, color: p.textoSecundario), const SizedBox(width: 4)],
                              Expanded(
                                child: Text(
                                  [
                                    '${n['coachNombre']}',
                                    Fechas.corta(DateTime.parse('${n['fecha']}').toLocal()),
                                    if (_puedeEditar) _visibles['${n['visible']}']?.$1 ?? '',
                                  ].join(' · '),
                                  style: TextStyle(fontSize: 12.5, color: p.textoSecundario),
                                ),
                              ),
                              if (_puedeEditar && n['coach'] == s.nombre)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Borrar nota',
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                  onPressed: () => _guardar({'accion': 'borrarNota', 'id': n['id']}),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.valor, required this.texto});
  final String valor, texto;
  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valor,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.texto),
          ),
          Text(texto, style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
        ],
      ),
    );
  }
}

class _Nivel extends StatelessWidget {
  const _Nivel({required this.nivel});
  final String? nivel;
  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final (fondo, texto) = switch (nivel) {
      'logrado' => (p.marca, p.sobreMarca),
      'proceso' => (p.suave, p.sobreSuave),
      _ => (p.apagadoFondo, p.textoSecundario),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(PivotRadios.chip)),
      child: Text(
        nivel == null ? 'Sin evaluar' : _niveles[nivel]!,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: texto),
      ),
    );
  }
}

/// Nota escrita o dictada, y quién más la ve.
class _EditorNota extends StatefulWidget {
  const _EditorNota();
  @override
  State<_EditorNota> createState() => _EditorNotaState();
}

class _EditorNotaState extends State<_EditorNota> {
  final _texto = TextEditingController();
  final _voz = SpeechToText();
  bool _escuchando = false;
  bool _porVoz = false;
  String _visible = 'yo';
  String _antes = '';

  @override
  void dispose() {
    _voz.cancel();
    _texto.dispose();
    super.dispose();
  }

  Future<void> _dictar() async {
    if (_escuchando) {
      await _voz.stop();
      setState(() => _escuchando = false);
      return;
    }
    final ok = await _voz.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) setState(() => _escuchando = false);
      },
      onError: (_) {
        if (mounted) setState(() => _escuchando = false);
      },
    );
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este teléfono no permite dictar. Revisa el permiso del micrófono.')));
      }
      return;
    }
    _antes = _texto.text.trim();
    setState(() {
      _escuchando = true;
      _porVoz = true;
    });
    await _voz.listen(
      listenOptions: SpeechListenOptions(partialResults: true, listenMode: ListenMode.dictation, localeId: 'es_ES'),
      onResult: (r) {
        final t = r.recognizedWords;
        _texto.text = _antes.isEmpty ? t : '$_antes $t';
        _texto.selection = TextSelection.collapsed(offset: _texto.text.length);
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nueva nota', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Escríbela o toca el micrófono y habla: se pasa a texto.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
          const SizedBox(height: 12),
          TextField(
            controller: _texto,
            minLines: 3,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Ej. Mejoró el T-stop; le cuesta caer en dos rodillas.',
              suffixIcon: IconButton(
                tooltip: _escuchando ? 'Dejar de dictar' : 'Dictar',
                onPressed: _dictar,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _escuchando ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
                    key: ValueKey(_escuchando),
                    color: _escuchando ? p.marcaTexto : null,
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _escuchando
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Escuchando…',
                      style: TextStyle(color: p.marcaTexto, fontWeight: FontWeight.w600),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 12),
          const Text('¿Quién más la ve?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in _visibles.entries)
                ChoiceChip(
                  avatar: Icon(v.value.$2, size: 16),
                  label: Text(v.value.$1),
                  selected: _visible == v.key,
                  onSelected: (_) => setState(() => _visible = v.key),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _texto.text.trim().isEmpty ? null : () => Navigator.of(context).pop((_texto.text.trim(), _porVoz, _visible)),
              child: const Text('Guardar nota'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lista de habilidades (editable) ───────────────────────────────────────

class HabilidadesScreen extends StatefulWidget {
  const HabilidadesScreen({super.key, required this.sesion});
  final Sesion sesion;
  @override
  State<HabilidadesScreen> createState() => _HabilidadesScreenState();
}

class _HabilidadesScreenState extends State<HabilidadesScreen> {
  List<Map<String, dynamic>>? _l;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.sesion.api.get('getHabilidades');
      if (mounted) setState(() => _l = [for (final h in (r['habilidades'] as List? ?? const [])) Map<String, dynamic>.from(h as Map)]);
    } catch (_) {}
  }

  Future<void> _editar([Map<String, dynamic>? h, String? categoria]) async {
    final nombre = TextEditingController(text: '${h?['nombre'] ?? ''}');
    final cat = TextEditingController(text: '${h?['categoria'] ?? categoria ?? ''}');
    var activa = h?['activa'] != false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(c).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h == null ? 'Nueva habilidad' : 'Editar habilidad', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: nombre,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Habilidad'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cat,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Grupo', hintText: 'Ej. Frenos'),
              ),
              if (h != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('En uso'),
                  subtitle: const Text('Apagada, deja de aparecer en las fichas (no se borra su historial).'),
                  value: activa,
                  onChanged: (v) => set(() => activa = v),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Guardar')),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || nombre.text.trim().isEmpty || cat.text.trim().isEmpty) return;
    try {
      final r = await widget.sesion.api.post('coachGuardar', {
        'accion': 'habilidad',
        'id': h?['id'],
        'nombre': nombre.text.trim(),
        'categoria': cat.text.trim(),
        'activa': activa,
      });
      if (r['exito'] == false) throw ApiException('${r['error']}');
      _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _l;
    final grupos = <String, List<Map<String, dynamic>>>{};
    for (final h in l ?? const <Map<String, dynamic>>[]) {
      (grupos['${h['categoria']}'] ??= []).add(h);
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _barra('Habilidades'),
      floatingActionButton: l == null
          ? null
          : FloatingActionButton.extended(onPressed: () => _editar(), icon: const Icon(Icons.add_rounded), label: const Text('Habilidad')),
      body: l == null
          ? const Esqueleto()
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
              children: [
                Text(
                  'La lista parte de las habilidades mínimas de WFTDA. Agrega, cambia o apaga las que tu liga necesite: vale para todas las fichas.',
                  style: TextStyle(fontSize: 14, height: 1.35, color: p.texto),
                ),
                for (final g in grupos.entries) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.key.toUpperCase(),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Agregar a ${g.key}',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _editar(null, g.key),
                        icon: const Icon(Icons.add_rounded, size: 20),
                      ),
                    ],
                  ),
                  for (final h in g.value)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        '${h['nombre']}',
                        style: TextStyle(
                          fontSize: 15,
                          color: h['activa'] == false ? p.apagado : p.texto,
                          decoration: h['activa'] == false ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => _editar(h),
                    ),
                ],
              ],
            ),
    );
  }
}

// ─── Pivots: coaches de la liga ────────────────────────────────────────────

/// Elige qué equipos lleva un coach. Vacío = todos. Null si se cancela.
Future<List<String>?> elegirEquiposCoach(BuildContext context, Sesion s, List<String> actuales) async {
  List<String> equipos;
  try {
    final r = await s.api.get('getTiers', {'adminToken': s.adminToken});
    equipos = [for (final t in (r['tiers'] as List? ?? const [])) '${(t as Map)['nombre']}'];
  } catch (_) {
    equipos = const [];
  }
  if (!context.mounted) return null;
  final sel = {...actuales};
  return showModalBottomSheet<List<String>>(
    context: context,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Qué equipos lleva?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Ve y sigue solo a lxs jugadorxs de esos equipos.', style: TextStyle(fontSize: 13, color: c.pivot.textoSecundario)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(label: const Text('Todos'), selected: sel.isEmpty, onSelected: (_) => set(sel.clear)),
                  for (final e in equipos) FilterChip(label: Text(e), selected: sel.contains(e), onSelected: (v) => set(() => v ? sel.add(e) : sel.remove(e))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.of(c).pop(sel.toList()), child: const Text('Listo')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CoachesScreen extends StatefulWidget {
  const CoachesScreen({super.key, required this.sesion});
  final Sesion sesion;
  @override
  State<CoachesScreen> createState() => _CoachesScreenState();
}

class _CoachesScreenState extends State<CoachesScreen> {
  List<Map<String, dynamic>>? _l;
  Sesion get s => widget.sesion;

  @override
  void initState() {
    super.initState();
    _llamar({'accion': 'listar'});
  }

  Future<void> _llamar(Map<String, Object?> q) async {
    try {
      final r = await s.api.post('adminCoaches', {'adminToken': s.adminToken, ...q});
      if (r['exito'] == false) throw ApiException('${r['error']}');
      if (mounted) setState(() => _l = [for (final c in (r['coaches'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)]);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(e))));
    }
  }

  Future<void> _nombrar() async {
    List<Map<String, dynamic>> personas;
    try {
      final r = await s.api.get('adminGetRosterEquipo', {'adminToken': s.adminToken});
      personas = [for (final x in (r['personas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(e))));
      return;
    }
    final ya = {
      for (final c in _l ?? const <Map<String, dynamic>>[])
        if (c['estado'] == 'aprobado') c['username'],
    };
    if (!mounted) return;
    var q = '';
    final elegida = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          final l = personas.where((x) => !ya.contains(x['nombre']) && '${x['nombreDerby']} ${x['nombre']}'.toLowerCase().contains(q.toLowerCase())).toList();
          return SizedBox(
            height: MediaQuery.sizeOf(c).height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => set(() => q = v),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: '¿Quién será coach?'),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final x in l)
                        ListTile(
                          leading: AvatarPersona(nombre: '${x['nombreDerby'] ?? x['nombre']}', foto: '${x['fotoPerfil'] ?? ''}', tamano: 40),
                          title: Text('${(x['nombreDerby'] ?? '').toString().isEmpty ? x['nombre'] : x['nombreDerby']}'),
                          subtitle: Text('@${x['nombre']}'),
                          onTap: () => Navigator.of(c).pop(x),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (elegida == null || !mounted) return;
    final eq = await elegirEquiposCoach(context, s, const []);
    if (eq == null) return;
    await _llamar({'accion': 'nombrar', 'username': elegida['nombre'], 'equipos': jsonEncode(eq)});
  }

  Future<void> _opciones(Map<String, dynamic> c) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (h) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('${c['nombre']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            if (c['estado'] == 'pendiente')
              ListTile(leading: const Icon(Icons.check_rounded), title: const Text('Aprobar'), onTap: () => Navigator.of(h).pop('aprobar')),
            if (c['estado'] == 'aprobado')
              ListTile(leading: const Icon(Icons.groups_rounded), title: const Text('Cambiar equipos'), onTap: () => Navigator.of(h).pop('equipos')),
            ListTile(
              leading: Icon(Icons.person_remove_outlined, color: h.pivot.marcaTexto),
              title: Text(c['estado'] == 'pendiente' ? 'Rechazar' : 'Quitar de coaches', style: TextStyle(color: h.pivot.marcaTexto)),
              onTap: () => Navigator.of(h).pop(c['estado'] == 'pendiente' ? 'rechazar' : 'quitar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (a == null || !mounted) return;
    if (a == 'aprobar' || a == 'equipos') {
      final eq = await elegirEquiposCoach(context, s, [for (final e in (c['equipos'] as List? ?? const [])) '$e']);
      if (eq == null) return;
      await _llamar({'accion': a, 'username': c['username'], 'equipos': jsonEncode(eq)});
    } else {
      await _llamar({'accion': a, 'username': c['username']});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _l;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _barra('Coaches'),
      floatingActionButton: l == null
          ? null
          : FloatingActionButton.extended(onPressed: _nombrar, icon: const Icon(Icons.add_rounded), label: const Text('Nombrar coach')),
      body: l == null
          ? const Esqueleto()
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
              children: [
                Text(
                  'Lxs coaches ven a lxs jugadorxs de sus equipos (sin datos de salud), llevan su ficha deportiva, arman el plan de cada evento y toman asistencia.',
                  style: TextStyle(fontSize: 14, height: 1.35, color: p.texto),
                ),
                const SizedBox(height: 12),
                if (l.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Center(
                      child: Text('Todavía no hay coaches.', style: TextStyle(color: p.textoSecundario)),
                    ),
                  ),
                for (final c in l)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AvatarPersona(nombre: '${c['nombre']}', foto: '${c['foto'] ?? ''}', tamano: 44),
                    title: Text('${c['nombre']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      c['estado'] == 'pendiente'
                          ? 'Pidió ser coach${'${c['mensaje'] ?? ''}'.isEmpty ? '' : ': ${c['mensaje']}'}'
                          : ((c['equipos'] as List? ?? const []).isEmpty ? 'Todos los equipos' : (c['equipos'] as List).join(' · ')),
                    ),
                    trailing: const Icon(Icons.more_horiz_rounded),
                    onTap: () => _opciones(c),
                  ),
              ],
            ),
    );
  }
}

/// Fila de Ajustes para pedir ser coach (o ver el pedido).
class FilaSerCoach extends StatelessWidget {
  const FilaSerCoach({super.key, required this.sesion});
  final Sesion sesion;

  Future<void> _pedir(BuildContext context) async {
    final mensaje = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(c).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quiero ser coach', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Un Pivot revisa tu pedido. Al aprobarlo tendrás la sección Coach para seguir a tus jugadorxs, armar el plan de cada evento y tomar asistencia.',
              style: TextStyle(height: 1.35, color: c.pivot.textoSecundario),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mensaje,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Mensaje para los Pivots (opcional)'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Enviar pedido')),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final r = await sesion.api.post('pedirCoach', {'mensaje': mensaje.text.trim()});
      if (r['exito'] == false) throw ApiException('${r['error']}');
      await sesion.cargarCoach();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido enviado. Te avisamos cuando un Pivot lo revise.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(e))));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sesion,
    builder: (context, _) {
      final e = sesion.coachEstado;
      if (e == 'aprobado') return const SizedBox.shrink();
      return FilaAjuste(
        icono: Icons.sports_rounded,
        seccion: 'coach',
        titulo: 'Quiero ser coach',
        valor: e == 'pendiente' ? 'Pedido enviado: un Pivot lo está revisando' : 'Pide la sección Coach',
        alTocar: e == 'pendiente' ? null : () => _pedir(context),
      );
    },
  );
}
