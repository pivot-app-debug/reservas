import 'dart:io';

import 'package:archive/archive.dart';
import 'package:coach/core/xlsx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('xlsx: hojas, números y texto con caracteres especiales', () {
    final b = crearXlsx([
      const HojaXlsx('Movimientos', [
        ['Fecha', 'Monto', 'Descripción'],
        ['2026-11-26', 12.5, 'Cuota & <clase> "x"'],
      ]),
      const HojaXlsx('Totales', [
        ['A', 'B'],
        ['x', 3],
      ]),
    ]);
    final z = ZipDecoder().decodeBytes(b);
    expect(z.files.map((f) => f.name), containsAll(['xl/workbook.xml', 'xl/worksheets/sheet1.xml', 'xl/worksheets/sheet2.xml']));
    if (Platform.environment['XLSX_OUT'] != null) File(Platform.environment['XLSX_OUT']!).writeAsBytesSync(b);
  });
}
