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

/// Cursos con try out (Victor, 2026-11-16): varias fechas con precio propio
/// e inscripción con cupo. La última fecha es el try out; al aprobarlo, el
/// Pivot elige a qué equipo pasa la persona.
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
            'Un grupo de clases con inscripción: para quienes empiezan o para practicar algo más avanzado. Si quieres, termina con una evaluación final para entrar a un equipo.',
            style: TextStyle(height: 1.35, color: p.sobreSuave),
          ),
          paso(Icons.event_outlined, 'Eliges las clases: cada una aparece en el calendario con su día, hora y lugar.'),
          paso(
            Icons.payments_outlined,
            'Le pones precio y, si quieres, un cupo. Las personas se inscriben desde el "+" del calendario y pagan con los medios de la liga.',
          ),
          paso(Icons.emoji_events_outlined, 'Si tiene evaluación final, ese día marcas quién aprobó y a qué equipo pasa.'),
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
      if (mounted) setState(() => _cursos = [for (final c in (r['cursos'] as List? ?? const [])) Curso(Map<String, dynamic>.from(c as Map))]);
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
        builder: (_) => _EditorCurso(curso: c, equipos: _equipos, lugares: _lugares),
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
              if (curso.equipoDestino != null) 'pasan a ${curso.equipoDestino}',
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
              trailing: x['estado'] == 'confirmada' && yaFueTryOut
                  ? TextButton(onPressed: () => _resultado(x), child: Text(x['resultado'] == null ? 'Resultado' : 'Cambiar'))
                  : null,
            ),
          if (tryOut != null && !yaFueTryOut && curso.personas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'El día de la evaluación final podrás marcar quién aprobó y a qué equipo pasa.',
                style: TextStyle(fontSize: 13, color: p.textoSecundario),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditorCurso extends StatefulWidget {
  const _EditorCurso({this.curso, required this.equipos, required this.lugares});
  final Curso? curso;
  final List<String> equipos, lugares;
  @override
  State<_EditorCurso> createState() => _EditorCursoState();
}

class _EditorCursoState extends State<_EditorCurso> {
  late final o = widget.curso;
  late final _nombre = TextEditingController(text: o?.nombre ?? '');
  late final _descripcion = TextEditingController(text: o?.descripcion ?? '');
  late final _precio = TextEditingController(text: o == null ? '' : '${o!.precio % 1 == 0 ? o!.precio.toInt() : o!.precio}');
  late bool _conCupo = o?.cupo != null;
  late int _cupo = o?.cupo ?? 20;
  late String? _equipo = o?.equipoDestino;
  // Curso o clínica (Victor, 2026-11-17). Clases (y clínicas en medio) y,
  // aparte, la evaluación final opcional.
  late String _tipo = o?.tipo ?? 'curso';
  late final List<Map<String, dynamic>> _clases = [
    for (var i = 0; i < (o?.fechas.length ?? 0); i++)
      if (Curso.tipoFecha(o!.fechas, i) != 'evaluacion') {...o!.fechas[i], 'tipo': Curso.tipoFecha(o!.fechas, i)},
  ];
  late Map<String, dynamic>? _tryout = [
    for (var i = 0; i < (o?.fechas.length ?? 0); i++)
      if (Curso.tipoFecha(o!.fechas, i) == 'evaluacion') o!.fechas[i],
  ].firstOrNull;
  bool get _clinica => _tipo == 'clinica';

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _precio.dispose();
    super.dispose();
  }

  num? get _monto => _precio.text.trim().isEmpty ? 0 : num.tryParse(_precio.text.replaceAll(',', '.'));

  static String _titulo(Map f) {
    final d = Curso.fecha(f);
    return d == null ? '${f['fecha']}' : '${Fechas.dia(d)} ${Fechas.corta(d)}';
  }

  /// El try out va después de la última clase.
  bool get _tryoutAntes => _tryout != null && _clases.isNotEmpty && '${_tryout!['fecha']}'.compareTo('${_clases.last['fecha']}') < 0;

  /// Elige día, hora y lugar, partiendo de [previa] (o de [sugerida]).
  Future<Map<String, dynamic>?> _elegir(Map<String, dynamic>? previa, DateTime sugerida) async {
    final d = await showDatePicker(
      context: context,
      initialDate: previa == null ? sugerida : (Curso.fecha(previa) ?? sugerida),
      firstDate: Fechas.hoy().subtract(const Duration(days: 365)),
      lastDate: Fechas.hoy().add(const Duration(days: 730)),
    );
    if (d == null || !mounted) return null;
    final base = previa ?? (_clases.isEmpty ? null : _clases.last);
    final h0 = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('${base?['hora'] ?? '09:00'}');
    final h = await elegirHora(
      context,
      inicial: TimeOfDay(hour: int.parse(h0?.group(1) ?? '9'), minute: int.parse(h0?.group(2) ?? '0')),
      titulo: 'Hora de la clase',
    );
    if (h == null || !mounted) return null;
    var lugar = '${base?['lugar'] ?? (widget.lugares.isEmpty ? '' : widget.lugares.first)}';
    if (widget.lugares.length > 1) {
      final l = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '¿Dónde?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.pivot.texto),
                ),
              ),
              for (final x in widget.lugares)
                ListTile(
                  leading: Icon(x == lugar ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                  title: Text(x),
                  onTap: () => Navigator.of(c).pop(x),
                ),
            ],
          ),
        ),
      );
      if (l == null) return null;
      lugar = l;
    }
    return {'fecha': Fechas.iso(d), 'hora': '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}', 'lugar': lugar};
  }

  Future<void> _clase([int? i, String tipo = 'clase']) async {
    final ultima = _clases.isEmpty ? null : Curso.fecha(_clases.last);
    var f = await _elegir(i == null ? null : _clases[i], ultima == null ? Fechas.hoy() : ultima.add(const Duration(days: 7)));
    if (f == null || !mounted) return;
    final t = i == null ? tipo : '${_clases[i]['tipo'] ?? 'clase'}';
    f = {...f, 'tipo': t};
    // Clínica: hasta qué hora y, dentro de un curso, de qué se trata.
    if (t == 'clinica' || _clinica) {
      final previa = i == null ? null : _clases[i];
      final fin = await elegirHoraTexto(context, inicial: '${previa?['termina'] ?? _sumarHoras('${f['hora']}', _clinica ? 5 : 2)}', titulo: 'Termina');
      if (fin == null || !mounted) return;
      f['termina'] = fin;
      if (!_clinica) {
        final ctl = TextEditingController(text: '${previa?['titulo'] ?? ''}');
        final titulo = await showDialog<String>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('¿De qué es la clínica?'),
            content: TextField(
              controller: ctl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Ej. Clínica con jugadorxs invitadxs'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.of(d).pop(ctl.text.trim()), child: const Text('Listo')),
            ],
          ),
        );
        if (titulo == null || !mounted) return;
        if (titulo.isNotEmpty) f['titulo'] = titulo;
      }
    }
    final nueva = f;
    setState(() {
      if (_clinica) {
        _clases
          ..clear()
          ..add(nueva);
        return;
      }
      if (i == null) {
        _clases.add(nueva);
      } else {
        _clases[i] = nueva;
      }
      _clases.sort((a, b) => '${a['fecha']}'.compareTo('${b['fecha']}'));
    });
  }

  Future<void> _elegirTryout() async {
    final ultima = _clases.isEmpty ? null : Curso.fecha(_clases.last);
    final f = await _elegir(_tryout, ultima == null ? Fechas.hoy() : ultima.add(const Duration(days: 7)));
    if (f != null) setState(() => _tryout = f);
  }

  static String _sumarHoras(String hhmm, int h) {
    final p = hhmm.split(':');
    final x = ((int.tryParse(p.first) ?? 9) + h) % 24;
    return '${x.toString().padLeft(2, '0')}:${p.length > 1 ? p[1] : '00'}';
  }

  Widget _filaFecha(PivotPaleta p, Map f, {required IconData icono, required VoidCallback alTocar, VoidCallback? alQuitar}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: p.tarjeta,
      borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icono, color: p.marcaTexto),
        title: Text([_titulo(f), if ('${f['titulo'] ?? ''}'.isNotEmpty) '${f['titulo']}'].join(' · '), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          ['${f['hora']}${'${f['termina'] ?? ''}'.isNotEmpty ? ' a ${f['termina']}' : ''}', if ('${f['lugar'] ?? ''}'.isNotEmpty) '${f['lugar']}'].join(' · '),
        ),
        onTap: alTocar,
        trailing: alQuitar == null
            ? const Icon(Icons.edit_outlined)
            : IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close_rounded), onPressed: alQuitar),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final valido = _nombre.text.trim().isNotEmpty && _monto != null && _clases.isNotEmpty && (_clinica || !_tryoutAntes);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _barra(o == null ? (_clinica ? 'Nueva clínica' : 'Nuevo curso') : (_clinica ? 'Editar clínica' : 'Editar curso')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (o == null) ...[const _QueEsUnCurso(), const SizedBox(height: 16)],
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'curso', icon: Icon(Icons.school_outlined), label: Text('Curso')),
              ButtonSegment(value: 'clinica', icon: Icon(Icons.star_outline_rounded), label: Text('Clínica')),
            ],
            selected: {_tipo},
            onSelectionChanged: (v) => setState(() {
              _tipo = v.first;
              if (_clinica && _clases.length > 1) _clases.removeRange(1, _clases.length);
            }),
          ),
          const SizedBox(height: 6),
          Text(
            _clinica
                ? 'Una sola sesión intensiva, por ejemplo con jugadorxs invitadxs de otra liga. Puede ser paga o gratis.'
                : 'Varias clases con inscripción. Puede tener clínicas en medio y una evaluación final.',
            style: TextStyle(fontSize: 13, color: p.textoSecundario),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nombre,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Nombre', hintText: _clinica ? 'Ej. Clínica intensiva de defensa' : 'Ej. Curso de iniciación de verano'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descripcion,
            maxLines: 6,
            minLines: 2,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Descripción', hintText: 'Qué se verá, quién la da, para quién es y qué se necesita'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _precio,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              labelText: _clinica ? 'Precio de la clínica' : 'Precio del curso',
              prefixText: '${Moneda.s} ',
              helperText: 'Vacío o 0: gratis',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Cupo limitado'), value: _conCupo, onChanged: (v) => setState(() => _conCupo = v)),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: _conCupo
                ? SelectorNumero(
                    valor: _cupo,
                    min: 1,
                    max: 200,
                    etiqueta: _cupo == 1 ? 'lugar' : 'lugares',
                    alCambiar: (v) => setState(() => _cupo = v.toInt()),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (widget.equipos.isNotEmpty && !_clinica && _tryout != null) ...[
            const SizedBox(height: 14),
            Text(
              'Equipo al que pasan si aprueban',
              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
            ),
            const SizedBox(height: 2),
            Text('Lo puedes cambiar para cada persona en la evaluación final.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in widget.equipos) ChoiceChip(label: Text(e), selected: _equipo == e, onSelected: (v) => setState(() => _equipo = v ? e : null)),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            _clinica ? 'Cuándo' : 'Clases',
            style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
          ),
          const SizedBox(height: 2),
          Text('Queda en el calendario con su día, hora y lugar. Quienes se inscriben la ven ahí.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
          const SizedBox(height: 8),
          for (var i = 0; i < _clases.length; i++)
            _filaFecha(
              p,
              _clases[i],
              icono: _clases[i]['tipo'] == 'clinica' || _clinica ? Icons.star_outline_rounded : Icons.event_outlined,
              alTocar: () => _clase(i),
              alQuitar: () => setState(() => _clases.removeAt(i)),
            ),
          if (!_clinica || _clases.isEmpty)
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _clase(null, _clinica ? 'clinica' : 'clase'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_clinica ? 'Elegir día y hora' : (_clases.isEmpty ? 'Agregar la primera clase' : 'Agregar clase')),
                ),
                if (!_clinica && _clases.isNotEmpty)
                  TextButton.icon(onPressed: () => _clase(null, 'clinica'), icon: const Icon(Icons.star_outline_rounded), label: const Text('Agregar clínica')),
              ],
            ),
          if (!_clinica) ...[
            const SizedBox(height: 16),
            Text(
              'Evaluación final (opcional)',
              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
            ),
            const SizedBox(height: 2),
            Text('Después de la última clase. Ese día marcas quién aprobó y a qué equipo pasa.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
            const SizedBox(height: 8),
            if (_tryout != null)
              _filaFecha(p, _tryout!, icono: Icons.emoji_events_outlined, alTocar: _elegirTryout, alQuitar: () => setState(() => _tryout = null))
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _elegirTryout,
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Elegir la fecha de la evaluación final'),
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _tryoutAntes
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('La evaluación final tiene que ser después de la última clase.', style: TextStyle(fontSize: 13, color: p.marcaTexto)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: valido
                ? () => Navigator.of(context).pop(<String, Object?>{
                    'id': o?.id,
                    'tipo': _tipo,
                    'nombre': _nombre.text.trim(),
                    'descripcion': _descripcion.text.trim(),
                    'precio': _monto,
                    'cupo': _conCupo ? _cupo : null,
                    'equipoDestino': _equipo,
                    'fechas': [
                      for (final f in _clases)
                        {
                          'fecha': f['fecha'],
                          'hora': f['hora'],
                          'lugar': f['lugar'],
                          'tipo': _clinica ? 'clinica' : (f['tipo'] ?? 'clase'),
                          'termina': ?f['termina'],
                          'titulo': ?f['titulo'],
                        },
                      if (!_clinica && _tryout != null)
                        {'fecha': _tryout!['fecha'], 'hora': _tryout!['hora'], 'lugar': _tryout!['lugar'], 'tipo': 'evaluacion'},
                    ],
                  })
                : null,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
