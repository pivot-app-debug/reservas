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
  EntradaAjuste('equipos', 'Equipos', 'Liga › Equipos', 'categorías quindes mirlxs equipo ajustes de un equipo crear equipo nuevo', dentro: 'liga'),
  EntradaAjuste('tesoreria', 'Finanzas', 'Barra de abajo', 'dinero cuentas caja banco saldo plata finanzas ingreso egreso'),
  EntradaAjuste('pivots', 'Pivots y permisos', 'Liga › Equipos › Pivots', 'administradores admins áreas acceso permisos roles', dentro: 'pivots'),
  EntradaAjuste('coaches', 'Entrenadorxs', 'Liga › Equipos › Entrenadorxs', 'coaches entrenadores entrenadorxs coach nombrar quitar', dentro: 'coaches'),
  EntradaAjuste('pedidos', 'Pedidos de Pivots', 'Ajustes › Pivots y permisos', 'aprobar solicitudes otro pivot automático', dentro: 'pivots'),
  EntradaAjuste(
    'reglas',
    'Reglas de la liga',
    'Ajustes › Equipos › De toda la liga',
    'reglas cobros asistencia puntos equipamiento privacidad',
    dentro: 'reglas',
  ),
  EntradaAjuste('avisos', 'Avisos al equipo', 'Liga › Comunicación', 'notificaciones mensaje enviar programar push anuncio quién recibe', dentro: 'avisos'),
  EntradaAjuste(
    'archivadas',
    'Personas archivadas',
    'Liga › Equipos › Sin actividad',
    'usuarios eliminadas restaurar volver archivo bajas inactivos',
    dentro: 'archivadas',
  ),
  EntradaAjuste('salud', 'Salud y seguros', 'Ajustes › Datos de la liga', 'seguro médico privado salud pública emergencia atención iess msp'),
  EntradaAjuste('pais', 'País', 'Ajustes › Datos de la liga', 'país teléfono prefijo'),
  EntradaAjuste('zona', 'Zona horaria', 'Ajustes › Datos de la liga', 'hora horario reloj'),
  EntradaAjuste('moneda', 'Moneda', 'Ajustes › Datos de la liga', 'dinero símbolo dólar sol euro peso divisa'),
  // Dentro de Reglas.
  EntradaAjuste(
    'vencimiento',
    'Fecha límite de pago',
    'Ajustes › Reglas',
    'vence vencimiento día gracia recargo multa tarde atraso pagar mora',
    dentro: 'reglas',
  ),
  EntradaAjuste(
    'tolerancia',
    'Tolerancia para llegadas tarde',
    'Ajustes › Reglas',
    'tarde minutos llegar atraso lista tolerancia de llegada',
    dentro: 'reglas',
  ),
  EntradaAjuste(
    'puntoExtra',
    'Recompensas por pagar a tiempo',
    'Ajustes › Reglas',
    'punto extra premio bono descuento clase gratis saldo a favor pronto pago recompensa racha asistencia perfecta mensualidad gratis',
    dentro: 'reglas',
  ),
  EntradaAjuste('rectificaciones', 'Rectificaciones', 'Ajustes › Reglas', 'corregir asistencia mal tomada días revisar pedido', dentro: 'reglas'),
  EntradaAjuste('minimo', 'Pocas personas en un evento', 'Ajustes › Reglas', 'cancelar mínimo personas evento', dentro: 'reglas'),
  EntradaAjuste(
    'estados',
    'Estados',
    'Ajustes › Reglas',
    'lesionadx lesión viaje enfermedad situación personal otro inactividad inactivos pausado aprobar',
    dentro: 'reglas',
  ),
  EntradaAjuste('reservas', 'Reservas por clase', 'Ajustes › Reglas', 'reservar clases cierre sin aprobar próximas', dentro: 'reglas'),
  EntradaAjuste('cupon', 'Clase gratis de bienvenida', 'Ajustes › Reglas', 'cupón primera clase gratis nueva persona cancelar', dentro: 'reglas'),
  EntradaAjuste(
    'sinCobro',
    'Meses y periodos sin cobro',
    'Ajustes › Reglas',
    'no se cobra gratis vacaciones diciembre descuento porcentaje periodo fechas cuota clases',
    dentro: 'reglas',
  ),
  EntradaAjuste('equipos', 'Clases de gracia', 'Ajustes › Equipos › cada equipo', 'gracia gratis sin pagar primera clase cuota equipo'),
  EntradaAjuste('ranking', 'Puntos de otras personas', 'Ajustes › Reglas', 'ranking tabla privacidad ver puntos ocultar', dentro: 'reglas'),
  EntradaAjuste('equipos', 'Préstamo de equipamiento', 'Ajustes › Equipos › cada equipo', 'prestar patines protecciones excepcional emergencia'),
  EntradaAjuste('equipos', 'Cobros de un equipo', 'Ajustes › Equipos › cada equipo', 'cómo paga mensualidad por clase precio propio exentos no pagan cuota'),
  // Dentro de Equipos: se abren directo (Victor, 2026-11-16).
  EntradaAjuste('corte', 'Cuándo se aplican los cambios', 'Ajustes › Equipos', 'corte revisar antes automático día cambio de equipo', dentro: 'equipos'),
  EntradaAjuste('equipos', 'Puntos por asistencia', 'Ajustes › Equipos › cada equipo', 'valor a tiempo tarde puntos fecha'),
  EntradaAjuste('equipos', 'Qué cuenta como clase', 'Ajustes › Equipos › cada equipo', 'clase tipos de evento partido llegadas tarde suman'),
  EntradaAjuste('historial', 'Historial de cambios', 'Ajustes › Equipos', 'quién cambió registro auditoría', dentro: 'equipos'),
  EntradaAjuste('nuevoEquipo', 'Crear un equipo', 'Ajustes › Equipos', 'nuevo equipo agregar', dentro: 'equipos'),
  // Dentro de Tesorería → Cobros.
  EntradaAjuste('mensualidad', 'Mensualidad', 'Finanzas › Cobros', 'precio cuota mes valor', dentro: 'cobros'),
  EntradaAjuste('clase', 'Valor por clase', 'Finanzas › Cobros', 'precio por clase valor clase suelta', dentro: 'cobros'),

  EntradaAjuste(
    'coaches',
    'Entreno',
    'Barra de abajo',
    'entrenamiento coach entrenador entrenadorxs seguimiento jugadorxs progreso ficha deportiva habilidades',
  ),
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
  EntradaAjuste('pagoCoaches', 'Pago a entrenadorxs', 'Finanzas', 'coach entrenadorx entrenador porcentaje 25 pagar sueldo le debe', dentro: 'tesoreria'),
  EntradaAjuste('cobrosBanco', 'Cobros del banco', 'Finanzas', 'mantenimiento comisión banco sms notificación cargo mensual programado', dentro: 'tesoreria'),
  EntradaAjuste('revisionTesoreria', 'Revisar cuentas', 'Finanzas', 'auditoría cuadrar duplicados sin registrar errores descuadre', dentro: 'tesoreria'),
  EntradaAjuste('viajes', 'Fondos de viaje', 'Ajustes › Equipos › De toda la liga', 'fondos de viaje torneo reparto asistencia', dentro: 'viajes'),
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

/// Mi perfil (Victor, 2026-11-22): sus filas y lo que hay dentro de cada una.
/// `dentro` es la pantalla que se abre.
const entradasPerfil = [
  EntradaAjuste('perfil', 'Foto de perfil', 'Mi perfil', 'foto imagen avatar cambiar'),
  EntradaAjuste('perfil', 'Nombre derby y número', 'Mi perfil', 'nombre apodo número camiseta'),
  EntradaAjuste('perfil', 'Pronombres', 'Mi perfil', 'él ella elle pronombre'),
  EntradaAjuste('perfil', 'Teléfono', 'Mi perfil', 'celular whatsapp número contacto'),
  EntradaAjuste('perfil', 'Roles en el equipo', 'Mi perfil', 'rol jammer blocker pivot jugadorx árbitro'),
  EntradaAjuste('perfil', 'Entraste al equipo', 'Mi perfil', 'fecha ingreso aniversario'),
  EntradaAjuste('pagos', 'Mis pagos y reservas', 'Mi perfil', 'recibos cuota suscripciones clases mensualidad deuda comprobante', dentro: 'pagos'),
  EntradaAjuste('excepcion', 'Excepción de cuota', 'Mi perfil', 'no pagar mes viaje lesión pedir excepción', dentro: 'excepcion'),
  EntradaAjuste('salud', 'Salud y emergencia', 'Mi perfil', 'contacto de emergencia ficha médica', dentro: 'salud'),
  EntradaAjuste('salud', 'Alergias', 'Mi perfil › Salud y emergencia', 'alergia alimentos medicamentos', dentro: 'salud'),
  EntradaAjuste('salud', 'Dieta', 'Mi perfil › Salud y emergencia', 'vegetariana vegana comida eventos fiestas', dentro: 'salud'),
  EntradaAjuste('salud', 'Medicamentos y antecedentes', 'Mi perfil › Salud y emergencia', 'medicamentos enfermedades antecedentes', dentro: 'salud'),
  EntradaAjuste('salud', 'Seguro', 'Mi perfil › Salud y emergencia', 'seguro médico privado público contacto del seguro', dentro: 'salud'),
  EntradaAjuste('identidad', 'Identidad y dirección', 'Mi perfil', 'documento cédula pasaporte nombre legal dirección dónde vives', dentro: 'identidad'),
  EntradaAjuste('privacidad', 'Privacidad', 'Mi perfil', 'qué ve el equipo ocultar público', dentro: 'privacidad'),
  EntradaAjuste('privacidad', 'Mi cumpleaños y mi edad', 'Mi perfil › Privacidad', 'fecha de nacimiento cumpleaños edad mostrar', dentro: 'privacidad'),
  EntradaAjuste('notificaciones', 'Notificaciones', 'Mi perfil', 'avisos push alertas recordatorios silenciar', dentro: 'notificaciones'),
  EntradaAjuste('coach', 'Ser entrenadorx', 'Mi perfil', 'coach entrenador entrenadora pedir'),
  EntradaAjuste('cuenta', 'Cuenta y acceso', 'Mi perfil', 'usuario correo contraseña clave', dentro: 'cuenta'),
  EntradaAjuste('cuenta', 'Cerrar sesión', 'Mi perfil › Cuenta y acceso', 'salir cerrar sesión', dentro: 'cuenta'),
  EntradaAjuste('cuenta', 'Ver de nuevo los tours guiados', 'Mi perfil › Cuenta y acceso', 'tour ayuda guía tutorial', dentro: 'cuenta'),
  EntradaAjuste('cuenta', 'Eliminar cuenta', 'Mi perfil › Cuenta y acceso', 'borrar cuenta darme de baja', dentro: 'cuenta'),
  EntradaAjuste('comentarios', 'Enviar comentarios', 'Mi perfil', 'error idea duda sugerencia ayuda soporte'),
];

/// Ajustes de cada equipo (Victor, QA 2026-11-26: buscar "gracia" o
/// "cobro" debe llevar al ajuste dentro del equipo). `dentro` = 'equipo:'
/// (`equipo:` + nombre) y el título es lo que se escribe en el buscador del equipo.
List<EntradaAjuste> entradasEquipos(Iterable<String> equipos) => [
  for (final e in equipos)
    for (final (t, palabras) in const [
      ('Cobros', 'precio mensualidad pago por clase cuota cobrar'),
      ('Clases de gracia', 'gracia sin pagar asistiré deuda'),
      ('Fecha límite de pago', 'vence vencimiento día recargo multa mora'),
      ('Recompensa por pagar a tiempo', 'punto extra premio pronto pago'),
      ('Mantenerse en el equipo', 'requisitos mínimo clases puntos quedarse'),
      ('Ascenso al equipo', 'subir ascender pasar'),
      ('Descenso del equipo', 'bajar descender perder'),
      ('Nombre del equipo', 'renombrar cambiar nombre'),
      ('Equipamiento propio', 'patines protecciones propios'),
      ('Préstamo de equipamiento', 'prestar patines protecciones inventario'),
      ('Puntos por asistencia', 'puntos asistir'),
      ('Qué cuenta como clase', 'entrenamiento cuenta clase tipo evento'),
      ('Fondos de viaje', 'viaje torneo fondo'),
      ('Pago a entrenadorxs', 'coach entrenadorx entrenador porcentaje pagar sueldo 25'),
    ])
      EntradaAjuste(t, '$t de $e', 'Liga › Equipos › $e', '$palabras $e equipo', dentro: 'equipo:$e'),
];

List<EntradaAjuste> buscarAjustes(String q, {bool tesoreria = true, String? solo, List<EntradaAjuste> entradas = entradasLiga}) {
  final palabras = _sinTildes(q).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (palabras.isEmpty) return const [];
  final r = <(int, EntradaAjuste)>[];
  for (final e in entradas) {
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
  const BuscadorLigaScreen({super.key, this.tesoreria = true, this.solo, this.donde = 'Ajustes', this.entradas = entradasLiga, this.ejemplo});
  final bool tesoreria;
  final List<EntradaAjuste> entradas;
  final String? ejemplo;

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
    final r = buscarAjustes(_q, tesoreria: widget.tesoreria, solo: widget.solo, entradas: widget.entradas);
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
                    widget.ejemplo ?? 'Escribe lo que buscas: "tarde", "precio", "whatsapp", "deudas"…',
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
