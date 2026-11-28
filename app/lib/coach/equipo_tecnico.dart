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
  /// Lo último cargado: al volver a verse al hacer scroll no parpadea (QA 2026-11-28).
  static List<Map<String, dynamic>>? _ultima;
  List<Map<String, dynamic>>? _l = _ultima;
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
      _ultima = [for (final c in (r['coaches'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
      if (mounted) setState(() => _l = _ultima);
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

  /// Tocar a alguien abre su subsección (QA 2026-11-27: en lugar de los tres
  /// puntos y la hoja de abajo).
  Future<void> _abrir(Map<String, dynamic> c) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PersonaTecnicaScreen(sesion: s, c: c, pivot: _pivot, alAccion: (a) => _hacer(c, a)),
      ),
    );
  }

  /// Ejecuta una acción sobre alguien del equipo técnico; true si se hizo.
  Future<bool> _hacer(Map<String, dynamic> c, String a) async {
    final propio = '${c['username']}' == s.nombre;
    if (a == 'dejar') {
      await _dejar();
      await _cargar();
      return !s.esCoach;
    }
    if (a == 'aprobar' || a == 'equipos') {
      final eq = await elegirEquiposCoach(context, s, [for (final e in (c['equipos'] as List? ?? const [])) '$e']);
      if (eq == null) return false;
      await _cargar({'accion': a, 'username': c['username'], 'equipos': jsonEncode(eq)});
    } else {
      await _cargar({'accion': a, 'username': c['username']});
    }
    if (propio) await s.cargarCoach();
    return true;
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
                                'Agregar',
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
                      final conMenu = _pivot || !pendiente || '${c['username']}' == s.nombre;
                      return tarjeta(
                        alTocar: conMenu ? () => _abrir(c) : null,
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
                                    pendiente ? 'Pidió sumarse' : (equipos.isEmpty ? 'Todos los equipos' : equipos.join(' · ')),
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, color: pendiente ? p.marcaTexto : p.textoSecundario),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// Subsección de alguien del equipo técnico (QA 2026-11-27): sus equipos y
/// funciones, lo que lleva este mes si eres tú, y lo que se puede hacer.
class _PersonaTecnicaScreen extends StatefulWidget {
  const _PersonaTecnicaScreen({required this.sesion, required this.c, required this.pivot, required this.alAccion});
  final Sesion sesion;
  final Map<String, dynamic> c;
  final bool pivot;
  final Future<bool> Function(String accion) alAccion;

  @override
  State<_PersonaTecnicaScreen> createState() => _PersonaTecnicaScreenState();
}

class _PersonaTecnicaScreenState extends State<_PersonaTecnicaScreen> {
  bool _ocupado = false;

  Future<void> _hacer(String a, {bool salir = false}) async {
    setState(() => _ocupado = true);
    final ok = await widget.alAccion(a);
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (ok && salir) Navigator.of(context).pop();
    if (ok && !salir) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final c = widget.c;
    final s = widget.sesion;
    final propio = '${c['username']}' == s.nombre;
    final pendiente = c['estado'] == 'pendiente';
    final equipos = [for (final e in (c['equipos'] as List? ?? const [])) '$e'];
    Widget fila(IconData i, String t, String sub) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(i, color: p.textoSecundario),
      title: Text(
        t,
        style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
      ),
      subtitle: Text(sub, style: TextStyle(color: p.textoSecundario)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Equipo técnico')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          Center(
            child: AvatarPersona(nombre: '${c['nombre']}', foto: '${c['foto'] ?? ''}', tamano: 88),
          ),
          const SizedBox(height: 10),
          Text(
            '${c['nombre']}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: p.texto),
          ),
          if (pendiente)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Pidió sumarse al equipo técnico${'${c['mensaje'] ?? ''}'.isEmpty ? '' : ': «${c['mensaje']}»'}',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.marcaTexto),
              ),
            ),
          const SizedBox(height: 16),
          // Lo que lleva este mes, solo si eres tú (antes en Mi perfil).
          if (propio && s.esCoach) ...[MiEstimado(sesion: s), const SizedBox(height: 12)],
          if (!pendiente) fila(Icons.groups_outlined, 'Equipos', equipos.isEmpty ? 'Todos los equipos' : equipos.join(', ')),
          // Sin «Funciones» (Victor, 2026-11-28): los roles ya se ven en Liga.
          const SizedBox(height: 16),
          if (pendiente && widget.pivot)
            FilledButton.icon(onPressed: _ocupado ? null : () => _hacer('aprobar'), icon: const Icon(Icons.check_rounded), label: const Text('Aprobar')),
          if (!pendiente)
            OutlinedButton.icon(
              onPressed: _ocupado ? null : () => _hacer('equipos'),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Cambiar equipos'),
            ),
          const SizedBox(height: 8),
          if (propio && !pendiente)
            TextButton.icon(
              onPressed: _ocupado ? null : () => _hacer('dejar', salir: true),
              icon: Icon(Icons.logout_rounded, color: p.marcaTexto),
              label: Text('Dejar el equipo técnico', style: TextStyle(color: p.marcaTexto)),
            )
          else if (widget.pivot)
            TextButton.icon(
              onPressed: _ocupado ? null : () => _hacer(pendiente ? 'rechazar' : 'quitar', salir: true),
              icon: Icon(Icons.person_remove_outlined, color: p.marcaTexto),
              label: Text(pendiente ? 'Rechazar el pedido' : 'Quitar del equipo técnico', style: TextStyle(color: p.marcaTexto)),
            ),
        ],
      ),
    );
  }
}
