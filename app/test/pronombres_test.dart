import 'package:flutter_test/flutter_test.dart';
import 'package:coach/core/pronombres.dart';

void main() {
  test('palabras según pronombres', () {
    expect(conPronombres('Lesionadx', 'Ella'), 'Lesionada');
    expect(conPronombres('Lesionadx', 'Él'), 'Lesionado');
    expect(conPronombres('Lesionadx', 'Elle'), 'Lesionade');
    expect(conPronombres('Lesionadx', 'Él, Elle'), 'Lesionadx');
    expect(conPronombres('Lesionadx', ''), 'Lesionadx');
    expect(conPronombres('Ya estás inscritx con unx administradorx', 'Ella'), 'Ya estás inscrita con una administradora');
    expect(conPronombres('Inactivxs y Mirlxs', 'Ella'), 'Inactivxs y Mirlxs');
    expect(conPronombres('vuelve a quedar Activx.', 'Él'), 'vuelve a quedar Activo.');
  });
}
