import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import 'editores_liga.dart' show plataLiga;
import '../core/moneda.dart';
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

class _ReservasReglasScreenState extends State<ReservasReglasScreen> {
  late int _visibles = widget.config.reservaClasesVisibles,
      _cierra = widget.config.reservaCierraHoras,
      _cupon = widget.config.cuponCancelarMin,
      _sinAprobar = widget.config.sinAprobarHoras;
  bool _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await widget.config.guardarReglas({
        'reservaClasesVisibles': _visibles,
        'reservaCierraHoras': _cierra,
        'cuponCancelarMin': _cupon,
        'sinAprobarHoras': _sinAprobar,
      });
      m.showSnackBar(const SnackBar(content: Text('Guardado. Rige desde ahora.')));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  static String _horas(int h) => h == 0 ? 'Hasta que empieza' : '$h ${h == 1 ? 'hora' : 'horas'} antes';
  static String _min(int m) => m == 0 ? 'Siempre' : (m % 60 == 0 ? '${m ~/ 60} ${m == 60 ? 'hora' : 'horas'} antes' : '$m minutos antes');

  Widget _bloque(String titulo, String texto, List<int> opciones, int valor, String Function(int) etiqueta, ValueChanged<int> alElegir) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
            ),
            const SizedBox(height: 2),
            Text(texto, style: TextStyle(fontSize: 13, height: 1.35, color: p.textoSecundario)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in {...opciones, valor}.toList()..sort())
                  ChoiceChip(label: Text(etiqueta(o)), selected: valor == o, onSelected: (_) => setState(() => alElegir(o))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final cambio = _visibles != c.reservaClasesVisibles || _cierra != c.reservaCierraHoras || _cupon != c.cuponCancelarMin || _sinAprobar != c.sinAprobarHoras;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Reservas', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          _bloque('Clases para reservar', 'Cuántas de las próximas clases se ven al reservar.', [3, 4, 6, 8, 10], _visibles, (n) => '$n', (n) => _visibles = n),
          _bloque('Cierre de reservas', 'Hasta cuándo se puede reservar una clase.', [0, 1, 2, 3, 6, 12, 24], _cierra, _horas, (n) => _cierra = n),
          _bloque(
            'Clase gratis al cancelar',
            'Quien reservó con su clase gratis la recupera si cancela con esta anticipación.',
            [0, 30, 60, 120, 180],
            _cupon,
            _min,
            (n) => _cupon = n,
          ),
          _bloque(
            'Reserva sin aprobar',
            'Si el pago no se aprobó, la reserva se cierra este tiempo después de la clase. Si la persona vino, queda la deuda.',
            [1, 2, 4, 12, 24],
            _sinAprobar,
            (h) => '$h ${h == 1 ? 'hora' : 'horas'} después',
            (n) => _sinAprobar = n,
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: cambio && !_guardando ? _guardar : null, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
        ],
      ),
    );
  }
}

/// Estados (Victor, 2026-11-15): qué hace cada uno. Lesionadx siempre exime
/// de la cuota; Ausente nunca congela. Los nuevos se pueden apagar.
const estadosEditables = <String, (IconData, String)>{
  'Lesionadx': (Icons.healing_rounded, 'Lesión. Necesita aprobación de un Pivot.'),
  'De viaje': (Icons.flight_takeoff_rounded, 'Con fecha de salida y de regreso.'),
  'Enfermedad': (Icons.sick_outlined, 'El equipo solo ve "Fuera por un tiempo".'),
  'Situación personal': (Icons.support_outlined, 'Situación personal o fuerza mayor. El equipo no ve el motivo.'),
  'Otro': (Icons.more_horiz_rounded, 'Otro motivo. El equipo no ve el motivo.'),
};
const _estadosNuevos = ['Enfermedad', 'Situación personal', 'Otro'];

Map<String, dynamic> cfgEstado(ConfigLiga c, String e) {
  const base = {
    'Lesionadx': {'congela': true, 'exentaCuota': true},
    'De viaje': {'congela': true, 'exentaCuota': false},
    'Enfermedad': {'activo': true, 'congela': true, 'exentaCuota': true},
    'Situación personal': {'activo': true, 'congela': true, 'exentaCuota': true},
    'Otro': {'activo': true, 'congela': false, 'exentaCuota': false},
  };
  final x = (c.reglas['estados'] as Map?)?[e];
  return {...?base[e], if (x is Map) ...Map<String, dynamic>.from(x)};
}

String textoEstado(ConfigLiga c, String e) {
  final x = cfgEstado(c, e);
  if (x['activo'] == false) return 'Apagado';
  return [x['congela'] == true ? 'Pausado en su equipo' : 'Sigue la regla de su equipo', x['exentaCuota'] == true ? 'no paga cuota' : 'paga cuota'].join(' · ');
}

class EstadoScreen extends StatefulWidget {
  const EstadoScreen({super.key, required this.config, required this.estado});
  final ConfigLiga config;
  final String estado;

  @override
  State<EstadoScreen> createState() => _EstadoScreenState();
}

class _EstadoScreenState extends State<EstadoScreen> {
  late final Map<String, dynamic> _o = cfgEstado(widget.config, widget.estado);
  late bool _activo = _o['activo'] != false, _congela = _o['congela'] == true, _exenta = _o['exentaCuota'] == true;
  bool _guardando = false;

  bool get _nuevo => _estadosNuevos.contains(widget.estado);

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await widget.config.guardarReglas({
        'estados': {
          widget.estado: {'congela': _congela, if (_nuevo) 'exentaCuota': _exenta, if (_nuevo) 'activo': _activo},
        },
      });
      m.showSnackBar(const SnackBar(content: Text('Guardado. Rige desde ahora.')));
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
    final cambio = _activo != (_o['activo'] != false) || _congela != (_o['congela'] == true) || _exenta != (_o['exentaCuota'] == true);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: Text(widget.estado, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(
            '${estadosEditables[widget.estado]?.$2 ?? ''} Al venir a entrenar (a horario o tarde), la persona vuelve a Activx.',
            style: TextStyle(fontSize: 15, height: 1.4, color: p.texto),
          ),
          const SizedBox(height: 16),
          Material(
            color: p.tarjeta,
            borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  if (_nuevo)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Disponible', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Las personas pueden elegirlo en Asistencia anticipada y un Pivot en su ficha.'),
                      value: _activo,
                      onChanged: (v) => setState(() => _activo = v),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pausado', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Mientras dure, no sube ni baja de equipo por asistencia.'),
                    value: _congela,
                    onChanged: (v) => setState(() => _congela = v),
                  ),
                  if (_nuevo)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('No paga cuota', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Mientras dure, queda exentx de la cuota.'),
                      value: _exenta,
                      onChanged: (v) => setState(() => _exenta = v),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Rige para quienes entren a este estado desde ahora y para el próximo cálculo de equipos.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: p.textoSecundario),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: cambio && !_guardando ? _guardar : null, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
        ],
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
