import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/sincroniza.dart';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../ajustes/componentes.dart';
import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/fechas.dart';
import '../core/tema.dart';
import '../pivots/buscador_liga.dart';
import '../equipo/equipo_modelos.dart';
import '../equipo/equipo_repo.dart';
import '../eventos/widgets_comunes.dart';
import '../sesion/sesion.dart';
import '../pivots/categorias_screen.dart' show cambiarFondosViaje;
import 'cobros_screen.dart';
import 'tesoreria_repo.dart';
import '../core/vidrio.dart';
import '../core/moneda.dart';
import '../core/esqueleto.dart';

IconData _iconoCuenta(String t) => switch (t) {
  'efectivo' => Icons.payments_outlined,
  'deuna' => Icons.account_balance_wallet_outlined,
  'banco' => Icons.account_balance_outlined,
  _ => Icons.savings_outlined,
};

void _aviso(BuildContext context, String t) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(t)));

String _error(Object e) => e is ApiException ? e.message : 'No se pudo completar. Revisa tu conexión.';

/// Elegir una persona del equipo (buscador). Devuelve el username o null.
Future<Integrante?> elegirPersona(BuildContext context, Sesion s, {String titulo = '¿Quién?'}) {
  final equipo = EquipoRepo.de(s)..cargar();
  var q = '';
  return showModalBottomSheet<Integrante>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (h) => StatefulBuilder(
      builder: (h, set) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(h).height * 0.8,
          child: ListenableBuilder(
            listenable: equipo,
            builder: (h, _) {
              final gente = [
                for (final x in equipo.personas ?? const <Integrante>[])
                  if (q.isEmpty || x.nombreMostrar.toLowerCase().contains(q.toLowerCase())) x,
              ]..sort((a, b) => a.nombreMostrar.toLowerCase().compareTo(b.nombreMostrar.toLowerCase()));
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(titulo, style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'Buscar por nombre', prefixIcon: Icon(Icons.search_rounded), isDense: true),
                      onChanged: (v) => set(() => q = v.trim()),
                    ),
                  ),
                  Expanded(
                    child: equipo.personas == null
                        ? const Esqueleto(forma: FormaEsqueleto.lista, arriba: 8)
                        : ListView(
                            children: [
                              for (final x in gente)
                                ListTile(
                                  leading: AvatarPersona(nombre: x.nombreMostrar, foto: x.foto, tamano: 36),
                                  title: Text(x.nombreMostrar),
                                  onTap: () => Navigator.of(h).pop(x),
                                ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Mi perfil → Tesorería (Pivots con Finanzas).
class TesoreriaScreen extends StatefulWidget {
  const TesoreriaScreen({super.key, required this.sesion, this.resaltar});
  final Sesion sesion;

  /// Fila a resaltar al abrir (desde el buscador de Mi Liga).
  final String? resaltar;

  @override
  State<TesoreriaScreen> createState() => _TesoreriaScreenState();
}

class _TesoreriaScreenState extends State<TesoreriaScreen> {
  final _resaltado = ValueNotifier<String?>(null);
  bool _resaltadoHecho = false;

  @override
  void dispose() {
    _resaltado.dispose();
    super.dispose();
  }

  late final repo = TesoreriaRepo(widget.sesion);
  Map<String, dynamic>? _r;
  String? _error_;

  /// Personas con saldo (debe o a favor) para las tarjetas del inicio.
  List<Map<String, dynamic>> _saldos = const [];

  List<Map<String, dynamic>> get _todas => [for (final c in (_r?['cuentas'] as List? ?? const [])) c as Map<String, dynamic>];
  List<Map<String, dynamic>> get _cuentas => _todas.where((c) => c['archivada'] != true).toList();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final rF = repo.accion('resumen');
      final sF = repo.accion('saldos').then<Map<String, dynamic>?>((x) => x).catchError((Object _) => null);
      final r = await rF;
      final s = await sF;
      if (mounted) {
        setState(() {
          _r = r;
          if (s != null) _saldos = [for (final x in (s['personas'] as List? ?? const [])) x as Map<String, dynamic>];
          _error_ = null;
        });
        final x = widget.resaltar;
        if (x != null && !_resaltadoHecho) {
          _resaltadoHecho = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _resaltado.value = x);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error_ = _error(e));
    }
  }

  Future<void> _hacer(Future<Object?> Function() f, String ok) async {
    try {
      await f();
      if (mounted) _aviso(context, ok);
      await _cargar();
    } catch (e) {
      if (mounted) _aviso(context, _error(e));
    }
  }

  Future<void> _cuenta([Map<String, dynamic>? c]) async {
    final nombre = TextEditingController(text: c?['nombre'] as String? ?? '');
    final resp = TextEditingController(text: c?['responsable'] as String? ?? '');
    final saldo = TextEditingController(text: c == null ? '' : '${c['saldoInicial']}');
    var tipo = c?['tipo'] as String? ?? 'efectivo';
    var fecha = DateTime.tryParse('${c?['fechaInicial'] ?? ''}') ?? Fechas.hoy();
    var activa = c?['activa'] != false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (h) => StatefulBuilder(
        builder: (h, set) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(h).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(c == null ? 'Nueva cuenta' : 'Editar cuenta', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in tiposCuenta.entries)
                      ChoiceChip(
                        showCheckmark: false,
                        avatar: Icon(_iconoCuenta(e.key), size: 18),
                        label: Text(e.value),
                        selected: tipo == e.key,
                        onSelected: (_) => set(() {
                          tipo = e.key;
                          if (nombre.text.trim().isEmpty || tiposCuenta.values.contains(nombre.text.trim())) nombre.text = e.value;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nombre,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                if (tipo == 'efectivo') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: resp,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: '¿Quién tiene la caja?'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: saldo,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))],
                  decoration: InputDecoration(
                    labelText: 'Saldo inicial',
                    prefixText: '${Moneda.s} ',
                    helperText: 'Lo que la liga ya tenía en esta cuenta antes de usar Pivot.',
                    helperMaxLines: 3,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Desde el ${Fechas.corta(fecha)}'),
                  subtitle: const Text('Los movimientos se cuentan desde esa fecha.'),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final f = await showDatePicker(context: h, firstDate: DateTime(2020), lastDate: Fechas.hoy(), initialDate: fecha);
                    if (f != null) set(() => fecha = f);
                  },
                ),
                if (c != null)
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Activa'), value: activa, onChanged: (v) => set(() => activa = v)),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.of(h).pop(true), child: const Text('Guardar')),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _hacer(
      () => repo.accion('guardarCuenta', {
        'id': ?c?['id'],
        'nombre': nombre.text.trim(),
        'tipo': tipo,
        'responsable': resp.text.trim(),
        'saldoInicial': num.tryParse(saldo.text.replaceAll(',', '.')) ?? 0,
        'fechaInicial': isoFecha(fecha),
        'activa': activa,
      }),
      'Cuenta guardada',
    );
  }

  Future<void> _conciliar(Map<String, dynamic> c) async {
    final ctl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Conciliar ${c['nombre']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Según la app: ${plata(c['saldo'] as num)}. Escribe el saldo real (estado de cuenta, billetera virtual o lo que hay en la caja).'),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(prefixText: '${Moneda.s} '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(d).pop(ctl.text.replaceAll(',', '.')), child: const Text('Comparar')),
        ],
      ),
    );
    final n = num.tryParse(v ?? '');
    if (n == null || !mounted) return;
    try {
      final r = await repo.accion('conciliar', {'cuentaId': c['id'], 'saldoReal': n});
      final dif = (r['diferencia'] as num?) ?? 0;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(dif == 0 ? 'Cuadra' : 'Hay una diferencia'),
          content: Text(
            dif == 0
                ? 'El saldo real y el de la app coinciden.'
                : dif > 0
                ? 'Hay ${plata(dif)} más de lo registrado: puede faltar registrar un ingreso.'
                : 'Faltan ${plata(-dif)}: puede faltar registrar un gasto o hay un ingreso de más.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Entendido'))],
        ),
      );
      await _cargar();
    } catch (e) {
      if (mounted) _aviso(context, _error(e));
    }
  }

  Future<void> _opcionesCuenta(Map<String, dynamic> c) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (h) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.balance_rounded),
              title: const Text('Conciliar'),
              subtitle: const Text('Comparar con el saldo real'),
              onTap: () => Navigator.of(h).pop('c'),
            ),
            ListTile(leading: const Icon(Icons.list_alt_rounded), title: const Text('Ver movimientos'), onTap: () => Navigator.of(h).pop('m')),
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Editar cuenta'), onTap: () => Navigator.of(h).pop('e')),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Borrar cuenta'),
              subtitle: const Text('Si tiene movimientos, se archiva y el historial queda'),
              onTap: () => Navigator.of(h).pop('b'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (a) {
      case 'c':
        await _conciliar(c);
      case 'm':
        await _abrir(MovimientosScreen(repo: repo, cuentas: _cuentas, cuentaId: c['id'] as String?));
      case 'e':
        await _cuenta(c);
      case 'b':
        await _borrarCuenta(c);
    }
  }

  /// Borrar una cuenta creada por error; con movimientos se archiva (Victor, 2026-11-13).
  Future<void> _borrarCuenta(Map<String, dynamic> c) async {
    final saldo = (c['saldo'] as num?) ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿Borrar ${c['nombre']}?'),
        content: Text(
          [
            'Si la creaste por error y no tiene movimientos, se borra.',
            'Si ya tiene movimientos, se archiva: deja de aparecer y de sumar al total, pero su historial queda y la puedes recuperar.',
            if (saldo != 0) 'Ojo: todavía tiene ${plata(saldo)}. Si el dinero está en otra cuenta, regístralo antes con una transferencia.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await repo.accion('borrarCuenta', {'id': c['id']});
      if (mounted) _aviso(context, r['archivada'] == true ? '${c['nombre']} quedó archivada con su historial.' : '${c['nombre']} borrada.');
      await _cargar();
    } catch (e) {
      if (mounted) _aviso(context, _error(e));
    }
  }

  Future<void> _archivadas() async {
    final l = _todas.where((c) => c['archivada'] == true).toList();
    final r = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (h) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Cuentas archivadas', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            for (final c in l)
              ListTile(
                leading: Icon(_iconoCuenta('${c['tipo']}')),
                title: Text('${c['nombre']}'),
                subtitle: Text('Saldo ${plata(c['saldo'] as num)}'),
                trailing: TextButton(onPressed: () => Navigator.of(h).pop('${c['id']}'), child: const Text('Recuperar')),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (r == null) return;
    try {
      await repo.accion('restaurarCuenta', {'id': r});
      if (mounted) _aviso(context, 'Cuenta recuperada');
      await _cargar();
    } catch (e) {
      if (mounted) _aviso(context, _error(e));
    }
  }

  Future<void> _abrir(Widget w) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    await _cargar();
  }

  Future<void> _registrar(String tipo, {Map<String, dynamic>? corregir, String? desde}) async {
    final ok = await abrirFormularioMovimiento(context, repo: repo, cuentas: _cuentas, tipo: tipo, corregir: corregir, desdeCuenta: desde);
    if (ok == true) {
      if (mounted) _aviso(context, corregir != null ? 'Corregido: el original queda anulado en el historial.' : 'Registrado');
      await _cargar();
    }
  }

  /// Registro rápido (Victor, 2026-11-14): alguien pagó algo propio con una
  /// cuenta del equipo, o lo devuelve. Sale (o entra) de la cuenta y queda
  /// como deuda (o abono) de cada persona; entre varias se divide en partes iguales.
  Future<void> _plataDelEquipo({required bool devolver}) async {
    final p = context.pivot;
    final gente = <Integrante>[];
    String? cuenta = _cuentas.isEmpty ? null : '${_cuentas.first['id']}';
    final monto = TextEditingController(), concepto = TextEditingController(text: devolver ? 'Devolución' : '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (h) => StatefulBuilder(
        builder: (h, set) {
          final total = double.tryParse(monto.text.replaceAll(',', '.')) ?? 0;
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(h).bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    devolver ? 'Devolví plata al equipo' : 'Usé plata del equipo',
                    style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    devolver
                        ? 'Entra a la cuenta y baja lo que debe cada persona.'
                        : 'Sale de la cuenta del equipo y queda como deuda de cada persona. Si eliges a varias, se divide en partes iguales.',
                    style: TextStyle(color: p.textoSecundario),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final x in gente) InputChip(label: Text(x.nombreMostrar), onDeleted: () => set(() => gente.remove(x))),
                      ActionChip(
                        avatar: const Icon(Icons.person_add_alt_rounded, size: 18),
                        label: Text(gente.isEmpty ? '¿Quién?' : 'Agregar'),
                        onPressed: () async {
                          final x = await elegirPersona(h, repo.sesion);
                          if (x != null && !gente.any((g) => g.username == x.username)) set(() => gente.add(x));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: monto,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    onChanged: (_) => set(() {}),
                    decoration: InputDecoration(
                      labelText: 'Monto total',
                      prefixText: '${Moneda.s} ',
                      helperText: gente.length > 1 && total > 0 ? '${plata(total / gente.length)} cada persona' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: concepto,
                    decoration: const InputDecoration(labelText: '¿Para qué fue?'),
                  ),
                  const SizedBox(height: 14),
                  Text(devolver ? '¿A qué cuenta entra?' : '¿De qué cuenta salió?', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _cuentas)
                        ChoiceChip(
                          showCheckmark: false,
                          label: Text('${c['nombre']}'),
                          selected: cuenta == '${c['id']}',
                          onSelected: (_) => set(() => cuenta = '${c['id']}'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: gente.isEmpty || total <= 0 || cuenta == null || concepto.text.trim().isEmpty ? null : () => Navigator.of(h).pop(true),
                    child: const Text('Registrar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    final total = double.tryParse(monto.text.replaceAll(',', '.')) ?? 0;
    // Partes iguales al centavo; el último se lleva el redondeo.
    final parte = (total / gente.length * 100).floorToDouble() / 100;
    try {
      for (var i = 0; i < gente.length; i++) {
        final m = i == gente.length - 1 ? double.parse((total - parte * (gente.length - 1)).toStringAsFixed(2)) : parte;
        await repo.accion('registrarSaldo', {
          'username': gente[i].username,
          'tipo': devolver ? 'abono' : 'prestamo',
          'monto': m,
          'concepto': concepto.text.trim(),
          'cuentaId': cuenta,
          'aplicar': 'aparte',
        });
      }
      if (mounted) _aviso(context, devolver ? 'Registrado: baja lo que deben.' : 'Registrado: queda como deuda con el equipo.');
    } catch (e) {
      if (mounted) _aviso(context, _error(e));
    }
    await _cargar();
  }

  // Lo frecuente vive en la pantalla (Victor, 2026-11-14): el botón flotante
  // solo crea cuentas.
  void _mas() => _cuenta();

  /// Ingreso/Egreso y los dos registros rápidos, debajo de la tarjeta roja.
  Widget _acciones(BuildContext context) {
    final p = context.pivot;
    Widget chico(IconData i, String t, VoidCallback f) => Expanded(
      child: OutlinedButton.icon(
        onPressed: f,
        icon: Icon(i, size: 18),
        label: Text(t, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), foregroundColor: p.texto),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _registrar('ingreso'),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Ingreso'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _registrar('egreso'),
                icon: const Icon(Icons.remove_circle_outline_rounded),
                label: const Text('Egreso'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            chico(Icons.shopping_bag_outlined, 'Usé plata del equipo', () => _plataDelEquipo(devolver: false)),
            const SizedBox(width: 10),
            chico(Icons.undo_rounded, 'Devolví plata al equipo', () => _plataDelEquipo(devolver: true)),
          ],
        ),
      ],
    );
  }

  /// Tarjetas de quién debe o tiene a favor; la última abre la lista completa.
  Widget _tarjetasSaldos(BuildContext context, PivotPaleta p) {
    final l = _saldos;
    Future<void> abrirPersona(Map<String, dynamic> x) async {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SaldoPersonaScreen(repo: repo, cuentas: _cuentas, username: '${x['username']}', nombre: '${x['nombre']}'),
        ),
      );
      await _cargar();
    }

    Widget tarjeta({required Widget child, required VoidCallback alTocar}) => Material(
      color: p.tarjeta,
      borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
      child: InkWell(
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        onTap: alTocar,
        child: Container(width: 132, padding: const EdgeInsets.all(12), child: child),
      ),
    );

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Las tarjetas llegan al borde de la pantalla al deslizar (Victor, 2026-11-16).
        clipBehavior: Clip.none,
        itemCount: l.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == l.length) {
            return tarjeta(
              alTocar: () async {
                await _abrir(SaldosScreen(repo: repo, cuentas: _cuentas));
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(l.isEmpty ? Icons.person_add_alt_rounded : Icons.people_alt_outlined, color: p.marcaTexto),
                  const SizedBox(height: 8),
                  Text(
                    l.isEmpty ? 'Nadie debe. Registrar un saldo' : 'Ver todas',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                  ),
                ],
              ),
            );
          }
          final x = l[i];
          final s = (x['saldo'] as num?) ?? 0;
          return tarjeta(
            alTocar: () => abrirPersona(x),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarPersona(nombre: '${x['nombre']}', foto: '${x['foto'] ?? ''}', tamano: 34),
                const Spacer(),
                Text(
                  '${x['nombre']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                ),
                Text(
                  s < 0 ? 'Debe ${plata(-s)}' : 'A favor ${plata(s)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: s < 0 ? p.marcaTexto : p.textoSecundario),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _titulo(String t, PivotPaleta p) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
    child: Text(
      t,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
    ),
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
        title: const Text('Finanzas', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [LupaSeccion(seccion: 'tesoreria', donde: 'Finanzas', resaltado: _resaltado)],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: r == null
            ? _error_ == null
                  ? const Esqueleto(forma: FormaEsqueleto.tarjetas, key: ValueKey('c'))
                  : Center(key: const ValueKey('e'), child: Text(_error_!))
            : Sincroniza(
                key: const ValueKey('l'),
                onRefresh: _cargar,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
                  children: _cuentas.isEmpty ? _vacio(context) : _contenido(context, r, p),
                ),
              ),
      ),
      floatingActionButton: r == null ? null : FloatingActionButton(tooltip: 'Nueva cuenta', onPressed: _mas, child: const Icon(Icons.add_rounded)),
    );
  }

  List<Widget> _vacio(BuildContext context) {
    final p = context.pivot;
    return [
      const SizedBox(height: 40),
      Icon(Icons.account_balance_wallet_outlined, size: 56, color: p.marcaTexto),
      const SizedBox(height: 12),
      Text(
        'Empieza creando las cuentas de la liga',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.texto),
      ),
      const SizedBox(height: 8),
      Text(
        'Efectivo, billeteras virtuales y cuentas bancarias. El saldo inicial es lo que la liga ya tenía. Desde ahí, cada pago aprobado entra a su cuenta.',
        textAlign: TextAlign.center,
        style: TextStyle(color: p.textoSecundario),
      ),
      const SizedBox(height: 20),
      Center(
        child: FilledButton.icon(onPressed: () => _cuenta(), icon: const Icon(Icons.add_rounded), label: const Text('Crear cuenta')),
      ),
    ];
  }

  List<Widget> _contenido(BuildContext context, Map<String, dynamic> r, PivotPaleta p) {
    final mes = (r['mes'] as Map?) ?? const {};
    final saldos = (r['saldos'] as Map?) ?? const {};
    final movs = [for (final m in (r['movimientos'] as List? ?? const [])) m as Map<String, dynamic>];
    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: PivotPaleta.degradadoMarca, borderRadius: BorderRadius.circular(PivotRadios.grande)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total en cuentas', style: TextStyle(color: PivotPaleta.sobreSeccion.withValues(alpha: 0.85))),
            Text(
              plata((r['total'] as num?) ?? 0),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: PivotPaleta.sobreSeccion),
            ),
            const SizedBox(height: 4),
            Text(
              'Este mes: +${plata((mes['ingresos'] as num?) ?? 0)} · −${plata((mes['egresos'] as num?) ?? 0)}',
              style: TextStyle(color: PivotPaleta.sobreSeccion.withValues(alpha: 0.9)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _acciones(context),
      _titulo('CUENTAS', p),
      SizedBox(
        height: 148,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // Las tarjetas llegan al borde de la pantalla al deslizar (Victor, 2026-11-16).
          clipBehavior: Clip.none,
          itemCount: _cuentas.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final c = _cuentas[i];
            final conc = c['conciliacion'] as Map?;
            return Material(
              color: c['activa'] == false ? p.apagadoFondo : p.tarjeta,
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              child: InkWell(
                borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                onTap: () => _opcionesCuenta(c),
                child: Container(
                  width: 190,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_iconoCuenta('${c['tipo']}'), size: 20, color: p.marcaTexto),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${c['nombre']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Transferir desde la tarjeta (Victor, 2026-11-14): en
                      // las cuentas que no son efectivo.
                      if ('${c['tipo']}' != 'efectivo' && c['activa'] != false && _cuentas.length > 1)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _registrar('transferencia', desde: '${c['id']}'),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                            label: const Text('Transferir'),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                          ),
                        ),
                      Text(
                        plata(c['saldo'] as num),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: p.texto),
                      ),
                      Text(
                        conc == null
                            ? ('${c['responsable'] ?? ''}'.isNotEmpty ? 'La tiene ${c['responsable']}' : 'Sin conciliar')
                            : ((conc['diferencia'] as num) == 0 ? 'Cuadró el ${_corta('${conc['fecha']}')}' : 'Diferencia ${plata(conc['diferencia'] as num)}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.textoSecundario),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      Resaltable(
        id: 'saldos',
        resaltado: _resaltado,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titulo(
              (saldos['personasDeben'] as num? ?? 0) == 0
                  ? 'SALDOS DE PERSONAS'
                  : 'SALDOS DE PERSONAS · ${saldos['personasDeben']} ${saldos['personasDeben'] == 1 ? 'DEBE' : 'DEBEN'} ${plata((saldos['totalDeben'] as num?) ?? 0)}',
              p,
            ),
            _tarjetasSaldos(context, p),
          ],
        ),
      ),
      _titulo('ADMINISTRAR', p),
      // Formas de pago viven en Tesorería (Victor, 2026-11-14): cada medio es una cuenta.
      Resaltable(
        id: 'formasTesoreria',
        resaltado: _resaltado,
        child: _fila(
          context,
          Icons.payments_outlined,
          'Cobros',
          'Mensualidad, valor por clase, formas de pago y fecha límite',
          () => _abrir(CobrosScreen(sesion: widget.sesion)),
        ),
      ),
      Resaltable(
        id: 'cuotas',
        resaltado: _resaltado,
        child: _fila(
          context,
          Icons.receipt_long_outlined,
          'Cuotas del mes',
          'Quién pagó, cuánto, cuándo y con qué medio',
          () => _abrir(CuotasMesScreen(repo: repo)),
        ),
      ),

      Resaltable(
        id: 'movimientos',
        resaltado: _resaltado,
        child: _fila(
          context,
          Icons.manage_search_rounded,
          'Todos los movimientos',
          'Filtrar y exportar',
          () => _abrir(MovimientosScreen(repo: repo, cuentas: _todas)),
        ),
      ),
      if (_todas.any((c) => c['archivada'] == true))
        _fila(context, Icons.inventory_outlined, 'Cuentas archivadas', '${_todas.where((c) => c['archivada'] == true).length} con su historial', _archivadas),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: p.tarjeta,
          borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            secondary: Icon(Icons.visibility_outlined, color: p.marcaTexto),
            title: const Text('Transparencia', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('El equipo ve totales y en qué se gasta. Nunca pagos ni deudas de otras personas.'),
            value: r['transparencia'] == true,
            onChanged: (v) => _hacer(() => repo.accion('transparencia', {'activa': v}), v ? 'El equipo ya ve los totales' : 'Solo Pivots ven Finanzas'),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Text(
          'ÚLTIMOS MOVIMIENTOS',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
        ),
      ),
      if (movs.isEmpty) Text('Todavía no hay movimientos.', style: TextStyle(color: p.textoSecundario)),
      for (final m in movs)
        FilaMovimiento(
          m: m,
          alTocar: () => detalleMovimiento(
            context,
            repo,
            m,
            alCorregir: () => _registrar('${m['tipo']}', corregir: m),
            alCambiar: _cargar,
          ),
        ),
    ];
  }

  Widget _fila(BuildContext context, IconData i, String t, String s, VoidCallback f) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(i, color: p.marcaTexto),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(s),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: f,
        ),
      ),
    );
  }
}

String _corta(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : Fechas.corta(d);
}

class FilaMovimiento extends StatelessWidget {
  const FilaMovimiento({super.key, required this.m, required this.alTocar});
  final Map<String, dynamic> m;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final tipo = '${m['tipo']}';
    final anulado = m['anulado'] == true;
    final signo = tipo == 'ingreso' ? '+' : (tipo == 'egreso' ? '−' : '');
    final titulo = '${m['descripcion'] ?? ''}'.isNotEmpty
        ? '${m['descripcion']}'
        : (tipo == 'transferencia' ? 'Transferencia' : (categoriasTesoreria['${m['categoria']}'] ?? 'Movimiento'));
    final sub = [
      _corta('${m['fecha']}'),
      if (tipo == 'transferencia') '${m['cuenta']} → ${m['cuentaDestino']}' else '${m['cuenta']}',
      if (m['personaNombre'] != null) '${m['personaNombre']}',
      if (anulado) 'Anulado${m['motivoAnulacion'] != null ? ': ${m['motivoAnulacion']}' : ''}',
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: p.suave,
        child: Icon(
          tipo == 'ingreso' ? Icons.south_west_rounded : (tipo == 'egreso' ? Icons.north_east_rounded : Icons.swap_horiz_rounded),
          color: p.sobreSuave,
          size: 20,
        ),
      ),
      title: Text(
        titulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w600, color: anulado ? p.apagado : p.texto, decoration: anulado ? TextDecoration.lineThrough : null),
      ),
      subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '$signo${plata(m['monto'] as num)}',
        style: TextStyle(fontWeight: FontWeight.w800, color: anulado ? p.apagado : (tipo == 'egreso' ? p.marcaTexto : p.texto)),
      ),
      onTap: alTocar,
    );
  }
}

/// Detalle de un movimiento: anular (con motivo) o corregir (anula y registra de nuevo).
Future<void> detalleMovimiento(
  BuildContext context,
  TesoreriaRepo repo,
  Map<String, dynamic> m, {
  required VoidCallback alCorregir,
  required Future<void> Function() alCambiar,
}) async {
  if (m['anulado'] == true) {
    _aviso(context, 'Este movimiento está anulado: se conserva en el historial.');
    return;
  }
  final a = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (h) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(plata(m['monto'] as num), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            subtitle: Text(
              [
                categoriasTesoreria['${m['categoria']}'] ?? '',
                '${m['descripcion'] ?? ''}',
                if (m['origen'] != 'manual') 'Registrado automáticamente',
              ].where((x) => x.isNotEmpty).join(' · '),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Corregir'),
            subtitle: const Text('Se anula y se registra de nuevo'),
            onTap: () => Navigator.of(h).pop('c'),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded),
            title: const Text('Anular'),
            subtitle: const Text('Queda en el historial, no cuenta en los saldos'),
            onTap: () => Navigator.of(h).pop('a'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (a == 'c') alCorregir();
  if (a == 'a') {
    final ctl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Anular el movimiento?'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.of(d).pop(ctl.text.trim()), child: const Text('Anular')),
        ],
      ),
    );
    if (motivo == null || !context.mounted) return;
    try {
      await repo.accion('anular', {'id': m['id'], 'motivo': motivo});
      if (context.mounted) _aviso(context, 'Anulado');
      await alCambiar();
    } catch (e) {
      if (context.mounted) _aviso(context, _error(e));
    }
  }
}

/// Ingreso, gasto o transferencia (también para corregir uno existente).
Future<bool?> abrirFormularioMovimiento(
  BuildContext context, {
  required TesoreriaRepo repo,
  required List<Map<String, dynamic>> cuentas,
  required String tipo,
  Map<String, dynamic>? corregir,
  String? desdeCuenta,
}) {
  final activas = cuentas.where((c) => c['activa'] != false).toList();
  final monto = TextEditingController(text: corregir == null ? '' : '${corregir['monto']}');
  final desc = TextEditingController(text: corregir?['descripcion'] as String? ?? '');
  String? cuenta = corregir?['cuentaId'] as String? ?? desdeCuenta ?? (activas.isEmpty ? null : activas.first['id'] as String);
  String? destino;
  var categoria = corregir?['categoria'] as String? ?? (tipo == 'ingreso' ? 'cuota' : 'otro');
  var fecha = DateTime.tryParse('${corregir?['fecha'] ?? ''}') ?? Fechas.hoy();
  String? persona = corregir?['persona'] as String?;
  String? personaNombre = corregir?['personaNombre'] as String?;
  var ocupado = false;
  final titulo = switch (tipo) {
    'ingreso' => corregir == null ? 'Ingreso' : 'Corregir ingreso',
    'egreso' => corregir == null ? 'Gasto' : 'Corregir gasto',
    _ => 'Transferencia entre cuentas',
  };
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (h) => StatefulBuilder(
      builder: (h, set) {
        final p = h.pivot;
        Widget etiqueta(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            t,
            style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
          ),
        );
        Future<void> guardar() async {
          final n = num.tryParse(monto.text.replaceAll(',', '.'));
          if (n == null || n <= 0) {
            _aviso(h, 'Escribe el monto.');
            return;
          }
          set(() => ocupado = true);
          final datos = <String, Object?>{
            'tipo': tipo,
            'monto': n,
            'cuentaId': cuenta,
            'cuentaDestinoId': destino,
            'categoria': categoria,
            'descripcion': desc.text.trim(),
            'fecha': isoFecha(fecha),
            'persona': persona,
          };
          try {
            if (corregir != null) {
              await repo.accion('corregir', {'id': corregir['id'], 'motivo': 'Corrección', 'nuevo': datos});
            } else {
              await repo.accion('registrar', datos);
            }
            if (h.mounted) Navigator.of(h).pop(true);
          } catch (e) {
            set(() => ocupado = false);
            if (h.mounted) _aviso(h, _error(e));
          }
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(h).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(titulo, style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: monto,
                  autofocus: corregir == null,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(prefixText: '${Moneda.s} ', hintText: '0,00'),
                ),
                etiqueta(tipo == 'transferencia' ? 'Desde' : (tipo == 'ingreso' ? '¿A qué cuenta entró?' : '¿De qué cuenta salió?')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in activas)
                      ChoiceChip(
                        showCheckmark: false,
                        avatar: Icon(_iconoCuenta('${c['tipo']}'), size: 18),
                        label: Text('${c['nombre']}'),
                        selected: cuenta == c['id'],
                        onSelected: (_) => set(() => cuenta = c['id'] as String),
                      ),
                  ],
                ),
                if (tipo == 'transferencia') ...[
                  etiqueta('Hacia'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in activas)
                        if (c['id'] != cuenta)
                          ChoiceChip(
                            showCheckmark: false,
                            avatar: Icon(_iconoCuenta('${c['tipo']}'), size: 18),
                            label: Text('${c['nombre']}'),
                            selected: destino == c['id'],
                            onSelected: (_) => set(() => destino = c['id'] as String),
                          ),
                    ],
                  ),
                ] else ...[
                  etiqueta('Categoría'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in categoriasTesoreria.entries)
                        ChoiceChip(label: Text(e.value), selected: categoria == e.key, onSelected: (_) => set(() => categoria = e.key)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: Text(Fechas.corta(fecha)),
                  onTap: () async {
                    final f = await showDatePicker(context: h, firstDate: DateTime(2020), lastDate: Fechas.hoy(), initialDate: fecha);
                    if (f != null) set(() => fecha = f);
                  },
                ),
                if (tipo != 'transferencia')
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text(personaNombre ?? 'Persona (opcional)'),
                    trailing: persona == null
                        ? null
                        : IconButton(
                            tooltip: 'Quitar',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => set(() {
                              persona = null;
                              personaNombre = null;
                            }),
                          ),
                    onTap: () async {
                      final x = await elegirPersona(h, repo.sesion);
                      if (x != null) {
                        set(() {
                          persona = x.username;
                          personaNombre = x.nombreMostrar;
                        });
                      }
                    },
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: ocupado || cuenta == null || (tipo == 'transferencia' && destino == null) ? null : guardar,
                  child: Text(corregir != null ? 'Corregir' : 'Registrar'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Todos los movimientos con filtros y exportación a CSV (Excel lo abre).
class MovimientosScreen extends StatefulWidget {
  const MovimientosScreen({super.key, required this.repo, required this.cuentas, this.cuentaId});
  final TesoreriaRepo repo;
  final List<Map<String, dynamic>> cuentas;
  final String? cuentaId;

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
  late String? _cuenta = widget.cuentaId;
  String? _tipo, _categoria, _persona, _personaNombre;
  DateTimeRange? _rango;
  bool _anulados = false;
  List<Map<String, dynamic>>? _movs;
  Map<String, dynamic> _totales = const {};

  @override
  void initState() {
    super.initState();
    final h = Fechas.hoy();
    _rango = DateTimeRange(start: DateTime(h.year, h.month, 1), end: h);
    _cargar();
  }

  Map<String, Object?> get _filtros => {
    if (_rango != null) 'desde': isoFecha(_rango!.start),
    if (_rango != null) 'hasta': isoFecha(_rango!.end),
    'cuentaId': ?_cuenta,
    'tipo': ?_tipo,
    'categoria': ?_categoria,
    'persona': ?_persona,
    'incluirAnulados': _anulados,
  };

  Future<void> _cargar() async {
    setState(() => _movs = null);
    try {
      final r = await widget.repo.accion('movimientos', _filtros);
      if (!mounted) return;
      setState(() {
        _movs = [for (final m in (r['movimientos'] as List? ?? const [])) m as Map<String, dynamic>];
        _totales = (r['totales'] as Map<String, dynamic>?) ?? const {};
      });
    } catch (e) {
      if (mounted) {
        setState(() => _movs = const []);
        _aviso(context, _error(e));
      }
    }
  }

  Future<void> _exportar() async {
    try {
      final r = await widget.repo.accion('exportar', _filtros);
      final bytes = utf8.encode('${r['csv'] ?? ''}');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'text/csv', name: 'tesoreria.csv')],
          fileNameOverrides: ['tesoreria-${isoFecha(Fechas.hoy())}.csv'],
          subject: 'Movimientos de Finanzas',
        ),
      );
    } catch (e) {
      if (mounted) _aviso(context, _error(e));
    }
  }

  String _textoRango() {
    final r = _rango;
    if (r == null) return 'Todo';
    return '${Fechas.corta(r.start)} – ${Fechas.corta(r.end)}';
  }

  Future<void> _elegirRango() async {
    final h = Fechas.hoy();
    final opciones = {
      'Este mes': DateTimeRange(start: DateTime(h.year, h.month, 1), end: h),
      'Mes pasado': DateTimeRange(start: DateTime(h.year, h.month - 1, 1), end: DateTime(h.year, h.month, 0)),
      'Este año': DateTimeRange(start: DateTime(h.year, 1, 1), end: h),
    };
    final v = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in opciones.entries) ListTile(title: Text(e.key), onTap: () => Navigator.of(s).pop(e.value)),
            ListTile(title: const Text('Todo'), onTap: () => Navigator.of(s).pop('todo')),
            ListTile(title: const Text('Elegir fechas'), trailing: const Icon(Icons.date_range_rounded), onTap: () => Navigator.of(s).pop('elegir')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || v == null) return;
    if (v == 'todo') {
      _rango = null;
    } else if (v == 'elegir') {
      final r = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: h, initialDateRange: _rango);
      if (r == null) return;
      _rango = r;
    } else {
      _rango = v as DateTimeRange;
    }
    _cargar();
  }

  Future<void> _elegir(String titulo, Map<String?, String> opciones, void Function(String?) alElegir) async {
    final v = await showModalBottomSheet<(String?,)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (s) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(titulo, style: Theme.of(s).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final e in opciones.entries) ListTile(title: Text(e.value), onTap: () => Navigator.of(s).pop((e.key,))),
          ],
        ),
      ),
    );
    if (v == null) return;
    alElegir(v.$1);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final movs = _movs;
    final nombreCuenta = widget.cuentas.where((c) => c['id'] == _cuenta).map((c) => '${c['nombre']}').firstOrNull;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Movimientos', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(tooltip: 'Exportar a CSV (Excel)', onPressed: _exportar, icon: const Icon(Icons.ios_share_rounded))],
      ),
      body: Column(
        children: [
          SizedBox(height: altoBarra(context)),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              children: [
                ActionChip(avatar: const Icon(Icons.date_range_rounded, size: 18), label: Text(_textoRango()), onPressed: _elegirRango),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(nombreCuenta ?? 'Todas las cuentas'),
                  onPressed: () => _elegir('Cuenta', {null: 'Todas', for (final c in widget.cuentas) c['id'] as String: '${c['nombre']}'}, (v) => _cuenta = v),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(switch (_tipo) {
                    'ingreso' => 'Ingresos',
                    'egreso' => 'Gastos',
                    'transferencia' => 'Transferencias',
                    _ => 'Todos los tipos',
                  }),
                  onPressed: () =>
                      _elegir('Tipo', {null: 'Todos', 'ingreso': 'Ingresos', 'egreso': 'Gastos', 'transferencia': 'Transferencias'}, (v) => _tipo = v),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(_categoria == null ? 'Todas las categorías' : categoriasTesoreria[_categoria] ?? ''),
                  onPressed: () => _elegir('Categoría', {null: 'Todas', ...categoriasTesoreria}, (v) => _categoria = v),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(_personaNombre ?? 'Cualquier persona'),
                  onPressed: () async {
                    if (_persona != null) {
                      setState(() => (_persona = null, _personaNombre = null));
                      _cargar();
                      return;
                    }
                    final x = await elegirPersona(context, widget.repo.sesion);
                    if (x == null) return;
                    setState(() => (_persona = x.username, _personaNombre = x.nombreMostrar));
                    _cargar();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Ver anulados'),
                  selected: _anulados,
                  onSelected: (v) {
                    _anulados = v;
                    _cargar();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(
              children: [
                Text(
                  'Ingresos ${plata((_totales['ingresos'] as num?) ?? 0)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                ),
                const Spacer(),
                Text(
                  'Gastos ${plata((_totales['egresos'] as num?) ?? 0)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.marcaTexto),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: movs == null
                  ? const Esqueleto(forma: FormaEsqueleto.lista, arriba: 8)
                  : movs.isEmpty
                  ? Center(
                      child: Text('Sin movimientos con estos filtros.', style: TextStyle(color: p.textoSecundario)),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
                      children: [
                        for (final m in movs)
                          FilaMovimiento(
                            m: m,
                            alTocar: () => detalleMovimiento(
                              context,
                              widget.repo,
                              m,
                              alCambiar: _cargar,
                              alCorregir: () async {
                                final ok = await abrirFormularioMovimiento(
                                  context,
                                  repo: widget.repo,
                                  cuentas: widget.cuentas,
                                  tipo: '${m['tipo']}',
                                  corregir: m,
                                );
                                if (ok == true) _cargar();
                              },
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Saldos con el equipo: quién debe (préstamos, merch…) y quién tiene a favor.
class SaldosScreen extends StatefulWidget {
  const SaldosScreen({super.key, required this.repo, required this.cuentas});
  final TesoreriaRepo repo;
  final List<Map<String, dynamic>> cuentas;

  @override
  State<SaldosScreen> createState() => _SaldosScreenState();
}

class _SaldosScreenState extends State<SaldosScreen> {
  List<Map<String, dynamic>>? _personas;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.repo.accion('saldos');
      if (mounted) setState(() => _personas = [for (final x in (r['personas'] as List? ?? const [])) x as Map<String, dynamic>]);
    } catch (e) {
      if (mounted) {
        setState(() => _personas = const []);
        _aviso(context, _error(e));
      }
    }
  }

  Future<void> _abrir(String username, String nombre) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SaldoPersonaScreen(repo: widget.repo, cuentas: widget.cuentas, username: username, nombre: nombre),
      ),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _personas;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Saldos de personas', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: l == null
          ? const Esqueleto(forma: FormaEsqueleto.lista)
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
              children: [
                Text(
                  'Préstamos, merch o pagos de más: aparte de la cuota. Al cobrar la cuota se avisa y se elige cómo aplicarlo.',
                  style: TextStyle(fontSize: 13, color: p.textoSecundario),
                ),
                const SizedBox(height: 8),
                if (l.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text('Nadie tiene saldo pendiente.', style: TextStyle(color: p.textoSecundario)),
                  ),
                for (final x in l)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AvatarPersona(nombre: '${x['nombre']}', foto: '${x['foto'] ?? ''}', tamano: 40),
                    title: Text('${x['nombre']}${x['sinCuenta'] == true ? ' (cuenta eliminada)' : ''}'),
                    subtitle: Text((x['saldo'] as num) < 0 ? 'Debe al equipo' : 'Tiene a favor'),
                    trailing: Text(
                      plata((x['saldo'] as num).abs()),
                      style: TextStyle(fontWeight: FontWeight.w800, color: (x['saldo'] as num) < 0 ? p.marcaTexto : p.texto),
                    ),
                    onTap: () => _abrir('${x['username']}', '${x['nombre']}'),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Registrar saldo',
        onPressed: () async {
          final x = await elegirPersona(context, widget.repo.sesion, titulo: '¿De quién es el saldo?');
          if (x != null) await _abrir(x.username, x.nombreMostrar);
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class SaldoPersonaScreen extends StatefulWidget {
  const SaldoPersonaScreen({super.key, required this.repo, required this.cuentas, required this.username, required this.nombre});
  final TesoreriaRepo repo;
  final List<Map<String, dynamic>> cuentas;
  final String username, nombre;

  @override
  State<SaldoPersonaScreen> createState() => _SaldoPersonaScreenState();
}

class _SaldoPersonaScreenState extends State<SaldoPersonaScreen> {
  Map<String, dynamic>? _r;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.repo.accion('saldoPersona', {'username': widget.username});
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (mounted) _aviso(context, _error(e));
    }
  }

  static const _tipos = {
    'cargo': ('Debe al equipo', 'Ej. merch que se llevó sin pagar.', Icons.call_made_rounded),
    'prestamo': ('Préstamo del equipo', 'El equipo le prestó dinero: sale de una cuenta.', Icons.handshake_outlined),
    'abono': ('Paga lo que debe', 'Entra a una cuenta y baja su deuda.', Icons.call_received_rounded),
    'a_favor': ('Tiene a favor', 'Ej. pagó de más o puso dinero por el equipo.', Icons.savings_outlined),
  };

  Future<void> _registrar() async {
    var tipo = 'cargo';
    final monto = TextEditingController(), concepto = TextEditingController(), porCuota = TextEditingController();
    String? cuenta;
    var aplicar = 'aparte';
    final activas = widget.cuentas.where((c) => c['activa'] != false).toList();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (h) => StatefulBuilder(
        builder: (h, set) {
          final mueveDinero = tipo == 'prestamo' || tipo == 'abono';
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(h).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.nombre, style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final e in _tipos.entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      selected: tipo == e.key,
                      onTap: () => set(() => tipo = e.key),
                      title: Text(e.value.$1),
                      subtitle: Text(e.value.$2),
                      leading: Icon(e.value.$3),
                      trailing: tipo == e.key ? const Icon(Icons.check_rounded) : null,
                    ),
                  TextField(
                    controller: monto,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Monto', prefixText: '${Moneda.s} '),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: concepto,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Concepto'),
                  ),
                  if (mueveDinero || tipo == 'a_favor') ...[
                    const SizedBox(height: 12),
                    Text(
                      tipo == 'prestamo' ? '¿De qué cuenta salió?' : (tipo == 'a_favor' ? '¿Entró dinero a una cuenta? (opcional)' : '¿A qué cuenta entró?'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in activas)
                          ChoiceChip(
                            label: Text('${c['nombre']}'),
                            selected: cuenta == c['id'],
                            onSelected: (v) => set(() => cuenta = v ? c['id'] as String : null),
                          ),
                      ],
                    ),
                  ],
                  if (tipo != 'abono') ...[
                    const SizedBox(height: 12),
                    const Text('¿Cómo se aplica?', style: TextStyle(fontWeight: FontWeight.w700)),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(label: const Text('Aparte'), selected: aplicar == 'aparte', onSelected: (_) => set(() => aplicar = 'aparte')),
                        ChoiceChip(
                          label: const Text('Junto con la cuota'),
                          selected: aplicar == 'con_cuota',
                          onSelected: (_) => set(() => aplicar = 'con_cuota'),
                        ),
                        ChoiceChip(label: const Text('En cuotas'), selected: aplicar == 'cuotas', onSelected: (_) => set(() => aplicar = 'cuotas')),
                      ],
                    ),
                    if (aplicar == 'cuotas')
                      TextField(
                        controller: porCuota,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Monto por mes', prefixText: '${Moneda.s} '),
                      ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(onPressed: mueveDinero && cuenta == null ? null : () => Navigator.of(h).pop(true), child: const Text('Registrar')),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await widget.repo.accion('registrarSaldo', {
        'username': widget.username,
        'tipo': tipo,
        'monto': num.tryParse(monto.text.replaceAll(',', '.')) ?? 0,
        'concepto': concepto.text.trim(),
        'cuentaId': cuenta,
        'aplicar': aplicar,
        'montoPorCuota': num.tryParse(porCuota.text.replaceAll(',', '.')),
      });
      if (mounted) _aviso(context, 'Registrado');
      await _cargar();
    } catch (e) {
      if (mounted) _aviso(context, _error(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final r = _r;
    final saldo = (r?['saldo'] as num?) ?? 0;
    final movs = [for (final m in (r?['movimientos'] as List? ?? const [])) m as Map<String, dynamic>];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: Text(widget.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: r == null
          ? const Esqueleto(forma: FormaEsqueleto.lista)
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
              children: [
                Center(
                  child: Text(
                    saldo == 0 ? 'Sin saldo' : (saldo < 0 ? 'Debe ${plata(-saldo)}' : 'Tiene ${plata(saldo)} a favor'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: saldo < 0 ? p.marcaTexto : p.texto),
                  ),
                ),
                const SizedBox(height: 16),
                for (final m in movs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${m['concepto']}',
                      style: TextStyle(decoration: m['anulado'] == true ? TextDecoration.lineThrough : null, color: m['anulado'] == true ? p.apagado : p.texto),
                    ),
                    subtitle: Text(
                      [
                        _corta('${m['fecha']}'),
                        _tipos['${m['tipo']}']?.$1 ?? '',
                        if (m['aplicar'] == 'con_cuota') 'junto con la cuota',
                        if (m['aplicar'] == 'cuotas') 'en cuotas de ${plata((m['monto_por_cuota'] as num?) ?? 0)}',
                        if (m['anulado'] == true) 'anulado',
                      ].where((x) => x.isNotEmpty).join(' · '),
                    ),
                    trailing: Text(plata((m['monto'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                    onLongPress: m['anulado'] == true
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (d) => AlertDialog(
                                title: const Text('¿Anular este movimiento?'),
                                content: const Text('Queda en el historial y deja de contar en el saldo.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Volver')),
                                  FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Anular')),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            try {
                              await widget.repo.accion('anularSaldo', {'id': m['id']});
                              await _cargar();
                            } catch (e) {
                              if (context.mounted) _aviso(context, _error(e));
                            }
                          },
                  ),
                if (movs.isNotEmpty) Text('Mantén presionado un movimiento para anularlo.', style: TextStyle(fontSize: 12, color: p.textoSecundario)),
              ],
            ),
      floatingActionButton: FloatingActionButton(tooltip: 'Registrar', onPressed: _registrar, child: const Icon(Icons.add_rounded)),
    );
  }
}

/// Fondos de viaje: monto, ventana de asistencia y tramos por %; vista previa
/// de quién recibe cuánto.
/// Desglose de cuotas de un mes (Victor, 2026-11-14): quién pagó qué mes,
/// cuánto, cuándo y con qué medio, quién está en revisión y quién debe.
class CuotasMesScreen extends StatefulWidget {
  const CuotasMesScreen({super.key, required this.repo});
  final TesoreriaRepo repo;

  @override
  State<CuotasMesScreen> createState() => _CuotasMesScreenState();
}

class _CuotasMesScreenState extends State<CuotasMesScreen> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic>? _r;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String get _clave => '${_mes.year}-${_mes.month.toString().padLeft(2, '0')}';

  Future<void> _cargar() async {
    setState(() {
      _r = null;
      _error = null;
    });
    try {
      final r = await widget.repo.accion('cuotasMes', {'mes': _clave});
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (mounted) setState(() => _error = _error2(e));
    }
  }

  String _error2(Object e) => e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.';

  void _mover(int d) {
    _mes = DateTime(_mes.year, _mes.month + d);
    _cargar();
  }

  static const _grupos = [('pagado', 'Pagaron'), ('en_revision', 'En revisión'), ('debe', 'Deben'), ('exenta', 'Exentas o con excepción')];

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final r = _r;
    final gente = [
      for (final x in (r?['personas'] as List? ?? const []).cast<Map>())
        if (_q.isEmpty || '${x['nombre']}'.toLowerCase().contains(_q.toLowerCase())) x,
    ];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Cuotas del mes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, 4 + altoBarra(context), 8, 0),
            child: Row(
              children: [
                IconButton(tooltip: 'Mes anterior', onPressed: () => _mover(-1), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(
                  child: Text(
                    '${Fechas.mes(_mes)[0].toUpperCase()}${Fechas.mes(_mes).substring(1)} ${_mes.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(tooltip: 'Mes siguiente', onPressed: () => _mover(1), icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v.trim()),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar persona'),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _error != null
                  ? Center(key: const ValueKey('e'), child: Text(_error!))
                  : r == null
                  ? const Esqueleto(forma: FormaEsqueleto.lista, key: ValueKey('c'))
                  : Sincroniza(
                      key: ValueKey(_clave),
                      onRefresh: _cargar,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + MediaQuery.paddingOf(context).bottom),
                        children: [
                          Text('Entró ${plata(r['total'] as num? ?? 0)} por cuotas de este mes.', style: TextStyle(color: p.textoSecundario)),
                          for (final (clave, titulo) in _grupos)
                            if (gente.any((x) => x['estado'] == clave)) ...[
                              const SizedBox(height: 16),
                              Text(
                                '$titulo (${gente.where((x) => x['estado'] == clave).length})',
                                style: TextStyle(fontWeight: FontWeight.w800, color: clave == 'debe' ? p.marcaTexto : p.texto),
                              ),
                              const SizedBox(height: 6),
                              for (final x in gente.where((x) => x['estado'] == clave)) _persona(context, x),
                            ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _persona(BuildContext context, Map x) {
    final p = context.pivot;
    final pagos = (x['pagos'] as List? ?? const []).cast<Map>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarPersona(nombre: '${x['nombre']}', foto: '${x['foto'] ?? ''}', tamano: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${x['nombre']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if ('${x['equipo'] ?? ''}'.isNotEmpty) Text('${x['equipo']}', style: TextStyle(fontSize: 12, color: p.textoSecundario)),
                    for (final g in pagos)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          [
                            plata(g['monto'] as num? ?? 0),
                            if ('${g['medio'] ?? ''}'.isNotEmpty) '${g['medio']}',
                            if ('${g['fecha'] ?? ''}'.isNotEmpty) 'el ${_corta('${g['fecha']}')}',
                            if (g['enRevision'] == true) 'en revisión',
                            if (g['origen'] == 'manual') 'anotado a mano',
                          ].join(' · '),
                          style: TextStyle(fontSize: 13, color: p.textoSecundario),
                        ),
                      ),
                    if (pagos.isEmpty && x['estado'] == 'debe') Text('Aún no paga', style: TextStyle(fontSize: 13, color: p.marcaTexto)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FondosViajeScreen extends StatefulWidget {
  const FondosViajeScreen({super.key, required this.repo});
  final TesoreriaRepo repo;

  @override
  State<FondosViajeScreen> createState() => _FondosViajeScreenState();
}

class _FondosViajeScreenState extends State<FondosViajeScreen> {
  List<Map<String, dynamic>>? _fondos;

  /// Equipos y si reciben fondos (antes un interruptor en cada equipo).
  List<Map<String, dynamic>> _equipos = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarEquipos();
  }

  Future<void> _cargarEquipos() async {
    try {
      final s = widget.repo.sesion;
      final r = await s.api.get('getTiers', {'adminToken': s.adminToken});
      if (mounted) {
        setState(
          () => _equipos = [
            for (final t in (r['tiers'] as List? ?? const []))
              if (t is Map<String, dynamic>) t,
          ]..sort((a, b) => ((a['orden'] as num?) ?? 0).compareTo((b['orden'] as num?) ?? 0)),
        );
      }
    } catch (_) {}
  }

  Future<void> _cambiarEquipo(Map<String, dynamic> t, bool v) async {
    setState(() => t['califica_fondos_viaje'] = v);
    try {
      await cambiarFondosViaje(widget.repo.sesion, t, v);
    } catch (e) {
      if (mounted) {
        setState(() => t['califica_fondos_viaje'] = !v);
        _aviso(context, _error(e));
      }
    }
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.repo.accion('fondos');
      if (mounted) setState(() => _fondos = [for (final x in (r['fondos'] as List? ?? const [])) x as Map<String, dynamic>]);
    } catch (e) {
      if (mounted) {
        setState(() => _fondos = const []);
        _aviso(context, _error(e));
      }
    }
  }

  Future<void> _editar([Map<String, dynamic>? f]) async {
    final ok = await SubAjustes.abrir<bool>(context, _FondoScreen(repo: widget.repo, fondo: f));
    if (ok == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _fondos;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Viajes', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: l == null
          ? const Esqueleto(forma: FormaEsqueleto.lista)
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
              children: [
                Text(
                  'Cada viaje reparte un monto entre quienes reciben fondos, según su % de asistencia en las fechas que elijas (por ejemplo, de 90 a 100 % recibe el 50 %).',
                  style: TextStyle(fontSize: 13, color: p.textoSecundario),
                ),
                if (_equipos.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                    child: Text(
                      'QUIÉNES RECIBEN FONDOS',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                    ),
                  ),
                  Material(
                    color: p.tarjeta,
                    borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final t in _equipos)
                          SwitchListTile(
                            title: Text('${t['nombre']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            value: t['califica_fondos_viaje'] == true,
                            onChanged: (v) => _cambiarEquipo(t, v),
                          ),
                      ],
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    'REGLAS DE REPARTO',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                  ),
                ),
                Material(
                  color: p.tarjeta,
                  borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(Icons.pie_chart_outline_rounded, color: p.marcaTexto),
                    title: const Text('Reparto por defecto', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(textoTramos(ConfigLiga.de(widget.repo.sesion).repartoViaje)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await SubAjustes.abrir<void>(context, RepartoViajeScreen(config: ConfigLiga.de(widget.repo.sesion)));
                      if (mounted) setState(() {});
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    'VIAJES',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                  ),
                ),
                if (l.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text('Todavía no hay viajes.', style: TextStyle(color: p.textoSecundario)),
                  ),
                for (final f in l)
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.flight_takeoff_rounded, color: p.marcaTexto),
                      title: Text('${f['nombre']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${plata((f['monto'] as num?) ?? 0)} · asistencia del ${_corta('${f['ventana_desde']}')} al ${_corta('${f['ventana_hasta']}')}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _editar(f),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(tooltip: 'Nuevo viaje', onPressed: _editar, child: const Icon(Icons.add_rounded)),
    );
  }
}

class _FondoScreen extends StatefulWidget {
  const _FondoScreen({required this.repo, this.fondo});
  final TesoreriaRepo repo;
  final Map<String, dynamic>? fondo;

  @override
  State<_FondoScreen> createState() => _FondoScreenState();
}

class _FondoScreenState extends State<_FondoScreen> {
  late final _nombre = TextEditingController(text: widget.fondo?['nombre'] as String? ?? '');
  late final _monto = TextEditingController(text: widget.fondo == null ? '' : '${widget.fondo!['monto']}');
  late DateTime _desde = DateTime.tryParse('${widget.fondo?['ventana_desde'] ?? ''}') ?? DateTime(Fechas.hoy().year - 1, Fechas.hoy().month, Fechas.hoy().day);
  late DateTime _hasta = DateTime.tryParse('${widget.fondo?['ventana_hasta'] ?? ''}') ?? Fechas.hoy();
  // Un viaje nuevo empieza con el reparto por defecto de la liga (Viajes → Reglas de reparto).
  late List<Map<String, num>> _tramos = [
    for (final t in (widget.fondo?['tramos'] as List? ?? ConfigLiga.de(widget.repo.sesion).repartoViaje))
      {'min': (t['min'] as num?) ?? 0, 'pct': (t['pct'] as num?) ?? 0},
  ];
  Map<String, dynamic>? _vista;
  bool _ocupado = false;

  Map<String, Object?> get _datos => {
    if (widget.fondo != null) 'id': widget.fondo!['id'],
    'nombre': _nombre.text.trim(),
    'monto': num.tryParse(_monto.text.replaceAll(',', '.')) ?? 0,
    'ventanaDesde': isoFecha(_desde),
    'ventanaHasta': isoFecha(_hasta),
    'tramos': _tramos,
  };

  @override
  void initState() {
    super.initState();
    _previsualizar();
  }

  Future<void> _previsualizar() async {
    try {
      final r = await widget.repo.accion('previsualizarFondo', _datos);
      if (mounted) setState(() => _vista = r);
    } catch (e) {
      if (mounted) _aviso(context, _error(e));
    }
  }

  Future<void> _guardar() async {
    setState(() => _ocupado = true);
    try {
      await widget.repo.accion('guardarFondo', _datos);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        _aviso(context, _error(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final v = _vista;
    final personas = [for (final x in (v?['personas'] as List? ?? const [])) x as Map<String, dynamic>];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: Text(widget.fondo == null ? 'Nuevo viaje' : 'Viaje', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 100 + MediaQuery.paddingOf(context).bottom),
        children: [
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Viaje (ej. Torneo en Lima)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Monto a repartir', prefixText: '${Moneda.s} '),
            onSubmitted: (_) => _previsualizar(),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.date_range_rounded),
            title: Text('Asistencia del ${Fechas.corta(_desde)} al ${Fechas.corta(_hasta)}'),
            onTap: () async {
              final r = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: Fechas.hoy(),
                initialDateRange: DateTimeRange(start: _desde, end: _hasta),
              );
              if (r != null) {
                setState(() => (_desde = r.start, _hasta = r.end));
                _previsualizar();
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Reglas de reparto',
            style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
          ),
          const SizedBox(height: 8),
          EditorTramos(tramos: _tramos, alCambiar: (t) => setState(() => _tramos = t)),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(onPressed: _previsualizar, icon: const Icon(Icons.visibility_outlined), label: const Text('Ver reparto')),
          const SizedBox(height: 12),
          if (v != null) ...[
            Text(
              '${v['eventosConLista']} clases con lista · se reparten ${plata((v['repartido'] as num?) ?? 0)}${((v['sobrante'] as num?) ?? 0) > 0 ? ' · sobran ${plata(v['sobrante'] as num)}' : ''}',
              style: TextStyle(color: p.textoSecundario),
            ),
            for (final x in personas)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AvatarPersona(nombre: '${x['nombre']}', foto: '${x['foto'] ?? ''}', tamano: 36),
                title: Text('${x['nombre']}'),
                subtitle: Text('${numero(x['pct'] as num)} % · ${x['clases']} clases'),
                trailing: Text(
                  plata((x['recibe'] as num?) ?? 0),
                  style: TextStyle(fontWeight: FontWeight.w800, color: ((x['recibe'] as num?) ?? 0) > 0 ? p.texto : p.apagado),
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ocupado ? null : _guardar,
        icon: const Icon(Icons.check_rounded),
        label: const Text('Guardar'),
      ),
    );
  }
}

/// "Desde 90 %: 50 % · desde 35 %: 50 %".
String textoTramos(List tramos) => tramos.isEmpty
    ? 'Sin reglas'
    : [for (final t in tramos) 'desde ${(t as Map)['min']} % de asistencia: ${t['pct']} % del fondo'].join(' · ').replaceFirst('d', 'D');

/// Reglas de reparto de un fondo de viaje (Victor, 2026-11-15), sin + y −:
/// "Quien asistió al X % o más recibe Y % del fondo", repartido en partes
/// iguales entre quienes caen en ese tramo.
class EditorTramos extends StatelessWidget {
  const EditorTramos({super.key, required this.tramos, required this.alCambiar});
  final List<Map<String, num>> tramos;
  final ValueChanged<List<Map<String, num>>> alCambiar;

  static const _minimos = [0, 10, 20, 25, 30, 35, 40, 50, 60, 70, 75, 80, 85, 90, 95, 100];

  List<Map<String, num>> _ordenar(List<Map<String, num>> l) => [...l]..sort((a, b) => (b['min'] ?? 0).compareTo(a['min'] ?? 0));

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final suma = tramos.fold<num>(0, (s, t) => s + (t['pct'] ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, t) in tramos.indexed)
          Container(
            key: ValueKey('tramo_$i'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text('Quien asistió al', style: TextStyle(color: p.texto)),
                      DropdownButton<int>(
                        value: _minimos.contains((t['min'] ?? 0).toInt()) ? (t['min'] ?? 0).toInt() : null,
                        hint: Text('${t['min']} %'),
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: [for (final m in _minimos) DropdownMenuItem(value: m, child: Text('$m %'))],
                        onChanged: (m) => alCambiar(
                          _ordenar([
                            for (final (j, x) in tramos.indexed) j == i ? {...x, 'min': m ?? 0} : x,
                          ]),
                        ),
                      ),
                      Text('o más recibe', style: TextStyle(color: p.texto)),
                      SizedBox(
                        width: 76,
                        child: TextFormField(
                          key: ValueKey('pct_${i}_${t['min']}'),
                          initialValue: '${t['pct']}',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(suffixText: '%', isDense: true),
                          onChanged: (x) => alCambiar([
                            for (final (j, y) in tramos.indexed) j == i ? {...y, 'pct': num.tryParse(x) ?? 0} : y,
                          ]),
                        ),
                      ),
                      Text('del fondo', style: TextStyle(color: p.texto)),
                    ],
                  ),
                ),
                if (tramos.length > 1)
                  IconButton(
                    tooltip: 'Quitar',
                    icon: Icon(Icons.close_rounded, color: p.textoSecundario),
                    onPressed: () => alCambiar([
                      for (final (j, x) in tramos.indexed)
                        if (j != i) x,
                    ]),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            if (tramos.length < 6)
              TextButton.icon(
                onPressed: () => alCambiar(
                  _ordenar([
                    ...tramos,
                    {'min': 0, 'pct': 0},
                  ]),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar regla'),
              ),
            const Spacer(),
            Text(
              'Total: $suma %',
              style: TextStyle(fontWeight: FontWeight.w700, color: suma > 100 ? p.marcaTexto : p.textoSecundario),
            ),
          ],
        ),
        Text(
          'Cada parte se divide en partes iguales entre quienes caen en ese rango (hasta la regla de arriba). Lo que no se reparte queda en la cuenta.',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: p.textoSecundario),
        ),
      ],
    );
  }
}

/// Reparto por defecto de la liga: con lo que empieza cada viaje nuevo.
class RepartoViajeScreen extends StatefulWidget {
  const RepartoViajeScreen({super.key, required this.config});
  final ConfigLiga config;

  @override
  State<RepartoViajeScreen> createState() => _RepartoViajeScreenState();
}

class _RepartoViajeScreenState extends State<RepartoViajeScreen> {
  late List<Map<String, num>> _tramos = [
    for (final t in widget.config.repartoViaje) {'min': (t['min'] as num?) ?? 0, 'pct': (t['pct'] as num?) ?? 0},
  ];
  bool _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await widget.config.guardarReglas({'repartoViaje': _tramos});
      if (mounted) {
        _aviso(context, 'Guardado. Se usa en los viajes nuevos.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _aviso(context, _error(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final suma = _tramos.fold<num>(0, (s, t) => s + (t['pct'] ?? 0));
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Reparto por defecto', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text(
            'Con estas reglas empieza cada viaje nuevo; en cada viaje se pueden cambiar. Los viajes ya guardados no cambian.',
            style: TextStyle(fontSize: 15, height: 1.4, color: p.texto),
          ),
          const SizedBox(height: 16),
          EditorTramos(tramos: _tramos, alCambiar: (t) => setState(() => _tramos = t)),
          const SizedBox(height: 20),
          FilledButton(onPressed: _guardando || suma > 100 ? null : _guardar, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
        ],
      ),
    );
  }
}
