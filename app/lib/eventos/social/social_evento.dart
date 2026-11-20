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

  bool get _esPivot => widget.repo.sesion.esAdmin && widget.repo.sesion.adminToken != null;

  @override
  void initState() {
    super.initState();
    _rsvpVisto = widget.evento.miEstado;
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final e = await _social.cargar();
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
              ? 'Se arma un sorteo nuevo con quienes confirmaron hoy ($n). ${e.admin?['revelados'] ?? 0} personas ya vieron su amigo secreto y tendrán que volver a girar la ruleta.'
              : 'Entran $n personas (quienes marcaron Asistiré y sus +1). Quien se sume después no entra al amigo secreto. Se avisa al equipo para que gire su ruleta.',
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
            : 'Sorteo listo: ${r['participantes']} personas ya pueden girar su ruleta.',
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

  Future<void> _agregarInvitado() async {
    final nombre = TextEditingController(), contacto = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Sumar a tu +1'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombre,
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: contacto,
              maxLength: 120,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'WhatsApp o correo', hintText: 'Para enviarle su enlace'),
            ),
            const Text('Recibe un enlace propio para entrar sin crear cuenta: sus pistas, su ruleta y la comida.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Sumar')),
        ],
      ),
    );
    final n = nombre.text.trim(), c = contacto.text.trim();
    nombre.dispose();
    contacto.dispose();
    if (ok != true || n.isEmpty || !mounted) return;
    try {
      final inv = await _social.agregarInvitado(n, c);
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
    return 'Hola, ${inv['nombre']}. Te invito a ${ev.lugar.isEmpty ? que : '$que en ${ev.lugar}'} el ${Fechas.corta(ev.fecha)}. '
        'Entra aquí (sin crear cuenta) para tus pistas del amigo secreto y la comida: ${inv['enlace']}';
  }

  Future<void> _compartir(Map<String, dynamic> inv) async {
    final contacto = '${inv['contacto'] ?? ''}';
    final tel = contacto.replaceAll(RegExp(r'[^0-9]'), '');
    final texto = _mensaje(inv);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (h) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('Enlace de ${inv['nombre']}'), subtitle: const Text('Es personal: con él entra sin cuenta.')),
            if (tel.length >= 7 && !contacto.contains('@'))
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('Enviar por WhatsApp'),
                onTap: () {
                  Navigator.pop(h);
                  launchUrl(Uri.parse('https://wa.me/$tel?text=${Uri.encodeComponent(texto)}'), mode: LaunchMode.externalApplication);
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
          if (lista.isEmpty) Text('Puedes sumar a una o más personas. Cada una recibe su propio enlace.', style: TextStyle(color: p.textoSecundario)),
          for (final inv in lista)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline_rounded),
              title: Text('${inv['nombre']}'),
              subtitle: Text([if ('${inv['contacto']}'.isNotEmpty) '${inv['contacto']}', if (inv['enSorteo'] == true) 'En el amigo secreto'].join(' · ')),
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
            child: TextButton.icon(onPressed: _agregarInvitado, icon: const Icon(Icons.add_rounded), label: const Text('Sumar +1')),
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
          '${e.sorteado ? ' · ${a['revelados'] ?? 0} de ${a['sorteados'] ?? 0} ya giraron su ruleta' : ''}.',
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
                Text('Elige las piezas: comida, playlist, amigo secreto, regalo robado, homenaje y más.', style: TextStyle(color: p.textoSecundario)),
                const SizedBox(height: 10),
                FilledButton(onPressed: _configurar, child: const Text('Configurar')),
              ],
            )
          : const SizedBox.shrink(key: ValueKey('nada'));
    } else {
      contenido = Column(
        key: const ValueKey('social'),
        children: [
          EncabezadoSocial(
            estado: e,
            accion: e.organiza ? TextButton(onPressed: _configurar, child: const Text('Editar')) : null,
          ),
          if (e.paraTi != null) ParaTiTarjeta(mensajes: e.paraTi!),
          if (e.organiza && e.modulo('amigoSecreto') && e.estadoAprobacion == 'publicado') _organizar(e),
          if (e.homenaje != null) HomenajeTarjeta(repo: _social, estado: e, alCambiar: _cargar, alLiberar: e.organiza ? _liberar : null),
          if (e.modulo('invitados')) _invitados(e),
          if (e.modulo('amigoSecreto')) AmigoSecretoTarjeta(repo: _social, estado: e, alCambiar: _cargar),
          if (e.modulo('regaloRobado')) RegaloRobadoTarjeta(estado: e),
          if (e.modulo('comida')) ComidaTarjeta(repo: _social, estado: e, alCambiar: _cargar),
          if (e.playlist != null) PlaylistTarjeta(datos: e.playlist!),
          if (e.dress != null) DressTarjeta(texto: '${e.dress!['texto'] ?? ''}'),
          if (e.social?['traer'] == true) TraerTarjeta(repo: _social, estado: e, alCambiar: _cargar),
          if (e.premios != null) PremiosTarjeta(lista: e.premios!),
          // Personas a cargo con su contacto, para consultar dudas (Victor, 2026-11-20).
          if (e.aCargo.isNotEmpty) ACargoTarjeta(personas: e.aCargo),
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
Future<bool?> editarSocial(BuildContext context, EventosRepo repo, Evento ev) async {
  final s = repo.sesion;
  final social = SocialRepo.miembro(s.api, idEvento: ev.id, adminToken: s.adminToken);
  try {
    final estado = await social.cargar();
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
