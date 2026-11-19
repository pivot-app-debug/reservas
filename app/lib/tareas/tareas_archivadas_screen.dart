import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/fechas.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../eventos/widgets_comunes.dart' show TextoDeslizante;
import 'tareas_modelos.dart';
import 'tareas_repo.dart';
import 'tareas_widgets.dart';
import '../core/esqueleto.dart';

/// Tareas archivadas (Pivots): quién las hizo y cómo quedó. Se pueden
/// borrar como último recurso; eso quita los puntos que dieron. Buscador y
/// filtros por área y fechas (día o rango) sobre la lista ya cargada.
class TareasArchivadasScreen extends StatefulWidget {
  const TareasArchivadasScreen({super.key, required this.repo});
  final TareasRepo repo;

  @override
  State<TareasArchivadasScreen> createState() => _TareasArchivadasScreenState();
}

class _TareasArchivadasScreenState extends State<TareasArchivadasScreen> {
  List<Map<String, dynamic>>? _l;
  String? _error;

  // Filtros (Victor, QA 2026-11-18): se combinan entre sí.
  String _q = '';
  final Set<String> _areasFiltro = {};
  DateTimeRange? _rango;
  final _buscar = TextEditingController();

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  bool get _hayFiltros => _q.trim().isNotEmpty || _areasFiltro.isNotEmpty || _rango != null;

  static DateTime? _dia(Object? iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  static List<PersonaTarea> _personas(Map<String, dynamic> t) => [
    for (final x in (t['personas'] as List? ?? const []))
      if (x is Map) PersonaTarea(Map<String, dynamic>.from(x)),
  ];

  bool _pasa(Map<String, dynamic> t) {
    final areas = AreaTarea.separar('${t['area'] ?? ''}');
    if (_areasFiltro.isNotEmpty && !areas.any(_areasFiltro.contains)) return false;
    final r = _rango;
    if (r != null) {
      final d = _dia(t['fechaArchivado']);
      if (d == null || d.isBefore(r.start) || d.isAfter(r.end)) return false;
    }
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    final texto = [
      '${t['titulo'] ?? ''}',
      '${t['notas'] ?? ''}',
      ...areas,
      for (final x in _personas(t)) ...[x.nombreMostrar, x.username],
    ].join(' ').toLowerCase();
    return texto.contains(q);
  }

  Future<void> _elegirFechas() async {
    final hoy = Fechas.hoy();
    final fechas = [for (final t in _l ?? const <Map<String, dynamic>>[]) _dia(t['fechaArchivado'])].whereType<DateTime>().toList()..sort();
    final primera = fechas.isEmpty || fechas.first.isAfter(hoy) ? DateTime(hoy.year - 1, hoy.month, hoy.day) : fechas.first;
    final r = await showDateRangePicker(
      context: context,
      firstDate: primera,
      lastDate: hoy,
      initialDateRange: _rango,
      helpText: 'Elige un día o un rango',
      saveText: 'Aplicar',
    );
    if (r != null && mounted) setState(() => _rango = DateTimeRange(start: r.start, end: r.end));
  }

  String get _textoRango {
    final r = _rango;
    if (r == null) return 'Fechas';
    if (r.start == r.end) return Fechas.corta(r.start);
    return '${Fechas.corta(r.start)} – ${Fechas.corta(r.end)}';
  }

  void _limpiar() {
    _buscar.clear();
    setState(() {
      _q = '';
      _areasFiltro.clear();
      _rango = null;
    });
  }

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
            ? Center(
                key: const ValueKey('c'),
                child: _error == null ? const Esqueleto(forma: FormaEsqueleto.lista) : Text(_error!),
              )
            : _lista(context, l),
      ),
    );
  }

  Widget _lista(BuildContext context, List<Map<String, dynamic>> l) {
    final p = context.pivot;
    final areas = {for (final t in l) ...AreaTarea.separar('${t['area'] ?? ''}')}.toList()
      ..sort((a, b) => AreaTarea.lista.indexOf(AreaTarea.de(a)).compareTo(AreaTarea.lista.indexOf(AreaTarea.de(b))));
    final filtradas = l.where(_pasa).toList();
    return ListView(
      key: const ValueKey('l'),
      padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 32 + MediaQuery.paddingOf(context).bottom),
      children: [
        if (l.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text('No hay tareas archivadas.', style: TextStyle(color: p.textoSecundario)),
          )
        else ...[
          TextField(
            controller: _buscar,
            onChanged: (v) => setState(() => _q = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Buscar por título, área o persona',
              suffixIcon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _q.isEmpty
                    ? const SizedBox.shrink(key: ValueKey('vacio'))
                    : IconButton(
                        key: const ValueKey('borrar'),
                        tooltip: 'Borrar búsqueda',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _buscar.clear();
                          setState(() => _q = '');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: const Icon(Icons.date_range_rounded, size: 18),
                    label: Text(_textoRango),
                    selected: _rango != null,
                    showCheckmark: false,
                    onSelected: (_) => _elegirFechas(),
                    onDeleted: _rango == null ? null : () => setState(() => _rango = null),
                  ),
                ),
                for (final a in areas)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(AreaTarea.de(a).icono, size: 18),
                      label: Text(a),
                      selected: _areasFiltro.contains(a),
                      showCheckmark: false,
                      onSelected: (si) => setState(() => si ? _areasFiltro.add(a) : _areasFiltro.remove(a)),
                    ),
                  ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topLeft,
            child: _hayFiltros
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            filtradas.length == 1 ? '1 tarea' : '${filtradas.length} tareas',
                            style: TextStyle(fontSize: 13, color: p.textoSecundario),
                          ),
                        ),
                        TextButton(onPressed: _limpiar, child: const Text('Quitar filtros')),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 8),
          ),
          const SizedBox(height: 6),
          // Al filtrar, la lista cambia con fundido y el alto se ajusta suave.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              layoutBuilder: (actual, previos) => Stack(alignment: Alignment.topCenter, children: [...previos, ?actual]),
              child: filtradas.isEmpty
                  ? Padding(
                      key: const ValueKey('sin'),
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        'No hay tareas que coincidan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.textoSecundario),
                      ),
                    )
                  : Column(
                      key: ValueKey(filtradas.map((t) => '${t['idTarea']}').join(',')),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (final t in filtradas) _tarjeta(context, t)],
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tarjeta(BuildContext context, Map<String, dynamic> t) {
    final p = context.pivot;
    final personas = _personas(t);
    final archivada = _fecha(t['fechaArchivado']);
    return Padding(
      key: ValueKey('t-${t['idTarea']}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconosAreas(areas: AreaTarea.separar('${t['area'] ?? ''}'), tamano: 24),
                  const Spacer(),
                  PillPuntos(puntos: (t['puntos'] as num?)?.toInt() ?? 0, completo: true),
                  IconButton(
                    tooltip: 'Borrar',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline_rounded, color: p.textoSecundario),
                    onPressed: () => _eliminar(t),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextoDeslizante(
                  texto: '${t['titulo']}',
                  alineacion: TextAlign.start,
                  estilo: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.texto),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(archivada.isEmpty ? 'Archivada' : 'Archivada el $archivada', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                    ),
                    if (personas.isEmpty)
                      Text('Sin personas', style: TextStyle(fontSize: 13, color: p.textoSecundario))
                    else
                      PilaAvatares(personas: personas, siempreAbre: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
