import '../equipo/equipo_repo.dart';

import 'package:flutter/material.dart';

import '../core/banner_ayuda.dart';

import '../core/sincroniza.dart';

import '../ajustes/componentes.dart';
import '../core/tema.dart';
import '../eventos/widgets_comunes.dart' show TextoDeslizante;
import 'crear_tarea_screen.dart';
import 'recurrentes_screen.dart';
import 'tareas_archivadas_screen.dart';
import 'tarea_screen.dart';
import 'tareas_modelos.dart';
import 'tareas_repo.dart';
import 'tareas_widgets.dart';
import '../core/vidrio.dart';
import '../core/esqueleto.dart';

export 'tareas_widgets.dart' show HeroOpcional, PillPuntos, PilaAvatares, IconosAreas;

/// Pestaña Tareas (nativa, 2026-11-08). Mismo lenguaje que Ajustes: grupos
/// en tarjeta, íconos con el degradado del área.
/// Orden: resumen del mes → Mis tareas (lo que vence antes arriba, lo vencido
/// en rojo) → Sugeridas para ti (si faltan puntos para la meta) →
/// Disponibles (con filtro por área) → Sin cupos → Baúl.
class TareasScreen extends StatefulWidget {
  const TareasScreen({super.key, required this.repo, this.embebida = false});

  /// Dentro de una pestaña de Actividad: sin barra propia.
  final bool embebida;
  final TareasRepo repo;

  @override
  State<TareasScreen> createState() => _TareasScreenState();
}

class _TareasScreenState extends State<TareasScreen> {
  TareasRepo get repo => widget.repo;
  String? _area; // filtro de Disponibles

  // Recurrentes y archivadas se piden al abrir y la lista aparece con todo
  // junto, sin cosas que asoman después (Victor, 2026-11-17).
  Future<List<Recurrente>>? _recurrentes;
  bool _extrasListos = false;
  List<Map<String, dynamic>> _archivadas = const [];

  @override
  void initState() {
    super.initState();
    repo.cargar(forzar: repo.cargado);
    EquipoRepo.de(repo.sesion).cargar(); // clases del mes para la meta
    _cargarExtras();
  }

  Future<void> _cargarExtras() async {
    if (!repo.esAdmin) return setState(() => _extrasListos = true);
    final rec = repo.recurrentes();
    _recurrentes = rec;
    try {
      await Future.wait([rec.then((_) {}, onError: (_) {}), repo.archivadas().then((l) => _archivadas = l, onError: (_) => _archivadas = const [])]);
    } catch (_) {}
    if (mounted) setState(() => _extrasListos = true);
  }

  void _abrir(Tarea t, {MiTarea? mia}) => SubAjustes.abrir(context, TareaScreen(repo: repo, tarea: t, mia: mia));

  Future<void> _nueva() async {
    await CrearTareaScreen.abrir(context, repo: repo, modo: repo.esAdmin ? ModoTarea.crear : ModoTarea.proponer);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      // Archivadas: ahora en un carrusel dentro de la lista (Victor, 2026-11-17).
      appBar: widget.embebida
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              flexibleSpace: const Vidrio(child: SizedBox.expand()),
              title: Text('Tareas', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
      // Solo con tareas disponibles; si no hay, el botón está en la lista (Victor, 2026-11-16).
      floatingActionButton: ListenableBuilder(
        listenable: repo,
        builder: (context, _) => AnimatedScale(
          scale: repo.cargado && repo.disponibles.isNotEmpty ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: FloatingActionButton.extended(
            onPressed: _nueva,
            icon: const Icon(Icons.add_rounded),
            label: Text(repo.esAdmin ? 'Nueva tarea' : 'Proponer tarea'),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          // Un solo cambio, de la carga a la lista (Victor, 2026-11-17: se
          // veía rota un momento al cruzarse dos listas).
          final listo = repo.cargado && _extrasListos;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: listo
                ? KeyedSubtree(
                    key: const ValueKey('lista'),
                    child: Sincroniza(onRefresh: () => repo.cargar(forzar: true), child: _lista(context)),
                  )
                : (repo.error == null
                      ? const Esqueleto(key: ValueKey('carga'), forma: FormaEsqueleto.tarjetas)
                      : _Error(key: const ValueKey('error'), texto: repo.error!, alReintentar: () => repo.cargar(forzar: true))),
          );
        },
      ),
    );
  }

  /// Las últimas 3 archivadas, deslizables, y al final "Ver todas".
  Widget _carruselArchivadas(BuildContext context) {
    final p = context.pivot;
    final l = _archivadas.take(3).toList();
    void verTodas() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TareasArchivadasScreen(repo: repo)));
    Widget tarjeta({required Widget child, VoidCallback? alTocar}) => Container(
      width: 230,
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'ARCHIVADAS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
            ),
          ),
          SizedBox(
            height: 124,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                for (final x in l)
                  tarjeta(
                    alTocar: verTodas,
                    child: Builder(
                      builder: (context) {
                        final personas = [
                          for (final y in (x['personas'] as List? ?? const []))
                            if (y is Map) PersonaTarea(Map<String, dynamic>.from(y)),
                        ];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconosAreas(areas: AreaTarea.separar('${x['area'] ?? ''}'), tamano: 22),
                                const Spacer(),
                                PillPuntos(puntos: (x['puntos'] as num?)?.toInt() ?? 0, completo: true),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextoDeslizante(
                              texto: '${x['titulo']}',
                              alineacion: TextAlign.start,
                              estilo: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                            ),
                            const Spacer(),
                            if (personas.isEmpty)
                              Text('Sin personas', style: TextStyle(fontSize: 13, color: p.textoSecundario))
                            else
                              PilaAvatares(personas: personas, tamano: 22),
                          ],
                        );
                      },
                    ),
                  ),
                tarjeta(
                  alTocar: verTodas,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, color: p.marcaTexto),
                      const SizedBox(height: 6),
                      Text(
                        'Ver todas',
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.marcaTexto),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista(BuildContext context) {
    final p = context.pivot;
    final disponibles = repo.disponibles.where((x) => _area == null || x.areas.contains(_area)).toList();
    final areas = {for (final x in repo.disponibles) ...x.areas}.toList()
      ..sort((a, b) => AreaTarea.lista.indexOf(AreaTarea.de(a)).compareTo(AreaTarea.lista.indexOf(AreaTarea.de(b))));
    final sugeridas = repo.sugeridas;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
      children: [
        // Cómo funcionan las tareas (Victor, 2026-11-20).
        BannerAyuda(
          clave: 'ayuda.tareas',
          titulo: '¿Cómo funcionan las tareas?',
          texto: 'Son cosas que el equipo necesita y que suman puntos a quien las hace.',
          pasos: [
            (Icons.front_hand_outlined, 'Toma una tarea disponible y termínala antes de que venza. Cada tarea dice cuántos puntos da.'),
            (Icons.verified_outlined, 'Cuando la marcas como hecha, un Pivot la revisa: si está bien, la aprueba y recibes los puntos.'),
            (
              Icons.add_task_rounded,
              repo.esAdmin
                  ? 'Puedes crear una tarea para el equipo cuando quieras: eliges los puntos, los cupos y el plazo.'
                  : 'Puedes proponer una tarea cuando quieras: un Pivot la revisa, le pone los puntos y la publica.',
            ),
          ],
        ),
        // Sin la tarjeta roja de puntos (Victor, 2026-11-13): se ve en Estadísticas.

        // Sin tareas propias, la sección no aparece (Victor, 2026-11-16).
        if (repo.mias.isNotEmpty)
          GrupoAjustes(
            titulo: 'MIS TAREAS',
            filas: [
              for (final m in repo.mias)
                FilaTarea(
                  tarea: m.tarea,
                  mia: m,
                  alTocar: () => _abrir(m.tarea, mia: m),
                ),
            ],
          ),
        if (repo.esAdmin) RecurrentesScreen(repo: repo, inicial: _recurrentes),
        if (repo.esAdmin && _archivadas.isNotEmpty) _carruselArchivadas(context),
        if (sugeridas.isNotEmpty)
          GrupoAjustes(
            titulo: 'SUGERIDAS PARA TI',
            pie: 'Te faltan ${textoPuntos(repo.faltan)} este mes para ${repo.meta!.nombre}.',
            filas: [for (final x in sugeridas) FilaTarea(tarea: x, hero: false, alTocar: () => _abrir(x))],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            'DISPONIBLES',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: p.textoSecundario),
          ),
        ),
        if (areas.length > 1)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              // Las tarjetas llegan al borde de la pantalla al deslizar (Victor, 2026-11-16).
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: const Text('Todas'), selected: _area == null, onSelected: (_) => setState(() => _area = null)),
                ),
                for (final a in areas)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(AreaTarea.de(a).icono, size: 18),
                      label: Text(a),
                      selected: _area == a,
                      onSelected: (si) => setState(() => _area = si ? a : null),
                    ),
                  ),
              ],
            ),
          ),
        if (disponibles.isEmpty)
          _SinTareas(esPivot: repo.esAdmin, alCrear: _nueva)
        else
          GrupoAjustes(
            filas: [for (final x in disponibles) FilaTarea(tarea: x, alTocar: () => _abrir(x))],
          ),
        if (repo.completas.isNotEmpty)
          GrupoAjustes(
            titulo: 'SIN CUPOS',
            filas: [for (final x in repo.completas) FilaTarea(tarea: x, alTocar: () => _abrir(x))],
          ),
        if (repo.baul.isNotEmpty)
          GrupoAjustes(
            titulo: 'BAÚL',
            pie: 'Tareas que vencieron sin terminarse. Al rescatar una tienes el mismo plazo que tenía, contado desde hoy.',
            filas: [for (final x in repo.baul) FilaTarea(tarea: x, alTocar: () => _abrir(x))],
          ),
      ],
    );
  }
}

/// Disponibles vacía: invitación a crear (o proponer) una tarea.
class _SinTareas extends StatelessWidget {
  const _SinTareas({required this.esPivot, required this.alCrear});
  final bool esPivot;
  final VoidCallback alCrear;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final (degradado, sobre) = PivotPaleta.seccion('organizacion', Theme.of(context).brightness);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.grande)),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(gradient: degradado, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: Icon(Icons.task_alt_rounded, color: sobre, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            'No hay tareas disponibles',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.texto),
          ),
          const SizedBox(height: 4),
          Text(
            esPivot ? 'Crea una para que el equipo sume puntos ayudando.' : 'Propón una: un Pivot la revisa y la publica.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textoSecundario),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: alCrear, icon: const Icon(Icons.add_rounded), label: Text(esPivot ? 'Crear una tarea' : 'Proponer una tarea')),
        ],
      ),
    );
  }
}

/// Fila de una tarea: ícono del área, título, vencimiento o cupos, puntos.
class FilaTarea extends StatelessWidget {
  const FilaTarea({super.key, required this.tarea, this.mia, this.alTocar, this.hero = true});
  final Tarea tarea;

  /// Vuela el ícono al detalle. Apagado donde la misma tarea puede repetirse (Sugeridas).
  final bool hero;
  final MiTarea? mia;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final area = tarea.areaInfo;
    final (degradado, sobre) = PivotPaleta.seccion(area.seccion, Theme.of(context).brightness);
    final m = mia;
    final vencida = m != null && !m.enRevision && (m.dias ?? 0) < 0;
    final String detalle;
    if (m != null) {
      detalle = m.enRevision ? 'En revisión' : (m.notaRechazo.isNotEmpty ? 'Con cambios pedidos · ${textoVence(m.vence)}' : textoVence(m.vence));
    } else if (tarea.enBaul) {
      detalle = 'Venció · se puede rescatar';
    } else if (tarea.libres == 0) {
      detalle = 'Sin cupos · ${textoVence(tarea.vence)}';
    } else {
      detalle = '${tarea.libres == 1 ? '1 cupo libre' : '${tarea.libres} cupos libres'} · ${textoVence(tarea.vence)}';
    }
    final personas = tarea.personas;
    final areas = tarea.areas;
    return InkWell(
      onTap: alTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroOpcional(
              tag: hero ? 'tarea-${tarea.id}' : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(gradient: degradado, borderRadius: BorderRadius.circular(PivotRadios.chip + 2)),
                child: Icon(m?.enRevision == true ? Icons.hourglass_top_rounded : area.icono, size: 20, color: sobre),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Títulos largos se deslizan en bucle (Victor, QA 2026-11-18).
                      Expanded(
                        child: TextoDeslizante(
                          texto: tarea.titulo,
                          alineacion: TextAlign.start,
                          estilo: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: p.texto),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PillPuntos(puntos: tarea.puntos, completo: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (tarea.recurrente) ...[Icon(Icons.repeat_rounded, size: 14, color: p.textoSecundario), const SizedBox(width: 4)],
                      Flexible(
                        child: Text(
                          detalle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: vencida ? p.marcaTexto : p.textoSecundario,
                            fontWeight: vencida ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (areas.length > 1 || personas.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          if (areas.length > 1) IconosAreas(areas: areas, tamano: 22),
                          const Spacer(),
                          if (personas.isNotEmpty) PilaAvatares(personas: personas),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({super.key, required this.texto, required this.alReintentar});
  final String texto;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: p.textoSecundario),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textoSecundario),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: alReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
