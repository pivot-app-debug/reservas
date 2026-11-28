import 'package:flutter/material.dart';

import '../pivots/pivots_screen.dart' show areasPivot, avisosPivot;

import '../core/api.dart';
import '../core/tema.dart';
import '../sesion/sesion.dart';
import '../core/vidrio.dart';
import '../core/esqueleto.dart';

/// Ajustes → Notificaciones: interruptor general y uno por tipo, generados
/// desde el catálogo del servidor (`getCatalogoNotificaciones`). Guardado
/// optimista: si falla, vuelve atrás y avisa.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key, required this.sesion});
  final Sesion sesion;

  /// Se llama al abrir Ajustes para que esta pantalla abra al instante.
  static Future<void> precargar(Api api) => _NotificacionesScreenState.precargar(api).catchError((_) {});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  List<Map<String, dynamic>>? _tipos;
  Map<String, bool> _prefs = {};
  bool _activas = true;
  String? _error;

  Api get _api => widget.sesion.api;

  // Copia en memoria (Victor, 2026-11-12: la pantalla mostraba carga cada
  // vez). Se precarga al abrir Ajustes y se refresca en segundo plano.
  static List<Map<String, dynamic>>? _cacheTipos;
  static Map<String, bool> _cachePrefs = {};

  /// Horas antes del evento para el resumen de Pivots (1, 2 o 3).
  static int _cacheHoras = 1;
  int _horas = _cacheHoras;
  static bool _cacheActivas = true;

  @override
  void initState() {
    super.initState();
    if (_cacheTipos != null) {
      _tipos = _cacheTipos;
      _prefs = Map.of(_cachePrefs);
      _activas = _cacheActivas;
    }
    _cargar();
  }

  static bool _fija(String categoria) {
    final c = categoria.toLowerCase();
    return c.contains('admin') || c.contains('cuenta');
  }

  /// Trae catálogo y preferencias y los deja en la copia en memoria.
  static Future<void> precargar(Api api) async {
    final r = await Future.wait([api.get('getCatalogoNotificaciones'), api.get('getPreferenciasPush')]);
    final c = r[0], p = r[1];
    if (p['exito'] == false) throw ApiException('${p['error']}');
    _cacheTipos = [
      for (final t in (c['tipos'] as List? ?? const []))
        // Administración y Cuenta no se pueden apagar (Victor, 2026-11-08).
        if (t is Map<String, dynamic> && t['soloAdmin'] != true && !_fija('${t['categoria'] ?? ''}')) t,
    ];
    _cacheActivas = p['activas'] != false;
    _cachePrefs = {for (final e in ((p['preferencias'] as Map?) ?? const {}).entries) '${e.key}': e.value == true};
    _cacheHoras = ((p['preferencias'] as Map?)?['resumenHoras'] as num?)?.toInt() ?? 1;
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      await precargar(_api);
      if (!mounted) return;
      setState(() {
        _tipos = _cacheTipos;
        _activas = _cacheActivas;
        _prefs = Map.of(_cachePrefs);
        _horas = _cacheHoras;
      });
    } catch (_) {
      // Con copia en pantalla, el error no tapa nada.
      if (mounted && _tipos == null) setState(() => _error = 'No se pudieron cargar tus preferencias. Revisa tu conexión.');
    }
  }

  Future<void> _guardar(Map<String, Object> params, VoidCallback aplicar, VoidCallback revertir) async {
    setState(aplicar);
    try {
      final r = await _api.post('guardarPreferenciasPush', params);
      if (r['exito'] != true) throw ApiException('${r['error'] ?? ''}');
      _cachePrefs = Map.of(_prefs);
      _cacheActivas = _activas;
    } catch (_) {
      if (!mounted) return;
      setState(revertir);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo guardar. Revisa tu conexión.')));
    }
  }

  /// Una categoría entera de una vez (cada clave se guarda por separado).
  Future<void> _categoria(List<Map<String, dynamic>> tipos, bool v) async {
    final antes = {for (final t in tipos) '${t['clave']}': _prefs['${t['clave']}']};
    setState(() {
      for (final t in tipos) {
        _prefs['${t['clave']}'] = v;
      }
    });
    try {
      final rs = await Future.wait([
        for (final t in tipos) _api.post('guardarPreferenciasPush', {'clave': '${t['clave']}', 'valor': '$v'}),
      ]);
      if (rs.any((r) => r['exito'] != true)) throw ApiException('');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        antes.forEach((k, x) => x == null ? _prefs.remove(k) : _prefs[k] = x);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo guardar. Revisa tu conexión.')));
    }
  }

  /// Tema de Mi perfil donde va cada área de Pivot (QA 2026-11-27: un solo
  /// lugar por tema, sin «Avisos de Pivot» aparte). Las que no tienen par
  /// quedan como tema propio con el nombre del área.
  static const _temaDeArea = {'tareas': 'Tareas', 'asistencia': 'Entrenamientos', 'equipo': 'Equipo', 'sociales': 'Equipo'};

  static const _horasTexto = {1: '1 hora antes', 2: '2 horas antes', 3: '3 horas antes'};

  /// Cuándo llega el resumen de cada evento: abre las 3 opciones en un
  /// bottom sheet para evitar toques accidentales (QA 2026-11-27).
  Widget _resumenEvento(BuildContext context) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(Icons.schedule_rounded, color: p.marcaTexto),
          title: const Text('Resumen antes de cada evento', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Quiénes vienen y qué equipamiento llevar · ${_horasTexto[_horas] ?? '1 hora antes'}'),
          trailing: const Icon(Icons.unfold_more_rounded),
          onTap: () async {
            final v = await showModalBottomSheet<int>(
              useRootNavigator: true,
              context: context,
              showDragHandle: true,
              builder: (h) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text('¿Cuándo te llega el resumen?', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    for (final e in _horasTexto.entries)
                      ListTile(
                        leading: Icon(e.key == _horas ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: p.marcaTexto),
                        title: Text(e.value),
                        onTap: () => Navigator.of(h).pop(e.key),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
            if (v == null || v == _horas) return;
            final antes = _horas;
            _guardar({'clave': 'resumenHoras', 'valor': '$v'}, () => _horas = v, () => _horas = antes);
            _cacheHoras = v;
          },
        ),
      ),
    );
  }

  static IconData _iconoCategoria(String c) {
    final x = c.toLowerCase();
    if (x.contains('evento') || x.contains('entren')) return Icons.event_rounded;
    if (x.contains('tarea')) return Icons.task_alt_rounded;
    if (x.contains('finanz') || x.contains('pago') || x.contains('cuota') || x.contains('reserva')) return Icons.payments_outlined;
    if (x.contains('equipo') || x.contains('cumple')) return Icons.groups_rounded;
    if (x.contains('admin')) return Icons.admin_panel_settings_outlined;
    return Icons.notifications_none_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final tipos = _tipos;
    final categorias = <String, List<Map<String, dynamic>>>{};
    final s = widget.sesion;
    for (final t in tipos ?? const <Map<String, dynamic>>[]) {
      // Avisos del equipo técnico, en su tema (QA 2026-11-27: todo en Mi perfil).
      if (t['soloCoach'] == true) {
        if (!s.esCoach) continue;
        (categorias['${t['categoria'] ?? 'Otras'}'] ??= []).add({...t, 'etiqueta': 'Equipo técnico'});
        continue;
      }
      (categorias['${t['categoria'] ?? 'Otras'}'] ??= []).add(t);
    }
    // Avisos de Pivot de tus áreas, dentro del mismo tema (sin sección aparte).
    final mias = s.areasPivot.isEmpty ? areasPivot.keys.toList() : s.areasPivot;
    final esPivot = s.esAdmin && s.adminToken != null;
    if (esPivot) {
      for (final a in areasPivot.entries) {
        if (!mias.contains(a.key) || avisosPivot[a.key] == null) continue;
        final tema = _temaDeArea[a.key] ?? a.value.$1;
        for (final (k, n) in avisosPivot[a.key]!) {
          (categorias[tema] ??= []).add({'clave': 'pivot_${a.key}_$k', 'nombre': n, 'etiqueta': 'Pivot'});
        }
      }
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: _error != null
            ? Center(
                key: const ValueKey('error'),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
                    ],
                  ),
                ),
              )
            : tipos == null
            ? const Esqueleto(forma: FormaEsqueleto.ajustes, key: ValueKey('cargando'))
            : ListView(
                key: const ValueKey('lista'),
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 40 + MediaQuery.paddingOf(context).bottom),
                children: [
                  // Interruptor general, grande, con el degradado de la marca
                  // (el amarillo no se leía en modo oscuro).
                  Material(
                    type: MaterialType.transparency,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _activas ? PivotPaleta.degradadoMarca : null,
                        color: _activas ? null : p.tarjeta,
                        borderRadius: BorderRadius.circular(PivotRadios.grande),
                      ),
                      child: SwitchListTile(
                        value: _activas,
                        onChanged: (v) => _guardar({'activas': '$v'}, () => _activas = v, () => _activas = !v),
                        contentPadding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PivotRadios.grande)),
                        secondary: Icon(
                          _activas ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                          color: _activas ? PivotPaleta.sobreSeccion : p.textoSecundario,
                        ),
                        title: Text(
                          _activas ? 'Notificaciones activadas' : 'Notificaciones apagadas',
                          style: TextStyle(fontWeight: FontWeight.w800, color: _activas ? PivotPaleta.sobreSeccion : p.texto),
                        ),
                        subtitle: Text(
                          _activas ? 'Elige abajo qué temas te interesan.' : 'No te llega ningún aviso de Pivot.',
                          style: TextStyle(color: _activas ? PivotPaleta.sobreSeccion.withValues(alpha: 0.85) : p.textoSecundario),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _activas ? 1 : 0.4,
                    child: IgnorePointer(
                      ignoring: !_activas,
                      child: Column(
                        children: [
                          for (final c in categorias.entries)
                            _Categoria(
                              nombre: c.key,
                              icono: _iconoCategoria(c.key),
                              tipos: c.value,
                              prefs: _prefs,
                              alCambiarTodo: (v) => _categoria(c.value, v),
                              alCambiarUno: (t, v) {
                                final k = '${t['clave']}';
                                final antes = _prefs[k];
                                _guardar({'clave': k, 'valor': '$v'}, () => _prefs[k] = v, () => antes == null ? _prefs.remove(k) : _prefs[k] = antes);
                              },
                            ),
                          if (esPivot && mias.contains('asistencia')) _resumenEvento(context),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Recomendamos mantener activas todas las notificaciones, así no te pierdes de nada importante.',
                      style: TextStyle(fontSize: 12.5, color: p.textoSecundario),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Un tema (Eventos, Tareas…) con un solo interruptor; "Personalizar" abre
/// cada aviso por separado para quien quiera afinar.
class _Categoria extends StatefulWidget {
  const _Categoria({
    required this.nombre,
    required this.icono,
    required this.tipos,
    required this.prefs,
    required this.alCambiarTodo,
    required this.alCambiarUno,
  });
  final String nombre;
  final IconData icono;
  final List<Map<String, dynamic>> tipos;
  final Map<String, bool> prefs;
  final ValueChanged<bool> alCambiarTodo;
  final void Function(Map<String, dynamic>, bool) alCambiarUno;

  @override
  State<_Categoria> createState() => _CategoriaState();
}

class _CategoriaState extends State<_Categoria> {
  bool _abierta = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final activas = widget.tipos.where((t) => widget.prefs['${t['clave']}'] != false).length;
    final total = widget.tipos.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SwitchListTile(
              value: activas > 0,
              onChanged: widget.alCambiarTodo,
              secondary: Icon(widget.icono, color: p.marcaTexto),
              title: Text(widget.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(activas == total ? 'Todos los avisos' : (activas == 0 ? 'Ninguno' : '$activas de $total avisos')),
            ),
            if (total > 1)
              InkWell(
                onTap: () => setState(() => _abierta = !_abierta),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      Text(
                        _abierta ? 'Ocultar' : 'Personalizar',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.marcaTexto),
                      ),
                      AnimatedRotation(
                        turns: _abierta ? 0.5 : 0,
                        duration: const Duration(milliseconds: 240),
                        child: Icon(Icons.expand_more_rounded, size: 20, color: p.marcaTexto),
                      ),
                    ],
                  ),
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_abierta
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      children: [
                        Divider(height: 1, color: p.fondo),
                        for (final t in widget.tipos)
                          SwitchListTile(
                            dense: true,
                            value: widget.prefs['${t['clave']}'] != false,
                            onChanged: (v) => widget.alCambiarUno(t, v),
                            contentPadding: const EdgeInsets.fromLTRB(72, 0, 16, 0),
                            // Pill rojiza para lo de Pivot o equipo técnico (Victor, 2026-11-28).
                            title: Text.rich(
                              TextSpan(
                                children: [
                                  if (t['etiqueta'] != null)
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.chip)),
                                        child: Text(
                                          '${t['etiqueta']}',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: p.sobreSuave),
                                        ),
                                      ),
                                    ),
                                  TextSpan(text: '${t['nombre'] ?? t['clave']}'),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
