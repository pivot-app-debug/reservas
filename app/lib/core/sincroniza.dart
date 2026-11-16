import 'package:flutter/widgets.dart';

/// En lugar de "deslizar para actualizar" (Victor, 2026-11-16: se quita en
/// toda la app): la pantalla se sincroniza sola al abrirse y al volver a la
/// app. [alAbrir] vuelve a pedir los datos al abrirla, para las pantallas
/// que muestran primero lo guardado.
class Sincroniza extends StatefulWidget {
  const Sincroniza({super.key, required this.onRefresh, required this.child, this.alAbrir = false, this.edgeOffset = 0});
  final Future<void> Function() onRefresh;
  final Widget child;
  final bool alAbrir;

  /// Se ignora: queda para no cambiar las llamadas.
  final double edgeOffset;

  @override
  State<Sincroniza> createState() => _SincronizaState();
}

class _SincronizaState extends State<Sincroniza> with WidgetsBindingObserver {
  DateTime _ultima = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.alAbrir) WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // Al volver a la app, si pasó un rato (cuidando los datos móviles).
    if (estado == AppLifecycleState.resumed && DateTime.now().difference(_ultima).inSeconds > 30) _sincronizar();
  }

  Future<void> _sincronizar() async {
    _ultima = DateTime.now();
    if (!mounted) return;
    try {
      await widget.onRefresh();
    } catch (_) {
      // Sin señal: queda lo que había.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
