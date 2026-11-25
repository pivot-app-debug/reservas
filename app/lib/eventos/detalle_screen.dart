import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../coach/coach_screen.dart';
import '../core/api.dart';
import '../core/fechas.dart';
import '../core/moneda.dart';
import '../core/navegacion.dart';
import '../core/reloj.dart';
import '../core/tema.dart';
import '../reservas/gestionar_reserva.dart';
import '../reservas/reserva_screen.dart';
import '../reservas/reservas_repo.dart';
import 'deco_fiesta.dart';
import 'social/social_plantillas.dart' show iconoSocial;
import '../equipo/emergencia_screen.dart';
import '../equipo/equipo_modelos.dart';
import '../equipo/equipo_repo.dart';
import '../equipo/persona_screen.dart';
import 'anticipada_screen.dart';
import 'editar_evento_screen.dart';
import 'eventos_repo.dart';
import 'tomar_asistencia_screen.dart';
import 'video_screen.dart';
import 'rectificacion.dart';
import 'social/social_evento.dart';
import 'social/social_vista.dart';
import 'social/social_repo.dart' show SocialRepo;
import 'tipos_evento.dart';
import 'modelos.dart';
import 'widgets_comunes.dart';
import '../core/vidrio.dart';
import '../core/esqueleto.dart';

/// Grupos de asistencia del detalle (mismo orden que la web).
enum _Grupo { asisten, noAsisten, noJugador, sinRespuesta }

class DetalleScreen extends StatefulWidget {
  const DetalleScreen({super.key, required this.repo, required this.eventoId, this.abrirCancelar = false, this.abrirNoAsistire = false});
  final EventosRepo repo;
  final String eventoId;

  /// Llega desde el botón "Cancelar entrenamiento" de una notificación:
  /// abre la confirmación apenas carga el evento (nunca cancela sola).
  final bool abrirCancelar;

  /// Llega desde el botón "No asistiré" de una notificación: pide confirmar.
  final bool abrirNoAsistire;

  @override
  State<DetalleScreen> createState() => _DetalleScreenState();
}

class _DetalleScreenState extends State<DetalleScreen> {
  EventosRepo get repo => widget.repo;
  bool _confirmacionPedida = false;

  /// Sube al editar el Social o fiesta para recargar sus piezas.
  final _kSocial = GlobalKey<SocialEnEventoState>();

  // Tour del detalle de un evento (Victor, 2026-11-15).
  final _kResumen = GlobalKey(debugLabel: 'tour-ev-resumen');
  final _kRespuesta = GlobalKey(debugLabel: 'tour-ev-respuesta');
  final _kEquipo = GlobalKey(debugLabel: 'tour-ev-equipo');
  final _kLista = GlobalKey(debugLabel: 'tour-ev-lista');
  final _kAdmin = GlobalKey(debugLabel: 'tour-ev-admin');
  // Sin tour guiado (Victor, 2026-11-16).
  void _tour(Evento ev) {}

  _Grupo _grupo = _Grupo.asisten;
  List<Persona>? _sinRespuesta;
  bool _cargandoSinRespuesta = false;

  bool get _esAdmin => repo.sesion.esAdmin && repo.sesion.adminToken != null;

  /// Fecha del evento en el ícono del Calendario mientras se ve (Victor,
  /// 2026-11-22); al salir vuelve la que había.
  DateTime? _diaAntes;

  DateTime? get _diaDelEvento {
    final ev = repo.porId(widget.eventoId);
    if (ev != null) return ev.fecha;
    final m = RegExp(r'^ev_(\d{4})(\d{2})(\d{2})').firstMatch(widget.eventoId);
    return m == null ? null : DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  @override
  void dispose() {
    final antes = _diaAntes;
    WidgetsBinding.instance.addPostFrameCallback((_) => Navegacion.diaEvento.value = antes);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _diaAntes = Navegacion.diaEvento.value;
    final dia = _diaDelEvento;
    if (dia != null) WidgetsBinding.instance.addPostFrameCallback((_) => Navegacion.diaEvento.value = dia);
    if (repo.porId(widget.eventoId) == null) repo.cargar(forzar: true);
    _cargarSinRespuesta();
    // Qué llevar (Pivots): pill con lo que reservó cada persona.
    if (_esAdmin) {
      repo.queLlevar().then((m) {
        if (mounted) setState(() => _llevar = m[widget.eventoId] ?? const {});
      });
    }
  }

  Map<String, String> _llevar = const {};

  Future<void> _cargarSinRespuesta() async {
    final ev = repo.porId(widget.eventoId);
    if (ev == null || ev.yaEmpezo || !(_esAdmin || ev.tipo == kTipoSocial)) return;
    setState(() => _cargandoSinRespuesta = true);
    try {
      final lista = await repo.sinRespuesta(ev);
      if (mounted) setState(() => _sinRespuesta = lista);
    } catch (_) {
      // Sin este grupo el resto del detalle funciona igual (como en la web).
    } finally {
      if (mounted) setState(() => _cargandoSinRespuesta = false);
    }
  }

  void _emergencia(Persona per) {
    final eq = EquipoRepo.de(repo.sesion);
    final x = eq.persona(per.username) ?? Integrante({'username': per.username, 'nombreDerby': per.nombreDerby});
    EmergenciaScreen.abrir(context, eq, x);
  }

  void _avisar(String texto) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  // ─── Acciones de admin ──────────────────────────────────────────────────

  Future<void> _menuAdmin(Evento ev) async {
    final accion = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!ev.finalizado && !ev.cancelado)
              ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Editar evento'), onTap: () => Navigator.pop(c, 'editar')),
            if (!ev.cancelado)
              ListTile(leading: const Icon(Icons.event_busy_outlined), title: const Text('Cancelar evento'), onTap: () => Navigator.pop(c, 'cancelar')),
            if (ev.cancelado)
              ListTile(leading: const Icon(Icons.restore_outlined), title: const Text('Reactivar evento'), onTap: () => Navigator.pop(c, 'reactivar')),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: c.pivot.marcaTexto),
              title: Text('Eliminar evento', style: TextStyle(color: c.pivot.marcaTexto)),
              onTap: () => Navigator.pop(c, 'eliminar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || accion == null) return;
    switch (accion) {
      case 'editar' when ev.tipo == kTipoSocial:
        // Social o fiesta: se edita con su asistente (Victor, 2026-11-20).
        final ok = await editarSocial(context, repo, ev);
        if (ok == true && mounted) {
          _kSocial.currentState?.recargar();
          _avisar('Cambios guardados.');
        }
      case 'editar':
        final guardado = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => EditarEventoScreen(repo: repo, evento: ev),
          ),
        );
        if (guardado == true) _avisar('Cambios guardados. Se avisó al equipo.');
      case 'cancelar':
        await _confirmarCancelar(ev);
      case 'reactivar':
        await _confirmarReactivar(ev);
      case 'eliminar':
        await _confirmarEliminar(ev);
    }
  }

  Future<bool> _confirmar({required String titulo, required String texto, required String si}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(si)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _confirmarCancelar(Evento ev) async {
    final ok = await _confirmar(
      titulo: '¿Cancelar el ${ev.tipo.toLowerCase()}?',
      texto:
          '${Fechas.encabezado(ev.fecha)} · ${ev.rangoHorario}\n${ev.finalizado ? 'El evento ya pasó: no se avisará al equipo.' : 'Se avisará a todo el equipo.'}',
      si: 'Sí, cancelar',
    );
    if (!ok || !mounted) return;
    var planes = 0;
    try {
      final r = await repo.sesion.api.get('moverPlanesEvento', {'adminToken': repo.sesion.adminToken, 'desde': ev.id, 'soloContar': true});
      planes = (r['cantidad'] as num?)?.toInt() ?? 0;
    } catch (_) {}
    try {
      await repo.cancelar(ev);
      _avisar(ev.finalizado ? 'Evento cancelado.' : 'Evento cancelado. Se avisó al equipo.');
    } catch (e) {
      _avisar(e.toString());
      return;
    }
    if (planes > 0 && mounted) await _moverPlanes(ev, planes);
  }

  /// Reactiva (descancela) un evento: quita la cancelación y avisa al equipo.
  Future<void> _confirmarReactivar(Evento ev) async {
    final ok = await _confirmar(
      titulo: '¿Reactivar el ${ev.tipo.toLowerCase()}?',
      texto: '${Fechas.encabezado(ev.fecha)} · ${ev.rangoHorario}\nSe quitará la cancelación y la gente podrá volver a responder.',
      si: 'Sí, reactivar',
    );
    if (!ok || !mounted) return;
    try {
      await repo.reactivar(ev);
      _avisar('Evento reactivado.');
    } catch (e) {
      _avisar(e.toString());
    }
  }

  /// El evento cancelado tenía planes de coach: a dónde pasan (Victor,
  /// 2026-11-17). Se sugiere el siguiente evento del mismo tipo.
  Future<void> _moverPlanes(Evento ev, int n) async {
    final proximos = [
      for (final e in repo.eventos)
        if (!e.cancelado && e.id != ev.id && e.fecha.isAfter(ev.fecha.subtract(const Duration(days: 1))) && !e.finalizado) e,
    ]..sort((a, b) => '${Fechas.iso(a.fecha)} ${a.horaInicio}'.compareTo('${Fechas.iso(b.fecha)} ${b.horaInicio}'));
    final sugerido = proximos.where((e) => e.tipo == ev.tipo).firstOrNull;
    String titulo(Evento e) => '${e.tipo} · ${Fechas.dia(e.fecha)} ${Fechas.corta(e.fecha)} · ${e.horaInicio}';
    final destino = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (h) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                n == 1 ? 'Este evento tenía un plan de coach' : 'Este evento tenía $n planes de coach',
                style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('¿A dónde lo pasamos?', style: TextStyle(color: h.pivot.textoSecundario)),
            ),
            if (sugerido != null)
              ListTile(
                leading: Icon(Icons.east_rounded, color: h.pivot.marcaTexto),
                title: Text('Al siguiente: ${titulo(sugerido)}'),
                subtitle: const Text('Sugerido'),
                onTap: () => Navigator.of(h).pop(sugerido.id),
              ),
            for (final e in proximos.where((e) => e != sugerido).take(6))
              ListTile(leading: const Icon(Icons.event_outlined), title: Text(titulo(e)), onTap: () => Navigator.of(h).pop(e.id)),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Guardarlo sin fecha'),
              subtitle: const Text('Queda en Coach → Planes sin fecha para asignarlo después'),
              onTap: () => Navigator.of(h).pop(''),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (destino == null || !mounted) return;
    try {
      final r = await repo.sesion.api.post('moverPlanesEvento', {'adminToken': repo.sesion.adminToken, 'desde': ev.id, 'a': destino});
      if (r['exito'] == false) throw ApiException('${r['error']}');
      final sf = (r['sinFecha'] as num?)?.toInt() ?? 0;
      _avisar(
        destino.isEmpty
            ? 'Plan guardado sin fecha.'
            : (sf > 0 ? 'Listo. $sf quedó sin fecha porque ese evento ya tenía plan de ese equipo.' : 'Plan pasado al otro evento.'),
      );
    } catch (e) {
      _avisar(e is ApiException ? e.message : 'No se pudo pasar el plan. Revisa tu conexión.');
    }
  }

  Future<void> _confirmarEliminar(Evento ev) async {
    final ok = await _confirmar(
      titulo: '¿Eliminar el evento?',
      texto: 'Se borrará definitivamente, junto con sus respuestas de asistencia. Esta acción no se puede deshacer.',
      si: 'Eliminar definitivamente',
    );
    if (!ok || !mounted) return;
    try {
      await repo.eliminar(ev);
      if (mounted) Navigator.of(context).pop();
      _avisar('Evento eliminado.');
    } catch (e) {
      _avisar(e.toString());
    }
  }

  // ─── Construcción ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([repo, RelojMinuto.instancia]),
      builder: (context, _) {
        final ev = repo.porId(widget.eventoId);
        if (ev == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: repo.cargando
                  ? const Esqueleto(forma: FormaEsqueleto.tarjetas)
                  : const Padding(padding: EdgeInsets.all(32), child: Text('No encontramos este evento. Puede que lo hayan eliminado.')),
            ),
          );
        }
        if (widget.abrirNoAsistire && !_confirmacionPedida) {
          _confirmacionPedida = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final ok = await _confirmar(
              titulo: '¿No asistirás?',
              texto: '${Fechas.encabezado(ev.fecha)} · ${ev.rangoHorario}\nTu respuesta cambia a "No asistiré".',
              si: 'Sí, no asistiré',
            );
            if (!ok || !mounted) return;
            try {
              final sinSenal = await repo.marcar(ev, EstadoRsvp.noAsistire);
              _avisar(sinSenal ? 'Sin señal: tu respuesta quedó guardada y se sube sola cuando vuelva la conexión.' : 'Listo: no asistirás.');
            } catch (e) {
              _avisar(e.toString());
            }
          });
        }
        if (widget.abrirCancelar && !_confirmacionPedida) {
          _confirmacionPedida = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_esAdmin) {
              _avisar('Solo administradorxs pueden cancelar el evento.');
            } else if (ev.cancelado) {
              _avisar('Este evento ya está cancelado.');
            } else {
              _confirmarCancelar(ev);
            }
          });
        }
        _tour(ev);
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            flexibleSpace: const Vidrio(child: SizedBox.expand()),
            toolbarHeight: 68,
            titleSpacing: 0,
            title: _titulo(context, ev),
            actions: [
              if (ev.cancelado)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Etiqueta(texto: textoEstadoEvento(ev), apagada: true),
                ),
              // Fiesta (Victor, 2026-11-21): cuánto falta y Dudas y preguntas en la barra.
              if (ev.tipo == kTipoSocial && !ev.cancelado && !ev.yaEmpezo)
                Etiqueta(
                  // Con el ícono de la festividad (Victor, 2026-11-22).
                  icono: ev.socialSorpresa != null ? Icons.card_giftcard_rounded : iconoSocial(ev.socialIcono),
                  texto: switch (DateUtils.dateOnly(ev.fecha).difference(Fechas.hoy()).inDays) {
                    <= 0 => 'Es hoy',
                    1 => 'Mañana',
                    final n => 'Faltan $n días',
                  },
                ),
              if (ev.tipo == kTipoSocial && !ev.cancelado)
                ValueListenableBuilder<int>(
                  valueListenable: versionSocial,
                  builder: (_, _, _) => (estadosSociales[ev.id]?.aCargo.isNotEmpty ?? false)
                      ? IconButton(
                          tooltip: 'Dudas y preguntas',
                          icon: const Icon(Icons.help_outline_rounded),
                          onPressed: () => _kSocial.currentState?.abrirDudas(),
                        )
                      : const SizedBox(width: 8),
                ),
            ],
          ),
          floatingActionButton: _esAdmin
              ? FloatingActionButton(
                  key: _kAdmin,
                  tooltip: 'Opciones de administración',
                  onPressed: () => _menuAdmin(ev),
                  child: const Icon(Icons.edit_calendar_outlined),
                )
              // Quien organiza un Social o fiesta lo edita desde aquí (Victor, 2026-11-20).
              : ev.tipo == kTipoSocial && ev.socialOrganiza && !ev.cancelado
              ? FloatingActionButton.extended(
                  tooltip: 'Editar evento',
                  onPressed: () async {
                    final ok = await editarSocial(context, repo, ev);
                    if (ok == true && mounted) {
                      _kSocial.currentState?.recargar();
                      _avisar('Cambios guardados.');
                    }
                  },
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Editar evento'),
                )
              : null,
          body: ListView(
            padding: EdgeInsets.fromLTRB(0, 20 + altoBarra(context), 0, 96 + MediaQuery.paddingOf(context).bottom), // barra de 68
            children: [
              // Fiesta: lo que te falta completar, con atajos (Victor, 2026-11-21).
              if (ev.tipo == kTipoSocial && !ev.cancelado && !ev.finalizado)
                ValueListenableBuilder<int>(
                  valueListenable: versionSocial,
                  builder: (_, _, _) {
                    final e = estadosSociales[ev.id];
                    if (e == null) return const SizedBox.shrink();
                    return PendientesFiesta(
                      estado: e,
                      alParticipar: () => _kSocial.currentState?.participarAmigo(),
                      alDeseos: () => _kSocial.currentState?.abrirDeseos(),
                      alComida: () => _kSocial.currentState?.abrirQueLleva(),
                    );
                  },
                ),
              KeyedSubtree(key: _kResumen, child: _resumen(context, ev)),
              // Plan del coach: "Qué veremos" si lo compartió (Victor, 2026-11-16).
              // Un Social o fiesta no lleva plan: ya se arma con sus piezas (2026-11-20).
              if (ev.tipo != kTipoSocial) PlanEnEvento(sesion: repo.sesion, evento: ev),
              if ((_esAdmin || repo.sesion.esCoach) && ev.sePuedeTomarAsistencia)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: FilledButton.icon(
                    key: _kLista,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TomarAsistenciaScreen(repo: repo, eventoId: ev.id),
                      ),
                    ),
                    icon: const Icon(Icons.how_to_reg_rounded),
                    label: Text(
                      ev.asistentes.isEmpty
                          ? 'Tomar asistencia'
                          : 'Tomar asistencia · ${ev.asistentes.length} ${ev.asistentes.length == 1 ? 'presente' : 'presentes'}',
                    ),
                  ),
                ),
              // Pasado o cancelado (Victor, 2026-11-12): sin botones de respuesta.
              if (!ev.finalizado && !ev.cancelado) KeyedSubtree(key: _kRespuesta, child: _tuAsistencia(context, ev)),
              // Evento social (Naviquinde): +1, amigo secreto, regalo robado y comida.
              if (ev.tipo == kTipoSocial && !ev.cancelado) SocialEnEvento(key: _kSocial, repo: repo, evento: ev),
              if (!ev.cancelado) _tuReserva(context, ev),
              if (ev.cancelado)
                _ibanAIr(context, ev)
              else if (ev.finalizado)
                _quienesFueron(context, ev)
              else if (ev.tipo != kTipoSocial)
                KeyedSubtree(key: _kEquipo, child: _equipo(context, ev)),
            ],
          ),
        );
      },
    );
  }

  /// Fecha y tipo del evento, fijos en la barra superior (pedido 2026-11-06).
  Widget _titulo(BuildContext context, Evento ev) {
    final p = context.pivot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Fechas.encabezado(ev.fecha),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.marcaTexto),
        ),
        const SizedBox(height: 2),
        Text(
          ev.titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            decoration: ev.cancelado ? TextDecoration.lineThrough : null,
            color: ev.cancelado ? p.apagado : p.texto,
          ),
        ),
      ],
    );
  }

  /// Hora, lugar y accesos (Cómo llegar / Ver video) en una sola tarjeta.
  Widget _resumen(BuildContext context, Evento ev) {
    final p = context.pivot;
    final duracion = duracionEvento(ev);
    final botones = <Widget>[
      if (ev.mapsUrl.isNotEmpty) _BotonAcceso(icono: Icons.directions_outlined, texto: 'Cómo llegar', url: ev.mapsUrl),
      if (ev.videoInstructivo.isNotEmpty)
        _BotonAcceso(
          icono: Icons.play_circle_outline_rounded,
          texto: 'Ver video',
          url: ev.videoInstructivo,
          dentroDeLaApp: true,
          titulo: 'Cómo llegar a ${ev.lugar}',
        ),
    ];
    // Fiesta (Victor, 2026-11-22): esta tarjeta es su portada, con el fondo
    // rojizo y el detalle animado de la festividad (quieto si ya pasó).
    final festiva = ev.socialFestivo && !ev.cancelado && ev.socialSorpresa == null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: festiva ? null : p.tarjeta,
        gradient: festiva ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.suave, p.tarjeta], stops: const [0, 0.8]) : null,
        borderRadius: BorderRadius.circular(PivotRadios.grande),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (festiva)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoFiesta(clave: ev.socialIcono ?? '', animada: !ev.finalizado),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, festiva && ev.socialIcono == 'navidad' ? 24 : 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _dato(p, Icons.schedule_rounded, ev.rangoHorario, duracion)),
                    Container(width: 1, height: 36, color: p.tarjetaBorde),
                    const SizedBox(width: 12),
                    Expanded(child: _dato(p, Icons.place_outlined, ev.lugar, null)),
                  ],
                ),
                if (botones.isNotEmpty) ...[const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: botones)],
                if (ev.descripcion.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Divider(height: 1, color: p.tarjetaBorde),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: p.textoSecundario),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(ev.descripcion.trim(), style: TextStyle(fontSize: 14, height: 1.45, color: p.texto)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dato(PivotPaleta p, IconData icono, String principal, String? secundario) {
    return Row(
      children: [
        Icon(icono, size: 22, color: p.textoSecundario),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                principal,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.texto),
              ),
              if (secundario != null && secundario.isNotEmpty) Text(secundario, style: TextStyle(fontSize: 12, color: p.textoSecundario)),
            ],
          ),
        ),
      ],
    );
  }

  /// Fiesta: quien pasa a "No asistiré" elige si sigue en el amigo secreto
  /// (entrega y recibe después) y qué hace con lo que iba a llevar.
  Future<({bool cancelar, String? amigo, String? comida})?> _preguntarDejarDeIr(Evento ev) async {
    final e = estadosSociales[ev.id];
    if (e == null || !e.asiste) return null;
    final enSorteo = e.sorteado && (e.estadoAmigo == 'por_revelar' || e.estadoAmigo == 'revelado');
    final lleva = e.comida.any((c) => c.aportes.any((a) => a['mio'] == true));
    if (!enSorteo && !lleva) return null;
    String? amigo, comida;
    if (enSorteo) {
      amigo = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('¿Sigues en el amigo secreto?'),
          content: const Text('Puedes seguir y entregar y recibir tu regalo después. Si sales, quien te regalaba pasa a regalarle a quien tenías tú.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, 'sale'), child: const Text('Salir')),
            FilledButton(onPressed: () => Navigator.pop(d, 'sigue'), child: const Text('Sigo')),
          ],
        ),
      );
      if (amigo == null) return (cancelar: true, amigo: null, comida: null);
    }
    if (lleva && mounted) {
      comida = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Lo que ibas a llevar'),
          content: const Text('¿Lo quitas de la lista o igual lo envías al lugar del evento?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, 'quitar'), child: const Text('Quitarlo')),
            FilledButton(onPressed: () => Navigator.pop(d, 'enviar'), child: const Text('Igual lo envío')),
          ],
        ),
      );
      if (comida == null) return (cancelar: true, amigo: null, comida: null);
    }
    return (cancelar: false, amigo: amigo, comida: comida);
  }

  /// Clase de gracia usada y el mes sin pagar: ofrece ir a pagar.
  Future<void> _pagarCuota(CuotaPendiente e) async {
    // Con saldo a favor se le dice que puede usarlo (Victor, 2026-11-21).
    double saldo = 0;
    try {
      final r = await repo.sesion.api.get('getMiSaldo');
      saldo = ((r['saldo'] as num?) ?? 0).toDouble();
    } catch (_) {}
    if (!mounted) return;
    final ir = await showModalBottomSheet<bool>(
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
              Text(
                saldo > 0 ? 'Registra tu suscripción de ${Fechas.mes(e.mes)}' : 'Tu cuota de ${Fechas.mes(e.mes)}',
                style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(e.mensaje),
              if (saldo > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Tienes ${Moneda.s}${saldo.toStringAsFixed(2)} a favor: puedes usar todo o una parte para pagar ese mes.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: h.pivot.marcaTexto),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(h).pop(true),
                icon: const Icon(Icons.payments_outlined),
                label: Text('Pagar ${Fechas.mes(e.mes)}'),
              ),
              TextButton(onPressed: () => Navigator.of(h).pop(false), child: const Text('Ahora no')),
            ],
          ),
        ),
      ),
    );
    if (ir != true || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReservaScreen(repo: repo, tipo: TipoReserva.mes, mesInicial: DateTime(e.mes.year, e.mes.month)),
      ),
    );
  }

  /// Aviso del cierre del amigo secreto en "Tu asistencia" (ícono y texto), o null.
  /// Después del cierre se puede seguir marcando Asistiré: vas a la fiesta pero no al sorteo.
  (IconData, String)? _avisoCierre(Evento ev) {
    final c = ev.socialCierre;
    if (ev.tipo != kTipoSocial || c == null || ev.finalizado || ev.cancelado) return null;
    final abierto = !ev.socialSorteado && !Fechas.hoy().isAfter(c);
    if (abierto) {
      return ev.miEstado == EstadoRsvp.asistire
          ? (Icons.redeem_rounded, 'Ya estás en el amigo secreto. La inscripción cierra el ${Fechas.corta(c)}.')
          : (Icons.event_available_rounded, 'Tienes hasta el ${Fechas.corta(c)} para marcar Asistiré y entrar al amigo secreto.');
    }
    // Hasta que se hace el sorteo, quien marca Asistiré todavía entra.
    if (!ev.socialSorteado) {
      return (
        Icons.hourglass_bottom_rounded,
        'La inscripción al amigo secreto cerró el ${Fechas.corta(c)}. Si marcas Asistiré antes de que se haga el sorteo, todavía entras.',
      );
    }
    return ev.miEstado == EstadoRsvp.asistire
        ? (Icons.event_busy_rounded, 'La inscripción al amigo secreto cerró el ${Fechas.corta(c)} y el sorteo ya se hizo.')
        : (Icons.event_busy_rounded, 'El sorteo del amigo secreto ya se hizo. Si marcas Asistiré, vienes a la fiesta pero no participas en el amigo secreto.');
  }

  Widget _tuAsistencia(BuildContext context, Evento ev) {
    final p = context.pivot;
    final motivo = repo.motivoSinRespuesta(ev);
    final bloqueado = motivo != null;
    final sinNo = repo.sinNoAsistire(ev);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.grande)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // En una fiesta, "Asistencia" (Victor, 2026-11-22).
                  ev.tipo == kTipoSocial ? 'Asistencia' : 'Tu asistencia',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
                ),
              ),
            ],
          ),
          // Social o fiesta con amigo secreto: hasta cuándo inscribirse (Victor, 2026-11-20).
          if (_avisoCierre(ev) case final aviso?) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
              child: Row(
                children: [
                  Icon(aviso.$1, size: 20, color: p.marcaTexto),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      aviso.$2,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.sobreSuave),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<EstadoRsvp>(
              showSelectedIcon: true,
              emptySelectionAllowed: true,
              segments: [
                const ButtonSegment(value: EstadoRsvp.asistire, label: Text('Asistiré')),
                if (!sinNo) const ButtonSegment(value: EstadoRsvp.noAsistire, label: Text('No asistiré')),
                // En una fiesta no hay "No jugador" (Victor, 2026-11-20).
                if (ev.tipo != kTipoSocial) const ButtonSegment(value: EstadoRsvp.noJugador, label: Text('No jugador')),
              ],
              selected: {?ev.miEstado},
              onSelectionChanged: bloqueado
                  ? null
                  : (sel) async {
                      if (sel.isEmpty) return;
                      // Fiesta: antes de dejar de ir, qué pasa con el amigo secreto y lo que llevaba (Victor, 2026-11-22).
                      final dejar = sel.first == EstadoRsvp.noAsistire && ev.tipo == kTipoSocial ? await _preguntarDejarDeIr(ev) : null;
                      if (dejar != null && dejar.cancelar) return;
                      try {
                        final sinSenal = await repo.marcar(ev, sel.first);
                        if (dejar != null && (dejar.amigo != null || dejar.comida != null)) {
                          await SocialRepo.miembro(
                            repo.sesion.api,
                            idEvento: ev.id,
                            adminToken: repo.sesion.adminToken,
                          ).dejaDeIr(amigo: dejar.amigo, comida: dejar.comida);
                          _kSocial.currentState?.recargar();
                        }
                        if (sinSenal) _avisar('Sin señal: tu respuesta quedó guardada y se sube sola cuando vuelva la conexión.');
                      } on CuotaPendiente catch (e) {
                        if (mounted) await _pagarCuota(e);
                      } catch (e) {
                        _avisar(e.toString());
                      }
                    },
            ),
          ),
          // Con el aviso del amigo secreto arriba, abajo solo va un motivo si lo hay.
          if ((motivo ?? repo.motivoSinAsistire(ev)) != null || _avisoCierre(ev) == null) ...[
            const SizedBox(height: 10),
            Text(
              motivo ?? repo.motivoSinAsistire(ev) ?? 'Puedes cambiarla hasta 10 minutos antes de que empiece.',
              style: TextStyle(fontSize: 13, color: p.textoSecundario),
            ),
          ],
          // Asistencia anticipada aquí, junto a tu respuesta (Victor, 2026-11-17).
          // Sin asistencia anticipada en un Social o fiesta: es un evento especial (2026-11-20).
          if (repo.anticipada.disponible && ev.tipo != kTipoSocial) ...[const SizedBox(height: 12), _botonAnticipada(context)],
          // Fiesta: invitar a alguien de fuera del equipo desde aquí (Victor, 2026-11-21).
          if (ev.tipo == kTipoSocial)
            ValueListenableBuilder<int>(
              valueListenable: versionSocial,
              builder: (_, _, _) {
                final e = estadosSociales[ev.id];
                if (e == null || !e.modulo('invitados') || !e.asiste) return const SizedBox.shrink();
                final n = e.misInvitados.length;
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: () => _kSocial.currentState?.abrirInvitados(),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(n == 0 ? 'Invita a alguien' : 'Tus invitadxs ($n de ${e.maxInvitados})'),
                  ),
                );
              },
            ),
          // Fiesta: quiénes van, no van y no respondieron, en la misma tarjeta (Victor, 2026-11-20).
          if (ev.tipo == kTipoSocial) ...[const SizedBox(height: 16), KeyedSubtree(key: _kEquipo, child: _equipo(context, ev, embebido: true))],
        ],
      ),
    );
  }

  /// "Crea una asistencia anticipada" con su explicación; si ya tienes
  /// alguna, un botón más sutil que lleva a verlas (Victor, 2026-11-17).
  Widget _botonAnticipada(BuildContext context) {
    final a = repo.anticipada;
    if (a.cuantas.value == null) a.reglas().ignore();
    return ValueListenableBuilder<int?>(
      valueListenable: a.cuantas,
      builder: (context, n, _) {
        final tiene = (n ?? 0) > 0;
        void abrir() => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AnticipadaScreen(repo: repo, abrirNueva: !tiene),
          ),
        );
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: Column(
            key: ValueKey(tiene),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Siempre "Asistencia anticipada", sin texto debajo (Victor, 2026-11-17).
              if (tiene)
                OutlinedButton.icon(onPressed: abrir, icon: const Icon(Icons.event_repeat_rounded), label: const Text('Asistencia anticipada'))
              else
                FilledButton.tonalIcon(onPressed: abrir, icon: const Icon(Icons.event_repeat_rounded), label: const Text('Asistencia anticipada')),
            ],
          ),
        );
      },
    );
  }

  /// Reserva de esta clase: su estado y "Cancelar o reagendar"; sin reserva,
  /// "Reservar esta clase" (Mirlxs) y "Reservar (mes)" si ese mes no está
  /// pagado y no usa equipamiento del club (web: `_evDetalleAccionesHtml()`).
  Widget _tuReserva(BuildContext context, Evento ev) {
    final p = context.pivot;
    final fila = repo.reservaDe(ev);
    final reserva = fila == null ? null : ReservaActiva.desde(fila);
    final Widget contenido;
    if (reserva != null) {
      contenido = Column(
        key: const ValueKey('reserva'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tu reserva',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
              ),
              const Spacer(),
              EstadoReserva(estado: reserva.estado),
            ],
          ),
          if (reserva.estado != 'Confirmada' && reserva.estado != 'Reagendar') ...[
            const SizedBox(height: 8),
            Text('Queda pendiente hasta que el equipo revise tu pago.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
          ],
          if (reserva.gestionable && !ev.yaEmpezo) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: () => gestionarReserva(context, repo, reserva),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Cancelar o reagendar'),
            ),
          ],
        ],
      );
    } else {
      final hoy = Fechas.hoy();
      final futuro = ev.tipo == 'Entrenamiento' && !ev.cancelado && !ev.yaEmpezo && !ev.fecha.isBefore(hoy);
      final opciones = _esAdmin || !futuro ? const <TipoReserva>[] : ReservasRepo(repo.sesion).opciones;
      final cuota = repo.cuota;
      final mesLibre = opciones.contains(TipoReserva.mes) && cuota != null && !cuota.mesPagado(ev.fecha.month, ev.fecha.year);
      if (!opciones.contains(TipoReserva.clase) && !mesLibre) return const SizedBox.shrink(key: ValueKey('nada'));
      contenido = Column(
        key: const ValueKey('reservar'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (opciones.contains(TipoReserva.clase))
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReservaScreen(repo: repo, tipo: TipoReserva.clase, claseInicial: ev.id),
                ),
              ),
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text('Reservar esta clase'),
            ),
          if (opciones.contains(TipoReserva.clase) && mesLibre) const SizedBox(height: 10),
          if (mesLibre)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReservaScreen(repo: repo, tipo: TipoReserva.mes, mesInicial: DateTime(ev.fecha.year, ev.fecha.month)),
                ),
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Reservar ${Fechas.mes(ev.fecha)}'),
            ),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: contenido is SizedBox
          ? contenido
          : Container(
              key: contenido.key,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.grande)),
              child: contenido,
            ),
    );
  }

  /// Admins: cambiar o quitar la respuesta de alguien (Victor, 2026-11-12).
  Future<void> _cambiarRespuesta(Evento ev, Persona per) async {
    final actual = ev.rsvps.where((r) => r.persona.username == per.username).firstOrNull?.estado;
    final elegido = await showModalBottomSheet<(EstadoRsvp?,)>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Respuesta de ${per.nombreMostrar}', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final e in EstadoRsvp.values)
              ListTile(
                leading: Icon(iconoMiEstado(e)),
                title: Text(e.valor),
                trailing: e == actual ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(c, (e,)),
              ),
            ListTile(leading: const Icon(Icons.remove_circle_outline_rounded), title: const Text('Quitar respuesta'), onTap: () => Navigator.pop(c, (null,))),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (elegido == null || elegido.$1 == actual || !mounted) return;
    try {
      await repo.cambiarRespuesta(ev, per, elegido.$1);
      _avisar(elegido.$1 == null ? 'Respuesta quitada.' : 'Respuesta cambiada a "${elegido.$1!.valor}".');
    } catch (e) {
      _avisar(e.toString());
    }
  }

  /// Pivots: cambiar cómo llegó alguien sin abrir la toma de asistencia.
  Future<void> _cambiarReal(Evento ev, AsistenciaReal a) async {
    final elegido = await showModalBottomSheet<(EstadoReal?,)>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (hoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(a.persona.nombreMostrar, style: Theme.of(hoja).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            for (final (estado, texto, icono) in const [
              (EstadoReal.aTiempo, 'Llegó a horario', Icons.check_circle_rounded),
              (EstadoReal.tarde, 'Llegó tarde', Icons.schedule_rounded),
              (null, 'No asistió', Icons.cancel_outlined),
            ])
              ListTile(
                leading: Icon(icono),
                title: Text(texto),
                trailing: estado == a.estado ? Icon(Icons.check_rounded, color: hoja.pivot.marcaTexto) : null,
                onTap: () => Navigator.of(hoja).pop((estado,)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (elegido == null || elegido.$1 == a.estado || !mounted) return;
    try {
      await repo.marcarReal(ev, a.persona, elegido.$1);
      _avisar('Asistencia de ${a.persona.nombreMostrar} actualizada.');
    } catch (e) {
      _avisar(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.');
    }
  }

  /// Evento pasado: quién fue y cómo llegó (Victor, 2026-11-12).
  Widget _quienesFueron(BuildContext context, Evento ev) {
    final p = context.pivot;
    final fueron = [...ev.asistentes]..sort((a, b) => a.persona.nombreMostrar.toLowerCase().compareTo(b.persona.nombreMostrar.toLowerCase()));
    final yo = (repo.sesion.nombre ?? '').toLowerCase();
    final mia = ev.asistentes.where((a) => a.persona.username.toLowerCase() == yo).firstOrNull?.estado;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tu asistencia real y "¿Es correcto?" (rectificaciones, 2026-11-12).
          if (BotonRectificacion.aplica(ev))
            // Toda la tarjeta se toca para pedir la revisión.
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: p.tarjeta,
                borderRadius: BorderRadius.circular(PivotRadios.grande),
                child: InkWell(
                  borderRadius: BorderRadius.circular(PivotRadios.grande),
                  onTap: () => BotonRectificacion(repo: repo, ev: ev).tocar(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        Icon(switch (mia) {
                          EstadoReal.aTiempo => Icons.check_circle_rounded,
                          EstadoReal.tarde => Icons.schedule_rounded,
                          null => Icons.cancel_outlined,
                        }, color: p.marcaTexto),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tu asistencia', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                              Text(switch (mia) {
                                EstadoReal.aTiempo => 'Llegaste a horario',
                                EstadoReal.tarde => 'Llegaste tarde',
                                null => 'No asististe',
                              }, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto)),
                            ],
                          ),
                        ),
                        BotonRectificacion(repo: repo, ev: ev),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              fueron.isEmpty ? 'Asistencia' : 'Quiénes fueron · ${fueron.length}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
            ),
          ),
          const SizedBox(height: 8),
          if (fueron.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Todavía no se tomó asistencia de este evento.', style: TextStyle(color: p.textoSecundario)),
            )
          else
            for (final a in fueron)
              InkWell(
                borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                onTap: () => PersonaScreen.abrir(context, EquipoRepo.de(repo.sesion), a.persona.username),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      HeroAvatar(
                        tag: 'avatar-${a.persona.username}',
                        child: AvatarPersona(nombre: a.persona.nombreMostrar, foto: a.persona.fotoPerfil),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          a.persona.nombreMostrar,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.texto),
                        ),
                      ),
                      // Pivots: tocar el estado lo cambia; el avatar o el nombre abren la ficha (2026-11-13).
                      InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: _esAdmin ? () => _cambiarReal(ev, a) : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Etiqueta(texto: a.estado.etiqueta, icono: a.estado == EstadoReal.aTiempo ? Icons.check_rounded : Icons.schedule_rounded),
                            if (_esAdmin) Icon(Icons.expand_more_rounded, size: 18, color: p.textoSecundario),
                          ],
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

  /// Evento cancelado: a lo sumo, quién había dicho que iba.
  Widget _ibanAIr(BuildContext context, Evento ev) {
    final p = context.pivot;
    final iban = ev.con(EstadoRsvp.asistire).map((r) => r.persona).toList();
    if (iban.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habían dicho que irían · ${iban.length}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.textoSecundario),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final per in iban)
                Chip(
                  avatar: AvatarPersona(nombre: per.nombreMostrar, foto: per.fotoPerfil, tamano: 24),
                  label: Text(per.nombreMostrar),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// En una fiesta (`embebido`) va dentro de Tu asistencia: sin No jugador,
  /// con Sin respuesta para todxs y la lista cerrada hasta tocar un número.
  bool _listaAbierta = false;

  /// Fiesta: caritas de quienes van y el resumen en una línea; al tocar se
  /// abren los números y la lista (Victor, 2026-11-20).
  Widget _resumenQuienesVan(BuildContext context, List<(_Grupo, String, List<Persona>?)> grupos) {
    final p = context.pivot;
    final van = grupos.first.$3 ?? const <Persona>[];
    final caras = van.take(3).toList();
    final partes = [
      for (final g in grupos)
        if (g.$3 != null) '${g.$3!.length} ${g.$2.toLowerCase()}',
    ];
    return InkWell(
      borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
      onTap: () => setState(() => _listaAbierta = !_listaAbierta),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (caras.isNotEmpty) ...[
              SizedBox(
                width: 28.0 + 18 * (caras.length - 1),
                height: 32,
                child: Stack(
                  children: [
                    for (final (i, per) in caras.indexed)
                      Positioned(
                        left: 18.0 * i,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: p.tarjeta, shape: BoxShape.circle),
                          child: AvatarPersona(nombre: per.nombreMostrar, foto: per.fotoPerfil, tamano: 26),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(partes.join(' · '), style: TextStyle(fontSize: 13, color: p.textoSecundario)),
            ),
            AnimatedRotation(
              turns: _listaAbierta ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more_rounded, color: p.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }

  Widget _equipo(BuildContext context, Evento ev, {bool embebido = false}) {
    final p = context.pivot;
    final grupos = <(_Grupo, String, List<Persona>?)>[
      (_Grupo.asisten, 'Asisten', ev.con(EstadoRsvp.asistire).map((r) => r.persona).toList()),
      (_Grupo.noAsisten, 'No asisten', ev.con(EstadoRsvp.noAsistire).map((r) => r.persona).toList()),
      if (!embebido) (_Grupo.noJugador, 'No jugador', ev.con(EstadoRsvp.noJugador).map((r) => r.persona).toList()),
      if ((_esAdmin || embebido) && !ev.yaEmpezo) (_Grupo.sinRespuesta, 'Sin respuesta', _sinRespuesta),
    ];
    final verLista = !embebido || _listaAbierta;
    final elegido = grupos.firstWhere((g) => g.$1 == _grupo, orElse: () => grupos.first);
    final personas = elegido.$3;
    // Admins: Emergencia junto a quien fue marcadx A tiempo o Tarde en este evento.
    final marcadxs = {for (final a in ev.asistentes) a.persona.username.trim().toLowerCase()};
    return Padding(
      padding: embebido ? EdgeInsets.zero : const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (embebido)
            _resumenQuienesVan(context, grupos)
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Asistencia del equipo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (verLista)
            Row(
              children: [
                for (final (i, g) in grupos.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _Contador(
                      cantidad: g.$3?.length,
                      etiqueta: g.$2,
                      elegido: g.$1 == elegido.$1,
                      cargando: g.$1 == _Grupo.sinRespuesta && _cargandoSinRespuesta,
                      alTocar: () => setState(() => _grupo = g.$1),
                    ),
                  ),
                ],
              ],
            ),
          SizedBox(height: verLista ? 12 : 0),
          // Cambio de grupo: "fundido cruzado" de Material (sale la lista
          // anterior, entra la nueva, sin encimarse) y la altura se acomoda
          // suave (antes las dos listas se superponían y saltaba el alto).
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: PageTransitionSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (hijo, primaria, secundaria) =>
                  FadeThroughTransition(animation: primaria, secondaryAnimation: secundaria, fillColor: Colors.transparent, child: hijo),
              layoutBuilder: (hijos) => Stack(alignment: Alignment.topCenter, children: hijos),
              child: KeyedSubtree(
                key: ValueKey('${elegido.$1}-${personas?.length}-$verLista'),
                child: !verLista
                    ? const SizedBox(width: double.infinity)
                    : personas == null
                    ? const Padding(padding: EdgeInsets.all(16), child: EsqueletoFilas())
                    : personas.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Vacío por el momento.', style: TextStyle(color: p.textoSecundario)),
                      )
                    : Column(
                        children: [
                          // Tocar a alguien abre su ficha en Equipo (Victor, 2026-11-07).
                          for (final per in personas)
                            InkWell(
                              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                              onTap: () => PersonaScreen.abrir(context, EquipoRepo.de(repo.sesion), per.username),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Row(
                                  children: [
                                    HeroAvatar(
                                      tag: 'avatar-${per.username}',
                                      child: AvatarPersona(nombre: per.nombreMostrar, foto: per.fotoPerfil),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        per.nombreMostrar,
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.texto),
                                      ),
                                    ),
                                    // Fiesta: lo que lleva cada quien se ve en Qué llevar (Victor, 2026-11-22).
                                    if (ev.tipo != kTipoSocial && _llevar[per.username.toLowerCase()] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Etiqueta(texto: _llevar[per.username.toLowerCase()]!, icono: Icons.content_paste_rounded),
                                      ),
                                    if (_esAdmin &&
                                        marcadxs.contains(per.username.trim().toLowerCase()) &&
                                        per.username.toLowerCase() != (repo.sesion.nombre ?? '').toLowerCase())
                                      PildoraEmergencia(alTocar: () => _emergencia(per))
                                    // La propia se cambia arriba en "Tu asistencia" (Victor, 2026-11-16).
                                    else if (_esAdmin &&
                                        elegido.$1 != _Grupo.sinRespuesta &&
                                        !ev.yaEmpezo &&
                                        per.username.toLowerCase() != (repo.sesion.nombre ?? '').toLowerCase())
                                      IconButton(
                                        tooltip: 'Cambiar respuesta',
                                        icon: Icon(Icons.edit_note_rounded, color: p.textoSecundario),
                                        onPressed: () => _cambiarRespuesta(ev, per),
                                      )
                                    else
                                      Icon(Icons.chevron_right_rounded, color: p.textoSecundario),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.cantidad, required this.etiqueta, required this.elegido, required this.cargando, required this.alTocar});
  final int? cantidad;
  final String etiqueta;
  final bool elegido;
  final bool cargando;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final color = elegido ? p.sobreSuave : p.texto;
    return Material(
      color: elegido ? p.suave : p.apagadoFondo,
      borderRadius: BorderRadius.circular(PivotRadios.contador),
      child: InkWell(
        borderRadius: BorderRadius.circular(PivotRadios.contador),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              SizedBox(
                height: 26,
                child: Center(
                  child: cargando || cantidad == null
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                      : Text(
                          '$cantidad',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color),
                        ),
                ),
              ),
              Text(
                etiqueta,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: elegido ? color : p.textoSecundario),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonAcceso extends StatelessWidget {
  const _BotonAcceso({required this.icono, required this.texto, required this.url, this.dentroDeLaApp = false, this.titulo = ''});
  final bool dentroDeLaApp;
  final String titulo;
  final IconData icono;
  final String texto;
  final String url;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        side: BorderSide(color: p.bordeSuave),
        foregroundColor: p.texto,
      ),
      onPressed: () async {
        if (dentroDeLaApp) {
          await VideoScreen.abrir(context, url, titulo: titulo);
          return;
        }
        final uri = Uri.tryParse(url);
        if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace.')));
          }
        }
      },
      icon: Icon(icono, size: 20, color: p.marcaTexto),
      label: Text(texto),
    );
  }
}
