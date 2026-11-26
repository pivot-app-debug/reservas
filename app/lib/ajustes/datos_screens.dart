import '../core/deporte.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../eventos/widgets_comunes.dart' show AvatarPersona;
import '../core/api.dart';
import '../core/esqueleto.dart';
import '../core/paises.dart';
import '../core/tema.dart';
import '../equipo/equipo_repo.dart';
import '../equipo/roles_screen.dart';
import '../sesion/sesion.dart';
import 'ajustes_screen.dart';
import '../equipo/inventario_asistentes.dart';
import '../equipo/inventario_modelos.dart';
import 'campos.dart';
import 'componentes.dart';
import '../core/vidrio.dart';

// ─── Mis datos ───────────────────────────────────────────────────────────

/// Lo que ve el resto del equipo, editable desde tu propia ficha en Equipo
/// (como en la web; Victor, 2026-11-07). Incluye Mi equipamiento.
class MiPerfilEditable extends StatelessWidget {
  const MiPerfilEditable({super.key, required this.sesion});
  final Sesion sesion;

  @override
  Widget build(BuildContext context) {
    final equipo = EquipoRepo.de(sesion);
    // Sin esto, con la caché de Equipo vacía la fila se veía sin roles
    // (Victor, 2026-11-14). `cargar()` no hace nada si ya está cargado.
    if (equipo.personas == null) unawaited(equipo.cargar());
    final s = sesion;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final tel = valorDe(s, 'telefono');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GrupoAjustes(
              filas: [
                // Foto como una fila más, sin avatar arriba (Victor, 2026-11-17).
                FilaAjuste(
                  icono: Icons.add_a_photo_rounded,
                  seccion: 'foto',
                  titulo: 'Foto de perfil',
                  valor: s.fotoPerfil.isEmpty ? 'Agrega una foto' : 'Toca para cambiarla',
                  pendiente: s.fotoPerfil.isEmpty,
                  derecha: s.fotoPerfil.isEmpty ? null : AvatarPersona(nombre: s.nombreMostrar, foto: s.fotoPerfil, tamano: 36),
                  alTocar: () => cambiarFoto(context, s),
                ),
                FilaAjuste(
                  icono: Icons.badge_outlined,
                  seccion: 'nombre',
                  titulo: Deporte.apodo,
                  valor: valorDe(s, 'nombreDerby'),
                  alTocar: () => editarCampo(context, s, 'nombreDerby', Deporte.apodo, maxLength: 40),
                ),
                FilaAjuste(
                  icono: Icons.tag_rounded,
                  seccion: 'numero',
                  titulo: Deporte.numero,
                  valor: valorDe(s, 'numeroDerby'),
                  alTocar: () => editarCampo(context, s, 'numeroDerby', Deporte.numero, maxLength: 4),
                ),
                FilaAjuste(
                  icono: Icons.record_voice_over_outlined,
                  seccion: 'pronombres',
                  titulo: 'Pronombres',
                  valor: valorDe(s, 'pronombres'),
                  alTocar: () =>
                      elegirCampo(context, s, 'pronombres', 'Pronombres', const ['Ella', 'Él', 'Elle'], multi: true, ayuda: 'Elige todos los que apliquen.'),
                ),
                ListenableBuilder(
                  listenable: equipo,
                  builder: (context, _) {
                    // Fuente: Equipo; si aún no llegó, los de tu propia ficha.
                    final roles =
                        equipo.persona(s.nombre ?? '')?.roles ??
                        [
                          for (final r in (s.datos['roles'] is List ? s.datos['roles'] as List : const []))
                            if ('$r' != 'No definido') '$r',
                        ];
                    return FilaAjuste(
                      icono: Icons.shield_outlined,
                      seccion: 'roles',
                      titulo: 'Roles en el equipo',
                      valor: roles.join(', '),
                      alTocar: () async {
                        final v = await elegirOpciones(
                          context,
                          titulo: 'Roles en el equipo',
                          opciones: equipo.roles,
                          valor: roles.join(', '),
                          multi: true,
                          // Pivots: editar el catálogo desde aquí (Victor, 2026-11-13).
                          secundaria: s.esAdmin && s.adminToken != null
                              ? (
                                  'Agregar o editar roles',
                                  () {
                                    Navigator.of(context).pop();
                                    SubAjustes.abrir(context, RolesScreen(repo: equipo));
                                  },
                                )
                              : null,
                        );
                        if (v == null || !context.mounted) return;
                        final ok = await guardarCampos(context, s, {'roles': v});
                        if (ok) await equipo.cargar(forzar: true);
                      },
                    );
                  },
                ),
                FilaAjuste(
                  icono: Icons.phone_outlined,
                  seccion: 'telefono',
                  titulo: 'Teléfono',
                  valor: Paises.telefono(valorDe(s, 'prefijo'), tel),
                  alTocar: () => editarTelefono(context, s, 'prefijo', 'telefono', 'Teléfono'),
                ),
                FilaAjuste(
                  icono: Icons.event_outlined,
                  seccion: 'ingreso',
                  titulo: 'Entraste al equipo',
                  valor: fechaLarga(s.datos['fechaIngreso']),
                  alTocar: () => elegirFechaCampo(context, s, 'fechaIngreso', ayuda: 'Cuándo entraste al equipo', desde: DateTime(2010)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─── Mi equipamiento ─────────────────────────────────────────────────────

/// Patines y protecciones del club. Si alguien de Quindes elige equipamiento
/// del club, primero ve el aviso (Victor, 2026-11-07).
class EquipamientoScreen extends StatefulWidget {
  const EquipamientoScreen({super.key, required this.sesion, this.conPedido = true});
  final Sesion sesion;

  /// Mostrar "¿Necesitas equipamiento por un tiempo?" (no al entrar desde Inventario).
  final bool conPedido;

  @override
  State<EquipamientoScreen> createState() => _EquipamientoScreenState();
}

class _EquipamientoScreenState extends State<EquipamientoScreen> {
  // Listas de la liga para entrenar (Victor, 2026-11-17): cada liga arma las
  // suyas en el Inventario. Por cada una: propio o de la liga (con talla o
  // piezas si tiene).
  List<Map<String, dynamic>>? _listas;
  Map<String, String> _orig = const {};
  final Map<String, String> _usa = {};
  List<String> _propio = const [];
  String _equipo = '';
  String? _error;
  bool _guardando = false;

  Sesion get s => widget.sesion;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await s.api.get('getMiEquipoLiga');
      if (r['exito'] == false) throw ApiException('${r['error']}');
      final mio = {for (final e in ((r['mio'] as Map?) ?? const {}).entries) '${e.key}': '${e.value ?? ''}'};
      if (!mounted) return;
      setState(() {
        _listas = [for (final l in (r['listas'] as List? ?? const [])) Map<String, dynamic>.from(l as Map)];
        _orig = mio;
        _usa
          ..clear()
          ..addAll(mio);
        _propio = [for (final x in (r['propio'] as List? ?? const [])) '$x'];
        _equipo = '${r['equipo'] ?? ''}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
    }
  }

  bool get _usaLiga => _usa.isNotEmpty;

  bool get _cambio => _usa.length != _orig.length || _usa.entries.any((e) => _orig[e.key] != e.value);

  /// Listas que tu equipo pide propias y marcaste "de la liga".
  List<String> get _chocan => [
    for (final l in _listas ?? const <Map<String, dynamic>>[])
      if (_propio.contains('${l['id']}') && _usa.containsKey('${l['id']}')) '${l['nombre']}'.toLowerCase(),
  ];

  Future<void> _guardar() async {
    for (final l in _listas ?? const <Map<String, dynamic>>[]) {
      final id = '${l['id']}';
      if (_usa.containsKey(id) && l['tipo'] == 'tallas' && (_usa[id] ?? '').isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Elige tu talla de ${'${l['nombre']}'.toLowerCase()}.')));
        return;
      }
    }
    final chocan = _chocan.where((x) => !_orig.keys.any((k) => _listas!.any((l) => '${l['id']}' == k && '${l['nombre']}'.toLowerCase() == x))).toList();
    if (chocan.isNotEmpty && _equipo.isNotEmpty) {
      final si = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Dejas $_equipo'),
          content: Text(
            '$_equipo pide tener propio: ${chocan.join(', ')}. Con eso de la liga pasas al equipo de abajo y no vuelves hasta tenerlo propio.\n\n'
            'Si es por un tiempo (se te rompió o lo estás lavando), mejor pídelo: un Pivot decide por cuánto tiempo y no cambias de equipo.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop('pedir'), child: const Text('Pedir por un tiempo')),
            FilledButton(onPressed: () => Navigator.of(c).pop('guardar'), child: const Text('Guardar igual')),
          ],
        ),
      );
      if (si == 'pedir' && mounted) {
        await _pedirUso();
        return;
      }
      if (si != 'guardar' || !mounted) return;
    }
    setState(() => _guardando = true);
    String? nuevo;
    final ok = await guardarConAviso(context, () async {
      nuevo = await s.guardarEquipoLiga(Map.of(_usa));
    }, ok: 'Equipamiento guardado');
    if (!mounted) return;
    setState(() {
      _guardando = false;
      if (ok) _orig = Map.of(_usa);
    });
    if (ok && nuevo != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Equipamiento guardado. Ahora estás en $nuevo.')));
      EquipoRepo.de(s).cargar(forzar: true);
    }
  }

  /// Pedir equipamiento del equipo por un tiempo (Victor, 2026-11-13).
  Future<void> _pedirUso() async {
    final repo = InventarioRepo(s);
    try {
      await repo.cargar();
    } catch (_) {}
    if (!mounted) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrestamoAsistente(repo: repo, equipo: EquipoRepo.de(s), modo: ModoPrestamo.uso),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido enviado. Un Pivot decidirá por cuánto tiempo.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(
        t,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: p.textoSecundario),
      ),
    );
    const dur = Duration(milliseconds: 260);
    final listas = _listas;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Mi equipamiento', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AnimatedSwitcher(
        duration: dur,
        child: listas == null
            ? (_error == null ? const Esqueleto(key: ValueKey('c')) : Center(key: const ValueKey('e'), child: Text(_error!)))
            : ListView(
                key: const ValueKey('l'),
                padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 120 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (listas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text(
                        'Tu liga todavía no presta equipamiento para entrenar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.textoSecundario),
                      ),
                    ),
                  for (final l in listas) ...[
                    titulo('${l['nombre']}'.toUpperCase()),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Propio')),
                        ButtonSegment(value: true, label: Text('De la liga')),
                      ],
                      selected: {_usa.containsKey('${l['id']}')},
                      onSelectionChanged: (x) => setState(() => x.first ? _usa['${l['id']}'] = _orig['${l['id']}'] ?? '' : _usa.remove('${l['id']}')),
                    ),
                    AnimatedSize(
                      duration: dur,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: !_usa.containsKey('${l['id']}') ? const SizedBox(width: double.infinity) : _detalle(p, l),
                    ),
                    const SizedBox(height: 24),
                  ],
                  AnimatedSwitcher(
                    duration: dur,
                    child: Text(
                      key: ValueKey(_usaLiga),
                      _usaLiga ? 'Con equipamiento de la liga reservas por clase, y la liga te lo tiene listo.' : '',
                      style: TextStyle(fontSize: 13.5, color: p.textoSecundario),
                    ),
                  ),
                  // Se quitó al entrar desde Inventario (Victor, 2026-11-14): ahí está
                  // la tarjeta "Solicitar equipamiento de emergencia".
                  if (widget.conPedido && _propio.isNotEmpty && !_usaLiga) ...[
                    const SizedBox(height: 12),
                    Material(
                      color: p.tarjeta,
                      borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                        leading: Icon(Icons.volunteer_activism_outlined, color: p.marcaTexto),
                        title: const Text('¿Necesitas equipamiento por un tiempo?', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Si se te rompió o lo estás lavando, pídelo: un Pivot decide por cuánto tiempo y no cambias de equipo.'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _pedirUso,
                      ),
                    ),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _cambio && !_guardando ? _guardar : null,
            child: Text(_guardando ? 'Guardando…' : 'Guardar'),
          ),
        ),
      ),
    );
  }

  /// Talla (listas con tallas) o qué piezas (sets).
  Widget _detalle(PivotPaleta p, Map<String, dynamic> l) {
    final id = '${l['id']}';
    if (l['tipo'] == 'tallas') {
      final tallas = [for (final t in (l['tallas'] as List? ?? const [])) '$t']..sort((a, b) => (num.tryParse(a) ?? 0).compareTo(num.tryParse(b) ?? 0));
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (tallas.isEmpty) Text('La liga todavía no cargó tallas.', style: TextStyle(color: p.textoSecundario)),
            for (final t in tallas) ChoiceChip(label: Text('Talla $t'), selected: _usa[id] == t, onSelected: (_) => setState(() => _usa[id] = t)),
          ],
        ),
      );
    }
    final piezas = [for (final x in (l['piezas'] as List? ?? const [])) '$x'];
    if (l['tipo'] != 'set' || piezas.isEmpty) return const SizedBox(width: double.infinity);
    final elegidas = (_usa[id] ?? '').split(',').map((x) => x.trim()).where(piezas.contains).toSet();
    final todas = elegidas.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            todas ? 'Usas el set completo. ¿Solo algunas piezas? Elígelas:' : '¿Cuáles usas de la liga?',
            style: TextStyle(fontSize: 13.5, color: p.textoSecundario),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final x in piezas)
                FilterChip(
                  label: Text(x),
                  selected: elegidas.contains(x),
                  onSelected: (si) => setState(() {
                    si ? elegidas.add(x) : elegidas.remove(x);
                    _usa[id] = piezas.where(elegidas.contains).join(', ');
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
