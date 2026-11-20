import 'package:coach/core/api.dart';
import 'package:coach/core/tema.dart';
import 'package:coach/eventos/social/social_juego_screen.dart';
import 'package:coach/eventos/social/social_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _Falso extends SocialRepo {
  _Falso(this.r) : super.miembro(Api(), idEvento: 'e');
  Map<String, dynamic> r;
  final acciones = <String>[];
  @override
  Future<Map<String, dynamic>> juego(String accion, [Map<String, Object?> extra = const {}]) async {
    acciones.add(accion);
    return r;
  }
}

Map<String, dynamic> _resp(Map<String, dynamic> juego, {bool dirige = true}) => {
  'exito': true,
  'dirige': dirige,
  'hoy': true,
  'reglas': {'robosMax': 3, 'devolver': false, 'turnoFinal': true, 'describir': true},
  'juego': juego,
};

void main() {
  testWidgets('Regalo robado en vivo: pila, turno y robo sin desbordes', (t) async {
    t.view.physicalSize = const Size(360 * 3, 700 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final repo = _Falso(
      _resp({
        'fase': 'pila',
        'participantes': [
          {'clave': 'a', 'nombre': 'Ana', 'dejo': true, 'yo': true},
          {'clave': 'b', 'nombre': 'Beto', 'dejo': false, 'yo': false},
        ],
        'orden': [],
        'regalos': [],
        'historial': [],
        'pila': 1,
        'miTurno': 0,
      }),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: construirTema(Brightness.light),
        home: RegaloRobadoJuegoScreen(repo: repo),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Regalos a la pila'), findsOneWidget);
    expect(find.text('1 DE 2 DEJARON SU REGALO'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(t.takeException(), isNull, reason: 'pila');

    repo.r = _resp({
      'fase': 'juego',
      'participantes': [],
      'orden': [
        {'clave': 'a', 'nombre': 'Ana', 'yo': true, 'paso': true},
        {'clave': 'b', 'nombre': 'Beto', 'yo': false, 'paso': false},
      ],
      'actual': {'clave': 'b', 'nombre': 'Beto', 'yo': false},
      'esperando': false,
      'pila': 1,
      'regalos': [
        {'id': 1, 'desc': 'Taza', 'robos': 0, 'bloqueado': false, 'duenx': 'a', 'nombre': 'Ana', 'mio': true, 'vedado': false},
      ],
      'robado': null,
      'miTurno': 1,
      'historial': [
        {'texto': 'Ana abrió un regalo: Taza.', 'en': ''},
      ],
      'deshacer': true,
    });
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    expect(find.text('Le toca a Beto'), findsOneWidget);
    expect(find.text('Tienes: Taza'), findsOneWidget);
    expect(find.text('Abrió uno'), findsOneWidget);
    for (final e in t.allElements) {
      final ro = e.renderObject;
      if (ro is RenderFlex && ro.toStringShort().contains('OVERFLOWING')) debugPrint('OVF ${ro.debugCreator}');
    }
    final ex = t.takeException();
    if (ex is FlutterError) debugPrint(ex.toStringDeep());
    expect(ex, isNull, reason: 'juego');
    await t.tap(find.text('Robó uno'));
    await t.pumpAndSettle();
    expect(find.text('¿Qué regalo roba?'), findsOneWidget);
    await t.tap(find.text('Taza').last);
    await t.pumpAndSettle();
    expect(repo.acciones, contains('robar'));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
