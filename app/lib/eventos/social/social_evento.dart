import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/esqueleto.dart';
import '../../core/fechas.dart';
import '../../core/tema.dart';
import '../eventos_repo.dart';
import '../modelos.dart';
import 'crear_social_screen.dart';
import 'mensajeria.dart';
import 'social_piezas.dart';
import 'social_repo.dart';
import 'social_widgets.dart';

/// Secciones del "Social o fiesta" en su detalle (NAVIQUINDE.md): encabezado
/// (nombre, sorpresa, aprobación), +1, amigo secreto, regalo robado, comida,
/// playlist, dress code, qué traer, homenaje y premios. Se recarga al cambiar
/// la asistencia. Lo que no le toca ver a cada quien no llega del servidor.
class SocialEnEvento extends StatefulWidget {
  const SocialEnEvento({super.key, required this.repo, required this.evento});
  final EventosRepo repo;
  final Evento evento;

  @override
  State<SocialEnEvento> createState() => _SocialEnEventoState();
}

class _SocialEnEventoState extends State<SocialEnEvento> {
  late final SocialRepo _social = SocialRepo.miembro(widget.repo.sesion.api, idEvento: widget.evento.id, adminToken: widget.repo.sesion.adminToken);
  EstadoSocial? _estado;
  String? _error;
  EstadoRsvp? _rsvpVisto;
  bool _sorteando = false;

  /// Apps de mensajería de la liga (Comunidad en Equipo).
  List<String> _redes = const [];

  bool get _esPivot => widget.repo.sesion.esAdmin && widget.repo.sesion.adminToken != null;

  @override
  void initState() {
    super.initState();
    _rsvpVisto = widget.evento.miEstado;
    _cargar();
    mensajeriasDeLiga(widget.repo.sesion).then((r) {
      if (mounted) setState(() => _redes = r);
    }).ignore();
  }

  Future<void> _cargar() async {
    try {
      final e = await _social.cargar();
      _estadosSociales[widget.evento.id] = e;
      if (mounted) {
        setState(() {
          _estado = e;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _configurar() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CrearSocialScreen(sesion: widget.repo.sesion, repo: _social, actual: _estado),
      ),
    );
    if (ok == true) {
      _cargar();
      widget.repo.cargar(forzar: true);
    }
  }

  Future<void> _liberar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Liberar los mensajes?'),
        content: const Text('Las personas homenajeadas podrán leerlos desde ahora y se les avisa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Liberar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _social.liberarMensajes();
      await _cargar();
    } catch (e) {
      if (mounted) avisarSocial(context, e.toString());
    }
  }

  Future<void> _sortear() async {
    final e = _estado!;
    final rehacer = e.sorteado;
    final n = e.admin?['participantes'] ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(rehacer ? '¿Rehacer el sorteo?' : '¿Cerrar la inscripción y sortear?'),
        content: Text(
          rehacer
              ? 'Se arma un sorteo nuevo con quienes confirmaron hoy ($n). ${e.admin?['revelados'] ?? 0} personas ya vieron a quién le regalan y tendrán que volver a descubrirlo con el sorteo nuevo.'
              : 'Entran $n personas (quienes marcaron Asistiré y sus +1). Se sortea a quién le regala cada persona y se les avisa para que lo descubran en el evento. Quien se sume después no entra al amigo secreto.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(rehacer ? 'Rehacer' : 'Sortear')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sorteando = true);
    try {
      final r = await _social.sortear(rehacer: rehacer);
      if (!mounted) return;
      avisarSocial(
        context,
        r['repiteAnterior'] == true
            ? 'Sorteo listo. No hubo forma de evitar todas las parejas del año anterior.'
            : 'Sorteo listo: ${r['participantes']} personas ya pueden descubrir a quién le regalan.',
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('No se pudo sortear'),
          content: Text(e.toString()),
          actions: [FilledButton(onPressed: () => Navigator.pop(d), child: const Text('Entendido'))],
        ),
      );
    } finally {
      if (mounted) setState(() => _sorteando = false);
    }
  }

  // ─── +1 ─────────────────────────────────────────────────────────────────

  /// +1 por enlace (Victor, 2026-11-20): se crea su enlace y se abre para
  /// mandarlo. El +1 escribe su nombre al abrirlo.
  Future<void> _agregarInvitado() async {
    try {
      final inv = await _social.agregarInvitado('', '');
      await _cargar();
      if (mounted) await _compartir(inv);
    } catch (e) {
      if (mounted) avisarSocial(context, e.toString());
    }
  }

  String _mensaje(Map<String, dynamic> inv) {
    final ev = widget.evento;
    final titulo = _estado?.titulo ?? '';
    final que = titulo.isEmpty ? 'nuestro evento' : '"$titulo"';
    final n = '${inv['nombre'] ?? ''}'.trim();
    return '${n.isEmpty ? 'Hola' : 'Hola, $n'}. Te invito a ${ev.lugar.isEmpty ? que : '$que en ${ev.lugar}'} el ${Fechas.corta(ev.fecha)}. '
        'Entra aquí (sin crear cuenta) para tus pistas del amigo secreto y la comida: ${inv['enlace']}';
  }

  Future<void> _compartir(Map<String, dynamic> inv) async {
    final contacto = '${inv['contacto'] ?? ''}';
    final tel = contacto.contains('@') ? '' : telefonoInternacional(contacto);
    final texto = _mensaje(inv);
    final canales = canalesPara(tel, _redes, texto: texto);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (h) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('${inv['nombre'] ?? ''}'.isEmpty ? 'Enlace para tu +1' : 'Enlace de ${inv['nombre']}'),
              subtitle: const Text('Es para una sola persona: con él entra sin crear cuenta y escribe su nombre.'),
            ),
            // Las apps de mensajería que usa la liga (Comunidad en Equipo) y SMS.
            for (final (nombre, icono, uri) in canales)
              ListTile(
                leading: Icon(icono),
                title: Text('Enviar por $nombre'),
                onTap: () {
                  Navigator.pop(h);
                  // Telegram y Signal no reciben el texto: se copia para pegarlo en el chat.
                  if (nombre != 'WhatsApp' && nombre != 'Mensaje de texto') {
                    Clipboard.setData(ClipboardData(text: texto));
                    avisarSocial(context, 'Copiamos el mensaje con su enlace: pégalo en el chat.');
                  }
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            if (contacto.contains('@'))
              ListTile(
                leading: const Icon(Icons.mail_outline_rounded),
                title: const Text('Enviar por correo'),
                onTap: () {
                  Navigator.pop(h);
                  launchUrl(Uri(scheme: 'mailto', path: contacto, queryParameters: {'subject': 'Tu invitación', 'body': texto}));
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Compartir'),
              onTap: () {
                Navigator.pop(h);
                SharePlus.instance.share(ShareParams(text: texto));
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copiar enlace'),
              onTap: () {
                Navigator.pop(h);
                Clipboard.setData(ClipboardData(text: '${inv['enlace']}'));
                avisarSocial(context, 'Enlace copiado.');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quitarInvitado(Map<String, dynamic> inv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿Quitar a ${inv['nombre']}?'),
        content: const Text('Su enlace deja de funcionar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _social.quitarInvitado('${inv['id']}');
      await _cargar();
    } catch (e) {
      if (mounted) avisarSocial(context, e.toString());
    }
  }

  Widget _invitados(EstadoSocial e) {
    final p = context.pivot;
    final lista = e.misInvitados;
    return TarjetaSocial(
      titulo: 'Tus invitadxs +1',
      icono: Icons.person_add_alt_1_outlined,
      children: [
        if (!e.asiste)
          Text('Marca Asistiré para sumar a tu +1.', style: TextStyle(color: p.textoSecundario))
        else ...[
          if (lista.isEmpty)
            Text(
              'Mándale un enlace a tu +1: entra sin crear cuenta, escribe su nombre y ve el evento. Cada enlace es para una persona.',
              style: TextStyle(color: p.textoSecundario),
            ),
          for (final inv in lista)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(inv['entro'] == false ? Icons.schedule_send_outlined : Icons.person_outline_rounded),
              title: Text(inv['entro'] == false ? 'Enlace enviado' : '${inv['nombre']}'),
              subtitle: Text(
                [
                  if (inv['entro'] == false) 'Todavía no entra',
                  if ('${inv['contacto'] ?? ''}'.isNotEmpty) '${inv['contacto']}',
                  if (inv['enSorteo'] == true) 'En el amigo secreto',
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(tooltip: 'Enviar enlace', icon: const Icon(Icons.send_outlined), onPressed: () => _compartir(inv)),
                  if (inv['enSorteo'] != true) IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close_rounded), onPressed: () => _quitarInvitado(inv)),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: _agregarInvitado, icon: const Icon(Icons.add_rounded), label: const Text('Invitar a mi +1')),
          ),
        ],
      ],
    );
  }

  Widget _organizar(EstadoSocial e) {
    final p = context.pivot;
    final a = e.admin ?? const {};
    final cierre = e.cierre;
    final hoy = Fechas.hoy();
    final yaCerro = cierre != null && !hoy.isBefore(cierre);
    return TarjetaSocial(
      titulo: 'Amigo secreto: organizar',
      icono: Icons.tune_rounded,
      children: [
        Text(
          '${a['participantes'] ?? 0} personas en el amigo secreto (${a['invitados'] ?? 0} +1)'
          '${e.sorteado ? ' · ${a['revelados'] ?? 0} de ${a['sorteados'] ?? 0} ya vieron a quién le regalan' : ''}.',
          style: TextStyle(color: p.texto),
        ),
        if (e.modulo('amigoSecreto')) ...[
          const SizedBox(height: 6),
          Text(
            e.sorteado
                ? 'El sorteo ya se hizo.'
                : cierre == null
                ? ''
                : yaCerro
                ? 'La inscripción cerró el ${Fechas.corta(cierre)}: ya puedes sortear.'
                : 'La inscripción cierra el ${Fechas.corta(cierre)}.',
            style: TextStyle(fontSize: 13, color: p.textoSecundario),
          ),
          const SizedBox(height: 10),
          if (!e.sorteado)
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: _sorteando ? null : _sortear,
              icon: const Icon(Icons.shuffle_rounded),
              label: Text(_sorteando ? 'Sorteando…' : 'Cerrar inscripción y sortear'),
            )
          else
            OutlinedButton.icon(onPressed: _sorteando ? null : _sortear, icon: const Icon(Icons.refresh_rounded), label: const Text('Rehacer sorteo')),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Al marcar o cambiar la asistencia, se recarga (puede sumar +1, comida…).
    if (widget.evento.miEstado != _rsvpVisto) {
      _rsvpVisto = widget.evento.miEstado;
      WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
    }
    final p = context.pivot;
    final e = _estado;
    final Widget contenido;
    if (e == null && _error == null) {
      contenido = const Padding(key: ValueKey('cargando'), padding: EdgeInsets.all(16), child: EsqueletoFilas());
    } else if (e == null) {
      contenido = TarjetaSocial(
        key: const ValueKey('error'),
        titulo: 'Social o fiesta',
        children: [
          Text(_error!, style: TextStyle(color: p.textoSecundario)),
          TextButton(onPressed: _cargar, child: const Text('Reintentar')),
        ],
      );
    } else if (!e.configurado) {
      contenido = _esPivot
          ? TarjetaSocial(
              key: const ValueKey('sin-config'),
              titulo: 'Social o fiesta',
              icono: Icons.celebration_outlined,
              children: [
                Text('Elige qué tendrá: comida, playlist, amigo secreto, regalo robado, homenaje y más.', style: TextStyle(color: p.textoSecundario)),
                const SizedBox(height: 10),
                FilledButton(onPressed: _configurar, child: const Text('Configurar')),
              ],
            )
          : const SizedBox.shrink(key: ValueKey('nada'));
    } else {
      contenido = Column(
        key: const ValueKey('social'),
        children: [
          EncabezadoSocial(estado: e),
          if (e.paraTi != null) ParaTiTarjeta(mensajes: e.paraTi!),
          if (e.organiza && e.modulo('amigoSecreto') && e.estadoAprobacion == 'publicado') _organizar(e),
          if (e.homenaje != null) HomenajeTarjeta(repo: _social, estado: e, alCambiar: _cargar, alLiberar: e.organiza ? _liberar : null),
          if (e.modulo('invitados')) _invitados(e),
          if (e.modulo('amigoSecreto')) AmigoSecretoTarjeta(repo: _social, estado: e, alCambiar: _cargar, pronombres: widget.repo.sesion.datos['pronombres']),
          if (e.modulo('regaloRobado')) RegaloRobadoTarjeta(estado: e),
          if (e.modulo('comida')) ComidaTarjeta(repo: _social, estado: e, alCambiar: _cargar),
          if (e.playlist != null) PlaylistTarjeta(datos: e.playlist!),
          if (e.dress != null) DressTarjeta(texto: '${e.dress!['texto'] ?? ''}'),
          // "Qué traer" ya está dentro de "Qué lleva cada quien" (Victor, 2026-11-20).
          if (e.premios != null) PremiosTarjeta(lista: e.premios!),
          // Personas a cargo con su contacto, para consultar dudas (Victor, 2026-11-20).
          if (e.aCargo.isNotEmpty) ACargoTarjeta(personas: e.aCargo, redes: _redes),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SizeTransition(sizeFactor: a, alignment: Alignment.topCenter, child: c),
      ),
      child: contenido,
    );
  }
}

/// Editar un Social o fiesta con su asistente desde el menú del evento
/// (Victor, 2026-11-20). Devuelve true si se guardaron cambios.
/// Último estado cargado de cada Social o fiesta (solo en memoria): así el
/// asistente abre al toque desde el botón del evento.
final _estadosSociales = <String, EstadoSocial>{};

Future<bool?> editarSocial(BuildContext context, EventosRepo repo, Evento ev) async {
  final s = repo.sesion;
  final social = SocialRepo.miembro(s.api, idEvento: ev.id, adminToken: s.adminToken);
  try {
    var estado = _estadosSociales[ev.id];
    if (estado == null) {
      // Sin datos todavía: se muestra que está cargando en vez de quedarse trabado.
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        ),
      );
      try {
        estado = await social.cargar();
      } finally {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!context.mounted) return null;
    return await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CrearSocialScreen(sesion: s, repo: social, actual: estado),
      ),
    );
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir: $e')));
    return null;
  }
}
