import 'package:coach/core/api.dart';
import 'package:coach/core/tema.dart';
import 'package:coach/eventos/social/que_lleva_calculo.dart';
import 'package:coach/eventos/social/social_widgets.dart';
import 'package:flutter/material.dart';
import 'package:coach/eventos/social/social_repo.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _sec(String id, String unidad, num pp, num meta, List<Map<String, dynamic>> aportes, {String modo = 'meta'}) => {
  'id': id,
  'nombre': id,
  'unidad': unidad,
  'porPersona': pp,
  'meta': meta,
  'aportado': 0,
  'modo': modo,
  'aportes': aportes,
};

void main() {
  test('Rendimientos: reconoce cosas comunes, cantidades y litros escritos', () {
    expect(rendimientoDe('Pollo entero')?.personas, 4);
    expect(rendimientoDe('2 pollos asados')?.personas, 8);
    expect(rendimientoDe('dos pizzas grandes')?.personas, 8);
    expect(rendimientoDe('Una botella de vino tinto')?.litros, 0.75);
    expect(rendimientoDe('Coca cola 3 litros')?.litros, 3);
    expect(rendimientoDe('Pastel de chocolate')?.personas, 10);
    expect(rendimientoDe('Algo rico'), isNull);
  });

  test('Tu parte: lo que llevas para todxs compensa entre secciones', () {
    // 10 personas; salado y postre a 2 porciones, bebida a 1 litro; hielo no cuenta.
    EstadoSocial con(List<Map<String, dynamic>> bebida) => EstadoSocial({
      'yo': {'asiste': true},
      'conteo': {'total': 10},
      'comida': [
        _sec('Salado', 'porciones', 2, 20, []),
        _sec('Postre', 'porciones', 2, 20, []),
        _sec('Bebidas', 'litros', 1, 10, bebida),
        _sec('Hielo', 'bolsas', 0.3, 3, [], modo: 'total'),
      ],
    });
    final e = con([]);
    expect(e.seccionesParte.length, 3);
    expect(e.miParte, 0);
    // 4 litros = 4 personas en una sección: más que las 3 que te tocan.
    expect(
      con([
        {'mio': true, 'cantidad': 4, 'paraTodxs': true},
      ]).miParte,
      greaterThanOrEqualTo(1),
    );
    // Solo para mí no cuenta.
    expect(
      con([
        {'mio': true, 'cantidad': 4, 'paraTodxs': false},
      ]).miParte,
      0,
    );
    // Un pollo (4 personas = 8 porciones) en salado.
    final s = e.seccionesParte.first;
    expect(e.parteDe(s, 8), closeTo(4 / 3, 0.001));
  });

  testWidgets('Anotarse en comida: pregunta personas, calcula con lo que escribes y deja llevar de más', (t) async {
    t.view.physicalSize = const Size(360 * 3, 640 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final estado = EstadoSocial({
      'yo': {'asiste': true},
      'conteo': {'total': 10},
      'comida': [
        {..._sec('Platos salados', 'porciones', 2, 20, []), 'cerrada': true, 'aportado': 20, 'sugerencias': []},
        {..._sec('Bebidas', 'litros', 1, 10, []), 'sugerencias': []},
      ],
    });
    await t.pumpWidget(
      MaterialApp(
        theme: construirTema(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ComidaTarjeta(
              repo: SocialRepo.miembro(Api(), idEvento: 'e'),
              estado: estado,
              alCambiar: () {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Tu parte'), findsOneWidget);
    expect(find.text('0 %'), findsOneWidget);
    // La sección completa igual deja llevar más.
    await t.tap(find.text('Completadas (1)'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Llevar más'));
    await t.pumpAndSettle();
    expect(find.text('¿Para cuántas personas alcanza?'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'Pollo entero');
    await t.pumpAndSettle();
    expect(find.text('Un pollo entero suele alcanzar para unas 4 personas.'), findsOneWidget);
    expect(find.text('Una persona come unas 2 porciones. Son 8 porciones.'), findsOneWidget);
    expect(find.text('Con esto cubres tu parte ✓'), findsOneWidget);
    // Si bajas a 1 persona, avisa con Ajustar.
    await t.tap(find.byTooltip('Menos'));
    await t.tap(find.byTooltip('Menos'));
    await t.tap(find.byTooltip('Menos'));
    await t.pumpAndSettle();
    expect(find.text('Ajustar'), findsOneWidget);
    await t.ensureVisible(find.text('Ajustar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ajustar'));
    await t.pumpAndSettle();
    expect(find.text('Son 8 porciones.', findRichText: false), findsNothing);
    expect(find.text('Una persona come unas 2 porciones. Son 8 porciones.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
