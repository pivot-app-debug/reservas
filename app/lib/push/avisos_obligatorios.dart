import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/tema.dart';
import 'aviso_web.dart';
import '../core/instalar_web.dart' show esAppInstalada;
import 'push.dart';

/// Notificaciones "casi obligatorias" (Victor, 2026-11-18): ninguna app puede
/// activarlas por la persona, así que al abrir Pivot con los avisos apagados se
/// muestra una pantalla completa para activarlos (con "Ahora no"), queda un
/// aviso fijo en Calendario y los Pivots ven en Equipo quién los tiene apagados.
///
/// Estados: 'activos', 'pendiente' (se puede pedir el permiso), 'bloqueados'
/// (hay que ir a los ajustes), 'instalar' (iPhone sin agregar a inicio) y
/// 'sin_soporte' (navegador sin avisos).
class EstadoAvisos {
  EstadoAvisos._();

  /// Optimista hasta revisar: así no aparece nada si no se pudo saber.
  static final actual = ValueNotifier<String>('activos');
  static String? _informado;

  /// "Ahora no" en la pantalla completa: no vuelve a salir hasta abrir de nuevo la app.
  static bool posponer = false;

  static const _canal = MethodChannel('pivot/seguridad');

  static Future<String> revisar(Api api) async {
    final e = await _calcular();
    actual.value = e;
    if (e != _informado) {
      _informado = e;
      try {
        await api.post('estadoAvisos', {'estado': e});
      } catch (_) {
        _informado = null;
      }
    }
    return e;
  }

  static Future<String> _calcular() async {
    if (kIsWeb) {
      // iPhone en Safari (sin abrir desde la pantalla de inicio): ahí iOS no
      // permite avisos y los marca como bloqueados. Se pide abrir la app
      // instalada en vez de mandar a ajustes (caso Veneno, 2026-11-28).
      if (esIosWeb() && !esAppInstalada()) return 'instalar';
      final w = permisoAvisosWeb();
      return switch (w) {
        'granted' => 'activos',
        'default' => 'pendiente',
        'denied' => 'bloqueados',
        _ => esIosWeb() ? 'instalar' : 'sin_soporte',
      };
    }
    await Push.listo;
    // Sin Firebase no hay avisos posibles: no se molesta a la persona.
    if (!Push.disponible) return 'activos';
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return switch (s.authorizationStatus) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => 'activos',
        AuthorizationStatus.notDetermined => 'pendiente',
        AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => 'bloqueados',
      };
    } catch (_) {
      return 'activos';
    }
  }

  /// Toque en "Activar": pide el permiso y, si ya está bloqueado, abre los ajustes.
  static Future<String> activar(Api api) async {
    if (kIsWeb) {
      if (actual.value == 'pendiente') {
        final r = await pedirPermisoAvisosWeb();
        if (r == 'granted') await Push.registrar(api);
      }
      return revisar(api);
    }
    // Si ya estaban bloqueados, el permiso no se puede volver a pedir: a los ajustes.
    final antes = actual.value;
    await Push.registrar(api);
    final e = await revisar(api);
    if (e != 'activos' && antes == 'bloqueados') {
      try {
        await _canal.invokeMethod<void>('abrirAjustesAvisos');
      } catch (_) {}
    }
    return e;
  }

  /// Qué decirle a la persona según el estado (sin el caso 'activos').
  static String texto(String e) => switch (e) {
    'bloqueados' when kIsWeb =>
      'Están bloqueadas en este navegador. Toca el candado o el ícono junto a la dirección, entra a Permisos y permite las notificaciones.',
    'bloqueados' => 'Están apagadas en tu teléfono. Toca "Activar" y enciende las notificaciones de Pivot en los ajustes.',
    'instalar' => 'En iPhone solo llegan si agregas Pivot a tu pantalla de inicio: toca Compartir → Agregar a inicio y abre Pivot desde ahí.',
    'sin_soporte' => 'Este navegador no permite notificaciones. Usa Chrome, Edge o Firefox, o la app de Android.',
    _ => 'Así te enteras de entrenamientos, cambios de horario, pagos y novedades de tu liga a tiempo.',
  };

  static bool puedeTocar(String e) => e == 'pendiente' || (e == 'bloqueados' && !kIsWeb);

  /// Pasos para activarlas según el navegador o el teléfono (QA 2026-11-27).
  static List<String> pasos(String e) {
    if (e == 'activos' || e == 'pendiente') return const [];
    if (e == 'instalar') {
      return const [
        '¿Ya tienes Pivot en tu pantalla de inicio? Ábrelo desde ese ícono, no desde Safari.',
        'Si no lo tienes: abre Pivot en Safari.',
        'Toca Compartir (el cuadrado con la flecha hacia arriba).',
        'Elige «Agregar a inicio» y luego «Agregar».',
        'Abre Pivot desde el ícono de tu pantalla de inicio y toca «Activar».',
      ];
    }
    if (e == 'sin_soporte') {
      return const ['Abre Pivot en Chrome, Edge o Firefox, o instala la app de Android.', 'Inicia sesión y toca «Activar».'];
    }
    // Bloqueadas.
    return switch (kIsWeb ? navegadorWeb() : 'app') {
      'app' => const ['Toca «Abrir ajustes».', 'Entra a Notificaciones.', 'Activa «Permitir notificaciones» para Pivot y vuelve a la app.'],
      'android' => const [
        'Toca los tres puntos de Chrome › Configuración › Configuración de sitios › Notificaciones.',
        'Busca Pivot en la lista y elige «Permitir».',
        'Vuelve a Pivot y toca «Ya las activé».',
      ],
      'ios' => const ['Abre Ajustes del iPhone › Notificaciones › Pivot.', 'Activa «Permitir notificaciones».', 'Vuelve a Pivot y toca «Ya las activé».'],
      'safari' => const [
        'En la barra de menú: Safari › Configuración › Sitios web › Notificaciones.',
        'Junto a Pivot elige «Permitir».',
        'Vuelve y toca «Ya las activé».',
      ],
      'firefox' => const [
        'Toca el ícono a la izquierda de la dirección.',
        'En «Enviar notificaciones», quita el bloqueo.',
        'Recarga la página y toca «Activar».',
      ],
      _ => const [
        'Toca el ícono a la izquierda de la dirección (candado o ajustes).',
        'En «Notificaciones», elige «Permitir».',
        'Recarga la página y toca «Ya las activé».',
      ],
    };
  }
}

/// Pantalla completa al abrir la app con los avisos apagados.
class PantallaAvisos extends StatefulWidget {
  const PantallaAvisos({super.key, required this.api});
  final Api api;

  /// La muestra si hace falta. No sale si se pospuso en esta apertura.
  /// Obligatoria (QA 2026-11-27): sin «Ahora no» y sin poder volver atrás.
  static bool _abierta = false;

  static Future<void> siCorresponde(BuildContext context, Api api) async {
    if (_abierta) return;
    final e = await EstadoAvisos.revisar(api);
    if (e == 'activos' || !context.mounted || _abierta) return;
    _abierta = true;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => PantallaAvisos(api: api),
        transitionsBuilder: (_, a, _, hijo) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: hijo,
          ),
        ),
      ),
    );
    _abierta = false;
  }

  @override
  State<PantallaAvisos> createState() => _PantallaAvisosState();
}

class _PantallaAvisosState extends State<PantallaAvisos> with WidgetsBindingObserver {
  bool _pidiendo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EstadoAvisos.actual.addListener(_alCambiar);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    EstadoAvisos.actual.removeListener(_alCambiar);
    super.dispose();
  }

  // Al volver de los ajustes del teléfono se revisa de nuevo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) EstadoAvisos.revisar(widget.api);
  }

  void _alCambiar() {
    if (!mounted) return;
    if (EstadoAvisos.actual.value == 'activos') {
      Navigator.of(context).pop();
    } else {
      setState(() {});
    }
  }

  Future<void> _activar() async {
    setState(() => _pidiendo = true);
    await EstadoAvisos.activar(widget.api);
    if (mounted) setState(() => _pidiendo = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final e = EstadoAvisos.actual.value;
    final pasos = EstadoAvisos.pasos(e);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: p.fondo,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(color: p.suave, shape: BoxShape.circle),
                    child: Icon(Icons.notifications_active_outlined, size: 48, color: p.marcaTexto),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Activa las notificaciones',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: p.texto),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu liga usa Pivot para avisar entrenamientos, cambios y pagos. Sin notificaciones te los puedes perder.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15.5, height: 1.4, color: p.texto),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    EstadoAvisos.texto(e),
                    key: ValueKey(e),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.4, color: p.textoSecundario),
                  ),
                ),
                // Guía paso a paso según el navegador o el teléfono.
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: pasos.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final (i, t) in pasos.indexed)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(color: p.suave, shape: BoxShape.circle),
                                          child: Text(
                                            '${i + 1}',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.sobreSuave),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(t, style: TextStyle(fontSize: 14, height: 1.35, color: p.texto)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
                const Spacer(flex: 2),
                if (EstadoAvisos.puedeTocar(e))
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _pidiendo ? null : _activar,
                    child: Text(e == 'bloqueados' ? 'Abrir ajustes' : 'Activar'),
                  )
                else
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () => EstadoAvisos.revisar(widget.api),
                    child: const Text('Ya las activé'),
                  ),
                if (EstadoAvisos.puedeTocar(e)) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => EstadoAvisos.revisar(widget.api), child: const Text('Ya las activé')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso fijo (Calendario) mientras los avisos estén apagados.
class BannerAvisos extends StatelessWidget {
  const BannerAvisos({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return ValueListenableBuilder<String>(
      valueListenable: EstadoAvisos.actual,
      builder: (context, e, _) => AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: e == 'activos'
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Material(
                  color: p.suave,
                  borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                    onTap: () {
                      EstadoAvisos.posponer = false;
                      PantallaAvisos.siCorresponde(context, api);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 20, color: p.marcaTexto),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tus notificaciones están apagadas',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.sobreSuave),
                            ),
                          ),
                          Text(
                            'Activar',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.marcaTexto),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
