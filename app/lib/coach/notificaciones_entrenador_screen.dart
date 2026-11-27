import 'dart:convert';

import 'package:flutter/material.dart';

import '../ajustes/componentes.dart';
import '../core/api.dart';
import '../core/tema.dart';
import '../core/vidrio.dart' show altoBarra;
import '../eventos/widgets_comunes.dart' show AvatarPersona;
import '../sesion/sesion.dart';
import 'coach_screen.dart' show barraCoach, errorCoach;

/// Notificaciones de entrenador (Victor, 2026-11-26): qué avisos le llegan a
/// cada persona que entrenas, mandar avisos tuyos y elegir los que te llegan
/// a ti como entrenadorx.
class NotificacionesEntrenadorScreen extends StatefulWidget {
  const NotificacionesEntrenadorScreen({super.key, required this.sesion, required this.jugadorxs, required this.sinAvisos, required this.avisarNovedades});
  final Sesion sesion;
  final List<Map<String, dynamic>> jugadorxs;
  final List<String> sinAvisos;
  final bool avisarNovedades;

  @override
  State<NotificacionesEntrenadorScreen> createState() => _NotificacionesEntrenadorScreenState();
}

/// Avisos que recibe unx entrenadorx (claves del catálogo del servidor).
const _misAvisos = [
  ('coach_por_evaluar', 'Entrenamientos por evaluar', 'El día siguiente, si falta evaluar a quienes vinieron.'),
  ('coach_pedido_plan', 'Entrenamiento sin plan', 'El día antes, si un entrenamiento todavía no tiene plan.'),
  ('cambios_asistencia', 'Cambios de asistencia', 'Cuando alguien cambia su respuesta a un entrenamiento.'),
];

class _NotificacionesEntrenadorScreenState extends State<NotificacionesEntrenadorScreen> {
  Sesion get s => widget.sesion;
  late final Set<String> _callados = {...widget.sinAvisos};
  late bool _novedades = widget.avisarNovedades;
  Map<String, bool>? _prefs;
  final _busca = TextEditingController();

  @override
  void initState() {
    super.initState();
    s.api.get('getPreferenciasPush').then((r) {
      if (!mounted || r['exito'] == false) return;
      setState(() => _prefs = {for (final e in ((r['preferencias'] as Map?) ?? const {}).entries) '${e.key}': e.value == true});
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  void _aviso(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _persona(String u, bool activo) async {
    setState(() => activo ? _callados.remove(u) : _callados.add(u));
    try {
      final r = await s.api.post('coachGuardar', {'accion': 'avisosPersona', 'username': u, 'activo': activo});
      if (r['exito'] == false) throw ApiException('${r['error']}');
    } catch (e) {
      if (!mounted) return;
      setState(() => activo ? _callados.add(u) : _callados.remove(u));
      _aviso(errorCoach(e));
    }
  }

  Future<void> _resumen(bool v) async {
    setState(() => _novedades = v);
    try {
      await s.api.post('coachGuardar', {'accion': 'ajustes', 'avisarNovedades': v});
    } catch (_) {
      if (mounted) setState(() => _novedades = !v);
    }
  }

  Future<void> _mio(String clave, bool v) async {
    final antes = _prefs?[clave];
    setState(() => (_prefs ??= {})[clave] = v);
    try {
      final r = await s.api.post('guardarPreferenciasPush', {'clave': clave, 'valor': '$v'});
      if (r['exito'] != true) throw ApiException('${r['error'] ?? ''}');
    } catch (_) {
      if (!mounted) return;
      setState(() => antes == null ? _prefs!.remove(clave) : _prefs![clave] = antes);
      _aviso('No se pudo guardar. Revisa tu conexión.');
    }
  }

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
    child: Text(
      t,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.pivot.textoSecundario),
    ),
  );

  Widget _grupo(List<Widget> hijos) => Material(
    color: context.pivot.tarjeta,
    borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
    clipBehavior: Clip.antiAlias,
    child: Column(children: hijos),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final q = _busca.text.trim().toLowerCase();
    final personas = widget.jugadorxs.where((x) => q.isEmpty || '${x['nombre']}'.toLowerCase().contains(q)).toList();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: barraCoach('Notificaciones de entrenador'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => SubAjustes.abrir<void>(
              context,
              EnviarAvisoEntrenadorScreen(sesion: s, jugadorxs: widget.jugadorxs.where((x) => !_callados.contains('${x['username']}')).toList()),
            ),
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Mandar un aviso'),
          ),
          _titulo('A LAS PERSONAS QUE ENTRENAS'),
          _grupo([
            SwitchListTile(
              secondary: Icon(Icons.auto_awesome_outlined, color: p.marcaTexto),
              title: const Text('Novedades de su progreso'),
              subtitle: const Text('Los lunes, a quien tiene notas o resultados nuevos tuyos. Si no hay nada nuevo, no le llega nada.'),
              value: _novedades,
              onChanged: _resumen,
            ),
          ]),
          if (widget.jugadorxs.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                controller: _busca,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar persona'),
              ),
            ),
          const SizedBox(height: 10),
          if (widget.jugadorxs.isEmpty)
            Text('Todavía no hay personas en tus equipos.', style: TextStyle(color: p.textoSecundario))
          else
            _grupo([
              for (final x in personas)
                SwitchListTile(
                  secondary: AvatarPersona(nombre: '${x['nombre']}', foto: '${x['foto'] ?? ''}', tamano: 36),
                  title: Text('${x['nombre']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_callados.contains('${x['username']}') ? 'No le llegan tus avisos' : 'Le llegan tus avisos'),
                  value: !_callados.contains('${x['username']}'),
                  onChanged: (v) => _persona('${x['username']}', v),
                ),
            ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Cada persona también puede apagar los avisos de entrenadorxs en Mi perfil → Notificaciones.',
              style: TextStyle(fontSize: 12.5, color: p.textoSecundario),
            ),
          ),
          _titulo('LO QUE TE LLEGA A TI'),
          _grupo([
            for (final a in _misAvisos)
              SwitchListTile(title: Text(a.$2), subtitle: Text(a.$3), value: _prefs?[a.$1] != false, onChanged: _prefs == null ? null : (v) => _mio(a.$1, v)),
          ]),
        ],
      ),
    );
  }
}

/// Mandar un aviso de entrenador: a todxs o a algunas personas. Es una
/// subsección porque se escribe con teclado.
class EnviarAvisoEntrenadorScreen extends StatefulWidget {
  const EnviarAvisoEntrenadorScreen({super.key, required this.sesion, required this.jugadorxs});
  final Sesion sesion;
  final List<Map<String, dynamic>> jugadorxs;

  @override
  State<EnviarAvisoEntrenadorScreen> createState() => _EnviarAvisoEntrenadorScreenState();
}

class _EnviarAvisoEntrenadorScreenState extends State<EnviarAvisoEntrenadorScreen> {
  final _titulo = TextEditingController();
  final _texto = TextEditingController();
  bool _todxs = true;
  final Set<String> _elegidxs = {};
  bool _enviando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _texto.dispose();
    super.dispose();
  }

  bool get _listo => _texto.text.trim().isNotEmpty && (_todxs || _elegidxs.isNotEmpty) && !_enviando;

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    final m = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final r = await widget.sesion.api.post('coachGuardar', {
        'accion': 'enviarAviso',
        'titulo': _titulo.text.trim(),
        'texto': _texto.text.trim(),
        'para': jsonEncode(_todxs ? <String>[] : _elegidxs.toList()),
      });
      if (r['exito'] == false) throw ApiException('${r['error']}');
      final n = (r['enviados'] as num?)?.toInt() ?? 0;
      m.showSnackBar(SnackBar(content: Text(n == 1 ? 'Aviso enviado a 1 persona.' : 'Aviso enviado a $n personas.')));
      nav.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      m.showSnackBar(SnackBar(content: Text(errorCoach(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: barraCoach('Mandar un aviso'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12 + altoBarra(context), 16, 120 + MediaQuery.paddingOf(context).bottom),
        children: [
          TextField(
            controller: _titulo,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Título (opcional)', hintText: 'Ej. Traigan protecciones completas'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _texto,
            minLines: 3,
            maxLines: 8,
            maxLength: 400,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Aviso', alignLabelWithHint: true),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('A todxs'), icon: Icon(Icons.groups_outlined)),
              ButtonSegment(value: false, label: Text('Elegir personas'), icon: Icon(Icons.person_search_outlined)),
            ],
            selected: {_todxs},
            onSelectionChanged: (v) => setState(() => _todxs = v.first),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _todxs
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Text(
                      widget.jugadorxs.length == 1 ? 'Le llega a 1 persona.' : 'Les llega a ${widget.jugadorxs.length} personas de tus equipos.',
                      style: TextStyle(color: p.textoSecundario),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final x in widget.jugadorxs)
                          FilterChip(
                            label: Text('${x['nombre']}'),
                            selected: _elegidxs.contains('${x['username']}'),
                            onSelected: (v) => setState(() => v ? _elegidxs.add('${x['username']}') : _elegidxs.remove('${x['username']}')),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _listo ? _enviar : null,
            icon: _enviando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
            label: const Text('Enviar'),
          ),
        ),
      ),
    );
  }
}
