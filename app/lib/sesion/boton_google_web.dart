import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Botón oficial de Google para la web (Flutter web no permite abrir el
/// selector desde un botón propio).
/// [ancho]: el de los demás botones (Google admite de 200 a 400 px).
Widget? botonGoogleWeb({double ancho = 300}) => SizedBox(
  height: 52,
  child: web.renderButton(
    configuration: web.GSIButtonConfiguration(
      type: web.GSIButtonType.standard,
      shape: web.GSIButtonShape.pill,
      size: web.GSIButtonSize.large,
      text: web.GSIButtonText.continueWith,
      minimumWidth: ancho.clamp(200, 400).toDouble(),
      locale: 'es',
    ),
  ),
);
