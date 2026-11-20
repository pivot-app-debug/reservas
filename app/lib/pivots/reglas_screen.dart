import 'package:flutter/material.dart';

import '../ajustes/componentes.dart';
import '../core/config_liga.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../sesion/sesion.dart';
import 'buscador_liga.dart';
import 'cobro_equipo_screen.dart';

import 'editores_liga.dart';
import 'periodos_sin_cobro_screen.dart';
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
  late final String? _equipo = widget.equipo;
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Reglas de la liga', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [LupaSeccion(seccion: 'reglas', donde: 'Reglas', resaltado: _resaltado)],
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 40 + MediaQuery.paddingOf(context).bottom),
          children: [
            Text(
              'Las reglas de toda la liga. Lo de cada equipo (cobros, clases de gracia, equipamiento, puntos y requisitos) está dentro de cada equipo en Mi Liga. Un cambio rige desde que lo guardas; lo anterior no cambia.',
              style: TextStyle(fontSize: 14, height: 1.4, color: p.texto),
            ),
            const SizedBox(height: 12),
            GrupoAjustes(
              titulo: 'Pagos',
              filas: [
                _regla(
                  'vencimiento',
                  Icons.event_busy_outlined,
                  'Fecha límite de pago',
                  textoVencimiento(c),
                  editar: () => SubAjustes.abrir(context, VencimientoScreen(config: c)),
                ),
                _regla(
                  'reservas',
                  Icons.event_available_outlined,
                  'Reservas por clase',
                  'Se ven las ${c.reservaClasesVisibles} próximas; ${c.reservaCierraHoras == 0 ? 'se reserva hasta que empieza' : 'cierra ${c.reservaCierraHoras} ${c.reservaCierraHoras == 1 ? 'hora' : 'horas'} antes'}; sin aprobar se cierra ${c.sinAprobarHoras} ${c.sinAprobarHoras == 1 ? 'hora' : 'horas'} después',
                  editar: () => SubAjustes.abrir(context, ReservasReglasScreen(config: c)),
                ),
                _regla(
                  'cupon',
                  Icons.local_activity_outlined,
                  'Clase gratis de bienvenida',
                  !c.cuponBienvenida
                      ? 'Apagada'
                      : (!c.cuponVuelve ? 'Una por persona nueva; no vuelve si cancela' : 'Una por persona nueva; vuelve si cancela a tiempo'),
                  editar: () => SubAjustes.abrir(context, ClaseBienvenidaScreen(config: c)),
                ),
                _regla(
                  'sinCobro',
                  Icons.money_off_rounded,
                  'Meses y periodos sin cobro',
                  textoPeriodosSinCobro(c),
                  editar: () => SubAjustes.abrir(context, PeriodosSinCobroScreen(config: c, equipos: _equipos)),
                ),
                _regla('sinReserva', Icons.person_off_outlined, 'Vino sin reserva', 'Si debía pagar esa clase, queda la deuda del valor por clase'),
                _regla('sinPago', Icons.how_to_reg_outlined, 'Asistiré sin pago', 'Si paga por mes y no ha pagado, al marcar Asistiré se le pide pagar'),
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
              titulo: 'Estados',
              filas: [
                _regla(
                  'estados',
                  Icons.person_pin_outlined,
                  'Estados',
                  'Lesionadx, De viaje, Enfermedad, Situación personal, Otro e Inactividad',
                  seccion: 'entrenamientos',
                  editar: () => SubAjustes.abrir(context, EstadosScreen(config: c)),
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
