import 'package:coach/actividad/actividad_screen.dart';
import 'package:coach/core/api.dart';
import 'package:coach/core/tema.dart';
import 'package:coach/eventos/eventos_repo.dart';
import 'package:coach/pivots/bandeja_repo.dart';
import 'package:coach/sesion/sesion.dart';
import 'package:coach/tareas/tareas_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Actividad: pestañas y Fiestas sin crear para quien no es Pivot de fiestas', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(360 * 3, 760 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final s = Sesion(Api());
    final repo = EventosRepo(s);
    await t.pumpWidget(
      MaterialApp(
        theme: construirTema(Brightness.light),
        home: ActividadScreen(eventos: repo, bandeja: BandejaRepo.de(s), tareas: TareasRepo.de(s), verClases: true),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Tareas'), findsOneWidget);
    expect(find.text('Clases'), findsOneWidget);
    await t.tap(find.text('Fiestas'));
    await t.pumpAndSettle();
    expect(find.textContaining('Los crea un Pivot de fiestas y eventos sociales'), findsOneWidget);
    expect(find.text('Crear evento'), findsNothing);
    expect(s.puedeCrearSocial, isFalse);
    // Un Pivot solo de fiestas no ve las herramientas de Pivot.
    s
      ..esAdmin = true
      ..adminToken = 'x'
      ..areasPivot = ['sociales']
      ..soloSociales = true;
    expect(s.esAdmin, isFalse);
    expect(s.puedeCrearSocial, isTrue);
    expect(t.takeException(), isNull);
  });
}
