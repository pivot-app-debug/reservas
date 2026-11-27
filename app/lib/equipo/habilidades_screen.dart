import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/espacio_barra.dart';

import '../coach/coach_screen.dart' show BotonDictar, FichaDeportivaScreen, QuienVe, barraCoach, errorCoach;
import '../core/api.dart';
import '../core/deporte.dart';
import '../core/esqueleto.dart';
import '../core/fechas.dart';
import '../core/pronombres.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../eventos/eventos_repo.dart';
import '../eventos/widgets_comunes.dart';
import '../sesion/sesion.dart';

/// Habilidades en Equipo (Victor, 2026-11-19): salieron de Coach. Una sola
/// sección con dos vistas: "Personas" (buscador con filtros por nivel, equipo
/// y asistencia, selección múltiple, asignar habilidades y comentar por
/// persona, escrito o dictado) y "Lista" (habilidades básicas y avanzadas en
/// desplegables). Solo para coaches aprobadxs.

/// Niveles en Coach (Victor, 2026-11-17).
const nivelesCoach = {'sin': 'Aprendiendo lo básico', 'basicas': 'Habilidades básicas', 'avanzadas': 'Habilidades avanzadas'};

class HabilidadesEquipoScreen extends StatefulWidget {
  const HabilidadesEquipoScreen({super.key, required this.sesion, this.lista = false});
  final Sesion sesion;

  /// Abre directo en la lista de habilidades (desde Coach).
  final bool lista;
  @override
  State<HabilidadesEquipoScreen> createState() => _HabilidadesEquipoScreenState();
}

class _HabilidadesEquipoScreenState extends State<HabilidadesEquipoScreen> {
  late String _vista = widget.lista ? 'lista' : 'personas';
  final _lista = GlobalKey<_ListaHabilidadesState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: barraCoach(
        'Habilidades',
        abajo: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'personas', icon: Icon(Icons.groups_rounded), label: Text('Marcar habilidades')),
                  ButtonSegment(value: 'lista', icon: Icon(Icons.checklist_rounded), label: Text('Lista')),
                ],
                selected: {_vista},
                onSelectionChanged: (v) => setState(() => _vista = v.first),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (h, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: a, child: h),
        ),
        child: _vista == 'lista'
            ? FloatingActionButton.extended(
                key: const ValueKey('fab'),
                onPressed: () => _lista.currentState?.editar(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Habilidad'),
              )
            : const SizedBox.shrink(key: ValueKey('sin')),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (h, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.03, 0), end: Offset.zero).animate(a),
            child: h,
          ),
        ),
        child: _vista == 'lista'
            ? _ListaHabilidades(key: _lista, sesion: widget.sesion)
            : _MarcarPersonas(key: const ValueKey('personas'), sesion: widget.sesion),
      ),
    );
  }
}

/// Alto de la barra con el selector de vistas.
double _arriba(BuildContext context) => altoBarra(context) + 8;

// ─── Lista de habilidades (editable) ───────────────────────────────────────

class _ListaHabilidades extends StatefulWidget {
  const _ListaHabilidades({super.key, required this.sesion});
  final Sesion sesion;
  @override
  State<_ListaHabilidades> createState() => _ListaHabilidadesState();
}

class _ListaHabilidadesState extends State<_ListaHabilidades> {
  List<Map<String, dynamic>>? _l;
  final Set<String> _abiertos = {'basica'};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.sesion.api.get('getHabilidades');
      if (mounted) setState(() => _l = [for (final h in (r['habilidades'] as List? ?? const [])) Map<String, dynamic>.from(h as Map)]);
    } catch (_) {
      if (mounted) setState(() => _l ??= const []);
    }
  }

  /// Nueva o editar. [nivelInicial] = desplegable desde el que se agrega.
  Future<void> editar([Map<String, dynamic>? h, String? categoria, String? nivelInicial]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditarHabilidadScreen(
          sesion: widget.sesion,
          habilidad: h,
          categoria: categoria,
          nivelInicial: nivelInicial,
          alGuardar: (resultado) async {
            await widget.sesion.api.post('coachGuardar', {
              'accion': 'habilidad',
              'id': h?['id'],
              'nombre': resultado['nombre'],
              'categoria': resultado['categoria'],
              'activa': resultado['activa'],
              'nivel': resultado['nivel'],
            });
            setState(() => _abiertos.add(resultado['nivel']));
            _cargar();
          },
        ),
      ),
    );
    if (ok == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _l;
    if (l == null) return const Esqueleto(key: ValueKey('c'));
    Map<String, List<Map<String, dynamic>>> porGrupo(String nivel) {
      final g = <String, List<Map<String, dynamic>>>{};
      for (final h in l.where((h) => '${h['nivel'] ?? 'basica'}' == nivel)) {
        (g['${h['categoria']}'] ??= []).add(h);
      }
      return g;
    }

    Widget desplegable(String nivel, String titulo, String sub) {
      final g = porGrupo(nivel);
      final n = g.values.fold<int>(0, (a, x) => a + x.length);
      final abierto = _abiertos.contains(nivel);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: p.tarjeta,
          borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() => abierto ? _abiertos.remove(nivel) : _abiertos.add(nivel)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$titulo ($n)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.texto),
                            ),
                            const SizedBox(height: 2),
                            Text(sub, style: TextStyle(fontSize: 12.5, height: 1.3, color: p.textoSecundario)),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: abierto ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(Icons.expand_more_rounded, color: p.textoSecundario),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !abierto
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (g.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('Todavía no hay habilidades aquí.', style: TextStyle(color: p.textoSecundario)),
                              ),
                            for (final e in g.entries) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.key.toUpperCase(),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Agregar a ${e.key}',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => editar(null, e.key, nivel),
                                    icon: const Icon(Icons.add_rounded, size: 20),
                                  ),
                                ],
                              ),
                              for (final h in e.value)
                                ListTile(
                                  contentPadding: const EdgeInsets.only(right: 8),
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
                                  onTap: () => editar(h),
                                ),
                            ],
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => editar(null, null, nivel),
                                icon: const Icon(Icons.add_rounded),
                                label: Text(nivel == 'avanzada' ? 'Agregar habilidad avanzada' : 'Agregar habilidad básica'),
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

    return ListView(
      key: const ValueKey('lista'),
      padding: EdgeInsets.fromLTRB(16, _arriba(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
      children: [
        Text(
          'Vale para todas las fichas de la liga. Apagar una habilidad no borra su historial.',
          style: TextStyle(fontSize: 14, height: 1.35, color: p.texto),
        ),
        const SizedBox(height: 12),
        desplegable(
          'basica',
          'Habilidades básicas',
          Deporte.esDerby
              ? 'Parten de las habilidades mínimas de WFTDA. Puedes editarlas, sumar otras o apagarlas.'
              : 'Las básicas de tu deporte. Puedes editarlas, sumar otras o apagarlas.',
        ),
        desplegable('avanzada', 'Habilidades avanzadas', 'Las escribe lx entrenadorx: lo que se trabaja después de las básicas.'),
      ],
    );
  }
}

// ─── Marcar habilidades: buscador de personas ──────────────────────────────

class _MarcarPersonas extends StatefulWidget {
  const _MarcarPersonas({super.key, required this.sesion});
  final Sesion sesion;
  @override
  State<_MarcarPersonas> createState() => _MarcarPersonasState();
}

class _MarcarPersonasState extends State<_MarcarPersonas> {
  Map<String, dynamic>? _d;
  String? _error_;
  String _q = '';
  String? _nivel, _equipo;

  /// Asistencia en 30 días: null = todas, 75 / 50 = "o más", -50 = menos de 50 %.
  int? _asis;
  final Set<String> _sel = {};
  Sesion get s => widget.sesion;

  @override
  void initState() {
    super.initState();
    _cargar();
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

  List<Map<String, dynamic>> get _personas => [for (final x in (_d?['jugadorxs'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
  List<Map<String, dynamic>> get _habilidades => [for (final h in (_d?['habilidades'] as List? ?? const [])) Map<String, dynamic>.from(h as Map)];

  /// Eventos de los últimos 30 días que ya pasaron (base del %). Sin
  /// eventos cargados, se compara con quien más vino.
  int _base(List<Map<String, dynamic>> l) {
    final repo = EventosRepo.actual;
    final hoy = Fechas.hoy();
    final desde = hoy.subtract(const Duration(days: 30));
    final n = repo == null ? 0 : repo.eventos.where((e) => !e.cancelado && e.finalizado && !e.fecha.isBefore(desde)).length;
    final max = l.fold<int>(0, (a, x) => math.max(a, (x['asistencias30'] as num? ?? 0).toInt()));
    return math.max(n, max);
  }

  int _pct(Map<String, dynamic> x, int base) => base == 0 ? 0 : (((x['asistencias30'] as num? ?? 0) * 100) / base).round().clamp(0, 100);

  bool _pasaAsis(Map<String, dynamic> x, int base) {
    final a = _asis;
    if (a == null) return true;
    final v = _pct(x, base);
    return a < 0 ? v < -a : v >= a;
  }

  /// Nivel a mano (o volver a calcularlo). Se abre manteniendo presionada la fila.
  Future<void> _cambiarNivel(Map<String, dynamic> x) async {
    final v = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (h) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Nivel de ${x['nombre']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.auto_mode_rounded),
              title: const Text('Calcularlo con sus habilidades'),
              trailing: x['nivelAMano'] != true ? Icon(Icons.check_rounded, color: h.pivot.marcaTexto) : null,
              onTap: () => Navigator.of(h).pop(''),
            ),
            for (final e in nivelesCoach.entries)
              ListTile(
                title: Text(e.value),
                trailing: x['nivelAMano'] == true && x['nivel'] == e.key ? Icon(Icons.check_rounded, color: h.pivot.marcaTexto) : null,
                onTap: () => Navigator.of(h).pop(e.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (v == null) return;
    try {
      await s.api.post('coachGuardar', {'accion': 'nivel', 'username': '${x['username']}', 'nivel': v});
      _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCoach(e))));
    }
  }

  List<Map<String, dynamic>> get _seleccionadas => _personas.where((x) => _sel.contains('${x['username']}')).toList();

  Future<void> _asignar() async {
    final ok = await Navigator.of(context).push<bool>(_ruta(_ElegirHabilidadesScreen(sesion: s, personas: _seleccionadas, habilidades: _habilidades)));
    if (ok == true) {
      setState(_sel.clear);
      _cargar();
    }
  }

  Future<void> _comentar() async {
    final ok = await Navigator.of(context).push<bool>(_ruta(_ComentariosScreen(sesion: s, personas: _seleccionadas)));
    if (ok == true) setState(_sel.clear);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    if (_d == null) {
      return _error_ == null ? const Esqueleto(key: ValueKey('c'), forma: FormaEsqueleto.lista) : Center(key: const ValueKey('e'), child: Text(_error_!));
    }
    final total = (_d?['totalHabilidades'] as num?)?.toInt() ?? 0;
    final todos = _personas;
    final base = _base(todos);
    final q = _q.trim().toLowerCase();
    final equipos = {for (final x in todos) '${x['equipo']}'}.where((e) => e.isNotEmpty).toList()..sort();
    final l = todos
        .where(
          (x) =>
              (_nivel == null || x['nivel'] == _nivel) &&
              (_equipo == null || x['equipo'] == _equipo) &&
              _pasaAsis(x, base) &&
              (q.isEmpty || '${x['nombre']} ${x['username']}'.toLowerCase().contains(q)),
        )
        .toList();
    final todosVisibles = l.isNotEmpty && l.every((x) => _sel.contains('${x['username']}'));
    final sel = _seleccionadas;

    Widget fila(String titulo, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              titulo,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [for (final c in chips) Padding(padding: const EdgeInsets.only(right: 6), child: c)],
            ),
          ),
        ],
      ),
    );

    return Stack(
      key: const ValueKey('personas'),
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16, _arriba(context), 16, 120 + MediaQuery.paddingOf(context).bottom),
          children: [
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar persona'),
            ),
            const SizedBox(height: 12),
            fila('NIVEL', [
              for (final (k, t) in [(null, 'Todxs'), ...nivelesCoach.entries.map((e) => (e.key, e.value))])
                ChoiceChip(
                  label: Text('$t (${k == null ? todos.length : todos.where((x) => x['nivel'] == k).length})'),
                  selected: _nivel == k,
                  onSelected: (_) => setState(() => _nivel = k),
                ),
            ]),
            if (equipos.length > 1)
              fila('EQUIPO', [
                ChoiceChip(label: const Text('Todos'), selected: _equipo == null, onSelected: (_) => setState(() => _equipo = null)),
                for (final e in equipos) ChoiceChip(label: Text(e), selected: _equipo == e, onSelected: (_) => setState(() => _equipo = e)),
              ]),
            fila('ASISTENCIA EN 30 DÍAS', [
              for (final (k, t) in const [(null, 'Todas'), (75, '75 % o más'), (50, '50 % o más'), (-50, 'Menos de 50 %')])
                ChoiceChip(label: Text(t), selected: _asis == k, onSelected: (_) => setState(() => _asis = k)),
            ]),
            // Seleccionadas: se quitan con la X (Victor, 2026-11-18).
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: sel.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final x in sel)
                            InputChip(
                              avatar: AvatarPersona(nombre: '${x['nombre']}', foto: '${x['foto'] ?? ''}', tamano: 24),
                              label: Text('${x['nombre']}'),
                              tooltip: 'Quitar de la selección',
                              onDeleted: () => setState(() => _sel.remove('${x['username']}')),
                            ),
                        ],
                      ),
                    ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(l.length == 1 ? '1 persona' : '${l.length} personas', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                ),
                if (l.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      final us = l.map((x) => '${x['username']}');
                      todosVisibles ? _sel.removeAll(us) : _sel.addAll(us);
                    }),
                    child: Text(todosVisibles ? 'Quitar a todxs' : 'Elegir a todxs'),
                  ),
              ],
            ),
            if (l.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    todos.isEmpty ? 'No hay jugadorxs en tus equipos.' : 'Nadie coincide con estos filtros.',
                    style: TextStyle(color: p.textoSecundario),
                  ),
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
                    nivelesCoach['${x['nivel']}'] ?? '',
                    if ('${x['estado']}' != 'Activx') conPronombres('${x['estado']}', x['pronombres']),
                    '${_pct(x, base)} % de asistencia',
                    if (total > 0) '${x['logradas']} de $total habilidades',
                  ].where((t) => t.isNotEmpty).join(' · '),
                ),
                onTap: () => setState(() => _sel.contains('${x['username']}') ? _sel.remove('${x['username']}') : _sel.add('${x['username']}')),
                onLongPress: () => _cambiarNivel(x),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Progreso',
                      icon: const Icon(Icons.badge_outlined),
                      onPressed: () async {
                        await Navigator.of(context).push(_ruta(FichaDeportivaScreen(sesion: s, username: '${x['username']}', nombre: '${x['nombre']}')));
                        _cargar();
                      },
                    ),
                    Checkbox(
                      value: _sel.contains('${x['username']}'),
                      onChanged: (v) => setState(() => v == true ? _sel.add('${x['username']}') : _sel.remove('${x['username']}')),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Mantén presionada una persona para cambiar su nivel a mano.', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
            ),
          ],
        ),
        // Acciones con la selección: aparecen deslizando desde abajo.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSlide(
            offset: sel.isEmpty ? const Offset(0, 1.2) : Offset.zero,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: sel.isEmpty ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: sel.isEmpty,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                            onPressed: _comentar,
                            icon: const Icon(Icons.mic_none_rounded),
                            label: const Text('Comentar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                            onPressed: _asignar,
                            icon: const Icon(Icons.done_all_rounded),
                            label: Text('Asignar habilidades (${sel.length})'),
                          ),
                        ),
                      ],
                    ),
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

/// Transición suave (fundido y deslizamiento) para las pantallas de esta sección.
Route<T> _ruta<T>(Widget pantalla) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 280),
  reverseTransitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (_, _, _) => EspacioBarraAbajo(child: pantalla),
  transitionsBuilder: (_, a, _, child) {
    final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: c,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(c),
        child: child,
      ),
    );
  },
);

/// Paso 2 de "Marcar habilidades": qué habilidades quedan logradas para las
/// personas elegidas (por ejemplo, quienes ya pasaron un curso antes de la app).
class _ElegirHabilidadesScreen extends StatefulWidget {
  const _ElegirHabilidadesScreen({required this.sesion, required this.personas, required this.habilidades});
  final Sesion sesion;
  final List<Map<String, dynamic>> personas, habilidades;
  @override
  State<_ElegirHabilidadesScreen> createState() => _ElegirHabilidadesScreenState();
}

class _ElegirHabilidadesScreenState extends State<_ElegirHabilidadesScreen> {
  final Set<String> _habs = {};
  bool _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final n = widget.personas.length;
    try {
      final r = await widget.sesion.api.post('coachGuardar', {
        'accion': 'marcarGrupo',
        'personas': jsonEncode([for (final x in widget.personas) '${x['username']}']),
        'habilidades': jsonEncode(_habs.toList()),
      });
      if (r['exito'] == false) throw ApiException('${r['error']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Listo: ${_habs.length} habilidades logradas para $n ${n == 1 ? 'persona' : 'personas'}.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCoach(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    Map<String, List<Map<String, dynamic>>> porGrupo(bool avanzada) {
      final g = <String, List<Map<String, dynamic>>>{};
      for (final h in widget.habilidades.where((h) => (h['nivel'] == 'avanzada') == avanzada)) {
        (g['${h['categoria']}'] ??= []).add(h);
      }
      return g;
    }

    final basicas = widget.habilidades.where((h) => h['nivel'] != 'avanzada').map((h) => '${h['id']}').toSet();
    List<Widget> grupos(Map<String, List<Map<String, dynamic>>> g) => [
      for (final e in g.entries) ...[
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            e.key.toUpperCase(),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
          ),
          value: e.value.every((h) => _habs.contains('${h['id']}')),
          onChanged: (v) => setState(() => v == true ? _habs.addAll(e.value.map((h) => '${h['id']}')) : _habs.removeAll(e.value.map((h) => '${h['id']}'))),
        ),
        for (final h in e.value)
          CheckboxListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 16),
            title: Text('${h['nombre']}'),
            value: _habs.contains('${h['id']}'),
            onChanged: (v) => setState(() => v == true ? _habs.add('${h['id']}') : _habs.remove('${h['id']}')),
          ),
      ],
    ];
    final av = porGrupo(true);
    final n = widget.personas.length;
    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 4),
      child: Text(
        t,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.texto),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('¿Qué habilidades?', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Quedan como logradas para ${n == 1 ? '${widget.personas.first['nombre']}' : '$n personas'}.',
            style: TextStyle(fontSize: 14, color: p.textoSecundario),
          ),
          const SizedBox(height: 10),
          if (basicas.isNotEmpty)
            Material(
              color: p.suave,
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              clipBehavior: Clip.antiAlias,
              child: CheckboxListTile(
                title: Text(
                  Deporte.esDerby ? 'Todas las básicas (Freshmeat)' : 'Todas las básicas',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.sobreSuave),
                ),
                value: basicas.every(_habs.contains),
                onChanged: (v) => setState(() => v == true ? _habs.addAll(basicas) : _habs.removeAll(basicas)),
              ),
            ),
          titulo('Habilidades básicas'),
          ...grupos(porGrupo(false)),
          if (av.isNotEmpty) ...[titulo('Habilidades avanzadas'), ...grupos(av)],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _guardando || _habs.isEmpty ? null : _guardar,
            child: Text('Marcar como logradas (${_habs.length})'),
          ),
        ),
      ),
    );
  }
}

/// Comentario por persona, escrito o dictado (se guarda como nota de su
/// ficha deportiva). Quien no tiene texto no recibe nada.
class _ComentariosScreen extends StatefulWidget {
  const _ComentariosScreen({required this.sesion, required this.personas});
  final Sesion sesion;
  final List<Map<String, dynamic>> personas;
  @override
  State<_ComentariosScreen> createState() => _ComentariosScreenState();
}

class _ComentariosScreenState extends State<_ComentariosScreen> {
  final Map<String, TextEditingController> _c = {};
  final Set<String> _porVoz = {};
  String _visible = 'jugadorx,';
  bool _guardando = false;

  TextEditingController _de(String u) => _c[u] ??= TextEditingController();

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    var n = 0;
    try {
      for (final x in widget.personas) {
        final u = '${x['username']}';
        final t = _de(u).text.trim();
        if (t.isEmpty) continue;
        final r = await widget.sesion.api.post('coachGuardar', {
          'accion': 'nota',
          'username': u,
          'texto': t,
          'porVoz': _porVoz.contains(u),
          'visible': _visible,
        });
        if (r['exito'] == false) throw ApiException('${r['error']}');
        n++;
      }
      m.showSnackBar(SnackBar(content: Text(n == 1 ? 'Comentario guardado.' : '$n comentarios guardados.')));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(errorCoach(e))));
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final hay = widget.personas.any((x) => _de('${x['username']}').text.trim().isNotEmpty);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comentarios', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Escribe o mantén presionado el micrófono mientras hablas: se pasa a texto y queda en su ficha deportiva.',
            style: TextStyle(fontSize: 13.5, height: 1.35, color: p.textoSecundario),
          ),
          const SizedBox(height: 12),
          const Text('¿Quién los ve?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          QuienVe(valor: _visible, alCambiar: (v) => setState(() => _visible = v)),
          const SizedBox(height: 8),
          for (final x in widget.personas)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarPersona(nombre: '${x['nombre']}', foto: '${x['foto'] ?? ''}', tamano: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${x['nombre']}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _de('${x['username']}'),
                    minLines: 2,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Comentario para esta persona',
                      suffixIcon: BotonDictar(controlador: _de('${x['username']}'), alDictar: () => setState(() => _porVoz.add('${x['username']}'))),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _guardando || !hay ? null : _guardar,
            child: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar comentarios'),
          ),
        ),
      ),
    );
  }
}

/// Subsección para crear o editar una habilidad.
/// Reemplaza el bottom sheet con campos de texto para evitar cierres accidentales al escribir.
class EditarHabilidadScreen extends StatefulWidget {
  const EditarHabilidadScreen({
    super.key,
    required this.sesion,
    required this.habilidad,
    required this.categoria,
    required this.nivelInicial,
    required this.alGuardar,
  });
  final Sesion sesion;
  final Map<String, dynamic>? habilidad;
  final String? categoria;
  final String? nivelInicial;
  final Future<void> Function(Map<String, dynamic> resultado) alGuardar;

  @override
  State<EditarHabilidadScreen> createState() => _EditarHabilidadScreenState();
}

class _EditarHabilidadScreenState extends State<EditarHabilidadScreen> {
  late final nombre = TextEditingController();
  late final cat = TextEditingController();
  late bool activa = true;
  late String nivel = 'basica';

  @override
  void initState() {
    super.initState();
    nombre.text = widget.habilidad?['nombre'] ?? '';
    cat.text = '${widget.habilidad?['categoria'] ?? widget.categoria ?? ''}';
    activa = widget.habilidad?['activa'] != false;
    nivel = '${widget.habilidad?['nivel'] ?? widget.nivelInicial ?? 'basica'}';
  }

  @override
  void dispose() {
    nombre.dispose();
    cat.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (nombre.text.trim().isEmpty || cat.text.trim().isEmpty) return;
    try {
      final r = await widget.sesion.api.post('coachGuardar', {
        'accion': 'habilidad',
        'id': widget.habilidad?['id'],
        'nombre': nombre.text.trim(),
        'categoria': cat.text.trim(),
        'activa': activa,
        'nivel': nivel,
      });
      if (r['exito'] == false) throw ApiException('${r['error']}');
      if (!mounted) return;
      widget.alGuardar({'nombre': nombre.text.trim(), 'categoria': cat.text.trim(), 'activa': activa, 'nivel': nivel});
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCoach(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: Text(widget.habilidad == null ? 'Nueva habilidad' : 'Editar habilidad', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'basica', label: Text('Básica')),
                    ButtonSegment(value: 'avanzada', label: Text('Avanzada')),
                  ],
                  selected: {nivel},
                  onSelectionChanged: (v) => setState(() => nivel = v.first),
                ),
              ),
              if (widget.habilidad != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('En uso'),
                  subtitle: const Text('Apagada, deja de aparecer en las fichas (no se borra su historial).'),
                  value: activa,
                  onChanged: (v) => setState(() => activa = v),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _guardar, child: const Text('Guardar')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
