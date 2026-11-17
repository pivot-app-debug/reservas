/// Palabras según los pronombres de la persona (Victor, 2026-11-16): solo
/// Ella → "Lesionada"; solo Él → "Lesionado"; solo Elle → "Lesionade";
/// varios o ninguno → "Lesionadx". Solo para textos sobre o para una
/// persona; los de grupo siguen con x ("Inactivxs").
enum Genero { a, o, e, x }

Genero generoDe(Object? pronombres) {
  final s = '${pronombres ?? ''}'.toLowerCase();
  final ella = RegExp(r'\bella\b').hasMatch(s);
  final el = RegExp(r'(^|[^a-záéíóúñ])(él|el)([^a-záéíóúñ]|$)').hasMatch(s);
  final elle = RegExp(r'\belle\b').hasMatch(s);
  final n = [ella, el, elle].where((x) => x).length;
  if (n != 1) return Genero.x;
  return ella ? Genero.a : (el ? Genero.o : Genero.e);
}

/// Palabras de una persona que se adaptan (en minúscula, con la x final).
const _irregulares = <String, List<String>>{
  // a, o, e
  'unx': ['una', 'un', 'une'],
  'administradorx': ['administradora', 'administrador', 'administradore'],
};
const _regulares = {
  'lesionadx', 'inactivx', 'activx', 'nuevx', 'marcadx', 'inscritx', 'archivadx', 'bienvenidx', 'hermanx', 'listx', 'invitadx', 'aprobadx', //
  'pausadx', 'anotadx', 'elegidx', 'seleccionadx', 'confirmadx', 'retiradx', 'cansadx', 'ausentadx',
};

final _palabra = RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]+x\b');

/// [texto] con las palabras de una persona según sus [pronombres].
String conPronombres(String texto, Object? pronombres) {
  final g = generoDe(pronombres);
  if (g == Genero.x) return texto;
  return texto.replaceAllMapped(_palabra, (m) {
    final w = m[0]!;
    final bajo = w.toLowerCase();
    final i = g.index; // a=0, o=1, e=2
    String? nueva;
    if (_irregulares[bajo] case final l?) {
      nueva = l[i];
    } else if (_regulares.contains(bajo)) {
      nueva = bajo.substring(0, bajo.length - 1) + const ['a', 'o', 'e'][i];
    }
    if (nueva == null) return w;
    // Respeta la mayúscula inicial.
    return w[0] == w[0].toUpperCase() ? nueva[0].toUpperCase() + nueva.substring(1) : nueva;
  });
}
