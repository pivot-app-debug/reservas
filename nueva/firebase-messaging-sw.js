/* Notificaciones de la app web (Flutter) con Firebase Cloud Messaging
   (Victor, 2026-11-15). El servidor manda mensajes solo de datos
   (titulo, cuerpo, url, evento_id): aquí se arma la notificación.
   Firebase lo busca en /firebase-messaging-sw.js (raíz del sitio): una copia
   vive en la raíz del repositorio mientras la app esté en /nueva/. */
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB2k9hPFPmAMLVHvOnz13j5P9X6YJx0sQ4',
  authDomain: 'pivot-d65f4.firebaseapp.com',
  projectId: 'pivot-d65f4',
  storageBucket: 'pivot-d65f4.firebasestorage.app',
  messagingSenderId: '167871376984',
  appId: '1:167871376984:web:565066c2084cf2adeae42d',
});

var APP = '/nueva/';

firebase.messaging().onBackgroundMessage(function (m) {
  var d = (m && m.data) || {};
  return self.registration.showNotification(d.titulo || 'Pivot', {
    body: d.cuerpo || '',
    icon: APP + 'icons/Icon-192.png',
    badge: APP + 'icons/Icon-192.png',
    data: { url: APP + (d.evento_id ? '?evento=' + encodeURIComponent(d.evento_id) : '') },
  });
});

self.addEventListener('notificationclick', function (e) {
  e.notification.close();
  var url = (e.notification.data && e.notification.data.url) || APP;
  e.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (lista) {
      for (var i = 0; i < lista.length; i++) {
        if (lista[i].url.indexOf(APP) !== -1 && 'focus' in lista[i]) return lista[i].focus();
      }
      return clients.openWindow(url);
    })
  );
});
