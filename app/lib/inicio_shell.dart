import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coach/coach_screen.dart';
import 'core/config_liga.dart';
import 'core/fechas.dart';
import 'core/tema.dart';
import 'core/vidrio.dart';
import 'core/datos_pendientes.dart';
import 'core/tour.dart';
import 'ajustes/ajustes_screen.dart';
import 'core/aviso_sin_conexion.dart';
import 'equipo/equipo_repo.dart';
import 'equipo/equipo_screen.dart';
import 'eventos/eventos_repo.dart';
import 'eventos/timeline_screen.dart';
import 'sesion/sesion.dart';
import 'core/navegacion.dart';
import 'finanzas/tesoreria_screen.dart';
import 'core/aviso_cambio_equipo.dart';

import 'eventos/widgets_comunes.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Navegacion.ir.addListener(_irAPestana);
    // Coach: la pestaña aparece al aprobarse (Victor, 2026-11-16).
    widget.sesion.addListener(_alCambiarSesion);
    widget.sesion.cargarCoach();
    // Ajustes y reglas de la liga (inactividad, tolerancia…) desde el inicio.
    ConfigLiga.de(widget.sesion);

    // Datos del perfil pendientes: al entrar, sin tapar el tour de primera vez.
    Future.delayed(const Duration(milliseconds: 2500), _recordarDatos);
  }

  Future<void> _recordarDatos() async {
    if (!mounted || Tour.activo) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('tour.calendario.v2') != true || !mounted) return;
    // Cambio de equipo por ver (Victor, 2026-11-16).
    await mostrarAvisoCambioEquipo(context, widget.sesion);
    if (!mounted) return;
    await DatosPendientes.recordarSiCorresponde(context, widget.sesion, abrir: (clave) => abrirPendiente(context, widget.sesion, clave));
  }

  bool _eraCoach = false;
  void _alCambiarSesion() {
    if (mounted && widget.sesion.esCoach != _eraCoach) setState(() => _eraCoach = widget.sesion.esCoach);
  }

  /// Otra pantalla pidió abrir una pestaña (ej. Mi perfil desde tu ficha).
  void _irAPestana() {
    final p = Navegacion.ir.value;
    if (p == null || !mounted) return;
    Navegacion.ir.value = null;
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(
      () => _indice = switch (p) {
        Pestana.calendario => 0,
        Pestana.equipo => 1,
        Pestana.perfil => 1 + (widget.sesion.tieneArea('finanzas') ? 1 : 0) + (widget.sesion.esCoach ? 1 : 0) + 1,
      },
    );
  }

  @override
  void dispose() {
    widget.sesion.removeListener(_alCambiarSesion);
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
          icon: ValueListenableBuilder<int>(
            valueListenable: _irAHoy.lejos,
            builder: (context, lejos, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (hijo, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(anim), child: hijo),
              ),
              child: lejos == 0 || indiceActual != 0
                  ? _IconoHoy(key: const ValueKey('dia'), dia: Fechas.hoy().day)
                  : _IconoFlechaHoy(key: ValueKey(lejos), arriba: lejos < 0),
            ),
          ),
          label: 'Calendario',
          tooltip: 'Calendario · tócalo de nuevo para ir a hoy',
        ),
        TimelineScreen(repo: widget.repo, irAHoy: _irAHoy),
      ),
      (
        const NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Equipo'),
        EquipoScreen(repo: EquipoRepo.de(widget.sesion)),
      ),
      // Finanzas (antes Tesorería en Mi Liga; Victor, 2026-11-16): en la
      // barra para quien gestiona finanzas.
      if (widget.sesion.tieneArea('finanzas'))
        (
          const NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Finanzas'),
          TesoreriaScreen(sesion: widget.sesion),
        ),
      // Mi Liga ya no es una pestaña: vive dentro de Ajustes (Victor, 2026-11-16).
      // En su lugar, Coach para quien un Pivot aprobó como coach.
      if (widget.sesion.esCoach)
        (
          const NavigationDestination(icon: Icon(Icons.sports_outlined), selectedIcon: Icon(Icons.sports), label: 'Coach'),
          CoachScreen(sesion: widget.sesion, eventos: widget.repo),
        ),
      // Ajustes (antes Mi perfil; Victor, 2026-11-16), con tu avatar.
      (
        NavigationDestination(
          icon: ListenableBuilder(
            listenable: widget.sesion,
            builder: (context, _) => AvatarPersona(nombre: widget.sesion.nombreMostrar, foto: widget.sesion.fotoPerfil, tamano: 26),
          ),
          label: 'Ajustes',
        ),
        AjustesScreen(sesion: widget.sesion, eventos: widget.repo),
      ),
    ];
    final indice = _indice.clamp(0, destinos.length - 1);
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(key: ValueKey(indice), child: destinos[indice].$2),
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
                  if (i == 0 && indice == 0) {
                    _irAHoy.disparar();
                  } else {
                    // Al volver al Calendario el timeline abre en hoy.
                    if (i != 0) _irAHoy.lejos.value = 0;
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

/// Flecha hacia hoy (arriba o abajo): aparece en lugar
/// del número del día cuando el timeline se aleja de hoy.
class _IconoFlechaHoy extends StatelessWidget {
  const _IconoFlechaHoy({super.key, required this.arriba});
  final bool arriba;

  @override
  Widget build(BuildContext context) {
    // Sin el puntito rojo (Victor, 2026-11-16): solo la flecha.
    return Icon(arriba ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);
  }
}

/// Ícono de Eventos: cuadrado redondeado con el número del día adentro
/// (como el de Google Calendar). Siempre en contorno: la selección ya la marca el fondo
/// de la pestaña (un ícono lleno se veía como un cuadrado sin forma).
class _IconoHoy extends StatelessWidget {
  const _IconoHoy({super.key, required this.dia});
  final int dia;

  @override
  Widget build(BuildContext context) {
    final tema = IconTheme.of(context);
    final color = tema.color ?? context.pivot.texto;
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
              border: Border.all(color: color, width: 2),
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
