import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
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

  Future<void> _cargar() async {
    try {
      final e = await _repo.cargar();
      if (!mounted) return;
      setState(() {
        _estado = e;
        _error = null;
      });
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
            if (e.modulo('amigoSecreto')) AmigoSecretoTarjeta(repo: _repo, estado: e, alCambiar: _cargar, simbolo: simbolo),
            if (e.modulo('regaloRobado')) RegaloRobadoTarjeta(estado: e, simbolo: simbolo),
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
