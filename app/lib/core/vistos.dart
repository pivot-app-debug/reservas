import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que ya viste (Victor, 2026-11-22): el punto de aviso sigue el camino
/// hasta lo nuevo (la persona o el aviso, su pestaña y la barra de abajo) y
/// se apaga en todo el camino cuando lo ves. Se guarda en el teléfono.
class Vistos extends ChangeNotifier {
  Vistos._() {
    _cargar();
  }
  static final instancia = Vistos._();

  static const _pref = 'vistos.claves';
  Set<String> _claves = {};
  bool _listo = false;

  /// Hasta cargar, todo cuenta como visto (sin puntos que se prenden y apagan).
  bool visto(String clave) => !_listo || _claves.contains(clave);

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _claves = (prefs.getStringList(_pref) ?? const []).toSet();
    _listo = true;
    notifyListeners();
  }

  Future<void> marcar(Iterable<String> claves) async {
    final nuevas = claves.where((c) => !_claves.contains(c)).toList();
    if (nuevas.isEmpty) return;
    _claves.addAll(nuevas);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    // Solo lo último: no crece para siempre.
    final l = _claves.toList();
    await prefs.setStringList(_pref, l.length > 400 ? l.sublist(l.length - 400) : l);
  }
}
