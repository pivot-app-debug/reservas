import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import 'editores_liga.dart' show plataLiga;

/// Cómo paga cada equipo (Victor, 2026-11-15): por mes, por clase, elige,
/// según su equipamiento o sin cobro, y precio propio opcional.
const modosCobro = <String, (String, String)>{
  'mes': ('Por mes', 'Paga la mensualidad. Puede tener clases de gracia.'),
  'clase': ('Por clase', 'Reserva y paga cada clase.'),
  'elige': ('Elige', 'Cada persona elige pagar por clase o por mes.'),
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
    final p = context.pivot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            valor ? 'Precio propio de ${widget.equipo}' : 'Igual que la liga (${plataLiga(deLaLiga)})',
            style: TextStyle(color: p.textoSecundario),
          ),
          value: valor,
          onChanged: alCambiar,
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
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(labelText: 'Precio', prefixText: '\$ '),
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
        title: Text('Cobro de ${widget.equipo}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('Cómo paga ${widget.equipo}. Las personas exentas no pagan, sea cual sea el modo.', style: TextStyle(fontSize: 15, height: 1.4, color: p.texto)),
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
        ],
      ),
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
