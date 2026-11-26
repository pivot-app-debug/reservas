import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/esqueleto.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import 'tesoreria_repo.dart';

/// Revisar cuentas (auditoría de Finanzas, 2026-11-26): lo que no cuadra en
/// Tesorería. Solo lee (`adminTesoreria` acción 'salud'); cada caso explica
/// qué pasa y qué hacer. Pagos sin registrar, duplicados, anulados cuyo pago
/// sigue vivo, cuentas que dejan movimientos fuera y deudores con Asistiré.
class RevisionTesoreriaScreen extends StatefulWidget {
  const RevisionTesoreriaScreen({super.key, required this.repo});
  final TesoreriaRepo repo;

  @override
  State<RevisionTesoreriaScreen> createState() => _RevisionTesoreriaScreenState();
}

class _RevisionTesoreriaScreenState extends State<RevisionTesoreriaScreen> {
  Map<String, dynamic>? _r;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.repo.accion('salud');
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _r = const {'total': 0});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo completar. Revisa tu conexión.')));
    }
  }

  List<Map<String, dynamic>> _lista(String k) => [for (final x in (_r?[k] as List? ?? const [])) x as Map<String, dynamic>];

  String _fecha(Object? f) {
    final t = '${f ?? ''}';
    if (t.length < 10) return '';
    return '${t.substring(8, 10)}/${t.substring(5, 7)}/${t.substring(0, 4)}';
  }

  Widget _seccion(BuildContext context, String titulo, String ayuda, List<Widget> filas) {
    final p = context.pivot;
    if (filas.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$titulo · ${filas.length}', style: TextStyle(fontWeight: FontWeight.w800, color: p.texto)),
              const SizedBox(height: 4),
              Text(ayuda, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
              const SizedBox(height: 4),
              ...filas,
            ],
          ),
        ),
      ),
    );
  }

  Widget _fila(String t, String s, [String? monto]) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: s.isEmpty ? null : Text(s),
    trailing: monto == null ? null : Text(monto, style: const TextStyle(fontWeight: FontWeight.w700)),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final r = _r;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Revisar cuentas', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: r == null
          ? const Esqueleto(forma: FormaEsqueleto.lista)
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 32 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Text(
                    (r['total'] as num? ?? 0) == 0
                        ? 'Todo cuadra: no hay pagos sin registrar, duplicados ni deudas pendientes de revisar.'
                        : 'Esto no cuadra en Tesorería. Revísalo y corrígelo desde Movimientos o Cuotas del mes.',
                    style: TextStyle(fontSize: 13.5, color: p.textoSecundario),
                  ),
                  const SizedBox(height: 12),
                  _seccion(
                    context,
                    'Pagos confirmados sin registrar',
                    'Se aprobaron pero nunca entraron a una cuenta. Regístralos como ingreso en la cuenta donde llegó el dinero.',
                    [
                      for (final x in [..._lista('sinMovimientoReservas'), ..._lista('sinMovimientoPagos')])
                        _fila('${x['persona']} · ${x['que']}', _fecha(x['fecha']), plata((x['monto'] as num?) ?? 0)),
                    ],
                  ),
                  _seccion(
                    context,
                    'Cuotas duplicadas',
                    'La misma persona tiene dos pagos activos del mismo mes. Anula el que sobra.',
                    [
                      for (final d in _lista('duplicados'))
                        _fila('${d['persona']} · ${d['mes']}/${d['anio']}', '${(d['movimientos'] as List? ?? const []).length} pagos del mismo mes'),
                    ],
                  ),
                  _seccion(
                    context,
                    'Anulados que siguen como pagados',
                    'El movimiento se anuló pero el pago o la reserva siguen vivos. Si el pago fue real, vuelve a registrarlo.',
                    [
                      for (final m in _lista('anuladosConOrigenVivo'))
                        _fila('${m['personaNombre'] ?? m['persona'] ?? ''} · ${m['descripcion']}', _fecha(m['fecha']), plata((m['monto'] as num?) ?? 0)),
                    ],
                  ),
                  _seccion(
                    context,
                    'Cuentas que dejan movimientos fuera',
                    'Tienen movimientos anteriores a su fecha inicial, así que no suman en el saldo. Cambia la fecha inicial de la cuenta.',
                    [
                      for (final c in _lista('cuentasConMovimientosAntes'))
                        _fila('${c['cuenta']}', '${c['movimientos']} movimientos antes del ${_fecha(c['fechaInicial'])}', plata((c['monto'] as num?) ?? 0)),
                    ],
                  ),
                  _seccion(
                    context,
                    'Deben la cuota y tienen Asistiré',
                    'Ya no pueden marcar Asistiré nuevos, pero conservan los que ya tenían.',
                    [
                      for (final d in _lista('deudoresConAsistire'))
                        _fila(
                          '${d['nombre']}',
                          '${d['asistire']} Asistiré a futuro${(d['anticipada'] as num? ?? 0) > 0 ? ' (${d['anticipada']} por asistencia anticipada)' : ''}',
                          plata((d['debe'] as num?) ?? 0),
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
