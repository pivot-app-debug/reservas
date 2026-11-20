import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Borra lo guardado en caché por el navegador (sin tocar el service worker de
/// las notificaciones) y recarga con la versión nueva.
Future<void> recargarWebNueva(int version) async {
  try {
    final claves = await web.window.caches.keys().toDart;
    for (final k in claves.toDart) {
      await web.window.caches.delete(k.toDart).toDart;
    }
  } catch (_) {}
  try {
    final regs = await web.window.navigator.serviceWorker.getRegistrations().toDart;
    for (final r in regs.toDart) {
      // El de las notificaciones push se queda.
      if (!(r.active?.scriptURL ?? '').contains('firebase-messaging-sw')) await r.unregister().toDart;
    }
  } catch (_) {}
  // Vuelve a pedir los archivos principales saltándose la caché del navegador,
  // así la recarga no trae otra vez la versión vieja.
  for (final a in ['/', 'index.html', 'flutter_bootstrap.js', 'flutter.js', 'main.dart.js']) {
    try {
      await web.window.fetch(a.toJS, web.RequestInit(cache: 'reload')).toDart;
    } catch (_) {}
  }
  web.window.location.replace('/?v=$version');
}
