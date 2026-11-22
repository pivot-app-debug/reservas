import 'pivots/bandeja_repo.dart' show BandejaRepo;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'liga/directorio_screen.dart';
import 'pivots/ajustes_liga_screen.dart';
import 'ajustes/componentes.dart';
import 'core/config_liga.dart';
import 'core/fechas.dart';
import 'core/tema.dart';
import 'core/vidrio.dart';
import 'core/datos_pendientes.dart';
import 'core/tour.dart';
import 'ajustes/ajustes_screen.dart';
import 'core/aviso_sin_conexion.dart';
import 'equipo/equipo_repo.dart';
import 'equipo/avisos_liga.dart';
import 'equipo/equipo_screen.dart';
import 'eventos/eventos_repo.dart';
import 'eventos/widgets_comunes.dart' show AvatarPersona;
import 'eventos/timeline_screen.dart';
import 'sesion/sesion.dart';
import 'core/navegacion.dart';
import 'core/aviso_cambio_equipo.dart';
import 'push/avisos_obligatorios.dart';

/// Estructura principal con la barra de navegación inferior. En esta
/// primera versión solo Eventos es nativo; el resto abre la web mientras se
/// migra (decisión 2026-11-06, ver MANIFEST.md "App Android").
class InicioShell extends StatefulWidget {
  const InicioShell({super.key, required this.sesion, required this.repo});
  final Sesion sesion;
  final EventosRepo repo;

  @override
  State<InicioShell> createState() => _InicioShellState();
}

class _InicioShellState extends State<InicioShell> with WidgetsBindingObserver {
  int _indice = 0;
  final _irAHoy = SenalHoy();

  // Cada pestaña con su propio Navigator (Victor, 2026-11-17): al entrar a una
  // subsección (Cursos, Tareas, una ficha…) la barra de abajo sigue visible.
  // Se identifican por su nombre (no por posición). Cada pestaña visitada
  // queda viva y recuerda dónde estabas (Victor, 2026-11-17). Desde
  // 2026-11-19 son siempre tres: Calendario, Equipo y Ajustes.
  final _navs = <String, GlobalKey<NavigatorState>>{};
  final _heroes = <String, HeroController>{};
  final _visitadas = <String>{};
  String _actual = '';
  GlobalKey<NavigatorState> _nav(String i) => _navs[i] ??= GlobalKey<NavigatorState>(debugLabel: 'pestana-$i');

  Widget _pestana(String i, Widget pagina) => NavigatorPopHandler(
    // Solo la pestaña visible responde al botón o gesto de atrás.
    enabled: i == _actual,

    onPopWithResult: (_) => _nav(i).currentState?.maybePop(),
    child: Navigator(
      key: _nav(i),
      observers: [_heroes[i] ??= HeroController()],
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => pagina),
    ),
  );

  /// Vuelve al inicio de la pestaña actual (si había entrado a una subsección).
  bool _alInicioDePestana() {
    final n = _nav(_actual).currentState;
    if (n == null || !n.canPop()) return false;
    n.popUntil((r) => r.isFirst);
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Navegacion.ir.addListener(_irAPestana);
    // Coach (ahora en Ajustes → Herramientas de la liga, Victor 2026-11-19).
    widget.sesion.cargarCoach();
    // Ajustes y reglas de la liga (inactividad, tolerancia…) desde el inicio.
    ConfigLiga.de(widget.sesion);

    // Datos del perfil pendientes: al entrar, sin tapar el tour de primera vez.
    Future.delayed(const Duration(milliseconds: 2500), _recordarDatos);
    // Avisos de Liga (viajes, lesiones, cosas para llevar) aunque no hayas
    // entrado a Liga: la lista del equipo se pide una vez, un rato después.
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      AvisosLiga.de(widget.sesion);
      EquipoRepo.de(widget.sesion).cargar();
    });
  }

  Future<void> _recordarDatos() async {
    // Ya no depende de haber visto el recorrido del Calendario (Victor,
    // 2026-11-17): si hay un recorrido en pantalla, espera a que termine.
    for (var i = 0; i < 60 && mounted && Tour.activo; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (!mounted || Tour.activo) return;
    // Notificaciones casi obligatorias (Victor, 2026-11-18): primero que todo.
    // Solo a personas activas: quien no está Activx no recibe avisos de
    // eventos (Victor, 2026-11-20), así que no se le pide activarlos.
    final estado = '${widget.sesion.datos['estado_miembro'] ?? ''}'.trim();
    if (estado.isEmpty || estado == 'Activx') await PantallaAvisos.siCorresponde(context, widget.sesion.api);
    if (!mounted) return;
    // Cambio de equipo por ver (Victor, 2026-11-16).
    await mostrarAvisoCambioEquipo(context, widget.sesion);
    if (!mounted) return;
    // Liga creada por el camino rápido (Victor, 2026-11-17).
    await SugerenciaReglas.siCorresponde(
      context,
      widget.sesion,
      abrir: () => SubAjustes.abrir(context, AjustesLigaScreen(sesion: widget.sesion, pestana: true)),
    );
    if (!mounted) return;
    await DatosPendientes.recordarSiCorresponde(context, widget.sesion, abrir: (clave) => abrirPendiente(context, widget.sesion, clave));
  }

  /// Otra pantalla pidió abrir una pestaña (ej. Mi perfil desde tu ficha).
  void _irAPestana() {
    final p = Navegacion.ir.value;
    if (p == null || !mounted) return;
    Navegacion.ir.value = null;
    Navigator.of(context).popUntil((r) => r.isFirst);
    // La pestaña que se deja queda donde estaba (Victor, 2026-11-17): solo
    // vuelve a su inicio al tocar de nuevo su ícono o al ir atrás.

    setState(
      () => _indice = switch (p) {
        Pestana.calendario => 0,
        Pestana.equipo => 1,
        Pestana.perfil => 2,
      },
    );
  }

  @override
  void dispose() {
    Navegacion.ir.removeListener(_irAPestana);
    WidgetsBinding.instance.removeObserver(this);
    _irAHoy.dispose();
    super.dispose();
  }

  // El número del ícono de Eventos se actualiza al volver a la app (por si cambió el día).
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      setState(() {});
      // Al volver a la app: subir lo guardado sin señal.
      widget.repo.cola.sincronizar();
      // Por si activó o apagó las notificaciones en los ajustes del teléfono.
      EstadoAvisos.revisar(widget.sesion.api);
    }
  }

  @override
  Widget build(BuildContext context) {
    final indiceActual = _indice;
    final destinos = <(NavigationDestination, Widget)>[
      (
        // Ícono con la fecha de hoy (como Google Calendar); tocarlo estando
        // en Eventos lleva a hoy.
        NavigationDestination(
          // Lejos de hoy en el timeline: flecha hacia hoy con un puntito
          // rojo; al volver, regresa el número del día (opción A, 2026-11-16).
          // Punto rojo si hay novedades en Notificaciones (Victor, 2026-11-17).
          icon: ListenableBuilder(
            listenable: Listenable.merge([BandejaRepo.de(widget.sesion), Navegacion.puntoCalendario]),
            // El punto va centrado sobre la esquina redondeada del recuadro del
            // día (el Badge de Material lo dejaba metido y descuadrado; QA 2026-11-18).
            builder: (context, hijo) => Stack(
              clipBehavior: Clip.none,
              children: [
                hijo!,
                Positioned(
                  right: -2.5,
                  top: -2.5,
                  child: AnimatedScale(
                    // También si hay algo nuevo en Tareas o Cursos (Victor, 2026-11-22).
                    scale: BandejaRepo.de(widget.sesion).hayNovedades || Navegacion.puntoCalendario.value ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: context.pivot.marca, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ],
            ),
            // Hoy: recuadro rojo con el número claro. Otra fecha del timeline o un
            // evento abierto: el número de ese día (Victor, 2026-11-22).
            child: ListenableBuilder(
              listenable: Listenable.merge([_irAHoy.lejos, _irAHoy.dia, Navegacion.diaEvento]),
              builder: (context, _) {
                final hoy = Fechas.hoy();
                final evento = Navegacion.diaEvento.value;
                final DateTime dia = evento ?? (_irAHoy.lejos.value == 0 || indiceActual != 0 ? hoy : (_irAHoy.dia.value ?? hoy));
                // Relleno rojo solo estando en Calendario (Victor, 2026-11-22).
                final esHoy = evento == null && Fechas.soloDia(dia) == hoy && indiceActual == 0;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (hijo, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(anim), child: hijo),
                  ),
                  child: _IconoHoy(key: ValueKey('${dia.day}-$esHoy'), dia: dia.day, relleno: esHoy),
                );
              },
            ),
          ),
          label: 'Calendario',
          tooltip: 'Calendario · tócalo de nuevo para ir a hoy',
        ),
        TimelineScreen(repo: widget.repo, irAHoy: _irAHoy),
      ),
      (
        // Equipo pasó a Liga (Victor, 2026-11-22): Comunidad, Redes, Inventario y Finanzas.
        NavigationDestination(
          icon: ValueListenableBuilder<bool>(
            valueListenable: Navegacion.puntoLiga,
            builder: (context, v, _) => Badge(isLabelVisible: v, smallSize: 9, backgroundColor: context.pivot.marca, child: const Icon(Icons.group_outlined)),
          ),
          selectedIcon: ValueListenableBuilder<bool>(
            valueListenable: Navegacion.puntoLiga,
            builder: (context, v, _) => Badge(isLabelVisible: v, smallSize: 9, backgroundColor: context.pivot.marca, child: const Icon(Icons.group)),
          ),
          label: 'Liga',
        ),
        EquipoScreen(repo: EquipoRepo.de(widget.sesion)),
      ),
      // Finanzas y Coach salieron de la barra (Victor, 2026-11-19): viven en
      // Ajustes → Herramientas de la liga, junto con Mi Liga.
      // Ajustes (antes Mi perfil): ícono de engranaje (Victor, 2026-11-16).
      (
        // Mi perfil con tu avatar (Victor, 2026-11-22).
        NavigationDestination(
          icon: ListenableBuilder(
            listenable: widget.sesion,
            builder: (context, _) => AvatarPersona(nombre: widget.sesion.nombreMostrar, foto: widget.sesion.fotoPerfil, tamano: 26),
          ),
          selectedIcon: ListenableBuilder(
            listenable: widget.sesion,
            builder: (context, _) => Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.pivot.marca, width: 2),
              ),
              child: AvatarPersona(nombre: widget.sesion.nombreMostrar, foto: widget.sesion.fotoPerfil, tamano: 24),
            ),
          ),
          label: 'Mi perfil',
        ),
        AjustesScreen(sesion: widget.sesion, eventos: widget.repo),
      ),
    ];
    final indice = _indice.clamp(0, destinos.length - 1);
    _actual = destinos[indice].$1.label;
    _visitadas
      ..add(_actual)
      ..retainWhere((l) => destinos.any((d) => d.$1.label == l));

    ClavesTour.destinos = destinos.length;
    // Barra de estado con íconos que contrastan en las pestañas sin AppBar.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: estiloBarraSistema(Theme.of(context).brightness),
      child: Scaffold(
        // Barra de abajo de vidrio: el contenido pasa por detrás desenfocado.
        extendBody: true,
        // Con extendBody, el "+" de cada pestaña quedaba detrás de la barra
        // (bug, Victor 2026-11-13: "desapareció el FAB de Calendario"): el
        // Scaffold de adentro ubica el botón con viewPadding, que no incluía la barra.
        body: Builder(
          builder: (context) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(viewPadding: mq.viewPadding.copyWith(bottom: mq.padding.bottom)),
              // Todas las pestañas visitadas siguen montadas, una encima de
              // otra; la activa aparece con un fundido.
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final d in destinos)
                    if (_visitadas.contains(d.$1.label))
                      KeyedSubtree(
                        key: ValueKey(d.$1.label),
                        child: _CapaPestana(activa: d.$1.label == _actual, child: _pestana(d.$1.label, d.$2)),
                      ),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvisoSinConexion(repo: widget.repo),
            Vidrio(
              abajo: true,
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                key: ClavesTour.navegacion,
                selectedIndex: indice,
                onDestinationSelected: (i) {
                  // Tocar la pestaña en la que estás vuelve a su inicio.
                  if (i == indice && _alInicioDePestana()) return;
                  if (i == 0 && indice == 0) {
                    _irAHoy.disparar();
                  } else {
                    // El Calendario queda donde estaba (con su flecha hacia hoy si corresponde).

                    setState(() => _indice = i);
                  }
                },
                destinations: [for (final d in destinos) d.$1],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ícono de Eventos: cuadrado redondeado con el número del día adentro
/// (como el de Google Calendar). Siempre en contorno: la selección ya la marca el fondo
/// de la pestaña (un ícono lleno se veía como un cuadrado sin forma).
class _IconoHoy extends StatelessWidget {
  const _IconoHoy({super.key, required this.dia, this.relleno = false});
  final int dia;

  /// Hoy: recuadro rojo lleno y número claro.
  final bool relleno;

  @override
  Widget build(BuildContext context) {
    final tema = IconTheme.of(context);
    final p = context.pivot;
    final color = relleno ? p.sobreMarca : (tema.color ?? p.texto);
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cuadrado redondeado simple (sin las anillas del ícono de Material,
          // que apretaban el número) y el día en Nunito Black.
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: relleno ? p.marca : null,
              border: Border.all(color: relleno ? p.marca : color, width: 2),
              borderRadius: BorderRadius.circular(PivotRadios.iconoDia),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              '$dia',
              textAlign: TextAlign.center,
              style: PivotTexto.numeroIcono(color, tam: dia > 9 ? 11.5 : 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una pestaña de la barra: la activa se ve y recibe toques; las otras quedan
/// montadas (con su pila de pantallas) pero ocultas y en pausa.
class _CapaPestana extends StatelessWidget {
  const _CapaPestana({required this.activa, required this.child});
  final bool activa;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: activa ? 1 : 0,
    duration: const Duration(milliseconds: 200),
    child: IgnorePointer(
      ignoring: !activa,
      child: ExcludeSemantics(
        excluding: !activa,
        child: ExcludeFocus(
          excluding: !activa,
          child: TickerMode(enabled: activa, child: child),
        ),
      ),
    ),
  );
}
