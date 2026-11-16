import 'package:flutter/material.dart';

import '../ajustes/componentes.dart';
import '../core/config_liga.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../equipo/inventario_modelos.dart';
import '../equipo/inventario_screen.dart';
import '../sesion/sesion.dart';
import 'buscador_liga.dart';
import 'categorias_screen.dart';
import 'cobro_equipo_screen.dart';

import 'editores_liga.dart';
import 'recompensas_asistencia.dart';
import 'recompensas_screen.dart';

import 'vencimiento_screen.dart';

/// Reglas de la liga en un solo lugar (Victor, 2026-11-14), por tema y con
/// a quién aplica cada una ("Toda la liga" o "Solo Quindes"). Las que hoy
/// se pueden cambiar abren su editor; las que todavía están escritas en la
/// app se marcan "Fija por ahora" hasta que exista el asistente de reglas.
/// Filtro por equipo: muestra las de toda la liga y las de ese equipo.
class ReglasScreen extends StatefulWidget {
  const ReglasScreen({super.key, required this.sesion, this.equipo, this.resaltar});
  final Sesion sesion;
  final String? equipo;
  final String? resaltar;

  @override
  State<ReglasScreen> createState() => _ReglasScreenState();
}

class _ReglasScreenState extends State<ReglasScreen> {
  late String? _equipo = widget.equipo;
  List<String> _equipos = const [];
  List<Map<String, dynamic>> _tiers = const [];
  final _resaltado = ValueNotifier<String?>(null);
  late final _recRepo = RecompensasRepo(widget.sesion);
  List<ReglaRecompensa> _recompensas = const [];

  Sesion get s => widget.sesion;

  Future<void> _cargarRecompensas() async {
    try {
      final l = await _recRepo.listar();
      if (mounted) setState(() => _recompensas = l);
    } catch (_) {}
  }

  Future<void> _abrirRecompensa([ReglaRecompensa? r]) async {
    final ok = await SubAjustes.abrir<bool>(context, RecompensaAsistenteScreen(repo: _recRepo, equipos: _equipos, regla: r));
    if (ok == true) _cargarRecompensas();
  }

  Future<void> _activarRecompensa(ReglaRecompensa r, bool v) async {
    final m = ScaffoldMessenger.of(context);
    try {
      final l = await _recRepo.guardar({...r.d, 'activa': v});
      if (mounted) setState(() => _recompensas = l);
    } catch (e) {
      m.showSnackBar(const SnackBar(content: Text('No se pudo guardar. Revisa tu conexión.')));
    }
  }

  Future<void> _cargarEquipos() async {
    try {
      final r = await s.api.get('getTiers', {'adminToken': s.adminToken});
      if (!mounted) return;
      setState(() {
        _tiers = [
          for (final t in (r['tiers'] as List? ?? const []))
            if (t is Map<String, dynamic>) t,
        ]..sort((a, b) => ((a['orden'] as num?) ?? 0).compareTo((b['orden'] as num?) ?? 0));
        _equipos = [for (final t in _tiers) '${t['nombre']}'];
      });
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _cargarEquipos();
    _cargarRecompensas();
    final x = widget.resaltar;
    if (x != null) WidgetsBinding.instance.addPostFrameCallback((_) => _resaltado.value = x);
  }

  @override
  void dispose() {
    _resaltado.dispose();
    super.dispose();
  }

  bool? _ranking;

  /// Regla escrita en la app: se explica en vez de editarse.
  void _fija(String titulo) => showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titulo),
      content: const Text('Por ahora esta regla está escrita en la app y funciona igual que en la web. Se podrá cambiar con el asistente de reglas.'),
      actions: [TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Entendido'))],
    ),
  );

  /// Una regla: título, qué hace, a quién aplica y qué pasa al tocarla.
  Widget _regla(String id, IconData icono, String titulo, String texto, {String? equipo, VoidCallback? editar, String seccion = 'cuota', bool? interruptor}) {
    if (_equipo != null && equipo != null && equipo != _equipo) return const SizedBox.shrink();
    return Resaltable(
      id: id,
      resaltado: _resaltado,
      child: FilaAjuste(
        icono: icono,
        seccion: seccion,
        titulo: titulo,
        valor: texto,
        derecha: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (interruptor != null) Switch(value: interruptor, onChanged: (_) => editar?.call()) else ChipAlcance(equipo: equipo),
            if (editar == null) ...[const SizedBox(width: 6), Icon(Icons.lock_outline_rounded, size: 16, color: context.pivot.textoSecundario)],
          ],
        ),
        alTocar: editar ?? () => _fija(titulo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final c = ConfigLiga.de(s);
    final gracia = c.graciaPorEquipo;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Reglas', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 40),
          children: [
            Text(
              'Cómo funciona la liga: cobros, asistencia, puntos, equipamiento y privacidad. Un cambio rige desde que lo guardas; lo anterior no cambia.',
              style: TextStyle(fontSize: 14, height: 1.4, color: p.texto),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final e in [null, ..._equipos])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Text(e ?? 'Toda la liga'),
                        selected: _equipo == e,
                        onSelected: (_) => setState(() => _equipo = e),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GrupoAjustes(
              titulo: 'Cobros',
              filas: [
                _regla(
                  'vencimiento',
                  Icons.event_busy_outlined,
                  'Fecha límite de pago',
                  textoVencimiento(c),
                  editar: () => SubAjustes.abrir(context, VencimientoScreen(config: c)),
                ),

                for (final e in _equipos)
                  _regla(
                    'cobro_$e',
                    Icons.payments_outlined,
                    'Cómo paga',
                    textoCobroEquipo(c, e),
                    equipo: e,
                    editar: () => SubAjustes.abrir(context, CobroEquipoScreen(config: c, equipo: e)),
                  ),
                for (final e in (_equipos.isEmpty ? gracia.keys : _equipos))
                  _regla(
                    'gracia_$e',
                    Icons.redeem_outlined,
                    'Clases de gracia',
                    gracia[e] == null
                        ? 'No usa: sigue su regla de pago'
                        : (gracia[e] == 0
                              ? 'Debe pagar antes de marcar Asistiré'
                              : '${gracia[e]} ${gracia[e] == 1 ? 'clase' : 'clases'} al mes sin haber pagado; después debe pagar'),
                    equipo: e,
                    editar: () => editarGracia(context, s, c, soloEquipo: e),
                  ),
                _regla(
                  'seisClases',
                  Icons.event_available_outlined,
                  'Clases para reservar',
                  'Se ven las ${c.reservaClasesVisibles} próximas; ${c.reservaCierraHoras == 0 ? 'se puede reservar hasta que empieza' : 'se cierra ${c.reservaCierraHoras} ${c.reservaCierraHoras == 1 ? 'hora' : 'horas'} antes de empezar'}',
                  editar: () => SubAjustes.abrir(context, ReservasReglasScreen(config: c)),
                ),
                _regla(
                  'cupon',
                  Icons.local_activity_outlined,
                  'Clase gratis de bienvenida',
                  'Una por persona nueva; ${c.cuponCancelarMin == 0 ? 'vuelve siempre que cancele' : 'vuelve si cancela con ${c.cuponCancelarMin % 60 == 0 ? '${c.cuponCancelarMin ~/ 60} ${c.cuponCancelarMin == 60 ? 'hora' : 'horas'}' : '${c.cuponCancelarMin} minutos'} de anticipación'}',
                  editar: () => SubAjustes.abrir(context, ReservasReglasScreen(config: c)),
                ),
                _regla(
                  'sinAprobar',
                  Icons.cancel_outlined,
                  'Reserva sin aprobar',
                  '${c.sinAprobarHoras} ${c.sinAprobarHoras == 1 ? 'hora' : 'horas'} después de la clase se cancela; si vino, queda la deuda',
                  editar: () => SubAjustes.abrir(context, ReservasReglasScreen(config: c)),
                ),
                _regla('sinReserva', Icons.person_off_outlined, 'Vino sin reserva', 'Si debía pagar esa clase, queda la deuda del valor por clase'),
              ],
            ),
            const SizedBox(height: 16),
            GrupoAjustes(
              titulo: 'Recompensas',
              pie: 'Se dan solas y le llega un aviso a la persona. Un cambio rige desde que lo guardas; lo ya dado no cambia.',
              filas: [
                _regla(
                  'puntoExtra',
                  Icons.star_outline_rounded,
                  'Por pagar a tiempo',
                  resumenRecompensa(c),
                  editar: () => SubAjustes.abrir(context, RecompensasPagoScreen(config: c)),
                ),
                _regla(
                  'racha3',
                  Icons.local_fire_department_outlined,
                  'Racha de asistencia',
                  'Cada 3 asistencias seguidas, 2 puntos extra',
                  seccion: 'entrenamientos',
                ),
                for (final r in _recompensas)
                  if (_equipo == null || r.equipo == null || r.equipo == _equipo)
                    Resaltable(
                      id: 'rec_${r.id}',
                      resaltado: _resaltado,
                      child: FilaAjuste(
                        icono: Icons.emoji_events_outlined,
                        seccion: 'entrenamientos',
                        titulo: r.nombre,
                        valor: '${r.resumen}${r.otorgadas > 0 ? ' · ${r.otorgadas} ${r.otorgadas == 1 ? 'vez' : 'veces'} dada' : ''}',
                        derecha: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ChipAlcance(equipo: r.equipo),
                            Switch(value: r.activa, onChanged: (v) => _activarRecompensa(r, v)),
                          ],
                        ),
                        alTocar: () => _abrirRecompensa(r),
                      ),
                    ),
                FilaAjuste(
                  icono: Icons.add_rounded,
                  titulo: 'Nueva recompensa',
                  valor: 'Premia la asistencia con puntos, clases o descuentos',
                  alTocar: _abrirRecompensa,
                ),
              ],
            ),
            const SizedBox(height: 16),
            GrupoAjustes(
              titulo: 'Asistencia',
              filas: [
                _regla(
                  'tiposEvento',
                  Icons.category_outlined,
                  'Tipos de evento',
                  c.tiposEventoExtra.isEmpty
                      ? 'Entrenamiento, Partido, Torneo, Asamblea, Evento social y Otro'
                      : 'Los de siempre y ${c.tiposEventoExtra.join(', ')}',
                  seccion: 'entrenamientos',
                  editar: () => SubAjustes.abrir(context, TiposEventoScreen(config: c)),
                ),
                _regla(
                  'tolerancia',
                  Icons.timer_outlined,
                  'Tolerancia para llegadas tarde',
                  '${c.toleranciaMin} minutos: después se sugiere marcar Tarde',
                  seccion: 'entrenamientos',
                  editar: () => numeroLiga(context, c, 'Tolerancia para llegadas tarde', 'toleranciaMin', c.toleranciaMin, 0, 120, 'minutos'),
                ),
                _regla(
                  'rectificaciones',
                  Icons.fact_check_outlined,
                  'Rectificaciones',
                  'Pedidos para corregir una asistencia mal tomada. Se revisan en ${c.rectificacionDias} días',
                  seccion: 'entrenamientos',
                  editar: () => numeroLiga(context, c, 'Días para revisar una rectificación', 'rectificacionDias', c.rectificacionDias, 1, 60, 'días'),
                ),
                _regla(
                  'minimo',
                  Icons.groups_2_outlined,
                  'Pocas personas en un evento',
                  c.eventosMinPersonas == 0 ? 'No se sugiere cancelar' : 'Con menos de ${c.eventosMinPersonas}, se sugiere cancelar',
                  seccion: 'entrenamientos',
                  editar: () => numeroLiga(context, c, 'Sugerir cancelar con menos de', 'eventosMinPersonas', c.eventosMinPersonas, 0, 200, 'personas'),
                ),
                _regla(
                  'inactividad',
                  Icons.hourglass_empty_rounded,
                  'Inactividad',
                  'Pasa a Inactivx tras ${ConfigLiga.diasInactividad} días sin venir a ningún evento',
                  seccion: 'entrenamientos',
                  editar: () => numeroLiga(context, c, 'Pasa a inactiva después de', 'inactividadDias', ConfigLiga.diasInactividad, 7, 365, 'días sin venir'),
                ),
                _regla(
                  'sinPago',
                  Icons.how_to_reg_outlined,
                  'Asistiré sin pago',
                  'Si paga por mes y no ha pagado, al marcar Asistiré se le pide pagar',
                  seccion: 'entrenamientos',
                ),
                for (final e in estadosEditables.entries)
                  _regla(
                    'estado_${e.key}',
                    e.value.$1,
                    e.key,
                    textoEstado(c, e.key),
                    seccion: 'entrenamientos',
                    editar: () => SubAjustes.abrir(context, EstadoScreen(config: c, estado: e.key)),
                  ),
                _regla(
                  'reactivar',
                  Icons.directions_run_rounded,
                  'Volver a Activx',
                  'Si viene a entrenar (a horario o tarde) estando en otro estado, vuelve a Activx y usa su clase de gracia o queda con deuda si no pagó',
                  seccion: 'entrenamientos',
                ),
              ],
            ),
            const SizedBox(height: 16),
            GrupoAjustes(
              titulo: 'Puntos y equipos',
              filas: [
                _regla(
                  'equipos',
                  Icons.workspace_premium_outlined,
                  'Requisitos de cada equipo',
                  'Qué pide cada uno para mantenerse, subir o bajar, y cuántos puntos da asistir',
                  editar: () => SubAjustes.abrir(context, CategoriasScreen(sesion: s)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GrupoAjustes(
              titulo: 'Equipamiento',
              filas: [
                // Equipamiento propio de cada equipo (antes "Entrar con el enlace", Victor 2026-11-15).
                for (final t in _tiers.where((t) => t['es_default'] != true))
                  _regla(
                    'propio_${t['nombre']}',
                    Icons.roller_skating_outlined,
                    'Equipamiento propio',
                    () {
                      final req = (t['requisitos'] as Map?) ?? const {};
                      final x = [if (req['patinesPropios'] == true) 'patines', if (req['proteccionesPropias'] == true) 'protecciones'].join(' y ');
                      return x.isEmpty
                          ? 'No pide equipamiento propio'
                          : 'Pide $x propios. Quien usa los del club pasa a ${_tiers.lastWhere((e) => e['es_default'] == true, orElse: () => t)['nombre']}';
                    }(),
                    equipo: '${t['nombre']}',
                    seccion: 'equipamiento',
                    editar: () async {
                      if (await editarEquipamientoPropio(context, s, t)) _cargarEquipos();
                    },
                  ),
                _regla(
                  'prestamo',
                  Icons.handshake_outlined,
                  'Préstamo de equipamiento',
                  'Cuándo puede pedir equipamiento del club cada equipo',
                  seccion: 'equipamiento',
                  editar: () => SubAjustes.abrir(context, ReglasPrestamoScreen(repo: InventarioRepo(s))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GrupoAjustes(
              titulo: 'Privacidad',
              pie: 'Los Pivots siempre ven todo. Cada persona siempre ve sus propios puntos.',
              filas: [
                _regla(
                  'ranking',
                  Icons.leaderboard_outlined,
                  'Puntos de otras personas',
                  (_ranking ?? c.rankingVisible) ? 'Todo el equipo ve los puntos de todas las personas' : 'Cada persona solo ve sus puntos',
                  seccion: 'privacidad',
                  interruptor: _ranking ?? c.rankingVisible,
                  editar: () async {
                    // Cambia al instante y se guarda por detrás (Victor, 2026-11-16).
                    final v = !(_ranking ?? c.rankingVisible);
                    setState(() => _ranking = v);
                    await guardarReglaLiga(context, c, {'rankingVisible': v});
                    if (mounted) setState(() => _ranking = null);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: p.textoSecundario),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Fija por ahora: funciona igual que en la web y se podrá cambiar con el asistente de reglas.',
                    style: TextStyle(fontSize: 12.5, color: p.textoSecundario),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
