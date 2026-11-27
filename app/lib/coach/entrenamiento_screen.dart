import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ajustes/herramientas_liga.dart' show FuncionesLiga;
import '../core/navegacion.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../cursos/cursos_screen.dart';
import '../eventos/eventos_repo.dart';
import '../sesion/sesion.dart';
import 'coach_screen.dart';

/// Vistas de Entrenamiento.
enum VistaEntrenamiento { entrenamiento, progreso, cursos }

/// Entrenamiento en la barra de abajo (Victor, 2026-11-26), para todxs:
/// las herramientas de entrenadorx (si lo eres), Mi progreso y Cursos. Antes
/// estaban repartidas entre la bandeja y Mi perfil.
class EntrenamientoScreen extends StatefulWidget {
  const EntrenamientoScreen({super.key, required this.sesion, required this.eventos});
  final Sesion sesion;
  final EventosRepo eventos;

  @override
  State<EntrenamientoScreen> createState() => _EntrenamientoScreenState();
}

class _EntrenamientoScreenState extends State<EntrenamientoScreen> with TickerProviderStateMixin {
  Sesion get s => widget.sesion;
  TabController? _tabs;
  List<VistaEntrenamiento> _vistas = const [];
  EstadoCursos _cursos = const EstadoCursos([], false);

  List<VistaEntrenamiento> _calcular() => [
    if (s.esCoach && FuncionesLiga.coach(s)) VistaEntrenamiento.entrenamiento,
    if (FuncionesLiga.coach(s)) VistaEntrenamiento.progreso,
    VistaEntrenamiento.cursos,
  ];

  TabController _controlador() {
    final l = _calcular();
    if (_tabs == null || l.length != _vistas.length) {
      final antes = _tabs == null ? null : _vistas[_tabs!.index];
      _tabs?.dispose();
      _vistas = l;
      _tabs = TabController(length: l.length, vsync: this, initialIndex: antes == null ? 0 : l.indexOf(antes).clamp(0, l.length - 1))..addListener(_alCambiar);
    }
    return _tabs!;
  }

  @override
  void initState() {
    super.initState();
    s.addListener(_refrescar);
    Navegacion.entrenamiento.addListener(_irAVista);
    WidgetsBinding.instance.addPostFrameCallback((_) => _irAVista());
    _cargarCursos();
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  Future<void> _cargarCursos() async {
    final e = await estadoCursos(s);
    if (!mounted) return;
    setState(() => _cursos = e);
    Navegacion.puntoEntrenamiento.value = e.nuevos;
    _alCambiar();
  }

  /// Una notificación o Novedades pidió una vista.
  void _irAVista() {
    final v = Navegacion.entrenamiento.value;
    if (v == null || !mounted) return;
    Navegacion.entrenamiento.value = null;
    final vista = VistaEntrenamiento.values.where((x) => x.name == v).firstOrNull;
    final tabs = _controlador();
    if (vista != null && _vistas.contains(vista)) tabs.animateTo(_vistas.indexOf(vista));
  }

  void _alCambiar() {
    if (_tabs == null || !mounted) return;
    if (_vistas[_tabs!.index] == VistaEntrenamiento.cursos && _cursos.nuevos) {
      marcarCursosVistos(_cursos.ids);
      _cursos = EstadoCursos(_cursos.ids, false);
      Navegacion.puntoEntrenamiento.value = false;
    }
    setState(() {});
  }

  @override
  void dispose() {
    s.removeListener(_refrescar);
    Navegacion.entrenamiento.removeListener(_irAVista);
    _tabs?.dispose();
    super.dispose();
  }

  static String _nombre(VistaEntrenamiento x) => switch (x) {
    VistaEntrenamiento.entrenamiento => 'Entrenamiento',
    VistaEntrenamiento.progreso => 'Mi progreso',
    VistaEntrenamiento.cursos => 'Cursos',
  };

  static IconData _icono(VistaEntrenamiento x) => switch (x) {
    VistaEntrenamiento.entrenamiento => Symbols.sports,
    VistaEntrenamiento.progreso => Symbols.trending_up,
    VistaEntrenamiento.cursos => Symbols.school,
  };

  Widget _cuerpo(VistaEntrenamiento x) => switch (x) {
    VistaEntrenamiento.entrenamiento => CoachScreen(sesion: s, eventos: widget.eventos, embebida: true),
    VistaEntrenamiento.progreso => FichaDeportivaScreen(sesion: s, embebida: true),
    VistaEntrenamiento.cursos => s.esAdmin ? CursosScreen(sesion: s, embebida: true) : CursosAbiertosScreen(sesion: s, embebida: true),
  };

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final tabs = _controlador();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        titleSpacing: 0,
        toolbarHeight: 64,
        title: _vistas.length == 1
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(_nombre(_vistas.first), style: const TextStyle(fontWeight: FontWeight.w800)),
              )
            : Align(alignment: Alignment.centerLeft, child: _pills(p, tabs)),
      ),
      body: TabBarView(controller: tabs, children: [for (final x in _vistas) _cuerpo(x)]),
    );
  }

  /// Pills como en la bandeja: la elegida con ícono y nombre en rojo.
  Widget _pills(PivotPaleta p, TabController tabs) => AnimatedBuilder(
    animation: tabs.animation!,
    builder: (context, _) {
      final actual = tabs.animation!.value.round().clamp(0, _vistas.length - 1);
      return Padding(
        padding: const EdgeInsets.only(left: 8, right: 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, x) in _vistas.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Semantics(
                    selected: i == actual,
                    button: true,
                    label: _nombre(x),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(PivotRadios.chip),
                      onTap: () => tabs.animateTo(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        height: 44,
                        padding: EdgeInsets.symmetric(horizontal: i == actual ? 16 : 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Badge(
                              isLabelVisible: x == VistaEntrenamiento.cursos && _cursos.nuevos,
                              smallSize: 9,
                              backgroundColor: p.marca,
                              child: Icon(_icono(x), size: 24, color: i == actual ? p.marcaTexto : p.textoSecundario, fill: i == actual ? 1 : 0),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              child: i == actual
                                  ? Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        _nombre(x),
                                        style: TextStyle(fontWeight: FontWeight.w700, color: p.marcaTexto),
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
            ],
          ),
        ),
      );
    },
  );
}
