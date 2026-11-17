import 'dart:convert';

import '../core/selector_hora.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/pronombres.dart';
import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/esqueleto.dart';
import '../core/fechas.dart';
import '../core/moneda.dart';
import '../core/selector_plazo.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../pivots/formas_pago_screen.dart' show LogoMedio;
import '../reservas/reserva_screen.dart' show ReservaExitoScreen;
import '../reservas/reservas_repo.dart';
import '../sesion/sesion.dart';
import '../core/asistente.dart';
import '../coach/coach_screen.dart' show EscalaDiez;

import 'importar_clases.dart';

part 'asistente_curso.dart';

/// Cursos y clínicas (Victor, 2026-11-16/17): clases con temas, precio
/// propio, inscripción con cupo y una evaluación por temas opcional.
class Curso {
  Curso(this.m);
  final Map<String, dynamic> m;
  String get id => '${m['id']}';

  /// 'curso' (varias clases) o 'clinica' (una sola sesión).
  String get tipo => '${m['tipo'] ?? 'curso'}';
  bool get esClinica => tipo == 'clinica';
  String get nombre => '${m['nombre'] ?? ''}';
  String get descripcion => '${m['descripcion'] ?? ''}';
  double get precio => (m['precio'] as num?)?.toDouble() ?? 0;
  int? get cupo => (m['cupo'] as num?)?.toInt();
  int? get libres => (m['libres'] as num?)?.toInt();
  int get inscritos => (m['inscritos'] as num?)?.toInt() ?? 0;
  String get estado => '${m['estado'] ?? 'abierto'}';
  String? get equipoDestino => m['equipoDestino'] as String?;

  /// Al aprobar, ¿cambia de equipo? (Victor, 2026-11-17: por defecto no).
  bool get cambiaEquipo => m['cambiaEquipo'] == true;

  /// Temas de la evaluación con su mínimo (1 a 10).
  List<Map<String, dynamic>> get temasEvaluacion => [
    for (final t in ((m['evaluacion'] as Map?)?['temas'] as List? ?? const []))
      if (t is Map) {'nombre': '${t['nombre']}', 'minimo': (t['minimo'] as num?)?.toInt() ?? 5},
  ];
  List<Map<String, dynamic>> get fechas => [for (final f in (m['fechas'] as List? ?? const [])) Map<String, dynamic>.from(f as Map)];
  Map? get mia => m['miInscripcion'] as Map?;
  List<Map<String, dynamic>> get personas => [for (final x in (m['personas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

  static DateTime? fecha(Map f) => DateTime.tryParse('${f['fecha']}');

  /// Tipo de cada fecha; en cursos viejos, la última de varias es la evaluación.
  static String tipoFecha(List<Map<String, dynamic>> l, int i) =>
      '${l[i]['tipo'] ?? (i == l.length - 1 && l.length > 1 && l.every((x) => x['tipo'] == null) ? 'evaluacion' : 'clase')}';

  bool get tieneEvaluacion => [for (var i = 0; i < fechas.length; i++) tipoFecha(fechas, i)].contains('evaluacion');

  /// Enlace para invitar a inscribirse (Victor, 2026-11-17).
  String get enlace => '${ApiConfig.webAppUrl}/?curso=$id';

  /// "3 fechas, del 5 de diciembre al 20 de diciembre".
  String get resumenFechas {
    final l = [for (final f in fechas) ?fecha(f)];
    if (l.isEmpty) return 'Sin fechas';
    if (l.length == 1) return Fechas.corta(l.first);
    return '${l.length} fechas, del ${Fechas.corta(l.first)} al ${Fechas.corta(l.last)}';
  }
}

/// Qué es un curso, para guiar a quien lo arma (Victor, 2026-11-16).
class _QueEsUnCurso extends StatelessWidget {
  const _QueEsUnCurso();
  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    Widget paso(IconData i, String t) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 18, color: p.sobreSuave),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t, style: TextStyle(height: 1.35, color: p.sobreSuave)),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Qué es un curso?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.sobreSuave),
          ),
          const SizedBox(height: 4),
          Text(
            'Un grupo de clases con inscripción, para quienes empiezan o para practicar algo más avanzado. Cada clase tiene sus temas y, al final, puede haber una evaluación.',
            style: TextStyle(height: 1.35, color: p.sobreSuave),
          ),
          paso(Icons.event_outlined, 'Eliges las clases: cada una aparece en el calendario con su día, hora y lugar.'),
          paso(
            Icons.payments_outlined,
            'Le pones precio y, si quieres, un cupo. Las personas se inscriben desde el "+" del calendario y pagan con los medios de la liga.',
          ),
          paso(Icons.emoji_events_outlined, 'Si tiene evaluación, ese día evalúas a cada persona en los temas de las clases.'),
        ],
      ),
    );
  }
}

String _precio(double v) => v == 0 ? 'Gratis' : ReservasRepo.dinero(v);

/// Lista de fechas: la última, marcada como try out.
class _Fechas extends StatelessWidget {
  const _Fechas({required this.curso});
  final Curso curso;
  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = curso.fechas;
    return Column(
      children: [
        for (var i = 0; i < l.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  switch (Curso.tipoFecha(l, i)) {
                    'evaluacion' => Icons.emoji_events_outlined,
                    'clinica' => Icons.star_outline_rounded,
                    _ => Icons.event_outlined,
                  },
                  size: 18,
                  color: Curso.tipoFecha(l, i) == 'clase' ? p.textoSecundario : p.marcaTexto,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    [
                      if (Curso.fecha(l[i]) case final d?) '${Fechas.dia(d)} ${Fechas.corta(d)}',
                      if ('${l[i]['hora'] ?? ''}'.isNotEmpty) '${l[i]['hora']}${'${l[i]['termina'] ?? ''}'.isNotEmpty ? ' a ${l[i]['termina']}' : ''}',
                      if ('${l[i]['lugar'] ?? ''}'.isNotEmpty) '${l[i]['lugar']}',
                    ].join(' · '),
                    style: TextStyle(fontSize: 14, color: p.texto),
                  ),
                ),
                if ((l[i]['temas'] as List? ?? const []).isNotEmpty && Curso.tipoFecha(l, i) != 'evaluacion')
                  Flexible(
                    child: Text(
                      (l[i]['temas'] as List).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.textoSecundario),
                    ),
                  ),
                if (Curso.tipoFecha(l, i) != 'clase' && !curso.esClinica)
                  Text(
                    Curso.tipoFecha(l, i) == 'evaluacion' ? 'Evaluación final' : '${l[i]['titulo'] ?? 'Clínica'}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.marcaTexto),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

AppBar _barra(String titulo) => AppBar(
  backgroundColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  flexibleSpace: const Vidrio(child: SizedBox.expand()),
  title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
);

// ─── Persona: cursos abiertos ──────────────────────────────────────────────

/// ¿Hay cursos para mostrar en el "+"? Sin señal, no.
Future<bool> hayCursos(Sesion s) async {
  try {
    final r = await s.api.get('getCursos', const {});
    return (r['cursos'] as List? ?? const []).isNotEmpty;
  } catch (_) {
    return false;
  }
}

class CursosAbiertosScreen extends StatefulWidget {
  const CursosAbiertosScreen({super.key, required this.sesion, this.destacado});
  final Sesion sesion;

  /// Curso del enlace de invitación: va primero.
  final String? destacado;
  @override
  State<CursosAbiertosScreen> createState() => _CursosAbiertosScreenState();
}

class _CursosAbiertosScreenState extends State<CursosAbiertosScreen> {
  List<Curso>? _cursos;
  String? _error;
  bool _guardando = false;
  Sesion get s => widget.sesion;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await s.api.get('getCursos', const {});
      final l = [for (final c in (r['cursos'] as List? ?? const [])) Curso(Map<String, dynamic>.from(c as Map))];
      l.sort((a, b) => (a.id == widget.destacado ? 0 : 1).compareTo(b.id == widget.destacado ? 0 : 1));
      if (mounted) setState(() => _cursos = l);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar. Revisa tu conexión.');
    }
  }

  Future<void> _inscribirme(Curso c) async {
    MedioPago? medio;
    if (c.precio > 0) {
      final medios = ConfigLiga.de(s).mediosActivos;
      medio = await showModalBottomSheet<MedioPago>(
        context: context,
        showDragHandle: true,
        builder: (h) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('¿Cómo pagarás ${_precio(c.precio)}?', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              for (final m in medios)
                ListTile(
                  leading: LogoMedio(medio: m, tamano: 36),
                  title: Text(m.nombre),
                  subtitle: Text(m.enlace.isNotEmpty ? 'Se abre para pagar' : m.nombreTipo),
                  onTap: () => Navigator.of(h).pop(m),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (medio == null) return;
    }
    setState(() => _guardando = true);
    try {
      final r = await s.api.post('inscribirseCurso', {'cursoId': c.id, 'medio': ?medio?.id, 'medioNombre': ?medio?.nombre});
      if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo guardar.'}');
      if (!mounted) return;
      if (c.precio == 0 || r['id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡Listo! Te inscribiste en ${c.nombre}.')));
        setState(() => _guardando = false);
        _cargar();
        return;
      }
      if (medio != null && medio.enlace.isNotEmpty) await launchUrl(Uri.parse(medio.enlace), mode: LaunchMode.inAppBrowserView);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (_, _, _) => ReservaExitoScreen(
            resultado: ResultadoReserva(guardados: ['Curso ${c.nombre}'], fallidos: const [], mensajeWhatsapp: '', ids: ['${r['id']}']),
            total: Total(cantidad: 1, aFavor: 0, cupon: 0, cobradas: 1, monto: c.precio, precio: c.precio),
            esClase: false,
            repo: ReservasRepo(s),
          ),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _cursos;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _barra('Cursos'),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: l == null
            ? (_error == null
                  ? const Esqueleto(key: ValueKey('c'), forma: FormaEsqueleto.tarjetas, filas: 2)
                  : Center(key: const ValueKey('e'), child: Text(_error!)))
            : ListView(
                key: const ValueKey('l'),
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (l.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text(
                        'No hay cursos abiertos por ahora.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.textoSecundario),
                      ),
                    ),
                  for (final c in l)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.nombre,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.texto),
                          ),
                          if (c.descripcion.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(c.descripcion, style: TextStyle(height: 1.4, color: p.textoSecundario)),
                          ],
                          const SizedBox(height: 10),
                          _Fechas(curso: c),
                          const SizedBox(height: 10),
                          Text(
                            [_precio(c.precio), if (c.libres != null) c.libres == 1 ? 'queda 1 lugar' : 'quedan ${c.libres} lugares'].join(' · '),
                            style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: switch (c.mia?['estado']) {
                              'confirmada' => FilledButton.tonal(
                                onPressed: null,
                                child: Text(conPronombres(_textoResultado(c.mia?['resultado']), s.datos['pronombres'])),
                              ),
                              'pendiente' => const FilledButton.tonal(onPressed: null, child: Text('Inscripción por confirmar')),
                              _ => FilledButton(
                                onPressed: _guardando || c.libres == 0 ? null : () => _inscribirme(c),
                                child: Text(c.libres == 0 ? 'Sin cupo' : 'Inscribirme'),
                              ),
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  static String _textoResultado(Object? r) => switch (r) {
    'aprobado' => '¡Aprobaste la evaluación final!',
    'no_aprobado' => 'Curso terminado',
    _ => 'Ya estás inscritx',
  };
}

// ─── Pivots: crear y seguir cursos ─────────────────────────────────────────

class CursosScreen extends StatefulWidget {
  const CursosScreen({super.key, required this.sesion});
  final Sesion sesion;
  @override
  State<CursosScreen> createState() => _CursosScreenState();
}

class _CursosScreenState extends State<CursosScreen> {
  List<Curso>? _cursos;
  List<String> _equipos = const [];
  List<String> _lugares = const [];
  List<Map<String, dynamic>> _habilidades = const [];
  List<Map<String, dynamic>> _plantillas = const [];
  String? _error;
  Sesion get s => widget.sesion;

  @override
  void initState() {
    super.initState();
    _llamar({'accion': 'listar'});
    s.api.get('getTiers', {'adminToken': s.adminToken}).then((r) {
      if (mounted) setState(() => _equipos = [for (final t in (r['tiers'] as List? ?? const [])) '${(t as Map)['nombre']}']);
    }, onError: (_) {});
    s.api.restGet('venues?select=lugar&order=lugar.asc').then((f) {
      if (mounted) setState(() => _lugares = {for (final x in f) '${(x as Map)['lugar'] ?? ''}'}.where((x) => x.isNotEmpty).toList());
    }, onError: (_) {});
  }

  Future<bool> _llamar(Map<String, Object?> q) async {
    try {
      final r = await s.api.post('adminCursos', {'adminToken': s.adminToken, ...q});
      if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo guardar.'}');
      if (mounted) {
        setState(() {
          _cursos = [for (final c in (r['cursos'] as List? ?? const [])) Curso(Map<String, dynamic>.from(c as Map))];
          _habilidades = [for (final h in (r['habilidades'] as List? ?? const [])) Map<String, dynamic>.from(h as Map)];
          _plantillas = [for (final x in (r['plantillas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        });
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      if (_cursos == null) {
        setState(() => _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
      }
      return false;
    }
  }

  Future<void> _editar([Curso? c]) async {
    final ok = await Navigator.of(context).push<Map<String, Object?>>(
      MaterialPageRoute(
        builder: (_) => _AsistenteCurso(curso: c, equipos: _equipos, lugares: _lugares, habilidades: _habilidades, plantillas: _plantillas),
      ),
    );
    if (ok == null) return;
    if (await _llamar({'accion': 'guardar', 'curso': ok}) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Curso guardado. Sus fechas ya están en el calendario.')));
    }
  }

  void _abrir(Curso c) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _DetalleCurso(id: c.id, cursos: () => _cursos ?? const [], equipos: _equipos, llamar: _llamar, editar: _editar),
    ),
  );

  static String _estado(String e) => switch (e) {
    'cerrado' => 'Inscripciones cerradas',
    'terminado' => 'Terminado',
    _ => 'Inscripciones abiertas',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _cursos;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _barra('Cursos'),
      floatingActionButton: l == null
          ? null
          : FloatingActionButton.extended(onPressed: _editar, icon: const Icon(Icons.add_rounded), label: const Text('Nuevo curso')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: l == null
            ? (_error == null ? const Esqueleto(key: ValueKey('c')) : Center(key: const ValueKey('e'), child: Text(_error!)))
            : ListView(
                key: const ValueKey('l'),
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
                children: [
                  const _QueEsUnCurso(),
                  const SizedBox(height: 14),
                  if (l.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Todavía no hay cursos. Toca "Nuevo curso" para armar el primero.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.textoSecundario),
                      ),
                    ),
                  for (final c in l)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: p.tarjeta,
                        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: Icon(Icons.school_outlined, color: c.estado == 'terminado' ? p.textoSecundario : p.marcaTexto),
                          title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${_estado(c.estado)} · ${c.inscritos}${c.cupo != null ? ' de ${c.cupo}' : ''} ${c.inscritos == 1 ? 'inscritx' : 'inscritxs'}\n${c.resumenFechas}',
                          ),
                          isThreeLine: true,
                          onTap: () => _abrir(c),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _DetalleCurso extends StatefulWidget {
  const _DetalleCurso({required this.id, required this.cursos, required this.equipos, required this.llamar, required this.editar});
  final String id;
  final List<Curso> Function() cursos;
  final List<String> equipos;
  final Future<bool> Function(Map<String, Object?>) llamar;
  final Future<void> Function([Curso?]) editar;
  @override
  State<_DetalleCurso> createState() => _DetalleCursoState();
}

class _DetalleCursoState extends State<_DetalleCurso> {
  Curso? get c => widget.cursos().where((x) => x.id == widget.id).firstOrNull;

  Future<void> _estado(String e) async {
    await widget.llamar({'accion': 'estado', 'id': widget.id, 'estado': e});
    if (mounted) setState(() {});
  }

  /// Evaluación por temas, del 1 al 10 (Victor, 2026-11-17). Aprueba quien
  /// llega al mínimo en cada tema; el resultado queda en su ficha deportiva.
  Future<void> _evaluar(Curso curso, Map<String, dynamic> x) async {
    final temas = curso.temasEvaluacion;
    final notas = <String, int?>{for (final t in temas) '${t['nombre']}': ((x['notas'] as Map?)?['${t['nombre']}'] as num?)?.toInt()};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (h) => StatefulBuilder(
        builder: (h, set) {
          final p = h.pivot;
          final aprueba = temas.every((t) => (notas['${t['nombre']}'] ?? 0) >= (t['minimo'] as int));
          final completas = notas.values.every((n) => n != null);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(h).height * 0.85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('Evaluación de ${x['nombreMostrar']}', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      children: [
                        for (final t in temas) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text('${t['nombre']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              Text('Mínimo ${t['minimo']}', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          EscalaDiez(valor: notas['${t['nombre']}'], alCambiar: (n) => set(() => notas['${t['nombre']}'] = n)),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            key: ValueKey('$completas$aprueba'),
                            !completas
                                ? 'Faltan temas por evaluar.'
                                : (aprueba ? 'Aprueba: llega al mínimo en todos los temas.' : 'No aprueba: hay temas por debajo del mínimo.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w700, color: completas && aprueba ? p.texto : p.marcaTexto),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: notas.values.any((n) => n != null) ? () => Navigator.of(h).pop(true) : null,
                          child: const Text('Guardar evaluación'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ok != true) return;
    await widget.llamar({
      'accion': 'evaluar',
      'inscripcionId': x['id'],
      'notas': jsonEncode({
        for (final e in notas.entries)
          if (e.value != null) e.key: e.value,
      }),
    });
    if (mounted) setState(() {});
  }

  Future<void> _resultado(Map<String, dynamic> x) async {
    final curso = c;
    if (curso == null) return;
    var equipo = x['equipo'] as String? ?? curso.equipoDestino ?? (widget.equipos.isEmpty ? null : widget.equipos.first);
    final r = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (h) => StatefulBuilder(
        builder: (h, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Evaluación de ${x['nombreMostrar']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (widget.equipos.isNotEmpty) ...[
                  const Text('Si aprueba, pasa a'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final e in widget.equipos) ChoiceChip(label: Text(e), selected: equipo == e, onSelected: (_) => set(() => equipo = e))],
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: () => Navigator.of(h).pop('si'), child: Text(equipo == null ? 'Aprobó' : 'Aprobó: pasa a $equipo')),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(onPressed: () => Navigator.of(h).pop('no'), child: const Text('No aprobó')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (r == null) return;
    await widget.llamar({'accion': 'resultado', 'inscripcionId': x['id'], 'aprobado': r == 'si', 'equipo': r == 'si' ? equipo : null});
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final curso = c;
    if (curso == null) return Scaffold(appBar: _barra('Curso'));
    final l = curso.fechas;
    final iEval = [for (var i = 0; i < l.length; i++) Curso.tipoFecha(l, i)].indexOf('evaluacion');
    final tryOut = iEval < 0 ? null : Curso.fecha(l[iEval]);
    final yaFueTryOut = tryOut != null && !tryOut.isAfter(Fechas.hoy());
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: Text(curso.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await widget.editar(curso);
              if (mounted) setState(() {});
            },
          ),
          // Para repetirlo (Victor, 2026-11-17).
          IconButton(
            tooltip: 'Guardar como plantilla',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () async {
              final ok = await widget.llamar({
                'accion': 'guardarPlantilla',
                'plantilla': jsonEncode({
                  'nombre': curso.nombre,
                  'tipo': curso.tipo,
                  'descripcion': curso.descripcion,
                  'clases': [
                    for (var i = 0; i < curso.fechas.length; i++)
                      if (Curso.tipoFecha(curso.fechas, i) != 'evaluacion')
                        {'tipo': Curso.tipoFecha(curso.fechas, i), 'temas': curso.fechas[i]['temas'] ?? const []},
                  ],
                  'evaluacion': {'temas': curso.temasEvaluacion},
                }),
              });
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plantilla guardada: aparece al crear un curso nuevo.')));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'abierto', label: Text('Abierto')),
              ButtonSegment(value: 'cerrado', label: Text('Cerrado')),
              ButtonSegment(value: 'terminado', label: Text('Terminado')),
            ],
            selected: {curso.estado},
            onSelectionChanged: (x) => _estado(x.first),
          ),
          const SizedBox(height: 6),
          Text(switch (curso.estado) {
            'cerrado' => 'Ya no recibe inscripciones; quienes se inscribieron lo siguen viendo.',
            'terminado' => 'El curso terminó y ya no aparece en la app.',
            _ => 'Aparece en Cursos (arriba en el Calendario) para inscribirse.',
          }, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
          // Invitar con un enlace (Victor, 2026-11-17).
          if (curso.estado == 'abierto') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Invita a inscribirse',
                    style: TextStyle(fontWeight: FontWeight.w800, color: p.sobreSuave),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Quien abre el enlace con su cuenta de la liga ve ${curso.esClinica ? 'la clínica' : 'el curso'} y se inscribe ahí.',
                    style: TextStyle(fontSize: 13, color: p.sobreSuave),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: curso.enlace));
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enlace copiado')));
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copiar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => SharePlus.instance.share(
                            ShareParams(text: '${curso.nombre}${curso.descripcion.isEmpty ? '' : ': ${curso.descripcion}'}\nInscríbete aquí: ${curso.enlace}'),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Compartir'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _Fechas(curso: curso),
          const SizedBox(height: 8),
          Text(
            [
              _precio(curso.precio),
              curso.cupo == null ? 'sin límite de cupo' : 'cupo de ${curso.cupo}',
              if (curso.cambiaEquipo && curso.equipoDestino != null) 'al aprobar pasan a ${curso.equipoDestino}',
            ].join(' · '),
            style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
          ),
          const SizedBox(height: 20),
          Text(
            'INSCRITXS (${curso.personas.length})',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
          ),
          const SizedBox(height: 6),
          if (curso.personas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Todavía nadie se inscribió.', style: TextStyle(color: p.textoSecundario)),
            ),
          for (final x in curso.personas)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: p.suave,
                backgroundImage: '${x['foto'] ?? ''}'.isNotEmpty ? NetworkImage('${x['foto']}') : null,
                child: '${x['foto'] ?? ''}'.isNotEmpty
                    ? null
                    : Text('${x['nombreMostrar']}'.characters.first.toUpperCase(), style: TextStyle(color: p.sobreSuave)),
              ),
              title: Text('${x['nombreMostrar']}'),
              subtitle: Text(switch ((x['estado'], x['resultado'])) {
                ('pendiente', _) => 'Pago por confirmar',
                (_, 'aprobado') => x['equipo'] == null ? 'Aprobó la evaluación' : 'Aprobó · pasó a ${x['equipo']}',
                (_, 'no_aprobado') => 'No aprobó la evaluación',
                _ => 'Inscripción confirmada',
              }),
              trailing: x['estado'] == 'confirmada' && (yaFueTryOut || (tryOut == null && curso.temasEvaluacion.isNotEmpty))
                  ? TextButton(
                      onPressed: () => curso.temasEvaluacion.isEmpty ? _resultado(x) : _evaluar(curso, x),
                      child: Text(x['resultado'] == null ? 'Evaluar' : 'Cambiar'),
                    )
                  : null,
            ),
          if (tryOut != null && !yaFueTryOut && curso.personas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Ese día podrás evaluar a cada persona en los temas de las clases.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
            ),
        ],
      ),
    );
  }
}
