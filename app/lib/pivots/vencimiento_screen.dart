import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/selector_plazo.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';

/// Vencimiento de la cuota explicado (Victor, 2026-11-14): qué hace cada
/// valor, con ejemplos que cambian según lo elegido y una recomendación.
/// Hoy el vencimiento solo decide desde cuándo corre el recargo; los
/// recordatorios (1, 14 y 16) y el punto extra (hasta el 15) van aparte.
class VencimientoScreen extends StatefulWidget {
  const VencimientoScreen({super.key, required this.config});
  final ConfigLiga config;

  @override
  State<VencimientoScreen> createState() => _VencimientoScreenState();
}

class _VencimientoScreenState extends State<VencimientoScreen> {
  static const _diaPuntoExtra = 15; // igual que DIA_PUNTO_EXTRA del servidor
  late int _dia = widget.config.cuotaVenceDia, _gracia = widget.config.cuotaGraciaDias;
  late bool _conRecargo = widget.config.cuotaRecargo > 0;
  late final _recargo = TextEditingController(text: widget.config.cuotaRecargo > 0 ? '${widget.config.cuotaRecargo}' : '');
  bool _guardando = false;

  @override
  void dispose() {
    _recargo.dispose();
    super.dispose();
  }

  num get _monto => num.tryParse(_recargo.text.replaceAll(',', '.')) ?? 0;
  String _plata(num v) => '\$${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(2)}';

  bool get _cambio =>
      _dia != widget.config.cuotaVenceDia || _gracia != widget.config.cuotaGraciaDias || (_conRecargo ? _monto : 0) != widget.config.cuotaRecargo;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await widget.config.guardarReglas({
        'cuotaVenceDia': _dia,
        'cuotaGraciaDias': _dia == 0 ? 0 : _gracia,
        'cuotaRecargo': _dia == 0 || !_conRecargo ? 0 : _monto,
      });
      m.showSnackBar(const SnackBar(content: Text('Guardado. Rige para los pagos que lleguen desde ahora.')));
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
    final ultimo = _dia + _gracia;
    final ejemploDia = _dia == 0
        ? 'Con 0 la cuota no vence: nunca hay recargo, sin importar el día en que paguen.'
        : 'Quien envía su pago hasta el $_dia${_gracia > 0 ? ' (o hasta el $ultimo con la gracia)' : ''} paga el precio normal.';
    final ejemploRecargo = !_conRecargo || _monto <= 0
        ? 'Sin recargo, el vencimiento no cambia lo que se paga: sirve solo como referencia.'
        : 'Desde el día ${ultimo + 1}, al pagar se ve "Mensualidad + ${_plata(_monto)} de recargo". Cuenta el día en que la persona envía el pago, no el día en que un Pivot lo aprueba.';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Vencimiento de la cuota', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(
            'Define hasta qué día se puede pagar la cuota del mes sin atraso. Si activas el recargo, quien pague después lo paga.',
            style: TextStyle(fontSize: 15, height: 1.4, color: p.texto),
          ),
          const SizedBox(height: 18),
          const _Titulo('ASÍ SE VE UN MES'),
          _Tarjeta(
            child: Column(
              children: [
                const _Paso(dia: '1', titulo: 'Recordatorio de cuota', texto: '"Si pagas hasta el 15, recibes un punto extra."'),
                const _Paso(dia: '14', titulo: 'Último aviso para el punto extra', texto: 'Solo a quien todavía no pagó.'),
                const _Paso(dia: '$_diaPuntoExtra', titulo: 'Último día del punto extra', texto: 'Quien pagó hasta hoy recibe un punto al aprobarse su pago.'),
                const _Paso(dia: '16', titulo: 'Aviso de cuota pendiente', texto: 'A quien todavía no pagó.'),
                if (_dia > 0)
                  _Paso(
                    dia: '$ultimo',
                    titulo: 'Vence la cuota',
                    texto: _conRecargo && _monto > 0 ? 'Desde el día siguiente se suma el recargo.' : 'Sin recargo: nada cambia al pasar este día.',
                    fuerte: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Los avisos y el punto extra no dependen del vencimiento: siempre son los días 1, 14, 15 y 16.',
            style: TextStyle(fontSize: 12.5, color: p.textoSecundario),
          ),
          const SizedBox(height: 18),
          const _Titulo('DÍA DE VENCIMIENTO'),
          _Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectorNumero(
                  valor: _dia,
                  min: 0,
                  max: 28,
                  etiqueta: _dia == 0 ? 'no vence' : 'de cada mes',
                  alCambiar: (n) => setState(() => _dia = n.toInt()),
                ),
                const SizedBox(height: 10),
                _Ejemplo(ejemploDia),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: _dia == 0
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 18),
                      const _Titulo('DÍAS DE GRACIA'),
                      _Tarjeta(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SelectorNumero(valor: _gracia, min: 0, max: 27, etiqueta: 'días', alCambiar: (n) => setState(() => _gracia = n.toInt())),
                            const SizedBox(height: 10),
                            _Ejemplo(
                              _gracia == 0
                                  ? 'Sin gracia, el recargo corre desde el día siguiente al vencimiento.'
                                  : 'Margen para quien se atrasa unos días: hasta el $ultimo todavía no hay recargo.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _Titulo('RECARGO POR ATRASO'),
                      _Tarjeta(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Cobrar recargo', style: TextStyle(fontWeight: FontWeight.w700)),
                              value: _conRecargo,
                              onChanged: (v) => setState(() => _conRecargo = v),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              child: !_conRecargo
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: TextField(
                                        controller: _recargo,
                                        onChanged: (_) => setState(() {}),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                        decoration: const InputDecoration(labelText: 'Monto fijo', prefixText: '\$ '),
                                      ),
                                    ),
                            ),
                            _Ejemplo(ejemploRecargo),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recomendación',
                  style: TextStyle(fontWeight: FontWeight.w800, color: p.sobreSuave),
                ),
                const SizedBox(height: 6),
                Text(
                  'Deja el recargo apagado: los avisos y el punto extra ya motivan a pagar a tiempo. '
                  'Actívalo solo si muchas personas pagan tarde varios meses seguidos, y avísalo al equipo antes. '
                  'Un cambio rige para los pagos que lleguen desde que lo guardas; los anteriores no cambian.',
                  style: TextStyle(height: 1.4, color: p.sobreSuave),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _cambio && !_guardando ? _guardar : null, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
        ],
      ),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: context.pivot.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
    child: child,
  );
}

class _Ejemplo extends StatelessWidget {
  const _Ejemplo(this.t);
  final String t;
  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(t),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: p.fondo, borderRadius: BorderRadius.circular(PivotRadios.contador)),
        child: Text(t, style: TextStyle(fontSize: 13, height: 1.4, color: p.textoSecundario)),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.dia, required this.titulo, required this.texto, this.fuerte = false});
  final String dia, titulo, texto;
  final bool fuerte;
  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: fuerte ? p.marca : p.suave, shape: BoxShape.circle),
            child: Text(
              dia,
              style: TextStyle(fontWeight: FontWeight.w900, color: fuerte ? p.sobreMarca : p.sobreSuave),
            ),
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
                Text(texto, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
