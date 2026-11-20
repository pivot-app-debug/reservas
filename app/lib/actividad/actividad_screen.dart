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

  Widget _pestana(PivotPaleta p, PestanaActividad x) {
    Widget punto(bool ver, Widget hijo) => Badge(isLabelVisible: ver, smallSize: 8, backgroundColor: p.marca, child: hijo);
    return switch (x) {
      PestanaActividad.notificaciones => Tab(
        child: ListenableBuilder(listenable: widget.bandeja, builder: (_, _) => punto(widget.bandeja.hayNovedades, const Text('Notificaciones'))),
      ),
      PestanaActividad.tareas => Tab(
        child: ListenableBuilder(
          listenable: widget.tareas,
          builder: (_, _) => Badge(
            isLabelVisible: widget.tareas.disponibles.isNotEmpty,
            backgroundColor: p.marca,
            offset: const Offset(14, -6),
            label: Text('${widget.tareas.disponibles.length}'),
            child: const Text('Tareas'),
          ),
        ),
      ),
      PestanaActividad.clases => Tab(child: punto(_cursosNuevos, const Text('Clases'))),
      PestanaActividad.sociales => const Tab(text: 'Fiestas'),
    };
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
        title: const Text('Actividad', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          // Caben las cuatro en un teléfono angosto.
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          dividerColor: Colors.transparent,
          tabs: [for (final x in _pestanas) _pestana(p, x)],
        ),
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

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final puede = eventos.sesion.puedeCrearSocial;
    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: puede
          ? FloatingActionButton.extended(onPressed: () => _crear(context), icon: const Icon(Icons.add_rounded), label: const Text('Crear evento'))
          : null,
      body: ListenableBuilder(
        listenable: eventos,
        builder: (context, _) {
          final hoy = Fechas.hoy();
          final proximos = eventos.eventos.where((e) => e.tipo == kTipoSocial && !e.fecha.isBefore(hoy)).toList()..sort((a, b) => a.fecha.compareTo(b.fecha));
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 12 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.celebration_outlined, color: p.sobreSuave),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fiestas y eventos sociales',
                            style: TextStyle(fontWeight: FontWeight.w700, color: p.sobreSuave),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            puede
                                ? 'Crea una fiesta, festividad, cumpleaños, aniversario o despedida. Eliges qué tendrá: '
                                      'invitación, qué lleva cada quien, amigo secreto, regalo robado y más.'
                                : 'Aquí ves las próximas fiestas y eventos sociales de la liga. Los crea un Pivot de fiestas y eventos sociales.',
                            style: TextStyle(fontSize: 13, color: p.sobreSuave),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'PRÓXIMOS',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
              ),
              const SizedBox(height: 4),
              if (proximos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No hay fiestas ni eventos sociales próximos.', style: TextStyle(color: p.textoSecundario)),
                ),
              for (final e in proximos) _fila(context, p, e),
            ],
          );
        },
      ),
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
