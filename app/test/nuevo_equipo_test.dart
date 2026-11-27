import 'package:coach/core/api.dart';
import 'package:coach/core/tema.dart';
import 'package:coach/pivots/categorias_screen.dart';
import 'package:coach/sesion/sesion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ApiFalsa extends Api {
  @override
  Future<Map<String, dynamic>> get(String action, [Map<String, Object?> params = const {}]) async {
    if (action == 'getTiers') {
      return {
        'tiers': [
          {'id': 1, 'nombre': 'Mirlxs', 'orden': 1, 'es_default': true, 'requisitos': {}},
          {'id': 2, 'nombre': 'Quindes', 'orden': 2, 'requisitos': {}},
        ],
      };
    }
    if (action == 'adminDatosCategorias') return {'personas': []};
    return {};
  }
}

void main() {
  testWidgets('Crear un equipo: el asistente abre y avanza sin errores', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(360 * 3, 760 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final s = Sesion(_ApiFalsa())
      ..esAdmin = true
      ..adminToken = 'x';
    await t.pumpWidget(
      MaterialApp(
        theme: construirTema(Brightness.light),
        home: NuevoEquipoScreen(sesion: s),
      ),
    );
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull);
    expect(find.text('¿Cómo se llama?'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Halcones');
    await t.pump();
    final siguiente = find.text('Continuar');
    if (siguiente.evaluate().isNotEmpty) {
      await t.tap(siguiente.first);
      await t.pump(const Duration(milliseconds: 600));
    }
    expect(t.takeException(), isNull);
  });
}
