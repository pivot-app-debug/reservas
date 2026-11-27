import 'dart:convert';

import 'package:flutter/material.dart';

import '../finanzas/pago_coaches_screen.dart';

import '../core/banner_ayuda.dart';

import '../core/sincroniza.dart';

import 'package:share_plus/share_plus.dart';

import 'cobro_equipo_screen.dart' show modosCobro, CobroEquipoScreen, textoCobroEquipo;
import '../equipo/inventario_modelos.dart';
import '../equipo/inventario_screen.dart';
import '../ajustes/componentes.dart' show SubAjustes;

import '../core/config_liga.dart';

import 'editores_liga.dart';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../ajustes/recorte_foto.dart';
import '../core/api.dart';
import 'buscador_liga.dart';
import '../core/asistente.dart';
import '../core/fechas.dart';
import '../core/selector_plazo.dart';
import '../core/tema.dart';
import '../equipo/equipo_modelos.dart';
import '../eventos/widgets_comunes.dart';
import '../sesion/sesion.dart';
import '../core/vidrio.dart';
import '../core/moneda.dart';
import '../core/esqueleto.dart';
import '../finanzas/tesoreria_repo.dart';
import '../finanzas/tesoreria_screen.dart' show FondosViajeScreen;
import 'reglas_screen.dart' show ReglasScreen;
import 'recompensas_screen.dart' show RecompensasPagoScreen, textoRecompensa;
import 'vencimiento_screen.dart' show VencimientoScreen;

/// Persona con clases y puntos por mes calendario (`adminDatosCategorias`):
/// índice 0 = mes en curso, 1 = último mes cerrado… hasta 12.
class _Persona {
  _Persona(Map<String, dynamic> m)
    : nombre = '${m['nombre']}',
      nombreMostrar = '${m['nombreMostrar'] ?? m['nombre']}',
      foto = '${m['foto'] ?? ''}',
      categoria = '${m['categoria'] ?? ''}',
      auto = (m['modo'] ?? 'auto') == 'auto',
      estado = '${m['estado'] ?? ''}',
      usaEquipo = m['usaEquipo'] == true,
      clasesMes = [for (final x in (m['clasesMes'] as List? ?? const [])) (x as num)],
      clasesEquipos = {
        for (final e in ((m['clasesEquipos'] as Map?) ?? const {}).entries) '${e.key}': [for (final x in (e.value as List? ?? const [])) (x as num)],
      },
      tareasMes = [for (final x in (m['tareasMes'] as List? ?? const [])) (x as num)],
      puntosMes = [for (final x in (m['puntosMes'] as List? ?? const [])) (x as num)];
  final String nombre, nombreMostrar, foto, categoria, estado;
  final bool auto, usaEquipo;
  final List<num> clasesMes, tareasMes, puntosMes;

  /// Clases contadas con la regla propia de un equipo (si tiene).
  final Map<String, List<num>> clasesEquipos;

  /// Entra en el cálculo automático (no fijada a mano, no congelada).
  bool get evaluable => auto && !const ['Lesionadx', 'De viaje', 'Técnico', 'Enfermedad', 'Situación personal'].contains(estado);
  static num _suma(List<num> l, int meses) {
    num t = 0;
    for (var i = 1; i <= meses && i < l.length; i++) {
      t += l[i];
    }
    return t;
  }

  /// Meses cerrados (como el servidor: en noviembre se mira octubre).
  num c(int meses, [String? equipo]) => _suma(clasesEquipos[equipo] ?? clasesMes, meses);
  num p(int meses, String fuente) => _suma(fuente == 'todos' ? puntosMes : tareasMes, meses);
}

/// Lo que pide un equipo (fila de `config_tiers`).
class _Regla {
  _Regla({
    required this.clases,
    required this.puntos,
    required this.logica,
    required this.ventana,
    required this.unidad,
    required this.fuente,
    required this.subir,
    required this.gracia,
    required this.graciaUnidad,
    this.equipo,
  });
  factory _Regla.de(Map<String, dynamic> t) {
    int n(Object? v) => (v as num?)?.toInt() ?? int.tryParse('$v') ?? 0;
    return _Regla(
      clases: n(t['min_clases']),
      puntos: n(t['min_puntos']),
      logica: t['logica'] == 'Y' ? 'Y' : 'O',
      ventana: n(t['ventana_meses']).clamp(1, 99),
      unidad: '${t['periodo_unidad'] ?? 'mes'}',
      fuente: t['puntos_fuente'] == 'todos' ? 'todos' : 'tareas',
      subir: n(t['meses_consecutivos_ascenso']).clamp(1, 24),
      gracia: n(t['meses_gracia_demotion']).clamp(0, 99),
      graciaUnidad: '${t['gracia_unidad'] ?? 'mes'}',
      equipo: t['nombre'] == null ? null : '${t['nombre']}',
    );
  }
  int clases, puntos, ventana, subir, gracia;
  String logica, unidad, fuente, graciaUnidad;

  /// Equipo de la regla: sus clases se cuentan con su "qué cuenta como clase".
  final String? equipo;

  _Regla copia() => _Regla(
    clases: clases,
    puntos: puntos,
    logica: logica,
    ventana: ventana,
    unidad: unidad,
    fuente: fuente,
    subir: subir,
    gracia: gracia,
    graciaUnidad: graciaUnidad,
    equipo: equipo,
  );

  int get meses => mesesDePlazo(ventana, unidad);

  /// 'clases', 'puntos', 'o' (cualquiera) o 'y' (los dos).
  String get modo => clases > 0 && puntos > 0 ? logica.toLowerCase() : (puntos > 0 ? 'puntos' : 'clases');

  /// Igual que el servidor: un mínimo en 0 siempre se cumple.
  bool cumple(_Persona x) {
    final c = x.c(meses, equipo) >= clases, p = x.p(meses, fuente) >= puntos;
    return logica == 'Y' ? c && p : c || p;
  }

  String get periodo => ventana == 1
      ? switch (unidad) {
          'dia' => 'en el último día',
          'semana' => 'por semana',
          'anio' => 'al año',
          _ => 'al mes',
        }
      : 'en ${unidad == 'semana' ? 'las últimas' : 'los últimos'} ${textoPlazo(ventana, unidad)}';

  String get texto {
    final partes = [
      if (clases > 0) clases == 1 ? '1 clase asistida' : '$clases clases asistidas',
      if (puntos > 0) '$puntos puntos${fuente == 'tareas' ? ' por tareas' : ''}',
    ];
    if (partes.isEmpty) return 'No pide un mínimo';
    return '${partes.join(logica == 'Y' ? ' y ' : ' o ')} $periodo';
  }

  String get textoSubir => '$subir ${subir == 1 ? 'mes' : 'meses seguidos'} cumpliéndolo';
  String get textoBajar => gracia == 0 ? 'Baja en el siguiente cálculo' : '${textoPlazo(gracia, graciaUnidad)} para ponerse al día';

  Map<String, Object?> params(Map<String, dynamic> t) => {
    if (t['id'] != null) 'id': t['id'],
    'orden': t['orden'],
    'nombre': t['nombre'],
    'min_clases': clases,
    'min_puntos': puntos,
    'ventana_meses': ventana,
    'logica': logica,
    'es_default': t['es_default'] == true ? 'true' : '',
    'meses_consecutivos_ascenso': subir,
    'meses_gracia_demotion': gracia,
    'dividir_puntos_mitad': t['dividir_puntos_mitad'] == true ? 'true' : '',
    'califica_fondos_viaje': t['califica_fondos_viaje'] == true ? 'true' : '',
    'puntos_fuente': fuente,
    'periodo_unidad': unidad,
    'gracia_unidad': graciaUnidad,
    'requisitos': jsonEncode(t['requisitos'] ?? const {}),
  };
}

/// Guarda un equipo con `upsertTier`. Lanza ApiException si falla.
Future<Map<String, dynamic>> _guardarTier(Sesion s, Map<String, Object?> params) async {
  final r = await s.api.post('upsertTier', {'adminToken': s.adminToken, ...params});
  if (r['error'] != null) throw ApiException('${r['error']}');
  return (r['tier'] as Map<String, dynamic>?) ?? const {};
}

/// Elegir, encuadrar y subir un logo (de la liga o de un equipo).
Future<String?> elegirYSubirLogo(BuildContext context, Sesion s, String destino) async {
  XFile? img;
  try {
    img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 92);
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir la galería.')));
    return null;
  }
  if (img == null || !context.mounted) return null;
  final original = await img.readAsBytes();
  if (!context.mounted) return null;
  final bytes = await RecorteFotoScreen.abrir(context, original);
  if (bytes == null) return null;
  final r = await s.api.post('adminSubirLogo', {'adminToken': s.adminToken, 'destino': destino, 'base64Data': 'data:image/jpeg;base64,${base64Encode(bytes)}'});
  if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo subir.'}');
  return '${r['url'] ?? ''}';
}

/// Logo redondo de un equipo o de la liga; sin logo, la inicial.
class LogoEquipo extends StatelessWidget {
  const LogoEquipo({super.key, required this.nombre, this.url, this.tamano = 44});
  final String nombre;
  final String? url;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final u = url ?? '';
    return ClipOval(
      child: SizedBox(
        width: tamano,
        height: tamano,
        child: u.isNotEmpty ? Image.network(u, fit: BoxFit.cover, errorBuilder: (_, _, _) => _inicial(p)) : _inicial(p),
      ),
    );
  }

  Widget _inicial(PivotPaleta p) => Container(
    color: p.suave,
    alignment: Alignment.center,
    child: Text(
      nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
      style: TextStyle(fontSize: tamano * 0.42, fontWeight: FontWeight.w900, color: p.sobreSuave),
    ),
  );
}

/// Ajustes de la liga → Equipos y puntos (Victor, 2026-11-13). Cada equipo
/// en palabras y con cuántos lo cumplen hoy; tocar uno abre su resumen con
/// filas que se cambian por separado. El asistente es solo para crear.
/// También: cuándo se aplican los cambios, cuánto vale cada marca y qué
/// cuenta como clase.
class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key, required this.sesion, this.resaltar});
  final Sesion sesion;

  /// Fila a resaltar al abrir (desde el buscador de Mi Liga).
  final String? resaltar;

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  final _resaltado = ValueNotifier<String?>(null);
  bool _resaltadoHecho = false;

  @override
  void dispose() {
    _resaltado.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>>? _tiers;
  List<_Persona> _gente = const [];
  Map<String, dynamic> _reglas = const {};
  String? _error;

  Sesion get s => widget.sesion;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final token = {'adminToken': s.adminToken};
      final r = await Future.wait([s.api.get('getTiers', token), s.api.get('adminDatosCategorias', token), s.api.get('getReglasLiga', token)]);
      final l = [
        for (final t in (r[0]['tiers'] as List? ?? const []))
          if (t is Map<String, dynamic>) t,
      ]..sort((a, b) => ((a['orden'] as num?) ?? 0).compareTo((b['orden'] as num?) ?? 0));
      final g = [
        for (final p in (r[1]['personas'] as List? ?? const []))
          if (p is Map<String, dynamic>) _Persona(p),
      ];
      if (mounted) {
        setState(() {
          _tiers = l;
          _gente = g;
          _reglas = r[2];
          _error = null;
        });
        final x = widget.resaltar;
        if (x != null && !_resaltadoHecho) {
          _resaltadoHecho = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => x == 'nuevoEquipo' ? _nuevo() : _resaltado.value = x);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
    }
  }

  void _aviso(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  Future<void> _abrirEquipo(int i) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _EquipoScreen(sesion: s, tiers: _tiers!, indice: i, gente: _gente),
      ),
    );
    await _cargar();
  }

  Future<void> _nuevo() async {
    final l = _tiers!;
    final inicial = l.firstWhere((t) => t['es_default'] == true, orElse: () => l.last);
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _NuevoEquipoAsistente(sesion: s, inicial: inicial, gente: _gente),
      ),
    );
    if (ok == true) {
      _aviso('Equipo creado. Quedó justo encima de ${inicial['nombre']}.');
      await _cargar();
    }
  }

  // ─── Cuándo se aplican los cambios de equipo ───────────────────────────
  Map<String, dynamic> get _corte => (_reglas['corte'] as Map<String, dynamic>?) ?? const {'modo': 'revisar', 'dia': 1, 'avisoDias': 7, 'autoAprobar': true};

  (DateTime, DateTime) _fechasCorte(int dia, int aviso) => fechasCorteEquipos(dia, aviso);

  Future<void> _editarCorte() async {
    final r = await editarCorteEquipos(context, s, _tiers, corte: _corte);
    if (r != null && mounted) setState(() => _reglas = {..._reglas, 'corte': r});
  }

  @override
  Widget build(BuildContext context) {
    final l = _tiers;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Equipos y puntos', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: l == null
            ? _error == null
                  ? const Esqueleto(forma: FormaEsqueleto.tarjetas, key: ValueKey('c'))
                  : Center(key: const ValueKey('e'), child: Text(_error!))
            : Sincroniza(
                key: const ValueKey('l'),
                onRefresh: _cargar,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    _Seccion('EQUIPOS'),
                    for (final (i, t) in l.indexed) _tarjeta(context, i, t),
                    const SizedBox(height: 8),
                    _Seccion('REGLAS'),
                    Resaltable(
                      id: 'corte',
                      resaltado: _resaltado,
                      child: _Fila(
                        icono: Icons.event_repeat_rounded,
                        titulo: 'Cuándo se aplican los cambios',
                        texto: _corte['modo'] == 'auto'
                            ? 'Automático'
                            : (_corte['autoAprobar'] == false
                                  ? 'Revisar antes · manual, cada cambio espera a un Pivot'
                                  : 'Revisar antes · lo no revisado se aplica el ${Fechas.corta(_fechasCorte((_corte['dia'] as num?)?.toInt() ?? 1, 0).$1)}'),
                        alTocar: _editarCorte,
                      ),
                    ),
                    Resaltable(
                      id: 'historial',
                      resaltado: _resaltado,
                      child: _Fila(
                        icono: Icons.history_rounded,
                        titulo: 'Historial de cambios',
                        texto: 'Últimos 6 meses',
                        alTocar: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HistorialAjustesScreen(sesion: s))),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: l == null ? null : FloatingActionButton(tooltip: 'Nuevo equipo', onPressed: _nuevo, child: const Icon(Icons.add_rounded)),
    );
  }

  Widget _tarjeta(BuildContext context, int i, Map<String, dynamic> t) {
    final p = context.pivot;
    final piso = t['es_default'] == true;
    final r = _Regla.de(t);
    final miembros = _gente.where((x) => x.categoria == t['nombre'] && x.evaluable && !x.usaEquipo).toList();
    final cumplen = miembros.where(r.cumple).length;
    final total = _gente.where((x) => x.categoria == t['nombre']).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        child: InkWell(
          borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
          onTap: () => _abrirEquipo(i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                LogoEquipo(nombre: '${t['nombre']}', url: t['logo'] as String?),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t['nombre']}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.texto),
                      ),
                      const SizedBox(height: 2),
                      Text(piso ? 'Equipo inicial: no pide un mínimo.' : 'Pide ${r.texto}.', style: TextStyle(fontSize: 14, color: p.texto)),
                      const SizedBox(height: 2),
                      Text(
                        piso || miembros.isEmpty ? '$total ${total == 1 ? 'persona' : 'personas'}' : 'Hoy lo cumplen $cumplen de ${miembros.length}.',
                        style: TextStyle(fontSize: 13, color: p.textoSecundario),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.textoSecundario),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.texto);
  final String texto;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
    child: Text(
      texto,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.pivot.textoSecundario),
    ),
  );
}

class _SoloLectura extends InheritedWidget {
  const _SoloLectura({required super.child});
  static bool de(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_SoloLectura>() != null;
  @override
  bool updateShouldNotify(_SoloLectura old) => false;
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.titulo, required this.texto, required this.alTocar, this.final_});
  final IconData icono;
  final String titulo, texto;
  final VoidCallback? alTocar;
  final Widget? final_;

  @override
  Widget build(BuildContext context) {
    if (_SoloLectura.de(context)) return _Fila(icono: icono, titulo: titulo, texto: texto, alTocar: null)._dibujar(context);
    return _dibujar(context);
  }

  Widget _dibujar(BuildContext context) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icono, color: p.marcaTexto),
          title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(texto),
          trailing: final_ ?? (alTocar == null ? null : const Icon(Icons.chevron_right_rounded)),
          onTap: alTocar,
        ),
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({super.key, required this.texto});
  final String texto;
  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta - 4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: p.sobreSuave),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: TextStyle(fontSize: 13.5, height: 1.35, color: p.sobreSuave)),
          ),
        ],
      ),
    );
  }
}

/// Historial de cambios en los ajustes de la liga (Victor, 2026-11-13):
/// tarjetas con quién lo hizo, qué cambió en palabras, buscador y filtros.
class HistorialAjustesScreen extends StatefulWidget {
  const HistorialAjustesScreen({super.key, required this.sesion, this.grupo = ''});
  final Sesion sesion;

  /// Filtro con el que abre: desde un equipo, 'equipos' (Victor, 2026-11-16).
  final String grupo;

  @override
  State<HistorialAjustesScreen> createState() => _HistorialAjustesScreenState();
}

class _HistorialAjustesScreenState extends State<HistorialAjustesScreen> {
  List<Map<String, dynamic>>? _items;
  int _desdeAnio = DateTime.now().year;
  String _periodo = '6m'; // '6m' | 'mes' | 'anio:<n>' | 'todo' | 'rango'
  DateTimeRange? _rango;
  late String _grupo = widget.grupo;
  String _q = '';
  String? _error;

  static const _grupos = {
    'equipos': ('Equipos', Icons.groups_outlined),
    'puntos': ('Puntos y reglas', Icons.rule_rounded),
    'tesoreria': ('Finanzas', Icons.account_balance_wallet_outlined),
    'liga': ('Liga', Icons.stadium_outlined),
  };

  static String _grupoDe(String clave) => switch (clave) {
    'equipo' || 'corte' => 'equipos',
    'puntos' || 'tiposCuentan' || 'tardeCuentaClase' || 'toleranciaMin' || 'rectificacionDias' || 'eventosMinPersonas' || 'inactividadDias' => 'puntos',
    'cuenta' || 'transparencia' => 'tesoreria',
    _ => 'liga',
  };

  static const _nombres = {
    'corte': 'Cuándo se aplican los cambios de equipo',
    'puntos': 'Puntos por asistencia',
    'tiposCuentan': 'Qué cuenta como clase',
    'tardeCuentaClase': 'Llegadas tarde para el equipo',
    'toleranciaMin': 'Tolerancia de llegada',
    'rectificacionDias': 'Días para revisar rectificaciones',
    'eventosMinPersonas': 'Mínimo de personas por evento',
    'inactividadDias': 'Inactividad',
    'equipo': 'Equipos',
    'logo': 'Logo',
    'cuenta': 'Cuenta de Finanzas',
    'transparencia': 'Transparencia de Finanzas',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  (String?, String?) get _fechas {
    final h = Fechas.hoy();
    if (_periodo == '6m') return (_iso(DateTime(h.year, h.month - 6, h.day)), null);
    if (_periodo == 'mes') return (_iso(DateTime(h.year, h.month, 1)), null);
    if (_periodo.startsWith('anio:')) {
      final a = int.parse(_periodo.substring(5));
      return ('$a-01-01', '$a-12-31');
    }
    if (_periodo == 'rango' && _rango != null) return (_iso(_rango!.start), _iso(_rango!.end));
    return (null, null);
  }

  Future<void> _cargar() async {
    setState(() => _items = null);
    try {
      final (d, h) = _fechas;
      final r = await widget.sesion.api.get('adminHistorialAjustes', {'adminToken': widget.sesion.adminToken, 'desde': ?d, 'hasta': ?h});
      if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo cargar.'}');
      if (!mounted) return;
      setState(() {
        _items = [
          for (final x in (r['historial'] as List? ?? const []))
            if (x is Map<String, dynamic>) x,
        ];
        _desdeAnio = (r['desdeAnio'] as num?)?.toInt() ?? DateTime.now().year;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => (_items = const [], _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.'));
    }
  }

  static String _v(Object? x, [String unidad = '']) {
    if (x == null) return '—';
    if (x is bool) return x ? 'sí' : 'no';
    if (x is num) return '${numero(x).replaceAll('.', ',')}${unidad.isEmpty ? '' : ' $unidad'}';
    if (x is List) return x.isEmpty ? 'todo suma' : x.join(', ');
    return '$x';
  }

  static const _camposEquipo = {
    'nombre': 'nombre',
    'min_clases': 'clases',
    'min_puntos': 'puntos',
    'ventana_meses': 'período',
    'periodo_unidad': 'unidad del período',
    'logica': 'clases y/o puntos',
    'meses_consecutivos_ascenso': 'meses para subir',
    'meses_gracia_demotion': 'margen para bajar',
    'gracia_unidad': 'unidad del margen',
    'dividir_puntos_mitad': 'puntos a la mitad',
    'califica_fondos_viaje': 'fondos de viaje',
    'puntos_fuente': 'qué puntos cuentan',
    'orden': 'orden',
    'requisitos': 'requisitos del enlace',
    'logo': 'logo',
  };

  /// Qué cambió, en palabras.
  /// Una frase por cambio, en lenguaje simple (Victor, 2026-11-14: "las
  /// cards no se entienden mucho").
  static String _frasEquipo(String k, Object? a, Object? d) {
    String n(Object? x) => _v(x);
    String meses(Object? x) => x is num ? '${n(x)} ${x == 1 ? 'mes' : 'meses'}' : n(x);
    const fuente = {'tareas': 'solo los puntos por tareas', 'todos': 'todos los puntos', 'asistencia': 'solo los puntos por asistencia'};
    return switch (k) {
      'min_clases' => 'ahora pide ${n(d)} clases (antes ${n(a)})',
      'min_puntos' => 'ahora pide ${n(d)} puntos (antes ${n(a)})',
      'ventana_meses' => 'revisa cada ${meses(d)} (antes cada ${meses(a)})',
      'periodo_unidad' || 'gracia_unidad' => 'cambió la unidad de tiempo a ${n(d)}',
      'logica' => d == 'Y' ? 'ahora pide clases y puntos a la vez' : 'ahora basta con cumplir clases o puntos',
      'meses_consecutivos_ascenso' => 'para subir hay que cumplir ${meses(d)} seguidos (antes ${meses(a)})',
      'meses_gracia_demotion' => 'margen antes de bajar: ${meses(d)} (antes ${meses(a)})',
      'califica_fondos_viaje' => d == true ? 'ahora participa de los fondos de viaje' : 'ya no participa de los fondos de viaje',
      'puntos_fuente' => 'ahora cuentan ${fuente['$d'] ?? n(d)}',
      'orden' => 'cambió de lugar en la lista de equipos',
      'requisitos' => 'cambió los requisitos del enlace de invitación',
      'logo' => 'cambió su logo',
      'dividir_puntos_mitad' => '',
      _ => '',
    };
  }

  String _detalle(Map<String, dynamic> h) {
    final clave = '${h['clave']}';
    final antes = h['antes'], despues = h['despues'];
    switch (clave) {
      case 'equipo':
        final nombre = despues is Map ? despues['nombre'] : (antes is Map ? antes['nombre'] : 'un equipo');
        if (despues == null) return 'Borró el equipo $nombre.';
        if (antes == null) return 'Creó el equipo $nombre.';
        final cambios = <String>[];
        if (antes is Map && despues is Map) {
          if ('${antes['nombre']}' != '${despues['nombre']}') cambios.add('ahora se llama ${despues['nombre']} (antes ${antes['nombre']})');
          for (final k in _camposEquipo.keys) {
            if (k == 'nombre') continue;
            final a = antes[k], d = despues[k];
            if ('$a' == '$d') continue;
            final f = _frasEquipo(k, a, d);
            if (f.isNotEmpty) cambios.add(f);
          }
        }
        if (cambios.isEmpty) return 'Guardó $nombre sin cambios en sus reglas.';
        final t = cambios.join('; ');
        return 'En $nombre ${t[0].toLowerCase()}${t.substring(1)}.';
      case 'puntos':
        final d = despues is Map ? despues : const {};
        final a = antes is Map ? antes : const {};
        final desde = DateTime.tryParse('${d['desde'] ?? ''}');
        String tarde(Map m) => m['tardeCuenta'] == false ? 'no suma' : 'vale ${_v(m['tarde'])}';
        return 'Ahora llegar a tiempo vale ${_v(d['aTiempo'])} y llegar tarde ${tarde(d)} (antes ${_v(a['aTiempo'])} y ${tarde(a)})'
            '${desde == null ? '' : ', para las clases desde el ${Fechas.corta(desde)}'}. Los puntos ya ganados no cambian.';
      case 'corte':
        String t(Object? x) => x is Map
            ? (x['modo'] == 'auto'
                  ? 'se aplican solos apenas alguien cumple o deja de cumplir'
                  : 'se revisan antes: la lista llega ${x['avisoDias']} días antes y se aplica el día ${x['dia']}')
            : 'sin definir';
        return 'Los cambios de equipo ahora ${t(despues)} (antes ${t(antes)}).';
      case 'toleranciaMin':
        return 'La tolerancia para llegadas tarde ahora es de ${_v(despues, 'minutos')} (antes ${_v(antes, 'minutos')}).';
      case 'rectificacionDias':
        return 'Los Pivots ahora tienen ${_v(despues, 'días')} para revisar rectificaciones (antes ${_v(antes, 'días')}).';
      case 'inactividadDias':
        return 'Una persona ahora pasa a inactiva tras ${_v(despues, 'días')} sin venir (antes ${_v(antes, 'días')}).';
      case 'eventosMinPersonas':
        return 'Un evento ahora necesita al menos ${_v(despues, 'personas')} (antes ${_v(antes, 'personas')}).';
      case 'tardeCuentaClase':
        return despues == false ? 'Llegar tarde ya no cuenta para los requisitos del equipo.' : 'Llegar tarde ahora cuenta para los requisitos del equipo.';
      case 'tiposCuentan':
        return 'Ahora cuentan como clase: ${_v(despues)} (antes: ${_v(antes)}).';
      case 'logo':
        final d = despues is Map ? despues['destino'] : '';
        return d == 'liga'
            ? 'Cambió el logo de la liga.'
            : ('$d'.startsWith('medio-') ? 'Cambió el logo de un medio de pago.' : 'Cambió el logo de un equipo.');
      case 'cuenta':
        final n = despues is Map ? despues['nombre'] : (antes is Map ? antes['nombre'] : 'una cuenta');
        if (despues == null) return 'Borró la cuenta $n de Finanzas.';
        if (antes == null) {
          final s0 = despues is Map ? despues['saldo_inicial'] : null;
          return 'Creó la cuenta $n en Finanzas${s0 is num && s0 != 0 ? ' con ${Moneda.s}${_v(s0)} de saldo inicial' : ''}.';
        }
        if (despues is Map && despues['archivada'] == true) return 'Archivó la cuenta $n de Finanzas.';
        if (antes is Map && despues is Map && '${antes['saldo_inicial']}' != '${despues['saldo_inicial']}') {
          return 'Cambió el saldo inicial de $n: ${Moneda.s}${_v(despues['saldo_inicial'])} (antes ${Moneda.s}${_v(antes['saldo_inicial'])}).';
        }
        return 'Editó la cuenta $n de Finanzas.';
      case 'transparencia':
        return despues == true ? 'Activó la transparencia: el equipo ve los totales.' : 'Desactivó la transparencia.';
    }
    return 'Cambió "$clave": ${_v(despues is Map || despues is List ? null : despues)} (antes ${_v(antes is Map || antes is List ? null : antes)}).';
  }

  Future<void> _elegirPeriodo() async {
    final anios = [for (var a = DateTime.now().year; a >= _desdeAnio; a--) a];
    final v = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: const Text('Este mes'), onTap: () => Navigator.of(s).pop('mes')),
            ListTile(title: const Text('Últimos 6 meses'), onTap: () => Navigator.of(s).pop('6m')),
            for (final a in anios) ListTile(title: Text('Año $a'), onTap: () => Navigator.of(s).pop('anio:$a')),
            ListTile(title: const Text('Todo'), onTap: () => Navigator.of(s).pop('todo')),
            ListTile(title: const Text('Elegir fechas'), trailing: const Icon(Icons.date_range_rounded), onTap: () => Navigator.of(s).pop('rango')),
          ],
        ),
      ),
    );
    if (v == null || !mounted) return;
    if (v == 'rango') {
      final r = await showDateRangePicker(context: context, firstDate: DateTime(_desdeAnio), lastDate: Fechas.hoy(), initialDateRange: _rango);
      if (r == null) return;
      _rango = r;
    }
    _periodo = v;
    _cargar();
  }

  String get _textoPeriodo => switch (_periodo) {
    'mes' => 'Este mes',
    '6m' => 'Últimos 6 meses',
    'todo' => 'Todo',
    'rango' => _rango == null ? 'Fechas' : '${Fechas.corta(_rango!.start)} – ${Fechas.corta(_rango!.end)}',
    _ => 'Año ${_periodo.substring(5)}',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final todos = _items;
    final q = _q.trim().toLowerCase();
    final l = todos == null
        ? null
        : [
            for (final h in todos)
              if ((_grupo.isEmpty || _grupoDe('${h['clave']}') == _grupo) &&
                  (q.isEmpty || '${_nombres['${h['clave']}'] ?? ''} ${_detalle(h)} ${h['por']}'.toLowerCase().contains(q)))
                h,
          ];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Historial de cambios', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4 + altoBarra(context), 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(hintText: 'Buscar (persona, equipo, regla…)', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                ActionChip(avatar: const Icon(Icons.date_range_rounded, size: 18), label: Text(_textoPeriodo), onPressed: _elegirPeriodo),
                const SizedBox(width: 8),
                for (final e in _grupos.entries) ...[
                  FilterChip(
                    showCheckmark: false,
                    avatar: Icon(e.value.$2, size: 18),
                    label: Text(e.value.$1),
                    selected: _grupo == e.key,
                    onSelected: (v) => setState(() => _grupo = v ? e.key : ''),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: l == null
                  ? const Esqueleto(forma: FormaEsqueleto.lista, arriba: 8)
                  : l.isEmpty
                  ? Center(
                      child: Text(_error ?? 'Sin cambios con estos filtros.', style: TextStyle(color: p.textoSecundario)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                      itemCount: l.length,
                      itemBuilder: (_, i) {
                        final h = l[i];
                        final f = DateTime.tryParse('${h['fecha']}')?.toLocal();
                        final grupo = _grupos[_grupoDe('${h['clave']}')]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: p.tarjeta,
                            borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  h['automatico'] == true
                                      ? CircleAvatar(
                                          radius: 20,
                                          backgroundColor: p.suave,
                                          child: Icon(Icons.bolt_rounded, color: p.sobreSuave),
                                        )
                                      : AvatarPersona(nombre: '${h['por']}', foto: '${h['foto'] ?? ''}', tamano: 40),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(grupo.$2, size: 16, color: p.marcaTexto),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _nombres['${h['clave']}'] ?? '${h['clave']}',
                                                style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(_detalle(h), style: TextStyle(color: p.texto, height: 1.3)),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${h['por']}${f == null ? '' : ' · ${Fechas.corta(f)} a las ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}'}',
                                          style: TextStyle(fontSize: 12.5, color: p.textoSecundario),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen de un equipo: cada fila se cambia por separado en una hoja corta
/// que muestra a quién afecta (Victor, 2026-11-13).
class _EquipoScreen extends StatefulWidget {
  const _EquipoScreen({required this.sesion, required this.tiers, required this.indice, required this.gente, this.soloLectura = false, this.buscar});
  final Sesion sesion;
  final List<Map<String, dynamic>> tiers;
  final int indice;
  final List<_Persona> gente;

  /// Quien no es Pivot ve las reglas de su equipo sin poder cambiarlas
  /// (Victor, 2026-11-22: así sabe qué le afecta).
  final bool soloLectura;

  /// Búsqueda con la que abre (buscador de la liga → un ajuste del equipo).
  final String? buscar;

  @override
  State<_EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends State<_EquipoScreen> {
  late Map<String, dynamic> t = Map.of(widget.tiers[widget.indice]);
  bool _ocupado = false;

  /// Reglas de la liga (puntos y qué cuenta como clase de este equipo).
  Map<String, dynamic>? _rl;

  /// Premios por asistir que aplican a este equipo (racha, % de asistencia…),
  /// para explicarlos en su desplegable (Victor, 2026-11-27).
  List<Map<String, dynamic>> _premios = const [];

  @override
  void initState() {
    super.initState();
    if (!widget.soloLectura) _cargarReglas();
    s.api.get('getRecompensasEquipo', {'equipo': _nombre}).then((r) {
      if (mounted && r['exito'] == true) setState(() => _premios = [for (final x in (r['reglas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)]);
    }, onError: (_) {});
  }

  Future<void> _cargarReglas() async {
    try {
      final r = await _reglasDeLiga(s);
      if (mounted) setState(() => _rl = r);
    } catch (_) {}
  }

  Sesion get s => widget.sesion;
  bool get _piso => t['es_default'] == true;
  String get _nombre => '${t['nombre']}';
  Map<String, dynamic>? get _debajo {
    final i = widget.tiers.indexWhere((x) => x['id'] == t['id']);
    return i + 1 < widget.tiers.length ? widget.tiers[i + 1] : null;
  }

  String get _nombreDebajo => '${_debajo?['nombre'] ?? 'el equipo inicial'}';

  /// Lo que pide el equipo al inscribirse con su enlace, dicho con todas
  /// las letras (Victor, 2026-11-16).
  String get _textoInvitar {
    final pide = _propioNombres(t);
    if (_piso || pide.isEmpty) return 'Quien se inscribe con este enlace entra a $_nombre.';
    return 'Quien se inscribe con este enlace entra a $_nombre si tiene propio: ${_unirY(pide)}; '
        'si no, entra a $_nombreDebajo y se le explica por qué.';
  }

  /// Cobros, clase de gracia, equipamiento y lo de toda la liga que afecta
  /// al equipo (antes en Reglas → "Puntos y equipos").
  /// Cómo se sube o baja del equipo: arriba de todo (QA 2026-11-27).
  Widget _bannerSubir() {
    if (_piso) return const SizedBox.shrink();
    final r = _Regla.de(t);
    final propio = _unirY(_propioNombres(t));
    final curso = '${(t['requisitos'] as Map?)?['cursoNombre'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BannerAyuda(
        clave: 'equipo_subir_$_nombre',
        titulo: 'Cómo se sube o baja de $_nombre',
        texto: 'Así se entra, se sigue y se sale de $_nombre según sus reglas.',
        pasos: [
          (Icons.verified_outlined, 'Para seguir en $_nombre: ${r.texto}.'),
          (Icons.trending_up_rounded, 'Para subir desde $_nombreDebajo: cumplirlo ${r.textoSubir.replaceAll(' cumpliéndolo', '')}.'),
          (
            Icons.trending_down_rounded,
            r.gracia == 0
                ? 'Si se deja de cumplir, se baja a $_nombreDebajo en el siguiente cálculo.'
                : 'Si se deja de cumplir, hay ${textoPlazo(r.gracia, r.graciaUnidad)} para ponerse al día; si no, se baja a $_nombreDebajo.',
          ),
          if (propio.isNotEmpty) (Icons.roller_skating_outlined, 'Equipamiento: hay que tener propio $propio.'),
          if (curso.isNotEmpty) (Icons.school_outlined, 'Curso: hay que tener aprobado $curso.'),
          (Icons.event_repeat_rounded, 'Los cambios de equipo se aplican en la fecha que fija la liga.'),
        ],
      ),
    );
  }

  List<Widget> _reglasDelEquipo(BuildContext context) {
    final c = ConfigLiga.de(s);
    final porMes = const {'mes', 'elige', 'segun_equipamiento'}.contains('${c.cobroEquipo(_nombre)['modo']}');
    final g = c.graciaClases(_nombre);
    final propio = _unirY(_propioNombres(t));
    Future<void> abrir(Widget w) async {
      await SubAjustes.abrir(context, w);
      if (mounted) setState(() {});
    }

    // Desplegable de cómo se paga en este equipo, con sus valores (Victor, QA 2026-11-26).
    final dia = porMes ? ConfigEquipo(c, _nombre).diaFechaLimite : 0;
    // Desplegables que explican cada regla en su sección (Victor, 2026-11-27).
    final recompensa = porMes ? ConfigEquipo(c, _nombre).recompensaPago : const <String, dynamic>{};
    final textoPremioPago = textoRecompensa(recompensa);
    final pe = (_rl?['puntosEquipos'] as Map?)?[_nombre] as Map?;
    return [
      const SizedBox(height: 8),
      const _Seccion('PAGOS'),
      // Cómo se paga, dentro de Pagos y antes del premio (QA 2026-11-27).
      BannerAyuda(
        clave: 'equipo_pagos_$_nombre',
        titulo: 'Cómo se paga en $_nombre',
        texto: textoCobroEquipo(c, _nombre),
        pasos: [
          if (porMes) ...[
            (
              Icons.redeem_outlined,
              g == null
                  ? 'Clase de gracia: este equipo no la usa.'
                  : g == 0
                  ? 'Clase de gracia: no hay. Hay que pagar la cuota del mes antes de marcar Asistiré.'
                  : 'Clase de gracia: puedes venir a $g ${g == 1 ? 'entrenamiento' : 'entrenamientos'} del mes sin haber pagado. Después, para marcar Asistiré hay que pagar la cuota.',
            ),
            (
              Icons.event_busy_outlined,
              dia > 0 ? 'Fecha límite: la cuota del mes se paga hasta el día $dia.' : 'Fecha límite: la cuota no tiene una fecha límite fija.',
            ),
          ],
          (Icons.receipt_long_outlined, 'Cada pago queda registrado. Puedes verlo en Calendario → Actividad → Pagos y suscripciones.'),
        ],
      ),
      if (porMes && recompensa['activa'] != false && textoPremioPago.isNotEmpty)
        BannerAyuda(
          clave: 'equipo_premio_pago_$_nombre',
          titulo: 'Premio por pagar a tiempo',
          texto: 'Si pagas la cuota del mes hasta el día $dia recibes $textoPremioPago. Se da solo cuando se aprueba el pago.',
        ),
      _Fila(
        icono: Icons.payments_outlined,
        titulo: 'Cobros',
        texto: textoCobroEquipo(c, _nombre),
        alTocar: () => abrir(CobroEquipoScreen(config: c, equipo: _nombre)),
      ),
      if (porMes)
        _Fila(
          icono: Icons.redeem_outlined,
          titulo: 'Clases de gracia',
          texto: g == null
              ? 'No usa clases de gracia'
              : (g == 0 ? 'Debe pagar antes de marcar Asistiré' : '$g ${g == 1 ? 'clase' : 'clases'} al mes sin haber pagado'),
          alTocar: () async {
            await editarGracia(context, s, c, soloEquipo: _nombre);
            if (mounted) setState(() {});
          },
        ),
      // Pago a coaches por equipo (Victor, 2026-11-26).
      if (!widget.soloLectura && s.tieneArea('finanzas'))
        _Fila(
          icono: Icons.sports_rounded,
          titulo: 'Pago al equipo técnico',
          texto: 'Cuánto de lo que paga $_nombre va al equipo técnico, o un monto por entrenamiento',
          alTocar: () => abrir(PagoCoachesScreen(sesion: s, equipo: _nombre)),
        ),
      // Reglas propias del equipo (Victor, 2026-11-17): fecha límite y recompensa.
      if (porMes) ...[
        _Fila(
          icono: Icons.event_busy_outlined,
          titulo: 'Fecha límite de pago',
          texto: () {
            final pr = ConfigEquipo.propias(c, _nombre), e = ConfigEquipo(c, _nombre);
            return 'Día ${e.diaFechaLimite} · ${pr.containsKey('cuotaVenceDia') ? 'solo para este equipo' : 'igual que en la liga'}';
          }(),
          alTocar: () => _reglaPropia(context, c, 'Fecha límite de pago', const [
            'cuotaVenceDia',
            'cuotaGraciaDias',
            'cuotaRecargo',
            'cuotaRecargoTipo',
            'cuotaRecargoModo',
          ], () => VencimientoScreen(config: ConfigEquipo(c, _nombre))),
        ),
        _Fila(
          icono: Icons.workspace_premium_outlined,
          titulo: 'Recompensa por pagar a tiempo',
          texto: () {
            final pr = ConfigEquipo.propias(c, _nombre), r = ConfigEquipo(c, _nombre).recompensaPago, t = textoRecompensa(r);
            final que = r['activa'] == false || t.isEmpty ? 'Sin recompensa' : 'Recibe $t';
            return '$que · ${pr.containsKey('recompensaPago') ? 'solo para este equipo' : 'igual que en la liga'}';
          }(),
          alTocar: () => _reglaPropia(context, c, 'Recompensa por pagar a tiempo', const [
            'recompensaPago',
          ], () => RecompensasPagoScreen(config: ConfigEquipo(c, _nombre))),
        ),
      ],

      const SizedBox(height: 8),
      const _Seccion('EQUIPAMIENTO'),
      if (!_piso)
        _Fila(
          icono: Icons.roller_skating_outlined,
          titulo: 'Equipamiento propio',
          texto: propio.isEmpty ? 'No pide equipamiento propio' : 'Pide propio: $propio',
          alTocar: () async {
            if (await editarEquipamientoPropio(context, s, t) && mounted) {
              final r = await s.api.get('getTiers', {'adminToken': s.adminToken});
              final nuevo = (r['tiers'] as List? ?? const []).whereType<Map>().where((x) => x['id'] == t['id']);
              if (mounted && nuevo.isNotEmpty) setState(() => t = Map<String, dynamic>.from(nuevo.first));
            }
          },
        ),
      // Requisito "tener aprobado tal curso" (Victor, 2026-11-26).
      if (!_piso)
        _Fila(
          icono: Icons.school_outlined,
          titulo: 'Curso aprobado',
          texto: '${(t['requisitos'] as Map?)?['cursoId'] ?? ''}'.isEmpty
              ? 'No pide un curso'
              : 'Pide tener aprobado ${(t['requisitos'] as Map?)?['cursoNombre'] ?? 'un curso'}',
          alTocar: () async {
            if (await editarCursoRequerido(context, s, t) && mounted) {
              final r = await s.api.get('getTiers', {'adminToken': s.adminToken});
              final nuevo = (r['tiers'] as List? ?? const []).whereType<Map>().where((x) => x['id'] == t['id']);
              if (mounted && nuevo.isNotEmpty) setState(() => t = Map<String, dynamic>.from(nuevo.first));
            }
          },
        ),
      _Fila(
        icono: Icons.handshake_outlined,
        titulo: 'Préstamo de equipamiento',
        texto: 'Cuándo puede pedir equipamiento de la liga',
        alTocar: () => abrir(ReglasPrestamoScreen(repo: InventarioRepo(s))),
      ),
      const SizedBox(height: 8),
      const _Seccion('PUNTOS Y CLASES'),
      if (pe != null)
        BannerAyuda(
          clave: 'equipo_puntos_$_nombre',
          titulo: 'Cómo se ganan puntos en $_nombre',
          texto: 'En $_nombre se suman puntos por venir a entrenar y por hacer tareas.',
          pasos: [
            (Icons.event_available_outlined, 'Asistencia: ${textoPuntosVersion((pe['actual'] as Map?) ?? const {})}.'),
            // Las tareas suman en cualquier equipo (QA 2026-11-27).
            (Icons.task_alt_rounded, 'Tareas: cada tarea terminada y aprobada suma los puntos que indica.'),
          ],
        ),
      if (_premios.isNotEmpty)
        BannerAyuda(
          clave: 'equipo_premios_$_nombre',
          titulo: 'Premios por asistir',
          texto: _premios.length == 1 ? 'En $_nombre hay un premio por asistencia.' : 'En $_nombre hay ${_premios.length} premios por asistencia.',
          pasos: [
            for (final x in _premios)
              (
                Icons.local_fire_department_outlined,
                '${x['nombre']}: por ${x['condicionTexto']}, ${x['premioTexto']}${x['deLaLiga'] == true ? ' (de toda la liga)' : ''}.',
              ),
          ],
        ),
      _Fila(
        icono: Icons.star_outline_rounded,
        titulo: 'Puntos por asistencia',
        texto: () {
          final pe = (_rl?['puntosEquipos'] as Map?)?[_nombre] as Map?;
          if (pe == null) return 'Cuántos puntos da venir a horario o tarde';
          final prox = pe['proxima'] as Map?;
          return [
            textoPuntosVersion((pe['actual'] as Map?) ?? const {}),
            if (prox != null) 'Desde el ${Fechas.corta(DateTime.parse('${prox['desde']}'))}: ${textoPuntosVersion(prox)}',
          ].join('\n');
        }(),
        alTocar: () async {
          if (await editarPuntosEquipo(context, s, _nombre)) _cargarReglas();
        },
      ),
      _Fila(
        icono: Icons.event_available_outlined,
        titulo: 'Qué cuenta como clase',
        texto: _rl == null
            ? 'Qué eventos suman para los requisitos'
            : textoQueCuenta(reglaClaseEquipo((_rl!['reglas'] as Map<String, dynamic>?) ?? const {}, _nombre)),
        alTocar: () async {
          if (await editarQueCuentaEquipo(context, s, _nombre)) _cargarReglas();
        },
      ),
      const SizedBox(height: 8),
      const _Seccion('DE TODA LA LIGA'),
      if (t['califica_fondos_viaje'] == true)
        BannerAyuda(
          clave: 'equipo_fondos_$_nombre',
          titulo: 'Fondos de viaje',
          texto: 'Quienes están en $_nombre participan de los fondos de viaje: cuando la liga viaja a un torneo, aporta parte del costo según sus reglas.',
        ),
      _Fila(
        icono: Icons.rule_folder_outlined,
        titulo: 'Reglas de la liga',
        texto: 'Cobros, asistencia, puntos, equipamiento y privacidad · cada equipo puede cambiar sus pagos',
        alTocar: () => abrir(ReglasScreen(sesion: s)),
      ),
      if (s.tieneArea('finanzas'))
        _Fila(
          icono: Icons.flight_takeoff_rounded,
          titulo: 'Fondos de viaje',
          texto: 'Cuánto se da para viajar y cómo se reparte',
          alTocar: () => abrir(FondosViajeScreen(repo: TesoreriaRepo(s))),
        ),

      for (final (id, icono, titulo, texto) in const [
        ('corte', Icons.event_repeat_rounded, 'Cuándo se aplican los cambios', 'Cuándo se sube o baja de equipo'),
        ('historial', Icons.history_rounded, 'Historial de cambios', 'Últimos 6 meses'),
      ])
        _Fila(
          icono: icono,
          titulo: titulo,
          texto: '$texto · cambia para todos los equipos',
          alTocar: () => id == 'historial'
              ? Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HistorialAjustesScreen(sesion: s, grupo: 'equipos'),
                  ),
                )
              : editarCorteEquipos(context, s, widget.tiers),
        ),
    ];
  }

  /// "Igual que en la liga" o "Solo para este equipo" (Victor, 2026-11-17).
  Future<void> _reglaPropia(BuildContext context, ConfigLiga c, String titulo, List<String> claves, Widget Function() pantalla) async {
    final propia = ConfigEquipo.propias(c, _nombre).keys.any(claves.contains);
    final v = await showModalBottomSheet<bool>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (h) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(titulo, style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Cada equipo puede usar la de la liga o tener la suya. Rige desde que se guarda; los pagos y puntos anteriores no cambian.',
                style: TextStyle(fontSize: 13.5, color: h.pivot.textoSecundario),
              ),
            ),
            for (final (op, t, sub) in [
              (false, 'Igual que en la liga', 'Si la liga la cambia, cambia aquí también'),
              (true, 'Solo para $_nombre', 'Se elige aparte para este equipo'),
            ])
              ListTile(
                title: Text(t),
                subtitle: Text(sub),
                trailing: op == propia ? Icon(Icons.check_rounded, color: h.pivot.marcaTexto) : null,
                onTap: () => Navigator.of(h).pop(op),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (v == null || !context.mounted) return;
    if (v) {
      await SubAjustes.abrir(context, pantalla());
    } else if (propia) {
      final m = ScaffoldMessenger.of(context);
      try {
        await ConfigEquipo(c, _nombre).igualQueLaLiga(claves);
        m.showSnackBar(const SnackBar(content: Text('Listo: usa lo de la liga desde ahora.')));
      } catch (e) {
        m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
      }
    }
    if (mounted) setState(() {});
  }

  String get _inicial => '${widget.tiers.firstWhere((x) => x['es_default'] == true, orElse: () => widget.tiers.last)['nombre']}';
  List<_Persona> get _miembros => widget.gente.where((x) => x.categoria == _nombre && x.evaluable && !x.usaEquipo).toList();
  List<_Persona> get _candidatos => _debajo == null ? const [] : widget.gente.where((x) => x.categoria == _nombreDebajo && x.evaluable).toList();

  void _aviso(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _guardar(Map<String, Object?> cambios, {_Regla? regla, String ok = 'Guardado'}) async {
    setState(() => _ocupado = true);
    try {
      final base = (regla ?? _Regla.de(t)).params({...t, ...cambios});
      final nuevo = await _guardarTier(s, {...base, ...cambios.map((k, v) => MapEntry(k, v is Map ? jsonEncode(v) : v))});
      if (!mounted) return;
      setState(() {
        if (nuevo.isNotEmpty) t = Map.of(nuevo);
        _ocupado = false;
      });
      _aviso(ok);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      _aviso(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.');
    }
  }

  // Subsección en vez de hoja inferior (Victor, 2026-11-15).
  Future<bool?> _hoja(String titulo, List<Widget> Function(StateSetter set) contenido, {String boton = 'Guardar'}) =>
      abrirSubseccion(context, titulo: titulo, contenido: contenido, boton: boton);

  /// Mantenerse en el equipo, por pasos (Victor, 2026-11-16: la hoja con
  /// todo junto daba miedo tocarla).
  Future<void> _mantener() async {
    final antes = _Regla.de(t);
    final r = await Navigator.of(context).push<_Regla>(
      MaterialPageRoute(
        builder: (_) => _MantenerAsistente(antes: antes, miembros: _miembros, candidatos: _candidatos, nombre: _nombre, debajo: _nombreDebajo),
      ),
    );
    if (r != null) await _guardar(const {}, regla: r);
  }

  Future<void> _subir() async {
    final antes = _Regla.de(t);
    final r = antes.copia();
    final ok = await _hoja('Ascenso al equipo', (set) {
      return [
        SelectorNumero(valor: r.subir, min: 1, max: 12, etiqueta: r.subir == 1 ? 'mes' : 'meses seguidos', alCambiar: (v) => set(() => r.subir = v.toInt())),
        const SizedBox(height: 12),
        _Nota(texto: 'Desde $_nombreDebajo, sube quien cumple lo de $_nombre ${r.textoSubir.replaceFirst(' cumpliéndolo', '')}.'),
      ];
    });
    if (ok == true) await _guardar(const {}, regla: r);
  }

  Future<void> _bajar() async {
    final antes = _Regla.de(t);
    final r = antes.copia();
    final ok = await _hoja('Descenso del equipo', (set) {
      return [
        SelectorPlazo(valor: r.gracia, unidad: r.graciaUnidad, min: 0, max: 52, alCambiar: (v, u) => set(() => (r.gracia = v, r.graciaUnidad = u))),
        const SizedBox(height: 12),
        _Nota(
          texto: r.gracia == 0
              ? 'Si deja de cumplir, baja a $_nombreDebajo en el siguiente cálculo.'
              : 'Si deja de cumplir, tiene ${textoPlazo(r.gracia, r.graciaUnidad)} para ponerse al día antes de bajar a $_nombreDebajo.',
        ),
      ];
    });
    if (ok == true) await _guardar(const {}, regla: r);
  }

  Future<void> _renombrar() async {
    final c = TextEditingController(text: _nombre);
    final n = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        scrollable: true,
        title: const Text('Nombre del equipo'),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(d).pop(c.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (n == null || n.isEmpty || n == _nombre) return;
    if (widget.tiers.any((x) => x['id'] != t['id'] && '${x['nombre']}'.toLowerCase() == n.toLowerCase())) {
      _aviso('Ya hay un equipo con ese nombre.');
      return;
    }
    await _guardar({'nombre': n}, ok: 'Ahora se llama $n. Quienes estaban en $_nombre siguen en el equipo.');
  }

  Future<void> _logo() async {
    try {
      final u = await elegirYSubirLogo(context, s, '${t['id']}');
      if (u != null && mounted) {
        setState(() => t['logo'] = u);
        _aviso('Logo actualizado');
      }
    } catch (e) {
      _aviso(e is ApiException ? e.message : 'No se pudo subir el logo.');
    }
  }

  String get _enlace => '${ApiConfig.webAppUrl}/inscripcion/?equipo=${t['codigo_invitacion'] ?? ''}';

  Future<void> _mover(int d) async {
    final otros = widget.tiers.where((x) => x['es_default'] != true).toList();
    final i = otros.indexWhere((x) => x['id'] == t['id']);
    final j = i + d;
    if (i < 0 || j < 0 || j >= otros.length) return;
    final otro = otros[j];
    final miOrden = t['orden'], suOrden = otro['orden'];
    setState(() => _ocupado = true);
    try {
      await _guardarTier(s, {..._Regla.de(otro).params(otro), 'orden': miOrden});
      final nuevo = await _guardarTier(s, {..._Regla.de(t).params(t), 'orden': suOrden});
      if (mounted) Navigator.of(context).pop();
      _aviso(d < 0 ? '${nuevo['nombre']} quedó más arriba' : '${nuevo['nombre']} quedó más abajo');
    } catch (e) {
      if (mounted) setState(() => _ocupado = false);
      _aviso(e is ApiException ? e.message : 'No se pudo cambiar el orden.');
    }
  }

  Future<void> _borrar() async {
    final n = widget.gente.where((x) => x.categoria == _nombre).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿Borrar $_nombre?'),
        content: Text(
          n == 0
              ? 'No hay nadie en este equipo.'
              : '${n == 1 ? 'La persona' : 'Las $n personas'} de $_nombre ${n == 1 ? 'pasa' : 'pasan'} a $_inicial. Sus puntos no cambian.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await s.api.post('deleteTier', {'adminToken': s.adminToken, 'id': t['id']});
    if (r['error'] != null) {
      _aviso('${r['error']}');
      return;
    }
    if (mounted) Navigator.of(context).pop();
    _aviso('$_nombre borrado');
  }

  /// Texto del buscador; null = cerrado.
  late String? _q = widget.buscar;
  late final _ctlQ = TextEditingController(text: widget.buscar ?? '');

  @override
  void dispose() {
    _ctlQ.dispose();
    super.dispose();
  }

  static String _plano(String x) => x
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u');

  /// Con algo escrito, solo las filas que lo contienen (título o valor).
  List<Widget> _filtrar(BuildContext context, List<Widget> hijos) {
    final q = _plano(_q?.trim() ?? '');
    if (q.isEmpty) return hijos;
    final palabras = q.split(RegExp(r'\s+'));
    // Bug del QA (2026-11-26): solo miraba las filas sueltas, así que en la
    // vista de solo lectura (todo dentro de _SoloLectura/Column) nunca
    // encontraba nada. Ahora busca también dentro de esos contenedores.
    // También los desplegables que explican las reglas (2026-11-27).
    final filas = <(Widget, String)>[];
    void juntar(Widget w) {
      if (w is _Fila) {
        filas.add((w, '${w.titulo} ${w.texto}'));
      } else if (w is BannerAyuda) {
        filas.add((w, '${w.titulo} ${w.texto} ${w.pasos.map((x) => x.$2).join(' ')}'));
      } else if (w is _SoloLectura) {
        juntar(w.child);
      } else if (w is Column) {
        w.children.forEach(juntar);
      } else if (w is Padding && w.child != null) {
        juntar(w.child!);
      } else if (w is Resaltable) {
        juntar(w.child);
      }
    }

    hijos.forEach(juntar);
    final l = <Widget>[
      for (final (h, texto) in filas)
        if (palabras.every(_plano(texto).contains)) h,
    ];
    if (l.isNotEmpty) {
      return widget.soloLectura
          ? [
              _SoloLectura(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: l),
              ),
            ]
          : l;
    }
    return [
      Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Text(
          'No hay ajustes con "${_q!.trim()}" en este equipo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pivot.textoSecundario),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final r = _Regla.de(t);
    final otros = widget.tiers.where((x) => x['es_default'] != true).toList();
    final pos = otros.indexWhere((x) => x['id'] == t['id']);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        // Buscador dentro del equipo (Victor, 2026-11-16), como el de Mi Liga.
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _q == null
              ? Text(
                  _nombre,
                  key: const ValueKey('t'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                )
              : TextField(
                  key: const ValueKey('b'),
                  controller: _ctlQ,
                  autofocus: widget.buscar == null,
                  textInputAction: TextInputAction.search,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(hintText: 'Buscar en $_nombre', border: InputBorder.none, filled: false),
                ),
        ),
        actions: [
          IconButton(
            tooltip: _q == null ? 'Buscar' : 'Cerrar búsqueda',
            icon: Icon(_q == null ? Icons.search_rounded : Icons.close_rounded),
            onPressed: () => setState(() {
              _q = _q == null ? '' : null;
              _ctlQ.clear();
            }),
          ),
        ],
        bottom: _ocupado ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: AbsorbPointer(
        absorbing: _ocupado,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 40 + MediaQuery.paddingOf(context).bottom),
          children: _filtrar(context, [
            if (widget.soloLectura) ...[
              Center(
                child: LogoEquipo(nombre: _nombre, url: t['logo'] as String?, tamano: 88),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Así funciona $_nombre. Solo los Pivots pueden cambiarlo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textoSecundario),
                ),
              ),
              const SizedBox(height: 16),
              _bannerSubir(),
              _SoloLectura(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_piso) ...[
                      _Fila(icono: Icons.verified_outlined, titulo: 'Mantenerse en el equipo', texto: 'Pide ${r.texto}.', alTocar: null),
                      _Fila(icono: Icons.trending_up_rounded, titulo: 'Ascenso al equipo', texto: 'Desde $_nombreDebajo: ${r.textoSubir}.', alTocar: null),
                      _Fila(icono: Icons.trending_down_rounded, titulo: 'Descenso del equipo', texto: '${r.textoBajar}.', alTocar: null),
                    ],
                    ..._reglasDelEquipo(context),
                  ],
                ),
              ),
            ] else ...[
              Center(
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _logo,
                  child: Stack(
                    children: [
                      LogoEquipo(nombre: _nombre, url: t['logo'] as String?, tamano: 88),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: p.marca,
                          child: Icon(Icons.edit_rounded, size: 16, color: p.sobreMarca),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Sin «Hoy lo cumplen…» en la vista del equipo (QA 2026-11-27).
              if (_piso)
                Center(
                  child: Text('Equipo inicial: quien se une entra aquí.', style: TextStyle(color: p.textoSecundario)),
                ),
              const SizedBox(height: 16),
              _bannerSubir(),
              _Fila(icono: Icons.badge_outlined, titulo: 'Nombre del equipo', texto: _nombre, alTocar: _renombrar),
              if (!_piso) ...[
                _Fila(icono: Icons.verified_outlined, titulo: 'Mantenerse en el equipo', texto: 'Pide ${r.texto}.', alTocar: _mantener),
                _Fila(icono: Icons.trending_up_rounded, titulo: 'Ascenso al equipo', texto: 'Desde $_nombreDebajo: ${r.textoSubir}.', alTocar: _subir),
                _Fila(icono: Icons.trending_down_rounded, titulo: 'Descenso del equipo', texto: '${r.textoBajar}.', alTocar: _bajar),
                if (otros.length > 1)
                  _Fila(
                    icono: Icons.swap_vert_rounded,
                    titulo: 'Orden',
                    texto: 'Puesto ${pos + 1} de ${otros.length} (el de arriba es el más exigente)',
                    alTocar: null,
                    final_: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(tooltip: 'Más arriba', onPressed: pos > 0 ? () => _mover(-1) : null, icon: const Icon(Icons.arrow_upward_rounded)),
                        IconButton(
                          tooltip: 'Más abajo',
                          onPressed: pos < otros.length - 1 ? () => _mover(1) : null,
                          icon: const Icon(Icons.arrow_downward_rounded),
                        ),
                      ],
                    ),
                  ),
              ],
              // Invitar al equipo (Victor, 2026-11-15): a la vista y fácil de
              // compartir. Quien no cumple lo que pide el equipo entra al inicial
              // y la inscripción le explica por qué.
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(gradient: PivotPaleta.degradadoMarca, borderRadius: BorderRadius.circular(PivotRadios.grande)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_add_alt_1_rounded, color: PivotPaleta.sobreSeccion),
                          SizedBox(width: 8),
                          Text(
                            'Invita al equipo',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: PivotPaleta.sobreSeccion),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_textoInvitar, style: TextStyle(color: PivotPaleta.sobreSeccion.withValues(alpha: 0.92))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: PivotPaleta.sobreSeccion, foregroundColor: p.marcaTexto),
                              onPressed: () => SharePlus.instance.share(ShareParams(text: 'Únete a $_nombre en Pivot: $_enlace')),
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('Compartir'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PivotPaleta.sobreSeccion,
                                side: BorderSide(color: PivotPaleta.sobreSeccion.withValues(alpha: 0.7)),
                              ),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: _enlace));
                                _aviso('Enlace copiado');
                              },
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copiar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Reglas del equipo dentro del equipo (Victor, 2026-11-16); las
              // de toda la liga que lo afectan, con su etiqueta.
              ..._reglasDelEquipo(context),
              if (!_piso) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(onPressed: _borrar, icon: const Icon(Icons.delete_outline_rounded), label: Text('Borrar $_nombre')),
                ),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}

enum _Paso { nombre, cobro, que, periodo, clases, puntos, subirBajar, resumen }

/// Asistente para crear un equipo nuevo (queda justo encima del inicial).
class _NuevoEquipoAsistente extends StatefulWidget {
  const _NuevoEquipoAsistente({required this.sesion, required this.inicial, required this.gente});
  final Sesion sesion;
  final Map<String, dynamic> inicial;
  final List<_Persona> gente;

  @override
  State<_NuevoEquipoAsistente> createState() => _NuevoEquipoAsistenteState();
}

class _NuevoEquipoAsistenteState extends State<_NuevoEquipoAsistente> {
  final _antes = _Regla(clases: 0, puntos: 0, logica: 'O', ventana: 1, unidad: 'mes', fuente: 'tareas', subir: 3, gracia: 1, graciaUnidad: 'mes');
  late final _Regla _r = _antes.copia()
    ..clases = 2
    ..logica = 'Y';
  final _nombreCtl = TextEditingController();
  final _focoNombre = FocusNode();
  _Paso _paso = _Paso.nombre;
  bool _adelante = true, _ocupado = false;

  /// Cómo paga el equipo nuevo (Victor, 2026-11-15); se cambia en Reglas.
  String _cobro = 'mes';

  String get _nombre => _nombreCtl.text.trim().isEmpty ? 'el equipo nuevo' : _nombreCtl.text.trim();
  String get _nombreDebajo => '${widget.inicial['nombre']}';
  List<_Persona> get _candidatos => widget.gente.where((x) => x.categoria == _nombreDebajo && x.evaluable).toList();

  List<_Paso> get _pasos => [
    _Paso.nombre,
    _Paso.cobro,
    _Paso.que,
    _Paso.periodo,
    if (_r.modo != 'puntos') _Paso.clases,
    if (_r.modo != 'clases') _Paso.puntos,
    _Paso.subirBajar,
    _Paso.resumen,
  ];

  @override
  void initState() {
    super.initState();
    // En Android, pedir el foco justo al abrir el asistente hace que el
    // teclado intente abrirse mientras la animación de entrada todavía está
    // corriendo, lo que provoca un crash/bucle de cierre. Se espera al
    // primer frame estable para pedirlo (fix 2026-11-23).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focoNombre.requestFocus();
    });
  }

  @override
  void dispose() {
    _nombreCtl.dispose();
    _focoNombre.dispose();
    super.dispose();
  }

  void _ir(int d) {
    final l = _pasos;
    final i = l.indexOf(_paso) + d;
    if (i < 0) {
      Navigator.of(context).pop();
      return;
    }
    if (i >= l.length) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _adelante = d > 0;
      _paso = l[i];
    });
  }

  void _modo(String m) => setState(() {
    switch (m) {
      case 'clases':
        if (_r.clases == 0) _r.clases = 2;
        _r.puntos = 0;
        _r.logica = 'Y';
      case 'puntos':
        if (_r.puntos == 0) _r.puntos = 5;
        _r.clases = 0;
        _r.logica = 'Y';
      default:
        if (_r.clases == 0) _r.clases = 2;
        if (_r.puntos == 0) _r.puntos = 5;
        _r.logica = m == 'y' ? 'Y' : 'O';
    }
  });

  Future<void> _guardar() async {
    setState(() => _ocupado = true);
    final ini = widget.inicial;
    final orden = (ini['orden'] as num?)?.toInt() ?? 1;
    try {
      // Queda justo encima del inicial: el inicial baja un lugar.
      await _guardarTier(widget.sesion, {
        ..._r.params({'orden': orden, 'nombre': _nombreCtl.text.trim(), 'requisitos': const {}}),
      });
      await _guardarTier(widget.sesion, {..._Regla.de(ini).params(ini), 'orden': orden + 1});
      await ConfigLiga.de(widget.sesion).guardarReglas({
        'cobroEquipos': {
          _nombreCtl.text.trim(): {'modo': _cobro},
        },
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    }
  }

  Widget get _impacto => _Impacto(antes: _antes, ahora: _r, miembros: const [], candidatos: _candidatos, nombre: _nombre, debajo: _nombreDebajo);

  @override
  Widget build(BuildContext context) {
    final l = _pasos;
    final p = context.pivot;
    return Asistente(
      titulo: 'Nuevo equipo',
      indice: l.indexOf(_paso),
      total: l.length,
      clavePaso: _paso,
      adelante: _adelante,
      alAtras: () => _ir(-1),
      tituloPaso: switch (_paso) {
        _Paso.nombre => '¿Cómo se llama?',
        _Paso.cobro => '¿Cómo paga?',
        _Paso.que => '¿Qué pide?',
        _Paso.periodo => '¿En cuánto tiempo?',
        _Paso.clases => '¿Cuántas clases?',
        _Paso.puntos => '¿Cuántos puntos?',
        _Paso.subirBajar => 'Subir y bajar',
        _Paso.resumen => 'Revisa',
      },
      ayuda: switch (_paso) {
        _Paso.nombre => 'Quedará justo encima de $_nombreDebajo.',
        _Paso.cobro => 'Se puede cambiar después en Reglas, con precio propio si quieres.',
        _Paso.periodo => 'Con meses, se cuentan meses completos.',
        _ => null,
      },
      cuerpo: switch (_paso) {
        _Paso.nombre => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nombreCtl,
              focusNode: _focoNombre,
              // autofocus en Android causa crash al abrir el asistente porque
              // el teclado intenta abrirse mientras la pantalla todavía está
              // animando. Se desactiva y el foco se pide en el primer frame
              // estable via initState/addPostFrameCallback (fix 2026-11-23).
              autofocus: false,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Ej. Halcones'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        _Paso.cobro => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final e in modosCobro.entries)
              OpcionAsistente(
                icono: switch (e.key) {
                  'mes' => Icons.calendar_month_outlined,
                  'clase' => Icons.confirmation_number_outlined,
                  'elige' => Icons.alt_route_rounded,
                  'sin_cobro' => Icons.money_off_rounded,
                  _ => Icons.roller_skating_outlined,
                },
                titulo: e.value.$1,
                texto: e.value.$2,
                activa: _cobro == e.key,
                alTocar: () => setState(() => _cobro = e.key),
              ),
          ],
        ),
        _Paso.que => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (m, icono, titulo, texto) in const [
              ('clases', Icons.event_available_rounded, 'Solo clases', 'Un mínimo de clases asistidas.'),
              ('puntos', Icons.star_outline_rounded, 'Solo puntos', 'Un mínimo de puntos.'),
              ('o', Icons.alt_route_rounded, 'Clases o puntos', 'Basta con uno de los dos.'),
              ('y', Icons.join_inner_rounded, 'Clases y puntos', 'Hay que cumplir los dos.'),
            ])
              OpcionAsistente(icono: icono, titulo: titulo, texto: texto, activa: _r.modo == m, alTocar: () => _modo(m)),
          ],
        ),
        _Paso.periodo => ListView(
          padding: const EdgeInsets.all(16),
          children: [SelectorPlazo(valor: _r.ventana, unidad: _r.unidad, max: 52, alCambiar: (v, u) => setState(() => (_r.ventana = v, _r.unidad = u)))],
        ),
        _Paso.clases => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SelectorNumero(
              valor: _r.clases,
              min: 1,
              max: 60,
              etiqueta: _r.clases == 1 ? 'clase' : 'clases',
              alCambiar: (v) => setState(() => _r.clases = v.toInt()),
            ),
            const SizedBox(height: 16),
            _impacto,
          ],
        ),
        _Paso.puntos => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SelectorNumero(valor: _r.puntos, min: 1, max: 500, etiqueta: 'puntos', alCambiar: (v) => setState(() => _r.puntos = v.toInt())),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('Solo por tareas'), selected: _r.fuente == 'tareas', onSelected: (_) => setState(() => _r.fuente = 'tareas')),
                ChoiceChip(label: const Text('Todos los puntos'), selected: _r.fuente == 'todos', onSelected: (_) => setState(() => _r.fuente = 'todos')),
              ],
            ),
            const SizedBox(height: 16),
            _impacto,
          ],
        ),
        _Paso.subirBajar => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Para subir desde $_nombreDebajo',
              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
            ),
            SelectorNumero(
              valor: _r.subir,
              min: 1,
              max: 12,
              etiqueta: _r.subir == 1 ? 'mes' : 'meses seguidos',
              alCambiar: (v) => setState(() => _r.subir = v.toInt()),
            ),
            const SizedBox(height: 16),
            Text(
              'Margen antes de bajar',
              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
            ),
            SelectorPlazo(
              valor: _r.gracia,
              unidad: _r.graciaUnidad,
              min: 0,
              max: 52,
              alCambiar: (v, u) => setState(() => (_r.gracia = v, _r.graciaUnidad = u)),
            ),
          ],
        ),
        _Paso.resumen => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Nota(texto: '$_nombre pide ${_r.texto}. Para subir: ${_r.textoSubir}. Para bajar: ${_r.textoBajar.toLowerCase()}.'),
            const SizedBox(height: 12),
            _impacto,
          ],
        ),
      },
      textoBoton: _paso == _Paso.resumen ? 'Crear equipo' : 'Siguiente',
      alContinuar: _paso == _Paso.nombre && _nombreCtl.text.trim().isEmpty ? null : (_paso == _Paso.resumen ? _guardar : () => _ir(1)),
      ocupado: _ocupado,
    );
  }
}

enum _PasoM { que, clases, puntos, periodo, resumen }

/// Qué pide un equipo para mantenerse, en pasos cortos con ejemplos.
class _MantenerAsistente extends StatefulWidget {
  const _MantenerAsistente({required this.antes, required this.miembros, required this.candidatos, required this.nombre, required this.debajo});
  final _Regla antes;
  final List<_Persona> miembros, candidatos;
  final String nombre, debajo;

  @override
  State<_MantenerAsistente> createState() => _MantenerAsistenteState();
}

class _MantenerAsistenteState extends State<_MantenerAsistente> {
  late final _Regla _r = widget.antes.copia();
  _PasoM _paso = _PasoM.que;
  bool _adelante = true;

  List<_PasoM> get _pasos => [_PasoM.que, if (_r.modo != 'puntos') _PasoM.clases, if (_r.modo != 'clases') _PasoM.puntos, _PasoM.periodo, _PasoM.resumen];

  void _ir(int d) {
    final l = _pasos;
    final i = l.indexOf(_paso) + d;
    if (i < 0) return Navigator.of(context).pop();
    if (i >= l.length) return;
    setState(() => (_adelante = d > 0, _paso = l[i]));
  }

  void _modo(String m) => setState(() {
    final a = widget.antes;
    switch (m) {
      case 'clases':
        if (_r.clases == 0) _r.clases = a.clases > 0 ? a.clases : 3;
        _r.puntos = 0;
        _r.logica = 'Y';
      case 'puntos':
        if (_r.puntos == 0) _r.puntos = a.puntos > 0 ? a.puntos : 5;
        _r.clases = 0;
        _r.logica = 'Y';
      default:
        if (_r.clases == 0) _r.clases = a.clases > 0 ? a.clases : 3;
        if (_r.puntos == 0) _r.puntos = a.puntos > 0 ? a.puntos : 5;
        _r.logica = m == 'y' ? 'Y' : 'O';
    }
  });

  /// Ejemplo con fechas reales de qué se mira y qué pasa si se cambia.
  String get _ejemploPeriodo {
    final hoy = Fechas.hoy();
    final n = _r.ventana;
    if (_r.unidad == 'mes' || _r.unidad == 'anio') {
      final meses = _r.unidad == 'anio' ? n * 12 : n;
      final hasta = DateTime(hoy.year, hoy.month - 1);
      final desde = DateTime(hoy.year, hoy.month - meses);
      final rango = meses == 1 ? 'todo ${Fechas.mes(hasta)}' : 'de ${Fechas.mes(desde)} a ${Fechas.mes(hasta)}';
      return 'Se cuentan meses completos y el mes en curso no entra. Por ejemplo, en una revisión de ${Fechas.mes(hoy)} se mira $rango.';
    }
    final desde = hoy.subtract(Duration(days: _r.unidad == 'semana' ? n * 7 : n));
    return 'Se cuenta hacia atrás desde el día de la revisión. Por ejemplo, hoy se miraría del ${Fechas.corta(desde)} al ${Fechas.corta(hoy)}.';
  }

  @override
  Widget build(BuildContext context) {
    final l = _pasos;
    final p = context.pivot;
    final impacto = _Impacto(
      antes: widget.antes,
      ahora: _r,
      miembros: widget.miembros,
      candidatos: widget.candidatos,
      nombre: widget.nombre,
      debajo: widget.debajo,
    );
    return Asistente(
      titulo: 'Mantenerse',
      indice: l.indexOf(_paso),
      total: l.length,
      clavePaso: _paso,
      adelante: _adelante,
      alAtras: () => _ir(-1),
      tituloPaso: switch (_paso) {
        _PasoM.que => '¿Qué se pide?',
        _PasoM.clases => '¿Cuántas clases?',
        _PasoM.puntos => '¿Cuántos puntos?',
        _PasoM.periodo => '¿En cuánto tiempo?',
        _PasoM.resumen => 'Revisa',
      },
      ayuda: switch (_paso) {
        _PasoM.que => 'Lo que hay que cumplir para seguir en ${widget.nombre}.',
        _PasoM.periodo => 'El tiempo en el que se suman las clases o los puntos.',
        _PasoM.resumen => 'Así quedaría y a quién afecta hoy. Nada cambia hasta que guardes.',
        _ => null,
      },
      cuerpo: switch (_paso) {
        _PasoM.que => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (m, icono, titulo, texto) in const [
              ('clases', Icons.event_available_rounded, 'Solo clases', 'Un mínimo de clases asistidas.'),
              ('puntos', Icons.star_outline_rounded, 'Solo puntos', 'Un mínimo de puntos.'),
              ('o', Icons.alt_route_rounded, 'Clases o puntos', 'Basta con cumplir uno de los dos.'),
              ('y', Icons.join_inner_rounded, 'Clases y puntos', 'Hay que cumplir los dos.'),
            ])
              OpcionAsistente(icono: icono, titulo: titulo, texto: texto, activa: _r.modo == m, alTocar: () => _modo(m)),
          ],
        ),
        _PasoM.clases => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SelectorNumero(
              valor: _r.clases,
              min: 1,
              max: 60,
              etiqueta: _r.clases == 1 ? 'clase' : 'clases',
              alCambiar: (v) => setState(() => _r.clases = v.toInt()),
            ),
            const SizedBox(height: 16),
            impacto,
          ],
        ),
        _PasoM.puntos => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SelectorNumero(valor: _r.puntos, min: 1, max: 500, etiqueta: 'puntos', alCambiar: (v) => setState(() => _r.puntos = v.toInt())),
            const SizedBox(height: 8),
            OpcionAsistente(
              icono: Icons.task_alt_rounded,
              titulo: 'Solo puntos por tareas',
              texto: 'No cuentan los de asistencia ni racha.',
              activa: _r.fuente == 'tareas',
              alTocar: () => setState(() => _r.fuente = 'tareas'),
            ),
            OpcionAsistente(
              icono: Icons.stars_rounded,
              titulo: 'Todos los puntos',
              texto: 'Asistencia, tareas y racha.',
              activa: _r.fuente == 'todos',
              alTocar: () => setState(() => _r.fuente = 'todos'),
            ),
            const SizedBox(height: 8),
            impacto,
          ],
        ),
        _PasoM.periodo => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SelectorPlazo(valor: _r.ventana, unidad: _r.unidad, max: 52, alCambiar: (v, u) => setState(() => (_r.ventana = v, _r.unidad = u))),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _Nota(key: ValueKey(_ejemploPeriodo), texto: _ejemploPeriodo),
            ),
            const SizedBox(height: 10),
            Text(
              'Más tiempo da margen a quien tuvo un mes flojo. Menos tiempo hace que el equipo refleje lo más reciente. '
              'Quien no llega en ese tiempo pasa a ${widget.debajo}, después del margen que fijes en Descenso del equipo.',
              style: TextStyle(fontSize: 13, height: 1.4, color: p.textoSecundario),
            ),
            const SizedBox(height: 14),
            impacto,
          ],
        ),
        _PasoM.resumen => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Nota(texto: '${widget.nombre} pedirá ${_r.texto}.'),
            const SizedBox(height: 12),
            impacto,
          ],
        ),
      },
      textoBoton: _paso == _PasoM.resumen ? 'Guardar' : 'Siguiente',
      alContinuar: _paso == _PasoM.resumen ? () => Navigator.of(context).pop(_r) : () => _ir(1),
    );
  }
}

/// Efecto del cambio sobre el equipo de hoy, con nombres y un aviso amable
/// si la regla queda muy por encima de lo que el equipo está haciendo.
class _Impacto extends StatelessWidget {
  const _Impacto({required this.antes, required this.ahora, required this.miembros, required this.candidatos, required this.nombre, required this.debajo});
  final _Regla antes, ahora;
  final List<_Persona> miembros, candidatos;
  final String nombre, debajo;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final cumplenAntes = miembros.where(antes.cumple).length;
    final cumplen = miembros.where(ahora.cumple).length;
    final dejan = miembros.where((x) => antes.cumple(x) && !ahora.cumple(x)).toList();
    final empiezan = miembros.where((x) => !antes.cumple(x) && ahora.cumple(x)).toList();
    final suben = candidatos.where((x) => !x.usaEquipo && ahora.cumple(x)).toList();
    final subenAntes = candidatos.where((x) => !x.usaEquipo && antes.cumple(x)).length;
    final pct = miembros.isEmpty ? 100 : (cumplen * 100 / miembros.length).round();
    final masExigente = cumplen < cumplenAntes;
    final aviso = masExigente && pct < 60;
    final faciles = !masExigente && miembros.isNotEmpty && pct == 100 && suben.length > candidatos.length * 0.6 && candidatos.length >= 3;

    Widget nombres(List<_Persona> l) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final x in l.take(8))
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: AvatarPersona(nombre: x.nombreMostrar, foto: x.foto, tamano: 22),
              label: Text(x.nombreMostrar),
            ),
          if (l.length > 8) Chip(visualDensity: VisualDensity.compact, label: Text('+${l.length - 8}')),
        ],
      ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Con esto, hoy',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textoSecundario),
            ),
            const SizedBox(height: 6),
            if (miembros.isNotEmpty) ...[
              Text(
                'Lo cumplen $cumplen de ${miembros.length} personas de $nombre ($pct%).',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.texto),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: pct / 100),
                  duration: const Duration(milliseconds: 300),
                  builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: p.fondo, color: p.marca),
                ),
              ),
            ] else
              Text('Hoy no hay personas en $nombre que entren en el cálculo.', style: TextStyle(color: p.texto)),
            if (dejan.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Dejarían de cumplirlo (${dejan.length}):',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
              ),
              nombres(dejan),
            ],
            if (empiezan.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Empezarían a cumplirlo (${empiezan.length}):',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
              ),
              nombres(empiezan),
            ],
            if (candidatos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                suben.isEmpty
                    ? 'Nadie de $debajo lo cumpliría para subir.'
                    : 'De $debajo, ${suben.length} lo ${suben.length == 1 ? 'cumpliría' : 'cumplirían'} para subir${suben.length != subenAntes ? ' (antes $subenAntes)' : ''}:',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
              ),
              if (suben.isNotEmpty) nombres(suben),
            ],
            if (aviso || faciles) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta - 4)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 20, color: p.sobreSuave),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        aviso
                            ? 'Hoy solo $cumplen de ${miembros.length} lo cumplirían. Con la asistencia actual, hacerlo más exigente bajaría a varias personas; quizás convenga esperar a que la asistencia suba o dar más meses de margen.'
                            : 'Casi todo el equipo lo cumple, también en $debajo. Si quieres que $nombre signifique un compromiso mayor, puedes pedir un poco más.',
                        style: TextStyle(fontSize: 13.5, height: 1.35, color: p.sobreSuave),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ajustes de un equipo por su nombre (Mi Liga → tarjetas de equipos):
/// carga los equipos y la gente, y muestra la misma pantalla de Equipos y puntos.
class AjustesEquipoScreen extends StatefulWidget {
  const AjustesEquipoScreen({super.key, required this.sesion, required this.nombre, this.buscar});
  final Sesion sesion;
  final String nombre;

  /// Abre con el buscador del equipo ya filtrado (buscador de la liga).
  final String? buscar;

  @override
  State<AjustesEquipoScreen> createState() => _AjustesEquipoScreenState();
}

class _AjustesEquipoScreenState extends State<AjustesEquipoScreen> {
  List<Map<String, dynamic>>? _tiers;
  List<_Persona> _gente = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.sesion, token = {'adminToken': s.adminToken};
    Future.wait([s.api.get('getTiers', token), s.api.get('adminDatosCategorias', token)])
        .then((r) {
          if (!mounted) return;
          setState(() {
            _tiers = [
              for (final t in (r[0]['tiers'] as List? ?? const []))
                if (t is Map<String, dynamic>) t,
            ]..sort((a, b) => ((a['orden'] as num?) ?? 0).compareTo((b['orden'] as num?) ?? 0));
            _gente = [
              for (final p in (r[1]['personas'] as List? ?? const []))
                if (p is Map<String, dynamic>) _Persona(p),
            ];
          });
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
        });
  }

  @override
  Widget build(BuildContext context) {
    final l = _tiers;
    final i = l?.indexWhere((t) => '${t['nombre']}' == widget.nombre) ?? -1;
    if (l == null || i < 0) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.nombre)),
        body: Center(
          child: _error != null ? Text(_error!) : (l == null ? const Esqueleto(forma: FormaEsqueleto.ajustes) : const Text('Ese equipo ya no existe.')),
        ),
      );
    }
    return _EquipoScreen(sesion: widget.sesion, tiers: l, indice: i, gente: _gente, buscar: widget.buscar);
  }
}

/// Ver un equipo desde Comunidad (Victor, 2026-11-22): los Pivots lo editan;
/// el resto ve sus reglas sin poder cambiarlas.
class VerEquipoScreen extends StatefulWidget {
  const VerEquipoScreen({super.key, required this.sesion, required this.nombre});
  final Sesion sesion;
  final String nombre;

  @override
  State<VerEquipoScreen> createState() => _VerEquipoScreenState();
}

class _VerEquipoScreenState extends State<VerEquipoScreen> {
  List<Map<String, dynamic>>? _tiers;
  String? _error;

  bool get _pivot => widget.sesion.esAdmin && widget.sesion.adminToken != null;

  @override
  void initState() {
    super.initState();
    if (_pivot) return;
    widget.sesion.api
        .get('getEquipoPublico')
        .then((r) {
          if (!mounted) return;
          setState(() {
            _tiers = [
              for (final t in (r['tiers'] as List? ?? const []))
                if (t is Map<String, dynamic>) t,
            ]..sort((a, b) => ((a['orden'] as num?) ?? 0).compareTo((b['orden'] as num?) ?? 0));
          });
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_pivot) return AjustesEquipoScreen(sesion: widget.sesion, nombre: widget.nombre);
    final l = _tiers;
    final i = l?.indexWhere((t) => '${t['nombre']}' == widget.nombre) ?? -1;
    if (l == null || i < 0) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.nombre)),
        body: Center(
          child: _error != null ? Text(_error!) : (l == null ? const Esqueleto(forma: FormaEsqueleto.ajustes) : const Text('Ese equipo ya no existe.')),
        ),
      );
    }
    return _EquipoScreen(sesion: widget.sesion, tiers: l, indice: i, gente: const [], soloLectura: true);
  }
}

/// Crear un equipo desde Mi Liga: el asistente directo; al terminar o volver,
/// regresa a Mi Liga (Victor, 2026-11-15).
class NuevoEquipoScreen extends StatefulWidget {
  const NuevoEquipoScreen({super.key, required this.sesion});
  final Sesion sesion;

  @override
  State<NuevoEquipoScreen> createState() => _NuevoEquipoScreenState();
}

class _NuevoEquipoScreenState extends State<NuevoEquipoScreen> {
  Map<String, dynamic>? _inicial;
  List<_Persona> _gente = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.sesion, token = {'adminToken': s.adminToken};
    Future.wait([s.api.get('getTiers', token), s.api.get('adminDatosCategorias', token)])
        .then((r) {
          if (!mounted) return;
          final l = [
            for (final t in (r[0]['tiers'] as List? ?? const []))
              if (t is Map<String, dynamic>) t,
          ];
          setState(() {
            _inicial = l.firstWhere((t) => t['es_default'] == true, orElse: () => l.last);
            _gente = [
              for (final p in (r[1]['personas'] as List? ?? const []))
                if (p is Map<String, dynamic>) _Persona(p),
            ];
          });
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
        });
  }

  @override
  Widget build(BuildContext context) {
    final i = _inicial;
    if (i == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nuevo equipo')),
        body: _error != null ? Center(child: Text(_error!)) : const Esqueleto(forma: FormaEsqueleto.ajustes),
      );
    }
    return _NuevoEquipoAsistente(sesion: widget.sesion, inicial: i, gente: _gente);
  }
}

/// Nombres de lo que un equipo pide propio (`getTiers.propioNombres`).
List<String> _propioNombres(Map<String, dynamic> t) => [for (final x in (t['propioNombres'] as List? ?? const [])) '$x'];

String _unirY(List<String> l) {
  final x = [for (final y in l) y.toLowerCase()];
  return x.length > 1 ? '${x.sublist(0, x.length - 1).join(', ')} y ${x.last}' : x.join();
}

/// Equipamiento propio que pide un equipo (Reglas → Equipamiento, Victor
/// 2026-11-15). Desde 2026-11-17 se elige de las listas de la liga que se
/// usan para entrenar (Inventario). Quien se inscribe con su enlace y no lo
/// cumple entra al equipo inicial. Devuelve true si se guardó.
Future<bool> editarEquipamientoPropio(BuildContext context, Sesion s, Map<String, dynamic> t) async {
  final req = (t['requisitos'] as Map?) ?? const {};
  List<Map<String, dynamic>> listas = const [];
  try {
    final r = await s.api.get('getTiers', {'adminToken': s.adminToken});
    listas = [for (final l in (r['listasEntrenar'] as List? ?? const [])) Map<String, dynamic>.from(l as Map)];
  } catch (_) {}
  if (!context.mounted) return false;
  final elegidas = <String>{for (final x in (req['propio'] as List? ?? const [])) '$x'};
  final ok = await abrirSubseccion(
    context,
    titulo: 'Equipamiento propio',
    contenido: (set) => [
      Text(
        'Qué tiene que tener propio quien está en ${t['nombre']}. Quien usa eso de la liga pasa al equipo de abajo, y quien se inscribe con su enlace sin cumplirlo entra al equipo inicial y se le explica por qué.',
        style: TextStyle(color: context.pivot.textoSecundario),
      ),
      const SizedBox(height: 8),
      if (listas.isEmpty)
        Text('Primero marca en el Inventario qué listas de equipamiento se prestan para entrenar.', style: TextStyle(color: context.pivot.textoSecundario)),
      for (final l in listas)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${l['nombre']} propio'),
          value: elegidas.contains('${l['id']}'),
          onChanged: (v) => set(() => v ? elegidas.add('${l['id']}') : elegidas.remove('${l['id']}')),
        ),
    ],
  );
  if (ok != true || !context.mounted) return false;
  final m = ScaffoldMessenger.of(context);
  try {
    final cambios = {
      'requisitos': {...req, 'propio': elegidas.toList()},
    };
    final base = _Regla.de(t).params({...t, ...cambios});
    await _guardarTier(s, {...base, ...cambios.map((k, v) => MapEntry(k, jsonEncode(v)))});
    m.showSnackBar(const SnackBar(content: Text('Guardado')));
    return true;
  } catch (e) {
    m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    return false;
  }
}

/// Curso que hay que tener aprobado para estar en un equipo (Victor,
/// 2026-11-26). El cálculo de equipos ya lo revisaba; aquí se elige. Quien no
/// lo tiene aprobado baja o no sube, y quien se inscribe con el enlace del
/// equipo entra al equipo inicial con el aviso de qué curso le falta.
Future<bool> editarCursoRequerido(BuildContext context, Sesion s, Map<String, dynamic> t) async {
  final req = (t['requisitos'] as Map?) ?? const {};
  List<Map<String, dynamic>> cursos = const [];
  try {
    final r = await s.api.post('adminCursos', {'adminToken': s.adminToken, 'accion': 'listar'});
    cursos = [for (final c in (r['cursos'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
  } catch (_) {}
  if (!context.mounted) return false;
  String elegido = '${req['cursoId'] ?? ''}';
  final ok = await abrirSubseccion(
    context,
    titulo: 'Curso aprobado',
    contenido: (set) => [
      Text(
        'Para estar en ${t['nombre']} hay que tener aprobado este curso. Quien no lo tiene no sube a este equipo.',
        style: TextStyle(color: context.pivot.textoSecundario),
      ),
      const SizedBox(height: 8),
      RadioGroup<String>(
        groupValue: elegido,
        onChanged: (v) => set(() => elegido = v ?? ''),
        child: Column(
          children: [
            const RadioListTile<String>(contentPadding: EdgeInsets.zero, value: '', title: Text('No pide un curso')),
            for (final c in cursos) RadioListTile<String>(contentPadding: EdgeInsets.zero, value: '${c['id']}', title: Text('${c['nombre'] ?? 'Curso'}')),
          ],
        ),
      ),
      if (cursos.isEmpty) Text('Todavía no hay cursos creados.', style: TextStyle(color: context.pivot.textoSecundario)),
    ],
  );
  if (ok != true || !context.mounted) return false;
  final m = ScaffoldMessenger.of(context);
  try {
    final nombre = cursos.where((c) => '${c['id']}' == elegido).map((c) => '${c['nombre'] ?? ''}').firstOrNull ?? '';
    final nuevo = {...req}
      ..remove('cursoId')
      ..remove('cursoNombre');
    if (elegido.isNotEmpty) nuevo.addAll({'cursoId': elegido, 'cursoNombre': nombre});
    final cambios = {'requisitos': nuevo};
    final base = _Regla.de(t).params({...t, ...cambios});
    await _guardarTier(s, {...base, ...cambios.map((k, v) => MapEntry(k, jsonEncode(v)))});
    m.showSnackBar(const SnackBar(content: Text('Guardado')));
    return true;
  } catch (e) {
    m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    return false;
  }
}

/// Si quienes están en un equipo reciben fondos de viaje (Viajes, Victor 2026-11-15).
Future<void> cambiarFondosViaje(Sesion s, Map<String, dynamic> t, bool recibe) async {
  final cambios = {'califica_fondos_viaje': recibe ? 'true' : ''};
  final base = _Regla.de(t).params({...t, ...cambios});
  await _guardarTier(s, {...base, ...cambios});
}

// ─── Puntos por asistencia y qué cuenta como clase, por equipo ────────────
// (Victor, 2026-11-16). Todos los equipos empiezan con los mismos valores;
// un cambio empieza desde mañana o después y nunca toca puntos ya ganados.

String textoPuntosVersion(Map v) {
  String n(Object? x) => x is num && x == x.roundToDouble() ? x.toInt().toString() : '${x ?? 0}';
  return v['tardeCuenta'] == false ? '${n(v['aTiempo'])} a tiempo · tarde no suma' : '${n(v['aTiempo'])} a tiempo · ${n(v['tarde'])} tarde';
}

/// Regla de "qué cuenta como clase" de un equipo (o la general).
Map<String, dynamic> reglaClaseEquipo(Map<String, dynamic> reglas, String equipo) {
  final x = (reglas['queCuentaEquipos'] as Map?)?[equipo];
  if (x is Map) return Map<String, dynamic>.from(x);
  return {'tiposCuentan': reglas['tiposCuentan'], 'tardeCuentaClase': reglas['tardeCuentaClase']};
}

String textoQueCuenta(Map<String, dynamic> r) {
  final t = r['tiposCuentan'];
  final base = t is List && t.isNotEmpty ? t.map((x) => x == 'Externa' ? 'con otros equipos' : '$x'.toLowerCase()).join(', ') : 'todo suma';
  return '${base[0].toUpperCase()}${base.substring(1)}${r['tardeCuentaClase'] == false ? ' · llegar tarde no suma' : ''}';
}

/// Fechas reales del próximo corte para un modo/día/aviso dados.
(DateTime, DateTime) fechasCorteEquipos(int dia, int aviso) {
  final h = Fechas.hoy();
  final c = h.day < dia ? DateTime(h.year, h.month, dia) : DateTime(h.year, h.month + 1, dia);
  return (c, c.subtract(Duration(days: aviso)));
}

String _textoCorte(List<Map<String, dynamic>>? tiers, String modo, int dia, int aviso, [bool autoAprobar = true]) {
  final (c, llega) = fechasCorteEquipos(dia, aviso);
  final ej = _ejemploCorte(tiers, modo, c);
  if (modo == 'auto') {
    return 'Los cambios se aplicarán apenas alguien cumpla o deje de cumplir los requisitos, de forma automática.${ej.isEmpty ? '' : '\n\n$ej'}';
  }
  return autoAprobar
      ? 'La lista llegará a Notificaciones el ${Fechas.corta(llega)}. Tendrás $aviso ${aviso == 1 ? 'día' : 'días'}, hasta el ${Fechas.corta(c)}, para revisarla; lo que no revises se aplicará solo ese día.${ej.isEmpty ? '' : '\n\n$ej'}'
      : 'La lista llegará a Notificaciones el ${Fechas.corta(llega)}. Ningún cambio se aplica hasta que un Pivot lo apruebe.${ej.isEmpty ? '' : '\n\n$ej'}';
}

/// Ejemplo con los requisitos reales de los dos primeros equipos (Victor, 2026-11-14).
String _ejemploCorte(List<Map<String, dynamic>>? tiers, String modo, DateTime corte) {
  final l = tiers;
  if (l == null || l.length < 2) return '';
  final arriba = '${l[0]['nombre']}', abajo = '${l[1]['nombre']}';
  final r = _Regla.de(l[0]);
  if (r.clases == 0 && r.puntos == 0) return '';
  final cuando = modo == 'auto' ? 'pasa a $arriba ese mismo día' : 'aparece en la lista y, si no la revisas, pasa a $arriba el ${Fechas.corta(corte)}';
  return 'Ejemplo: si alguien de $abajo logra ${r.texto} durante ${r.subir} ${r.subir == 1 ? 'mes' : 'meses seguidos'}, $cuando.';
}

/// Editor de "Cuándo se aplican los cambios" (de toda la liga). Se abre desde
/// Equipos y desde los ajustes de cada equipo (Victor, 2026-11-16: antes este
/// llevaba a la pantalla vieja). Devuelve el corte guardado, o null.
Future<Map<String, dynamic>?> editarCorteEquipos(BuildContext context, Sesion s, List<Map<String, dynamic>>? tiers, {Map<String, dynamic>? corte}) async {
  var c0 = corte;
  if (c0 == null) {
    try {
      c0 = ((await _reglasDeLiga(s))['corte'] as Map?)?.cast<String, dynamic>() ?? const {};
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo cargar. Revisa tu conexión.')));
      return null;
    }
    if (!context.mounted) return null;
  }
  final Map<String, dynamic> corteActual = c0;
  var modo = '${corteActual['modo'] ?? 'revisar'}';
  var dia = (corteActual['dia'] as num?)?.toInt() ?? 1;
  var aviso = (corteActual['avisoDias'] as num?)?.toInt() ?? 7;
  var auto = corteActual['autoAprobar'] != false;
  final ok = await abrirSubseccion(
    context,
    titulo: 'Cuándo se aplican los cambios',
    contenido: (set) => [
      for (final (k, t, d, i) in const [
        (
          'revisar',
          'Revisar antes',
          'Los cambios llegan a Notificaciones antes del día de corte para aprobarlos o dejarlos como están.',
          Icons.fact_check_outlined,
        ),
        ('auto', 'Automático', 'Se aplican solos, sin revisión.', Icons.bolt_rounded),
      ])
        OpcionAsistente(icono: i, titulo: t, texto: d, activa: modo == k, alTocar: () => set(() => modo = k)),
      if (modo == 'revisar') ...[
        const SizedBox(height: 8),
        Text(
          'Día de corte (de cada mes)',
          style: TextStyle(fontWeight: FontWeight.w700, color: context.pivot.texto),
        ),
        const SizedBox(height: 6),
        SelectorNumero(valor: dia, min: 1, max: 28, etiqueta: 'día', alCambiar: (v) => set(() => dia = v.toInt())),
        const SizedBox(height: 12),
        Text(
          'Días para revisar la lista',
          style: TextStyle(fontWeight: FontWeight.w700, color: context.pivot.texto),
        ),
        const SizedBox(height: 6),
        SelectorNumero(
          valor: aviso,
          min: 1,
          max: 20,
          etiqueta: aviso == 1 ? 'día antes del corte' : 'días antes del corte',
          alCambiar: (v) => set(() => aviso = v.toInt()),
        ),
        // Aprobar solo si nadie revisa (Victor, 2026-11-16).
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Si nadie la revisa, se aplica sola'),
          subtitle: Text(auto ? 'El día de corte se aplica lo que no se revisó.' : 'Manual: cada cambio espera a que un Pivot lo apruebe.'),
          value: auto,
          onChanged: (v) => set(() => auto = v),
        ),
      ],
      const SizedBox(height: 12),
      _Nota(texto: _textoCorte(tiers, modo, dia, aviso, auto)),
    ],
  );
  if (ok != true || !context.mounted) return null;
  final nuevo = <String, dynamic>{'modo': modo, 'dia': dia, 'avisoDias': aviso, 'autoAprobar': auto};
  return await _guardarReglasLiga(context, s, {'corte': jsonEncode(nuevo)}, 'Guardado') ? nuevo : null;
}

Future<Map<String, dynamic>> _reglasDeLiga(Sesion s) async {
  final r = await s.api.get('getReglasLiga', {'adminToken': s.adminToken});
  if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo cargar.'}');
  return r;
}

Future<bool> _guardarReglasLiga(BuildContext context, Sesion s, Map<String, Object?> cambios, String ok) async {
  final m = ScaffoldMessenger.of(context);
  try {
    final r = await s.api.post('adminReglasLiga', {'adminToken': s.adminToken, ...cambios});
    if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo guardar.'}');
    m.showSnackBar(SnackBar(content: Text(ok)));
    return true;
  } catch (e) {
    m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    return false;
  }
}

Future<bool> editarPuntosEquipo(BuildContext context, Sesion s, String equipo) async {
  final Map<String, dynamic> datos;
  try {
    datos = await _reglasDeLiga(s);
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo cargar. Revisa tu conexión.')));
    return false;
  }
  if (!context.mounted) return false;
  final pe = ((datos['puntosEquipos'] as Map?)?[equipo] as Map?) ?? (datos['puntos'] as Map?) ?? const {};
  final actual = (pe['actual'] as Map?) ?? const {'aTiempo': 1, 'tarde': 0.5, 'tardeCuenta': true};
  final proxima = pe['proxima'] as Map?;
  final base = proxima ?? actual;
  num aTiempo = (base['aTiempo'] as num?) ?? 1;
  num tarde = (base['tarde'] as num?) ?? 0.5;
  var tardeCuenta = base['tardeCuenta'] != false;
  final manana = Fechas.hoy().add(const Duration(days: 1));
  final h = Fechas.hoy();
  var desde = DateTime.tryParse('${proxima?['desde'] ?? ''}') ?? DateTime(h.year, h.month + 1, 1);
  if (desde.isBefore(manana)) desde = manana;
  final ok = await abrirSubseccion(
    context,
    titulo: 'Puntos por asistencia',
    contenido: (set) => [
      Text('Hoy: ${textoPuntosVersion(actual)}.', style: TextStyle(color: context.pivot.textoSecundario)),
      const SizedBox(height: 12),
      Text(
        'Por clase a tiempo',
        style: TextStyle(fontWeight: FontWeight.w700, color: context.pivot.texto),
      ),
      SelectorNumero(valor: aTiempo, min: 0, max: 10, paso: 0.5, decimales: true, etiqueta: 'puntos', alCambiar: (v) => set(() => aTiempo = v)),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Llegar tarde suma puntos'),
        value: tardeCuenta,
        onChanged: (v) => set(() => tardeCuenta = v),
      ),
      if (tardeCuenta) SelectorNumero(valor: tarde, min: 0, max: 10, paso: 0.5, decimales: true, etiqueta: 'puntos', alCambiar: (v) => set(() => tarde = v)),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_rounded),
        title: Text('Empieza el ${Fechas.corta(desde)}'),
        subtitle: const Text('Desde mañana o después.'),
        trailing: const Icon(Icons.edit_calendar_outlined),
        onTap: () async {
          final f = await showDatePicker(context: context, firstDate: manana, lastDate: manana.add(const Duration(days: 730)), initialDate: desde);
          if (f != null) set(() => desde = f);
        },
      ),
      _Nota(texto: 'Solo para $equipo. Los puntos ya ganados nunca cambian.'),
    ],
  );
  if (ok != true || !context.mounted) return false;
  return _guardarReglasLiga(context, s, {
    'puntos': jsonEncode({'desde': Fechas.iso(desde), 'aTiempo': aTiempo, 'tarde': tarde, 'tardeCuenta': tardeCuenta, 'equipo': equipo}),
  }, 'Guardado. Empieza el ${Fechas.corta(desde)}.');
}

Future<bool> editarQueCuentaEquipo(BuildContext context, Sesion s, String equipo) async {
  final Map<String, dynamic> datos;
  try {
    datos = await _reglasDeLiga(s);
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo cargar. Revisa tu conexión.')));
    return false;
  }
  if (!context.mounted) return false;
  final r = reglaClaseEquipo((datos['reglas'] as Map<String, dynamic>?) ?? const {}, equipo);
  final tiposEvento = [
    ...ConfigLiga.de(s).tiposEvento(const ['Entrenamiento', 'Partido', 'Evento', 'Otro']),
    'Externa',
  ];
  final t = r['tiposCuentan'];
  var todo = t is! List || t.isEmpty;
  final sel = <String>{if (t is List) ...t.map((x) => '$x')};
  var tarde = r['tardeCuentaClase'] != false;
  final ok = await abrirSubseccion(
    context,
    titulo: 'Qué cuenta como clase',
    contenido: (set) => [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Todo suma'),
        subtitle: const Text('Cualquier evento con asistencia tomada.'),
        value: todo,
        onChanged: (v) => set(() => todo = v),
      ),
      if (!todo)
        for (final x in tiposEvento)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(x == 'Externa' ? 'Entrenar con otros equipos' : x),
            value: sel.contains(x),
            onChanged: (v) => set(() => v == true ? sel.add(x) : sel.remove(x)),
          ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Las llegadas tarde suman para el equipo'),
        subtitle: Text(
          tarde
              ? 'Si alguien llega tarde, ese evento cuenta igual para los requisitos mínimos.'
              : 'Si alguien llega tarde, ese evento no cuenta para los requisitos mínimos. Los puntos por llegar tarde no cambian.',
        ),
        value: tarde,
        onChanged: (v) => set(() => tarde = v),
      ),
      _Nota(texto: 'Solo para $equipo. Rige para el próximo cálculo de equipos.'),
    ],
  );
  if (ok != true || !context.mounted) return false;
  return _guardarReglasLiga(context, s, {
    'reglas': jsonEncode({
      'queCuentaEquipo': {'equipo': equipo, 'tiposCuentan': todo || sel.isEmpty ? null : sel.toList(), 'tardeCuentaClase': tarde},
    }),
  }, 'Guardado');
}
