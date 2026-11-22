import 'package:coach/core/api.dart';
import 'package:coach/core/tema.dart';
import 'package:coach/eventos/social/social_repo.dart';
import 'package:coach/eventos/social/social_vista.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vista de fiesta (Victor, 2026-11-21): banner de pendientes, Qué lleva
/// resumida y actividades deslizables, sin desbordes en un teléfono angosto.
void main() {
  testWidgets('Fiesta: pendientes, Qué lleva resumida y actividades', (t) async {
    t.view.physicalSize = const Size(340 * 3, 900 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final estado = EstadoSocial({
      'yo': {
        'asiste': true,
        'participa': {'amigo': false, 'robado': true, 'respondio': true},
      },
      'conteo': {'total': 10},
      'social': {
        'comida': true,
        'amigoSecreto': true,
        'regaloRobado': true,
        'inscripcionAbierta': true,
        'cierre': '2026-12-15',
        'topeAmigo': 15,
        'playlist': {'link': ''},
        'dress': {'texto': 'Ugly sweater navideño con luces'},
      },
      'modulos': {'comida': true, 'amigoSecreto': true, 'regaloRobado': true},
      'comida': [
        {
          'id': 'a',
          'nombre': 'Postres',
          'unidad': 'porciones',
          'porPersona': 2,
          'meta': 20,
          'aportado': 4,
          'modo': 'meta',
          'falta': false,
          'cerrada': false,
          'sugerencias': [],
          'aportes': [
            {'id': 'x', 'nombre': 'Vic', 'usuario': 'Vic', 'cantidad': 1, 'detalle': 'Brownies de chocolate', 'mio': true, 'paraTodxs': true},
          ],
        },
      ],
    });
    var comida = 0, amigo = 0;
    String? abierta;
    await t.pumpWidget(
      MaterialApp(
        theme: construirTema(Brightness.light),
        home: Scaffold(
          body: ListView(
            children: [
              PendientesFiesta(estado: estado, alParticipar: () => amigo++, alDeseos: () {}, alComida: () => comida++),
              QueLlevaResumen(
                repo: SocialRepo.miembro(Api(), idEvento: 'e'),
                estado: estado,
                alCambiar: () {},
                alAbrir: () => comida++,
              ),
              ActividadesSocial(estado: estado, alAbrir: (q) => abierta = q),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('No participas del amigo secreto. ¿Quieres participar?'), findsOneWidget);
    expect(find.text('Te falta completar lo que llevas.'), findsOneWidget);
    expect(find.textContaining('Tu parte:'), findsOneWidget);
    expect(find.text('Hace falta'), findsWidgets);
    expect(find.text('Actividades del evento'), findsOneWidget);
    await t.tap(find.text('Participar'));
    expect(amigo, 1);
    await t.tap(find.text('Amigo secreto'));
    expect(abierta, 'amigo');
    await t.tap(find.text('Qué llevar'));
    expect(comida, 1);
  });
}
