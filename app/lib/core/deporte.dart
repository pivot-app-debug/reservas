/// Palabras según el deporte de la liga (Victor, 2026-11-17: Pivot sirve
/// para cualquier deporte; lo propio del roller derby solo se ve en ligas de
/// roller derby). Lo llena ConfigLiga al cargar (`getConfigLiga.deporte`).
class Deporte {
  static String id = 'roller_derby';
  static bool get esDerby => id == 'roller_derby';

  static String get apodo => esDerby ? 'Nombre derby' : 'Apodo';
  static String get numero => esDerby ? 'Número derby' : 'Número';

  /// Ejemplos de roles para textos de ayuda.
  static String get ejemplosRoles => esDerby ? 'Jammer, blocker, entrenadorx…' : 'Capitanx, entrenadorx, staff…';
  static String get ejemploRolBusqueda => esDerby ? 'jammer, blocker' : 'entrenadorx, staff';
}
