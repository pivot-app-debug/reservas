import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/tema.dart';
import '../core/vidrio.dart' show altoBarra;
import '../sesion/sesion.dart';
import 'coach_screen.dart' show barraCoach;

/// Notificaciones de entrenador (Victor, 2026-11-26; simplificada el
/// 2026-11-27, sin lista de personas ni avisos sueltos): el aviso semanal de
/// progreso a tus jugadorxs y los avisos que te llegan a ti.
class NotificacionesEntrenadorScreen extends StatefulWidget {
  const NotificacionesEntrenadorScreen({super.key, required this.sesion, required this.jugadorxs, required this.sinAvisos, required this.avisarNovedades});
  final Sesion sesion;
  final List<Map<String, dynamic>> jugadorxs;
  final List<String> sinAvisos;
  final bool avisarNovedades;

  @override
  State<NotificacionesEntrenadorScreen> createState() => _NotificacionesEntrenadorScreenState();
}

/// Avisos que recibe unx entrenadorx (claves del catálogo del servidor).
const _misAvisos = [
  ('coach_por_evaluar', 'Entrenamientos por evaluar', 'El día siguiente, si falta evaluar a quienes vinieron.'),
  ('coach_pedido_plan', 'Entrenamiento sin plan', 'El día antes, si un entrenamiento todavía no tiene plan.'),
  ('cambios_asistencia', 'Cambios de asistencia', 'Cuando alguien cambia su respuesta a un entrenamiento.'),
];

class _NotificacionesEntrenadorScreenState extends State<NotificacionesEntrenadorScreen> {
  Sesion get s => widget.sesion;
  late bool _novedades = widget.avisarNovedades;
  Map<String, bool>? _prefs;

  @override
  void initState() {
    super.initState();
    s.api.get('getPreferenciasPush').then((r) {
      if (!mounted || r['exito'] == false) return;
      setState(() => _prefs = {for (final e in ((r['preferencias'] as Map?) ?? const {}).entries) '${e.key}': e.value == true});
    }, onError: (_) {});
  }

  void _aviso(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _resumen(bool v) async {
    setState(() => _novedades = v);
    try {
      await s.api.post('coachGuardar', {'accion': 'ajustes', 'avisarNovedades': v});
    } catch (_) {
      if (mounted) setState(() => _novedades = !v);
    }
  }

  Future<void> _mio(String clave, bool v) async {
    final antes = _prefs?[clave];
    setState(() => (_prefs ??= {})[clave] = v);
    try {
      final r = await s.api.post('guardarPreferenciasPush', {'clave': clave, 'valor': '$v'});
      if (r['exito'] != true) throw ApiException('${r['error'] ?? ''}');
    } catch (_) {
      if (!mounted) return;
      setState(() => antes == null ? _prefs!.remove(clave) : _prefs![clave] = antes);
      _aviso('No se pudo guardar. Revisa tu conexión.');
    }
  }

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
    child: Text(
      t,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.pivot.textoSecundario),
    ),
  );

  Widget _grupo(List<Widget> hijos) => Material(
    color: context.pivot.tarjeta,
    borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
    clipBehavior: Clip.antiAlias,
    child: Column(children: hijos),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: barraCoach('Notificaciones del equipo técnico'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96 + MediaQuery.paddingOf(context).bottom),
        children: [
          _titulo('A LAS PERSONAS QUE ENTRENAS'),
          _grupo([
            SwitchListTile(
              secondary: Icon(Icons.auto_awesome_outlined, color: p.marcaTexto),
              // Explicado con un ejemplo (Victor, 2026-11-27: no se entendía).
              title: const Text('Aviso semanal de su progreso'),
              subtitle: const Text(
                'Si durante la semana evalúas una habilidad, anotas un resultado de prueba o dejas una nota a alguien, el lunes le llega: «El equipo técnico dejó notas o resultados esta semana. Míralos en Mi progreso». A quien no tiene nada nuevo no le llega nada.',
              ),
              value: _novedades,
              onChanged: _resumen,
            ),
          ]),
          _titulo('LO QUE TE LLEGA A TI'),
          _grupo([
            for (final a in _misAvisos)
              SwitchListTile(title: Text(a.$2), subtitle: Text(a.$3), value: _prefs?[a.$1] != false, onChanged: _prefs == null ? null : (v) => _mio(a.$1, v)),
          ]),
        ],
      ),
    );
  }
}
