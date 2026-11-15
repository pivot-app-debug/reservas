import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Botón oficial de Google para la web (Flutter web no permite abrir el
/// selector desde un botón propio).
Widget? botonGoogleWeb() => SizedBox(
  height: 52,
  child: web.renderButton(
    configuration: web.GSIButtonConfiguration(
      type: web.GSIButtonType.standard,
      shape: web.GSIButtonShape.pill,
      size: web.GSIButtonSize.large,
      text: web.GSIButtonText.continueWith,
      minimumWidth: 300,
      locale: 'es',
    ),
  ),
);
