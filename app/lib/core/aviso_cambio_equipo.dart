import 'package:flutter/material.dart';

import '../sesion/sesion.dart';
import 'tema.dart';

/// Ventana al abrir la app después de un cambio de equipo (Victor,
/// 2026-11-16): a qué equipo pasa y por qué, con sus números. Si sube, en
/// tono de celebración; si baja, "Entiendo" o "Pedir revisión" (llega a
/// Notificaciones y un Pivot decide si lo mantiene o lo devuelve).
Future<void> mostrarAvisoCambioEquipo(BuildContext context, Sesion s) async {
  final a = s.datos['avisoCambioEquipo'];
  if (a is! Map) return;
  final de = '${a['de'] ?? ''}', hacia = '${a['a'] ?? ''}';
  final sube = a['sube'] == true;
  // Números del período que decidió el cambio (el equipo al que subió, o el que dejó).
  String numeros = '';
  try {
    final r = await s.api.get('getEstadisticasPersona', {'nombreUsuario': s.nombre ?? '', 'anio': DateTime.now().year});
    final tiers = ((r['progreso'] as Map?)?['tiers'] as List?) ?? const [];
    final t = tiers.whereType<Map>().where((x) => x['nombre'] == (sube ? hacia : de)).firstOrNull;
    if (t != null) {
      final partes = [
        if ((t['minClases'] as num? ?? 0) > 0) '${t['clasesCerrado'] ?? 0} de ${t['minClases']} clases',
        if ((t['minPuntos'] as num? ?? 0) > 0 && t['puntosCerrado'] != null) '${t['puntosCerrado']} de ${t['minPuntos']} puntos',
      ];
      if (partes.isNotEmpty) numeros = 'En el último período: ${partes.join(' y ')}.';
    }
  } catch (_) {}
  if (!context.mounted) return;
  final p = context.pivot;
  final eleccion = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (d) => AlertDialog(
      icon: Icon(sube ? Icons.celebration_rounded : Icons.swap_vert_rounded, size: 40, color: p.marcaTexto),
      title: Text(sube ? '¡Subiste a $hacia!' : 'Pasaste a $hacia'),
      content: Text(
        [
          sube ? 'Cumpliste lo que pide $hacia. ¡Felicitaciones!' : 'No llegaste a lo que pide $de, así que pasaste a $hacia.',
          if (numeros.isNotEmpty) numeros,
          if (!sube) 'Tus asistencias y puntos ya ganados no cambian. Si crees que hay un error, pide una revisión.',
        ].join('\n\n'),
      ),
      actions: [
        if (!sube) TextButton(onPressed: () => Navigator.of(d).pop('revision'), child: const Text('Pedir revisión')),
        FilledButton(onPressed: () => Navigator.of(d).pop('ok'), child: Text(sube ? '¡Genial!' : 'Entiendo')),
      ],
    ),
  );
  if (!context.mounted) return;
  var mensaje = '';
  if (eleccion == 'revision') {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Pedir revisión'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'Cuéntale al Pivot qué pasó (opcional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Enviar')),
        ],
      ),
    );
    mensaje = c.text.trim();
    c.dispose();
    if (ok != true) return; // la ventana vuelve a salir la próxima vez
  }
  try {
    await s.api.post('responderCambioEquipo', {'accion': eleccion == 'revision' ? 'revision' : 'entiendo', 'mensaje': mensaje});
    s.datos = {...s.datos, 'avisoCambioEquipo': null, if (eleccion == 'revision') 'revisionCambio': a};
    if (eleccion == 'revision' && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listo. Un Pivot revisará tu cambio y te avisará.')));
    }
  } catch (_) {}
}
