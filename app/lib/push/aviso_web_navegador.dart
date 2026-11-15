import 'package:web/web.dart' as web;

/// Con la pestaña abierta el service worker no muestra nada: la mostramos aquí.
void mostrarAvisoWeb(String titulo, String cuerpo) {
  try {
    if (web.Notification.permission != 'granted') return;
    web.Notification(titulo, web.NotificationOptions(body: cuerpo, icon: 'icons/Icon-192.png'));
  } catch (_) {}
}
