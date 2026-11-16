import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../core/moneda.dart';
import '../core/selector_plazo.dart';
import 'recompensas_screen.dart' show textoRecompensa;

/// Fecha límite de pago de la cuota (Victor, 2026-11-15): se elige el día
/// en un calendario (sin + y -), y el mes de ejemplo se arma con ese día:
/// el punto extra, los avisos y el recargo siguen la fecha límite, igual
/// que el servidor (`_diaPuntoExtra`). Sin fecha guardada, se usa el 15.
class VencimientoScreen extends StatefulWidget {
  const VencimientoScreen({super.key, required this.config});
  final ConfigLiga config;

  @override
  State<VencimientoScreen> createState() => _VencimientoScreenState();
}

class _VencimientoScreenState extends State<VencimientoScreen> {
  static const _porDefecto = 15; // igual que el servidor cuando no hay fecha guardada
  ConfigLiga get c => widget.config;
  late final bool _sinGuardar = c.cuotaVenceDia < 1 || c.cuotaVenceDia > 28;
  late int _dia = _sinGuardar ? _porDefecto : c.cuotaVenceDia, _gracia = c.cuotaGraciaDias;
  late bool _conRecargo = c.cuotaRecargo > 0;
  // Recargo nuevo en porcentaje por defecto (Victor, 2026-11-16); el guardado se respeta.
  late bool _porcentaje = c.cuotaRecargo > 0 ? c.recargoPorcentaje : true, _mensual = c.recargoMensual;
  late final _recargo = TextEditingController(text: c.cuotaRecargo > 0 ? '${c.cuotaRecargo}' : '');
  bool _guardando = false;

  @override
  void dispose() {
    _recargo.dispose();
    super.dispose();
  }

  num get _valor => num.tryParse(_recargo.text.replaceAll(',', '.')) ?? 0;
  String _plata(num v) => '${Moneda.s}${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(2)}';
  bool get _recargoActivo => _conRecargo && _valor > 0 && (!_porcentaje || _valor <= 100);

  /// Qué recibe quien paga a tiempo, o null si las recompensas están apagadas.
  String? get _recompensa {
    final r = c.recompensaPago, t = textoRecompensa(r);
    return r['activa'] == false || t.isEmpty ? null : t;
  }

  /// Recargo de una vez, en texto ("10 % de la mensualidad ($3)" o "$5").
  String get _uno {
    if (!_porcentaje) return _plata(_valor);
    final m = c.precioMensual;
    return '${_valor % 1 == 0 ? _valor.toInt() : _valor} %${m != null && m > 0 ? ' de la mensualidad (${_plata(m * _valor / 100)})' : ' de la mensualidad'}';
  }

  bool get _cambio =>
      _sinGuardar ||
      _dia != c.cuotaVenceDia ||
      (_conRecargo ? _gracia : 0) != c.cuotaGraciaDias ||
      (_conRecargo ? _valor : 0) != c.cuotaRecargo ||
      (_conRecargo && (_porcentaje != c.recargoPorcentaje || _mensual != c.recargoMensual));

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await c.guardarReglas({
        'cuotaVenceDia': _dia,
        'cuotaGraciaDias': _conRecargo ? _gracia : 0,
        'cuotaRecargo': _conRecargo ? _valor : 0,
        'cuotaRecargoTipo': _porcentaje ? 'porcentaje' : 'fijo',
        'cuotaRecargoModo': _mensual ? 'mensual' : 'unico',
      });
      m.showSnackBar(const SnackBar(content: Text('Guardado. Rige desde ahora; los pagos y puntos anteriores no cambian.')));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  List<Widget> _mes() {
    final n = _dia, inicioRecargo = n + _gracia + 1;
    final premio = _recompensa != null ? ' y recibir la recompensa' : '';
    return [
      if (n > 1) const _Paso(dia: '1', titulo: 'Recordatorio de cuota', texto: 'Se avisa a todas las personas que ya pueden pagar.'),
      if (n > 2) _Paso(dia: '${n - 1}', titulo: 'Último aviso', texto: 'Solo a quien todavía no pagó: mañana es la fecha límite.'),
      _Paso(
        dia: '$n',
        titulo: 'Fecha límite',
        texto: n == 1 ? 'Recordatorio y último día para pagar a tiempo$premio.' : 'Último día para pagar a tiempo$premio.',
        fuerte: true,
      ),
      if (n < 28) _Paso(dia: '${n + 1}', titulo: 'Aviso de cuota pendiente', texto: 'A quien todavía no pagó.'),
      if (_recargoActivo && inicioRecargo <= 31)
        _Paso(
          dia: '$inicioRecargo',
          titulo: 'Empieza el recargo',
          texto: 'Desde hoy, al pagar se suma $_uno${_mensual ? ', y otra vez cada mes que pase sin pagar' : ''}.',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final premio = _recompensa;
    final inicio = _dia + _gracia + 1;
    final ejemploRecargo = !_recargoActivo
        ? 'Sin recargo, pagar tarde no cuesta más${premio != null ? ': solo se pierde la recompensa por pagar a tiempo' : ''}.'
        : _mensual
        ? 'Si alguien paga la cuota de noviembre el $inicio de noviembre, se suma $_uno. Si la paga el $inicio de diciembre, se suma dos veces, y así cada mes. '
              'Cuenta el día en que la persona envía el pago.'
        : 'Desde el día $inicio, al pagar se ve "Mensualidad + $_uno de recargo", una sola vez aunque pase más tiempo. Cuenta el día en que la persona envía el pago.';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Fecha límite de pago', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(
            premio != null
                ? 'Elige hasta qué día de cada mes se puede pagar la cuota a tiempo. Quien paga hasta ese día recibe $premio.'
                : 'Elige hasta qué día de cada mes se puede pagar la cuota a tiempo.',
            style: TextStyle(fontSize: 15, height: 1.4, color: p.texto),
          ),
          if (premio == null) ...[
            const SizedBox(height: 10),
            const _Ejemplo('La recompensa por pagar a tiempo está apagada. Se enciende en Reglas → Recompensas → Por pagar a tiempo.'),
          ],
          if (_sinGuardar) ...[
            const SizedBox(height: 10),
            _Ejemplo('Todavía no hay una fecha guardada: hoy se usa el día $_porDefecto. Guarda para dejarla fija.'),
          ],
          const SizedBox(height: 16),
          _Tarjeta(
            child: _Calendario(dia: _dia, alElegir: (d) => setState(() => _dia = d)),
          ),
          const SizedBox(height: 12),
          _Tarjeta(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Column(key: ValueKey('$_dia-$_gracia-$_recargoActivo-$_valor-$_porcentaje-$_mensual'), children: _mes()),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _Titulo('RECARGO POR PAGAR TARDE'),
          _Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cobrar recargo', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Se suma a la cuota de quien paga después de la fecha límite.'),
                  value: _conRecargo,
                  onChanged: (v) => setState(() => _conRecargo = v),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !_conRecargo
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            _Etiqueta('Cuánto'),
                            SegmentedButton<bool>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(value: true, label: Text('Porcentaje')),
                                ButtonSegment(value: false, label: Text('Monto fijo')),
                              ],
                              selected: {_porcentaje},
                              onSelectionChanged: (x) => setState(() => _porcentaje = x.first),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _recargo,
                              onChanged: (_) => setState(() {}),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              decoration: InputDecoration(
                                labelText: _porcentaje ? 'Porcentaje de la mensualidad' : 'Monto del recargo',
                                prefixText: _porcentaje ? null : '${Moneda.s} ',
                                suffixText: _porcentaje ? '%' : null,
                                errorText: _porcentaje && _valor > 100 ? 'Hasta 100 %' : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _Etiqueta('Cuántas veces'),
                            SegmentedButton<bool>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(value: false, label: Text('Una sola vez')),
                                ButtonSegment(value: true, label: Text('Cada mes de atraso')),
                              ],
                              selected: {_mensual},
                              onSelectionChanged: (x) => setState(() => _mensual = x.first),
                            ),
                            const SizedBox(height: 16),
                            _Etiqueta('Días de margen después de la fecha límite'),
                            SelectorNumero(
                              valor: _gracia,
                              min: 0,
                              max: 20,
                              etiqueta: _gracia == 1 ? 'día' : 'días',
                              alCambiar: (v) => setState(() => _gracia = v.toInt()),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                ),
                _Ejemplo(ejemploRecargo),
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
                  'Deja el recargo apagado: los avisos${premio != null ? ' y la recompensa' : ''} ya motivan a pagar a tiempo. '
                  'Actívalo solo si muchas personas pagan tarde varios meses seguidos, y avísalo al equipo antes. '
                  'Un cambio rige desde que lo guardas; los pagos y puntos anteriores no cambian.',
                  style: TextStyle(height: 1.4, color: p.sobreSuave),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _cambio && !_guardando && (!_conRecargo || _recargoActivo) ? _guardar : null,
            child: Text(_guardando ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: TextStyle(fontWeight: FontWeight.w700, color: context.pivot.texto),
    ),
  );
}

/// Días 1 a 28 en una grilla de 7 columnas, como un calendario. Se llega
/// hasta el 28 para que la fecha exista en todos los meses.
class _Calendario extends StatelessWidget {
  const _Calendario({required this.dia, required this.alElegir});
  final int dia;
  final ValueChanged<int> alElegir;
  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Column(
      children: [
        for (var fila = 0; fila < 4; fila++)
          Row(
            children: [
              for (var c = 1; c <= 7; c++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Builder(
                        builder: (_) {
                          final d = fila * 7 + c, sel = d == dia;
                          return Material(
                            color: sel ? p.marca : p.fondo,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => alElegir(d),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 180),
                                  style: TextStyle(fontWeight: sel ? FontWeight.w900 : FontWeight.w600, color: sel ? p.sobreMarca : p.texto),
                                  child: Text('$d'),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 6),
        Text('Se puede elegir hasta el 28 para que la fecha exista en todos los meses.', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
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
