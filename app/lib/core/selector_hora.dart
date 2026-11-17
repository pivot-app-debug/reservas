import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tema.dart';

/// Selector de hora con ruedas de hora, minutos y a. m./p. m., como el del
/// reloj de Google (Victor, 2026-11-17). Se usa en toda la app en lugar del
/// reloj de Material. Devuelve null si se cierra sin elegir.
Future<TimeOfDay?> elegirHora(BuildContext context, {TimeOfDay? inicial, String titulo = 'Elige la hora', int pasoMinutos = 5}) {
  final base = inicial ?? const TimeOfDay(hour: 19, minute: 0);
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    showDragHandle: true,
    builder: (h) => _SelectorHora(inicial: base, titulo: titulo, paso: pasoMinutos),
  );
}

/// Igual que [elegirHora] pero con horas "HH:mm".
Future<String?> elegirHoraTexto(BuildContext context, {String? inicial, String titulo = 'Elige la hora', int pasoMinutos = 5}) async {
  final p = (inicial ?? '19:00').split(':');
  final t = await elegirHora(
    context,
    inicial: TimeOfDay(hour: int.tryParse(p.first) ?? 19, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0),
    titulo: titulo,
    pasoMinutos: pasoMinutos,
  );
  return t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _SelectorHora extends StatefulWidget {
  const _SelectorHora({required this.inicial, required this.titulo, required this.paso});
  final TimeOfDay inicial;
  final String titulo;
  final int paso;

  @override
  State<_SelectorHora> createState() => _SelectorHoraState();
}

class _SelectorHoraState extends State<_SelectorHora> {
  static const _alto = 52.0;
  late int _h12 = widget.inicial.hourOfPeriod == 0 ? 12 : widget.inicial.hourOfPeriod;
  late int _min = (widget.inicial.minute ~/ widget.paso) * widget.paso;
  late bool _pm = widget.inicial.hour >= 12;
  late final int _minutos = 60 ~/ widget.paso;
  // Las ruedas de hora y minutos dan la vuelta; se empieza en la mitad para poder girar a ambos lados.
  late final _cHora = FixedExtentScrollController(initialItem: 12 * 50 + (_h12 - 1));
  late final _cMin = FixedExtentScrollController(initialItem: _minutos * 50 + _min ~/ widget.paso);
  late final _cAmPm = FixedExtentScrollController(initialItem: _pm ? 1 : 0);

  @override
  void dispose() {
    _cHora.dispose();
    _cMin.dispose();
    _cAmPm.dispose();
    super.dispose();
  }

  TimeOfDay get _hora => TimeOfDay(hour: (_h12 % 12) + (_pm ? 12 : 0), minute: _min);

  Widget _rueda({
    required FixedExtentScrollController c,
    required int? total,
    required String Function(int) texto,
    required ValueChanged<int> cambio,
    required double ancho,
  }) {
    final p = context.pivot;
    return SizedBox(
      width: ancho,
      child: ListWheelScrollView.useDelegate(
        controller: c,
        itemExtent: _alto,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.003,
        diameterRatio: 1.6,
        overAndUnderCenterOpacity: 0.35,
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          setState(() => cambio(i));
        },
        childDelegate: total == null
            ? ListWheelChildBuilderDelegate(builder: (_, i) => _item(texto(i), p))
            : ListWheelChildListDelegate(children: [for (var i = 0; i < total; i++) _item(texto(i), p)]),
      ),
    );
  }

  Widget _item(String t, PivotPaleta p) => Center(
    child: Text(
      t,
      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: p.texto, fontFeatures: const [FontFeature.tabularFigures()]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.titulo, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            SizedBox(
              height: _alto * 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Franja de la hora elegida.
                  Container(
                    height: _alto,
                    decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _rueda(c: _cHora, total: null, texto: (i) => '${i % 12 + 1}', cambio: (i) => _h12 = i % 12 + 1, ancho: 72),
                      Text(
                        ':',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: p.texto),
                      ),
                      _rueda(
                        c: _cMin,
                        total: null,
                        texto: (i) => ((i % _minutos) * widget.paso).toString().padLeft(2, '0'),
                        cambio: (i) => _min = (i % _minutos) * widget.paso,
                        ancho: 72,
                      ),
                      const SizedBox(width: 12),
                      _rueda(c: _cAmPm, total: 2, texto: (i) => i == 0 ? 'a. m.' : 'p. m.', cambio: (i) => _pm = i == 1, ancho: 96),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.of(context).pop(_hora), child: const Text('Listo')),
          ],
        ),
      ),
    );
  }
}
