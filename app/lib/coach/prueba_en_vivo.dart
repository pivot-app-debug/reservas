import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/fechas.dart';
import '../core/tema.dart';
import '../core/vidrio.dart' show altoBarra;
import '../eventos/widgets_comunes.dart' show AvatarPersona;
import '../sesion/sesion.dart';
import 'coach_screen.dart' show barraCoach, errorCoach;

/// Prueba en vivo (Victor, 2026-11-26, etapa 3 de Entrenamiento): con
/// temporizador. Si más es mejor (ej. vueltas en 5 minutos), cuenta hacia
/// atrás y se suma a cada persona con un toque; si menos es mejor (ej.
/// segundos), corre un cronómetro y se toca a cada persona al terminar.
/// Al final se guarda un resultado por persona en su progreso.
class PruebaEnVivoScreen extends StatefulWidget {
  const PruebaEnVivoScreen({super.key, required this.sesion, required this.prueba, required this.jugadorxs});
  final Sesion sesion;
  final Map<String, dynamic> prueba;
  final List<Map<String, dynamic>> jugadorxs;

  @override
  State<PruebaEnVivoScreen> createState() => _PruebaEnVivoScreenState();
}

enum _Fase { preparar, corriendo, terminada }

class _PruebaEnVivoScreenState extends State<PruebaEnVivoScreen> {
  late final bool _mas = widget.prueba['masEsMejor'] != false;
  late final String _unidad = '${widget.prueba['unidad'] ?? ''}';
  late final List<Map<String, dynamic>> _personas = () {
    final solo = {for (final u in (widget.prueba['personas'] as List? ?? const [])) '$u'};
    return widget.jugadorxs.where((j) => solo.isEmpty || solo.contains('${j['username']}')).toList();
  }();
  late final Set<String> _participan = {for (final j in _personas) '${j['username']}'};

  _Fase _fase = _Fase.preparar;
  int _minutos = 5;
  final _reloj = Stopwatch();
  Timer? _tick;
  final Map<String, num> _valores = {};
  bool _guardando = false;

  Duration get _total => Duration(minutes: _minutos);
  Duration get _transcurrido => _reloj.elapsed;
  Duration get _queda => _total - _transcurrido < Duration.zero ? Duration.zero : _total - _transcurrido;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _comenzar() {
    HapticFeedback.mediumImpact();
    setState(() {
      _fase = _Fase.corriendo;
      _valores.clear();
      if (_mas) {
        for (final u in _participan) {
          _valores[u] = 0;
        }
      }
    });
    _reloj
      ..reset()
      ..start();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (_mas && _queda == Duration.zero) {
        _terminar();
        return;
      }
      setState(() {});
    });
  }

  void _terminar() {
    _reloj.stop();
    _tick?.cancel();
    HapticFeedback.heavyImpact();
    setState(() => _fase = _Fase.terminada);
  }

  void _pausar() {
    setState(() => _reloj.isRunning ? _reloj.stop() : _reloj.start());
  }

  void _tocar(String u, {int cambio = 1}) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_mas) {
        _valores[u] = ((_valores[u] ?? 0) + cambio).clamp(0, 9999);
      } else if (_valores[u] == null) {
        // Menos es mejor: el tiempo en que terminó, en segundos con un decimal.
        _valores[u] = (_transcurrido.inMilliseconds / 100).round() / 10;
        if (_valores.length == _participan.length) _terminar();
      } else {
        _valores.remove(u);
      }
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    var n = 0;
    try {
      for (final e in _valores.entries) {
        final r = await widget.sesion.api.post('coachPruebas', {
          'accion': 'marca',
          'pruebaId': '${widget.prueba['id']}',
          'username': e.key,
          'valor': '${e.value}',
          'fecha': Fechas.iso(Fechas.hoy()),
        });
        if (r['exito'] == false) throw ApiException('${r['error']}');
        n++;
      }
      m.showSnackBar(SnackBar(content: Text(n == 1 ? 'Se guardó 1 resultado.' : 'Se guardaron $n resultados.')));
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      m.showSnackBar(SnackBar(content: Text('${errorCoach(e)} Se guardaron $n.')));
    }
  }

  String _reloj2(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$mm:$ss' : '$mm:$ss';
  }

  String _num(num v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _fase != _Fase.corriendo && (_fase != _Fase.terminada || _valores.isEmpty),
      onPopInvokedWithResult: (hizo, _) async {
        if (hizo) return;
        final salir = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('¿Salir sin guardar?'),
            content: const Text('Los resultados de esta prueba no se guardan.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Volver')),
              FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Salir')),
            ],
          ),
        );
        if (salir == true && context.mounted) {
          _tick?.cancel();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: barraCoach('${widget.prueba['nombre']}'),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: KeyedSubtree(key: ValueKey(_fase == _Fase.preparar), child: _fase == _Fase.preparar ? _preparar(context) : _enCurso(context)),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: switch (_fase) {
              _Fase.preparar => FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _participan.isEmpty ? null : _comenzar,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Comenzar'),
              ),
              _Fase.corriendo => Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: _pausar,
                      icon: Icon(_reloj.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      label: Text(_reloj.isRunning ? 'Pausar' : 'Seguir'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: _terminar,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Terminar'),
                    ),
                  ),
                ],
              ),
              _Fase.terminada => FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _valores.isEmpty || _guardando ? null : _guardar,
                icon: _guardando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                label: Text(_valores.length == 1 ? 'Guardar 1 resultado' : 'Guardar ${_valores.length} resultados'),
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _preparar(BuildContext context) {
    final p = context.pivot;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12 + altoBarra(context), 16, 24),
      children: [
        Text(
          _mas
              ? 'Corre el tiempo hacia atrás y vas sumando $_unidad a cada persona con un toque.'
              : 'Corre un cronómetro y tocas a cada persona cuando termina: queda su tiempo.',
          style: TextStyle(height: 1.35, color: p.texto),
        ),
        if (_mas) ...[
          const SizedBox(height: 16),
          const Text('Duración', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final m in const [1, 2, 3, 5, 10, 15])
                ChoiceChip(label: Text('$m min'), selected: _minutos == m, onSelected: (_) => setState(() => _minutos = m)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text('¿Quiénes participan?', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => setState(
                () => _participan.length == _personas.length ? _participan.clear() : _participan.addAll([for (final j in _personas) '${j['username']}']),
              ),
              child: Text(_participan.length == _personas.length ? 'Ninguna' : 'Todas'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final j in _personas)
              FilterChip(
                avatar: AvatarPersona(nombre: '${j['nombre']}', foto: '${j['foto'] ?? ''}', tamano: 24),
                label: Text('${j['nombre']}'),
                selected: _participan.contains('${j['username']}'),
                onSelected: (v) => setState(() => v ? _participan.add('${j['username']}') : _participan.remove('${j['username']}')),
              ),
          ],
        ),
        if (_personas.isEmpty) Text('No hay personas para esta prueba.', style: TextStyle(color: p.textoSecundario)),
      ],
    );
  }

  Widget _enCurso(BuildContext context) {
    final p = context.pivot;
    final personas = _personas.where((j) => _participan.contains('${j['username']}')).toList();
    final reloj = _mas ? _queda : _transcurrido;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24),
      children: [
        Center(
          child: Text(
            _fase == _Fase.terminada ? 'Terminó' : _reloj2(reloj),
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: _mas && _queda.inSeconds <= 10 && _fase == _Fase.corriendo ? p.marcaTexto : p.texto,
            ),
          ),
        ),
        Center(
          child: Text(
            _fase == _Fase.terminada
                ? 'Revisa los resultados y guárdalos.'
                : (_mas ? 'Toca a cada persona para sumar $_unidad.' : 'Toca a cada persona cuando termine.'),
            style: TextStyle(color: p.textoSecundario),
          ),
        ),
        const SizedBox(height: 14),
        for (final j in personas) _fila(p, j),
      ],
    );
  }

  Widget _fila(PivotPaleta p, Map<String, dynamic> j) {
    final u = '${j['username']}';
    final v = _valores[u];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: v != null && !_mas ? p.suave : p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _tocar(u),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                AvatarPersona(nombre: '${j['nombre']}', foto: '${j['foto'] ?? ''}', tamano: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${j['nombre']}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                  ),
                ),
                if (_mas) IconButton(tooltip: 'Restar', onPressed: (v ?? 0) > 0 ? () => _tocar(u, cambio: -1) : null, icon: const Icon(Icons.remove_rounded)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (h, a) => ScaleTransition(scale: a, child: h),
                  child: Text(
                    v == null ? '—' : '${_num(v)}${_mas ? '' : ' s'}',
                    key: ValueKey(v),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: p.marcaTexto),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
