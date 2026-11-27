import 'package:flutter/material.dart';

import '../ajustes/componentes.dart' show SubAjustes;
import '../ajustes/herramientas_liga.dart' show FuncionesLiga;
import '../core/atajos_color.dart';
import '../core/fechas.dart';
import '../core/navegacion.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../cursos/cursos_screen.dart';
import '../equipo/habilidades_screen.dart' show nivelesCoach;
import '../eventos/detalle_screen.dart' show DetalleScreen;
import '../eventos/eventos_repo.dart';
import '../sesion/sesion.dart';
import 'coach_screen.dart';

/// Entreno en la barra de abajo (Victor, 2026-11-26; sin pestañas desde el
/// 2026-11-27): arriba tarjetas de color como en Liga (Mi progreso, Cursos y,
/// para entrenadorxs, sus herramientas) con lo que hay adentro; debajo, para
/// entrenadorxs, el próximo entrenamiento, lo que falta evaluar y los planes;
/// para el resto, los próximos entrenamientos.
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
  String? _progreso;

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
      if (!mounted || r['exito'] == false) return;
      final habs = (r['habilidades'] as List? ?? const []);
      final logradas = habs.where((h) => (h as Map)['nivel'] == 'logrado').length;
      final nivel = nivelesCoach['${r['nivel'] ?? ''}'];
      setState(() => _progreso = [?nivel, '$logradas de ${habs.length} habilidades'].join(' · '));
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
    super.dispose();
  }

  List<AtajoColor> get _atajos => [
    if (FuncionesLiga.coach(s))
      AtajoColor(
        icono: Icons.trending_up_rounded,
        color: PivotPaleta.atajoRojo,
        titulo: 'Mi progreso',
        detalle: _progreso ?? 'Habilidades, pruebas y notas',
        alTocar: _abrirProgreso,
      ),
    AtajoColor(
      icono: Icons.school_outlined,
      color: PivotPaleta.atajoVerde,
      titulo: 'Cursos',
      punto: _cursos.nuevos,
      detalle: _cursos.nuevos
          ? (_cursos.nuevosLista.length == 1 ? 'Hay un curso nuevo' : 'Hay ${_cursos.nuevosLista.length} cursos nuevos')
          : (_cursos.ids.isEmpty ? 'Cursos y clínicas' : (_cursos.ids.length == 1 ? '1 curso abierto' : '${_cursos.ids.length} cursos abiertos')),
      alTocar: _abrirCursos,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Entreno', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _usaCoach ? CoachScreen(sesion: s, eventos: widget.eventos, embebida: true, atajosExtra: _atajos) : _paraTodxs(context),
    );
  }

  /// Sin herramientas de entrenadorx: los atajos y los próximos entrenamientos.
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
              GrillaAtajos(atajos: _atajos),
              if (proximos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
                  child: Text(
                    'PRÓXIMOS ENTRENAMIENTOS',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                  ),
                ),
              for (final e in proximos.take(4))
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
