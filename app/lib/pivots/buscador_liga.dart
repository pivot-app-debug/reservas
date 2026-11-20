import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Buscador de Mi Liga (Victor, 2026-11-13), como el de ajustes de Android:
/// encuentra cualquier ajuste, aunque esté dentro de una subsección, lleva
/// hasta ahí y lo hace parpadear.
class EntradaAjuste {
  const EntradaAjuste(this.id, this.titulo, this.ruta, this.palabras, {this.dentro});

  /// Id de la fila a resaltar (en Mi Liga o en la subsección).
  final String id;
  final String titulo;

  /// Dónde está, para mostrarlo: "Mi Liga › Equipos y puntos".
  final String ruta;

  /// Sinónimos para encontrarlo aunque no se escriba el nombre exacto.
  final String palabras;

  /// Subsección que hay que abrir (null = está en Mi Liga).
  final String? dentro;
}

const entradasLiga = [
  EntradaAjuste('equipos', 'Equipos', 'Mi Liga', 'categorías quindes mirlxs equipo ajustes de un equipo'),
  EntradaAjuste('tesoreria', 'Finanzas', 'Barra de abajo', 'dinero cuentas caja banco saldo plata finanzas ingreso egreso'),
  EntradaAjuste('pivots', 'Pivots y permisos', 'Mi Liga › Administrar', 'administradores admins áreas acceso permisos roles'),
  EntradaAjuste('pedidos', 'Pedidos de Pivots', 'Mi Liga › Pivots y permisos', 'aprobar solicitudes otro pivot automático', dentro: 'pivots'),
  EntradaAjuste(
    'reglas',
    'Reglas de la liga',
    'Mi Liga › Equipos › De toda la liga',
    'reglas cobros asistencia puntos equipamiento privacidad',
    dentro: 'reglas',
  ),
  EntradaAjuste('avisos', 'Avisos al equipo', 'Mi Liga › Administrar', 'notificaciones mensaje enviar programar push anuncio quién recibe'),
  EntradaAjuste('archivadas', 'Personas archivadas', 'Mi Liga › Administrar', 'usuarios eliminadas restaurar volver archivo bajas'),
  EntradaAjuste('salud', 'Salud y seguros', 'Mi Liga › Datos de la liga', 'seguro médico privado salud pública emergencia atención iess msp'),
  EntradaAjuste('pais', 'País', 'Mi Liga › Datos de la liga', 'país teléfono prefijo'),
  EntradaAjuste('zona', 'Zona horaria', 'Mi Liga › Datos de la liga', 'hora horario reloj'),
  EntradaAjuste('moneda', 'Moneda', 'Mi Liga › Datos de la liga', 'dinero símbolo dólar sol euro peso divisa'),
  // Dentro de Reglas.
  EntradaAjuste(
    'vencimiento',
    'Fecha límite de pago',
    'Mi Liga › Reglas',
    'vence vencimiento día gracia recargo multa tarde atraso pagar mora',
    dentro: 'reglas',
  ),
  EntradaAjuste(
    'tolerancia',
    'Tolerancia para llegadas tarde',
    'Mi Liga › Reglas',
    'tarde minutos llegar atraso lista tolerancia de llegada',
    dentro: 'reglas',
  ),
  EntradaAjuste(
    'puntoExtra',
    'Recompensas por pagar a tiempo',
    'Mi Liga › Reglas',
    'punto extra premio bono descuento clase gratis saldo a favor pronto pago recompensa racha asistencia perfecta mensualidad gratis',
    dentro: 'reglas',
  ),
  EntradaAjuste('rectificaciones', 'Rectificaciones', 'Mi Liga › Reglas', 'corregir asistencia mal tomada días revisar pedido', dentro: 'reglas'),
  EntradaAjuste('minimo', 'Pocas personas en un evento', 'Mi Liga › Reglas', 'cancelar mínimo personas evento', dentro: 'reglas'),
  EntradaAjuste(
    'estados',
    'Estados',
    'Mi Liga › Reglas',
    'lesionadx lesión viaje enfermedad situación personal otro inactividad inactivos pausado aprobar',
    dentro: 'reglas',
  ),
  EntradaAjuste('reservas', 'Reservas por clase', 'Mi Liga › Reglas', 'reservar clases cierre sin aprobar próximas', dentro: 'reglas'),
  EntradaAjuste('cupon', 'Clase gratis de bienvenida', 'Mi Liga › Reglas', 'cupón primera clase gratis nueva persona cancelar', dentro: 'reglas'),
  EntradaAjuste(
    'sinCobro',
    'Meses y periodos sin cobro',
    'Mi Liga › Reglas',
    'no se cobra gratis vacaciones diciembre descuento porcentaje periodo fechas cuota clases',
    dentro: 'reglas',
  ),
  EntradaAjuste('equipos', 'Clases de gracia', 'Mi Liga › Equipos › cada equipo', 'gracia gratis sin pagar primera clase cuota equipo'),
  EntradaAjuste('ranking', 'Puntos de otras personas', 'Mi Liga › Reglas', 'ranking tabla privacidad ver puntos ocultar', dentro: 'reglas'),
  EntradaAjuste('equipos', 'Préstamo de equipamiento', 'Mi Liga › Equipos › cada equipo', 'prestar patines protecciones excepcional emergencia'),
  EntradaAjuste('equipos', 'Cobros de un equipo', 'Mi Liga › Equipos › cada equipo', 'cómo paga mensualidad por clase precio propio exentos no pagan cuota'),
  // Dentro de Equipos: se abren directo (Victor, 2026-11-16).
  EntradaAjuste('corte', 'Cuándo se aplican los cambios', 'Mi Liga › Equipos', 'corte revisar antes automático día cambio de equipo', dentro: 'equipos'),
  EntradaAjuste('equipos', 'Puntos por asistencia', 'Mi Liga › Equipos › cada equipo', 'valor a tiempo tarde puntos fecha'),
  EntradaAjuste('equipos', 'Qué cuenta como clase', 'Mi Liga › Equipos › cada equipo', 'clase tipos de evento partido llegadas tarde suman'),
  EntradaAjuste('historial', 'Historial de cambios', 'Mi Liga › Equipos', 'quién cambió registro auditoría', dentro: 'equipos'),
  EntradaAjuste('nuevoEquipo', 'Crear un equipo', 'Mi Liga › Equipos', 'nuevo equipo agregar', dentro: 'equipos'),
  // Dentro de Tesorería → Cobros.
  EntradaAjuste('mensualidad', 'Mensualidad', 'Finanzas › Cobros', 'precio cuota mes valor', dentro: 'cobros'),
  EntradaAjuste('clase', 'Valor por clase', 'Finanzas › Cobros', 'precio por clase valor clase suelta', dentro: 'cobros'),

  EntradaAjuste('coaches', 'Coaches', 'Mi Liga', 'coach entrenador entrenadora seguimiento jugadorxs ficha deportiva habilidades'),
  EntradaAjuste('planes', 'Planes de pago', 'Finanzas › Cobros', 'paquete pack trimestral semestral meses clases descuento', dentro: 'cobros'),
  EntradaAjuste(
    'formas',
    'Formas de pago',
    'Finanzas › Cobros',
    'medios cuentas billetera virtual banco transferencia efectivo enlace comprobante logo color',
    dentro: 'cobros',
  ),
  // Dentro de Tesorería.
  EntradaAjuste('cuotas', 'Cuotas del mes', 'Finanzas', 'quién pagó mensualidad desglose debe mes pagos', dentro: 'tesoreria'),
  EntradaAjuste('saldos', 'Saldos de personas', 'Finanzas', 'deudas préstamos a favor debe', dentro: 'tesoreria'),
  EntradaAjuste('viajes', 'Fondos de viaje', 'Mi Liga › Equipos › De toda la liga', 'fondos de viaje torneo reparto asistencia', dentro: 'viajes'),
  EntradaAjuste('movimientos', 'Ver movimientos', 'Finanzas', 'todos los movimientos ingresos gastos exportar excel csv filtrar', dentro: 'tesoreria'),
  EntradaAjuste('transparencia', 'Transparencia', 'Finanzas', 'equipo ve totales público', dentro: 'tesoreria'),
];

String _sinTildes(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u');

List<EntradaAjuste> buscarAjustes(String q, {bool tesoreria = true, String? solo}) {
  final palabras = _sinTildes(q).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (palabras.isEmpty) return const [];
  final r = <(int, EntradaAjuste)>[];
  for (final e in entradasLiga) {
    if (solo != null && e.dentro != solo) continue;
    if (!tesoreria && (e.id == 'tesoreria' || e.id == 'viajes' || e.dentro == 'tesoreria' || e.dentro == 'cobros')) continue;
    final t = _sinTildes(e.titulo), todo = _sinTildes('${e.titulo} ${e.ruta} ${e.palabras}');
    if (!palabras.every(todo.contains)) continue;
    // Primero lo que coincide con el nombre.
    r.add((palabras.every(t.contains) ? 0 : 1, e));
  }
  r.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final x in r) x.$2];
}

/// Pantalla del buscador. Devuelve la entrada elegida.
class BuscadorLigaScreen extends StatefulWidget {
  const BuscadorLigaScreen({super.key, this.tesoreria = true, this.solo, this.donde = 'Mi Liga'});
  final bool tesoreria;

  /// Solo los ajustes de una sección ('reglas', 'cobros'…), para su propia lupa.
  final String? solo;
  final String donde;

  @override
  State<BuscadorLigaScreen> createState() => _BuscadorLigaScreenState();
}

class _BuscadorLigaScreenState extends State<BuscadorLigaScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final r = buscarAjustes(_q, tesoreria: widget.tesoreria, solo: widget.solo);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(hintText: 'Buscar en ${widget.donde}', border: InputBorder.none, filled: false),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _q.trim().isEmpty
            ? Center(
                key: const ValueKey('v'),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Escribe lo que buscas: "tarde", "precio", "whatsapp", "deudas"…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.textoSecundario),
                  ),
                ),
              )
            : r.isEmpty
            ? Center(
                key: const ValueKey('n'),
                child: Text('No hay ajustes con "${_q.trim()}".', style: TextStyle(color: p.textoSecundario)),
              )
            : ListView(
                key: const ValueKey('l'),
                children: [
                  for (final e in r)
                    ListTile(
                      leading: Icon(Icons.subdirectory_arrow_right_rounded, color: p.marcaTexto),
                      title: Text(e.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(e.ruta),
                      onTap: () => Navigator.of(context).pop(e),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Lupa de una sección grande (Victor, 2026-11-16): busca solo en ella y
/// hace parpadear la fila elegida.
class LupaSeccion extends StatelessWidget {
  const LupaSeccion({super.key, required this.seccion, required this.donde, required this.resaltado});
  final String seccion, donde;
  final ValueNotifier<String?> resaltado;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Buscar en $donde',
    icon: const Icon(Icons.search_rounded),
    onPressed: () async {
      final e = await Navigator.of(context).push<EntradaAjuste>(
        MaterialPageRoute(
          builder: (_) => BuscadorLigaScreen(solo: seccion, donde: donde),
        ),
      );
      if (e == null) return;
      resaltado.value = null;
      resaltado.value = e.id;
    },
  );
}

/// Envuelve una fila: cuando `resaltado` tiene su id, la lleva a la vista y
/// la hace parpadear tres veces.
class Resaltable extends StatefulWidget {
  const Resaltable({super.key, required this.id, required this.resaltado, required this.child});
  final String id;
  final ValueNotifier<String?> resaltado;
  final Widget child;

  @override
  State<Resaltable> createState() => _ResaltableState();
}

class _ResaltableState extends State<Resaltable> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    widget.resaltado.addListener(_revisar);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revisar());
  }

  void _revisar() {
    if (!mounted || widget.resaltado.value != widget.id) return;
    Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic, alignment: 0.3).then((_) {
      if (!mounted) return;
      _c.forward(from: 0).then((_) {
        if (widget.resaltado.value == widget.id) widget.resaltado.value = null;
      });
    });
  }

  @override
  void dispose() {
    widget.resaltado.removeListener(_revisar);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.pivot.marca;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, hijo) {
        // Tres pulsos que se apagan.
        final v = _c.isAnimating ? (0.5 - 0.5 * math.cos(_c.value * 6 * math.pi)) * (1 - _c.value * 0.4) : 0.0;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.22 * v)),
          child: hijo,
        );
      },
      child: widget.child,
    );
  }
}
