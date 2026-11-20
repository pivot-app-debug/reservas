import 'package:flutter/material.dart';

import '../core/fechas.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../cursos/cursos_screen.dart';
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
enum PestanaActividad { notificaciones, tareas, clases, sociales }

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
    this.cursosNuevos = false,
    this.inicial = PestanaActividad.notificaciones,
    this.alCrearSocial,
    this.alVerCursos,
  });

  final EventosRepo eventos;
  final BandejaRepo bandeja;
  final TareasRepo tareas;

  /// Pivots, coaches o quien tiene cursos para tomar.
  final bool verClases;
  final bool cursosNuevos;
  final PestanaActividad inicial;

  /// Al crear una fiesta: el Calendario recarga y salta a la fecha.
  final void Function(Map r)? alCrearSocial;

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
    PestanaActividad.sociales,
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
    PestanaActividad.notificaciones => 'Avisos',
    PestanaActividad.tareas => 'Tareas',
    PestanaActividad.clases => 'Cursos',
    PestanaActividad.sociales => 'Fiestas',
  };

  static IconData _icono(PestanaActividad x) => switch (x) {
    PestanaActividad.notificaciones => Icons.notifications_rounded,
    PestanaActividad.tareas => Icons.checklist_rounded,
    PestanaActividad.clases => Icons.school_rounded,
    PestanaActividad.sociales => Icons.celebration_rounded,
  };

  /// Pestañas con íconos grandes (Victor, 2026-11-20); el nombre va en el título.
  Widget _pestana(PivotPaleta p, PestanaActividad x) {
    final icono = Icon(_icono(x), size: 26);
    Widget punto(bool ver) => Badge(isLabelVisible: ver, smallSize: 9, backgroundColor: p.marca, child: icono);
    final Widget hijo = switch (x) {
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
      PestanaActividad.sociales => icono,
    };
    return Tab(
      height: 52,
      child: Tooltip(
        message: nombre(x),
        child: Semantics(label: nombre(x), child: hijo),
      ),
    );
  }

  Widget _cuerpo(PestanaActividad x) {
    final s = widget.eventos.sesion;
    return switch (x) {
      PestanaActividad.notificaciones => BandejaPivotsScreen(repo: widget.bandeja, embebida: true),
      PestanaActividad.tareas => TareasScreen(repo: widget.tareas, embebida: true),
      PestanaActividad.clases => s.esAdmin ? CursosScreen(sesion: s, embebida: true) : CursosAbiertosScreen(sesion: s, embebida: true),
      PestanaActividad.sociales => _PanelSociales(eventos: widget.eventos, alCrear: widget.alCrearSocial),
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
        bottom: TabBar(controller: _tabs, dividerColor: Colors.transparent, tabs: [for (final x in _pestanas) _pestana(p, x)]),
      ),
      body: TabBarView(controller: _tabs, children: [for (final x in _pestanas) _cuerpo(x)]),
    );
  }
}

/// Fiestas y eventos sociales: qué se puede crear y los próximos de la liga.
class _PanelSociales extends StatelessWidget {
  const _PanelSociales({required this.eventos, this.alCrear});
  final EventosRepo eventos;
  final void Function(Map r)? alCrear;

  Future<void> _crear(BuildContext context) async {
    final nav = Navigator.of(context);
    final r = await nav.push<Object>(MaterialPageRoute(builder: (_) => CrearSocialScreen(sesion: eventos.sesion)));
    if (r is! Map) return;
    nav.pop();
    alCrear?.call(r);
  }

  List<Evento> get _proximos {
    final hoy = Fechas.hoy();
    return eventos.eventos.where((e) => e.tipo == kTipoSocial && !e.fecha.isBefore(hoy)).toList()..sort((a, b) => a.fecha.compareTo(b.fecha));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final puede = eventos.sesion.puedeCrearSocial;
    return ListenableBuilder(
      listenable: eventos,
      builder: (context, _) {
        final proximos = _proximos;
        Widget paso(IconData i, String t) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(i, size: 18, color: p.sobreSuave),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t, style: TextStyle(height: 1.35, color: p.sobreSuave)),
              ),
            ],
          ),
        );
        return Scaffold(
          extendBodyBehindAppBar: true,
          // Con fiestas próximas, el "+" flota; sin ninguna, el botón va en la lista (como Tareas y Cursos).
          floatingActionButton: AnimatedScale(
            scale: puede && proximos.isNotEmpty ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: FloatingActionButton.extended(onPressed: () => _crear(context), icon: const Icon(Icons.add_rounded), label: const Text('Nueva fiesta')),
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(16, 12 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fiestas y eventos sociales',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.sobreSuave),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      puede
                          ? 'Fiestas, festividades, cumpleaños, aniversarios o despedidas para la liga. Tú eliges qué tendrá cada una.'
                          : 'Las fiestas y eventos sociales de la liga. Los crea un Pivot de fiestas y eventos sociales.',
                      style: TextStyle(height: 1.35, color: p.sobreSuave),
                    ),
                    paso(Icons.mail_outline_rounded, 'Invitación con fecha, lugar y quién organiza.'),
                    paso(Icons.restaurant_rounded, 'Qué lleva cada quien, para no repetir.'),
                    paso(Icons.redeem_rounded, 'Amigo secreto, regalo robado, playlist, dress code y más.'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (proximos.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      Text(
                        'No hay fiestas próximas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.texto),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        puede ? 'Arma la primera: aparece en el calendario de toda la liga.' : 'Cuando haya una, la verás aquí y en el calendario.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.textoSecundario),
                      ),
                      if (puede) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () => _crear(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Crear una fiesta'),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else ...[
                Text(
                  'PRÓXIMAS',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                ),
                for (final e in proximos) _fila(context, p, e),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _fila(BuildContext context, PivotPaleta p, Evento e) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: ListTile(
      leading: Icon(e.socialSorpresa != null ? Icons.card_giftcard_rounded : iconoSocial(e.socialIcono), color: p.marcaTexto),
      title: Text(e.socialTitulo ?? e.lugar, style: const TextStyle(fontWeight: FontWeight.w600)),
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
