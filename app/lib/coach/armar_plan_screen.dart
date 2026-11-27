import 'package:flutter/material.dart';

import '../core/esqueleto.dart';
import '../core/fechas.dart';
import '../core/tema.dart';
import '../core/vidrio.dart' show altoBarra;
import '../equipo/habilidades_screen.dart' show nivelesCoach;
import '../eventos/modelos.dart';
import '../sesion/sesion.dart';
import 'coach_screen.dart';

/// Armar el plan de un entrenamiento en pasos (Victor, 2026-11-26: antes era
/// un bottom sheet enorme). 1) qué entrenamiento, 2) para quién (toda la
/// liga, un equipo o un nivel) y después el editor del plan.
class ArmarPlanScreen extends StatefulWidget {
  const ArmarPlanScreen({super.key, required this.sesion, required this.entrenamientos});
  final Sesion sesion;
  final List<Evento> entrenamientos;

  @override
  State<ArmarPlanScreen> createState() => _ArmarPlanScreenState();
}

class _ArmarPlanScreenState extends State<ArmarPlanScreen> {
  int _paso = 0;
  Evento? _evento;
  Map<String, dynamic>? _datos;
  String? _error;

  @override
  void initState() {
    super.initState();
    // El estado del plan de cada entrenamiento, por detrás.
    for (final e in widget.entrenamientos.take(12)) {
      PlanEnEvento.precargar(widget.sesion, e.id).then((_) {
        if (mounted) setState(() {});
      }, onError: (_) {});
    }
  }

  Future<void> _elegirEvento(Evento e) async {
    setState(() {
      _evento = e;
      _paso = 1;
      _datos = PlanEnEvento.cache[e.id];
      _error = null;
    });
    try {
      final r = await PlanEnEvento.precargar(widget.sesion, e.id, forzar: true);
      if (!mounted || _evento != e) return;
      setState(() => _datos = r ?? const {});
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar. Revisa tu conexión.');
    }
  }

  List<Map<String, dynamic>> get _hechos => [for (final x in (_datos?['planes'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

  Future<void> _elegirPara(String para) async {
    final e = _evento!;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PlanEventoScreen(sesion: widget.sesion, evento: e, equipo: para, plan: _hechos.where((x) => '${x['equipo'] ?? ''}' == para).firstOrNull),
      ),
    );
    if (ok == true) {
      await PlanEnEvento.precargar(widget.sesion, e.id, forzar: true).catchError((_) => null);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paso == 0,
      onPopInvokedWithResult: (hizo, _) {
        if (!hizo) setState(() => _paso = 0);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: barraCoach(
          'Armar un plan',
          abajo: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _Pasos(actual: _paso, total: 2),
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (hijo, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
              child: hijo,
            ),
          ),
          child: _paso == 0
              ? KeyedSubtree(key: const ValueKey(0), child: _pasoEvento(context))
              : KeyedSubtree(key: const ValueKey(1), child: _pasoPara(context)),
        ),
      ),
    );
  }

  EdgeInsets _relleno(BuildContext context) => EdgeInsets.fromLTRB(16, 12 + altoBarra(context) + 28, 16, 40 + MediaQuery.paddingOf(context).bottom);

  Widget _titulo(BuildContext context, String t, String sub) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(color: context.pivot.textoSecundario)),
      ],
    ),
  );

  Widget _pasoEvento(BuildContext context) {
    final p = context.pivot;
    return ListView(
      padding: _relleno(context),
      children: [
        _titulo(context, '¿Para qué entrenamiento?', 'Los próximos del calendario.'),
        for (final e in widget.entrenamientos.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: p.tarjeta,
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(Icons.event_outlined, color: p.marcaTexto),
                title: Text('${Fechas.dia(e.fecha)} ${Fechas.corta(e.fecha)} · ${e.horaInicio}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  [
                    if (e.lugar.isNotEmpty) e.lugar,
                    switch (PlanEnEvento.cache[e.id]?['planes'] as List?) {
                      null => 'Revisando el plan…',
                      final l when l.isEmpty => 'Sin plan',
                      final l => l.length == 1 ? 'Ya tiene 1 plan' : 'Ya tiene ${l.length} planes',
                    },
                  ].join(' · '),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: p.textoSecundario),
                onTap: () => _elegirEvento(e),
              ),
            ),
          ),
      ],
    );
  }

  Widget _pasoPara(BuildContext context) {
    final p = context.pivot;
    final d = _datos;
    if (d == null) {
      return _error != null ? Center(child: Text(_error!)) : const Esqueleto(forma: FormaEsqueleto.lista);
    }
    final equipos = [for (final e in (d['equiposPlan'] as List? ?? const [])) '$e'];
    final hay = {for (final x in _hechos) '${x['equipo'] ?? ''}'};
    Widget opcion(String para, IconData icono, String titulo) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icono, color: p.marcaTexto),
          title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(hay.contains(para) ? 'Ya tiene plan: editarlo' : 'Sin plan'),
          trailing: hay.contains(para)
              ? Icon(Icons.assignment_turned_in_outlined, color: p.marcaTexto)
              : Icon(Icons.chevron_right_rounded, color: p.textoSecundario),
          onTap: () => _elegirPara(para),
        ),
      ),
    );
    final e = _evento!;
    return ListView(
      padding: _relleno(context),
      children: [
        _titulo(context, '¿Para quién es el plan?', '${Fechas.dia(e.fecha)} ${Fechas.corta(e.fecha)} · ${e.horaInicio}'),
        if (d['deTodaLaLiga'] == true) opcion('', Icons.groups_rounded, 'Toda la liga'),
        for (final x in equipos) opcion(x, Icons.group_outlined, x),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Text(
            'POR NIVEL',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
          ),
        ),
        for (final n in nivelesCoach.entries) opcion('nivel:${n.key}', Icons.stairs_outlined, n.value),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text('Un plan por nivel lo ven, si lo compartes, las personas de ese nivel.', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
        ),
      ],
    );
  }
}

/// Indicador de pasos: barras que se llenan.
class _Pasos extends StatelessWidget {
  const _Pasos({required this.actual, required this.total});
  final int actual;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              height: 4,
              decoration: BoxDecoration(color: i <= actual ? p.marca : p.borde, borderRadius: BorderRadius.circular(PivotRadios.chip)),
            ),
          ),
        ],
        const SizedBox(width: 10),
        Text('Paso ${actual + 1} de $total', style: TextStyle(fontSize: 12, color: p.textoSecundario)),
      ],
    );
  }
}
