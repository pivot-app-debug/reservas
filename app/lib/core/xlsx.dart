import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Hoja de Excel (.xlsx) mínima, sin paquetes extra (Victor, 2026-11-26:
/// "exportar .xlsx real"). Cada hoja es una tabla: la primera fila va en
/// negrita y fija; los números quedan como números y el resto como texto.
class HojaXlsx {
  const HojaXlsx(this.nombre, this.filas, {this.anchos = const []});
  final String nombre;
  final List<List<Object?>> filas;

  /// Ancho de cada columna (en caracteres).
  final List<double> anchos;
}

Uint8List crearXlsx(List<HojaXlsx> hojas) {
  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  String columna(int i) {
    var n = i + 1, s = '';
    while (n > 0) {
      final r = (n - 1) % 26;
      s = String.fromCharCode(65 + r) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  String hojaXml(HojaXlsx h) {
    final b = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
      ..write('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>');
    if (h.anchos.isNotEmpty) {
      b.write('<cols>');
      for (final (i, w) in h.anchos.indexed) {
        b.write('<col min="${i + 1}" max="${i + 1}" width="$w" customWidth="1"/>');
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    for (final (f, fila) in h.filas.indexed) {
      b.write('<row r="${f + 1}">');
      for (final (c, v) in fila.indexed) {
        final ref = '${columna(c)}${f + 1}';
        final estilo = f == 0 ? ' s="1"' : '';
        if (v == null || '$v'.isEmpty) continue;
        if (v is num && f > 0) {
          b.write('<c r="$ref"$estilo><v>$v</v></c>');
        } else {
          b.write('<c r="$ref" t="inlineStr"$estilo><is><t xml:space="preserve">${esc('$v')}</t></is></c>');
        }
      }
      b.write('</row>');
    }
    b.write('</sheetData></worksheet>');
    return b.toString();
  }

  final a = Archive();
  void agregar(String ruta, String texto) {
    final bytes = utf8.encode(texto);
    a.addFile(ArchiveFile(ruta, bytes.length, bytes));
  }

  agregar(
    '[Content_Types].xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '${[for (var i = 1; i <= hojas.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
        '</Types>',
  );
  agregar(
    '_rels/.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
  );
  agregar(
    'xl/workbook.xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
        '${[for (final (i, h) in hojas.indexed) '<sheet name="${esc(h.nombre.length > 31 ? h.nombre.substring(0, 31) : h.nombre)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets></workbook>',
  );
  agregar(
    'xl/_rels/workbook.xml.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var i = 1; i <= hojas.length; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}'
        '<Relationship Id="rId${hojas.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
  );
  agregar(
    'xl/styles.xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
        '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        '</styleSheet>',
  );
  for (final (i, h) in hojas.indexed) {
    agregar('xl/worksheets/sheet${i + 1}.xml', hojaXml(h));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}
