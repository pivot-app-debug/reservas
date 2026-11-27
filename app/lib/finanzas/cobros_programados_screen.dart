import 'package:flutter/material.dart';

import '../ajustes/componentes.dart' show abrirFormulario;
import '../core/api.dart';
import '../core/banner_ayuda.dart';
import '../core/esqueleto.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import 'tesoreria_repo.dart';

/// Cobros del banco (Victor, 2026-11-26): mantenimiento, notificaciones SMS y
/// otras comisiones que el banco descuenta solo. Cada mes (o cada año) la app
/// registra el egreso en su cuenta, así el saldo coincide con el estado de
/// cuenta. Si el cobro empezó antes, se registran también los meses pasados.
class CobrosProgramadosScreen extends StatefulWidget {
  const CobrosProgramadosScreen({super.key, required this.repo, required this.cuentas});
  final TesoreriaRepo repo;

  /// Cuentas activas {id, nombre}.
  final List<Map<String, dynamic>> cuentas;

  @override
  State<CobrosProgramadosScreen> createState() => _CobrosProgramadosScreenState();
}

class _CobrosProgramadosScreenState extends State<CobrosProgramadosScreen> {
  List<Map<String, dynamic>>? _cobros;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.repo.accion('cobros');
      if (mounted) setState(() => _cobros = [for (final c in (r['cobros'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cobros ??= const []);
      _aviso(e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
    }
  }

  void _aviso(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  String _cuenta(Object? id) => '${widget.cuentas.where((c) => '${c['id']}' == '$id').firstOrNull?['nombre'] ?? 'Cuenta'}';

  static const _meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

  Future<void> _editar([Map<String, dynamic>? c]) async {
    if (widget.cuentas.isEmpty) {
      _aviso('Primero crea una cuenta en Finanzas.');
      return;
    }
    final nombre = TextEditingController(text: '${c?['nombre'] ?? ''}');
    final monto = TextEditingController(text: c == null ? '' : '${c['monto']}');
    var cuenta = '${c?['cuenta_id'] ?? widget.cuentas.first['id']}';
    var frecuencia = '${c?['frecuencia'] ?? 'mensual'}';
    var dia = (c?['dia'] as num?)?.toInt() ?? 1;
    var desde = DateTime.tryParse('${c?['desde'] ?? ''}') ?? DateTime(DateTime.now().year, DateTime.now().month);
    final ok = await abrirFormulario<bool>(
      context,
      builder: (h) => StatefulBuilder(
        builder: (h, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(h).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(c == null ? 'Nuevo cobro del banco' : 'Editar cobro', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('La app lo registra sola como gasto de la cuenta, con el IVA incluido en el monto.', style: TextStyle(color: h.pivot.textoSecundario)),
              const SizedBox(height: 16),
              TextField(
                controller: nombre,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Qué cobra el banco', hintText: 'Por ejemplo: Notificaciones SMS'),
              ),
              TextField(
                controller: monto,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto total (con IVA)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: cuenta,
                decoration: const InputDecoration(labelText: 'De la cuenta'),
                items: [for (final x in widget.cuentas) DropdownMenuItem(value: '${x['id']}', child: Text('${x['nombre']}'))],
                onChanged: (v) => set(() => cuenta = v ?? cuenta),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'mensual', label: Text('Cada mes')),
                  ButtonSegment(value: 'anual', label: Text('Cada año')),
                ],
                selected: {frecuencia},
                onSelectionChanged: (v) => set(() => frecuencia = v.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: dia,
                decoration: const InputDecoration(labelText: 'Día del mes en que cobra'),
                items: [for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text('Día $d'))],
                onChanged: (v) => set(() => dia = v ?? dia),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: h,
                    initialDate: desde,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 366)),
                    helpText: '¿Desde cuándo cobra?',
                  );
                  if (d != null) set(() => desde = DateTime(d.year, d.month));
                },
                icon: const Icon(Icons.event_outlined),
                label: Text('Desde ${_meses[desde.month - 1]} de ${desde.year}'),
              ),
              const SizedBox(height: 6),
              Text(
                'Si eliges un mes pasado, se registran también los cobros de esos meses. Después revisa que la cuenta siga igual al estado de cuenta.',
                style: TextStyle(fontSize: 13, color: h.pivot.textoSecundario),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => Navigator.of(h).pop(true), child: const Text('Guardar')),
            ],
          ),
        ),
      ),
    );
    final n = nombre.text.trim(), m = num.tryParse(monto.text.trim().replaceAll(',', '.')) ?? 0;
    nombre.dispose();
    monto.dispose();
    if (ok != true) return;
    setState(() => _ocupado = true);
    try {
      final r = await widget.repo.accion('guardarCobro', {
        'id': ?c?['id'],
        'nombre': n,
        'monto': m,
        'cuentaId': cuenta,
        'frecuencia': frecuencia,
        'dia': dia,
        'desde': '${desde.year}-${desde.month.toString().padLeft(2, '0')}-01',
      });
      final g = (r['generados'] as num?)?.toInt() ?? 0;
      _aviso(g == 0 ? 'Guardado' : (g == 1 ? 'Guardado: se registró 1 cobro' : 'Guardado: se registraron $g cobros'));
      await _cargar();
    } catch (e) {
      _aviso(e is ApiException ? e.message : 'No se pudo guardar.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _quitar(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿Dejar de registrar "${c['nombre']}"?'),
        content: const Text('Desde hoy la app ya no lo registra. Lo que ya se registró queda en la cuenta.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Dejar de registrar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repo.accion('quitarCobro', {'id': c['id']});
      await _cargar();
    } catch (e) {
      _aviso(e is ApiException ? e.message : 'No se pudo completar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _cobros;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Cobros del banco', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: _ocupado ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: l == null
          ? const Esqueleto(forma: FormaEsqueleto.lista)
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 40 + MediaQuery.paddingOf(context).bottom),
              children: [
                const BannerAyuda(
                  clave: 'cobros_banco',
                  titulo: 'Para qué sirve',
                  texto: 'El banco descuenta solo algunas cosas, como el mantenimiento o las notificaciones SMS. Anótalas aquí una vez y la app las registra cada mes, así la cuenta coincide con el estado de cuenta.',
                  pasos: [
                    (Icons.receipt_long_outlined, 'Pon el monto total que aparece en el estado de cuenta, con IVA.'),
                    (Icons.history_rounded, 'Si el cobro viene de antes, elige desde qué mes: se registran también esos meses.'),
                    (Icons.block_rounded, 'Si el banco deja de cobrarlo, quítalo: lo ya registrado queda.'),
                  ],
                ),
                const SizedBox(height: 8),
                if (l.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Todavía no hay cobros programados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.textoSecundario),
                    ),
                  ),
                for (final c in l)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: p.tarjeta,
                      borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        onTap: () => _editar(c),
                        leading: Icon(Icons.account_balance_outlined, color: p.marcaTexto),
                        title: Text('${c['nombre']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${_cuenta(c['cuenta_id'])} · ${c['frecuencia'] == 'anual' ? 'cada año' : 'cada mes'}, el día ${c['dia']} · desde ${'${c['desde']}'.substring(5, 7)}/${'${c['desde']}'.substring(0, 4)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(plata((c['monto'] as num?) ?? num.tryParse('${c['monto']}') ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                            IconButton(
                              tooltip: 'Dejar de registrar',
                              icon: Icon(Icons.close_rounded, color: p.textoSecundario),
                              onPressed: () => _quitar(c),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: _ocupado ? null : () => _editar(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar un cobro del banco'),
                ),
              ],
            ),
    );
  }
}
