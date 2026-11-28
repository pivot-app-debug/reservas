import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Con la pestaña abierta el service worker no muestra nada: la mostramos aquí.
void mostrarAvisoWeb(String titulo, String cuerpo) {
  try {
    if (web.Notification.permission != 'granted') return;
    web.Notification(titulo, web.NotificationOptions(body: cuerpo, icon: 'icons/Icon-192.png'));
  } catch (_) {}
}

/// 'granted', 'denied', 'default' o 'unsupported' (iPhone sin instalar la app).
String permisoAvisosWeb() {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

/// Pide el permiso en el mismo toque (iPhone lo exige así).
Future<String> pedirPermisoAvisosWeb() async {
  try {
    final r = await web.Notification.requestPermission().toDart;
    return r.toDart;
  } catch (_) {
    return 'unsupported';
  }
}

/// iPhone o iPad (Safari): los avisos solo llegan con la app agregada a la pantalla de inicio.
bool esIosWeb() {
  final ua = web.window.navigator.userAgent.toLowerCase();
  return ua.contains('iphone') || ua.contains('ipad') || (ua.contains('macintosh') && web.window.navigator.maxTouchPoints > 1);
}

/// Navegador dentro de otra app (WhatsApp, Instagram, Facebook, TikTok…):
/// ahí no hay notificaciones (Victor, 2026-11-28).
bool esNavegadorInterno() {
  final ua = web.window.navigator.userAgent.toLowerCase();
  return const [
        'instagram',
        'fban',
        'fbav',
        'fb_iab',
        'whatsapp',
        'tiktok',
        'musical_ly',
        'bytedance',
        'snapchat',
        'line/',
        'telegram',
        'twitter',
        'linkedinapp',
      ].any(ua.contains) ||
      (ua.contains('android') && ua.contains('; wv)'));
}

/// Navegador y sistema para la guía de activar avisos (QA 2026-11-27):
/// 'ios', 'android', 'safari', 'firefox', 'edge' o 'chrome' (el resto).
String navegadorWeb() {
  final ua = web.window.navigator.userAgent.toLowerCase();
  if (esNavegadorInterno()) return 'interno';
  if (esIosWeb()) return 'ios';
  if (ua.contains('android')) return 'android';
  if (ua.contains('firefox')) return 'firefox';
  if (ua.contains('edg/')) return 'edge';
  if (ua.contains('safari') && !ua.contains('chrome')) return 'safari';
  return 'chrome';
}
