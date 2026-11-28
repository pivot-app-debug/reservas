import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api.dart';
import '../core/esqueleto.dart';
import '../core/tema.dart';
import '../core/xlsx.dart';
import 'tesoreria_repo.dart';

/// Cierre anual de cuentas (Victor, 2026-11-27). En enero, cualquier Pivot de
/// Finanzas revisa el año anterior en cuatro pasos y lo cierra con candado:
/// después no se pueden registrar, anular ni corregir movimientos de ese año.
/// Lo que se le debe al equipo técnico y los saldos de las personas siguen
/// al año nuevo. No se puede reabrir.
class CierreAnualScreen extends StatefulWidget {
  const CierreAnualScreen({super.key, required this.repo, required this.anio});
  final TesoreriaRepo repo;
  final int anio;

  @override
  State<CierreAnualScreen> createState() => _CierreAnualScreenState();
}

class _CierreAnualScreenState extends State<CierreAnualScreen> {
  Map<String, dynamic>? _r;
  String? _error;
  int _paso = 0;
  bool _cerrando = false;

  static const _titulos = ['Revisión', 'Equipo técnico', 'Saldos', 'Resumen'];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.repo.accion('cierre', {'anio': widget.anio});
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
    }
  }

  Map<String, dynamic> get _res => (_r?['resumen'] as Map?)?.cast<String, dynamic>() ?? const {};
  List<Map<String, dynamic>> _lista(String k) => [for (final x in (_res[k] as List? ?? const [])) (x as Map).cast<String, dynamic>()];
  bool get _cerrado => _r?['cerrado'] != null;

  Future<void> _cerrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Cerrar las cuentas de ${widget.anio}?'),
        content: Text(
          'Después no se podrán registrar, anular ni corregir movimientos de ${widget.anio}, y no se puede reabrir. '
          'Lo que se le debe al equipo técnico y los saldos de cada persona pasan a ${widget.anio + 1}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Cerrar el año')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cerrando = true);
    try {
      final r = await widget.repo.accion('cerrarAnio', {'anio': widget.anio});
      if (!mounted) return;
      setState(() => _r = r);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Listo: las cuentas de ${widget.anio} quedaron cerradas.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo cerrar.')));
    } finally {
      if (mounted) setState(() => _cerrando = false);
    }
  }

  Future<void> _exportar() async {
    final r = _res;
    final meses = ((r['meses'] as Map?) ?? const {}).cast<String, dynamic>();
    final cats = ((r['categorias'] as Map?) ?? const {}).cast<String, dynamic>();
    final bytes = crearXlsx([
      HojaXlsx(
        'Resumen',
        [
          const ['Concepto', 'Monto'],
          ['Ingresos', (r['ingresos'] as num?) ?? 0],
          ['Egresos', (r['egresos'] as num?) ?? 0],
          ['Resultado del año', (r['resultado'] as num?) ?? 0],
          ['Saldo al 31 de diciembre', (r['saldoFinal'] as num?) ?? 0],
          for (final c in _lista('cuentas')) ['Cuenta: ${c['nombre']}', (c['saldo'] as num?) ?? 0],
        ],
        anchos: const [34, 14],
      ),
      HojaXlsx(
        'Por mes',
        [
          const ['Mes', 'Ingresos', 'Egresos'],
          for (final k in meses.keys.toList()..sort()) [k, (meses[k]['ingresos'] as num?) ?? 0, (meses[k]['egresos'] as num?) ?? 0],
        ],
        anchos: const [12, 14, 14],
      ),
      HojaXlsx(
        'Por categoría',
        [
          const ['Categoría', 'Ingresos', 'Egresos'],
          for (final k in cats.keys) [k, (cats[k]['ingresos'] as num?) ?? 0, (cats[k]['egresos'] as num?) ?? 0],
        ],
        anchos: const [24, 14, 14],
      ),
      HojaXlsx(
        'Pasan al año nuevo',
        [
          const ['Persona', 'Qué', 'Monto'],
          for (final x in _lista('tecnico')) [x['nombre'], 'Se le debe (equipo técnico)', (x['monto'] as num?) ?? 0],
          for (final x in _lista('deben')) [x['nombre'], 'Debe', (x['saldo'] as num?) ?? 0],
          for (final x in _lista('aFavor')) [x['nombre'], 'Tiene a favor', (x['saldo'] as num?) ?? 0],
        ],
        anchos: const [26, 28, 14],
      ),
    ]);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: 'cierre.xlsx')],
        fileNameOverrides: ['cierre-${widget.anio}.xlsx'],
        subject: 'Cierre de cuentas ${widget.anio}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Scaffold(
      appBar: AppBar(title: Text('Cierre de ${widget.anio}')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _r == null
            ? (_error == null ? const Esqueleto(forma: FormaEsqueleto.tarjetas, key: ValueKey('c')) : Center(key: const ValueKey('e'), child: Text(_error!)))
            : _cerrado
            ? _vistaCerrada(context, p)
            : _pasos(context, p),
      ),
    );
  }

  Widget _vistaCerrada(BuildContext context, PivotPaleta p) => ListView(
    key: const ValueKey('cerrado'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
    children: [
      Icon(Icons.lock_outline_rounded, size: 48, color: p.marcaTexto),
      const SizedBox(height: 8),
      Text(
        'Las cuentas de ${widget.anio} están cerradas',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.texto),
      ),
      const SizedBox(height: 16),
      ..._resumen(p),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: _exportar, icon: const Icon(Icons.download_rounded), label: const Text('Descargar Excel')),
    ],
  );

  Widget _pasos(BuildContext context, PivotPaleta p) {
    final ultimo = _paso == _titulos.length - 1;
    return Column(
      key: const ValueKey('pasos'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              for (var i = 0; i < _titulos.length; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: i <= _paso ? p.marca : p.borde, borderRadius: BorderRadius.circular(PivotRadios.chip)),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Paso ${_paso + 1} de ${_titulos.length} · ${_titulos[_paso]}',
              style: TextStyle(color: p.textoSecundario, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.05, 0), end: Offset.zero).animate(a),
                child: c,
              ),
            ),
            child: ListView(
              key: ValueKey(_paso),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: switch (_paso) {
                0 => _revision(p),
                1 => _tecnico(p),
                2 => _saldos(p),
                _ => [
                  ..._resumen(p),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _exportar, icon: const Icon(Icons.download_rounded), label: const Text('Descargar Excel')),
                ],
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                if (_paso > 0) TextButton(onPressed: () => setState(() => _paso--), child: const Text('Atrás')),
                const Spacer(),
                ultimo
                    ? FilledButton.icon(
                        onPressed: _cerrando ? null : _cerrar,
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: Text('Cerrar ${widget.anio}'),
                      )
                    : FilledButton(onPressed: () => setState(() => _paso++), child: const Text('Siguiente')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _texto(PivotPaleta p, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: TextStyle(color: p.textoSecundario)),
  );

  Widget _fila(PivotPaleta p, IconData i, String titulo, String valor, {String? sub}) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(i, color: p.marcaTexto),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: sub == null ? null : Text(sub),
      trailing: Text(valor, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );

  List<Widget> _revision(PivotPaleta p) {
    final cuentas = _lista('cuentas');
    final faltan = cuentas.where((c) => c['conciliada'] != true).length;
    return [
      _texto(
        p,
        faltan == 0
            ? 'Todas las cuentas están conciliadas. Revisa que los saldos al 31 de diciembre coincidan con lo que hay en cada cuenta.'
            : 'Te recomendamos conciliar las cuentas antes de cerrar: compara cada saldo con lo que de verdad hay en la cuenta. Falta${faltan == 1 ? '' : 'n'} $faltan.',
      ),
      for (final c in cuentas)
        _fila(
          p,
          c['conciliada'] == true ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
          '${c['nombre']}',
          plata((c['saldo'] as num?) ?? 0),
          sub: c['conciliada'] == true ? 'Conciliada · saldo al 31 de diciembre' : 'Sin conciliar · saldo al 31 de diciembre',
        ),
    ];
  }

  List<Widget> _tecnico(PivotPaleta p) {
    final l = _lista('tecnico');
    return [
      _texto(
        p,
        l.isEmpty
            ? 'No se le debe nada al equipo técnico.'
            : 'Esto es lo que todavía se le debe al equipo técnico. Si no se paga antes de cerrar, la deuda pasa a ${widget.anio + 1}.',
      ),
      for (final x in l) _fila(p, Icons.sports_rounded, '${x['nombre']}', plata((x['monto'] as num?) ?? 0)),
    ];
  }

  List<Widget> _saldos(PivotPaleta p) {
    final deben = _lista('deben'), aFavor = _lista('aFavor');
    return [
      _texto(p, 'Los saldos de cada persona no se borran: pasan tal cual a ${widget.anio + 1}.'),
      if (deben.isEmpty && aFavor.isEmpty) _texto(p, 'Nadie tiene saldo pendiente.'),
      for (final x in deben) _fila(p, Icons.trending_down_rounded, '${x['nombre']}', plata(((x['saldo'] as num?) ?? 0).abs()), sub: 'Debe'),
      for (final x in aFavor) _fila(p, Icons.trending_up_rounded, '${x['nombre']}', plata((x['saldo'] as num?) ?? 0), sub: 'Tiene a favor'),
    ];
  }

  List<Widget> _resumen(PivotPaleta p) {
    final r = _res;
    num n(String k) => (r[k] as num?) ?? 0;
    return [
      _fila(p, Icons.south_west_rounded, 'Ingresos', plata(n('ingresos'))),
      _fila(p, Icons.north_east_rounded, 'Egresos', plata(n('egresos'))),
      _fila(p, Icons.equalizer_rounded, 'Resultado del año', plata(n('resultado'))),
      _fila(p, Icons.account_balance_wallet_outlined, 'Saldo al 31 de diciembre', plata(n('saldoFinal'))),
      _texto(p, 'Si las cuentas de la liga son visibles para todo el equipo, este resumen también lo será (solo totales, sin datos de personas).'),
    ];
  }
}
