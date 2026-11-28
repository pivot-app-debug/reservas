import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/banner_ayuda.dart';
import '../../core/cargando.dart';
import '../../core/fechas.dart';
import '../../core/monedas_mundo.dart';
import '../../core/tema.dart';
import 'social_piezas.dart';
import 'social_repo.dart';
import 'social_widgets.dart';

/// Pantalla de unx invitadx +1 que entra con su enlace (`?social=<token>`)
/// sin crear cuenta: datos del evento, su amigo secreto (ruleta y ficha),
/// sus pistas/wishlist y la comida. No ve la lista de asistentes.
class InvitadoSocialScreen extends StatefulWidget {
  const InvitadoSocialScreen({super.key, required this.token, this.alCargar});
  final String token;

  /// Avisa cuando ya hay algo que mostrar (para la animación de entrada).
  final VoidCallback? alCargar;

  @override
  State<InvitadoSocialScreen> createState() => _InvitadoSocialScreenState();
}

class _InvitadoSocialScreenState extends State<InvitadoSocialScreen> {
  late final SocialRepo _repo = SocialRepo.invitado(Api(), widget.token);
  EstadoSocial? _estado;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  bool _preguntado = false;

  Future<void> _cargar() async {
    try {
      final e = await _repo.cargar();
      if (!mounted) return;
      setState(() {
        _estado = e;
        _error = null;
      });
      if (!_preguntado && e.asiste && !e.respondioParticipa && !e.necesitaNombre) {
        _preguntado = true;
        unawaited(preguntarParticipacion(context, _repo, e, _cargar));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      widget.alCargar?.call();
    }
  }

  Widget _encabezado(EstadoSocial e) {
    final p = context.pivot;
    final ev = e.evento;
    final fecha = DateTime.tryParse('${ev['fecha'] ?? ''}');
    final hora = '${ev['inicia'] ?? ''}'.length >= 5 ? '${ev['inicia']}'.substring(0, 5) : '';
    final mapa = '${ev['mapa'] ?? ''}';
    final anfitrion = '${e.yo['anfitrion'] ?? ''}';
    final liga = '${ev['liga'] ?? ''}';
    return TarjetaSocial(
      titulo: '¡Hola, ${e.yo['nombre'] ?? ''}!',
      icono: Icons.celebration_outlined,
      children: [
        Text(
          '${anfitrion.isEmpty ? 'Te invitaron' : '$anfitrion te invitó'} a ${e.titulo.isEmpty ? 'un evento' : '"${e.titulo}"'}${liga.isEmpty ? '' : ' de $liga'}.',
          style: TextStyle(color: p.texto),
        ),
        const SizedBox(height: 10),
        if (fecha != null)
          Row(
            children: [
              Icon(Icons.event_outlined, size: 18, color: p.textoSecundario),
              const SizedBox(width: 8),
              Expanded(child: Text('${Fechas.encabezado(fecha)}${hora.isEmpty ? '' : ' · $hora'}')),
            ],
          ),
        if ('${ev['lugar'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 18, color: p.textoSecundario),
              const SizedBox(width: 8),
              Expanded(child: Text('${ev['lugar']}')),
              if (mapa.startsWith('http'))
                TextButton(
                  onPressed: () => launchUrl(Uri.parse(mapa), mode: LaunchMode.externalApplication),
                  child: const Text('Cómo llegar'),
                ),
            ],
          ),
        ],
        if ('${ev['info'] ?? ''}'.isNotEmpty) ...[const SizedBox(height: 8), Text('${ev['info']}', style: TextStyle(color: p.textoSecundario))],
        if (!e.asiste) ...[const SizedBox(height: 8), Text('Quien te invitó todavía no confirmó su asistencia.', style: TextStyle(color: p.textoSecundario))],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final e = _estado;
    final Widget cuerpo;
    if (e == null && _error == null) {
      cuerpo = const Center(key: ValueKey('cargando'), child: PivotCargando());
    } else if (e == null) {
      cuerpo = Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.texto),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    } else if (e.necesitaNombre) {
      // Primera vez con el enlace: escribe su nombre (Victor, 2026-11-20).
      cuerpo = _PedirNombre(
        key: const ValueKey('nombre'),
        estado: e,
        alGuardar: (n) async {
          await _repo.nombrarme(n);
          await _cargar();
        },
      );
    } else {
      // La liga guarda el código (USD); se muestra su símbolo.
      final codigo = '${e.evento['moneda'] ?? ''}';
      final simbolo = monedasMundo.where((m) => m.$1 == codigo).map((m) => m.$3).firstOrNull ?? (codigo.isEmpty ? '' : '$codigo ');
      cuerpo = RefreshIndicator(
        key: const ValueKey('listo'),
        onRefresh: _cargar,
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, 4, 0, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            _encabezado(e),
            // Mini guía para quien llega por invitación (QA 2026-11-27).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: BannerAyuda(
                clave: 'invitado_social',
                titulo: '¿Cómo funciona tu invitación?',
                texto: 'Aquí tienes todo lo de la fiesta en un solo lugar. No necesitas crear una cuenta.',
                pasos: [
                  (Icons.event_available_outlined, 'Arriba ves la fecha, el lugar y cómo llegar.'),
                  if (e.modulo('comida')) (Icons.restaurant_outlined, 'En «Qué lleva cada quien» eliges qué vas a llevar.'),
                  if (e.modulo('amigoSecreto') || e.modulo('regaloRobado')) (Icons.redeem_outlined, 'En los juegos de regalos ves tu parte y el presupuesto.'),
                  (Icons.refresh_rounded, 'Desliza hacia abajo para ver los cambios más recientes.'),
                ],
              ),
            ),
            if (e.modulo('amigoSecreto')) AmigoSecretoTarjeta(repo: _repo, estado: e, alCambiar: _cargar, simbolo: simbolo),
            if (e.modulo('regaloRobado')) RegaloRobadoTarjeta(estado: e, simbolo: simbolo, repo: _repo, alCambiar: _cargar),
            if (e.modulo('comida')) ComidaTarjeta(repo: _repo, estado: e, alCambiar: _cargar),
            if (e.playlist != null) PlaylistTarjeta(datos: e.playlist!),
            if (e.dress != null) DressTarjeta(texto: '${e.dress!['texto'] ?? ''}'),
            // "Qué traer" ya está dentro de "Qué lleva cada quien" (Victor, 2026-11-20).
            // Homenaje: lxs +1 solo aportan al regalo entre todxs (sin mensajes).
            if (e.homenaje != null) HomenajeTarjeta(repo: _repo, estado: e, alCambiar: _cargar, simbolo: simbolo),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tu invitación')),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: cuerpo),
    );
  }
}

class _PedirNombre extends StatefulWidget {
  const _PedirNombre({super.key, required this.estado, required this.alGuardar});
  final EstadoSocial estado;
  final Future<void> Function(String) alGuardar;

  @override
  State<_PedirNombre> createState() => _PedirNombreState();
}

class _PedirNombreState extends State<_PedirNombre> {
  final _nombre = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final n = _nombre.text.trim();
    if (n.isEmpty) return setState(() => _error = 'Escribe tu nombre.');
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.alGuardar(n);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final e = widget.estado;
    final anfitrion = '${e.yo['anfitrion'] ?? ''}';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.celebration_rounded, size: 56, color: p.marcaTexto),
        const SizedBox(height: 16),
        Text(
          '${anfitrion.isEmpty ? 'Te invitaron' : '$anfitrion te invitó'} a ${e.titulo.isEmpty ? 'un evento' : '"${e.titulo}"'}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: p.texto),
        ),
        const SizedBox(height: 8),
        Text(
          'Escribe tu nombre para entrar. No hace falta crear una cuenta.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textoSecundario),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nombre,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Tu nombre', errorText: _error),
          onSubmitted: (_) => _guardar(),
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Entrando…' : 'Entrar'),
        ),
      ],
    );
  }
}
