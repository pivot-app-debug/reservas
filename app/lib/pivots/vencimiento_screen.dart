import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../core/moneda.dart';

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
  static const _opcionesGracia = [0, 1, 2, 3, 5, 7, 10];
  late final bool _sinGuardar = widget.config.cuotaVenceDia < 1 || widget.config.cuotaVenceDia > 28;
  late int _dia = _sinGuardar ? _porDefecto : widget.config.cuotaVenceDia, _gracia = widget.config.cuotaGraciaDias;
  late bool _conRecargo = widget.config.cuotaRecargo > 0;
  late final _recargo = TextEditingController(text: widget.config.cuotaRecargo > 0 ? '${widget.config.cuotaRecargo}' : '');
  bool _guardando = false;

  @override
  void dispose() {
    _recargo.dispose();
    super.dispose();
  }

  num get _monto => num.tryParse(_recargo.text.replaceAll(',', '.')) ?? 0;
  String _plata(num v) => '${Moneda.s}${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(2)}';
  bool get _recargoActivo => _conRecargo && _monto > 0;

  bool get _cambio =>
      _sinGuardar ||
      _dia != widget.config.cuotaVenceDia ||
      (_conRecargo ? _gracia : 0) != widget.config.cuotaGraciaDias ||
      (_conRecargo ? _monto : 0) != widget.config.cuotaRecargo;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await widget.config.guardarReglas({'cuotaVenceDia': _dia, 'cuotaGraciaDias': _conRecargo ? _gracia : 0, 'cuotaRecargo': _conRecargo ? _monto : 0});
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
    return [
      if (n > 1) const _Paso(dia: '1', titulo: 'Recordatorio de cuota', texto: 'Se avisa a todas las personas que ya pueden pagar.'),
      if (n > 2) _Paso(dia: '${n - 1}', titulo: 'Último aviso', texto: 'Solo a quien todavía no pagó: mañana es la fecha límite.'),
      _Paso(
        dia: '$n',
        titulo: 'Fecha límite',
        texto: n == 1 ? 'Recordatorio y último día para pagar a tiempo y recibir la recompensa.' : 'Último día para pagar a tiempo y recibir la recompensa.',
        fuerte: true,
      ),
      if (n < 28) _Paso(dia: '${n + 1}', titulo: 'Aviso de cuota pendiente', texto: 'A quien todavía no pagó.'),
      if (_recargoActivo && inicioRecargo <= 31)
        _Paso(dia: '$inicioRecargo', titulo: 'Empieza el recargo', texto: 'Desde hoy, al pagar se suma ${_plata(_monto)}.'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final ejemploRecargo = !_recargoActivo
        ? 'Sin recargo, pagar tarde no cuesta más: solo se pierde la recompensa por pagar a tiempo.'
        : 'Desde el día ${_dia + _gracia + 1}, al pagar se ve "Mensualidad + ${_plata(_monto)} de recargo". Cuenta el día en que la persona envía el pago, no el día en que un Pivot lo aprueba.';
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
            'Elige hasta qué día se puede pagar la cuota del mes a tiempo. Quien paga hasta ese día recibe la recompensa por pagar a tiempo.',
            style: TextStyle(fontSize: 15, height: 1.4, color: p.texto),
          ),
          if (_sinGuardar) ...[
            const SizedBox(height: 10),
            _Ejemplo('Todavía no hay una fecha guardada: hoy se usa el día $_porDefecto. Guarda para dejarla fija.'),
          ],
          const SizedBox(height: 18),
          const _Titulo('FECHA LÍMITE (DÍA DE CADA MES)'),
          _Tarjeta(
            child: _Calendario(dia: _dia, alElegir: (d) => setState(() => _dia = d)),
          ),
          const SizedBox(height: 18),
          const _Titulo('ASÍ SE VE UN MES'),
          _Tarjeta(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Column(key: ValueKey('$_dia-$_gracia-$_recargoActivo-$_monto'), children: _mes()),
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
                  subtitle: const Text('Un monto fijo que se suma a la cuota de quien paga después de la fecha límite.'),
                  value: _conRecargo,
                  onChanged: (v) => setState(() => _conRecargo = v),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: !_conRecargo
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _recargo,
                              onChanged: (_) => setState(() {}),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              decoration: InputDecoration(labelText: 'Monto del recargo', prefixText: '${Moneda.s} '),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Días de margen antes del recargo',
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final g in _opcionesGracia)
                                  ChoiceChip(
                                    label: Text(g == 0 ? 'Ninguno' : '$g ${g == 1 ? 'día' : 'días'}'),
                                    selected: _gracia == g,
                                    onSelected: (_) => setState(() => _gracia = g),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
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
                  'Deja el recargo apagado: los avisos y la recompensa ya motivan a pagar a tiempo. '
                  'Actívalo solo si muchas personas pagan tarde varios meses seguidos, y avísalo al equipo antes. '
                  'Un cambio rige desde que lo guardas; los pagos y puntos anteriores no cambian.',
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
