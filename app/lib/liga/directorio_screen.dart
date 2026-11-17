import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ajustes/componentes.dart';
import '../core/api.dart';
import '../core/esqueleto.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../sesion/sesion.dart';

/// "Ligas en Pivot" (Victor, 2026-11-17): directorio para Pivots con la
/// información básica de cada liga y lo que cada una decide mostrar
/// (contacto, comunidad). Desde aquí se invitará a partidos y torneos.

AppBar _barra(String t) => AppBar(
  backgroundColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  flexibleSpace: const Vidrio(child: SizedBox.expand()),
  title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
);

String _err(Object e) => e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.';

class DirectorioLigasScreen extends StatefulWidget {
  const DirectorioLigasScreen({super.key, required this.sesion});
  final Sesion sesion;
  @override
  State<DirectorioLigasScreen> createState() => _DirectorioLigasScreenState();
}

class _DirectorioLigasScreenState extends State<DirectorioLigasScreen> {
  List<Map<String, dynamic>>? _l;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.sesion.api.get('getDirectorioLigas', {'adminToken': widget.sesion.adminToken});
      if (r['exito'] == false) throw ApiException('${r['error']}');
      if (mounted) setState(() => _l = [for (final x in (r['ligas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)]);
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
  }

  void _ver(Map<String, dynamic> l) {
    final contacto = Map<String, dynamic>.from(l['contacto'] as Map? ?? const {});
    final comunidad = [for (final c in (l['comunidad'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l['nombre']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text([l['ciudad'], l['pais']].where((x) => '${x ?? ''}'.isNotEmpty).join(', '), style: TextStyle(color: c.pivot.textoSecundario)),
              const SizedBox(height: 10),
              if (contacto.isEmpty && comunidad.isEmpty) Text('Esta liga todavía no compartió su contacto.', style: TextStyle(color: c.pivot.textoSecundario)),
              for (final e in contacto.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(switch (e.key) {
                    'correo' => Icons.mail_outline_rounded,
                    'telefono' => Icons.phone_outlined,
                    'instagram' => Icons.camera_alt_outlined,
                    _ => Icons.public_rounded,
                  }),
                  title: Text('${e.value}'),
                  onTap: () {
                    final v = '${e.value}';
                    final u = switch (e.key) {
                      'correo' => 'mailto:$v',
                      'telefono' => 'tel:$v',
                      'instagram' => 'https://instagram.com/${v.replaceAll('@', '')}',
                      _ => v.startsWith('http') ? v : 'https://$v',
                    };
                    launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
                  },
                ),
              for (final x in comunidad)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.groups_outlined),
                  title: Text('${x['nombre'] ?? x['red']}'),
                  onTap: () => launchUrl(Uri.parse('${x['url']}'), mode: LaunchMode.externalApplication),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final q = _q.trim().toLowerCase();
    final l = _l?.where((x) => q.isEmpty || '${x['nombre']} ${x['ciudad']} ${x['pais']}'.toLowerCase().contains(q)).toList();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _barra('Ligas en Pivot'),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: l == null
            ? (_error == null ? const Esqueleto(key: ValueKey('c')) : Center(key: const ValueKey('e'), child: Text(_error!)))
            : ListView(
                key: const ValueKey('l'),
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 32 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Material(
                    color: p.suave,
                    borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(Icons.storefront_outlined, color: p.sobreSuave),
                      title: Text(
                        'Tu liga en el directorio',
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.sobreSuave),
                      ),
                      subtitle: Text('Qué ven las otras ligas: contacto y comunidad', style: TextStyle(color: p.sobreSuave)),
                      trailing: Icon(Icons.chevron_right_rounded, color: p.sobreSuave),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MiLigaDirectorioScreen(sesion: widget.sesion)));
                        _cargar();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _q = v),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar liga o ciudad'),
                  ),
                  const SizedBox(height: 8),
                  for (final x in l)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: p.suave,
                        backgroundImage: '${x['logo'] ?? ''}'.isNotEmpty ? NetworkImage('${x['logo']}') : null,
                        child: '${x['logo'] ?? ''}'.isNotEmpty ? null : Icon(Icons.shield_outlined, color: p.sobreSuave),
                      ),
                      title: Text('${x['nombre']}${x['mia'] == true ? ' (tu liga)' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(['Roller derby', x['ciudad'], x['pais']].where((v) => '${v ?? ''}'.isNotEmpty).join(' · ')),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _ver(x),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Lo que tu liga muestra en el directorio.
class MiLigaDirectorioScreen extends StatefulWidget {
  const MiLigaDirectorioScreen({super.key, required this.sesion});
  final Sesion sesion;
  @override
  State<MiLigaDirectorioScreen> createState() => _MiLigaDirectorioScreenState();
}

class _MiLigaDirectorioScreenState extends State<MiLigaDirectorioScreen> {
  bool? _visible;
  bool _comunidad = false;
  final _c = {
    for (final k in ['ciudad', 'correo', 'telefono', 'web', 'instagram']) k: TextEditingController(),
  };
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    widget.sesion.api.get('adminMiLigaDirectorio', {'adminToken': widget.sesion.adminToken}).then((r) {
      final l = Map<String, dynamic>.from(r['liga'] as Map? ?? const {});
      final co = Map<String, dynamic>.from(l['contacto'] as Map? ?? const {});
      if (!mounted) return;
      setState(() {
        _visible = l['visible'] != false;
        _comunidad = l['mostrar_comunidad'] == true;
        _c['ciudad']!.text = '${l['ciudad'] ?? ''}';
        for (final k in ['correo', 'telefono', 'web', 'instagram']) {
          _c[k]!.text = '${co[k] ?? ''}';
        }
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await widget.sesion.api.post('adminMiLigaDirectorio', {
        'adminToken': widget.sesion.adminToken,
        'accion': 'guardar',
        'visible': _visible ?? true,
        'mostrarComunidad': _comunidad,
        'ciudad': _c['ciudad']!.text.trim(),
        'contacto': {
          for (final k in ['correo', 'telefono', 'web', 'instagram'])
            if (_c[k]!.text.trim().isNotEmpty) k: _c[k]!.text.trim(),
        },
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _visible;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _barra('Tu liga en el directorio'),
      body: v == null
          ? const Esqueleto(forma: FormaEsqueleto.ajustes)
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 32 + MediaQuery.paddingOf(context).bottom),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aparecer en Ligas en Pivot', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Con nombre, logo, deporte, ciudad y país.'),
                  value: v,
                  onChanged: (x) => setState(() => _visible = x),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar la comunidad', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Los enlaces de Comunidad (grupo, redes) que ya cargaste.'),
                  value: _comunidad,
                  onChanged: (x) => setState(() => _comunidad = x),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _c['ciudad'],
                  decoration: const InputDecoration(labelText: 'Ciudad'),
                ),
                const SizedBox(height: 14),
                const Text('Contacto (opcional)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: _c['correo'],
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _c['telefono'],
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono o WhatsApp'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _c['instagram'],
                  decoration: const InputDecoration(labelText: 'Instagram'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _c['web'],
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Página web'),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _guardando ? null : _guardar, child: const Text('Guardar')),
              ],
            ),
    );
  }
}

/// Panel del equipo de Pivot: todas las ligas creadas.
class PanelPivotScreen extends StatefulWidget {
  const PanelPivotScreen({super.key, required this.sesion});
  final Sesion sesion;
  @override
  State<PanelPivotScreen> createState() => _PanelPivotScreenState();
}

class _PanelPivotScreenState extends State<PanelPivotScreen> {
  List<Map<String, dynamic>>? _l;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.sesion.api.get('superLigas', {'adminToken': widget.sesion.adminToken}).then((r) {
      if (!mounted) return;
      if (r['exito'] == false) return setState(() => _error = '${r['error']}');
      setState(() => _l = [for (final x in (r['ligas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)]);
    }, onError: (Object e) => mounted ? setState(() => _error = _err(e)) : null);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _l;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _barra('Panel de Pivot'),
      body: l == null
          ? (_error == null ? const Esqueleto() : Center(child: Text(_error!)))
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 32 + MediaQuery.paddingOf(context).bottom),
              children: [
                Text(
                  '${l.length} ${l.length == 1 ? 'liga' : 'ligas'} · ${l.fold<int>(0, (a, x) => a + ((x['personas'] as num?) ?? 0).toInt())} personas',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.texto),
                ),
                const SizedBox(height: 10),
                for (final x in l)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${x['nombre']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      [
                        [x['ciudad'], x['pais']].where((v) => '${v ?? ''}'.isNotEmpty).join(', '),
                        '${x['personas']} personas',
                        '${x['marcas30']} marcas de asistencia en 30 días',
                        'creada ${'${x['creada_en'] ?? ''}'.split('T').first}',
                        if (x['visible'] == false) 'oculta',
                      ].where((v) => v.isNotEmpty).join(' · '),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Después del camino rápido: "¿Armamos tus equipos y reglas?". Omitir no
/// vuelve a preguntar; Recordar más tarde, a los 5 días.
class SugerenciaReglas {
  static const _clave = 'liga.sugerir_reglas';
  static const _hasta = 'liga.sugerir_reglas_hasta';

  static Future<void> marcarPendiente() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_clave, true);
  }

  static Future<void> siCorresponde(BuildContext context, Sesion s, {required VoidCallback abrir}) async {
    if (!s.esAdmin) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_clave) != true) return;
    if (DateTime.now().millisecondsSinceEpoch < (prefs.getInt(_hasta) ?? 0) || !context.mounted) return;
    final r = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('¿Armamos tus equipos y reglas?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Tu liga está con valores por defecto. En Mi Liga ajustas equipos, cuota, entrenamientos y reglas en unos minutos.',
                style: TextStyle(height: 1.4, color: c.pivot.textoSecundario),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.of(c).pop('si'), child: const Text('Vamos')),
              TextButton(onPressed: () => Navigator.of(c).pop('luego'), child: const Text('Recordar más tarde')),
              TextButton(onPressed: () => Navigator.of(c).pop('omitir'), child: const Text('Omitir')),
            ],
          ),
        ),
      ),
    );
    if (r == 'luego') {
      await prefs.setInt(_hasta, DateTime.now().add(const Duration(days: 5)).millisecondsSinceEpoch);
    } else if (r == 'si' || r == 'omitir') {
      await prefs.remove(_clave);
      if (r == 'si') abrir();
    }
  }
}

/// Lista de primeros pasos en Mi Liga para una liga recién creada.
class PrimerosPasos extends StatefulWidget {
  const PrimerosPasos({super.key, required this.pasos});

  /// (clave, ícono, texto, al tocar).
  final List<(String, IconData, String, VoidCallback)> pasos;

  static Future<void> activar() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('liga.primeros_pasos', true);
  }

  @override
  State<PrimerosPasos> createState() => _PrimerosPasosState();
}

class _PrimerosPasosState extends State<PrimerosPasos> {
  bool _activo = false;
  Set<String> _hechos = {};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _activo = p.getBool('liga.primeros_pasos') == true;
        _hechos = {...?p.getStringList('liga.primeros_pasos_hechos')};
      });
    });
  }

  Future<void> _marcar(String k) async {
    final p = await SharedPreferences.getInstance();
    setState(() => _hechos.add(k));
    await p.setStringList('liga.primeros_pasos_hechos', _hechos.toList());
    if (widget.pasos.every((x) => _hechos.contains(x.$1))) await p.remove('liga.primeros_pasos');
  }

  Future<void> _ocultar() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('liga.primeros_pasos');
    if (mounted) setState(() => _activo = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final visible = _activo && !widget.pasos.every((x) => _hechos.contains(x.$1));
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      alignment: Alignment.topCenter,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Primeros pasos',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.texto),
                        ),
                      ),
                      TextButton(onPressed: _ocultar, child: const Text('Ocultar')),
                    ],
                  ),
                  for (final x in widget.pasos)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        _hechos.contains(x.$1) ? Icons.check_circle_rounded : x.$2,
                        color: _hechos.contains(x.$1) ? p.marcaTexto : p.textoSecundario,
                      ),
                      title: Text(x.$3, style: TextStyle(fontSize: 15, decoration: _hechos.contains(x.$1) ? TextDecoration.lineThrough : null)),
                      onTap: () {
                        _marcar(x.$1);
                        x.$4();
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

/// Fila "Ligas en Pivot" (y el panel para el equipo de Pivot) en Mi Liga.
class FilasDirectorio extends StatefulWidget {
  const FilasDirectorio({super.key, required this.sesion});
  final Sesion sesion;
  @override
  State<FilasDirectorio> createState() => _FilasDirectorioState();
}

class _FilasDirectorioState extends State<FilasDirectorio> {
  bool _duenx = false;

  @override
  void initState() {
    super.initState();
    widget.sesion.api.get('esDuenxPivot', {'adminToken': widget.sesion.adminToken}).then((r) {
      if (mounted && r['duenx'] == true) setState(() => _duenx = true);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) => GrupoAjustes(
    filas: [
      FilaAjuste(
        icono: Icons.travel_explore_rounded,
        seccion: 'liga',
        titulo: 'Ligas en Pivot',
        valor: 'Otras ligas, su contacto y lo que muestra la tuya',
        alTocar: () => SubAjustes.abrir(context, DirectorioLigasScreen(sesion: widget.sesion)),
      ),
      if (_duenx)
        FilaAjuste(
          icono: Icons.insights_rounded,
          seccion: 'liga',
          titulo: 'Panel de Pivot',
          valor: 'Todas las ligas creadas',
          alTocar: () => SubAjustes.abrir(context, PanelPivotScreen(sesion: widget.sesion)),
        ),
    ],
  );
}
