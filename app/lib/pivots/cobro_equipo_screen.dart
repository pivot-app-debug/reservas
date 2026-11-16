import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import 'editores_liga.dart' show plataLiga, numeroLiga;
import '../core/moneda.dart';
import '../core/selector_plazo.dart';
import '../equipo/equipo_modelos.dart';
import '../equipo/equipo_repo.dart';
import '../eventos/widgets_comunes.dart' show AvatarPersona;

/// Cómo paga cada equipo (Victor, 2026-11-15): por mes, por clase, elige,
/// según su equipamiento o sin cobro, y precio propio opcional.
const modosCobro = <String, (String, String)>{
  'mes': ('Por mes', 'Paga la mensualidad. Puede tener clases de gracia.'),
  'clase': ('Por clase', 'Reserva y paga cada clase.'),
  'elige': ('Por clase o por mes', 'Cada persona elige pagar por clase o por mes.'),
  'segun_equipamiento': ('Según su equipamiento', 'Con equipamiento del club, solo por clase. Con equipamiento propio, elige por clase o por mes.'),
  'sin_cobro': ('Sin cobro', 'No paga: solo marca Asistiré.'),
};

String textoCobroEquipo(ConfigLiga c, String equipo) {
  final x = c.cobroEquipo(equipo);
  final m = modosCobro['${x['modo']}']?.$1 ?? 'Según su equipamiento';
  final precios = [
    if (x['precioMensual'] != null) 'mensualidad ${plataLiga(x['precioMensual'] as num)}',
    if (x['precioClase'] != null) 'clase ${plataLiga(x['precioClase'] as num)}',
  ];
  return precios.isEmpty ? m : '$m · ${precios.join(', ')}';
}

class CobroEquipoScreen extends StatefulWidget {
  const CobroEquipoScreen({super.key, required this.config, required this.equipo});
  final ConfigLiga config;
  final String equipo;

  @override
  State<CobroEquipoScreen> createState() => _CobroEquipoScreenState();
}

class _CobroEquipoScreenState extends State<CobroEquipoScreen> {
  late final Map<String, dynamic> _orig = widget.config.cobroEquipo(widget.equipo);
  late String _modo = '${_orig['modo']}';
  late bool _propioMes = _orig['precioMensual'] != null, _propioClase = _orig['precioClase'] != null;
  late final _mes = TextEditingController(text: _propioMes ? '${_orig['precioMensual']}' : '');
  late final _clase = TextEditingController(text: _propioClase ? '${_orig['precioClase']}' : '');
  bool _guardando = false;
  late final EquipoRepo _equipo = EquipoRepo.de(widget.config.sesion)..cargar();
  final _cambiando = <String>{};

  /// Pasa a pagar cuota a alguien de la lista de quienes no pagan.
  Future<void> _cobrarA(Integrante x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿${x.nombreMostrar} paga cuota?'),
        content: const Text('Desde ahora se le pedirá la cuota como al resto del equipo.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Paga cuota')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    setState(() => _cambiando.add(x.username));
    try {
      await _equipo.cambiarPagaCuota(x, true);
      m.showSnackBar(SnackBar(content: Text('${x.nombreMostrar} ahora paga cuota')));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    } finally {
      if (mounted) setState(() => _cambiando.remove(x.username));
    }
  }

  @override
  void dispose() {
    _mes.dispose();
    _clase.dispose();
    super.dispose();
  }

  num? _n(TextEditingController t) => num.tryParse(t.text.replaceAll(',', '.'));

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await widget.config.guardarReglas({
        'cobroEquipos': {
          widget.equipo: {'modo': _modo, 'precioMensual': _propioMes ? _n(_mes) : null, 'precioClase': _propioClase ? _n(_clase) : null},
        },
      });
      m.showSnackBar(const SnackBar(content: Text('Guardado. Rige para los pagos desde ahora.')));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _precio(String titulo, bool valor, ValueChanged<bool> alCambiar, TextEditingController t, num? deLaLiga) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: DropdownButtonFormField<bool>(
            initialValue: valor,
            decoration: InputDecoration(labelText: titulo),
            items: [
              DropdownMenuItem(value: false, child: Text('Igual que en la liga (${plataLiga(deLaLiga)})')),
              const DropdownMenuItem(value: true, child: Text('Personalizado')),
            ],
            onChanged: (v) => alCambiar(v ?? false),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: valor
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: t,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: InputDecoration(
                      labelText: 'Monto',
                      prefixText: '${Moneda.s} ',
                      errorText: _n(t) == null && t.text.isNotEmpty ? 'Escribe un monto' : null,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final c = widget.config;
    final cobra = _modo != 'sin_cobro';
    final valido = (!_propioMes || _n(_mes) != null) && (!_propioClase || _n(_clase) != null);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Cobros', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('A las personas exentas de pago o sin cobro de cuota no se les exigirá pagar.', style: TextStyle(fontSize: 15, height: 1.4, color: p.texto)),
          const SizedBox(height: 16),
          for (final e in modosCobro.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: _modo == e.key ? p.suave : p.tarjeta,
                borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                child: InkWell(
                  borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                  onTap: () => setState(() => _modo = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                      border: Border.all(color: _modo == e.key ? p.marca : p.tarjetaBorde, width: _modo == e.key ? 1.6 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.value.$1,
                          style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                        ),
                        const SizedBox(height: 2),
                        Text(e.value.$2, style: TextStyle(fontSize: 13, height: 1.35, color: p.textoSecundario)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !cobra
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Material(
                      color: p.tarjeta,
                      borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_modo != 'clase') _precio('Mensualidad', _propioMes, (v) => setState(() => _propioMes = v), _mes, c.precioMensual),
                            if (_modo != 'mes') _precio('Valor por clase', _propioClase, (v) => setState(() => _propioClase = v), _clase, c.precioPorClase),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            'Un cambio rige para los pagos que se hagan desde ahora; los anteriores no cambian. Quien viene sin reserva a una clase que debía pagar queda con deuda.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: p.textoSecundario),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: !_guardando && valido ? _guardar : null, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
          const SizedBox(height: 28),
          _noPagan(context),
        ],
      ),
    );
  }

  /// Quienes del equipo no pagan cuota (exentos), para revisarlos en un
  /// solo lugar y pasarlos a pagar si algo está mal (Victor, 2026-11-16).
  Widget _noPagan(BuildContext context) {
    final p = context.pivot;
    return ListenableBuilder(
      listenable: _equipo,
      builder: (context, _) {
        final l = [
          for (final x in _equipo.personas ?? const <Integrante>[])
            if (x.categoria == widget.equipo && x.exentaCuota) x,
        ]..sort((a, b) => a.nombreMostrar.toLowerCase().compareTo(b.nombreMostrar.toLowerCase()));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                'NO PAGAN CUOTA',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
              ),
            ),
            Material(
              color: p.tarjeta,
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _equipo.personas == null
                    ? const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator(minHeight: 2))
                    : l.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Todo el equipo paga cuota.', style: TextStyle(color: p.textoSecundario)),
                      )
                    : Column(
                        children: [
                          for (final x in l)
                            ListTile(
                              leading: AvatarPersona(nombre: x.nombreMostrar, foto: x.foto, tamano: 36),
                              title: Text(x.nombreMostrar, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(x.estado.isEmpty || x.estado == 'Activx' ? 'Sin cobro de cuota' : 'Sin cobro de cuota · ${x.estado}'),
                              trailing: _cambiando.contains(x.username)
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : TextButton(onPressed: () => _cobrarA(x), child: const Text('Cobrar')),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Reglas de reservas que antes estaban fijas (Victor, 2026-11-15).
class ReservasReglasScreen extends StatefulWidget {
  const ReservasReglasScreen({super.key, required this.config});
  final ConfigLiga config;

  @override
  State<ReservasReglasScreen> createState() => _ReservasReglasScreenState();
}

/// Modos de cobro en los que se reserva y paga cada clase.
const _modosPorClase = {'clase', 'elige', 'segun_equipamiento'};

/// Nombres de los equipos de la liga (para decir a quién afecta algo).
Future<List<String>> equiposDeLaLiga(ConfigLiga c) async {
  final r = await c.sesion.api.get('getTiers', {'adminToken': c.sesion.adminToken});
  return [for (final t in (r['tiers'] as List? ?? const [])) '${(t as Map)['nombre']}'];
}

/// Reservas por clase (Victor, 2026-11-16): una sola pantalla, arriba a qué
/// equipos afecta y debajo cada regla con su interruptor y un ejemplo.
class _ReservasReglasScreenState extends State<ReservasReglasScreen> {
  ConfigLiga get c => widget.config;
  late int _visibles = c.reservaClasesVisibles, _cierra = c.reservaCierraHoras, _sinAprobar = c.sinAprobarHoras;
  late bool _conCierre = c.reservaCierraHoras > 0;
  List<String>? _equipos;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    equiposDeLaLiga(c).then(
      (l) {
        if (mounted) setState(() => _equipos = l);
      },
      onError: (_) {
        if (mounted) setState(() => _equipos = const []);
      },
    );
  }

  int get _cierreFinal => _conCierre ? (_cierra == 0 ? 2 : _cierra) : 0;

  bool get _cambio => _visibles != c.reservaClasesVisibles || _cierreFinal != c.reservaCierraHoras || _sinAprobar != c.sinAprobarHoras;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await c.guardarReglas({'reservaClasesVisibles': _visibles, 'reservaCierraHoras': _cierreFinal, 'sinAprobarHoras': _sinAprobar});
      m.showSnackBar(const SnackBar(content: Text('Guardado. Rige desde ahora.')));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// "19:00" menos [h] horas, con el día si cambia.
  static String _antesDe19(int h) {
    final t = DateTime(2026, 1, 5, 19).subtract(Duration(hours: h));
    final hora = '${t.hour.toString().padLeft(2, '0')}:00';
    return t.day == 5 ? 'el lunes a las $hora' : (t.day == 4 ? 'el domingo a las $hora' : 'a las $hora de días antes');
  }

  static String _despuesDe21(int h) {
    final t = DateTime(2026, 1, 5, 21).add(Duration(hours: h));
    final hora = '${t.hour.toString().padLeft(2, '0')}:00';
    return t.day == 5 ? 'el lunes a las $hora' : (t.day == 6 ? 'el martes a las $hora' : 'el miércoles a las $hora');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final eq = _equipos;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Reservas por clase', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('Para quien reserva y paga cada clase. Quien paga por mes no reserva.', style: TextStyle(fontSize: 15, height: 1.4, color: p.texto)),
          const SizedBox(height: 14),
          _SeccionRegla(
            icono: Icons.groups_outlined,
            titulo: 'A qué equipos afecta',
            ejemplo: 'Se cambia en Cobros de cada equipo.',
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              alignment: Alignment.topCenter,
              child: eq == null
                  ? const LinearProgressIndicator(minHeight: 2)
                  : Column(
                      children: [
                        for (final e in eq)
                          Builder(
                            builder: (context) {
                              final modo = '${c.cobroEquipo(e)['modo']}';
                              final afecta = _modosPorClase.contains(modo);
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: Icon(
                                  afecta ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                                  color: afecta ? p.marcaTexto : p.textoSecundario,
                                ),
                                title: Text(e, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  afecta ? 'Reserva por clase (${modosCobro[modo]?.$1.toLowerCase()})' : 'No reserva: ${modosCobro[modo]?.$1.toLowerCase()}',
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => CobroEquipoScreen(config: c, equipo: e),
                                    ),
                                  );
                                  if (mounted) setState(() {});
                                },
                              );
                            },
                          ),
                      ],
                    ),
            ),
          ),
          _SeccionRegla(
            icono: Icons.event_available_outlined,
            titulo: 'Clases que se pueden reservar',
            ejemplo:
                'Al reservar se ven las próximas $_visibles clases. Con dos clases por semana, se puede reservar con unas ${(_visibles / 2).ceil()} semanas de anticipación.',
            child: SelectorNumero(
              valor: _visibles,
              min: 1,
              max: 20,
              etiqueta: _visibles == 1 ? 'clase' : 'clases',
              alCambiar: (v) => setState(() => _visibles = v.toInt()),
            ),
          ),
          _SeccionRegla(
            icono: Icons.lock_clock_outlined,
            titulo: 'Cierre de reservas',
            interruptor: _conCierre,
            alCambiar: (v) => setState(() => (_conCierre = v, _cierra = v && _cierra == 0 ? 2 : _cierra)),
            ejemplo: _conCierre
                ? 'Para una clase del lunes a las 19:00, se puede reservar hasta ${_antesDe19(_cierreFinal)}.'
                : 'Apagado: se puede reservar hasta que empieza la clase.',
            child: _conCierre
                ? SelectorNumero(
                    valor: _cierreFinal,
                    min: 1,
                    max: 48,
                    etiqueta: _cierreFinal == 1 ? 'hora antes' : 'horas antes',
                    alCambiar: (v) => setState(() => _cierra = v.toInt()),
                  )
                : null,
          ),
          _SeccionRegla(
            icono: Icons.hourglass_bottom_rounded,
            titulo: 'Reserva sin aprobar',
            ejemplo:
                'Si alguien reserva la clase del lunes de 19:00 a 21:00 y un Pivot no aprueba su pago, la reserva se cierra ${_despuesDe21(_sinAprobar)}. '
                'Si vino a la clase, queda con deuda; si no vino, solo se cancela.',
            child: SelectorNumero(
              valor: _sinAprobar,
              min: 1,
              max: 72,
              etiqueta: _sinAprobar == 1 ? 'hora después de la clase' : 'horas después de la clase',
              alCambiar: (v) => setState(() => _sinAprobar = v.toInt()),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _cambio && !_guardando ? _guardar : null, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
        ],
      ),
    );
  }
}

/// Clase gratis de bienvenida (Victor, 2026-11-16): sección propia, con
/// interruptores para darla y para que vuelva al cancelar.
class ClaseBienvenidaScreen extends StatefulWidget {
  const ClaseBienvenidaScreen({super.key, required this.config});
  final ConfigLiga config;

  @override
  State<ClaseBienvenidaScreen> createState() => _ClaseBienvenidaScreenState();
}

class _ClaseBienvenidaScreenState extends State<ClaseBienvenidaScreen> {
  ConfigLiga get c => widget.config;
  late bool _activa = c.cuponBienvenida, _vuelve = c.cuponVuelve;
  late int _min = c.cuponCancelarMin;
  bool _guardando = false;

  bool get _cambio => _activa != c.cuponBienvenida || _vuelve != c.cuponVuelve || _min != c.cuponCancelarMin;

  static String _anticipacion(int m) => m == 0
      ? 'en cualquier momento antes de la clase'
      : (m % 60 == 0 ? 'con ${m ~/ 60} ${m == 60 ? 'hora' : 'horas'} de anticipación' : 'con $m minutos de anticipación');

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await c.guardarReglas({'cuponBienvenida': _activa, 'cuponVuelve': _vuelve, 'cuponCancelarMin': _min});
      m.showSnackBar(const SnackBar(content: Text('Guardado. Rige desde ahora; las clases gratis ya dadas no cambian.')));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
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
        title: const Text('Clase gratis de bienvenida', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('Una clase sin pagar para quien recién se inscribe, para que pruebe.', style: TextStyle(fontSize: 15, height: 1.4, color: p.texto)),
          const SizedBox(height: 14),
          _SeccionRegla(
            icono: Icons.local_activity_outlined,
            titulo: 'Dar clase gratis al inscribirse',
            interruptor: _activa,
            alCambiar: (v) => setState(() => _activa = v),
            ejemplo: _activa
                ? 'Quien se inscribe puede reservar su primera clase sin pagar.'
                : 'Apagado: quien se inscribe paga desde la primera clase. Las clases gratis ya dadas se pueden seguir usando.',
          ),
          if (_activa)
            _SeccionRegla(
              icono: Icons.undo_rounded,
              titulo: 'Vuelve si cancela',
              interruptor: _vuelve,
              alCambiar: (v) => setState(() => _vuelve = v),
              ejemplo: _vuelve
                  ? 'Si reservó con su clase gratis y cancela ${_anticipacion(_min)}, la recupera para otra clase.'
                  : 'Apagado: si cancela, pierde la clase gratis.',
              child: _vuelve
                  ? SelectorNumero(
                      valor: _min ~/ 60,
                      min: 0,
                      max: 24,
                      etiqueta: _min < 60 ? 'horas: sin mínimo' : (_min < 120 ? 'hora antes' : 'horas antes'),
                      alCambiar: (v) => setState(() => _min = v.toInt() * 60),
                    )
                  : null,
            ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _cambio && !_guardando ? _guardar : null, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
        ],
      ),
    );
  }
}

/// Una regla en tarjeta: ícono y título (con interruptor si se puede
/// apagar), su control y un ejemplo que cambia en vivo.
class _SeccionRegla extends StatelessWidget {
  const _SeccionRegla({required this.icono, required this.titulo, required this.ejemplo, this.child, this.interruptor, this.alCambiar});
  final IconData icono;
  final String titulo, ejemplo;
  final Widget? child;
  final bool? interruptor;
  final ValueChanged<bool>? alCambiar;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icono, color: p.marcaTexto),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titulo,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: p.texto),
                    ),
                  ),
                  if (interruptor != null) Switch(value: interruptor!, onChanged: alCambiar) else const SizedBox(height: 40),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: child == null ? const SizedBox(width: double.infinity) : Padding(padding: const EdgeInsets.only(top: 6), child: child),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(ejemplo),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: p.fondo, borderRadius: BorderRadius.circular(PivotRadios.contador)),
                  child: Text(ejemplo, style: TextStyle(fontSize: 13, height: 1.4, color: p.textoSecundario)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estados (Victor, 2026-11-15): qué hace cada uno. Lesionadx siempre exime
/// de la cuota; Ausente nunca congela. Los nuevos se pueden apagar.
const estadosEditables = <String, (IconData, String)>{
  'Lesionadx': (Icons.healing_rounded, 'Lesión. Lesionadx siempre deja de pagar la cuota mientras dure.'),
  'De viaje': (Icons.flight_takeoff_rounded, 'Con fecha de salida y de regreso.'),
  'Enfermedad': (Icons.sick_outlined, 'El equipo solo ve "Fuera por un tiempo"; el motivo solo lo ven los Pivots.'),
  'Situación personal': (Icons.support_outlined, 'Situación personal o fuerza mayor. El equipo no ve el motivo.'),
  'Otro': (Icons.more_horiz_rounded, 'Otro motivo. El equipo no ve el motivo.'),
};
const _estadosNuevos = ['Enfermedad', 'Situación personal', 'Otro'];

Map<String, dynamic> cfgEstado(ConfigLiga c, String e) {
  const base = {
    'Lesionadx': {'congela': true, 'exentaCuota': true, 'aprobacion': true},
    'De viaje': {'congela': true, 'exentaCuota': false, 'aprobacion': false},
    'Enfermedad': {'activo': true, 'congela': true, 'exentaCuota': true, 'aprobacion': true},
    'Situación personal': {'activo': true, 'congela': true, 'exentaCuota': true, 'aprobacion': true},
    'Otro': {'activo': true, 'congela': false, 'exentaCuota': false, 'aprobacion': true},
  };
  final x = (c.reglas['estados'] as Map?)?[e];
  return {...?base[e], if (x is Map) ...Map<String, dynamic>.from(x)};
}

String textoEstado(ConfigLiga c, String e) {
  final x = cfgEstado(c, e);
  if (x['activo'] == false) return 'Apagado';
  return [
    x['congela'] == true ? 'Pausado' : 'Sigue la regla de su equipo',
    x['exentaCuota'] == true ? 'no paga cuota' : 'paga cuota',
    if (x['aprobacion'] == true) 'lo aprueba un Pivot',
  ].join(' · ');
}

/// Estados en una sola pantalla (Victor, 2026-11-16): cada uno con su
/// interruptor y sus opciones al desplegarlo; se guarda al tocar.
class EstadosScreen extends StatefulWidget {
  const EstadosScreen({super.key, required this.config});
  final ConfigLiga config;

  @override
  State<EstadosScreen> createState() => _EstadosScreenState();
}

class _EstadosScreenState extends State<EstadosScreen> {
  ConfigLiga get c => widget.config;
  final _abiertos = <String>{};
  final _local = <String, Map<String, dynamic>>{};

  Map<String, dynamic> _cfg(String e) => {...cfgEstado(c, e), ...?_local[e]};

  Future<void> _cambiar(String e, String k, bool v) async {
    setState(() => _local[e] = {...?_local[e], k: v});
    final m = ScaffoldMessenger.of(context);
    try {
      await c.guardarReglas({
        'estados': {
          e: {k: v},
        },
      });
    } catch (err) {
      m.showSnackBar(SnackBar(content: Text(err is ApiException ? err.message : 'No se pudo guardar. Revisa tu conexión.')));
    }
    if (mounted) setState(() => _local[e]?.remove(k));
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
        title: const Text('Estados', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            Text(
              'Qué pasa cuando alguien no puede venir por un tiempo. Al venir a entrenar (a horario o tarde), vuelve a Activx.',
              style: TextStyle(fontSize: 15, height: 1.4, color: p.texto),
            ),
            const SizedBox(height: 14),
            for (final e in estadosEditables.entries) _tarjeta(context, e.key, e.value.$1, e.value.$2),
            const SizedBox(height: 4),
            Material(
              color: p.tarjeta,
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(Icons.hourglass_empty_rounded, color: p.marcaTexto),
                title: const Text('Inactividad', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Pasa a Inactivx tras ${ConfigLiga.diasInactividad} días sin venir a ningún evento'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => numeroLiga(context, c, 'Pasa a Inactivx después de', 'inactividadDias', ConfigLiga.diasInactividad, 7, 365, 'días sin venir'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Un cambio rige para quienes entren a un estado desde ahora y para el próximo cálculo de equipos.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: p.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(BuildContext context, String e, IconData icono, String ayuda) {
    final p = context.pivot;
    final x = _cfg(e);
    final nuevo = _estadosNuevos.contains(e);
    final activo = x['activo'] != false;
    final abierto = _abiertos.contains(e) && activo;
    Widget opcion(String k, String titulo, String texto) => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(texto),
      value: x[k] == true,
      onChanged: (v) => _cambiar(e, k, v),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              leading: Icon(icono, color: activo ? p.marcaTexto : p.textoSecundario),
              title: Text(e, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(activo ? textoEstado(c, e) : 'Apagado: nadie puede elegirlo'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (nuevo) Switch(value: activo, onChanged: (v) => _cambiar(e, 'activo', v)),
                  if (activo)
                    AnimatedRotation(turns: abierto ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: const Icon(Icons.expand_more_rounded)),
                ],
              ),
              onTap: activo ? () => setState(() => abierto ? _abiertos.remove(e) : _abiertos.add(e)) : null,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !abierto
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ayuda, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                          const SizedBox(height: 4),
                          opcion('congela', 'Pausado', 'Mientras dure, no sube ni baja de equipo por asistencia.'),
                          if (nuevo) opcion('exentaCuota', 'No paga cuota', 'Mientras dure, no se le cobra la cuota.'),
                          if (e != 'De viaje') opcion('aprobacion', 'Lo aprueba un Pivot', 'El pedido llega a Notificaciones y el estado cambia al aprobarlo.'),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tipos de evento que agrega la liga (Victor, 2026-11-15). Los de siempre
/// (Entrenamiento, Partido, Evento, Otro…) no se quitan.
class TiposEventoScreen extends StatefulWidget {
  const TiposEventoScreen({super.key, required this.config});
  final ConfigLiga config;

  @override
  State<TiposEventoScreen> createState() => _TiposEventoScreenState();
}

class _TiposEventoScreenState extends State<TiposEventoScreen> {
  static const _base = ['Entrenamiento', 'Partido', 'Torneo', 'Asamblea', 'Evento social', 'Evento', 'Otro'];
  late List<String> _extra = [...widget.config.tiposEventoExtra];
  final _nuevo = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nuevo.dispose();
    super.dispose();
  }

  void _agregar() {
    final t = _nuevo.text.trim();
    if (t.isEmpty || _base.contains(t) || _extra.contains(t)) return;
    setState(() {
      _extra = [..._extra, t];
      _nuevo.clear();
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await widget.config.guardarReglas({'tiposEventoExtra': _extra});
      m.showSnackBar(const SnackBar(content: Text('Guardado.')));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final cambio = _extra.join('|') != widget.config.tiposEventoExtra.join('|');
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Tipos de evento', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(
            'Se eligen al crear un evento o un lugar. Qué tipos cuentan como clase se elige en Requisitos de cada equipo.',
            style: TextStyle(fontSize: 15, height: 1.4, color: p.texto),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _base) Chip(label: Text(t)),
              for (final t in _extra) InputChip(label: Text(t), onDeleted: () => setState(() => _extra = [..._extra]..remove(t))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nuevo,
                  maxLength: 30,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nuevo tipo (ej. Clínica)'),
                  onSubmitted: (_) => _agregar(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: _agregar, icon: const Icon(Icons.add_rounded)),
            ],
          ),
          Text('Quitar un tipo no cambia los eventos que ya lo usan.', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
          const SizedBox(height: 20),
          FilledButton(onPressed: cambio && !_guardando ? _guardar : null, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
        ],
      ),
    );
  }
}
