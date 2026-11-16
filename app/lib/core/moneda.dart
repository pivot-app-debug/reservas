/// Símbolo de la moneda de la liga (Mi Liga → Datos de la liga), para
/// todos los montos de la app. Se carga con la sesión y con Mi Liga.
class Moneda {
  static String s = r'$';

  /// Opciones comunes; la liga puede escribir otra.
  static const comunes = <String, String>{
    r'$': 'Dólar o peso (\$)',
    'S/': 'Sol (S/)',
    '€': 'Euro (€)',
    'Bs': 'Boliviano (Bs)',
    'Q': 'Quetzal (Q)',
    '₡': 'Colón (₡)',
    'R\$': 'Real (R\$)',
  };
}
