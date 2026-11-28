import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../../core/vidrio.dart';
import 'social_repo.dart';
import 'social_widgets.dart';

/// Regalo robado en vivo (Victor, 2026-11-20). Todxs ven lo mismo: quién dejó
/// su regalo, el orden sorteado, a quién le toca, quién robó a quién y qué
/// tiene cada quien. Solo quien dirige el juego toca los botones de acción.
/// Sin notificaciones: la pantalla se actualiza sola cada pocos segundos.
class RegaloRobadoJuegoScreen extends StatefulWidget {
  const RegaloRobadoJuegoScreen({super.key, required this.repo});
  final SocialRepo repo;

  @override
  State<RegaloRobadoJuegoScreen> createState() => _RegaloRobadoJuegoScreenState();
}

class _RegaloRobadoJuegoScreenState extends State<RegaloRobadoJuegoScreen> {
  Map<String, dynamic>? _r;
  String? _error;
  bool _ocupado = false;
  Timer? _reloj;

  Map<String, dynamic>? get _j => _r?['juego'] == null ? null : Map<String, dynamic>.from(_r!['juego'] as Map);
  bool get _dirige => _r?['dirige'] == true;
  Map<String, dynamic> get _reglas => Map<String, dynamic>.from((_r?['reglas'] as Map?) ?? const {});

  @override
  void initState() {
    super.initState();
    _cargar();
    _reloj = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_ocupado) _cargar();
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.repo.juego('ver');
      if (mounted) setState(() => (_r = r, _error = null));
    } catch (e) {
      if (mounted && _r == null) setState(() => _error = e.toString());
    }
  }

  Future<void> _hacer(String accion, [Map<String, Object?> extra = const {}]) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final r = await widget.repo.juego(accion, extra);
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (mounted) avisarSocial(context, e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  List<Map<String, dynamic>> _lista(String k) => [for (final x in (_j?[k] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

  // ─── Acciones de quien dirige ─────────────────────────────────────────────

  Future<void> _abrir() async {
    if (_reglas['describir'] == false) return _hacer('abrir');
    final desc = TextEditingController();
    final ok = await pantallaFormulario(
      context,
      titulo: '${_j?['actual']?['nombre'] ?? ''} abrió un regalo',
      accion: 'Listo',
      contenido: (d, set) => TextField(
        controller: desc,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: '¿Qué era? (opcional)', counterText: ''),
      ),
    );
    final t = desc.text.trim();
    Future.delayed(const Duration(milliseconds: 400), desc.dispose);
    if (ok == true) await _hacer('abrir', {'desc': t});
  }

  /// Elegir un regalo de otra persona (para robar o, en el turno final, cambiar).
  Future<void> _elegirRegalo({required bool cambio}) async {
    final actual = '${_j?['actual']?['clave'] ?? ''}';
    final opciones = [
      for (final g in _lista('regalos'))
        if (g['duenx'] != actual && g['bloqueado'] != true && g['vedado'] != true) g,
    ];
    if (opciones.isEmpty) return avisarSocial(context, 'No hay regalos que se puedan ${cambio ? 'cambiar' : 'robar'}.');
    final id = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (h) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                cambio ? '¿Con qué regalo cambia?' : '¿Qué regalo roba?',
                style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final g in opciones)
              ListTile(
                leading: const Icon(Icons.card_giftcard_rounded),
                title: Text(_nombreRegalo(g)),
                subtitle: Text('Lo tiene ${g['nombre']}${_textoRobos(g).isEmpty ? '' : ' · ${_textoRobos(g)}'}'),
                onTap: () => Navigator.pop(h, g['id'] as int),
              ),
          ],
        ),
      ),
    );
    if (id != null) await _hacer(cambio ? 'final' : 'robar', {'regalo': id});
  }

  Future<void> _reiniciar() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Reiniciar el juego?'),
        content: const Text('Se borra todo lo que pasó (pila, orden y turnos) y el juego vuelve a empezar desde cero.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Reiniciar')),
        ],
      ),
    );
    if (si != true) return;
    await _hacer('reiniciar');
    if (mounted) Navigator.of(context).pop();
  }

  // ─── Textos ───────────────────────────────────────────────────────────────

  String _nombreRegalo(Map<String, dynamic> g) => '${g['desc'] ?? ''}'.isNotEmpty ? '${g['desc']}' : 'Regalo ${g['id']}';

  String _textoRobos(Map<String, dynamic> g) {
    if (g['bloqueado'] == true) return 'ya no se puede robar';
    final n = (g['robos'] as num?)?.toInt() ?? 0;
    final max = (_reglas['robosMax'] as num?)?.toInt() ?? 0;
    if (n == 0) return '';
    return max > 0 ? 'robado $n de $max ${max == 1 ? 'vez' : 'veces'}' : 'robado $n ${n == 1 ? 'vez' : 'veces'}';
  }

  // ─── Pantalla ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final j = _j;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Regalo robado', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_dirige && j != null)
            PopupMenuButton<String>(
              tooltip: 'Opciones',
              position: PopupMenuPosition.under,
              onSelected: (v) => v == 'deshacer' ? _hacer('deshacer') : _reiniciar(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'deshacer', enabled: j['deshacer'] == true, child: const Text('Deshacer lo último')),
                const PopupMenuItem(value: 'reiniciar', child: Text('Reiniciar el juego')),
              ],
            ),
        ],
      ),
      body: _r == null
          ? Center(child: _error != null ? Text(_error!, textAlign: TextAlign.center) : const CircularProgressIndicator())
          : j == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('El juego todavía no empezó.', style: TextStyle(color: p.textoSecundario)),
              ),
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: KeyedSubtree(
                key: ValueKey(j['fase']),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 12 + altoBarra(context), 16, 32 + MediaQuery.paddingOf(context).bottom),
                  children: switch (j['fase']) {
                    'pila' => _pila(p, j),
                    'orden' => _orden(p, j),
                    'terminado' => _terminado(p, j),
                    _ => _juego(p, j),
                  },
                ),
              ),
            ),
    );
  }

  Widget _paso(PivotPaleta p, String paso, String titulo, String texto) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          paso,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.sobreSuave),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.sobreSuave),
        ),
        const SizedBox(height: 4),
        Text(texto, style: TextStyle(color: p.sobreSuave)),
      ],
    ),
  );

  Widget _titulo(PivotPaleta p, String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
    child: Text(
      t,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
    ),
  );

  List<Widget> _pila(PivotPaleta p, Map<String, dynamic> j) {
    final ps = _lista('participantes');
    final dejaron = ps.where((x) => x['dejo'] == true).length;
    return [
      _paso(
        p,
        'PASO 1 DE 3',
        'Regalos a la pila',
        _dirige
            ? 'Marca a cada persona cuando deje su regalo en la pila. Solo juega quien dejó regalo.'
            : 'Deja tu regalo en la pila y márcalo aquí. Solo juega quien dejó regalo.',
      ),
      _titulo(p, '$dejaron DE ${ps.length} DEJARON SU REGALO'),
      for (final x in ps)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: x['dejo'] == true,
          title: Text('${x['nombre']}${x['yo'] == true ? ' (tú)' : ''}'),
          onChanged: _dirige
              ? (v) => _hacer('dejo', {'clave': x['clave'], 'valor': v == true})
              : x['yo'] == true
              ? (v) => _hacer('mio', {'valor': v == true})
              : null,
        ),
      if (_dirige) ...[
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: dejaron >= 2 && !_ocupado ? () => _hacer('sortear') : null,
          icon: const Icon(Icons.shuffle_rounded),
          label: const Text('Sortear el orden'),
        ),
      ],
    ];
  }

  List<Widget> _orden(PivotPaleta p, Map<String, dynamic> j) {
    final orden = _lista('orden');
    final mi = (j['miTurno'] as num?)?.toInt() ?? 0;
    return [
      _paso(
        p,
        'PASO 2 DE 3',
        mi > 0 ? 'Tu turno: $mi.º de ${orden.length}' : 'Orden de los turnos',
        'Este es el orden sorteado. ${_dirige ? 'Cuando estén listxs, empieza el juego.' : 'Quien dirige empieza el juego cuando estén listxs.'}',
      ),
      _titulo(p, 'ORDEN'),
      for (final (i, x) in orden.indexed)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 250 + i * 60),
          curve: Curves.easeOutCubic,
          builder: (_, v, hijo) => Opacity(
            opacity: v,
            child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: hijo),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: x['yo'] == true ? p.marca : p.suave, child: Text('${i + 1}')),
            title: Text('${x['nombre']}${x['yo'] == true ? ' (tú)' : ''}', style: TextStyle(fontWeight: x['yo'] == true ? FontWeight.w700 : FontWeight.w400)),
          ),
        ),
      if (_dirige) ...[
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _ocupado ? null : () => _hacer('sortear'), child: const Text('Sortear de nuevo')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: _ocupado ? null : () => _hacer('empezar'), child: const Text('Empezar el juego')),
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _juego(PivotPaleta p, Map<String, dynamic> j) {
    final actual = Map<String, dynamic>.from((j['actual'] as Map?) ?? const {});
    final esperando = j['esperando'] == true;
    final finalTurno = j['fase'] == 'final';
    final robado = j['robado'] == null ? null : Map<String, dynamic>.from(j['robado'] as Map);
    final pila = (j['pila'] as num?)?.toInt() ?? 0;
    final mio = _lista('regalos').where((g) => g['mio'] == true).firstOrNull;
    final yo = actual['yo'] == true;
    final titulo = finalTurno
        ? (yo ? '¡Tu turno final!' : 'Turno final de ${actual['nombre']}')
        : esperando
        ? '${actual['nombre']} ya eligió'
        : (yo ? '¡Te toca!' : 'Le toca a ${actual['nombre']}');
    final texto = finalTurno
        ? 'Puede cambiar su regalo por otro que todavía se pueda robar, o quedarse con el suyo.'
        : esperando
        ? (_dirige ? 'Cuando estén listxs, pasa al siguiente turno.' : 'Esperando el siguiente turno.')
        : robado != null
        ? '${robado['yo'] == true ? '¡Te robaron! Elige' : 'A ${robado['victima']} le robaron: elige'} abrir un regalo de la pila o robar otro.'
        : 'Abre un regalo de la pila o roba uno que ya esté abierto.';
    return [
      _paso(p, finalTurno ? 'FINAL' : 'PASO 3 DE 3', titulo, texto),
      const SizedBox(height: 8),
      Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 18, color: p.textoSecundario),
          const SizedBox(width: 6),
          Expanded(
            child: Text(pila == 1 ? 'Queda 1 regalo en la pila' : 'Quedan $pila regalos en la pila', style: TextStyle(color: p.textoSecundario)),
          ),
          if ((j['miTurno'] as num? ?? 0) > 0) Text('Tu turno: ${j['miTurno']}.º', style: TextStyle(color: p.textoSecundario)),
        ],
      ),
      if (mio != null) ...[
        const SizedBox(height: 8),
        Text(
          'Tienes: ${_nombreRegalo(mio)}',
          style: TextStyle(fontWeight: FontWeight.w700, color: p.marcaTexto),
        ),
      ],
      if (_dirige) ...[
        const SizedBox(height: 16),
        if (finalTurno)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: _ocupado ? null : () => _hacer('final'), child: const Text('Se queda con el suyo')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _ocupado ? null : () => _elegirRegalo(cambio: true), child: const Text('Cambia su regalo')),
              ),
            ],
          )
        else if (esperando)
          FilledButton.icon(
            onPressed: _ocupado ? null : () => _hacer('siguiente'),
            icon: const Icon(Icons.skip_next_rounded),
            label: const Text('Siguiente turno'),
          )
        else
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _ocupado || pila == 0 ? null : _abrir,
                  icon: const Icon(Icons.card_giftcard_rounded),
                  label: const Text('Abrió uno'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _ocupado ? null : () => _elegirRegalo(cambio: false),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Robó uno'),
                ),
              ),
            ],
          ),
      ],
      ..._regalos(p),
      ..._ordenCompacto(p, j),
      ..._historial(p),
    ];
  }

  List<Widget> _regalos(PivotPaleta p) {
    final gs = _lista('regalos');
    if (gs.isEmpty) return const [];
    return [
      _titulo(p, 'REGALOS ABIERTOS'),
      for (final g in gs)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(g['bloqueado'] == true ? Icons.lock_rounded : Icons.card_giftcard_rounded, color: g['mio'] == true ? p.marcaTexto : p.textoSecundario),
          title: Text(_nombreRegalo(g)),
          subtitle: Text('Lo tiene ${g['mio'] == true ? 'tú' : g['nombre']}${_textoRobos(g).isEmpty ? '' : ' · ${_textoRobos(g)}'}'),
        ),
    ];
  }

  List<Widget> _ordenCompacto(PivotPaleta p, Map<String, dynamic> j) {
    final orden = _lista('orden');
    final actual = '${(j['actual'] as Map?)?['clave'] ?? ''}';
    return [
      _titulo(p, 'TURNOS'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (i, x) in orden.indexed)
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: x['clave'] == actual ? Icon(Icons.play_arrow_rounded, size: 16, color: p.marcaTexto) : null,
              label: Text('${i + 1}. ${x['yo'] == true ? 'Tú' : x['nombre']}'),
              backgroundColor: x['clave'] == actual ? p.suave : null,
              labelStyle: TextStyle(
                color: x['paso'] == true && x['clave'] != actual ? p.textoSecundario : p.texto,
                fontWeight: x['clave'] == actual ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
        ],
      ),
    ];
  }

  List<Widget> _historial(PivotPaleta p) {
    final h = _lista('historial');
    if (h.isEmpty) return const [];
    return [
      _titulo(p, 'LO QUE PASÓ'),
      for (final x in h.take(15))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('${x['texto']}', style: TextStyle(fontSize: 13, color: p.texto)),
        ),
    ];
  }

  List<Widget> _terminado(PivotPaleta p, Map<String, dynamic> j) {
    final gs = _lista('regalos');
    return [
      _paso(p, 'FIN', '¡Terminó el juego!', 'Así quedaron los regalos. ¡Que los disfruten!'),
      _titulo(p, 'QUIÉN SE LLEVÓ QUÉ'),
      for (final g in gs)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.card_giftcard_rounded, color: g['mio'] == true ? p.marcaTexto : p.textoSecundario),
          title: Text('${g['mio'] == true ? 'Tú' : g['nombre']}'),
          subtitle: Text(_nombreRegalo(g)),
        ),
      ..._historial(p),
    ];
  }
}
