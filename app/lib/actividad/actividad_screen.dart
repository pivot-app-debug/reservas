import '../ajustes/componentes.dart' show SubAjustes;
import '../core/navegacion.dart';
import '../sesion/sesion.dart';
import '../tareas/tarea_screen.dart' show TareaScreen;
import '../tareas/tareas_modelos.dart';

import 'package:flutter/material.dart';

import 'package:material_symbols_icons/symbols.dart';

import '../core/encabezado_seccion.dart';
import '../core/fechas.dart';
import '../core/tour.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../ajustes/pagos_screen.dart';
import '../cursos/cursos_screen.dart';
import '../eventos/tarjeta_cumple.dart';
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
enum PestanaActividad { notificaciones, tareas, clases, entrenamiento, pagos }

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

class _ActividadScreenState extends State<ActividadScreen> {
  // Bandeja como una sola lista, «Novedades» (Victor, 2026-11-26): eventos,
  // tareas y cursos nuevos; Tareas y Pagos en pills rojas arriba. Cursos y
  // Entrenamiento pasaron a Entrenamiento, en la barra de abajo.
  Sesion get s => widget.eventos.sesion;
  final _kPills = GlobalKey(debugLabel: 'tour-pills');
  final _kCuerpo = GlobalKey(debugLabel: 'tour-cuerpo');
  EstadoCursos _cursos = const EstadoCursos([], false);

  @override
  void initState() {
    super.initState();
    widget.tareas.cargar();
    estadoCursos(s).then((e) {
      if (mounted) setState(() => _cursos = e);
    });
    // Desde una notificación: abre directo lo que pidió.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (widget.inicial) {
        case PestanaActividad.tareas:
          _abrirTareas();
        case PestanaActividad.pagos:
          _abrirPagos();
        case PestanaActividad.clases:
          _irACursos();
        case PestanaActividad.entrenamiento:
          _irA('entrenamiento');
        case PestanaActividad.notificaciones:
          break;
      }
    });
    Future.delayed(const Duration(milliseconds: 900), _tour);
  }

  Future<void> _tour() async {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final crea = s.esAdmin || s.puedeCrearSocial;
    await Tour.mostrarSiCorresponde(
      context,
      preferencia: 'tour.novedades.v1',
      pasos: [
        PasoTour(clave: _kPills, titulo: 'Tareas y pagos', texto: 'Con estos botones entras a las tareas de la liga y a tus pagos y suscripciones.'),
        PasoTour(
          clave: _kCuerpo,
          ajuste: (r) => Rect.fromLTWH(r.left + 8, r.top + altoBarra(context) + 4, r.width - 16, r.height * 0.35),
          titulo: 'Novedades',
          texto: crea
              ? 'Los eventos de los próximos días, tus tareas, los cursos nuevos y tus notificaciones. Aquí también creas eventos.'
              : 'Los eventos de los próximos días, tus tareas, los cursos nuevos y tus notificaciones.',
        ),
      ],
    );
  }

  void _abrirTareas() => SubAjustes.abrir<void>(context, TareasScreen(repo: widget.tareas));
  void _abrirPagos() => SubAjustes.abrir<void>(context, PagosScreen(repo: widget.eventos));

  /// Ir a Entrenamiento en la barra de abajo.
  void _irA(String vista) {
    Navegacion.entrenamiento.value = vista;
    Navegacion.ir.value = Pestana.entrenamiento;
  }

  void _irACursos() {
    widget.alVerCursos?.call();
    _irA('cursos');
  }

  /// Pill roja de acceso (Victor, 2026-11-26).
  Widget _pill(PivotPaleta p, IconData icono, String texto, VoidCallback alTocar, {int? numero}) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: p.marca,
      borderRadius: BorderRadius.circular(PivotRadios.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 18, color: p.sobreMarca),
              const SizedBox(width: 6),
              Text(
                texto,
                style: TextStyle(fontWeight: FontWeight.w700, color: p.sobreMarca),
              ),
              if (numero != null && numero > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: p.sobreMarca, borderRadius: BorderRadius.circular(PivotRadios.chip)),
                  child: Text(
                    '$numero',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.marcaTexto),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _pills(PivotPaleta p) => KeyedSubtree(
    key: _kPills,
    child: ListenableBuilder(
      listenable: widget.tareas,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(p, Symbols.checklist, 'Tareas', _abrirTareas, numero: widget.tareas.disponibles.length),
          if (widget.verPagos) _pill(p, Symbols.payments, 'Pagos', _abrirPagos),
        ],
      ),
    ),
  );

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
        toolbarHeight: 64,
        title: const Text('Novedades', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [_pills(p), const SizedBox(width: 4)],
      ),
      body: KeyedSubtree(
        key: _kCuerpo,
        child: BandejaPivotsScreen(
          repo: widget.bandeja,
          embebida: true,
          encabezado: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SeccionEventos(eventos: widget.eventos, alCrearSocial: widget.alCrearSocial, alCrearEvento: widget.alCrearEvento),
              _SeccionTareas(repo: widget.tareas, alVerTodas: _abrirTareas),
              if (_cursos.nuevosLista.isNotEmpty) ...[
                EncabezadoSeccion(titulo: 'Cursos nuevos', icono: Icons.school_outlined, cantidad: _cursos.nuevosLista.length),
                for (final c in _cursos.nuevosLista.take(3))
                  Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      leading: Icon(Icons.school_outlined, color: p.marcaTexto),
                      title: Text(
                        c.$2,
                        style: TextStyle(fontWeight: FontWeight.w600, color: p.texto),
                      ),
                      subtitle: Text('Nuevo · míralo en Entrenamiento → Cursos', style: TextStyle(color: p.textoSecundario)),
                      trailing: Icon(Icons.chevron_right_rounded, color: p.textoSecundario),
                      onTap: _irACursos,
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tareas en Novedades (Victor, 2026-11-26): las que tomaste y las que hay
/// para tomar.
class _SeccionTareas extends StatelessWidget {
  const _SeccionTareas({required this.repo, required this.alVerTodas});
  final TareasRepo repo;
  final VoidCallback alVerTodas;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final mias = repo.mias.where((m) => !m.terminada).toList();
        final libres = repo.disponibles;
        if (mias.isEmpty && libres.isEmpty) return const SizedBox.shrink();
        Widget fila(Tarea t, String sub, {MiTarea? mia}) => Card(
          margin: const EdgeInsets.only(top: 8),
          child: ListTile(
            leading: Icon(Symbols.checklist, color: p.marcaTexto),
            title: Text(
              t.titulo,
              style: TextStyle(fontWeight: FontWeight.w600, color: p.texto),
            ),
            subtitle: Text(sub, style: TextStyle(color: p.textoSecundario)),
            trailing: Icon(Icons.chevron_right_rounded, color: p.textoSecundario),
            onTap: () => SubAjustes.abrir<void>(context, TareaScreen(repo: repo, tarea: t, mia: mia)),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoSeccion(titulo: 'Tareas', icono: Symbols.checklist, cantidad: mias.length + libres.length),
            for (final m in mias.take(3)) fila(m.tarea, m.enRevision ? 'Tomada por ti · en revisión' : 'Tomada por ti · ${textoVence(m.vence)}', mia: m),
            for (final t in libres.take(3)) fila(t, t.puntos > 0 ? 'Para tomar · ${t.puntos} puntos' : 'Para tomar'),
            if (mias.length + libres.length > 6 || libres.length > 3)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: alVerTodas, child: const Text('Ver todas las tareas')),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoSeccion(titulo: 'Próximos 7 días', icono: Icons.event_outlined, cantidad: semana.isEmpty ? null : semana.length),
            if (semana.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text('No hay eventos en los próximos 7 días.', style: TextStyle(color: p.textoSecundario)),
              ),
            for (final e in semana) _fila(context, p, e),
            // Crear, justo debajo de lo de esta semana (Victor, 2026-11-20).
            // Como el recuadro de crear una tarea (Victor, 2026-11-22).
            if (_puede)
              TarjetaCrear(
                icono: eventos.sesion.esAdmin ? Icons.event_rounded : Icons.celebration_rounded,
                seccion: 'reservas',
                titulo: eventos.sesion.esAdmin ? '¿Viene algo nuevo?' : '¿Armas una fiesta?',
                texto: eventos.sesion.esAdmin
                    ? 'Entrenamientos, partidos, reuniones o fiestas: quedan en el calendario.'
                    : 'Se publica cuando un Pivot la aprueba.',
                boton: eventos.sesion.esAdmin ? 'Crear un evento' : 'Crear una fiesta',
                alTocar: () => _crear(context),
              ),
            if (cumples.isNotEmpty) ...[
              EncabezadoSeccion(titulo: 'Cumpleaños', icono: Icons.cake_outlined, cantidad: cumples.length),
              // Igual que en el timeline (Victor, 2026-11-22).
              for (final c in cumples)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TarjetaCumple(cumple: c),
                ),
            ],
            if (fiestas.isNotEmpty) ...[
              EncabezadoSeccion(titulo: 'Fiestas y eventos sociales', icono: Icons.celebration_outlined, cantidad: fiestas.length),
              for (final e in fiestas) _fila(context, p, e),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _fila(BuildContext context, PivotPaleta p, Evento e) {
    // Fiestas con el fondo y la animación del timeline (Victor, 2026-11-22).
    if (e.socialFestivo && e.socialSorpresa == null && !e.cancelado) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: FondoFestivo(
          clave: e.socialIcono ?? '',
          animada: !e.finalizado,
          child: Builder(builder: (c) => _tile(c, c.pivot, e)),
        ),
      );
    }
    return Card(margin: const EdgeInsets.only(top: 8), child: _tile(context, p, e));
  }

  Widget _tile(BuildContext context, PivotPaleta p, Evento e) => ListTile(
    leading: Icon(
      e.tipo == kTipoSocial ? (e.socialSorpresa != null ? Icons.card_giftcard_rounded : iconoSocial(e.socialIcono)) : Icons.event_outlined,
      color: p.marcaTexto,
    ),
    title: Text(
      e.tipo == kTipoSocial ? (e.socialTitulo ?? e.lugar) : '${etiquetaTipoEvento(e.tipo)} · ${e.lugar}',
      style: TextStyle(fontWeight: FontWeight.w600, color: p.texto),
    ),
    subtitle: Text(style: TextStyle(color: p.textoSecundario), '${Fechas.dia(e.fecha)} ${Fechas.corta(e.fecha)} · ${e.rangoHorario}'),
    trailing: Icon(Icons.chevron_right_rounded, color: p.textoSecundario),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalleScreen(repo: eventos, eventoId: e.id),
      ),
    ),
  );
}
