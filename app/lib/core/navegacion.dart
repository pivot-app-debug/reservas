import 'package:flutter/foundation.dart';

/// Pestañas de la barra inferior que otras pantallas pueden abrir
/// (ej. "Editar mi perfil" desde tu ficha en Equipo).
enum Pestana { calendario, equipo, perfil }

class Navegacion {
  Navegacion._();

  /// La barra escucha y cambia de pestaña; vuelve a null al aplicarse.
  static final ir = ValueNotifier<Pestana?>(null);

  /// Abrir Actividad en una pestaña desde una notificación (Victor,
  /// 2026-11-22): 'novedades' | 'tareas' | 'cursos' | 'pagos'. Lo aplica el
  /// Calendario y vuelve a null.
  static final actividad = ValueNotifier<String?>(null);
}
