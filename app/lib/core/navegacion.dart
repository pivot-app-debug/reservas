import 'package:flutter/foundation.dart';

/// Pestañas de la barra inferior que otras pantallas pueden abrir
/// (ej. "Editar mi perfil" desde tu ficha en Equipo).
enum Pestana { calendario, entrenamiento, equipo, perfil }

class Navegacion {
  Navegacion._();

  /// La barra escucha y cambia de pestaña; vuelve a null al aplicarse.
  static final ir = ValueNotifier<Pestana?>(null);

  /// Abrir Actividad en una pestaña desde una notificación (Victor,
  /// 2026-11-22): 'novedades' | 'tareas' | 'cursos' | 'pagos'. Lo aplica el
  /// Calendario y vuelve a null.
  static final actividad = ValueNotifier<String?>(null);

  /// Fecha del evento abierto (Victor, 2026-11-22): el ícono del Calendario
  /// muestra ese día mientras se ve el detalle.
  static final diaEvento = ValueNotifier<DateTime?>(null);

  /// Punto de aviso en la barra de abajo (Victor, 2026-11-22): Calendario lo
  /// prende si hay algo nuevo en Actividad; Liga, si hay alguien de viaje o
  /// lesionadx que no viste o cosas para llevar.
  static final puntoCalendario = ValueNotifier<bool>(false);
  static final puntoLiga = ValueNotifier<bool>(false);

  /// Entrenamiento (Victor, 2026-11-26): punto si hay cursos nuevos, y la
  /// vista que pidió abrir una notificación ('entrenamiento' | 'progreso' |
  /// 'cursos'); la aplica Entrenamiento y vuelve a null.
  static final puntoEntrenamiento = ValueNotifier<bool>(false);
  static final entrenamiento = ValueNotifier<String?>(null);
}
