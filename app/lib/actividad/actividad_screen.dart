import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/fechas.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../ajustes/pagos_screen.dart';
import '../cursos/cursos_screen.dart';
import '../eventos/crear_evento_screen.dart';
import '../eventos/detalle_screen.dart';
import '../eventos/eventos_repo.dart';
import '../eventos/modelos.dart';
import '../eventos/social/crear_social_screen.dart';
import '../eventos/social/social_plantillas.dart';
import '../eventos/tipos_evento.dart';
import '../pivots/bandeja_repo.dart';
import '../pivots/bandeja_screen.dart';
import '../tareas/tareas_repo.dart';
import '../tareas/tareas_screen.dart' show TareasScreen;

/// Pestañas de Actividad.
enum PestanaActividad { notificaciones, tareas, clases, pagos }

/// Actividad (Victor, 2026-11-20): lo que se abre con la campana del
/// Calendario. Junta en pestañas Notificaciones, Tareas, Clases (cursos y
/// clínicas) y Fiestas y eventos sociales; cada pestaña muestra lo de hoy y
/// deja crear desde ahí. Reemplaza los íconos de Tareas y Cursos de la barra.
class ActividadScreen extends StatefulWidget {
  const ActividadScreen({
    super.key,
    required this.eventos,
    required this.bandeja,
    required this.tareas,
    required this.verClases,
    this.verPagos = true,
    this.cursosNuevos = false,
    this.inicial = PestanaActividad.notificaciones,
    this.alCrearSocial,
    this.alCrearEvento,
    this.alVerCursos,
  });

  final EventosRepo eventos;
  final BandejaRepo bandeja;
  final TareasRepo tareas;

  /// Pivots, coaches o quien tiene cursos para tomar.
  final bool verClases;

  /// Quien paga cuota o tiene pagos con el equipo.
  final bool verPagos;
  final bool cursosNuevos;
  final PestanaActividad inicial;

  /// Al crear una fiesta: el Calendario recarga y salta a la fecha.
  final void Function(Map r)? alCrearSocial;

  /// Al crear un evento desde Nuevo evento (resultado de `CrearEventoScreen`).
  final void Function(Object r)? alCrearEvento;

  /// Al entrar a Clases (quita el punto de cursos nuevos).
  final VoidCallback? alVerCursos;

  @override
  State<ActividadScreen> createState() => _ActividadScreenState();
}

class _ActividadScreenState extends State<ActividadScreen> with SingleTickerProviderStateMixin {
  late final List<PestanaActividad> _pestanas = [
    PestanaActividad.notificaciones,
    PestanaActividad.tareas,
    if (widget.verClases) PestanaActividad.clases,
    if (widget.verPagos) PestanaActividad.pagos,
  ];
  late final TabController _tabs = TabController(
    length: _pestanas.length,
    vsync: this,
    initialIndex: _pestanas.contains(widget.inicial) ? _pestanas.indexOf(widget.inicial) : 0,
  );
  late bool _cursosNuevos = widget.cursosNuevos;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_alCambiar);
    _alCambiar();
  }

  void _alCambiar() {
    if (_pestanas[_tabs.index] == PestanaActividad.clases && _cursosNuevos) {
      widget.alVerCursos?.call();
      setState(() => _cursosNuevos = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  static String nombre(PestanaActividad x) => switch (x) {
    PestanaActividad.notificaciones => 'Novedades',
    PestanaActividad.tareas => 'Tareas',
    PestanaActividad.clases => 'Cursos',
    PestanaActividad.pagos => 'Pagos y suscripciones',
  };

  /// Texto corto del pill (el título dice el nombre completo).
  static String _corto(PestanaActividad x) => x == PestanaActividad.pagos ? 'Pagos' : nombre(x);

  // Material Symbols (Victor, 2026-11-20): los mismos íconos de Google Fonts.
  static IconData _icono(PestanaActividad x) => switch (x) {
    PestanaActividad.notificaciones => Symbols.newspaper,
    PestanaActividad.tareas => Symbols.checklist,
    PestanaActividad.clases => Symbols.school,
    PestanaActividad.pagos => Symbols.payments,
  };

  /// Ícono con su punto o número de novedades.
  Widget _iconoCon(PivotPaleta p, PestanaActividad x, Color color, bool lleno) {
    final icono = Icon(_icono(x), size: 24, color: color, fill: lleno ? 1 : 0);
    Widget punto(bool ver) => Badge(isLabelVisible: ver, smallSize: 9, backgroundColor: p.marca, child: icono);
    return switch (x) {
      PestanaActividad.notificaciones => ListenableBuilder(listenable: widget.bandeja, builder: (_, _) => punto(widget.bandeja.hayNovedades)),
      PestanaActividad.tareas => ListenableBuilder(
        listenable: widget.tareas,
        builder: (_, _) => Badge(
          isLabelVisible: widget.tareas.disponibles.isNotEmpty,
          backgroundColor: p.marca,
          label: Text('${widget.tareas.disponibles.length}'),
          child: icono,
        ),
      ),
      PestanaActividad.clases => punto(_cursosNuevos),
      PestanaActividad.pagos => icono,
    };
  }

  /// Navegación por pills (Victor, 2026-11-20): la elegida se expande con su
  /// ícono y su nombre en el color de énfasis; las demás quedan solo con ícono.
  Widget _pills(PivotPaleta p) => AnimatedBuilder(
    animation: _tabs.animation!,
    builder: (context, _) {
      final actual = _tabs.animation!.value.round().clamp(0, _pestanas.length - 1);
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, x) in _pestanas.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Tooltip(
                    message: nombre(x),
                    child: Semantics(
                      selected: i == actual,
                      button: true,
                      label: nombre(x),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(PivotRadios.chip),
                        onTap: () => _tabs.animateTo(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          height: 44,
                          padding: EdgeInsets.symmetric(horizontal: i == actual ? 16 : 12),
                          decoration: BoxDecoration(color: i == actual ? p.marca : p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.chip)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _iconoCon(p, x, i == actual ? p.sobreMarca : p.textoSecundario, i == actual),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                child: i == actual
                                    ? Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Text(
                                          _corto(x),
                                          style: TextStyle(fontWeight: FontWeight.w700, color: p.sobreMarca),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _cuerpo(PestanaActividad x) {
    final s = widget.eventos.sesion;
    return switch (x) {
      // Novedades (Victor, 2026-11-20): primero los próximos eventos, después las notificaciones.
      PestanaActividad.notificaciones => BandejaPivotsScreen(
        repo: widget.bandeja,
        embebida: true,
        encabezado: _SeccionEventos(eventos: widget.eventos, alCrearSocial: widget.alCrearSocial, alCrearEvento: widget.alCrearEvento),
      ),
      PestanaActividad.tareas => TareasScreen(repo: widget.tareas, embebida: true),
      PestanaActividad.clases => s.esAdmin ? CursosScreen(sesion: s, embebida: true) : CursosAbiertosScreen(sesion: s, embebida: true),
      PestanaActividad.pagos => PagosScreen(repo: widget.eventos, embebida: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        // El título dice en qué pestaña estás (Victor, 2026-11-20).
        title: AnimatedBuilder(
          animation: _tabs.animation!,
          builder: (_, _) {
            final i = _tabs.animation!.value.round().clamp(0, _pestanas.length - 1);
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (h, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
                  child: h,
                ),
              ),
              child: Text(
                nombre(_pestanas[i]),
                key: ValueKey(i),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            );
          },
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(54), child: _pills(p)),
      ),
      body: TabBarView(controller: _tabs, children: [for (final x in _pestanas) _cuerpo(x)]),
    );
  }
}

/// Próximos eventos arriba de Novedades (Victor, 2026-11-20): los de la
/// próxima semana, los cumpleaños de los próximos 10 días y las fiestas. Para
/// quien puede crear eventos, un botón fijo (sin botón flotante): un Pivot usa
/// Nuevo evento (que incluye Social o fiesta); un Pivot solo de fiestas, el
/// asistente de fiestas.
class _SeccionEventos extends StatelessWidget {
  const _SeccionEventos({required this.eventos, this.alCrearSocial, this.alCrearEvento});
  final EventosRepo eventos;
  final void Function(Map r)? alCrearSocial;
  final void Function(Object r)? alCrearEvento;

  bool get _puede => eventos.sesion.esAdmin || eventos.sesion.puedeCrearSocial;

  Future<void> _crear(BuildContext context) async {
    final nav = Navigator.of(context);
    final s = eventos.sesion;
    if (s.esAdmin) {
      final r = await nav.push<Object>(MaterialPageRoute(builder: (_) => CrearEventoScreen(repo: eventos)));
      if (r == null) return;
      nav.pop();
      alCrearEvento?.call(r);
      return;
    }
    final r = await nav.push<Object>(MaterialPageRoute(builder: (_) => CrearSocialScreen(sesion: s)));
    if (r is! Map) return;
    nav.pop();
    alCrearSocial?.call(r);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return ListenableBuilder(
      listenable: eventos,
      builder: (context, _) {
        final hoy = Fechas.hoy();
        final finSemana = hoy.add(const Duration(days: 8));
        final proximos = eventos.eventos.where((e) => !e.fecha.isBefore(hoy)).toList()..sort((a, b) => a.fecha.compareTo(b.fecha));
        final semana = proximos.where((e) => e.fecha.isBefore(finSemana)).toList();
        final fiestas = proximos.where((e) => e.tipo == kTipoSocial && !e.fecha.isBefore(finSemana)).toList();
        final cumples = eventos.cumples.where((c) => !c.fecha.isBefore(hoy) && c.fecha.difference(hoy).inDays <= 10).toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));
        Widget titulo(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 2),
          child: Text(
            t,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titulo('PRÓXIMOS 7 DÍAS'),
            if (semana.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text('No hay eventos en los próximos 7 días.', style: TextStyle(color: p.textoSecundario)),
              ),
            for (final e in semana) _fila(context, p, e),
            if (cumples.isNotEmpty) ...[
              titulo('CUMPLEAÑOS PRÓXIMOS'),
              for (final c in cumples)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(c.esAniversario ? Icons.workspace_premium_outlined : Icons.cake_outlined, color: p.marcaTexto),
                  title: Text(c.nombre),
                  subtitle: Text(
                    '${c.fecha == hoy ? 'Hoy' : '${Fechas.dia(c.fecha)} ${c.fecha.day} de ${Fechas.mes(c.fecha)}'}'
                    '${c.esAniversario ? ' · ${c.aniosEquipo} ${c.aniosEquipo == 1 ? 'año' : 'años'} en el equipo' : (c.edad != null ? ' · cumple ${c.edad}' : '')}',
                  ),
                ),
            ],
            if (fiestas.isNotEmpty) ...[titulo('PRÓXIMAS FIESTAS Y EVENTOS SOCIALES'), for (final e in fiestas) _fila(context, p, e)],
            if (_puede) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => _crear(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(eventos.sesion.esAdmin ? 'Crear un evento' : 'Crear una fiesta'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _fila(BuildContext context, PivotPaleta p, Evento e) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: ListTile(
      leading: Icon(
        e.tipo == kTipoSocial ? (e.socialSorpresa != null ? Icons.card_giftcard_rounded : iconoSocial(e.socialIcono)) : Icons.event_outlined,
        color: p.marcaTexto,
      ),
      title: Text(
        e.tipo == kTipoSocial ? (e.socialTitulo ?? e.lugar) : '${etiquetaTipoEvento(e.tipo)} · ${e.lugar}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${Fechas.dia(e.fecha)} ${Fechas.corta(e.fecha)} · ${e.rangoHorario}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetalleScreen(repo: eventos, eventoId: e.id),
        ),
      ),
    ),
  );
}
