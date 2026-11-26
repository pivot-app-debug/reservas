import 'dart:convert';

import 'package:flutter/material.dart';

import '../ajustes/componentes.dart';
import '../core/api.dart';
import '../core/banner_ayuda.dart';
import '../core/esqueleto.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../sesion/sesion.dart';
import 'tesoreria_repo.dart' show plata;

/// Pago a coaches (Victor, 2026-11-26): regla editable de la liga y por
/// equipo, y el cálculo del año mes por mes. Todo lo calcula el servidor
/// (`adminPagoCoaches`); lo de cada mes cerrado queda en Saldos como "El
/// equipo le debe". Si se abre desde un equipo, [equipo] lleva a su regla.
class PagoCoachesScreen extends StatefulWidget {
  const PagoCoachesScreen({super.key, required this.sesion, this.equipo});
  final Sesion sesion;
  final String? equipo;

  @override
  State<PagoCoachesScreen> createState() => _PagoCoachesScreenState();
}

class _PagoCoachesScreenState extends State<PagoCoachesScreen> {
  Map<String, dynamic>? _r;
  bool _ocupado = false;

  Sesion get s => widget.sesion;

  @override
  void initState() {
    super.initState();
    _llamar('ver');
  }

  Future<void> _llamar(String accion, [Map<String, dynamic>? regla]) async {
    setState(() => _ocupado = true);
    try {
      final r = await s.api.post('adminPagoCoaches', {'adminToken': s.adminToken, 'accion': accion, 'regla': ?(regla == null ? null : jsonEncode(regla))});
      if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo completar.'}');
      if (!mounted) return;
      setState(() => _r = r);
      if (accion != 'ver') _aviso(accion == 'recalcular' ? 'Recalculado' : 'Guardado y recalculado');
    } catch (e) {
      if (mounted) _aviso(e is ApiException ? e.message : 'No se pudo completar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _aviso(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  Map<String, dynamic> get _regla => Map<String, dynamic>.from(_r?['regla'] as Map? ?? const {});

  static String textoRegla(Map? x) {
    if (x == null) return 'Igual que la liga';
    return x['modo'] == 'fijo' ? '${plata((x['monto'] as num?) ?? 0)} por entrenamiento' : '${x['porcentaje']} % de lo cobrado';
  }

  /// Editar una regla (de la liga o de un equipo) en una subsección.
  Future<void> _editar({String? equipo}) async {
    final regla = _regla;
    final porEquipo = Map<String, dynamic>.from(regla['porEquipo'] as Map? ?? const {});
    final actual = Map<String, dynamic>.from((equipo == null ? regla['liga'] : porEquipo[equipo]) as Map? ?? (regla['liga'] as Map? ?? const {}));
    var propia = equipo == null || porEquipo.containsKey(equipo);
    var modo = '${actual['modo'] ?? 'porcentaje'}';
    final pct = TextEditingController(text: '${actual['porcentaje'] ?? 25}');
    final monto = TextEditingController(text: '${actual['monto'] ?? 0}');
    final ok = await abrirFormulario<bool>(
      context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(c).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(equipo == null ? 'Pago a coaches de la liga' : 'Pago a coaches de $equipo', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                equipo == null
                    ? 'Vale para toda la liga y para los equipos que no tienen una regla propia.'
                    : 'Vale para lo que pagan las personas de $equipo y para los entrenamientos marcados solo con ese equipo.',
                style: TextStyle(color: c.pivot.textoSecundario),
              ),
              if (equipo != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Regla propia para este equipo'),
                  value: propia,
                  onChanged: (v) => set(() => propia = v),
                ),
              ],
              if (propia) ...[
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'porcentaje', label: Text('Porcentaje')),
                    ButtonSegment(value: 'fijo', label: Text('Monto fijo')),
                  ],
                  selected: {modo},
                  onSelectionChanged: (v) => set(() => modo = v.first),
                ),
                const SizedBox(height: 12),
                if (modo == 'porcentaje')
                  TextField(
                    controller: pct,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Porcentaje de lo cobrado', suffixText: '%', helperText: 'De cada cuota y clase pagada, esta parte va a lxs coaches.'),
                  )
                else
                  TextField(
                    controller: monto,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Monto por entrenamiento', helperText: 'Lo que cobra cada coach por entrenamiento dado a horario.'),
                  ),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Guardar')),
            ],
          ),
        ),
      ),
    );
    final p = num.tryParse(pct.text.trim().replaceAll(',', '.')) ?? 0, m = num.tryParse(monto.text.trim().replaceAll(',', '.')) ?? 0;
    pct.dispose();
    monto.dispose();
    if (ok != true) return;
    final nueva = {'modo': modo, 'porcentaje': p, 'monto': m};
    if (equipo == null) {
      regla['liga'] = nueva;
    } else if (propia) {
      porEquipo[equipo] = nueva;
    } else {
      porEquipo.remove(equipo);
    }
    regla['porEquipo'] = porEquipo;
    await _llamar('guardarRegla', regla);
  }

  /// Pagarle a un coach lo que se le debe, todo o una parte (Victor, 2026-11-26):
  /// sale de una cuenta y baja lo que el equipo le debe.
  Future<void> _pagar(Map<String, dynamic> d) async {
    final cuentas = [for (final c in (_r?['cuentas'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
    if (cuentas.isEmpty) {
      _aviso('Primero crea una cuenta en Finanzas.');
      return;
    }
    final debe = (d['seLeDebe'] as num?) ?? 0;
    final monto = TextEditingController(text: debe.toStringAsFixed(2));
    final nota = TextEditingController(text: 'Pago a coaches');
    String cuenta = '${cuentas.first['id']}';
    final ok = await abrirFormulario<bool>(
      context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(c).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pagarle a ${d['nombre']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Hoy el equipo le debe ${plata(debe)}. Puedes pagarle todo o una parte; lo que quede se sigue acumulando.',
                style: TextStyle(color: c.pivot.textoSecundario),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: monto,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto que se le paga'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: cuenta,
                decoration: const InputDecoration(labelText: 'Sale de la cuenta'),
                items: [for (final x in cuentas) DropdownMenuItem(value: '${x['id']}', child: Text('${x['nombre']} · ${plata((x['saldo'] as num?) ?? 0)}'))],
                onChanged: (v) => set(() => cuenta = v ?? cuenta),
              ),
              const SizedBox(height: 12),
              TextField(controller: nota, decoration: const InputDecoration(labelText: 'Concepto')),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Registrar el pago')),
            ],
          ),
        ),
      ),
    );
    final m = num.tryParse(monto.text.trim().replaceAll(',', '.')) ?? 0, concepto = nota.text.trim();
    monto.dispose();
    nota.dispose();
    if (ok != true) return;
    if (!(m > 0) || m > debe + 0.001) {
      _aviso(m > debe ? 'No puede ser más de lo que se le debe (${plata(debe)}).' : 'Indica el monto.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      final r = await s.api.post('adminTesoreria', {
        'adminToken': s.adminToken,
        'accion': 'registrarSaldo',
        'datos': jsonEncode({'username': d['username'], 'tipo': 'devolucion', 'monto': m, 'cuentaId': cuenta, 'concepto': concepto.isEmpty ? 'Pago a coaches' : concepto, 'pagoCoach': true}),
      });
      if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo registrar.'}');
      if (mounted) _aviso('Pago registrado');
    } catch (e) {
      if (mounted) _aviso(e is ApiException ? e.message : 'No se pudo completar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    await _llamar('ver');
  }

  Future<void> _cambiar(void Function(Map<String, dynamic> r) f) async {
    final r = _regla;
    f(r);
    await _llamar('guardarRegla', r);
  }

  Future<void> _desdeCoach(String username, String nombre) async {
    final coaches = Map<String, dynamic>.from(_regla['coaches'] as Map? ?? const {});
    final actual = DateTime.tryParse('${(coaches[username] as Map?)?['desde'] ?? ''}') ?? DateTime.now();
    final d = await showDatePicker(context: context, initialDate: actual, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)), helpText: '¿Desde cuándo cobra $nombre?');
    if (d == null) return;
    final iso = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await _cambiar((r) => r['coaches'] = {...coaches, username: {'desde': iso}});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final r = _r;
    final regla = _regla;
    final meses = [for (final m in (r?['meses'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
    final totales = [for (final t in (r?['totales'] as List? ?? const [])) Map<String, dynamic>.from(t as Map)];
    final equipos = [for (final e in (r?['equipos'] as List? ?? const [])) '$e'];
    final porEquipo = Map<String, dynamic>.from(regla['porEquipo'] as Map? ?? const {});
    final coachesRegla = Map<String, dynamic>.from(regla['coaches'] as Map? ?? const {});
    final nombres = {for (final m in meses) for (final c in (m['coaches'] as List? ?? const [])) '${c['username']}': '${c['nombre']}'};
    for (final t in totales) {
      nombres['${t['username']}'] = '${t['nombre']}';
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Pago a coaches', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: _ocupado ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: r == null
          ? const Esqueleto(forma: FormaEsqueleto.ajustes)
          : AbsorbPointer(
              absorbing: _ocupado,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 40 + MediaQuery.paddingOf(context).bottom),
                children: [
                  const BannerAyuda(
                    clave: 'pago_coaches',
                    titulo: 'Cómo se calcula',
                    texto: 'Cada mes se junta la parte de lxs coaches de lo que pagaron las personas (cuotas del mes y clases) y se reparte por entrenamiento dado.',
                    pasos: [
                      (Icons.check_circle_outline_rounded, 'Cada entrenamiento se divide entre lxs coaches que estuvieron a horario. Quien llegó tarde cobra la mitad de su parte.'),
                      (Icons.event_busy_outlined, 'Entrenamientos cancelados o sin coaches en la lista no se pagan: esa parte queda para el equipo.'),
                      (Icons.person_add_alt_outlined, 'Un coach cobra desde la fecha en que empezó; si entra a mitad de mes, cobra solo los entrenamientos que dio.'),
                      (Icons.account_balance_wallet_outlined, 'Al cerrar cada mes, lo de cada coach queda en Saldos como "El equipo le debe". Nada sale de una cuenta hasta que se registra el pago.'),
                    ],
                  ),
                  GrupoAjustes(
                    titulo: 'REGLA',
                    filas: [
                      FilaAjuste(
                        icono: Icons.toggle_on_outlined,
                        seccion: 'entrenamientos',
                        titulo: 'Pagar a coaches',
                        valor: regla['activa'] == false ? 'Desactivado' : 'Activado',
                        derecha: Switch(value: regla['activa'] != false, onChanged: (v) => _cambiar((r) => r['activa'] = v)),
                      ),
                      FilaAjuste(
                        icono: Icons.percent_rounded,
                        seccion: 'recaudacion',
                        titulo: 'De toda la liga',
                        valor: textoRegla(regla['liga'] as Map?),
                        alTocar: () => _editar(),
                      ),
                      for (final e in equipos)
                        FilaAjuste(
                          icono: Icons.groups_rounded,
                          seccion: 'roles',
                          titulo: e,
                          valor: porEquipo.containsKey(e) ? textoRegla(porEquipo[e] as Map?) : 'Igual que la liga',
                          alTocar: () => _editar(equipo: e),
                        ),
                      FilaAjuste(
                        icono: Icons.receipt_long_outlined,
                        seccion: 'cuota',
                        titulo: 'Cuenta las cuotas',
                        derecha: Switch(
                          value: (regla['incluye'] as Map?)?['cuotas'] != false,
                          onChanged: (v) => _cambiar((r) => r['incluye'] = {...Map<String, dynamic>.from(r['incluye'] as Map? ?? const {}), 'cuotas': v}),
                        ),
                      ),
                      FilaAjuste(
                        icono: Icons.confirmation_number_outlined,
                        seccion: 'cuota',
                        titulo: 'Cuenta las clases sueltas',
                        derecha: Switch(
                          value: (regla['incluye'] as Map?)?['clases'] != false,
                          onChanged: (v) => _cambiar((r) => r['incluye'] = {...Map<String, dynamic>.from(r['incluye'] as Map? ?? const {}), 'clases': v}),
                        ),
                      ),
                      FilaAjuste(
                        icono: Icons.schedule_rounded,
                        seccion: 'entrenamientos',
                        titulo: 'Quien llega tarde cobra la mitad',
                        derecha: Switch(value: ((regla['tarde'] as num?) ?? 0.5) == 0.5, onChanged: (v) => _cambiar((r) => r['tarde'] = v ? 0.5 : 0)),
                      ),
                    ],
                  ),
                  if (coachesRegla.isNotEmpty || nombres.isNotEmpty)
                    GrupoAjustes(
                      titulo: 'DESDE CUÁNDO COBRA CADA COACH',
                      filas: [
                        for (final u in {...coachesRegla.keys, ...nombres.keys})
                          FilaAjuste(
                            icono: Icons.sports_rounded,
                            seccion: 'entrenamientos',
                            titulo: nombres[u] ?? u,
                            valor: (coachesRegla[u] as Map?)?['desde'] == null ? 'Desde que lo nombraron coach' : 'Desde el ${_fecha('${(coachesRegla[u] as Map)['desde']}')}',
                            alTocar: () => _desdeCoach(u, nombres[u] ?? u),
                          ),
                      ],
                    ),
                  if ((r['deuda'] as List? ?? const []).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('SE LES DEBE HOY', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario)),
                    const SizedBox(height: 4),
                    for (final d in [for (final x in (r['deuda'] as List)) Map<String, dynamic>.from(x as Map)])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.account_balance_wallet_outlined, color: p.marcaTexto),
                        title: Text('${d['nombre']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('Todo lo que el equipo le debe: ${plata((d['seLeDebe'] as num?) ?? 0)}'),
                        trailing: TextButton(onPressed: ((d['seLeDebe'] as num?) ?? 0) > 0 ? () => _pagar(d) : null, child: const Text('Pagarle')),
                      ),
                  ],
                  const SizedBox(height: 8),
                  Text('${r['anio']}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario)),
                  const SizedBox(height: 8),
                  for (final t in totales)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.sports_rounded, color: p.marcaTexto),
                      title: Text('${t['nombre']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('En el año, con el mes en curso estimado'),
                      trailing: Text(plata((t['monto'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  const SizedBox(height: 8),
                  for (final m in meses.reversed) _Mes(m: m),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => _llamar('recalcular'),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Recalcular los meses cerrados'),
                  ),
                ],
              ),
            ),
    );
  }

  static String _fecha(String iso) => iso.length >= 10 ? '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}' : iso;
}

class _Mes extends StatelessWidget {
  const _Mes({required this.m});
  final Map<String, dynamic> m;

  static const _meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final mes = '${m['mes']}';
    final n = int.tryParse(mes.length >= 7 ? mes.substring(5, 7) : '') ?? 1;
    final coaches = [for (final c in (m['coaches'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
    final cerrado = m['cerrado'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const Border(),
          title: Text('${_meses[n - 1]}${cerrado ? '' : ' (en curso)'}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${m['entrenamientos']} entrenamientos · ${m['cancelados']} cancelados · para coaches ${plata((m['paraCoaches'] as num?) ?? 0)}'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final d in (m['detalle'] as List? ?? const []))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  d['modo'] == 'fijo'
                      ? 'Monto fijo: ${d['entrenamientos']} entrenamientos → ${plata((d['repartido'] as num?) ?? 0)}'
                      : '${d['equipo']}: cobrado ${plata((d['cobrado'] as num?) ?? 0)} × ${d['porcentaje']} % = ${plata((d['bolsa'] as num?) ?? 0)}',
                  style: TextStyle(fontSize: 13, color: p.textoSecundario),
                ),
              ),
            for (final c in coaches)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${c['nombre']} · ${c['horario']} a horario${(c['tarde'] as num? ?? 0) > 0 ? ', ${c['tarde']} tarde' : ''}${(c['sinLista'] as num? ?? 0) > 0 ? ' (en partes iguales)' : ''}',
                    ),
                  ),
                  Text(plata((c['monto'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            if ((m['quedaEquipo'] as num? ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Queda para el equipo: ${plata(m['quedaEquipo'] as num)}', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
              ),
          ],
        ),
      ),
    );
  }
}
