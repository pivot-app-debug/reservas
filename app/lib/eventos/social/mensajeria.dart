import 'package:flutter/material.dart';

import '../../core/iconos_marca.dart';
import '../../equipo/comunidad_screen.dart';
import '../../sesion/sesion.dart';

/// Apps de mensajería de la liga (Victor, 2026-11-20): las que tiene como
/// comunidad en Equipo (WhatsApp, Telegram, Signal). Si la liga no usa
/// WhatsApp, no se ofrece WhatsApp. El mensaje de texto (SMS) siempre está.
const _redesMensajeria = ['whatsapp', 'telegram', 'signal'];

Future<List<String>> mensajeriasDeLiga(Sesion s) async {
  final c = ComunidadRepo.de(s);
  if (!c.cargado) await c.cargar();
  return [
    for (final r in _redesMensajeria)
      if (c.enlaces.any((e) => e.red == r)) r,
  ];
}

/// Número con código de país, solo dígitos ("0991234567" → "593991234567").
String telefonoInternacional(String numero, {String prefijo = ''}) {
  var n = numero.replaceAll(RegExp(r'[^0-9]'), '');
  final pre = prefijo.replaceAll(RegExp(r'[^0-9]'), '');
  if (n.isEmpty) return '';
  if (n.startsWith('0')) return '${pre.isEmpty ? '593' : pre}${n.substring(1)}';
  if (pre.isNotEmpty && !n.startsWith(pre)) return '$pre$n';
  return n;
}

/// Formas de escribirle a un número: las apps de la liga y SMS.
List<(String, IconData, Uri)> canalesPara(String digitos, List<String> redes, {String? texto}) {
  if (digitos.length < 7) return const [];
  final t = texto == null ? '' : Uri.encodeComponent(texto);
  return [
    for (final r in redes)
      switch (r) {
        'whatsapp' => ('WhatsApp', IconosMarca.whatsapp, Uri.parse('https://wa.me/$digitos${t.isEmpty ? '' : '?text=$t'}')),
        'telegram' => ('Telegram', IconosMarca.telegram, Uri.parse('https://t.me/+$digitos')),
        _ => ('Signal', IconosMarca.signal, Uri.parse('https://signal.me/#p/+$digitos')),
      },
    ('Mensaje de texto', Icons.sms_outlined, Uri.parse('sms:+$digitos${t.isEmpty ? '' : '?body=$t'}')),
  ];
}
