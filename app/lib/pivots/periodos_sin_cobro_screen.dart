import 'package:flutter/material.dart';

import '../ajustes/componentes.dart';
import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/fechas.dart';
import '../core/periodos_sin_cobro.dart';
import '../core/selector_plazo.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';

/// Meses y periodos sin cobro (Victor, 2026-11-20), en Reglas de la liga → Pagos.
/// Para toda la liga o algunos equipos. Se guarda la lista completa en
/// `reglas_liga.periodosSinCobro`; el servidor conserva lo que ya terminó.
String textoPeriodosSinCobro(ConfigLiga c) {
  final l = c.periodosSinCobro.where((p) => !p.terminado).toList();
  if (l.isEmpty) return 'Ninguno por ahora';
  return l.map((p) => p.titulo).join(' · ');
}

class PeriodosSinCobroScreen extends StatelessWidget {
  const PeriodosSinCobroScreen({super.key, required this.config, required this.equipos});
  final ConfigLiga config;
  final List<String> equipos;

  Future<void> _abrir(BuildContext context, [PeriodoSinCobro? p]) =>
      SubAjustes.abrir<bool>(context, _EditarPeriodoScreen(config: config, equipos: equipos, periodo: p));

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Meses y periodos sin cobro', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListenableBuilder(
        listenable: config,
        builder: (context, _) {
          final todos = config.periodosSinCobro;
          final vigentes = todos.where((x) => !x.terminado).toList();
          final pasados = todos.where((x) => x.terminado).toList();
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 40 + MediaQuery.paddingOf(context).bottom),
            children: [
              Text(
                'Elige meses en que no se cobra, o un periodo de fechas en que las clases no se cobran o se cobran con descuento. '
                'Rige desde que lo guardas; lo ya pagado no cambia.',
                style: TextStyle(fontSize: 14, height: 1.4, color: p.texto),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: vigentes.isEmpty
                    ? Container(
                        key: const ValueKey('vacio'),
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                        child: Column(
                          children: [
                            Icon(Icons.money_off_rounded, size: 36, color: p.marcaTexto),
                            const SizedBox(height: 8),
                            Text(
                              'No hay meses ni periodos sin cobro',
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Por ejemplo: diciembre no se cobra, o del 19/11 al 15/12 las clases se cobran al 50 %.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: p.textoSecundario),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(onPressed: () => _abrir(context), icon: const Icon(Icons.add_rounded), label: const Text('Agregar')),
                          ],
                        ),
                      )
                    : GrupoAjustes(
                        key: const ValueKey('lista'),
                        titulo: 'VIGENTES Y PRÓXIMOS',
                        filas: [
                          for (final x in vigentes)
                            FilaAjuste(
                              icono: x.porMes ? Icons.calendar_month_outlined : Icons.date_range_outlined,
                              titulo: x.titulo,
                              valor: '${x.detalle} · ${_alcance(x)}',
                              alTocar: () => _abrir(context, x),
                            ),
                          FilaAjuste(icono: Icons.add_rounded, titulo: 'Agregar mes o periodo', alTocar: () => _abrir(context)),
                        ],
                      ),
              ),
              if (pasados.isNotEmpty)
                GrupoAjustes(
                  titulo: 'YA TERMINARON',
                  pie: 'Quedan guardados como historial de cobros y no se pueden cambiar.',
                  filas: [for (final x in pasados.reversed) FilaAjuste(icono: Icons.history_rounded, titulo: x.titulo, valor: '${x.detalle} · ${_alcance(x)}')],
                ),
            ],
          );
        },
      ),
    );
  }
}

String _alcance(PeriodoSinCobro x) => x.equipos.isEmpty ? 'Toda la liga' : 'Solo ${x.equipos.join(', ')}';

class _EditarPeriodoScreen extends StatefulWidget {
  const _EditarPeriodoScreen({required this.config, required this.equipos, this.periodo});
  final ConfigLiga config;
  final List<String> equipos;
  final PeriodoSinCobro? periodo;

  @override
  State<_EditarPeriodoScreen> createState() => _EditarPeriodoScreenState();
}

class _EditarPeriodoScreenState extends State<_EditarPeriodoScreen> {
  PeriodoSinCobro? get _orig => widget.periodo;
  late bool _porMes = _orig?.porMes ?? true;
  late final Set<DateTime> _meses = {...?_orig?.meses};
  late DateTimeRange? _rango = _orig == null || _orig!.porMes ? null : DateTimeRange(start: _orig!.desde!, end: _orig!.hasta!);
  late bool _conPorcentaje = (_orig?.clasesPct ?? 0) > 0;
  late int _pct = (_orig?.clasesPct ?? 0) > 0 ? _orig!.clasesPct : 50;
  late bool _cuotaProporcional = _orig?.cuotaProporcional ?? true;
  late bool _todaLaLiga = _orig == null || _orig!.equipos.isEmpty;
  late final Set<String> _equipos = {...?_orig?.equipos};
  bool _guardando = false;

  DateTime get _hoy => Fechas.hoy();

  /// El mes actual y los 12 siguientes; un mes ya pasado de esta regla se muestra fijo.
  List<DateTime> get _opcionesMes => [
    for (final m in _orig?.meses ?? const <DateTime>[])
      if (m.year * 12 + m.month < _hoy.year * 12 + _hoy.month) m,
    for (var i = 0; i <= 12; i++) DateTime(_hoy.year, _hoy.month + i),
  ];

  bool _pasado(DateTime m) => m.year * 12 + m.month < _hoy.year * 12 + _hoy.month;

  int get _pctClases => _conPorcentaje ? _pct : 0;

  bool get _valido => (_porMes ? _meses.isNotEmpty : _rango != null) && (_todaLaLiga || _equipos.isNotEmpty);

  PeriodoSinCobro get _nuevo => PeriodoSinCobro(
    id: _orig?.id ?? '',
    porMes: _porMes,
    meses: _porMes ? (_meses.toList()..sort()) : const [],
    desde: _porMes ? null : _rango!.start,
    hasta: _porMes ? null : _rango!.end,
    clasesPct: _porMes ? 0 : _pctClases,
    cuotaProporcional: _porMes || _cuotaProporcional,
    equipos: _todaLaLiga ? const [] : (_equipos.toList()..sort()),
  );

  /// Qué pasa, con un ejemplo concreto.
  String get _ejemplo {
    final quien = _todaLaLiga ? 'nadie en la liga' : 'nadie en ${_equipos.join(', ')}';
    if (_porMes) {
      if (_meses.isEmpty) return 'Elige uno o más meses.';
      final t = _nuevo.titulo;
      return '$t: $quien paga la cuota mensual ni las clases sueltas, y se puede marcar Asistiré sin suscripción. '
          'Al suscribirse se ve "$t no se ${_meses.length == 1 ? 'cobra' : 'cobran'}".';
    }
    if (_rango == null) return 'Elige desde y hasta qué día.';
    final clases = _pctClases == 0 ? 'no se cobran' : 'se cobran al $_pctClases %';
    final cuota = _cuotaProporcional
        ? (_pctClases == 0
              ? 'La cuota mensual se cobra solo por los entrenamientos del mes fuera del periodo, como en un descanso proporcional.'
              : 'En la cuota mensual, cada entrenamiento del mes dentro del periodo cuenta al $_pctClases %.')
        : 'La cuota mensual se cobra entera.';
    return '${_nuevo.titulo} las clases sueltas $clases. $cuota';
  }

  Future<void> _elegirRango() async {
    final inicio = _rango?.start.isBefore(_hoy) == true ? _rango!.start : _hoy;
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(inicio.year, inicio.month - 2),
      lastDate: DateTime(_hoy.year + 1, _hoy.month, _hoy.day),
      initialDateRange: _rango,
      helpText: 'Periodo sin cobro',
    );
    if (r != null && mounted) {
      if (r.end.isBefore(_hoy)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El periodo tiene que terminar hoy o después.')));
        return;
      }
      setState(() => _rango = r);
    }
  }

  Future<void> _guardar({bool borrar = false}) async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    final otros = [
      for (final x in widget.config.periodosSinCobro)
        if (x.id != _orig?.id || _orig == null) x.aMapa(),
    ];
    try {
      await widget.config.guardarReglas({
        'periodosSinCobro': [...otros, if (!borrar) _nuevo.aMapa()],
      });
      m.showSnackBar(SnackBar(content: Text(borrar ? 'Eliminado. Desde ahora se cobra como siempre.' : 'Guardado. Rige desde ahora; lo ya pagado no cambia.')));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarBorrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Eliminar?'),
        content: const Text('Desde ahora se vuelve a cobrar como siempre. Lo que ya se pagó o se dejó de cobrar no cambia.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true && mounted) _guardar(borrar: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: Text(_orig == null ? 'Nuevo sin cobro' : 'Editar sin cobro', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, label: Text('Por mes'), icon: Icon(Icons.calendar_month_outlined)),
              ButtonSegment(value: false, label: Text('Por fechas'), icon: Icon(Icons.date_range_outlined)),
            ],
            selected: {_porMes},
            onSelectionChanged: _orig != null ? null : (x) => setState(() => _porMes = x.first),
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _porMes
                  ? KeyedSubtree(key: const ValueKey('mes'), child: _bloqueMeses(p))
                  : KeyedSubtree(key: const ValueKey('periodo'), child: _bloquePeriodo(p)),
            ),
          ),
          const SizedBox(height: 18),
          const _Titulo('¿A QUIÉN APLICA?'),
          _Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Toda la liga', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(_todaLaLiga ? 'Todos los equipos' : 'Solo los equipos que elijas'),
                  value: _todaLaLiga,
                  onChanged: (v) => setState(() => _todaLaLiga = v),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _todaLaLiga
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: widget.equipos.isEmpty
                              ? Text('No se pudieron cargar los equipos.', style: TextStyle(color: p.textoSecundario))
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final e in {...widget.equipos, ..._equipos})
                                      FilterChip(
                                        label: Text(e),
                                        selected: _equipos.contains(e),
                                        onSelected: (v) => setState(() => v ? _equipos.add(e) : _equipos.remove(e)),
                                      ),
                                  ],
                                ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(_ejemplo),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
              child: Text(_ejemplo, style: TextStyle(height: 1.4, color: p.sobreSuave)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _valido && !_guardando ? _guardar : null, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
          if (_orig != null) ...[const SizedBox(height: 4), TextButton(onPressed: _guardando ? null : _confirmarBorrar, child: const Text('Eliminar'))],
        ],
      ),
    );
  }

  Widget _bloqueMeses(PivotPaleta p) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Titulo('MESES QUE NO SE COBRAN'),
      _Tarjeta(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _opcionesMes)
              FilterChip(
                label: Text(m.year == _hoy.year ? Fechas.mesNombre(m) : Fechas.mesAnio(m)),
                selected: _meses.contains(m),
                // Un mes que ya pasó queda fijo: cambiarlo cambiaría lo que se debía.
                onSelected: _pasado(m) ? null : (v) => setState(() => v ? _meses.add(m) : _meses.remove(m)),
              ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text('Ese mes no se cobra la cuota mensual ni las clases sueltas.', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
    ],
  );

  Widget _bloquePeriodo(PivotPaleta p) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Titulo('FECHAS'),
      _Tarjeta(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.date_range_outlined, color: p.marcaTexto),
          title: Text(
            _rango == null ? 'Elegir fechas' : 'Del ${PeriodoSinCobro.fechaCorta(_rango!.start)} al ${PeriodoSinCobro.fechaCorta(_rango!.end)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(_rango == null ? 'Desde y hasta qué día (incluidos)' : '${Fechas.diasEntre(_rango!.start, _rango!.end) + 1} días'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _elegirRango,
        ),
      ),
      const SizedBox(height: 18),
      const _Titulo('CLASES SUELTAS'),
      _Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('No se cobran')),
                ButtonSegment(value: true, label: Text('Con descuento')),
              ],
              selected: {_conPorcentaje},
              onSelectionChanged: (x) => setState(() => _conPorcentaje = x.first),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_conPorcentaje
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SelectorNumero(
                        valor: _pct,
                        min: 5,
                        max: 95,
                        paso: 5,
                        etiqueta: '% del precio',
                        alCambiar: (v) => setState(() => _pct = v.toInt()),
                      ),
                    ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const _Titulo('CUOTA MENSUAL'),
      _Tarjeta(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Proporcional', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            _cuotaProporcional
                ? 'Baja según los entrenamientos del mes que caen en el periodo, como en un descanso proporcional.'
                : 'Se cobra entera aunque haya entrenamientos en el periodo.',
          ),
          value: _cuotaProporcional,
          onChanged: (v) => setState(() => _cuotaProporcional = v),
        ),
      ),
    ],
  );
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      t,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.pivot.textoSecundario),
    ),
  );
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: context.pivot.tarjeta,
    borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );
}
