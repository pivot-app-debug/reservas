import 'package:flutter/material.dart';

import '../coach/coach_screen.dart';
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
import '../core/esqueleto.dart';
import '../core/fondo_logo.dart';
import 'cobro_equipo_screen.dart' show modosCobro;

/// Mi perfil → Ajustes de la liga (solo Pivots, Victor 2026-11-13): un solo
/// lugar para lo que configura la liga. Los roles se editan desde la hoja de
/// "Roles en el equipo" (botón "Agregar o editar roles").
class AjustesLigaScreen extends StatefulWidget {
  const AjustesLigaScreen({super.key, required this.sesion, this.pestana = false});
  final Sesion sesion;

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

  @override
  void dispose() {
    _resaltado.dispose();
    super.dispose();
  }

  /// Buscador: lleva al ajuste (abriendo la subsección si hace falta) y lo
  /// hace parpadear.
  Future<void> _buscar() async {
    final e = await Navigator.of(context).push<EntradaAjuste>(MaterialPageRoute(builder: (_) => BuscadorLigaScreen(tesoreria: sesion.tieneArea('finanzas'))));
    if (e == null || !mounted) return;
    // Finanzas está en la barra de abajo (Victor, 2026-11-16).
    if (e.id == 'tesoreria') {
      SubAjustes.abrir(context, TesoreriaScreen(sesion: sesion));
      return;
    }
    switch (e.dentro) {
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
    // Tour de Mi Liga (Victor, 2026-11-15).
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted || !widget.pestana || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      Tour.mostrarSiCorresponde(
        context,
        preferencia: 'tour.miliga.v1',
        pasos: [
          PasoTour(
            clave: _kEquipos,
            titulo: 'Tus equipos',
            texto: 'Toca un equipo para ver y cambiar todo lo suyo: requisitos, cobro, clases de gracia y fondos. Con "+" creas otro.',
          ),

          PasoTour(clave: _kLupa, titulo: 'Busca un ajuste', texto: 'Escribe lo que quieres cambiar (por ejemplo "tarde" o "precio") y te lleva directo.'),
        ],
      );
    });
  }

  final _kEquipos = GlobalKey(debugLabel: 'tour-liga-equipos');

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

  Widget _tarjetasEquipos(BuildContext context) {
    final p = context.pivot;
    final l = _equipos;
    final gente = EquipoRepo.de(sesion);
    Widget tarjeta({required Widget child, required VoidCallback alTocar, double ancho = 168, bool borde = false, String? logo}) => Material(
      color: borde ? Colors.transparent : p.tarjeta,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PivotRadios.grande),
        side: borde ? BorderSide(color: p.bordeSuave, width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(PivotRadios.grande),
        onTap: alTocar,
        child: FondoLogo(
          url: logo,
          opacidad: 0.5,
          ancho: 0.85,
          child: Container(width: ancho, padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
    Widget etiqueta(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.chip)),
      child: Text(
        t,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.sobreSuave),
      ),
    );
    return SizedBox(
      height: 184,
      child: l == null
          ? Brillo(
              child: Row(
                children: [
                  for (var i = 0; i < 2; i++)
                    Container(
                      width: 168,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(color: p.esqueleto, borderRadius: BorderRadius.circular(PivotRadios.grande)),
                    ),
                ],
              ),
            )
          : ListenableBuilder(
              listenable: gente,
              builder: (context, _) => ListView.separated(
                scrollDirection: Axis.horizontal,
                // Las tarjetas llegan al borde de la pantalla al deslizar (Victor, 2026-11-16).
                clipBehavior: Clip.none,
                itemCount: l.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  if (i == l.length) {
                    // Como "Agregar" en Comunidad (Victor, 2026-11-15).
                    final (degradado, sobre) = PivotPaleta.seccion('salud', Theme.of(context).brightness);
                    return tarjeta(
                      ancho: 132,
                      alTocar: () => _abrir(NuevoEquipoScreen(sesion: sesion)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(gradient: degradado, borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.add_rounded, color: sobre),
                          ),
                          const Spacer(),
                          Text(
                            'Nuevo equipo',
                            style: TextStyle(fontWeight: FontWeight.w700, height: 1.2, color: p.texto),
                          ),
                          Text('Con sus propias reglas', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                        ],
                      ),
                    );
                  }
                  final t = l[i];
                  final nombre = '${t['nombre']}';
                  final cuantas = gente.personas?.where((x) => x.categoria == nombre).length;
                  final req = (t['requisitos'] as Map?) ?? const {};
                  final propio = req['patinesPropios'] == true || req['proteccionesPropias'] == true;
                  final logo = '${t['logo'] ?? ''}';
                  final cobro = modosCobro['${ConfigLiga.de(sesion).cobroEquipo(nombre)['modo']}']?.$1;
                  // Con logo, va de fondo y no hace falta el avatar (Victor, 2026-11-16).
                  return tarjeta(
                    logo: logo.isEmpty ? null : logo,
                    alTocar: () => _abrir(AjustesEquipoScreen(sesion: sesion, nombre: nombre)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (logo.isEmpty) LogoEquipo(nombre: nombre, url: null, tamano: 44),
                        const Spacer(),
                        Text(
                          nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.texto),
                        ),
                        Text(
                          cuantas == null ? ' ' : '$cuantas ${cuantas == 1 ? 'persona' : 'personas'}',
                          style: TextStyle(fontSize: 13, color: p.textoSecundario),
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 4, runSpacing: 4, children: [if (cobro != null) etiqueta(cobro), if (propio) etiqueta('Equipo propio')]),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ConfigLiga.de(sesion);
    final pestana = widget.pestana;
    final arriba = pestana ? MediaQuery.paddingOf(context).top + kToolbarHeight : 0.0;
    return Scaffold(
      // En la pestaña, barra de vidrio como Equipo y Mi perfil.
      extendBodyBehindAppBar: pestana,
      appBar: AppBar(
        backgroundColor: pestana ? Colors.transparent : null,
        surfaceTintColor: pestana ? Colors.transparent : null,
        scrolledUnderElevation: pestana ? 0 : null,
        flexibleSpace: pestana ? const Vidrio(child: SizedBox.expand()) : null,
        title: Row(
          children: [
            if (pestana && c.logo.isNotEmpty) ...[LogoEquipo(nombre: 'Liga', url: c.logo, tamano: 32), const SizedBox(width: 10)],
            Text(pestana ? 'Mi Liga' : 'Ajustes de la liga', style: const TextStyle(fontWeight: FontWeight.w700)),
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
                // Liga recién creada: lo que conviene hacer primero.
                PrimerosPasos(
                  pasos: [
                    ('invitar', Icons.qr_code_2_rounded, 'Invita a tu gente con el enlace de cada equipo', () => _abrir(CategoriasScreen(sesion: sesion))),
                    ('reglas', Icons.rule_rounded, 'Revisa las reglas de la liga: cuota, asistencia y estados', () => _abrir(ReglasScreen(sesion: sesion))),
                    ('pivots', Icons.group_add_rounded, 'Suma otro Pivot y reparte las áreas', () => _abrir(PivotsScreen(sesion: sesion))),
                  ],
                ),
                _titulo(context, 'EQUIPOS'),
                Resaltable(
                  id: 'equipos',
                  resaltado: _resaltado,
                  child: KeyedSubtree(key: _kEquipos, child: _tarjetasEquipos(context)),
                ),

                _titulo(context, 'ADMINISTRAR'),
                GrupoAjustes(
                  filas: [
                    Resaltable(
                      id: 'pivots',
                      resaltado: _resaltado,
                      child: FilaAjuste(
                        icono: Icons.admin_panel_settings_outlined,
                        seccion: 'roles',
                        titulo: 'Pivots y permisos',
                        valor: 'Quién es Pivot, qué áreas gestiona y cómo se aprueban sus pedidos',
                        alTocar: () => _abrir(PivotsScreen(sesion: sesion)),
                      ),
                    ),
                    // Coaches (Victor, 2026-11-16).
                    Resaltable(
                      id: 'coaches',
                      resaltado: _resaltado,
                      child: FilaAjuste(
                        icono: Icons.sports_rounded,
                        seccion: 'entrenamientos',
                        titulo: 'Coaches',
                        valor: 'Quién es coach y qué equipos lleva',
                        alTocar: () => _abrir(CoachesScreen(sesion: sesion)),
                      ),
                    ),

                    if (sesion.tieneArea('liga'))
                      Resaltable(
                        id: 'avisos',
                        resaltado: _resaltado,
                        child: FilaAjuste(
                          icono: Icons.campaign_outlined,
                          seccion: 'telefono',
                          titulo: 'Avisos al equipo',
                          valor: 'Enviar un mensaje ahora o programado',
                          alTocar: () => _abrir(AvisosScreen(sesion: sesion)),
                        ),
                      ),
                    if (sesion.tieneArea('equipo'))
                      Resaltable(
                        id: 'archivadas',
                        resaltado: _resaltado,
                        child: FilaAjuste(
                          icono: Icons.inventory_outlined,
                          seccion: 'roles',
                          titulo: 'Personas archivadas',
                          valor: 'Quitadas del equipo por inactividad o por un Pivot',
                          alTocar: () => _abrir(ArchivadasScreen(repo: EquipoRepo.de(sesion))),
                        ),
                      ),
                  ],
                ),
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
