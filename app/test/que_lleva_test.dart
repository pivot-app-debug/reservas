import 'package:coach/core/api.dart';
import 'package:coach/core/tema.dart';
import 'package:coach/eventos/social/social_repo.dart';
import 'package:coach/eventos/social/social_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Qué lleva cada quien: secciones compactas, sin desbordes en un teléfono angosto', (t) async {
    t.view.physicalSize = const Size(360 * 3, 900 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final estado = EstadoSocial({
      'yo': {'asiste': true},
      'organiza': true,
      'conteo': {'total': 12, 'invitados': 0},
      'social': {'comida': true},
      'modulos': {'comida': true},
      'comida': [
        {
          'id': 'a',
          'nombre': 'Hielo',
          'unidad': 'bolsas',
          'porPersona': 1,
          'meta': 3,
          'aportado': 1,
          'modo': 'total',
          'total': 3,
          'mias': 0,
          'falta': true,
          'sugerencias': [],
          'cerrada': false,
          'aportes': [
            {'id': 'x', 'nombre': 'Shusho', 'cantidad': 1, 'detalle': '', 'mio': false, 'paraTodxs': true, 'foto': ''},
          ],
        },
        {
          'id': 'b',
          'nombre': 'Decoración navideña con luces y guirnaldas',
          'unidad': 'cosas',
          'porPersona': 2,
          'meta': 24,
          'aportado': 1,
          'modo': 'cada',
          'mias': 1,
          'falta': false,
          'sugerencias': ['Luces navideñas', 'Guirnaldas', 'Velas'],
          'cerrada': false,
          'aportes': [
            {'id': 'y', 'nombre': 'Victor', 'cantidad': 1, 'detalle': 'Luces navideñas', 'mio': true, 'paraTodxs': true, 'foto': ''},
          ],
        },
        {
          'id': 'c',
          'nombre': 'Bebidas',
          'unidad': 'litros',
          'porPersona': 1,
          'meta': 12,
          'aportado': 12,
          'modo': 'meta',
          'mias': 0,
          'falta': false,
          'sugerencias': [],
          'cerrada': true,
          'aportes': [],
        },
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
    expect(find.text('Qué lleva cada quien'), findsOneWidget);
    expect(find.text('Tú llevas'), findsOneWidget);
    expect(find.text('Hace falta'), findsOneWidget);
    expect(find.text('Te falta 1'), findsOneWidget);
    expect(find.text('Completadas (1)'), findsOneWidget);
    // La idea ya tomada no se repite.
    expect(find.text('Luces navideñas'), findsNothing);
    expect(find.text('Guirnaldas'), findsOneWidget);
    expect(t.takeException(), isNull);
    // La ventana para anotarse no se corta en un teléfono bajito.
    t.view.physicalSize = const Size(360 * 3, 560 * 3);
    await t.pumpAndSettle();
    await t.ensureVisible(find.byTooltip('Me anoto').first);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Me anoto').first);
    await t.pumpAndSettle();
    expect(find.text('¿Para quién?'), findsOneWidget);
    expect(find.text('Faltan 2 bolsas.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
