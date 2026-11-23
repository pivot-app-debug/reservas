import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../ajustes/componentes.dart';
import '../core/api.dart';
import '../core/esqueleto.dart';
import '../core/fechas.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../eventos/eventos_repo.dart';
import '../eventos/modelos.dart';
import '../eventos/widgets_comunes.dart';
import '../cursos/cursos_screen.dart' show Curso, CursosAbiertosScreen, CursosScreen;
import '../equipo/habilidades_screen.dart';
import '../ajustes/herramientas_liga.dart';
import '../sesion/sesion.dart';

/// Coach (Victor, 2026-11-16; rediseño 2026-11-19): portada con atajos
/// (en Ajustes → Herramientas de la liga), ficha deportiva, plan y evaluación
/// de cada evento. Las habilidades y "Marcar habilidades" están en
/// `equipo/habilidades_screen.dart`. Sin datos de salud: solo el estado que
/// ve el equipo.

AppBar barraCoach(String titulo, {List<Widget>? acciones, PreferredSizeWidget? abajo}) => AppBar(
  backgroundColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  flexibleSpace: const Vidrio(child: SizedBox.expand()),
  title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
  actions: acciones,
  bottom: abajo,
);

String errorCoach(Object e) => e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.';

// ─── Coach (Ajustes → Herramientas de la liga) ────────────────────────────

/// Portada de Coach (rediseño de Victor, 2026-11-19): atajos a la vista y
/// nada más. Las fichas y "Marcar habilidades" viven en Equipo; los cursos
/// y la evaluación de cada entrenamiento, en el Calendario. Se quitó el
/// Cronograma (para eso está el Calendario).
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
  List<Curso>? _cursos;
  Sesion get s => widget.sesion;
  bool get _pivot => s.esAdmin && s.adminToken != null;

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarCursos();
    widget.eventos.cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await s.api.get('getCoach');
      if (r['exito'] == false) throw ApiException('${r['error']}');
      if (mounted) setState(() => _d = r);
    } catch (e) {
      if (mounted) setState(() => _error_ = errorCoach(e));
    }
  }

  Future<void> _cargarCursos() async {
    try {
      final r = await s.api.get('getCursos', const {});
      final l = [
        for (final c in (r['cursos'] as List? ?? const []))
          if ('${(c as Map)['estado'] ?? 'abierto'}' != 'terminado') Curso(Map<String, dynamic>.from(c)),
      ];
      if (mounted) setState(() => _cursos = l);
    } catch (_) {
      if (mounted) setState(() => _cursos ??= const []);
    }
  }

  List<Map<String, dynamic>> get _jugadorxs => [for (final x in (_d?['jugadorxs'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

  Future<void> _abrir(Widget pantalla) async {
    await SubAjustes.abrir<void>(context, pantalla);
    if (mounted) _cargar();
  }

  /// Los mismos Cursos del Calendario (Pivots: crear, editar y pre-armados).
  Future<void> _abrirCursos() async {
    await SubAjustes.abrir<void>(context, _pivot ? CursosScreen(sesion: s) : CursosAbiertosScreen(sesion: s));
    if (mounted) _cargarCursos();
  }

  /// Plan sin fecha (de un evento cancelado) a un evento próximo.
  Future<void> _asignar(Map<String, dynamic> pl) async {
    final hoy = Fechas.hoy();
    final evs = [
      for (final e in widget.eventos.eventos)
        if (!e.cancelado && !e.fecha.isBefore(hoy)) e,
    ]..sort((a, b) => '${Fechas.iso(a.fecha)} ${a.horaInicio}'.compareTo('${Fechas.iso(b.fecha)} ${b.horaInicio}'));
    final e = await showModalBottomSheet<Evento>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (h) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('¿A qué evento lo pasamos?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            for (final e in evs.take(12))
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text('${e.tipo} · ${Fechas.dia(e.fecha)} ${Fechas.corta(e.fecha)} · ${e.horaInicio}'),
                onTap: () => Navigator.of(h).pop(e),
              ),
          ],
        ),
      ),
    );
    if (e == null || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    try {
      final r = await s.api.post('coachGuardar', {'accion': 'asignarPlan', 'id': '${pl['id']}', 'idEvento': e.id, 'fecha': Fechas.iso(e.fecha)});
      if (r['exito'] == false) throw ApiException('${r['error']}');
      m.showSnackBar(const SnackBar(content: Text('Plan asignado.')));
      _cargar();
    } catch (err) {
      m.showSnackBar(SnackBar(content: Text(errorCoach(err))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: barraCoach('Coach'),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _d == null
            ? (_error_ == null ? const Esqueleto(key: ValueKey('c')) : Center(key: const ValueKey('e'), child: Text(_error_!)))
            : ListView(
                key: const ValueKey('l'),
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 32 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Text(
                    (_d?['equipos'] as List? ?? const []).isEmpty ? 'Llevas todos los equipos.' : 'Llevas: ${(_d!['equipos'] as List).join(' · ')}',
                    style: TextStyle(fontSize: 13, color: p.textoSecundario),
                  ),
                  const SizedBox(height: 12),
                  _atajos(context),
                  ..._sinFecha(context),
                  ..._enCurso(context),
                  const SizedBox(height: 12),
                  Text(
                    'Las fichas deportivas y "Marcar habilidades" están en Liga. Para evaluar un entrenamiento, ábrelo en el Calendario y toca "Evaluar".',
                    style: TextStyle(fontSize: 12.5, height: 1.35, color: p.textoSecundario),
                  ),
                ],
              ),
      ),
    );
  }

  /// Atajos de la portada, del mismo estilo que los de Inventario.
  Widget _atajos(BuildContext context) {
    final p = context.pivot;
    final n = _cursos?.length;
    final puedeNombrar = s.esCoach || (_pivot && (s.tieneArea('coach') || s.tieneArea('equipo') || s.esAdmin));
    final l = <(IconData, String, String, VoidCallback)>[
      (Icons.checklist_rounded, 'Habilidades', 'Básicas y avanzadas: crear, editar y marcar', () => _abrir(HabilidadesEquipoScreen(sesion: s, lista: true))),
      (Icons.tune_rounded, 'Ajustes de coach', 'Avisos de novedades a las personas', _ajustes),
      (Icons.school_outlined, 'Cursos en curso', n == null ? 'Cursos y clínicas' : (n == 1 ? '1 curso abierto' : '$n cursos abiertos'), _abrirCursos),
      if (_pivot) (Icons.auto_awesome_motion_outlined, 'Pre-armados', 'Plantillas para crear cursos', _abrirCursos),
      (Icons.timer_outlined, 'Pruebas', 'Medir el progreso, como vueltas en 5 minutos', () => _abrir(PruebasCoachScreen(sesion: s, jugadorxs: _jugadorxs))),
      if (puedeNombrar)
        (Icons.person_add_outlined, 'Agregar nuevo coach', 'Nombrar o gestionar coaches del equipo', () => _abrir(CoachesScreen(sesion: s))),
    ];
    Widget atajo((IconData, String, String, VoidCallback) a) => Material(
      color: p.tarjeta,
      borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: a.$4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(a.$1, color: p.marcaTexto),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a.$2,
                      style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(a.$3, style: TextStyle(fontSize: 12, height: 1.3, color: p.textoSecundario)),
            ],
          ),
        ),
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < l.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            // Mismo alto aunque un subtítulo sea más largo (QA 2026-11-18).
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: atajo(l[i])),
                  const SizedBox(width: 10),
                  Expanded(child: i + 1 < l.length ? atajo(l[i + 1]) : const SizedBox.shrink()),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _titulo(BuildContext context, String t) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
    child: Text(
      t,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.pivot.textoSecundario),
    ),
  );

  /// Planes de eventos cancelados, para pasarlos a otro (Victor, 2026-11-17).
  List<Widget> _sinFecha(BuildContext context) {
    final p = context.pivot;
    final l = [for (final x in (_d?['sinFecha'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    if (l.isEmpty) return const [];
    return [
      _titulo(context, 'PLANES SIN FECHA'),
      for (final x in l)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: p.suave,
            borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(Icons.inventory_2_outlined, color: p.sobreSuave),
              title: Text(
                '${'${x['equipo'] ?? ''}'.isEmpty ? 'Toda la liga' : x['equipo']} · ${_resumenPlan([x])}',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.sobreSuave),
              ),
              subtitle: Text(
                [for (final b in (x['bloques'] as List? ?? const [])) '${(b as Map)['titulo']}'].join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.sobreSuave),
              ),
              trailing: TextButton(onPressed: () => _asignar(x), child: const Text('Asignar')),
            ),
          ),
        ),
    ];
  }

  /// Cursos que están corriendo, con atajo a editarlos.
  List<Widget> _enCurso(BuildContext context) {
    final p = context.pivot;
    final l = _cursos;
    if (l == null) return const [];
    return [
      _titulo(context, 'CURSOS EN CURSO'),
      if (l.isEmpty)
        Text('No hay cursos abiertos ahora.', style: TextStyle(color: p.textoSecundario))
      else
        for (final c in l.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: p.tarjeta,
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(c.esClinica ? Icons.bolt_rounded : Icons.school_outlined, color: p.marcaTexto),
                title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${c.resumenFechas} · ${c.inscritos == 1 ? '1 inscritx' : '${c.inscritos} inscritxs'}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _abrirCursos,
              ),
            ),
          ),
    ];
  }

  /// Aviso semanal a las personas con novedades en su ficha (Victor, 2026-11-17).
  Future<void> _ajustes() async {
    var avisar = _d?['avisarNovedades'] != false;
    await showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (h) => StatefulBuilder(
        builder: (h, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text('Ajustes de coach', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                SwitchListTile(
                  title: const Text('Avisar novedades a las personas'),
                  subtitle: const Text(
                    'Los lunes, a quien tiene notas, feedback o pruebas nuevas que puede ver en su ficha. Si no hay nada nuevo, no le llega nada.',
                  ),
                  value: avisar,
                  onChanged: (v) async {
                    set(() => avisar = v);
                    try {
                      await s.api.post('coachGuardar', {'accion': 'ajustes', 'avisarNovedades': v});
                      _d?['avisarNovedades'] = v;
                    } catch (_) {
                      set(() => avisar = !v);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _resumenPlan(List<Map<String, dynamic>>? l) {
    if (l == null || l.isEmpty) return 'Sin plan';
    if (l.length > 1) return '${l.length} planes (${l.map((x) => '${x['equipo'] ?? ''}'.isEmpty ? 'toda la liga' : '${x['equipo']}').join(', ')})';
    final x = l.first;
    final b = (x['bloques'] as List? ?? const []);
    final min = b.fold<int>(0, (a, y) => a + ((y as Map)['minutos'] as num? ?? 0).toInt());
    return '${b.length} ${b.length == 1 ? 'bloque' : 'bloques'}${min > 0 ? ' · $min min' : ''}${x['compartido'] == true ? ' · compartido' : ''}';
  }
}

/// Pruebas de progreso en su propia pantalla (antes, tercera vista de Coach).
class PruebasCoachScreen extends StatelessWidget {
  const PruebasCoachScreen({super.key, required this.sesion, required this.jugadorxs});
  final Sesion sesion;
  final List<Map<String, dynamic>> jugadorxs;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: barraCoach('Pruebas'),
    body: ListView(
      padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 32 + MediaQuery.paddingOf(context).bottom),
      children: [_PruebasCoach(sesion: sesion, jugadorxs: jugadorxs)],
    ),
  );
}

// ─── Plan de un evento ─────────────────────────────────────────

class PlanEventoScreen extends StatefulWidget {
  const PlanEventoScreen({super.key, required this.sesion, required this.evento, this.plan, this.otros = const [], this.equipo = '', this.coaches = const []});
  final Sesion sesion;
  final Evento evento;
  final Map<String, dynamic>? plan;
  final List<Map<String, dynamic>> otros;

  /// Para qué equipo es el plan ('' = toda la liga).
  final String equipo;

  /// Coaches aprobadxs, para elegir quién lo da.
  final List<Map<String, dynamic>> coaches;
  @override
  State<PlanEventoScreen> createState() => _PlanEventoScreenState();
}

class _PlanEventoScreenState extends State<PlanEventoScreen> {
  late final List<Map<String, dynamic>> _bloques = [for (final b in (widget.plan?['bloques'] as List? ?? const [])) Map<String, dynamic>.from(b as Map)];
  late bool _compartido = widget.plan?['compartido'] == true;
  // Quién da el plan (Victor, 2026-11-17).
  late final Set<String> _da = {
    for (final x in (widget.plan?['da'] as List? ?? const [])) x is Map ? '${x['username']}' : '$x',
    if (widget.plan == null) ?widget.sesion.nombre,
  };
  late List<Map<String, dynamic>> _coaches = widget.coaches;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (_coaches.isEmpty) {
      widget.sesion.api.get('getCoach').then((r) {
        if (mounted) setState(() => _coaches = [for (final c in (r['coaches'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)]);
      }, onError: (_) {});
    }
  }

  Future<void> _bloque([int? i]) async {
    final b = i == null ? null : _bloques[i];
    final titulo = TextEditingController(text: '${b?['titulo'] ?? ''}');
    final detalle = TextEditingController(text: '${b?['detalle'] ?? ''}');
    var minutos = (b?['minutos'] as num?)?.toInt() ?? 15;
    final ok = await showModalBottomSheet<bool>(
      useRootNavigator: true,
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
                decoration: const InputDecoration(labelText: 'Qué se hace', hintText: 'Ej. Calentamiento, técnica, juego'),
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
    final otros = widget.otros.where((x) => x['id_evento'] != widget.evento.id || '${x['equipo'] ?? ''}' != widget.equipo).toList();
    final x = await showModalBottomSheet<Map<String, dynamic>>(
      useRootNavigator: true,
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
                title: Text('${_fechaDe(o)}${'${o['equipo'] ?? ''}'.isEmpty ? '' : ' · ${o['equipo']}'}'),
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
        'equipo': widget.equipo,
        'da': jsonEncode(_da.toList()),
      });
      if (r['exito'] == false) throw ApiException('${r['error']}');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCoach(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final e = widget.evento;
    final min = _bloques.fold<int>(0, (a, b) => a + ((b['minutos'] as num?) ?? 0).toInt());
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: barraCoach(
        'Plan del evento',
        acciones: [
          if (widget.otros.any((x) => x['id_evento'] != e.id || '${x['equipo'] ?? ''}' != widget.equipo))
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
          Text(
            [e.lugar, widget.equipo.isEmpty ? 'Toda la liga' : 'Para ${widget.equipo}'].where((x) => x.isNotEmpty).join(' · '),
            style: TextStyle(color: p.textoSecundario),
          ),
          const SizedBox(height: 14),
          if (_coaches.isNotEmpty) ...[
            Text(
              'Quién lo da',
              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _coaches)
                  FilterChip(
                    label: Text('${c['nombre']}'),
                    selected: _da.contains('${c['username']}'),
                    onSelected: (v) => setState(() => v ? _da.add('${c['username']}') : _da.remove('${c['username']}')),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_bloques.isEmpty) Text('Agrega los bloques del entrenamiento en orden.', style: TextStyle(color: p.textoSecundario)),
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
            title: Text(widget.equipo.isEmpty ? 'La liga ve qué veremos' : 'El equipo ve qué veremos'),
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

/// Para qué equipo se arma el plan (Victor, 2026-11-17): coach de un equipo,
/// ese; coach de toda la liga, toda la liga o un equipo. Con una sola
/// opción no pregunta. null = canceló.
Future<String?> elegirEquipoPlan(BuildContext context, Map<String, dynamic> d, List<Map<String, dynamic>> hechos) async {
  final equipos = [for (final e in (d['equiposPlan'] as List? ?? const [])) '$e'];
  final opciones = [if (d['deTodaLaLiga'] == true) '', ...equipos];
  if (opciones.isEmpty) return '';
  if (opciones.length == 1) return opciones.first;
  final hay = {for (final x in hechos) '${x['equipo'] ?? ''}'};
  return showModalBottomSheet<String>(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    builder: (h) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('¿Para quién es el plan?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          for (final o in opciones)
            ListTile(
              leading: Icon(o.isEmpty ? Icons.groups_rounded : Icons.group_outlined),
              title: Text(o.isEmpty ? 'Toda la liga' : o),
              subtitle: Text(hay.contains(o) ? 'Ya tiene plan: editarlo' : 'Sin plan'),
              trailing: hay.contains(o) ? Icon(Icons.assignment_turned_in_outlined, color: h.pivot.marcaTexto) : null,
              onTap: () => Navigator.of(h).pop(o),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Plan del evento en su detalle (Victor, 2026-11-17: siempre visible, uno
/// por equipo y quién lo da). El resto lo ve si el coach lo compartió.
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
    } catch (_) {
      if (mounted) setState(() => _r = const {});
    }
  }

  List<Map<String, dynamic>> get _planes => [for (final x in (_r?['planes'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

  Future<void> _armar() async {
    final hechos = _planes;
    final equipo = await elegirEquipoPlan(context, _r ?? const {}, hechos);
    if (equipo == null || !mounted) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlanEventoScreen(
          sesion: widget.sesion,
          evento: widget.evento,
          equipo: equipo,
          plan: hechos.where((x) => '${x['equipo'] ?? ''}' == equipo).firstOrNull,
        ),
      ),
    );
    if (ok == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final esCoach = _r?['esCoach'] == true;
    final planes = _planes;
    final varios = planes.length > 1 || planes.any((x) => '${x['equipo'] ?? ''}'.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
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
                    'Plan del evento',
                    style: TextStyle(fontWeight: FontWeight.w800, color: p.texto),
                  ),
                ),
                if (esCoach) TextButton(onPressed: _armar, child: Text(planes.isEmpty ? 'Armar' : 'Armar o editar')),
              ],
            ),
            // Mismo alto mientras carga: no se "expande" al abrir.
            if (_r == null)
              Text('Cargando…', style: TextStyle(color: p.textoSecundario))
            else if (planes.isEmpty)
              Text('Todavía sin plan.', style: TextStyle(color: p.textoSecundario)),
            for (final pl in planes) ...[
              if (varios)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${pl['equipo'] ?? ''}'.isEmpty ? 'Toda la liga' : '${pl['equipo']}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                  ),
                ),
              if ((pl['da'] as List? ?? const []).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Lo da: ${[for (final d in pl['da'] as List) '${(d as Map)['nombre']}'].join(', ')}',
                    style: TextStyle(fontSize: 13, color: p.textoSecundario),
                  ),
                ),
              for (final b in (pl['bloques'] as List? ?? const []))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('• ${(b as Map)['titulo']}${(b['minutos'] as num? ?? 0) > 0 ? ' (${b['minutos']} min)' : ''}', style: TextStyle(color: p.texto)),
                ),
              if (esCoach && pl['compartido'] != true)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Solo lo ven lxs coaches.', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                ),
            ],
            // Al terminar: los entrenamientos se evalúan siempre desde aquí
            // (Victor, 2026-11-19); el resto, feedback por persona.
            if (esCoach && widget.evento.finalizado && FuncionesLiga.coach(widget.sesion))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                // Una sola pantalla para evaluar, sea el evento que sea (Victor, 2026-11-20).
                child: FilledButton.icon(
                  onPressed: () => EvaluarScreen.abrir(context, widget.sesion, {
                    'idEvento': widget.evento.id,
                    'fecha': Fechas.iso(widget.evento.fecha),
                    'tipo': widget.evento.tipo,
                  }),
                  icon: const Icon(Icons.rate_review_rounded),
                  label: const Text('Evaluar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Ficha deportiva ───────────────────────────────────────────────────────

const _niveles = {'no': 'Aún no', 'proceso': 'En proceso', 'logrado': 'Logrado'};

/// Quién ve una nota, feedback o prueba (Victor, 2026-11-17): Usuarios (la
/// persona), Pivots, Coaches, cada uno por separado; "Yo" = solo quien la
/// escribe. Se guarda "jugadorx,pivots" o "yo". Los valores viejos de uno
/// solo eran escalonados.
Set<String> quienVeDe(String v) => switch (v.trim()) {
  'jugadorx' => {'jugadorx', 'pivots', 'coaches'},
  'pivots' => {'pivots', 'coaches'},
  'coaches' => {'coaches'},
  final s => {
    for (final x in s.split(','))
      if (const ['jugadorx', 'pivots', 'coaches'].contains(x.trim())) x.trim(),
  },
};

// Con una sola opción lleva coma, para no leerse como los valores viejos.
String _codigoQuienVe(Set<String> s) => s.isEmpty ? 'yo' : '${const ['jugadorx', 'pivots', 'coaches'].where(s.contains).join(',')}${s.length == 1 ? ',' : ''}';

const _opcionesQuienVe = [
  ('jugadorx', 'Usuarios', Icons.person_outline_rounded),
  ('pivots', 'Pivots', Icons.shield_outlined),
  ('coaches', 'Coaches', Icons.sports_rounded),
];

/// "Usuarios y Pivots", "Solo yo".
String textoQuienVe(String v) {
  final s = quienVeDe(v);
  final l = [
    for (final o in _opcionesQuienVe)
      if (s.contains(o.$1)) o.$2,
  ];
  return l.isEmpty ? 'Solo yo' : (l.length > 1 ? '${l.sublist(0, l.length - 1).join(', ')} y ${l.last}' : l.first);
}

class QuienVe extends StatelessWidget {
  const QuienVe({super.key, required this.valor, required this.alCambiar});
  final String valor;
  final ValueChanged<String> alCambiar;

  @override
  Widget build(BuildContext context) {
    final s = quienVeDe(valor);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in _opcionesQuienVe)
          FilterChip(
            avatar: Icon(o.$3, size: 16),
            label: Text(o.$2),
            selected: s.contains(o.$1),
            onSelected: (v) => alCambiar(
              _codigoQuienVe(
                {...s}
                  ..removeWhere((x) => x == o.$1)
                  ..addAll([if (v) o.$1]),
              ),
            ),
          ),
        FilterChip(avatar: const Icon(Icons.lock_outline_rounded, size: 16), label: const Text('Yo'), selected: s.isEmpty, onSelected: (_) => alCambiar('yo')),
      ],
    );
  }
}

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
      if (mounted) setState(() => _error_ = errorCoach(e));
    }
  }

  Future<bool> _guardar(Map<String, Object?> q) async {
    try {
      final r = await s.api.post('coachGuardar', {'username': _d?['username'], ...q});
      if (r['exito'] == false) throw ApiException('${r['error']}');
      await _cargar();
      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCoach(e))));
      return false;
    }
  }

  Future<void> _evaluar(Map h) async {
    final n = await showModalBottomSheet<String>(
      useRootNavigator: true,
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

  Future<void> _nuevaMarca(Map<String, dynamic> pr) async {
    final c = TextEditingController();
    final v = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (h) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(h).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${pr['nombre']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Resultado de hoy', suffixText: '${pr['unidad']}'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.of(h).pop(c.text.trim()), child: const Text('Guardar')),
            ),
          ],
        ),
      ),
    );
    if (v == null || v.isEmpty) return;
    try {
      final r = await s.api.post('coachPruebas', {
        'accion': 'marca',
        'pruebaId': pr['id'],
        'username': _d?['username'],
        'valor': v,
        'fecha': Fechas.iso(Fechas.hoy()),
      });
      if (r['exito'] == false) throw ApiException('${r['error']}');
      await _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCoach(e))));
    }
  }

  Future<void> _nuevaNota() async {
    final r = await showModalBottomSheet<(String, bool, String)>(
      useRootNavigator: true,
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
      // Gestionar la lista de habilidades desde la ficha (Victor, 2026-11-21:
      // salió el botón Habilidades de Equipo).
      appBar: barraCoach(
        widget.username == null ? 'Mi ficha deportiva' : (widget.nombre ?? 'Ficha deportiva'),
        acciones: [
          if (_puedeEditar)
            IconButton(
              tooltip: 'Lista de habilidades',
              icon: const Icon(Icons.checklist_rounded),
              onPressed: () async {
                await SubAjustes.abrir<void>(context, HabilidadesEquipoScreen(sesion: s, lista: true));
                _cargar();
              },
            ),
        ],
      ),
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
                  _ProgresoFicha(d: d, puedeEditar: _puedeEditar, alMarca: (pr) => _nuevaMarca(pr)),
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
                                    if (_puedeEditar) 'Lo ven: ${textoQuienVe('${n['visible']}')}',
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
  bool _porVoz = false;
  String _visible = 'jugadorx,';

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
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
          Text('Escríbela o mantén presionado el micrófono mientras hablas: se pasa a texto.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
          const SizedBox(height: 12),
          TextField(
            controller: _texto,
            minLines: 3,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Ej. Mejoró el T-stop; le cuesta caer en dos rodillas.',
              suffixIcon: BotonDictar(controlador: _texto, alDictar: () => setState(() => _porVoz = true)),
            ),
          ),
          ...[
            const SizedBox(height: 12),
            const Text('¿Quién la ve?', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            QuienVe(valor: _visible, alCambiar: (v) => setState(() => _visible = v)),
          ],
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
    useRootNavigator: true,
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCoach(e))));
    }
  }

  Future<void> _nombrar() async {
    List<Map<String, dynamic>> personas;
    try {
      final r = await s.api.get('adminGetRosterEquipo', {'adminToken': s.adminToken});
      personas = [for (final x in (r['personas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCoach(e))));
      return;
    }
    final ya = {
      for (final c in _l ?? const <Map<String, dynamic>>[])
        if (c['estado'] == 'aprobado') c['username'],
    };
    if (!mounted) return;
    var q = '';
    final elegida = await showModalBottomSheet<Map<String, dynamic>>(
      useRootNavigator: true,
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
      useRootNavigator: true,
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
      appBar: barraCoach('Coaches'),
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
      useRootNavigator: true,
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
              'Un Pivot revisa tu pedido. Al aprobarlo tendrás Coaches en Liga y las fichas deportivas para seguir a tus jugadorxs, armar el plan de cada evento, evaluar los entrenamientos y tomar asistencia.',
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCoach(e))));
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

// ─── Etapa 3: pruebas, progreso y feedback ─────────────────────────────────

String _num(num v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

/// Pruebas y feedback dentro de la ficha deportiva.
class _ProgresoFicha extends StatelessWidget {
  const _ProgresoFicha({required this.d, required this.puedeEditar, required this.alMarca});
  final Map<String, dynamic> d;
  final bool puedeEditar;
  final void Function(Map<String, dynamic>) alMarca;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final pruebas = [for (final x in (d['pruebas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    final feedback = [for (final x in (d['feedback'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 6),
      child: Text(
        t,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pruebas.isNotEmpty) titulo('PRUEBAS'),
        for (final pr in pruebas) _TarjetaPrueba(pr: pr, puedeEditar: puedeEditar, alMarca: () => alMarca(pr)),
        if (feedback.isNotEmpty) titulo('FEEDBACK POR TEMA'),
        for (final t in feedback) _TarjetaTema(t: t),
      ],
    );
  }
}

class _TarjetaPrueba extends StatelessWidget {
  const _TarjetaPrueba({required this.pr, required this.puedeEditar, required this.alMarca});
  final Map<String, dynamic> pr;
  final bool puedeEditar;
  final VoidCallback alMarca;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final marcas = [for (final m in (pr['marcas'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
    final valores = [for (final m in marcas) (m['valor'] as num).toDouble()];
    final mas = pr['masEsMejor'] != false;
    String? cambio;
    if (valores.length >= 2) {
      final dif = valores.last - valores[valores.length - 2];
      final mejora = mas ? dif > 0 : dif < 0;
      cambio = dif == 0 ? 'Igual que la vez anterior' : '${dif > 0 ? '+' : ''}${_num(dif)} ${pr['unidad']} · ${mejora ? 'mejoró' : 'bajó'}';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${pr['nombre']}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: p.texto),
                ),
              ),
              if (puedeEditar) TextButton.icon(onPressed: alMarca, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Anotar')),
            ],
          ),
          if (valores.isEmpty)
            Text('Sin resultados todavía.', style: TextStyle(color: p.textoSecundario))
          else ...[
            Text('Última: ${_num(valores.last)} ${pr['unidad']} · Mejor: ${_num(pr['mejor'] as num)} ${pr['unidad']}', style: TextStyle(color: p.texto)),
            if (cambio != null) Text(cambio, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
            if (valores.length >= 2)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: CustomPaint(painter: _Curva(valores, p.marca, p.tarjetaBorde)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Curva simple del progreso de una prueba.
class _Curva extends CustomPainter {
  _Curva(this.v, this.color, this.base);
  final List<double> v;
  final Color color, base;
  @override
  void paint(Canvas c, Size s) {
    final mn = v.reduce((a, b) => a < b ? a : b), mx = v.reduce((a, b) => a > b ? a : b);
    final rango = (mx - mn) == 0 ? 1 : mx - mn;
    Offset pt(int i) => Offset(v.length == 1 ? s.width / 2 : i * s.width / (v.length - 1), s.height - 6 - (v[i] - mn) / rango * (s.height - 12));
    c.drawLine(Offset(0, s.height - 1), Offset(s.width, s.height - 1), Paint()..color = base);
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < v.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    c.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < v.length; i++) {
      c.drawCircle(pt(i), 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_Curva o) => o.v != v || o.color != color;
}

class _TarjetaTema extends StatelessWidget {
  const _TarjetaTema({required this.t});
  final Map<String, dynamic> t;
  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final items = [for (final x in (t['items'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    final notas = [
      for (final x in items)
        if (x['nota'] != null) (x['nota'] as num).toInt(),
    ];
    String? tendencia;
    if (notas.length >= 2) {
      final d = notas.last - notas[notas.length - 2];
      tendencia = d == 0 ? 'igual que la vez anterior' : (d > 0 ? 'mejoró ${d > 0 ? '+$d' : '$d'}' : 'bajó $d');
    }
    final ultimo = items.isEmpty ? null : items.last;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${t['tema']}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: p.texto),
                ),
              ),
              if (notas.isNotEmpty)
                Text(
                  '${notas.last}/10',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.marcaTexto),
                ),
            ],
          ),
          if (tendencia != null) Text('${notas.length} notas · $tendencia', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
          if (ultimo != null && '${ultimo['comentario'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('"${ultimo['comentario']}"', style: TextStyle(height: 1.35, color: p.texto)),
            ),
          if (ultimo != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${ultimo['coachNombre']} · ${Fechas.corta(DateTime.parse('${ultimo['fecha']}'))}',
                style: TextStyle(fontSize: 12.5, color: p.textoSecundario),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pruebas del coach: crear, editar y a quién se le hacen.
class _PruebasCoach extends StatefulWidget {
  const _PruebasCoach({required this.sesion, required this.jugadorxs});
  final Sesion sesion;
  final List<Map<String, dynamic>> jugadorxs;
  @override
  State<_PruebasCoach> createState() => _PruebasCoachState();
}

class _PruebasCoachState extends State<_PruebasCoach> {
  List<Map<String, dynamic>>? _l;

  @override
  void initState() {
    super.initState();
    _llamar({'accion': 'listar'});
  }

  Future<void> _llamar(Map<String, Object?> q) async {
    try {
      final r = await widget.sesion.api.post('coachPruebas', q);
      if (r['exito'] == false) throw ApiException('${r['error']}');
      if (mounted) setState(() => _l = [for (final x in (r['pruebas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)]);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCoach(e))));
    }
  }

  Future<void> _editar([Map<String, dynamic>? x]) async {
    final nombre = TextEditingController(text: '${x?['nombre'] ?? ''}');
    final unidad = TextEditingController(text: '${x?['unidad'] ?? 'vueltas'}');
    var mas = x?['masEsMejor'] != false;
    var activa = x?['activa'] != false;
    var visible = '${x?['visible'] ?? 'jugadorx,'}';
    final personas = <String>{
      ...[for (final u in (x?['personas'] as List? ?? const [])) '$u'],
    };
    final ok = await showModalBottomSheet<bool>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(c).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(x == null ? 'Nueva prueba' : 'Editar prueba', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Algo que se mide cada vez para ver el progreso. Ej. "5 minutos: vueltas".',
                  style: TextStyle(fontSize: 13, color: c.pivot.textoSecundario),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nombre,
                  autofocus: x == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Vueltas en 5 minutos'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unidad,
                  decoration: const InputDecoration(labelText: 'Se mide en', hintText: 'vueltas, segundos, repeticiones'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Más es mejor'),
                  subtitle: Text(mas ? 'Ej. más vueltas' : 'Menos es mejor, ej. menos segundos'),
                  value: mas,
                  onChanged: (v) => set(() => mas = v),
                ),
                const Text('¿A quiénes?', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(label: const Text('A todxs'), selected: personas.isEmpty, onSelected: (_) => set(personas.clear)),
                    for (final j in widget.jugadorxs)
                      FilterChip(
                        label: Text('${j['nombre']}'),
                        selected: personas.contains(j['username']),
                        onSelected: (v) => set(() => v ? personas.add('${j['username']}') : personas.remove(j['username'])),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('¿Quién ve los resultados?', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                QuienVe(valor: visible, alCambiar: (v) => set(() => visible = v)),
                if (x != null)
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('En uso'), value: activa, onChanged: (v) => set(() => activa = v)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Guardar')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || nombre.text.trim().isEmpty) return;
    await _llamar({
      'accion': 'guardar',
      'id': x?['id'],
      'nombre': nombre.text.trim(),
      'unidad': unidad.text.trim(),
      'masEsMejor': mas,
      'activa': activa,
      'visible': visible,
      'personas': jsonEncode(personas.toList()),
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _l;
    if (l == null) return const EsqueletoFilas();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pruebas que se repiten para ver el progreso, como contar vueltas en 5 minutos. Los resultados se anotan en la ficha de cada persona.',
          style: TextStyle(fontSize: 14, height: 1.35, color: p.texto),
        ),
        const SizedBox(height: 10),
        for (final x in l)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.timer_outlined, color: x['activa'] == false ? p.apagado : p.marcaTexto),
            title: Text(
              '${x['nombre']}',
              style: TextStyle(fontWeight: FontWeight.w700, color: x['activa'] == false ? p.apagado : p.texto),
            ),
            subtitle: Text(
              [
                'En ${x['unidad']}',
                (x['personas'] as List? ?? const []).isEmpty ? 'a todxs' : '${(x['personas'] as List).length} personas',
                'Lo ven: ${textoQuienVe('${x['visible']}')}',
              ].join(' · '),
            ),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: () => _editar(x),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: _editar, icon: const Icon(Icons.add_rounded), label: const Text('Nueva prueba')),
        ),
      ],
    );
  }
}

/// Nota del 1 al 10 que siempre cabe en el ancho (Victor, 2026-11-17: los
/// números se cortaban y costaba tocarlos). Tocar la elegida la quita.
class EscalaDiez extends StatelessWidget {
  const EscalaDiez({super.key, required this.valor, required this.alCambiar});
  final int? valor;
  final ValueChanged<int?> alCambiar;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Row(
      children: [
        for (var n = 1; n <= 10; n++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Semantics(
                button: true,
                selected: valor == n,
                label: 'Nota $n',
                child: InkWell(
                  borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                  onTap: () => alCambiar(valor == n ? null : n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: valor == n ? p.marca : p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                    child: Text(
                      '$n',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: valor == n ? p.sobreMarca : p.sobreSuave),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Evaluar a quienes vinieron (Victor, 2026-11-17) ────────────────────────
// Una persona por pantalla, deslizando: qué trabajó, cómo le fue (1 a 10),
// comentario por voz o texto, prueba del día y habilidades. Pocos toques.

class EvaluarScreen extends StatefulWidget {
  const EvaluarScreen({super.key, required this.sesion, required this.idEvento, required this.fecha, required this.titulo});
  final Sesion sesion;
  final String idEvento, fecha, titulo;

  static Future<void> abrir(BuildContext context, Sesion s, Map<String, dynamic> pend) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EvaluarScreen(sesion: s, idEvento: '${pend['idEvento']}', fecha: '${pend['fecha']}', titulo: tituloPendiente(pend)),
    ),
  );

  @override
  State<EvaluarScreen> createState() => _EvaluarScreenState();
}

/// "Ayer · Entrenamiento", "Lunes 16 · Scrimmage".
String tituloPendiente(Map<String, dynamic> x) {
  final f = DateTime.tryParse('${x['fecha']}');
  final hoy = Fechas.hoy();
  final dia = f == null
      ? ''
      : (Fechas.iso(f) == Fechas.iso(hoy) ? 'Hoy' : (Fechas.iso(f) == Fechas.iso(hoy.subtract(const Duration(days: 1))) ? 'Ayer' : Fechas.corta(f)));
  return [dia, if ('${x['tipo'] ?? ''}'.isNotEmpty) '${x['tipo']}'].join(' · ');
}

class _EvaluarScreenState extends State<EvaluarScreen> {
  Sesion get s => widget.sesion;
  final _pagina = PageController();
  int _i = 0;
  bool _cargando = true, _guardando = false;
  String? _error_;
  List<Map<String, dynamic>> _personas = [];
  List<String> _temas = [];
  List<Map<String, dynamic>> _pruebas = [];
  final Set<String> _hechos = {};
  String _visible = 'jugadorx,';

  // Lo de cada persona.
  final Map<String, Set<String>> _temasDe = {};
  final Map<String, int?> _nota = {};
  final Map<String, TextEditingController> _com = {};
  final Set<String> _porVoz = {};
  final Map<String, Map<String, String>> _marcas = {}; // persona → prueba → valor
  final Map<String, Map<String, String>> _niveles = {}; // persona → habilidad → nivel nuevo

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _pagina.dispose();
    for (final c in _com.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final res = await Future.wait([
        s.api.get('coachFeedbackEvento', {'idEvento': widget.idEvento}),
        s.api.get('coachPruebas', {'accion': 'listar'}).catchError((_) => <String, dynamic>{}),
      ]);
      final r = res[0];
      if (r['exito'] == false) throw ApiException('${r['error']}');
      final hecho = {for (final h in (r['hecho'] as List? ?? const [])) '${(h as Map)['username']}'};
      final personas = [for (final x in (r['personas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
      // Primero quienes faltan evaluar.
      personas.sort((a, b) => (hecho.contains(a['username']) ? 1 : 0).compareTo(hecho.contains(b['username']) ? 1 : 0));
      if (!mounted) return;
      setState(() {
        _personas = personas;
        _hechos.addAll(hecho);
        _temas = [for (final t in (r['temas'] as List? ?? const [])) '$t'];
        _pruebas = [
          for (final p in (res[1]['pruebas'] as List? ?? const []))
            if ((p as Map)['activa'] != false) Map<String, dynamic>.from(p),
        ];
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error_ = errorCoach(e));
    }
  }

  TextEditingController _c(String u) => _com[u] ??= TextEditingController();

  bool _tieneAlgo(String u) =>
      _nota[u] != null ||
      (_temasDe[u]?.isNotEmpty ?? false) ||
      _c(u).text.trim().isNotEmpty ||
      (_marcas[u]?.values.any((v) => v.trim().isNotEmpty) ?? false) ||
      (_niveles[u]?.isNotEmpty ?? false);

  Future<void> _habilidades(Map<String, dynamic> x) async {
    final u = '${x['username']}';
    final elegidas = await showModalBottomSheet<Map<String, String>>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _HojaHabilidades(sesion: s, username: u, nombre: '${x['nombre']}', cambios: {...?_niveles[u]}),
    );
    if (elegidas != null && mounted) setState(() => _niveles[u] = elegidas);
  }

  /// Guarda lo de esta persona y pasa a la siguiente.
  Future<void> _guardarYSeguir() async {
    final x = _personas[_i];
    final u = '${x['username']}';
    if (_tieneAlgo(u)) {
      setState(() => _guardando = true);
      final m = ScaffoldMessenger.of(context);
      try {
        final temas = (_temasDe[u]?.isNotEmpty ?? false) ? _temasDe[u]!.toList() : ['General'];
        final com = _c(u).text.trim();
        if (_nota[u] != null || com.isNotEmpty || (_temasDe[u]?.isNotEmpty ?? false)) {
          final r = await s.api.post('coachFeedbackEvento', {
            'accion': 'guardar',
            'idEvento': widget.idEvento,
            'fecha': widget.fecha,
            'visible': _visible,
            'items': jsonEncode([
              for (final (i, t) in temas.indexed)
                {'username': u, 'tema': t, 'nota': _nota[u], 'comentario': i == 0 ? com : '', 'porVoz': _porVoz.contains(u), 'trabajo': true},
            ]),
          });
          if (r['exito'] == false) throw ApiException('${r['error']}');
        }
        for (final e in (_marcas[u] ?? const <String, String>{}).entries) {
          if (e.value.trim().isEmpty) continue;
          final r = await s.api.post('coachPruebas', {
            'accion': 'marca',
            'pruebaId': e.key,
            'username': u,
            'valor': e.value.trim(),
            'idEvento': widget.idEvento,
            'fecha': widget.fecha,
          });
          if (r['exito'] == false) throw ApiException('${r['error']}');
        }
        for (final e in (_niveles[u] ?? const <String, String>{}).entries) {
          await s.api.post('coachGuardar', {'accion': 'evaluar', 'username': u, 'habilidadId': e.key, 'nivel': e.value});
        }
        _hechos.add(u);
        _marcas.remove(u);
        _niveles.remove(u);
      } catch (e) {
        m.showSnackBar(SnackBar(content: Text(errorCoach(e))));
        if (mounted) setState(() => _guardando = false);
        return;
      }
      if (!mounted) return;
      setState(() => _guardando = false);
    }
    _siguiente();
  }

  void _siguiente() {
    if (_i < _personas.length - 1) {
      _pagina.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      final n = _hechos.length;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Listo: $n de ${_personas.length} ${_personas.length == 1 ? 'persona evaluada' : 'personas evaluadas'}.')));
    }
  }

  Future<void> _elegirVisible() async {
    await showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (h) => StatefulBuilder(
        builder: (h, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¿Quién ve las notas de hoy?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                QuienVe(
                  valor: _visible,
                  alCambiar: (v) {
                    set(() {});
                    setState(() => _visible = v);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: () => Navigator.of(h).pop(), child: const Text('Listo')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Scaffold(
      // Solo el título arriba (Victor, 2026-11-20: se cortaba con "quién lo ve" al lado).
      appBar: AppBar(
        title: Text('Evaluar · ${widget.titulo}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _cargando
            ? (_error_ == null ? const Esqueleto(key: ValueKey('c')) : Center(key: const ValueKey('e'), child: Text(_error_!)))
            : _personas.isEmpty
            ? Center(
                key: const ValueKey('v'),
                child: Text('Nadie de tus equipos vino a este evento.', style: TextStyle(color: p.textoSecundario)),
              )
            : Column(
                key: const ValueKey('l'),
                children: [
                  // Progreso: una rayita por persona.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        for (var k = 0; k < _personas.length; k++)
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              decoration: BoxDecoration(
                                color: _hechos.contains(_personas[k]['username']) ? p.marca : (k == _i ? p.sobreSuave : p.suave),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pagina,
                      itemCount: _personas.length,
                      onPageChanged: (k) => setState(() => _i = k),
                      itemBuilder: (context, k) => _persona(context, _personas[k]),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          TextButton(onPressed: _guardando ? null : _siguiente, child: const Text('Saltar')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: _guardando ? null : _guardarYSeguir,
                              child: _guardando
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(_i == _personas.length - 1 ? 'Guardar y terminar' : 'Guardar y seguir'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _persona(BuildContext context, Map<String, dynamic> x) {
    final p = context.pivot;
    final u = '${x['username']}';
    final temas = {..._temas, ...?_temasDe[u]}.toList();
    final pruebas = [
      for (final pr in _pruebas)
        if ((pr['personas'] as List? ?? const []).isEmpty || (pr['personas'] as List).contains(u)) pr,
    ];
    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Text(
        t,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Row(
          children: [
            AvatarPersona(nombre: '${x['nombre']}', foto: '${x['foto'] ?? ''}', tamano: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${x['nombre']}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.texto),
                  ),
                  Text(
                    '${_i + 1} de ${_personas.length}${_hechos.contains(u) ? ' · ya evaluada hoy' : ''}',
                    style: TextStyle(fontSize: 13, color: p.textoSecundario),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Todo es opcional: llena solo lo que quieras (Victor, 2026-11-20).
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Llena solo lo que quieras: cómo le fue, una nota, lo que trabajó o sus habilidades. Lo ven: ${textoQuienVe(_visible)}.',
                  style: TextStyle(fontSize: 13, color: p.sobreSuave),
                ),
              ),
              TextButton(onPressed: _elegirVisible, child: const Text('Cambiar')),
            ],
          ),
        ),
        titulo('¿CÓMO LE FUE? (1 A 10)'),
        EscalaDiez(valor: _nota[u], alCambiar: (n) => setState(() => _nota[u] = n)),
        titulo('NOTA'),
        TextField(
          controller: _c(u),
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Escribe o mantén presionado el micrófono',
            suffixIcon: BotonDictar(controlador: _c(u), alDictar: () => setState(() => _porVoz.add(u))),
          ),
        ),
        titulo('LO QUE TRABAJÓ'),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Lo del plan del evento que trabajó esta persona, o agrega lo suyo (su plan personal de hoy).',
            style: TextStyle(fontSize: 13, color: p.textoSecundario),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in temas)
              FilterChip(
                label: Text(t),
                selected: _temasDe[u]?.contains(t) ?? false,
                onSelected: (v) => setState(() => v ? (_temasDe[u] ??= {}).add(t) : _temasDe[u]?.remove(t)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar otro'),
              onPressed: () async {
                final ctl = TextEditingController();
                final t = await showDialog<String>(
                  context: context,
                  builder: (d) => AlertDialog(
                    scrollable: true,
                    title: const Text('Agregar al plan'),
                    content: TextField(
                      controller: ctl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Ej. Frenos'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.of(d).pop(ctl.text.trim()), child: const Text('Agregar')),
                    ],
                  ),
                );
                if (t != null && t.isNotEmpty) setState(() => (_temasDe[u] ??= {}).add(t));
              },
            ),
          ],
        ),
        if (pruebas.isNotEmpty) ...[
          titulo('PRUEBAS DE HOY'),
          for (final pr in pruebas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => (_marcas[u] ??= {})['${pr['id']}'] = v,
                decoration: InputDecoration(labelText: '${pr['nombre']}', suffixText: '${pr['unidad'] ?? ''}', helperText: 'Vacío si no la hizo'),
              ),
            ),
        ],
        titulo('HABILIDADES'),
        OutlinedButton.icon(
          onPressed: () => _habilidades(x),
          icon: const Icon(Icons.checklist_rounded),
          label: Text((_niveles[u]?.isEmpty ?? true) ? 'Marcar habilidades' : '${_niveles[u]!.length} habilidades marcadas'),
        ),
      ],
    );
  }
}

/// Habilidades de una persona: tocar cambia Aún no → En proceso → Logrado.
class _HojaHabilidades extends StatefulWidget {
  const _HojaHabilidades({required this.sesion, required this.username, required this.nombre, required this.cambios});
  final Sesion sesion;
  final String username, nombre;
  final Map<String, String> cambios;
  @override
  State<_HojaHabilidades> createState() => _HojaHabilidadesState();
}

class _HojaHabilidadesState extends State<_HojaHabilidades> {
  List<Map<String, dynamic>>? _habs;
  late final Map<String, String> _cambios = widget.cambios;
  String _q = '';

  @override
  void initState() {
    super.initState();
    widget.sesion.api
        .get('getFichaDeportiva', {'username': widget.username})
        .then(
          (r) {
            if (mounted) setState(() => _habs = [for (final h in (r['habilidades'] as List? ?? const [])) Map<String, dynamic>.from(h as Map)]);
          },
          onError: (_) {
            if (mounted) setState(() => _habs = const []);
          },
        );
  }

  String? _nivel(Map<String, dynamic> h) => _cambios['${h['id']}'] ?? (h['nivel'] as String?);

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final q = _q.trim().toLowerCase();
    final l = (_habs ?? const <Map<String, dynamic>>[]).where((h) => q.isEmpty || '${h['nombre']} ${h['categoria']}'.toLowerCase().contains(q)).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Habilidades de ${widget.nombre}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar habilidad'),
              ),
            ),
            Expanded(
              child: _habs == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      children: [
                        for (final h in l)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${h['nombre']}'),
                            subtitle: Text('${h['categoria']}'),
                            trailing: SegmentedButton<String>(
                              showSelectedIcon: false,
                              emptySelectionAllowed: true,
                              style: const ButtonStyle(visualDensity: VisualDensity.compact),
                              segments: const [
                                ButtonSegment(value: 'no', label: Text('No')),
                                ButtonSegment(value: 'proceso', label: Text('Proceso')),
                                ButtonSegment(value: 'logrado', label: Text('Sí')),
                              ],
                              selected: {?_nivel(h)},
                              onSelectionChanged: (v) => setState(() {
                                if (v.isNotEmpty) _cambios['${h['id']}'] = v.first;
                              }),
                            ),
                          ),
                        if (l.isEmpty)
                          Center(
                            child: Text('No hay habilidades.', style: TextStyle(color: p.textoSecundario)),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton(onPressed: () => Navigator.of(context).pop(_cambios), child: const Text('Listo')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dictado como en WhatsApp (Victor, 2026-11-17): mientras mantienes
/// presionado el micrófono, escucha y escribe en [controlador]; al soltar,
/// para. Un toque solo explica cómo se usa.
class BotonDictar extends StatefulWidget {
  const BotonDictar({super.key, required this.controlador, this.alDictar});
  final TextEditingController controlador;

  /// Se llama al terminar de dictar (para marcar "por voz").
  final VoidCallback? alDictar;
  @override
  State<BotonDictar> createState() => _BotonDictarState();
}

class _BotonDictarState extends State<BotonDictar> {
  final _voz = SpeechToText();
  bool _escuchando = false;
  String _antes = '';

  @override
  void dispose() {
    _voz.cancel();
    super.dispose();
  }

  Future<void> _empezar() async {
    final m = ScaffoldMessenger.of(context);
    final ok = await _voz.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) setState(() => _escuchando = false);
      },
      onError: (_) {
        if (mounted) setState(() => _escuchando = false);
      },
    );
    if (!ok) {
      m.showSnackBar(const SnackBar(content: Text('Este teléfono no permite dictar. Revisa el permiso del micrófono.')));
      return;
    }
    HapticFeedback.mediumImpact();
    _antes = widget.controlador.text.trim();
    if (mounted) setState(() => _escuchando = true);
    await _voz.listen(
      listenOptions: SpeechListenOptions(partialResults: true, listenMode: ListenMode.dictation, localeId: 'es_ES'),
      onResult: (r) {
        final t = r.recognizedWords;
        widget.controlador.text = _antes.isEmpty ? t : '$_antes $t';
        widget.controlador.selection = TextSelection.collapsed(offset: widget.controlador.text.length);
      },
    );
  }

  Future<void> _soltar() async {
    await _voz.stop();
    if (!mounted) return;
    setState(() => _escuchando = false);
    widget.alDictar?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Semantics(
      button: true,
      label: 'Mantén presionado para dictar',
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Mantén presionado el micrófono mientras hablas.'))),
        onLongPressStart: (_) => _empezar(),
        onLongPressEnd: (_) => _soltar(),
        onLongPressCancel: _soltar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.all(4),
          width: _escuchando ? 48 : 40,
          height: _escuchando ? 48 : 40,
          decoration: BoxDecoration(color: _escuchando ? p.marca : p.suave, shape: BoxShape.circle),
          child: Icon(Icons.mic_rounded, color: _escuchando ? p.sobreMarca : p.sobreSuave),
        ),
      ),
    );
  }
}
