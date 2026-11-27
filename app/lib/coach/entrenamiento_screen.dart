import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ajustes/componentes.dart' show SubAjustes;
import '../ajustes/herramientas_liga.dart' show FuncionesLiga;
import '../core/fechas.dart';
import '../core/navegacion.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../cursos/cursos_screen.dart';
import '../eventos/detalle_screen.dart' show DetalleScreen;
import '../eventos/eventos_repo.dart';
import '../sesion/sesion.dart';
import 'coach_screen.dart';
import 'equipo_tecnico.dart';
import 'mi_progreso_hero.dart';
import 'niveles_coach.dart';

/// Entreno en la barra de abajo (Victor, 2026-11-26; rediseño del
/// 2026-11-27, mockups A y B): Mi progreso manda, arriba y grande; después
/// los cursos en un carrusel y el próximo entrenamiento. Para entrenadorxs,
/// Mi progreso más compacto, el próximo entrenamiento con su plan y lo que
/// falta evaluar, los cursos y los planes; sus herramientas son íconos en la
/// barra de arriba.
class EntrenamientoScreen extends StatefulWidget {
  const EntrenamientoScreen({super.key, required this.sesion, required this.eventos});
  final Sesion sesion;
  final EventosRepo eventos;

  @override
  State<EntrenamientoScreen> createState() => _EntrenamientoScreenState();
}

class _EntrenamientoScreenState extends State<EntrenamientoScreen> {
  Sesion get s => widget.sesion;
  EstadoCursos _cursos = const EstadoCursos([], false);
  Map<String, dynamic>? _ficha;
  final _herramienta = ValueNotifier<String?>(null);

  bool get _usaCoach => s.esCoach && FuncionesLiga.coach(s);

  @override
  void initState() {
    super.initState();
    s.addListener(_refrescar);
    Navegacion.entrenamiento.addListener(_irAVista);
    WidgetsBinding.instance.addPostFrameCallback((_) => _irAVista());
    _cargar();
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  Future<void> _cargar() async {
    estadoCursos(s).then((e) {
      if (!mounted) return;
      setState(() => _cursos = e);
      Navegacion.puntoEntrenamiento.value = e.nuevos;
    });
    if (!FuncionesLiga.coach(s)) return;
    try {
      final r = await s.api.get('getFichaDeportiva', const {});
      NivelesCoach.actualizar(r['niveles']);
      if (!mounted || r['exito'] == false) return;
      setState(() => _ficha = r);
    } catch (_) {}
  }

  /// Una notificación o Novedades pidió una vista.
  void _irAVista() {
    final v = Navegacion.entrenamiento.value;
    if (v == null || !mounted) return;
    Navegacion.entrenamiento.value = null;
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (v == 'progreso') _abrirProgreso();
    if (v == 'cursos') _abrirCursos();
  }

  void _abrirProgreso() => SubAjustes.abrir<void>(context, FichaDeportivaScreen(sesion: s)).then((_) => _cargar());

  void _abrirCursos() {
    if (_cursos.nuevos) {
      marcarCursosVistos(_cursos.ids);
      setState(() => _cursos = EstadoCursos(_cursos.ids, false));
      Navegacion.puntoEntrenamiento.value = false;
    }
    SubAjustes.abrir<void>(context, s.esAdmin ? CursosScreen(sesion: s) : CursosAbiertosScreen(sesion: s)).then((_) => _cargar());
  }

  @override
  void dispose() {
    s.removeListener(_refrescar);
    Navegacion.entrenamiento.removeListener(_irAVista);
    _herramienta.dispose();
    super.dispose();
  }

  bool get _puedeNombrar => s.esCoach || (s.esAdmin && s.adminToken != null && (s.tieneArea('coach') || s.tieneArea('equipo')));

  Widget _hero({bool compacto = false}) => FuncionesLiga.coach(s)
      ? Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 14),
          child: MiProgresoHero(d: _ficha, compacto: compacto, alTocar: _abrirProgreso),
        )
      : const SizedBox.shrink();

  /// Cursos en un carrusel (mockup A).
  Widget _carrusel(BuildContext context) {
    final p = context.pivot;
    final l = _cursos.lista;
    final nuevos = {for (final x in _cursos.nuevosLista) x.$1};
    final (degradado, sobre) = PivotPaleta.seccion('organizacion', Theme.of(context).brightness);
    String detalle(Map<String, dynamic> c) {
      if (c['miInscripcion'] != null) return 'Ya te inscribiste';
      final f = (c['fechas'] as List? ?? const []).firstOrNull;
      final fecha = DateTime.tryParse('${f is Map ? f['fecha'] : f ?? ''}');
      return [
        if (fecha != null) 'Empieza el ${Fechas.corta(fecha)}',
        if (c['libres'] != null) c['libres'] == 1 ? '1 cupo' : '${c['libres']} cupos',
      ].join(' · ').ifEmpty('Inscripciones abiertas');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'CURSOS',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                ),
              ),
              TextButton(onPressed: _abrirCursos, child: const Text('Ver todos')),
            ],
          ),
        ),
        if (l.isEmpty)
          Material(
            color: p.tarjeta,
            borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
            child: ListTile(
              leading: Icon(Icons.school_outlined, color: p.marcaTexto),
              title: const Text('No hay cursos abiertos ahora'),
              subtitle: const Text('Cuando abran uno para ti, aparece aquí.'),
              onTap: _abrirCursos,
            ),
          )
        else
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: l.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final c = l[i];
                return SizedBox(
                  width: 220,
                  child: Material(
                    color: p.tarjeta,
                    borderRadius: BorderRadius.circular(PivotRadios.tarjeta + 4),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _abrirCursos,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(gradient: degradado, borderRadius: BorderRadius.circular(PivotRadios.chip)),
                                  child: Icon(Symbols.school_rounded, color: sobre, fill: 1, size: 22),
                                ),
                                const Spacer(),
                                if (nuevos.contains('${c['id']}'))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: p.marca, borderRadius: BorderRadius.circular(PivotRadios.chip)),
                                    child: Text(
                                      'Nuevo',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p.sobreMarca),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${c['nombre'] ?? 'Curso'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w800, color: p.texto),
                            ),
                            const Spacer(),
                            Text(
                              detalle(c),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: p.textoSecundario),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    void ir(String h) => _herramienta.value = h;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Entreno', style: TextStyle(fontWeight: FontWeight.w800)),
        // Herramientas de entrenadorx en la barra (mockup B).
        actions: _usaCoach
            ? [
                // Mismos íconos (y trazo) que el resto de la app; el equipo
                // técnico pasó a una sección de la portada (QA 2026-11-27).
                IconButton(tooltip: 'Habilidades', onPressed: () => ir('habilidades'), icon: const Icon(Icons.military_tech_outlined)),
                IconButton(tooltip: 'Pruebas', onPressed: () => ir('pruebas'), icon: const Icon(Icons.timer_outlined)),
                IconButton(
                  tooltip: 'Notificaciones del equipo técnico',
                  onPressed: () => ir('notificaciones'),
                  icon: const Icon(Icons.notifications_active_outlined),
                ),
                const SizedBox(width: 4),
              ]
            : null,
      ),
      body: _usaCoach
          ? CoachScreen(
              sesion: s,
              eventos: widget.eventos,
              embebida: true,
              encabezado: _hero(compacto: true),
              despuesDelProximo: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _carrusel(context),
                  EquipoTecnicoSeccion(sesion: s),
                ],
              ),
              herramienta: _herramienta,
            )
          : _paraTodxs(context),
    );
  }

  /// Para todxs (mockup A): Mi progreso, cursos y el próximo entrenamiento.
  Widget _paraTodxs(BuildContext context) {
    final p = context.pivot;
    return ListenableBuilder(
      listenable: widget.eventos,
      builder: (context, _) {
        final hoy = Fechas.hoy();
        final proximos = [
          for (final e in widget.eventos.eventos)
            if (e.tipo == 'Entrenamiento' && !e.cancelado && !e.finalizado && !e.fecha.isBefore(hoy)) e,
        ]..sort((a, b) => '${Fechas.iso(a.fecha)} ${a.horaInicio}'.compareTo('${Fechas.iso(b.fecha)} ${b.horaInicio}'));
        return RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
            children: [
              _hero(),
              _carrusel(context),
              if (_puedeNombrar) EquipoTecnicoSeccion(sesion: s),
              if (proximos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                  child: Text(
                    proximos.length == 1 ? 'PRÓXIMO ENTRENAMIENTO' : 'PRÓXIMOS ENTRENAMIENTOS',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                  ),
                ),
              for (final e in proximos.take(3))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(Icons.sports_rounded, color: p.marcaTexto),
                    title: Text('${Fechas.dia(e.fecha)} ${Fechas.corta(e.fecha)} · ${e.horaInicio}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      [if (e.lugar.isNotEmpty) e.lugar, e.cantidadAsisten == 1 ? 'Viene 1 persona' : 'Vienen ${e.cantidadAsisten} personas'].join(' · '),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: p.textoSecundario),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DetalleScreen(repo: widget.eventos, eventoId: e.id),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

extension on String {
  String ifEmpty(String otro) => isEmpty ? otro : this;
}
