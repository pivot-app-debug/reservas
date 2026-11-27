/// Niveles de habilidades de la liga (Victor, 2026-11-27): una lista en orden
/// que arma cada liga (antes eran fijos: básicas y avanzadas). El servidor los
/// manda con getCoach, getHabilidades y getFichaDeportiva; aquí queda la
/// última lista vista para nombrarlos en toda la app.
class NivelCoach {
  const NivelCoach(this.clave, this.nombre, {this.regla = 'porcentaje', this.porcentaje = 80});
  final String clave, nombre;

  /// 'porcentaje' | 'todas' | 'una'.
  final String regla;
  final int porcentaje;

  factory NivelCoach.de(Map m) =>
      NivelCoach('${m['clave']}', '${m['nombre']}', regla: '${m['regla'] ?? 'porcentaje'}', porcentaje: (m['porcentaje'] as num?)?.toInt() ?? 80);

  /// Cómo se completa, dicho en palabras.
  String get textoRegla => switch (regla) {
    'todas' => 'Se completa al lograr todas sus habilidades.',
    'una' => 'Se completa al lograr una de sus habilidades.',
    _ => 'Se completa al lograr el $porcentaje % de sus habilidades.',
  };
}

class NivelesCoach {
  static List<NivelCoach> lista = const [NivelCoach('basica', 'Habilidades básicas'), NivelCoach('avanzada', 'Habilidades avanzadas', regla: 'una')];

  static void actualizar(Object? l) {
    if (l is! List || l.isEmpty) return;
    lista = [
      for (final x in l)
        if (x is Map) NivelCoach.de(x),
    ];
  }

  static String get primero => lista.isEmpty ? 'basica' : lista.first.clave;

  static String nombre(String clave) => lista.where((n) => n.clave == clave).firstOrNull?.nombre ?? clave;
}

/// Nivel de una persona → nombre: 'sin' y las claves de los niveles (las
/// claves viejas 'basicas' y 'avanzadas' también).
Map<String, String> get nivelesCoach => {
  'sin': 'Aprendiendo lo básico',
  for (final n in NivelesCoach.lista) n.clave: n.nombre,
  if (NivelesCoach.lista.any((n) => n.clave == 'basica')) 'basicas': NivelesCoach.nombre('basica'),
  if (NivelesCoach.lista.any((n) => n.clave == 'avanzada')) 'avanzadas': NivelesCoach.nombre('avanzada'),
};

/// Para elegir: sin las claves viejas repetidas.
Map<String, String> get nivelesCoachElegibles => {'sin': 'Aprendiendo lo básico', for (final n in NivelesCoach.lista) n.clave: n.nombre};
