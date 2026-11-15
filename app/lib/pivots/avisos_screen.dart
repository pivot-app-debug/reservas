import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/cargando.dart';
import '../core/fechas.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../equipo/equipo_modelos.dart';
import '../eventos/widgets_comunes.dart';
import '../finanzas/tesoreria_screen.dart' show elegirPersona;
import '../sesion/sesion.dart';

/// Avisos de los Pivots al equipo (Victor, 2026-11-14; antes en Mi Liga web):
/// ahora o programados, a todo el equipo o a algunas personas. Llegan por la
/// app y por la web. Abajo, quién tiene las notificaciones activas.
class AvisosScreen extends StatefulWidget {
  const AvisosScreen({super.key, required this.sesion});
  final Sesion sesion;

  @override
  State<AvisosScreen> createState() => _AvisosScreenState();
}

class _AvisosScreenState extends State<AvisosScreen> {
  List<Map<String, dynamic>>? _programados, _enviados;
  String? _error;

  Sesion get s => widget.sesion;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await s.api.post('adminAvisosProgramados', {'adminToken': s.adminToken, 'accion': 'listar'});
      if (r['exito'] == false) throw ApiException('${r['error']}');
      if (!mounted) return;
      setState(() {
        _programados = [for (final x in (r['programados'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        _enviados = [for (final x in (r['enviados'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'No se pudieron cargar los avisos. Revisa tu conexión.');
    }
  }

  void _aviso(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));

  String _cuando(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${Fechas.dia(d)} ${Fechas.corta(d)} · ${Fechas.hora(d)}';
  }

  String _destino(Object? d) => d is List ? '${d.length} ${d.length == 1 ? 'persona' : 'personas'}' : 'Todo el equipo';

  Future<void> _nuevo() async {
    final titulo = TextEditingController(), mensaje = TextEditingController();
    final gente = <Integrante>[];
    DateTime? cuando;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (h) => StatefulBuilder(
        builder: (h, set) {
          final p = h.pivot;
          final listo = titulo.text.trim().isNotEmpty && mensaje.text.trim().isNotEmpty;
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(h).bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Nuevo aviso', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titulo,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => set(() {}),
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  TextField(
                    controller: mensaje,
                    maxLength: 500,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => set(() {}),
                    decoration: const InputDecoration(labelText: 'Mensaje'),
                  ),
                  const SizedBox(height: 8),
                  const Text('¿A quién?', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(showCheckmark: false, label: const Text('Todo el equipo'), selected: gente.isEmpty, onSelected: (_) => set(gente.clear)),
                      for (final x in gente) InputChip(label: Text(x.nombreMostrar), onDeleted: () => set(() => gente.remove(x))),
                      ActionChip(
                        avatar: const Icon(Icons.person_add_alt_rounded, size: 18),
                        label: Text(gente.isEmpty ? 'Elegir personas' : 'Agregar'),
                        onPressed: () async {
                          final x = await elegirPersona(h, s, titulo: '¿A quién le llega?');
                          if (x != null && !gente.any((g) => g.username == x.username)) set(() => gente.add(x));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('¿Cuándo?', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(showCheckmark: false, label: const Text('Ahora'), selected: cuando == null, onSelected: (_) => set(() => cuando = null)),
                      ChoiceChip(
                        showCheckmark: false,
                        label: Text(cuando == null ? 'Programar' : _cuando(cuando!.toIso8601String())),
                        selected: cuando != null,
                        onSelected: (_) async {
                          final hoy = DateTime.now();
                          final f = await showDatePicker(context: h, firstDate: hoy, lastDate: hoy.add(const Duration(days: 365)), initialDate: cuando ?? hoy);
                          if (f == null || !h.mounted) return;
                          final t = await showTimePicker(context: h, initialTime: TimeOfDay.fromDateTime(cuando ?? hoy.add(const Duration(hours: 1))));
                          if (t == null) return;
                          final elegido = DateTime(f.year, f.month, f.day, t.hour, t.minute);
                          if (elegido.isBefore(DateTime.now().add(const Duration(minutes: 2)))) {
                            set(() => cuando = null);
                            return;
                          }
                          set(() => cuando = elegido);
                        },
                      ),
                    ],
                  ),
                  if (cuando != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Sale en un margen de 10 minutos desde esa hora.', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: listo ? () => Navigator.of(h).pop(true) : null, child: Text(cuando == null ? 'Enviar ahora' : 'Programar')),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final r = await s.api.post('adminEnviarAviso', {
        'adminToken': s.adminToken,
        'titulo': titulo.text.trim(),
        'mensaje': mensaje.text.trim(),
        'destino': jsonEncode(gente.isEmpty ? 'todos' : [for (final x in gente) x.username]),
        'enviarEn': ?cuando?.toUtc().toIso8601String(),
      });
      if (r['exito'] == false) throw ApiException('${r['error']}');
      _aviso(r['programado'] == true ? 'Aviso programado.' : 'Aviso enviado.');
    } catch (e) {
      _aviso(e is ApiException ? e.message : 'No se pudo enviar. Revisa tu conexión.');
    }
    await _cargar();
  }

  Future<void> _cancelar(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Cancelar este aviso?'),
        content: Text('"${a['titulo']}" ya no se enviará.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Cancelar aviso')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await s.api.post('adminAvisosProgramados', {'adminToken': s.adminToken, 'accion': 'cancelar', 'id': '${a['id']}'});
      if (r['exito'] == false) throw ApiException('${r['error']}');
      _aviso('Aviso cancelado.');
    } catch (e) {
      _aviso(e is ApiException ? e.message : 'No se pudo cancelar.');
    }
    await _cargar();
  }

  Widget _tarjeta(BuildContext context, Map<String, dynamic> a, {required bool programado}) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${a['titulo']}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${a['mensaje']}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: p.textoSecundario),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_destino(a['destino'])} · ${_cuando('${programado ? a['enviar_en'] : a['enviado_en']}')}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: programado ? p.marcaTexto : p.textoSecundario),
                    ),
                  ],
                ),
              ),
              if (programado) IconButton(tooltip: 'Cancelar aviso', onPressed: () => _cancelar(a), icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titulo(BuildContext context, String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(
      t,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.pivot.textoSecundario),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final prog = _programados, env = _enviados;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Avisos al equipo', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: prog == null || env == null
            ? Center(key: const ValueKey('c'), child: _error == null ? const PivotCargando(centrarEnPantalla: true) : Text(_error!))
            : RefreshIndicator(
                key: const ValueKey('l'),
                onRefresh: _cargar,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 96),
                  children: [
                    Text(
                      'Un mensaje para todo el equipo o para algunas personas, ahora o a una hora elegida. Llega por la app y por la web.',
                      style: TextStyle(fontSize: 14, height: 1.4, color: p.texto),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Material(
                        color: p.tarjeta,
                        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: Icon(Icons.notifications_active_outlined, color: p.marcaTexto),
                          title: const Text('Quién recibe avisos', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Notificaciones activas o apagadas de cada persona'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EstadoAvisosScreen(sesion: s))),
                        ),
                      ),
                    ),
                    if (prog.isNotEmpty) ...[_titulo(context, 'PROGRAMADOS'), for (final a in prog) _tarjeta(context, a, programado: true)],
                    _titulo(context, 'ENVIADOS'),
                    if (env.isEmpty) Text('Todavía no se envió ningún aviso desde la app.', style: TextStyle(color: p.textoSecundario)),
                    for (final a in env) _tarjeta(context, a, programado: false),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _nuevo, icon: const Icon(Icons.edit_rounded), label: const Text('Nuevo aviso')),
    );
  }
}

/// Quién tiene las notificaciones activas (app o web), para saber a quién
/// no le llegan los avisos.
class EstadoAvisosScreen extends StatefulWidget {
  const EstadoAvisosScreen({super.key, required this.sesion});
  final Sesion sesion;

  @override
  State<EstadoAvisosScreen> createState() => _EstadoAvisosScreenState();
}

class _EstadoAvisosScreenState extends State<EstadoAvisosScreen> {
  List<Map<String, dynamic>>? _personas;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.sesion.api.post('adminGetEstadoPush', {'adminToken': widget.sesion.adminToken});
      if (r['exito'] == false) throw ApiException('${r['error']}');
      if (mounted) setState(() => _personas = [for (final x in (r['personas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)]);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
    }
  }

  /// (llega, texto) según la app Android o el estado de la web.
  (bool, String) _estado(Map<String, dynamic> x) {
    if (x['app'] == true) return (true, 'Recibe en la app');
    return switch ('${x['pushEstado']}') {
      'activo' => (true, 'Recibe en la web'),
      'sin_permiso' => (false, 'No dio permiso en la web'),
      'bloqueado' => (false, 'Las bloqueó en el navegador'),
      _ => (false, 'No las activó'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _personas;
    final ordenadas = l == null ? null : ([...l]..sort((a, b) => (_estado(a).$1 ? 1 : 0).compareTo(_estado(b).$1 ? 1 : 0)));
    final llegan = l?.where((x) => _estado(x).$1).length ?? 0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Quién recibe avisos', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: ordenadas == null
            ? Center(key: const ValueKey('c'), child: _error == null ? const PivotCargando(centrarEnPantalla: true) : Text(_error!))
            : ListView(
                key: const ValueKey('l'),
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 32),
                children: [
                  Text(
                    '$llegan de ${ordenadas.length} personas reciben las notificaciones. Arriba, a quienes no les llegan.',
                    style: TextStyle(color: p.textoSecundario),
                  ),
                  const SizedBox(height: 8),
                  for (final x in ordenadas)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AvatarPersona(nombre: '${x['nombreDerby']}', foto: '${x['fotoPerfil'] ?? ''}', tamano: 40),
                      title: Text('${x['nombreDerby']}'),
                      subtitle: Text(_estado(x).$2),
                      trailing: Icon(
                        _estado(x).$1 ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                        color: _estado(x).$1 ? p.textoSecundario : p.marcaTexto,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
