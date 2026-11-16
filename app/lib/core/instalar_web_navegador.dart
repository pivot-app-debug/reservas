import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

enum PlataformaWeb { escritorio, android, ios }

String get _ua => web.window.navigator.userAgent.toLowerCase();

PlataformaWeb plataformaWeb() {
  final ua = _ua;
  if (ua.contains('android')) return PlataformaWeb.android;
  if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod') || (ua.contains('macintosh') && web.window.navigator.maxTouchPoints > 1)) {
    return PlataformaWeb.ios;
  }
  return PlataformaWeb.escritorio;
}

/// Abierta desde la pantalla de inicio (Android y iPhone).
bool esAppInstalada() {
  try {
    if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
    final s = web.window.navigator.getProperty<JSAny?>('standalone'.toJS);
    return s != null && (s as JSBoolean).toDart;
  } catch (_) {
    return false;
  }
}

/// Android solo con Chrome; iPhone solo con Safari (los únicos que instalan).
bool navegadorCompatible() {
  final ua = _ua;
  switch (plataformaWeb()) {
    case PlataformaWeb.android:
      return ua.contains('chrome') && !ua.contains('edg') && !ua.contains('opr') && !ua.contains('samsung') && !ua.contains('wv');
    case PlataformaWeb.ios:
      return ua.contains('safari') &&
          !ua.contains('crios') &&
          !ua.contains('fxios') &&
          !ua.contains('opios') &&
          !ua.contains('edgios') &&
          !ua.contains('mercury');
    case PlataformaWeb.escritorio:
      return true;
  }
}

bool puedeInstalarDirecto() {
  try {
    return globalContext.getProperty<JSAny?>('pivotPrompt'.toJS) != null;
  } catch (_) {
    return false;
  }
}

bool recienInstalada() {
  try {
    return globalContext.getProperty<JSAny?>('pivotInstalada'.toJS) != null;
  } catch (_) {
    return false;
  }
}

/// Muestra el aviso de instalación de Chrome. true si la persona aceptó.
Future<bool> instalarDirecto() async {
  try {
    final p = globalContext.getProperty<JSObject?>('pivotPrompt'.toJS);
    if (p == null) return false;
    p.callMethod<JSAny?>('prompt'.toJS);
    final eleccion = await (p.getProperty<JSPromise<JSObject>>('userChoice'.toJS)).toDart;
    globalContext.setProperty('pivotPrompt'.toJS, null);
    return (eleccion.getProperty<JSString>('outcome'.toJS)).toDart == 'accepted';
  } catch (_) {
    return false;
  }
}

String direccionActual() => web.window.location.href;

/// Quita los datos de la dirección (token de la inscripción) sin recargar.
void limpiarEnlace() {
  try {
    web.window.history.replaceState(null, '', web.window.location.pathname);
  } catch (_) {}
}
