import 'package:flutter/material.dart';

import '../core/fechas.dart';

/// Áreas de tareas (mismas que la web, js/tareas.js).
class AreaTarea {
  const AreaTarea(this.nombre, this.icono, this.seccion);
  final String nombre;
  final IconData icono;

  /// Clave del degradado en `PivotPaleta.seccion`.
  final String seccion;

  static const lista = [
    AreaTarea('Logística', Icons.local_shipping_outlined, 'logistica'),
    AreaTarea('Organización', Icons.event_note_outlined, 'organizacion'),
    AreaTarea('Redes Sociales y Comunicación', Icons.campaign_outlined, 'redes'),
    AreaTarea('Entrenamientos', Icons.sports_outlined, 'entrenamientos'),
    AreaTarea('Mantenimiento', Icons.build_outlined, 'mantenimiento'),
    AreaTarea('Recaudación', Icons.savings_outlined, 'recaudacion'),
    // Nuevas áreas (Victor, QA 2026-11-18). Reusan degradados ya definidos en el tema.
    AreaTarea('Finanzas', Icons.account_balance_wallet_outlined, 'cuota'),
    AreaTarea('Torneos', Icons.emoji_events_outlined, 'privacidad'),
    AreaTarea('Partidos', Icons.sports_score_outlined, 'reservas'),
    AreaTarea('Eventos', Icons.celebration_outlined, 'notificaciones'),
    AreaTarea('Viajes', Icons.luggage_outlined, 'logistica'),
    AreaTarea('Clases', Icons.school_outlined, 'identidad'),
    AreaTarea('Cursos', Icons.menu_book_outlined, 'mantenimiento'),
    AreaTarea('Otro', Icons.more_horiz, 'otro'),
  ];

  static AreaTarea de(String nombre) => lista.firstWhere((a) => a.nombre == nombre, orElse: () => lista.last);

  /// Una tarea puede tener varias áreas: se guardan en el mismo campo de
  /// texto separadas por coma ("Logística, Eventos"), sin cambiar la base.
  static List<String> separar(String texto) {
    final l = [
      for (final x in texto.split(','))
        if (x.trim().isNotEmpty) x.trim(),
    ];
    return l.isEmpty ? const ['Otro'] : l;
  }

  /// Une las áreas en el orden de [lista] (las que no están en la lista, al final).
  static String unir(Iterable<String> areas) {
    int orden(String a) {
      final i = lista.indexWhere((x) => x.nombre == a);
      return i < 0 ? lista.length : i;
    }

    final l = areas.toSet().toList()..sort((a, b) => orden(a).compareTo(orden(b)));
    return l.isEmpty ? 'Otro' : l.join(', ');
  }
}

class PersonaTarea {
  PersonaTarea(this.m);
  final Map<String, dynamic> m;
  String get username => '${m['nombre'] ?? ''}';
  String get nombreMostrar => '${m['nombreDerby'] ?? ''}'.trim().isNotEmpty ? '${m['nombreDerby']}'.trim() : username;
  String get foto => '${m['fotoPerfil'] ?? ''}';
  String get estado => '${m['estado'] ?? ''}';
  String get idAsignacion => '${m['idAsignacion'] ?? ''}';
  bool get enRevision => estado == 'pendiente_revision';
}

/// Tarea del tablero (o la de una asignación propia).
class Tarea {
  Tarea(this.m);
  final Map<String, dynamic> m;

  String get id => '${m['idTarea']}';
  String get titulo => '${m['titulo'] ?? ''}';
  String get notas => '${m['notas'] ?? ''}'.trim();
  String get area => '${m['area'] ?? ''}'.trim().isEmpty ? 'Otro' : '${m['area']}';
  List<String> get areas => AreaTarea.separar(area);
  AreaTarea get areaInfo => AreaTarea.de(areas.first);
  int get puntos => (m['puntos'] as num?)?.toInt() ?? 0;
  int get cupos => (m['cuposTotales'] as num?)?.toInt() ?? 1;
  int get libres => (m['cuposLibres'] as num?)?.toInt() ?? 0;
  String get estado => '${m['estado'] ?? ''}';
  bool get enBaul => estado == 'expirada';
  String? get idPlantilla => m['idPlantilla'] == null ? null : '${m['idPlantilla']}';
  bool get recurrente => idPlantilla != null;
  DateTime? get vence => _fecha(m['fechaVencimiento']);
  List<PersonaTarea> get personas => [
    for (final x in (m['asignados'] as List? ?? const []))
      if (x is Map<String, dynamic>) PersonaTarea(x),
  ];
  bool tiene(String username) => personas.any((p) => p.username.toLowerCase() == username.toLowerCase());
}

/// Una tarea que tomé (o me asignaron).
class MiTarea {
  MiTarea(this.m);
  final Map<String, dynamic> m;
  String get idAsignacion => '${m['idAsignacion']}';
  bool get enRevision => m['estado'] == 'pendiente_revision';

  /// Aprobada: se ve en el timeline el día en que se aprobó (Victor, 2026-11-16).
  bool get terminada => m['estado'] == 'aprobada';
  bool get rescate => m['esRescate'] == true;
  String get notaRechazo => '${m['notaRechazo'] ?? ''}'.trim();
  DateTime? get vence => _fecha(m['fechaVencimiento']);
  Tarea get tarea => Tarea(Map<String, dynamic>.from(m['tarea'] as Map));

  /// Días hasta el vencimiento (negativo: vencida). Null si no tiene fecha.
  int? get dias {
    final v = vence;
    if (v == null) return null;
    return v.difference(Fechas.hoy()).inDays;
  }
}

/// Plantilla de una tarea recurrente (admins).
class Recurrente {
  Recurrente(this.m);
  final Map<String, dynamic> m;
  String get id => '${m['idPlantilla']}';
  String get titulo => '${m['titulo'] ?? ''}';
  String get notas => '${m['notas'] ?? ''}';
  String get area => '${m['area'] ?? ''}'.trim().isEmpty ? 'Otro' : '${m['area']}';
  List<String> get areas => AreaTarea.separar(area);
  int get puntos => (m['puntos'] as num?)?.toInt() ?? 0;
  int get cupos => (m['cuposTotales'] as num?)?.toInt() ?? 1;
  bool get pausada => m['estado'] == 'pausada';
  String get frecuencia => '${m['frecuencia'] ?? 'Cada mes'}';
}

DateTime? _fecha(Object? v) {
  final s = '${v ?? ''}';
  if (s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
}

/// Texto del vencimiento: "Vence hoy", "Vence mañana", "Venció hace 2 días"…
String textoVence(DateTime? v) {
  if (v == null) return 'Sin fecha límite';
  final d = v.difference(Fechas.hoy()).inDays;
  if (d < -1) return 'Venció hace ${-d} días';
  if (d == -1) return 'Venció ayer';
  if (d == 0) return 'Vence hoy';
  if (d == 1) return 'Vence mañana';
  if (d < 7) return 'Vence en $d días';
  return 'Vence el ${v.day} ${Fechas.mes(v).substring(0, 3)}';
}

String textoPuntos(int n) => n == 1 ? '1 punto' : '$n puntos';

/// Estado de una persona en una tarea, para mostrarlo en listas.
String textoEstadoPersona(String estado) => switch (estado) {
  'aprobada' => 'Aprobada',
  'pendiente_revision' => 'En revisión',
  'iniciada' => 'En curso',
  'rechazada' => 'Rechazada',
  '' => '',
  _ => '${estado[0].toUpperCase()}${estado.substring(1).replaceAll('_', ' ')}',
};

/// Límite del título de una tarea (Victor, QA 2026-11-18: 120 era mucho).
const maxTituloTarea = 40;
