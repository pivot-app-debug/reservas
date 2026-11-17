import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

/// Clases de un curso desde un Excel (.xlsx) o un .csv (Victor, 2026-11-17).
/// Columnas (la primera fila es el encabezado, en cualquier orden): Fecha,
/// Hora, Termina (opcional), Lugar, Temas (separados por coma), Clínica (sí/no).
class ClasesImportadas {
  ClasesImportadas(this.clases, this.saltadas);
  final List<Map<String, dynamic>> clases;
  final int saltadas;
}

/// Pide el archivo y lo lee. null = no eligió nada.
Future<ClasesImportadas?> importarClases() async {
  final l = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx', 'csv']);
  if (l.isEmpty) return null;
  final f = l.first;
  final bytes = await f.readAsBytes();
  final filas = f.name.toLowerCase().endsWith('.csv') ? _leerCsv(utf8.decode(bytes, allowMalformed: true)) : _leerXlsx(bytes);
  return _aClases(filas);
}

/// Plantilla para completar en Excel (se abre como hoja de cálculo).
Future<void> compartirPlantilla() async {
  const texto =
      'Fecha,Hora,Termina,Lugar,Temas,Clínica\n'
      '2026-12-01,19:00,21:00,Coliseo,"Postura, Frenos",No\n'
      '2026-12-08,19:00,21:00,Coliseo,"Caídas, Frenos",No\n'
      '2026-12-13,09:00,14:00,Coliseo,"Clínica de agilidad",Sí\n';
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(Uint8List.fromList(utf8.encode('﻿$texto')), name: 'plantilla_clases.csv', mimeType: 'text/csv')],
      fileNameOverrides: const ['plantilla_clases.csv'],
      text: 'Plantilla de clases: una fila por clase. Temas separados por coma.',
    ),
  );
}

// ─── Lectura ────────────────────────────────────────────────────────────────

List<List<String>> _leerCsv(String t) {
  final filas = <List<String>>[];
  var fila = <String>[], celda = StringBuffer(), comillas = false;
  final sep = t.split('\n').first.contains(';') && !t.split('\n').first.contains(',') ? ';' : ',';
  for (var i = 0; i < t.length; i++) {
    final c = t[i];
    if (comillas) {
      if (c == '"' && i + 1 < t.length && t[i + 1] == '"') {
        celda.write('"');
        i++;
      } else if (c == '"') {
        comillas = false;
      } else {
        celda.write(c);
      }
    } else if (c == '"') {
      comillas = true;
    } else if (c == sep) {
      fila.add(celda.toString());
      celda = StringBuffer();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < t.length && t[i + 1] == '\n') i++;
      fila.add(celda.toString());
      filas.add(fila);
      fila = [];
      celda = StringBuffer();
    } else {
      celda.write(c);
    }
  }
  if (celda.isNotEmpty || fila.isNotEmpty) {
    fila.add(celda.toString());
    filas.add(fila);
  }
  return filas;
}

/// Lector mínimo de .xlsx: la primera hoja, con textos compartidos, números y
/// textos en línea. Fechas y horas llegan como número de Excel.
List<List<String>> _leerXlsx(Uint8List bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  String? archivo(String nombre) {
    final f = zip.findFile(nombre);
    return f == null ? null : utf8.decode(f.content, allowMalformed: true);
  }

  String sinXml(String s) => s
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m.group(2)!, radix: m.group(1)!.isEmpty ? 10 : 16)))
      .replaceAll('&amp;', '&');
  final compartidos = [for (final m in RegExp(r'<si>(.*?)</si>', dotAll: true).allMatches(archivo('xl/sharedStrings.xml') ?? '')) sinXml(m.group(1)!)];
  final hoja = archivo('xl/worksheets/sheet1.xml') ?? '';
  final filas = <List<String>>[];
  for (final r in RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true).allMatches(hoja)) {
    final fila = <String>[];
    for (final c in RegExp(r'<c ([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true).allMatches(r.group(1)!)) {
      final attrs = c.group(1)!, cuerpo = c.group(2) ?? '';
      final ref = RegExp(r'r="([A-Z]+)\d+"').firstMatch(attrs)?.group(1) ?? '';
      var col = 0;
      for (final ch in ref.codeUnits) {
        col = col * 26 + (ch - 64);
      }
      while (fila.length < col - 1) {
        fila.add('');
      }
      final tipo = RegExp(r't="(\w+)"').firstMatch(attrs)?.group(1);
      final v = RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(cuerpo)?.group(1) ?? '';
      fila.add(switch (tipo) {
        's' => compartidos.elementAtOrNull(int.tryParse(v) ?? -1) ?? '',
        'inlineStr' => sinXml(RegExp(r'<is>(.*?)</is>', dotAll: true).firstMatch(cuerpo)?.group(1) ?? ''),
        _ => sinXml(v),
      });
    }
    filas.add(fila);
  }
  return filas;
}

// ─── Filas a clases ─────────────────────────────────────────────────────────

String _norm(String s) => s.toLowerCase().replaceAll('í', 'i').replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('ó', 'o').replaceAll('ú', 'u').trim();

ClasesImportadas _aClases(List<List<String>> filas) {
  if (filas.isEmpty) return ClasesImportadas(const [], 0);
  final enc = [for (final x in filas.first) _norm(x)];
  int col(List<String> claves) => enc.indexWhere((h) => claves.any(h.contains));
  final cFecha = col(['fecha', 'dia']), cHora = col(['hora', 'empieza', 'inicio']), cFin = col(['termina', 'fin']);
  final cLugar = col(['lugar', 'donde']), cTemas = col(['tema', 'habilidad']), cClinica = col(['clinica']);
  final out = <Map<String, dynamic>>[];
  var saltadas = 0;
  for (final f in filas.skip(1)) {
    String de(int i) => i >= 0 && i < f.length ? f[i].trim() : '';
    if (f.every((x) => x.trim().isEmpty)) continue;
    final fecha = _fecha(de(cFecha));
    if (fecha == null) {
      saltadas++;
      continue;
    }
    final hora = _hora(de(cHora == cFin ? -1 : cHora)) ?? '09:00';
    final fin = cFin >= 0 && cFin != cHora ? _hora(de(cFin)) : null;
    final temas = [
      for (final t in de(cTemas).split(RegExp(r'[,;/]')))
        if (t.trim().isNotEmpty) t.trim().length > 40 ? t.trim().substring(0, 40) : t.trim(),
    ];
    final clinica = const ['si', 'sí', 'x', '1', 'true'].contains(_norm(de(cClinica)));
    out.add({
      'fecha': fecha,
      'hora': hora,
      'termina': ?fin,
      'lugar': de(cLugar),
      'tipo': clinica ? 'clinica' : 'clase',
      if (temas.isNotEmpty) 'temas': temas.take(15).toList(),
    });
  }
  out.sort((a, b) => '${a['fecha']}'.compareTo('${b['fecha']}'));
  return ClasesImportadas(out, saltadas);
}

/// "2026-12-01", "01/12/2026", "1-12-26" o número de Excel → aaaa-mm-dd.
String? _fecha(String s) {
  if (s.isEmpty) return null;
  final n = double.tryParse(s);
  if (n != null && n > 20000 && n < 80000) {
    final d = DateTime(1899, 12, 30).add(Duration(days: n.floor()));
    return _iso(d);
  }
  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (m != null) return _iso(DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!)));
  m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})').firstMatch(s);
  if (m != null) {
    var a = int.parse(m.group(3)!);
    if (a < 100) a += 2000;
    return _iso(DateTime(a, int.parse(m.group(2)!), int.parse(m.group(1)!)));
  }
  return null;
}

String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "19:00", "7:30 pm" o fracción de día de Excel → HH:mm.
String? _hora(String s) {
  if (s.isEmpty) return null;
  final n = double.tryParse(s);
  if (n != null && n >= 0 && n < 1) {
    final min = (n * 24 * 60).round();
    return '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';
  }
  final m = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([ap])?\.?\s*m?', caseSensitive: false).firstMatch(s.trim());
  if (m == null) return null;
  var h = int.parse(m.group(1)!);
  final mi = int.tryParse(m.group(2) ?? '0') ?? 0;
  final ap = m.group(3)?.toLowerCase();
  if (ap == 'p' && h < 12) h += 12;
  if (ap == 'a' && h == 12) h = 0;
  if (h > 23 || mi > 59) return null;
  return '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
}

/// Para pruebas: clases desde el texto de un .csv o los bytes de un .xlsx.
ClasesImportadas clasesDesdeCsv(String texto) => _aClases(_leerCsv(texto));
ClasesImportadas clasesDesdeXlsx(Uint8List bytes) => _aClases(_leerXlsx(bytes));
