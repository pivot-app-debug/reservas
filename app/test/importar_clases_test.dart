import 'dart:io';

import 'package:coach/cursos/importar_clases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('csv', () {
    final r = clasesDesdeCsv(
      'Fecha,Hora,Lugar,Temas,Clínica\n2026-12-01,19:00,Coliseo,"Postura, Frenos",No\nmal,,,,\n13/12/2026,9:00 am,Coliseo,Agilidad,Sí\n',
    );
    expect(r.clases.length, 2);
    expect(r.saltadas, 1);
    expect(r.clases.first['temas'], ['Postura', 'Frenos']);
    expect(r.clases.last['tipo'], 'clinica');
    expect(r.clases.last['hora'], '09:00');
  });
  test('xlsx', () {
    final r = clasesDesdeXlsx(File('test/clases.xlsx').readAsBytesSync());
    expect(r.clases.length, 3);
    expect(r.clases[0]['fecha'], '2026-12-01');
    expect(r.clases[0]['hora'], '19:00');
    expect(r.clases[0]['termina'], '21:00');
    expect(r.clases[1]['hora'], '19:30');
    expect(r.clases[2]['tipo'], 'clinica');
  });
}
