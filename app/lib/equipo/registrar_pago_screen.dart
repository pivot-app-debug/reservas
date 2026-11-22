import 'package:flutter/material.dart';

import '../core/fechas.dart';
import '../core/moneda.dart';
import '../core/tema.dart';
import '../eventos/widgets_comunes.dart';
import 'equipo_repo.dart';
import 'equipo_modelos.dart';

/// Registrar un pago a mano (Victor, 2026-11-21). Subsección (antes era un
/// panel que tardaba en abrir): se abre al instante y carga precios y clases
/// detrás. Se puede pagar una mensualidad, una clase (también una que quedó
/// debiendo por venir sin reserva) o dejar dinero a favor. Lo que pase del
/// precio queda como saldo a favor.
class RegistrarPagoScreen extends StatefulWidget {
  const RegistrarPagoScreen({super.key, required this.repo, required this.persona});
  final EquipoRepo repo;
  final Integrante persona;

  /// Últimos 6 meses, este y los próximos 6.
  static List<DateTime> meses() {
    final h = Fechas.hoy();
    return [for (var i = -6; i <= 6; i++) DateTime(h.year, h.month + i)];
  }

  @override
  State<RegistrarPagoScreen> createState() => _RegistrarPagoScreenState();
}

class _RegistrarPagoScreenState extends State<RegistrarPagoScreen> {
  var _tipo = 'mensual';
  var _mes = DateTime(Fechas.hoy().year, Fechas.hoy().month);
  var _forma = 'Efectivo';
  String? _clase;
  final _monto = TextEditingController();
  final _notas = TextEditingController();
  Map<String, dynamic>? _datos;
  String? _error;
  bool _guardando = false, _montoTocado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _monto.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final d = await widget.repo.clasesParaPago(widget.persona);
      if (!mounted) return;
      setState(() => _datos = d);
      _sugerirMonto();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<Map<String, dynamic>> get _clases => [for (final c in (_datos?['clases'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];

  double get _precio => switch (_tipo) {
    'mensual' => ((_datos?['precioMensual'] as num?) ?? 0).toDouble(),
    'clase' => ((_clases.where((c) => c['idEvento'] == _clase).firstOrNull?['monto'] as num?) ?? (_datos?['precioPorClase'] as num?) ?? 0).toDouble(),
    _ => 0,
  };

  void _sugerirMonto() {
    if (_montoTocado) return;
    final v = _precio;
    _monto.text = v > 0 ? v.toStringAsFixed(2) : '';
    setState(() {});
  }

  double get _valor => double.tryParse(_monto.text.replaceAll(',', '.')) ?? 0;

  Future<void> _guardar() async {
    if (_valor <= 0) return _aviso('Indica el monto.');
    if (_tipo == 'clase' && _clase == null) return _aviso('Elige la clase.');
    setState(() => _guardando = true);
    try {
      await widget.repo.registrarPago(
        widget.persona,
        mes: _mes,
        monto: _valor,
        forma: _forma,
        notas: _notas.text,
        tipo: _tipo,
        idEvento: _tipo == 'clase' ? _clase : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _aviso(e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _aviso(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final saldo = ((_datos?['saldo'] as num?) ?? 0).toDouble();
    final sobra = _tipo == 'saldo' ? _valor : (_precio > 0 && _valor > _precio ? _valor - _precio : 0.0);
    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        t,
        style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text('Pago de ${widget.persona.nombreMostrar}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (saldo != 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Etiqueta(
                  icono: saldo > 0 ? Icons.savings_outlined : Icons.account_balance_wallet_outlined,
                  texto: saldo > 0 ? 'Tiene ${Moneda.s}${saldo.toStringAsFixed(2)} a favor' : 'Debe ${Moneda.s}${(-saldo).toStringAsFixed(2)}',
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'mensual', label: Text('Mensualidad')),
                  ButtonSegment(value: 'clase', label: Text('Clase')),
                  ButtonSegment(value: 'saldo', label: Text('A favor')),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) {
                  setState(() => _tipo = s.first);
                  _sugerirMonto();
                },
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: switch (_tipo) {
                'mensual' => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titulo('Mes'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in RegistrarPagoScreen.meses())
                          ChoiceChip(label: Text(Fechas.mesAnio(m)), selected: m == _mes, onSelected: (_) => setState(() => _mes = m)),
                      ],
                    ),
                  ],
                ),
                'clase' => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titulo('Clase'),
                    if (_datos == null && _error == null)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_clases.isEmpty)
                      Text('No hay clases en las últimas semanas.', style: TextStyle(color: p.textoSecundario))
                    else
                      RadioGroup<String>(
                        groupValue: _clase,
                        onChanged: (v) {
                          setState(() => _clase = v);
                          _montoTocado = false;
                          _sugerirMonto();
                        },
                        child: Column(
                          children: [
                            for (final c in _clases)
                              RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                value: '${c['idEvento']}',
                                enabled: c['estado'] != 'pagada' && c['estado'] != 'pendiente',
                                title: Text('${Fechas.corta(DateTime.parse('${c['fecha']}'))}${'${c['hora']}'.isEmpty ? '' : ' · ${c['hora']}'}'),
                                subtitle: Text('${c['lugar']}'),
                                secondary: switch (c['estado']) {
                                  'debe' => Etiqueta(texto: 'Debe ${Moneda.s}${(c['monto'] as num).toStringAsFixed(2)}'),
                                  'pagada' => const Etiqueta(texto: 'Pagada', apagada: true),
                                  'pendiente' => const Etiqueta(texto: 'Por aprobar', apagada: true),
                                  _ => null,
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                _ => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Todo queda como saldo a favor. La persona elige cuánto usar al pagar una cuota o reservar una clase.',
                    style: TextStyle(color: p.textoSecundario),
                  ),
                ),
              },
            ),
            titulo('Medio de pago'),
            Wrap(
              spacing: 8,
              children: [
                for (final f in const ['Efectivo', 'De Una', 'Transferencia'])
                  ChoiceChip(label: Text(f), selected: f == _forma, onSelected: (_) => setState(() => _forma = f)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _monto,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Monto', prefixText: '${Moneda.s} '),
              onChanged: (_) => setState(() => _montoTocado = true),
            ),
            if (_tipo != 'saldo' && sobra > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Quedan ${Moneda.s}${sobra.toStringAsFixed(2)} como saldo a favor.', style: TextStyle(fontSize: 13, color: p.marcaTexto)),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _notas,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: _tipo == 'saldo' ? 'Concepto (opcional)' : 'Notas (opcional)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: p.marcaTexto)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _guardando ? null : _guardar,
              child: Text(
                _guardando
                    ? 'Guardando…'
                    : _tipo == 'mensual'
                    ? 'Registrar ${Moneda.s}${_valor.toStringAsFixed(2)} de ${Fechas.mes(_mes)}'
                    : 'Registrar ${Moneda.s}${_valor.toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
