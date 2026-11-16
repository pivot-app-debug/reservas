import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import 'editores_liga.dart' show plataLiga;
import '../core/moneda.dart';

/// "a" y "b" / "a, b y c".
String _unir(List<String> p) => p.length > 1 ? '${p.sublist(0, p.length - 1).join(', ')} y ${p.last}' : (p.isEmpty ? '' : p.first);

/// Qué recibe quien paga a tiempo, en una frase ("un punto extra y una clase gratis").
String textoRecompensa(Map<String, dynamic> r) {
  final pts = (r['puntos'] as num?)?.toInt() ?? 0, saldo = (r['saldo'] as num?) ?? 0;
  return _unir([
    if (pts > 0) pts == 1 ? 'un punto extra' : '$pts puntos extra',
    if (r['claseGratis'] == true) 'una clase gratis',
    if (saldo > 0) '${plataLiga(saldo)} de saldo a favor',
  ]);
}

/// Resumen para la fila de Reglas.
String resumenRecompensa(ConfigLiga c) {
  final r = c.recompensaPago, t = textoRecompensa(r);
  if (r['activa'] == false || t.isEmpty) return 'Sin recompensa';
  return 'Quien paga hasta el día ${c.diaFechaLimite} recibe $t';
}

/// Recompensas por pagar a tiempo (Victor, 2026-11-15): encender o apagar y
/// qué se recibe (puntos extra, clase gratis, saldo a favor; se combinan).
/// Rige para los pagos que se aprueben desde que se guarda.
class RecompensasPagoScreen extends StatefulWidget {
  const RecompensasPagoScreen({super.key, required this.config});
  final ConfigLiga config;

  @override
  State<RecompensasPagoScreen> createState() => _RecompensasPagoScreenState();
}

class _RecompensasPagoScreenState extends State<RecompensasPagoScreen> {
  static const _opcionesPuntos = [1, 2, 3, 5];
  late final Map<String, dynamic> _orig = widget.config.recompensaPago;
  late bool _activa = _orig['activa'] != false;
  late int _puntos = (_orig['puntos'] as num?)?.toInt() ?? 0;
  late bool _conPuntos = _puntos > 0, _clase = _orig['claseGratis'] == true;
  late bool _conSaldo = ((_orig['saldo'] as num?) ?? 0) > 0;
  late final _saldo = TextEditingController(text: _conSaldo ? '${_orig['saldo']}' : '');
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (_puntos == 0) _puntos = 1;
  }

  @override
  void dispose() {
    _saldo.dispose();
    super.dispose();
  }

  num get _montoSaldo => num.tryParse(_saldo.text.replaceAll(',', '.')) ?? 0;

  Map<String, dynamic> get _nueva => {'activa': _activa, 'puntos': _conPuntos ? _puntos : 0, 'claseGratis': _clase, 'saldo': _conSaldo ? _montoSaldo : 0};

  bool get _vacia => textoRecompensa(_nueva).isEmpty;

  bool get _cambio {
    final n = _nueva, o = _orig;
    return n['activa'] != (o['activa'] != false) ||
        n['puntos'] != ((o['puntos'] as num?)?.toInt() ?? 0) ||
        n['claseGratis'] != (o['claseGratis'] == true) ||
        n['saldo'] != ((o['saldo'] as num?) ?? 0);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await widget.config.guardarReglas({'recompensaPago': _nueva});
      m.showSnackBar(const SnackBar(content: Text('Guardado. Rige para los pagos que se aprueben desde ahora.')));
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
    final dia = widget.config.diaFechaLimite, t = textoRecompensa(_nueva);
    final ejemplo = !_activa
        ? 'Sin recompensa: pagar a tiempo no da nada extra. Los avisos de cuota siguen llegando.'
        : t.isEmpty
        ? 'Elige al menos una recompensa.'
        : 'Quien envía el pago de su cuota hasta el día $dia recibe $t cuando un Pivot aprueba el pago. Si después se cancela, se quita.';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Pagar a tiempo', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(
            'Elige qué recibe quien paga su cuota hasta la fecha límite (día $dia). Puedes combinar varias.',
            style: TextStyle(fontSize: 15, height: 1.4, color: p.texto),
          ),
          const SizedBox(height: 18),
          _Tarjeta(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dar recompensa', style: TextStyle(fontWeight: FontWeight.w700)),
              value: _activa,
              onChanged: (v) => setState(() => _activa = v),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_activa
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 18),
                      const _Titulo('QUÉ SE RECIBE'),
                      _Tarjeta(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Opcion(
                              icono: Icons.star_outline_rounded,
                              titulo: 'Puntos extra',
                              texto: 'Se suman a los puntos del mes que paga.',
                              valor: _conPuntos,
                              alCambiar: (v) => setState(() => _conPuntos = v),
                              extra: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final n in _opcionesPuntos)
                                    ChoiceChip(
                                      label: Text('$n ${n == 1 ? 'punto' : 'puntos'}'),
                                      selected: _puntos == n,
                                      onSelected: (_) => setState(() => _puntos = n),
                                    ),
                                ],
                              ),
                            ),
                            Divider(height: 24, color: p.bordeSuave),
                            _Opcion(
                              icono: Icons.local_activity_outlined,
                              titulo: 'Clase gratis',
                              texto: 'Para reservar una clase suelta sin pagar. Si ya tiene una sin usar, no se acumula.',
                              valor: _clase,
                              alCambiar: (v) => setState(() => _clase = v),
                            ),
                            Divider(height: 24, color: p.bordeSuave),
                            _Opcion(
                              icono: Icons.savings_outlined,
                              titulo: 'Saldo a favor',
                              texto: 'Un monto que puede usar en su próximo pago, como un descuento.',
                              valor: _conSaldo,
                              alCambiar: (v) => setState(() => _conSaldo = v),
                              extra: TextField(
                                controller: _saldo,
                                onChanged: (_) => setState(() {}),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                decoration: InputDecoration(labelText: 'Monto', prefixText: '${Moneda.s} '),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(ejemplo),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
              child: Text(ejemplo, style: TextStyle(height: 1.4, color: p.sobreSuave)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Un cambio rige para los pagos que se aprueben desde que lo guardas; lo que ya se dio no cambia. La fecha límite se cambia en Fecha límite de pago.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: p.textoSecundario),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _cambio && !_guardando && !(_activa && _vacia) ? _guardar : null, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.icono, required this.titulo, required this.texto, required this.valor, required this.alCambiar, this.extra});
  final IconData icono;
  final String titulo, texto;
  final bool valor;
  final ValueChanged<bool> alCambiar;
  final Widget? extra;
  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icono, color: p.textoSecundario),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                  ),
                  const SizedBox(height: 2),
                  Text(texto, style: TextStyle(fontSize: 13, height: 1.35, color: p.textoSecundario)),
                ],
              ),
            ),
            Switch(value: valor, onChanged: alCambiar),
          ],
        ),
        if (extra != null)
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: valor ? Padding(padding: const EdgeInsets.only(left: 36, top: 10), child: extra) : const SizedBox(width: double.infinity),
          ),
      ],
    );
  }
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
