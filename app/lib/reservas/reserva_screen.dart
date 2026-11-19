import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pivots/formas_pago_screen.dart' show LogoMedio, copiarDato;
import '../core/config_liga.dart';
import '../core/iconos_marca.dart';
import '../core/asistente.dart';
import '../core/fechas.dart';
import '../core/api.dart';
import '../core/tema.dart';
import '../eventos/anticipada.dart';
import '../eventos/eventos_repo.dart';
import 'comprobante.dart';
import 'reservas_repo.dart';
import '../core/vidrio.dart';
import '../core/esqueleto.dart';

enum _Paso { elegir, pago }

/// Reserva por clase o por mes desde el "+" (Fase 3), como el flujo de la
/// web (s4 → s-pago → s6) pero en el marco de asistente de la app:
/// 1) elegir clases o meses, con el total siempre a la vista;
/// 2) pagar con uno de los medios de la liga (enlace o datos); al elegir, la reserva
///    queda registrada como pendiente, igual que en la web;
/// después, pantalla de éxito con el botón para mandar el comprobante.
class ReservaScreen extends StatefulWidget {
  const ReservaScreen({super.key, required this.repo, required this.tipo, this.claseInicial, this.mesInicial, this.datosPrueba});
  final EventosRepo repo;
  final TipoReserva tipo;

  /// Desde el detalle de un evento: esa clase o ese mes ya elegidos.
  final String? claseInicial;
  final DateTime? mesInicial;

  /// Solo pruebas: precios, cuota, cupón y clases sin pasar por el servidor.
  @visibleForTesting
  final (Precios, Cuota, bool, List<FechaClase>)? datosPrueba;

  @override
  State<ReservaScreen> createState() => _ReservaScreenState();
}

class _ReservaScreenState extends State<ReservaScreen> {
  late final _r = ReservasRepo(widget.repo.sesion);
  _Paso _paso = _Paso.elegir;
  bool _adelante = true;
  bool _guardando = false;
  String? _error;

  Precios? _precios;
  Cuota? _cuota;
  bool _hayCupon = false;
  bool _usarCupon = false;

  /// Saldo con el equipo (solo cuotas): a favor (+) o en contra (−) y si la persona lo aplica.
  double _saldo = 0, _deudaClases = 0;
  bool _aplicarSaldo = false;
  List<FechaClase>? _clases;
  List<MesReserva>? _meses;
  final _clasesSel = <String>{};
  final _tallaPorFecha = <String, String>{};
  Set<DateTime> _mesesSel = {};
  String? _medioAbierto;

  bool get _esMes => widget.tipo == TipoReserva.mes;

  // Planes de pago (Victor, 2026-11-16).
  List<PlanPago> _planes = const [];
  int _clasesPlan = 0;
  PlanPago? _plan;
  List<PlanPago> get _planesAqui => [
    for (final p in _planes)
      if (p.deClases != _esMes) p,
  ];

  void _elegirPlan(PlanPago? p) => setState(() {
    _plan = _plan?.id == p?.id ? null : p;
    if (_plan != null && _esMes) {
      // N meses seguidos desde el primero sin pagar.
      _mesesSel = {for (final m in (_meses ?? const <MesReserva>[]).where((m) => !m.pagado).take(_plan!.cantidad)) m.mes};
    }
  });

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    final prueba = widget.datosPrueba;
    if (prueba == null) {
      _r.misPlanes().then((x) {
        if (mounted) setState(() => (_planes = x.planes, _clasesPlan = x.clases));
      });
      _r.miSaldoDetalle().then((s) {
        if (mounted) {
          setState(() {
            _saldo = s.saldo;
            _deudaClases = s.deudaClases;
          });
        }
      });
    }
    try {
      final res = prueba != null
          ? <Object>[prueba.$1, prueba.$2, prueba.$3, if (!_esMes) prueba.$4]
          : await Future.wait([_r.precios(), widget.repo.anticipada.cuota(), _r.cuponDisponible(), if (!_esMes) _r.fechas()]);
      if (!mounted) return;
      setState(() {
        _precios = res[0] as Precios;
        _cuota = res[1] as Cuota;
        _hayCupon = res[2] as bool;
        if (_esMes) {
          _meses = _r.meses(_cuota!);
          _mesesSel = _r.preseleccion(_meses!);
          // Desde un evento: solo ese mes (web: `_evFabReservaParaEvento()`).
          final mi = widget.mesInicial;
          if (mi != null && _meses!.any((m) => m.mes == mi && !m.pagado)) _mesesSel = {mi};
        } else {
          _clases = res[3] as List<FechaClase>;
          final ci = widget.claseInicial;
          final c = _clases!.where((c) => c.id == ci).firstOrNull;
          if (c != null && c.disponible) _clasesSel.add(c.id);
          if (ci != null && c != null && !c.elegible) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c.razon)));
            });
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo cargar. Revisa tu conexión.');
    }
  }

  int get _creditos => (_cuota?.reservas.where((r) => r['estado'] == 'Reagendar').length ?? 0) + _clasesPlan;

  int get _cantidad => _plan != null && _plan!.deClases ? 1 : (_esMes ? _mesesSel.length : _clasesSel.length);

  Total get _total => _plan != null
      ? Total(cantidad: 1, aFavor: 0, cupon: 0, cobradas: 1, monto: _plan!.precio, precio: _plan!.precio)
      : _r.total(
          tipo: widget.tipo,
          cantidad: _cantidad,
          p: _precios ?? const Precios(0, 0),
          creditos: _creditos,
          cupon: _usarCupon,
          meses: _mesesSel,
          saldo: _aplicarSaldo ? _saldo : 0,
          deudaObligatoria: _deudaClases,
        );

  void _ir(int delta) {
    final i = _paso.index + delta;
    if (i < 0) {
      Navigator.of(context).pop();
      return;
    }
    if (i >= _Paso.values.length) return;
    setState(() {
      _adelante = delta > 0;
      _paso = _Paso.values[i];
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final listo = _precios != null && (_esMes ? _meses != null : _clases != null);
    return Asistente(
      titulo: _esMes ? 'Reserva por mes' : 'Reserva por clase',
      indice: _paso.index,
      total: _Paso.values.length,
      tituloPaso: switch (_paso) {
        _Paso.elegir => _esMes ? 'Elige los meses' : 'Elige tus clases',
        _Paso.pago => total.monto == 0 ? 'Confirma tu reserva' : 'Paga tu reserva',
      },
      ayuda: switch (_paso) {
        _Paso.elegir =>
          _esMes
              ? 'Puedes pagar varios meses de una vez.'
              : _r.resumenEquipo == null
              ? null
              : 'Usarás del equipo: ${_r.resumenEquipo!.toLowerCase()}.',
        _Paso.pago =>
          total.monto == 0 ? 'No tienes nada que pagar.' : 'Al elegir cómo pagar, tu reserva queda registrada y pendiente hasta que el equipo revise el pago.',
      },
      clavePaso: _paso,
      adelante: _adelante,
      alAtras: () => _ir(-1),
      cuerpo: _error != null
          ? _errorCarga(context)
          : !listo
          ? const Esqueleto(forma: FormaEsqueleto.tarjetas)
          : switch (_paso) {
              _Paso.elegir => _esMes ? _pasoMeses(context) : _pasoClases(context),
              _Paso.pago => _pasoPago(context, total),
            },
      textoBoton: switch (_paso) {
        _Paso.elegir => _cantidad == 0 ? 'Siguiente' : 'Siguiente · ${ReservasRepo.dinero(total.monto)}',
        _Paso.pago => total.monto == 0 ? 'Confirmar reserva' : null,
      },
      alContinuar: switch (_paso) {
        _Paso.elegir => _cantidad == 0 ? null : () => _ir(1),
        _Paso.pago => total.monto == 0 && !_guardando ? () => _confirmar(null) : null,
      },
      ocupado: _guardando,
    );
  }

  Widget _errorCarga(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error!),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
      ],
    ),
  );

  // ─── Paso 1: clases ───────────────────────────────────────────────────

  Widget _pasoClases(BuildContext context) {
    final p = context.pivot;
    final clases = _clases!;
    if (clases.isEmpty) {
      return Center(
        child: Text('No hay clases disponibles por ahora.', style: TextStyle(color: p.textoSecundario)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _tarjetasPlanes(context),
        if (_plan != null)
          _aviso(context, Icons.info_outline_rounded, 'Con el plan, reservas tus clases después de que se apruebe el pago, sin pagar cada una.')
        else ...[
          if (_creditos > 0)
            _aviso(
              context,
              Icons.autorenew_rounded,
              'Tienes $_creditos ${_creditos == 1 ? 'clase a favor' : 'clases a favor'} por entrenamientos cancelados. Se descuentan solas.',
            ),
          _tarjetaEquipo(context),
          for (final c in clases) _tarjetaClase(context, c),
        ],
      ],
    );
  }

  /// Planes que puede comprar (Victor, 2026-11-16): tocar uno lo elige.
  Widget _tarjetasPlanes(BuildContext context) {
    final p = context.pivot;
    final l = _planesAqui;
    if (l.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              'PLANES',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
            ),
          ),
          for (final x in l)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: _plan?.id == x.id ? p.suave : p.tarjeta,
                  borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                  border: Border.all(color: _plan?.id == x.id ? p.marca : p.tarjetaBorde, width: _plan?.id == x.id ? 1.6 : 1),
                ),
                child: ListTile(
                  leading: Icon(x.deClases ? Icons.confirmation_number_outlined : Icons.calendar_month_outlined, color: p.marcaTexto),
                  title: Text(x.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(x.detalle),
                  trailing: Icon(_plan?.id == x.id ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: p.marcaTexto),
                  onTap: () => _elegirPlan(x),
                ),
              ),
            ),
          if (_clasesPlan > 0 && !_esMes)
            Text(
              'Te quedan $_clasesPlan ${_clasesPlan == 1 ? 'clase' : 'clases'} de tu plan: se descuentan solas.',
              style: TextStyle(color: p.textoSecundario),
            ),
        ],
      ),
    );
  }

  /// Equipamiento para estas clases, con "Cambiar" (Victor, 2026-11-16).
  Widget _tarjetaEquipo(BuildContext context) {
    final p = context.pivot;
    final r = _r.resumenEquipo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: p.suave,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        child: InkWell(
          borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
          onTap: _cambiarEquipo,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Icon(Icons.roller_skating_outlined, color: p.sobreSuave),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _r.cambiadoParaEsta ? 'Equipamiento para esta reserva' : 'Tu equipamiento',
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.sobreSuave),
                      ),
                      Text(r == null ? 'Llevas tu propio equipamiento' : 'De la liga: ${r.toLowerCase()}', style: TextStyle(fontSize: 13, color: p.sobreSuave)),
                    ],
                  ),
                ),
                TextButton(onPressed: _cambiarEquipo, child: const Text('Cambiar')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Equipamiento solo para esta reserva, con las listas que arma la liga
  /// (Victor, 2026-11-17).
  Future<void> _cambiarEquipo() async {
    final s = widget.repo.sesion;
    List<Map<String, dynamic>> listas = const [];
    Map<String, String> mio = const {};
    try {
      final r = await s.api.get('getMiEquipoLiga');
      listas = [for (final l in (r['listas'] as List? ?? const [])) Map<String, dynamic>.from(l as Map)];
      mio = {for (final e in ((r['mio'] as Map?) ?? const {}).entries) '${e.key}': '${e.value ?? ''}'};
    } catch (_) {}
    if (!mounted) return;
    if (listas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tu liga no presta equipamiento para entrenar.')));
      return;
    }
    final usa = Map<String, String>.of(_r.equipoEsta ?? mio);
    var guardar = false;
    final ok = await showModalBottomSheet<bool>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (h) => StatefulBuilder(
        builder: (h, set) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(h).bottom),
            children: [
              Text('Equipamiento para estas clases', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Elige lo que necesitas de la liga solo para esta reserva.', style: TextStyle(color: h.pivot.textoSecundario)),
              for (final l in listas) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${l['nombre']} de la liga'),
                  value: usa.containsKey('${l['id']}'),
                  onChanged: (v) => set(() => v ? usa['${l['id']}'] = mio['${l['id']}'] ?? '' : usa.remove('${l['id']}')),
                ),
                if (usa.containsKey('${l['id']}') && l['tipo'] == 'tallas')
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in ([
                        for (final x in (l['tallas'] as List? ?? const [])) '$x',
                      ]..sort((a, b) => (num.tryParse(a) ?? 0).compareTo(num.tryParse(b) ?? 0))))
                        ChoiceChip(label: Text('Talla $t'), selected: usa['${l['id']}'] == t, onSelected: (_) => set(() => usa['${l['id']}'] = t)),
                    ],
                  ),
                if (usa.containsKey('${l['id']}') && l['tipo'] == 'set' && (l['piezas'] as List? ?? const []).isNotEmpty) ...[
                  Text('Sin elegir piezas: el set completo.', style: TextStyle(fontSize: 13, color: h.pivot.textoSecundario)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final x in [for (final y in l['piezas'] as List) '$y'])
                        FilterChip(
                          label: Text(x),
                          selected: (usa['${l['id']}'] ?? '').split(',').map((y) => y.trim()).contains(x),
                          onSelected: (v) => set(() {
                            final todas = [for (final y in l['piezas'] as List) '$y'];
                            final el = (usa['${l['id']}'] ?? '').split(',').map((y) => y.trim()).where(todas.contains).toSet();
                            v ? el.add(x) : el.remove(x);
                            usa['${l['id']}'] = todas.where(el.contains).join(', ');
                          }),
                        ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Guardarlo en mi perfil'),
                subtitle: const Text('Para mis próximas reservas. Si pasas a usar equipamiento de la liga, tu equipo puede cambiar.'),
                value: guardar,
                onChanged: (v) => set(() => guardar = v == true),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: listas.any((l) => l['tipo'] == 'tallas' && usa.containsKey('${l['id']}') && (usa['${l['id']}'] ?? '').isEmpty)
                    ? null
                    : () => Navigator.of(h).pop(true),
                child: const Text('Listo'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (guardar) {
      try {
        await s.guardarEquipoLiga(usa);
        _r.patinesEsta = null;
        _r.tallaEsta = null;
        _r.protecEsta = null;
        _r.equipoEsta = null;
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado en tu perfil')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar en tu perfil.')));
        return;
      }
    } else {
      // Patines y protecciones (listas del sistema) siguen por sus campos de siempre.
      final pat = listas.where((l) => l['sistema'] == 'patines').firstOrNull, pro = listas.where((l) => l['sistema'] == 'protecciones').firstOrNull;
      if (pat != null) {
        _r.patinesEsta = usa.containsKey('${pat['id']}');
        _r.tallaEsta = usa['${pat['id']}'];
      }
      if (pro != null) {
        final v = usa['${pro['id']}'];
        _r.protecEsta = v == null ? 'No' : (v.isEmpty ? 'Sí' : v);
      }
      _r.equipoEsta = {
        for (final e in usa.entries)
          if (!listas.any((l) => '${l['id']}' == e.key && l['sistema'] != null)) e.key: e.value,
      };
    }
    // Los cupos dependen de la talla: se vuelven a pedir.
    try {
      final l = await _r.fechas();
      if (!mounted) return;
      setState(() {
        _clases = l;
        _tallaPorFecha.clear();
        _clasesSel.removeWhere((id) => !l.any((c) => c.id == id && c.elegible));
      });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Widget _tarjetaClase(BuildContext context, FechaClase c) {
    final p = context.pivot;
    final sel = _clasesSel.contains(c.id);
    final otraTalla = _tallaPorFecha[c.id];
    final f = c.fecha;
    final titulo = f == null ? c.id : '${Fechas.dia(f)[0].toUpperCase()}${Fechas.dia(f).substring(1)} ${Fechas.corta(f)}';
    final detalle = [if (c.hora.isNotEmpty) c.hora, if (c.lugar.isNotEmpty) c.lugar].join(' · ');
    final String? nota = !c.elegible
        ? c.razon
        : (c.tallaAgotada ? (otraTalla != null ? 'Con patines talla $otraTalla' : 'Sin patines de tu talla: toca para elegir otra') : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: c.elegible ? 1 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: sel ? p.suave : p.tarjeta,
            borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
            border: Border.all(color: sel ? p.marca : p.tarjeta, width: 1.5),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              onTap: !c.elegible ? null : () => _tocarClase(c),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
                          ),
                          if (detalle.isNotEmpty) ...[const SizedBox(height: 2), Text(detalle, style: TextStyle(fontSize: 13, color: p.textoSecundario))],
                          if (nota != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              nota,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.elegible ? p.marcaTexto : p.textoSecundario),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _circulo(p, sel),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _tocarClase(FechaClase c) async {
    if (_clasesSel.contains(c.id)) {
      setState(() {
        _clasesSel.remove(c.id);
        _tallaPorFecha.remove(c.id);
        _ajustarCupon();
      });
      return;
    }
    if (c.tallaAgotada) {
      final t = await _elegirTalla(c);
      if (t == null || !mounted) return;
      _tallaPorFecha[c.id] = t;
    }
    setState(() {
      _clasesSel.add(c.id);
      _ajustarCupon();
    });
  }

  void _ajustarCupon() {
    if (_cantidad <= _creditos) _usarCupon = false;
  }

  /// Sin patines de tu talla esa fecha: elegir otra talla libre (web:
  /// `abrirSheetTallaNuevaReserva()`).
  Future<String?> _elegirTalla(FechaClase c) {
    return showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (context) => FutureBuilder<List<String>>(
        future: _r.tallasLibres(c.id),
        builder: (context, s) {
          final p = context.pivot;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No quedan patines talla ${_r.talla}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Puedes reservar esta fecha con otra talla:', style: TextStyle(color: p.textoSecundario)),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: !s.hasData
                      ? const Padding(padding: EdgeInsets.all(16), child: EsqueletoFilas())
                      : s.data!.isEmpty
                      ? Text('No quedan patines libres para esta fecha.', style: TextStyle(color: p.textoSecundario))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final t in s.data!) ActionChip(label: Text('Talla $t'), onPressed: () => Navigator.of(context).pop(t))],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Paso 1: meses ────────────────────────────────────────────────────

  Widget _pasoMeses(BuildContext context) {
    final p = context.pivot;
    final meses = _meses!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _tarjetasPlanes(context),
        if (meses.any((m) => m.pasado)) _aviso(context, Icons.info_outline_rounded, 'Tienes meses anteriores sin pagar; ya están marcados.'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.35,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final m in meses)
              _celdaMes(
                p,
                m,
                sel: _mesesSel.contains(m.mes),
                // Con un plan de meses, los meses los fija el plan.
                alTocar: m.pagado || _plan != null ? null : () => setState(() => _mesesSel.contains(m.mes) ? _mesesSel.remove(m.mes) : _mesesSel.add(m.mes)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _celdaMes(PivotPaleta p, MesReserva m, {required bool sel, VoidCallback? alTocar}) {
    final sub = m.pagado ? 'Pagado' : (m.pasado ? 'Adeudado' : '${m.mes.year}');
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: m.pagado ? 0.5 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: sel ? p.suave : p.tarjeta,
          borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
          border: Border.all(color: sel ? p.marca : p.tarjeta, width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
            onTap: alTocar,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Fechas.mesNombre(m.mes),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: sel ? p.sobreSuave : p.texto),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: m.pagado || m.pasado ? FontWeight.w600 : FontWeight.w400,
                    color: m.pasado ? p.marcaTexto : p.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Paso 2: pago ─────────────────────────────────────────────────────

  Widget _pasoPago(BuildContext context, Total t) {
    final p = context.pivot;
    final cuponPosible = !_esMes && _hayCupon && _cantidad > t.aFavor;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _cajaTotal(context, t),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _deudaClases > 0 && t.saldo < 0 && !_aplicarSaldo
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Material(
                    color: p.suave,
                    borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                    child: ListTile(
                      leading: Icon(Icons.receipt_long_outlined, color: p.marcaTexto),
                      title: const Text('Incluye una clase pendiente de pago'),
                      subtitle: Text('Tienes ${ReservasRepo.dinero(_deudaClases)} de una reserva que no se pudo confirmar. Se suma a este pago.'),
                    ),
                  ),
                )
              : _esMes && _saldo != 0
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Material(
                    color: p.tarjeta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                    child: SwitchListTile(
                      value: _aplicarSaldo,
                      onChanged: (v) => setState(() => _aplicarSaldo = v),
                      secondary: Icon(_saldo > 0 ? Icons.savings_outlined : Icons.account_balance_wallet_outlined, color: p.marcaTexto),
                      title: Text(_saldo > 0 ? 'Usar mi saldo a favor' : 'Pagar lo que debo junto con la cuota'),
                      subtitle: Text(
                        _saldo > 0
                            ? 'Tienes ${ReservasRepo.dinero(_saldo)} a favor con el equipo. Se descuenta de esta cuota.'
                            : 'Tienes ${ReservasRepo.dinero(-_saldo)} pendientes con el equipo. Se suman a esta cuota.',
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (cuponPosible) ...[
          const SizedBox(height: 12),
          Material(
            color: p.tarjeta,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: SwitchListTile(
              value: _usarCupon,
              onChanged: (v) => setState(() => _usarCupon = v),
              secondary: Icon(Icons.confirmation_number_outlined, color: p.marcaTexto),
              title: const Text('Usar mi cupón'),
              subtitle: const Text('1 clase gratis · personal e intransferible'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            ),
          ),
        ],
        // Formas de pago de la liga (Mi Liga → Cobros): cada medio con su color.
        if (t.monto > 0) ...[
          const SizedBox(height: 20),
          for (final m in _cfg.mediosActivos) Padding(padding: const EdgeInsets.only(bottom: 12), child: _medio(context, t, m)),
          if (_cfg.mediosActivos.isEmpty)
            Text(
              'La liga todavía no tiene formas de pago. Escríbele a un Pivot.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textoSecundario),
            ),
        ],
      ],
    );
  }

  Widget _cajaTotal(BuildContext context, Total t) {
    final p = context.pivot;
    final items = _esMes
        ? (_mesesSel.toList()..sort()).map((m) => ReglaAnticipada.nombreMes(m)).toList()
        : _clases!.where((c) => _clasesSel.contains(c.id)).map(ReservasRepo.etiquetaClase).toList();
    final partes = [
      if (t.cobradas > 0 && t.proporcional)
        '${t.cobradas} ${t.cobradas == 1 ? 'mes' : 'meses'} ${ReservasRepo.dinero(t.mensualidades)} (proporcional por el descanso)'
      else if (t.cobradas > 0)
        '${t.cobradas} ${_esMes ? (t.cobradas == 1 ? 'mes' : 'meses') : (t.cobradas == 1 ? 'clase' : 'clases')} × ${ReservasRepo.dinero(t.precio)}',
      if (t.recargos > 0) 'recargo por pagar tarde ${ReservasRepo.dinero(t.recargo)}',
      if (t.descuento > 0) 'descuento de ${ReservasRepo.dinero(t.descuento)}',
      if (t.saldo < 0) '${ReservasRepo.dinero(-t.saldo)} pendientes de antes',

      if (t.aFavor > 0) '${t.aFavor} a favor',
      if (t.cupon > 0) '1 con cupón',
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.sobreSuave),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: t.monto),
            duration: const Duration(milliseconds: 300),
            builder: (context, v, _) => Text(
              ReservasRepo.dinero(v),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: p.sobreSuave),
            ),
          ),
          Text(partes.join(' + '), style: TextStyle(fontSize: 13, color: p.sobreSuave)),
          if (t.saldo > 0) Text('Menos ${ReservasRepo.dinero(t.saldo)} de tu saldo a favor', style: TextStyle(fontSize: 13, color: p.sobreSuave)),
          const SizedBox(height: 10),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $i', style: TextStyle(fontSize: 13, color: p.sobreSuave)),
            ),
        ],
      ),
    );
  }

  /// Un medio de pago: con enlace, botón que lo abre; con datos, tarjeta que
  /// se despliega con los datos para copiar; si no, solo confirmar.
  Widget _medio(BuildContext context, Total t, MedioPago m) {
    final p = context.pivot;
    final color = PivotMedios.de(m.color);
    final abierto = _medioAbierto == m.id;
    final conDatos = m.datos.isNotEmpty || m.indicaciones.isNotEmpty;
    Future<void> pagar() => _confirmar(m.enlace.isNotEmpty ? m.enlace : null, medio: m.id, medioNombre: m.nombre);
    return Material(
      color: p.tarjeta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 5)),
        ),
        child: Column(
          children: [
            ListTile(
              leading: LogoMedio(medio: m, tamano: 40),
              title: Text(m.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(m.enlace.isNotEmpty ? 'Se abre para pagar ${ReservasRepo.dinero(t.monto)}' : m.nombreTipo),
              trailing: conDatos && m.enlace.isEmpty
                  ? AnimatedRotation(turns: abierto ? 0.5 : 0, duration: const Duration(milliseconds: 220), child: const Icon(Icons.expand_more_rounded))
                  : Icon(Icons.chevron_right_rounded, color: color),
              onTap: _guardando ? null : (conDatos && m.enlace.isEmpty ? () => setState(() => _medioAbierto = abierto ? null : m.id) : pagar),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !(abierto || (conDatos && m.enlace.isNotEmpty))
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (etiqueta, valor) in m.datos)
                            Row(
                              children: [
                                SizedBox(
                                  width: 104,
                                  child: Text(etiqueta, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                                ),
                                Expanded(
                                  child: Text(
                                    valor,
                                    style: TextStyle(fontWeight: FontWeight.w600, color: p.texto),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copiar',
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  onPressed: () => copiarDato(context, etiqueta, valor),
                                ),
                              ],
                            ),
                          if (m.indicaciones.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 8),
                              child: Text(m.indicaciones, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                            ),
                          if (m.enlace.isEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: PivotPaleta.sobreSeccion),
                                onPressed: _guardando ? null : pagar,
                                child: Text(
                                  m.tipo == 'efectivo' ? 'Pagaré ${ReservasRepo.dinero(t.monto)} en efectivo' : 'Ya pagué ${ReservasRepo.dinero(t.monto)}',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Confirmar ────────────────────────────────────────────────────────

  ConfigLiga get _cfg => ConfigLiga.de(widget.repo.sesion);

  Future<void> _confirmar(String? urlPago, {String? medio, String? medioNombre}) async {
    if (_guardando) return;
    setState(() => _guardando = true);
    final total = _total;
    final plan = _plan;
    final resultado = plan != null && plan.deClases
        ? await _r.comprarPlan(plan, medio: total.monto == 0 ? null : medio, medioNombre: total.monto == 0 ? null : medioNombre)
        : await _r.confirmar(
            planId: plan?.id,
            tipo: widget.tipo,
            clases: _clases?.where((c) => _clasesSel.contains(c.id)).toList() ?? const [],
            meses: _mesesSel.toList()..sort(),
            tallaPorFecha: _tallaPorFecha,
            total: total,
            // Dónde dice que pagó, para que el Pivot sepa dónde revisar.
            medio: total.monto == 0 ? null : medio,
            medioNombre: total.monto == 0 ? null : medioNombre,
          );
    if (!mounted) return;
    if (resultado.guardados.isEmpty) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo guardar tu reserva. Intenta de nuevo.')));
      return;
    }
    // La reserva ya quedó registrada; recién ahí se abre el enlace de pago.
    if (urlPago != null) await launchUrl(Uri.parse(urlPago), mode: LaunchMode.inAppBrowserView);
    widget.repo.cargar(forzar: true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => ReservaExitoScreen(resultado: resultado, total: total, esClase: !_esMes, repo: _r),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _aviso(BuildContext context, IconData icono, String texto) {
    final p = context.pivot;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
      child: Row(
        children: [
          Icon(icono, color: p.sobreSuave),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto, style: TextStyle(fontSize: 13, height: 1.35, color: p.sobreSuave)),
          ),
        ],
      ),
    );
  }

  Widget _circulo(PivotPaleta p, bool sel) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: sel ? p.marca : null,
      border: Border.all(color: sel ? p.marca : p.borde, width: 2),
    ),
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: sel ? 1 : 0,
      child: Icon(Icons.check_rounded, size: 16, color: p.sobreMarca),
    ),
  );
}

/// "¡Reserva registrada!" (web: s6). Lo principal es subir el comprobante
/// dentro de la app (Victor, 2026-11-14): la reserva ya quedó guardada; si
/// la persona sale a pagar y vuelve, se le pide la captura en ese momento.
class ReservaExitoScreen extends StatefulWidget {
  const ReservaExitoScreen({super.key, required this.resultado, required this.total, required this.esClase, this.repo});
  final ResultadoReserva resultado;
  final Total total;
  final bool esClase;
  final ReservasRepo? repo;

  @override
  State<ReservaExitoScreen> createState() => _ReservaExitoScreenState();
}

class _ReservaExitoScreenState extends State<ReservaExitoScreen> with WidgetsBindingObserver {
  bool _subido = false, _salio = false, _preguntando = false;

  ResultadoReserva get resultado => widget.resultado;
  Total get total => widget.total;
  bool get esClase => widget.esClase;
  bool get _puedeSubir => widget.repo != null && resultado.ids.isNotEmpty && !_subido;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) _salio = true;
    // Volvió de pagar (app del banco o billetera): se pide la captura ahora.
    if (s == AppLifecycleState.resumed && _salio && _puedeSubir && !_preguntando) {
      _salio = false;
      _preguntarAlVolver();
    }
  }

  Future<void> _preguntarAlVolver() async {
    _preguntando = true;
    final si = await showModalBottomSheet<bool>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (h) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿Ya pagaste?', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Sube la captura del pago y listo: un Pivot la revisa y confirma tu reserva.'),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(h).pop(true),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Subir comprobante'),
              ),
              TextButton(onPressed: () => Navigator.of(h).pop(false), child: const Text('Todavía no')),
            ],
          ),
        ),
      ),
    );
    _preguntando = false;
    if (si == true && mounted) await _subir();
  }

  Future<void> _subir() async {
    final ok = await subirComprobante(context, widget.repo!, resultado.ids);
    if (ok && mounted) setState(() => _subido = true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final t = Theme.of(context).textTheme;
    final gratis = total.monto == 0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 8 + altoBarra(context), 24, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.elasticOut,
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: Icon(Icons.check_circle_rounded, size: 84, color: p.marca),
          ),
          const SizedBox(height: 16),
          Text(
            '¡Reserva registrada!',
            textAlign: TextAlign.center,
            style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            gratis
                ? 'Queda pendiente hasta que el equipo la apruebe. Te llegará una notificación.'
                : 'Queda pendiente hasta que el equipo revise tu pago. Te llegará una notificación cuando esté aprobada.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.4, color: p.textoSecundario),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final g in resultado.guardados)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.check_rounded, size: 18, color: p.marcaTexto),
                        const SizedBox(width: 8),
                        Expanded(child: Text(g)),
                      ],
                    ),
                  ),
                for (final f in resultado.fallidos)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 18, color: p.textoSecundario),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('$f (no se pudo guardar)', style: TextStyle(color: p.textoSecundario)),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 20),
                Text('Total: ${ReservasRepo.dinero(total.monto)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _subido
                ? Row(
                    key: const ValueKey('ok'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: p.marcaTexto),
                      const SizedBox(width: 8),
                      const Text('Comprobante enviado', style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  )
                : _puedeSubir
                ? Column(
                    key: const ValueKey('subir'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: _subir,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Subir comprobante'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Si todavía no pagas, hazlo y vuelve: te lo pediremos al volver. También puedes subirlo después desde Notificaciones.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: p.textoSecundario),
                      ),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('nada')),
          ),
          if (!gratis) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://wa.me/${ConfigLiga.whatsappActual}?text=${Uri.encodeComponent(resultado.mensajeWhatsapp)}'),
                mode: LaunchMode.externalApplication,
              ),
              icon: Icon(IconosMarca.whatsapp, size: 18),
              label: const Text('O enviarlo por WhatsApp'),
            ),
          ],
          const SizedBox(height: 10),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Listo')),
          if (esClase) ...[
            const SizedBox(height: 8),
            Text(
              'Si no puedes venir, cancela o reagenda lo antes posible para liberar tu cupo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: p.textoSecundario),
            ),
          ],
        ],
      ),
    );
  }
}
