import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../eventos/widgets_comunes.dart' show AvatarPersona;
import '../sesion/sesion.dart';
import 'coach_screen.dart' show NombrarCoachScreen, elegirEquiposCoach, errorCoach;
import 'mi_estimado.dart';

/// Equipo técnico en Entreno (Victor, 2026-11-27): antes era un botón de la
/// barra. Un carrusel con cada persona del equipo técnico y los equipos que
/// entrena. Pivots y el mismo equipo técnico suman gente con «+» y cambian
/// equipos con los tres puntos; aprobar pedidos y quitar, solo Pivots. Quien
/// entrena ve también lo que lleva este mes.
class EquipoTecnicoSeccion extends StatefulWidget {
  const EquipoTecnicoSeccion({super.key, required this.sesion});
  final Sesion sesion;

  @override
  State<EquipoTecnicoSeccion> createState() => _EquipoTecnicoSeccionState();
}

class _EquipoTecnicoSeccionState extends State<EquipoTecnicoSeccion> {
  List<Map<String, dynamic>>? _l;
  Sesion get s => widget.sesion;
  bool get _pivot => s.esAdmin && s.adminToken != null;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar([Map<String, Object?> q = const {'accion': 'listar'}]) async {
    try {
      final Map<String, dynamic> r = await s.api.post('adminCoaches', {if (_pivot) 'adminToken': s.adminToken, ...q});
      if (r['exito'] == false) throw Exception('${r['error']}');
      if (mounted) setState(() => _l = [for (final c in (r['coaches'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)]);
    } catch (e) {
      if (mounted && q['accion'] != 'listar') ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCoach(e))));
      if (mounted && _l == null) setState(() => _l = const []);
    }
  }

  Future<void> _sumar() async {
    final elegida = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => NombrarCoachScreen(sesion: s, coaches: _l ?? const []),
      ),
    );
    if (elegida == null || !mounted) return;
    final eq = await elegirEquiposCoach(context, s, const []);
    if (eq == null) return;
    await _cargar({'accion': 'nombrar', 'username': elegida['nombre'], 'equipos': jsonEncode(eq)});
  }

  Future<void> _dejar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Dejar el equipo técnico?'),
        content: const Text('Dejas de ver las herramientas de entrenamiento. Las evaluaciones y notas que hiciste se conservan.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Dejarlo')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await s.api.post('dejarDeSerCoach', {});
      if (r['exito'] == false) throw Exception('${r['error']}');
      await s.cargarCoach();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya no estás en el equipo técnico.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorCoach(e))));
    }
  }

  Future<void> _opciones(Map<String, dynamic> c) async {
    final propio = '${c['username']}' == s.nombre;
    if (!_pivot && propio) return _dejar();
    final pendiente = c['estado'] == 'pendiente';
    final a = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (h) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('${c['nombre']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            if (pendiente && _pivot)
              ListTile(leading: const Icon(Icons.check_rounded), title: const Text('Aprobar'), onTap: () => Navigator.of(h).pop('aprobar')),
            if (!pendiente)
              ListTile(leading: const Icon(Icons.groups_outlined), title: const Text('Cambiar equipos'), onTap: () => Navigator.of(h).pop('equipos')),
            if (_pivot)
              ListTile(
                leading: Icon(Icons.person_remove_outlined, color: h.pivot.marcaTexto),
                title: Text(
                  pendiente ? 'Rechazar el pedido' : (propio ? 'Dejar el equipo técnico' : 'Quitar del equipo técnico'),
                  style: TextStyle(color: h.pivot.marcaTexto),
                ),
                onTap: () => Navigator.of(h).pop(pendiente ? 'rechazar' : 'quitar'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (a == null || !mounted) return;
    if (a == 'aprobar' || a == 'equipos') {
      final eq = await elegirEquiposCoach(context, s, [for (final e in (c['equipos'] as List? ?? const [])) '$e']);
      if (eq == null) return;
      await _cargar({'accion': a, 'username': c['username'], 'equipos': jsonEncode(eq)});
    } else {
      await _cargar({'accion': a, 'username': c['username']});
    }
    if (propio) await s.cargarCoach();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _l;
    if (!_pivot && !s.esCoach) return const SizedBox.shrink();
    final (degradado, sobre) = PivotPaleta.seccion('entrenamientos', Theme.of(context).brightness);
    Widget tarjeta({required Widget hijo, VoidCallback? alTocar}) => SizedBox(
      width: 150,
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta + 4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: alTocar, child: hijo),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
          child: Text(
            'EQUIPO TÉCNICO',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: l == null
              ? const SizedBox(key: ValueKey('c'), height: 168)
              : SizedBox(
                  key: const ValueKey('l'),
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: l.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      if (i == l.length) {
                        return tarjeta(
                          alTocar: _sumar,
                          hijo: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(gradient: degradado, shape: BoxShape.circle),
                                child: Icon(Icons.add_rounded, color: sobre, size: 28),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Sumar a alguien',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                              ),
                            ],
                          ),
                        );
                      }
                      final c = l[i];
                      final equipos = [for (final e in (c['equipos'] as List? ?? const [])) '$e'];
                      final pendiente = c['estado'] == 'pendiente';
                      final conMenu = _pivot || !pendiente;
                      // Bench y otras funciones del equipo técnico (2026-11-27).
                      final funciones = [
                        for (final f in (c['funciones'] as List? ?? const []))
                          if ('$f' != 'Coach') '$f',
                      ];
                      return tarjeta(
                        alTocar: conMenu ? () => _opciones(c) : null,
                        hijo: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                              child: Column(
                                children: [
                                  AvatarPersona(nombre: '${c['nombre']}', foto: '${c['foto'] ?? ''}', tamano: 52),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${c['nombre']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: FontWeight.w800, color: p.texto),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pendiente ? 'Pidió sumarse' : [...funciones, equipos.isEmpty ? 'Todos los equipos' : equipos.join(' · ')].join(' · '),
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, color: pendiente ? p.marcaTexto : p.textoSecundario),
                                  ),
                                ],
                              ),
                            ),
                            if (conMenu)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  tooltip: 'Opciones',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(Icons.more_vert_rounded, size: 20, color: p.textoSecundario),
                                  onPressed: () => _opciones(c),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        // Lo que lleva este mes quien entrena (antes en Mi perfil).
        if (s.esCoach)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: MiEstimado(sesion: s),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}
