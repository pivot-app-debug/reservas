import 'package:flutter/material.dart';

import '../coach/coach_screen.dart';
import '../ajustes/herramientas_liga.dart';
import '../liga/directorio_screen.dart';
import '../core/sincroniza.dart';

import '../ajustes/campos.dart';
import '../ajustes/componentes.dart';
import '../core/config_liga.dart';
import '../core/zonas_horarias.dart';
import '../core/paises.dart';
import '../core/tema.dart';
import '../sesion/sesion.dart';
import '../core/tour.dart';
import '../core/vidrio.dart';
import '../finanzas/tesoreria_screen.dart';
import 'buscador_liga.dart';
import '../finanzas/tesoreria_repo.dart';
import '../finanzas/cobros_screen.dart';
import 'reglas_screen.dart';
import 'editores_liga.dart';
import 'archivadas_screen.dart';
import 'avisos_screen.dart';
import '../equipo/equipo_repo.dart';
import 'salud_liga_screen.dart';
import 'categorias_screen.dart';
import 'pivots_screen.dart';

/// Mi perfil → Ajustes de la liga (solo Pivots, Victor 2026-11-13): un solo
/// lugar para lo que configura la liga. Los roles se editan desde la hoja de
/// "Roles en el equipo" (botón "Agregar o editar roles").
class AjustesLigaScreen extends StatefulWidget {
  const AjustesLigaScreen({super.key, required this.sesion, this.pestana = false, this.embebida = false});
  final Sesion sesion;

  /// Pestaña Mi Liga dentro de Liga (Victor, 2026-11-22): sin barra propia;
  /// el buscador va arriba de la lista.
  final bool embebida;

  /// Mi Liga como pestaña de la barra de abajo (Victor, 2026-11-13).
  final bool pestana;

  @override
  State<AjustesLigaScreen> createState() => _AjustesLigaScreenState();

  static const zonas = {
    'America/Guayaquil': 'Ecuador (UTC−5)',
    'America/Bogota': 'Colombia (UTC−5)',
    'America/Lima': 'Perú (UTC−5)',
    'America/Panama': 'Panamá (UTC−5)',
    'America/Mexico_City': 'México, centro (UTC−6)',
    'America/Caracas': 'Venezuela (UTC−4)',
    'America/La_Paz': 'Bolivia (UTC−4)',
    'America/Santiago': 'Chile',
    'America/Argentina/Buenos_Aires': 'Argentina (UTC−3)',
    'America/Montevideo': 'Uruguay (UTC−3)',
    'America/Asuncion': 'Paraguay',
    'America/Sao_Paulo': 'Brasil, São Paulo (UTC−3)',
    'America/New_York': 'Estados Unidos, este',
    'America/Los_Angeles': 'Estados Unidos, pacífico',
    'Europe/Madrid': 'España',
  };
}

class _AjustesLigaScreenState extends State<AjustesLigaScreen> {
  Sesion get sesion => widget.sesion;
  static const zonas = AjustesLigaScreen.zonas;

  /// Fila que el buscador pidió resaltar.
  final _resaltado = ValueNotifier<String?>(null);

  /// Solo Pivots pueden tocar ajustes sensibles como invitar al equipo.
  bool get _pivot => sesion.esAdmin && sesion.adminToken != null;

  @override
  void dispose() {
    _resaltado.dispose();
    super.dispose();
  }

  /// Buscador: lleva al ajuste (abriendo la subsección si hace falta) y lo
  /// hace parpadear.
  Future<void> _buscar() async {
    final e = await Navigator.of(context)
        .push<EntradaAjuste>(
          MaterialPageRoute(
            builder: (_) => BuscadorLigaScreen(
              tesoreria: sesion.tieneArea('finanzas') && FuncionesLiga.finanzas(sesion),
              donde: 'la liga',
              // También los ajustes de cada equipo (QA 2026-11-26).
              entradas: [...entradasLiga, ...entradasEquipos([for (final t in _equipos ?? const <Map<String, dynamic>>[]) '${t['nombre']}'])],
            ),
          ),
        );
    if (e == null || !mounted) return;
    // Finanzas está en Ajustes → Herramientas de la liga (Victor, 2026-11-19).
    if (e.id == 'tesoreria') {
      SubAjustes.abrir(context, TesoreriaScreen(sesion: sesion));
      return;
    }
    final dentro = e.dentro ?? '';
    if (dentro.startsWith('equipo:')) {
      SubAjustes.abrir(context, AjustesEquipoScreen(sesion: sesion, nombre: dentro.substring(7), buscar: e.id));
      return;
    }
    switch (dentro) {
      case 'liga':
        SubAjustes.abrir(context, CategoriasScreen(sesion: sesion));
      case 'coaches':
        SubAjustes.abrir(context, CoachesScreen(sesion: sesion));
      case 'avisos':
        SubAjustes.abrir(context, AvisosScreen(sesion: sesion));
      case 'archivadas':
        SubAjustes.abrir(context, ArchivadasScreen(repo: EquipoRepo.de(sesion)));
      case 'equipos':
        // Sin pasar por la pantalla vieja de Equipos y puntos (Victor, 2026-11-16).
        if (e.id == 'corte') {
          editarCorteEquipos(context, sesion, null);
        } else if (e.id == 'historial') {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HistorialAjustesScreen(sesion: sesion, grupo: 'equipos'),
            ),
          );
        } else {
          SubAjustes.abrir(context, CategoriasScreen(sesion: sesion, resaltar: e.id));
        }
      case 'tesoreria':
        SubAjustes.abrir(context, TesoreriaScreen(sesion: sesion, resaltar: e.id));
      case 'cobros':
        SubAjustes.abrir(context, CobrosScreen(sesion: sesion, resaltar: e.id));
      case 'reglas':
        SubAjustes.abrir(context, ReglasScreen(sesion: sesion, resaltar: e.id));
      case 'viajes':
        SubAjustes.abrir(context, FondosViajeScreen(repo: _tesRepo));
      case 'pivots':
        SubAjustes.abrir(context, PivotsScreen(sesion: sesion));
      default:
        _resaltado.value = null;
        _resaltado.value = e.id;
    }
  }

  // ─── Inicio de Mi Liga (Victor, 2026-11-14): Equipos, Tesorería, Pivots,
  // Reglas, Comunicación y Datos de la liga.
  List<Map<String, dynamic>>? _equipos;
  late final _tesRepo = TesoreriaRepo(sesion);

  @override
  void initState() {
    super.initState();
    _cargarInicio();
    // Tour de Mi Liga (Victor, 2026-11-15); solo si no está embebida en pestañas de Liga.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted || !widget.pestana || widget.embebida || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      Tour.mostrarSiCorresponde(
        context,
        preferencia: 'tour.miliga.v1',
        pasos: [
          PasoTour(clave: _kLupa, titulo: 'Busca un ajuste', texto: 'Escribe lo que quieres cambiar (por ejemplo "tarde" o "precio") y te lleva directo.'),
        ],
      );
    });
  }

  final _kLupa = GlobalKey(debugLabel: 'tour-liga-lupa');

  Future<void> _cargarInicio() async {
    EquipoRepo.de(sesion).cargar();
    try {
      final r = await sesion.api.get('getTiers', {'adminToken': sesion.adminToken});
      if (mounted) {
        setState(
          () => _equipos = [
            for (final t in (r['tiers'] as List? ?? const []))
              if (t is Map<String, dynamic>) t,
          ]..sort((a, b) => ((a['orden'] as num?) ?? 0).compareTo((b['orden'] as num?) ?? 0)),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _equipos = const []);
    }
  }

  Future<void> _abrir(Widget w) async {
    await SubAjustes.abrir(context, w);
    if (mounted) _cargarInicio();
  }

  Widget _titulo(BuildContext context, String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      t,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.pivot.textoSecundario),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = ConfigLiga.de(sesion);
    final pestana = widget.pestana;
    final arriba = widget.embebida ? 8 + altoBarra(context) : (pestana ? MediaQuery.paddingOf(context).top + kToolbarHeight : 0.0);
    return Scaffold(
      // En la pestaña, barra de vidrio como Equipo y Mi perfil.
      extendBodyBehindAppBar: pestana,
      appBar: widget.embebida
          ? null
          : AppBar(
              backgroundColor: pestana ? Colors.transparent : null,
              surfaceTintColor: pestana ? Colors.transparent : null,
              scrolledUnderElevation: pestana ? 0 : null,
              flexibleSpace: pestana ? const Vidrio(child: SizedBox.expand()) : null,
              title: Row(
                children: [
                  if (pestana && c.logo.isNotEmpty) ...[LogoEquipo(nombre: 'Liga', url: c.logo, tamano: 32), const SizedBox(width: 10)],
                  const Text('Ajustes', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              actions: [IconButton(key: _kLupa, tooltip: 'Buscar un ajuste', onPressed: _buscar, icon: const Icon(Icons.search_rounded))],
            ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Sincroniza(
          edgeOffset: arriba,
          onRefresh: _cargarInicio,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, arriba, 16, 40 + MediaQuery.paddingOf(context).bottom),
            // Todo construido: el buscador puede llevar a cualquier fila.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.embebida)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      key: _kLupa,
                      color: context.pivot.tarjeta,
                      borderRadius: BorderRadius.circular(PivotRadios.chip),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(PivotRadios.chip),
                        onTap: _buscar,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded, color: context.pivot.textoSecundario),
                              const SizedBox(width: 10),
                              Text('Buscar un ajuste, también de cada equipo', style: TextStyle(color: context.pivot.textoSecundario)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                // Liga recién creada: lo que conviene hacer primero.
                PrimerosPasos(
                  pasos: [
                    if (_pivot) ('invitar', Icons.qr_code_2_rounded, 'Invita a tu gente con el enlace de cada equipo', () => _abrir(CategoriasScreen(sesion: sesion))),
                    ('reglas', Icons.rule_rounded, 'Revisa las reglas de la liga: cuota, asistencia y estados', () => _abrir(ReglasScreen(sesion: sesion))),
                    ('pivots', Icons.group_add_rounded, 'Suma otro Pivot y reparte las áreas', () => _abrir(PivotsScreen(sesion: sesion))),
                  ],
                ),
                // Equipos, Pivots, Coaches, Personas archivadas y Avisos viven en
                // Liga → Equipos y Comunicación (Victor, QA 2026-11-26); el
                // buscador de arriba sigue llevando a cada uno.
                _titulo(context, 'FUNCIONES DE LA LIGA'),
                GrupoHerramientasLiga(sesion: sesion),
                _titulo(context, 'DATOS DE LA LIGA'),
                GrupoAjustes(
                  pie: 'El país define el prefijo de teléfono y los números de emergencia. La zona horaria se aplicará a los horarios cuando la app admita varias ligas; por ahora todo usa la hora de Ecuador.',
                  filas: [
                    Resaltable(
                      id: 'salud',
                      resaltado: _resaltado,
                      child: FilaAjuste(
                        icono: Icons.health_and_safety_outlined,
                        seccion: 'salud',
                        titulo: 'Salud y seguros',
                        valor: '${c.atencionMedica.length} opciones de atención · ${c.segurosPrivados.length} seguros privados',
                        alTocar: () => _abrir(SaludLigaScreen(config: c)),
                      ),
                    ),
                    Resaltable(
                      id: 'pais',
                      resaltado: _resaltado,
                      child: FilaAjuste(
                        icono: Icons.flag_outlined,
                        seccion: 'identidad',
                        titulo: 'País',
                        valor: Paises.porCodigo(c.pais).nombre,
                        alTocar: () async {
                          final p = await elegirPais(context, paisEquipo: c.pais, actual: Paises.porCodigo(c.pais), titulo: 'País de la liga');
                          if (p != null && p.codigo != c.pais && context.mounted) await guardarLiga(context, c, {'pais': p.codigo});
                        },
                      ),
                    ),
                    Resaltable(
                      id: 'zona',
                      resaltado: _resaltado,
                      child: FilaAjuste(
                        icono: Icons.schedule_rounded,
                        seccion: 'identidad',
                        titulo: 'Zona horaria',
                        valor: zonasHorarias[c.zonaHoraria] ?? zonas[c.zonaHoraria] ?? c.zonaHoraria,
                        alTocar: () => elegirZonaLiga(context, c),
                      ),
                    ),
                    Resaltable(
                      id: 'moneda',
                      resaltado: _resaltado,
                      child: FilaAjuste(
                        icono: Icons.payments_outlined,
                        seccion: 'identidad',
                        titulo: 'Moneda',
                        valor: textoMonedaLiga(c),
                        alTocar: () => elegirMonedaLiga(context, c),
                      ),
                    ),
                  ],
                ),
                // Directorio de ligas y panel de Pivot (Victor, 2026-11-17).
                _titulo(context, 'PIVOT'),
                FilasDirectorio(sesion: sesion),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
