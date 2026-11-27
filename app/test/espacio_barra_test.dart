import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coach/core/espacio_barra.dart';
import 'package:coach/ajustes/componentes.dart';

int creados = 0;

class Padre extends StatefulWidget {
  const Padre({super.key});
  @override
  State<Padre> createState() => _PadreState();
}

class _PadreState extends State<Padre> {
  String r = 'nada';
  @override
  void initState() {
    super.initState();
    creados++;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text('padre $r')),
    floatingActionButton: FloatingActionButton(
      key: const Key('mas'),
      onPressed: () async {
        final x = await Navigator.of(context).push<Object>(MaterialPageRoute(builder: (_) => const Hijo()));
        if (!mounted) return;
        setState(() => r = '$x');
      },
    ),
  );
}

class Hijo extends StatelessWidget {
  const Hijo({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: const TextField(key: Key('campo')),
    floatingActionButton: FloatingActionButton(key: const Key('guardar'), onPressed: () => Navigator.of(context).pop('ok')),
  );
}

void main() {
  testWidgets('el teclado no vuelve a crear la pantalla de abajo (formas de pago, 2026-11-27)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: TransicionConBarra(ZoomPageTransitionsBuilder())}),
        ),
        home: Builder(
          builder: (context) {
            final mq = MediaQuery.of(context);
            return Scaffold(
              extendBody: true,
              body: Builder(
                builder: (context) {
                  final mq = MediaQuery.of(context);
                  return MediaQuery(
                    data: mq.copyWith(viewPadding: mq.viewPadding.copyWith(bottom: mq.padding.bottom)),
                    child: Navigator(
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (c) => Scaffold(
                          body: Center(
                            child: ElevatedButton(key: const Key('abrir'), onPressed: () => SubAjustes.abrir(c, const Padre()), child: const Text('abrir')),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              bottomNavigationBar: SizedBox(
                height: 80 + mq.padding.bottom,
                child: const ColoredBox(color: Colors.red),
              ),
            );
          },
        ),
      ),
    );
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('abrir')));
    await tester.pumpAndSettle();
    expect(creados, 1);
    await tester.tap(find.byKey(const Key('mas')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campo')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    tester.view.padding = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guardar')));
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.padding = const FakeViewPadding(bottom: 48);
    await tester.pumpAndSettle();
    expect(creados, 1);
    expect(find.text('padre ok'), findsOneWidget);
  });
}
