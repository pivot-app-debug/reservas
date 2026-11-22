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
import 'social_editar_tarjetas.dart';
import 'social_repo.dart';
import 'social_widgets.dart';
import 'pistas_screen.dart';
import 'social_vista.dart';

/// Secciones del "Social o fiesta" en su detalle (NAVIQUINDE.md): encabezado
/// (nombre, sorpresa, aprobación), +1, amigo secreto, regalo robado, comida,
/// playlist, dress code, qué traer, homenaje y premios. Se recarga al cambiar
/// la asistencia. Lo que no le toca ver a cada quien no llega del servidor.
class SocialEnEvento extends StatefulWidget {
  const SocialEnEvento({super.key, required this.repo, required this.evento});
  final EventosRepo repo;
  final Evento evento;

  @override
  State<SocialEnEvento> createState() => SocialEnEventoState();
}

class SocialEnEventoState extends State<SocialEnEvento> {
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
      guardarEstadoSocial(widget.evento.id, e);
      if (mounted) {
        setState(() {
          _estado = e;
          _error = null;
        });
        // Recién marcó Asistiré: ¿participa del amigo secreto y del regalo robado?
        if (!_preguntado && e.asiste && !e.respondioParticipa) {
          _preguntado = true;
          unawaited(preguntarParticipacion(context, _social, e, _cargar));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  bool _preguntado = false;

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

  Future<void> _editarResponsables() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CrearSocialScreen(sesion: widget.repo.sesion, repo: _social, actual: _estado, abrirEncargados: true),
      ),
    );
    if (ok == true) unawaited(_cargar());
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
              : 'Entran $n personas (quienes marcaron Asistiré y sus invitadxs). Se sortea a quién le regala cada persona y se les avisa para que lo descubran en el evento. Quien se sume después no entra al amigo secreto.',
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
  /// Mientras se crea el enlace el botón muestra que está trabajando; el
  /// menú para enviarlo se abre enseguida y la lista se recarga detrás
  /// (Victor, 2026-11-20: "lo toqué y no responde").
  bool _creandoInvitado = false;

  Future<void> _agregarInvitado() async {
    if (_creandoInvitado) return;
    setState(() => _creandoInvitado = true);
    versionSocial.value++;
    try {
      final inv = await _social.agregarInvitado('', '');
      if (!mounted) return;
      setState(() => _creandoInvitado = false);
      versionSocial.value++;
      unawaited(_cargar());
      await _compartir(inv);
    } catch (e) {
      if (mounted) avisarSocial(context, e.toString());
    } finally {
      if (mounted && _creandoInvitado) {
        setState(() => _creandoInvitado = false);
        versionSocial.value++;
      }
    }
  }

  String _mensaje(Map<String, dynamic> inv) {
    final ev = widget.evento;
    final titulo = _estado?.titulo ?? '';
    final que = titulo.isEmpty ? 'nuestro evento' : '"$titulo"';
    final n = '${inv['nombre'] ?? ''}'.trim();
    return '${n.isEmpty ? 'Hola' : 'Hola, $n'}. Te invito a ${ev.lugar.isEmpty ? que : '$que en ${ev.lugar}'} el ${Fechas.corta(ev.fecha)}. '
        'Entra aquí (sin crear cuenta) para ver todo el evento: ${inv['enlace']}';
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
              title: Text('${inv['nombre'] ?? ''}'.isEmpty ? 'Enlace para tu invitadx' : 'Enlace de ${inv['nombre']}'),
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
    // Se ve que está quitando y no se traba (Victor, 2026-11-22).
    setState(() => _quitando.add('${inv['id']}'));
    versionSocial.value++;
    try {
      await _social.quitarInvitado('${inv['id']}');
      await _cargar();
    } catch (e) {
      if (mounted) avisarSocial(context, e.toString());
    } finally {
      if (mounted) setState(() => _quitando.remove('${inv['id']}'));
      versionSocial.value++;
    }
  }

  final _quitando = <String>{};

  Widget _invitados(EstadoSocial e) {
    final p = context.pivot;
    final lista = e.misInvitados;
    final max = e.maxInvitados;
    return TarjetaSocial(
      titulo: 'Invitadxs',
      icono: Icons.person_add_alt_1_outlined,
      estado: e.asiste ? '${lista.length} de $max' : null,
      estadoActivo: lista.length < max,
      accion: e.puedeArea('invitados') ? EditarTarjetas.boton(() => EditarTarjetas(context, _social, e, _cargar).invitados()) : null,
      children: [
        // Texto de Victor (2026-11-21), en español neutro.
        Text(
          'Puedes invitar a ${max == 1 ? 'alguien' : 'hasta $max personas'} que no ${max == 1 ? 'esté' : 'estén'} en el equipo con un enlace. '
          '${max == 1 ? 'Esa persona decide' : 'Cada una decide'} si participa en algunas actividades del evento y no necesita registrarse en Pivot.',
          style: TextStyle(color: p.textoSecundario),
        ),
        const SizedBox(height: 8),
        if (!e.asiste)
          Text('Marca Asistiré para invitar a alguien.', style: TextStyle(color: p.textoSecundario))
        else ...[
          for (final inv in lista)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(inv['entro'] == false ? Icons.schedule_send_outlined : Icons.person_outline_rounded),
              // Sin abrir el enlace todavía: invitación pendiente (no sabemos si se envió).
              title: Text(inv['entro'] == false ? 'Invitación pendiente' : '${inv['nombre']}'),
              subtitle: Text(
                [
                  if (inv['entro'] == false) 'Todavía no abre su enlace',
                  if ('${inv['contacto'] ?? ''}'.isNotEmpty) '${inv['contacto']}',
                  if (inv['enSorteo'] == true) 'En el amigo secreto',
                ].join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(tooltip: 'Enviar enlace', icon: const Icon(Icons.send_outlined), onPressed: () => _compartir(inv)),
                  if (inv['enSorteo'] != true)
                    _quitando.contains('${inv['id']}')
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close_rounded), onPressed: () => _quitarInvitado(inv)),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: lista.length >= max
                ? Text(max == 1 ? 'Ya invitaste a alguien.' : 'Ya invitaste a $max personas.', style: TextStyle(color: p.textoSecundario))
                : TextButton.icon(
                    onPressed: _creandoInvitado ? null : _agregarInvitado,
                    icon: _creandoInvitado
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_rounded),
                    label: Text(_creandoInvitado ? 'Creando el enlace…' : (lista.isEmpty ? 'Invitar a alguien' : 'Invitar a otra persona')),
                  ),
          ),
        ],
      ],
    );
  }

  // ─── Subsecciones (Victor, 2026-11-21) ──────────────────────────────────

  String get _id => widget.evento.id;

  Future<void> recargar() => _cargar();

  Future<void> abrirQueLleva() => abrirSubseccionSocial(
    context,
    idEvento: _id,
    titulo: 'Qué llevar',
    contenido: (e) => QueLlevarVista(
      repo: _social,
      estado: e,
      alCambiar: _cargar,
      asisten: [for (final r in widget.evento.con(EstadoRsvp.asistire)) (r.persona.username, r.persona.nombreMostrar)],
    ),
  );

  Future<void> abrirActividad(String que) => abrirSubseccionSocial(
    context,
    idEvento: _id,
    titulo: switch (que) {
      'amigo' => 'Amigo secreto',
      'robado' => 'Regalo robado',
      'playlist' => 'Playlist',
      'dress' => 'Dress code',
      _ => 'Premios',
    },
    contenido: (e) => switch (que) {
      'amigo' => AmigoSecretoTarjeta(
        repo: _social,
        estado: e,
        alCambiar: _cargar,
        pronombres: widget.repo.sesion.datos['pronombres'],
        organizar: e.organiza && e.estadoAprobacion == 'publicado' ? _organizar(e) : null,
      ),
      'robado' => RegaloRobadoTarjeta(estado: e, repo: _social, alCambiar: _cargar),
      'playlist' =>
        e.playlist == null
            ? const SizedBox.shrink()
            : PlaylistTarjeta(datos: e.playlist!, alEditar: e.puedeArea('extras') ? () => EditarTarjetas(context, _social, e, _cargar).playlist() : null),
      'dress' => DressTarjeta(
        texto: '${e.dress?['texto'] ?? ''}',
        alEditar: e.puedeArea('extras') ? () => EditarTarjetas(context, _social, e, _cargar).dress() : null,
      ),
      _ => PremiosTarjeta(lista: e.premios ?? const []),
    },
  );

  /// Dudas y preguntas: las personas a cargo, desde la barra del evento.
  /// Quien creó el evento toca a alguien para elegir de qué está a cargo, y
  /// con el lápiz suma o quita encargadxs (Victor, 2026-11-22).
  Future<void> abrirDudas() => abrirSubseccionSocial(
    context,
    idEvento: _id,
    titulo: 'Dudas y preguntas',
    contenido: (e) {
      final edita = e.organiza && e.editable?['misPermisos'] is! List;
      return ACargoTarjeta(personas: e.aCargo, redes: _redes, alTocarPersona: edita ? (u) => _rolDe(e, u) : null, alEditar: edita ? _editarResponsables : null);
    },
  );

  static const _areasACargo = [
    ('fecha', 'Fecha, hora y lugar', Icons.event_outlined),
    ('amigo', 'Amigo secreto y regalo robado', Icons.redeem_rounded),
    ('comida', 'Qué llevar', Icons.restaurant_rounded),
    ('extras', 'Playlist, dress code y premios', Icons.music_note_rounded),
    ('invitados', 'Invitadxs', Icons.person_add_alt_rounded),
    ('homenaje', 'Homenaje y sorpresa', Icons.favorite_border_rounded),
  ];

  /// De qué está a cargo unx encargadx (panel corto desde abajo).
  Future<void> _rolDe(EstadoSocial e, String usuario) async {
    final ed = e.editable ?? const {};
    final encargados = [for (final x in (ed['encargados'] as List? ?? const [])) '$x'];
    final permisos = <String, Set<String>>{
      for (final u in encargados)
        u: {
          for (final a in ((ed['permisos'] as Map?)?[u] as List? ?? const ['fecha', 'amigo', 'comida', 'extras', 'invitados'])) '$a',
        },
    };
    final mio = {...permisos[usuario] ?? const <String>{}};
    final nombre = '${e.aCargo.where((x) => x['username'] == usuario).firstOrNull?['nombre'] ?? usuario}';
    final r = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (h) => StatefulBuilder(
        builder: (h, set) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('¿De qué está a cargo $nombre?', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final (clave, texto, icono) in _areasACargo)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(icono),
                    title: Text(texto),
                    value: mio.contains(clave),
                    onChanged: (v) => set(() => v == true ? mio.add(clave) : mio.remove(clave)),
                  ),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.pop(h, 'guardar'), child: const Text('Guardar')),
                TextButton(onPressed: () => Navigator.pop(h, 'quitar'), child: const Text('Ya no es encargadx')),
              ],
            ),
          ),
        ),
      ),
    );
    if (r == null || !mounted) return;
    if (r == 'quitar') {
      encargados.remove(usuario);
      permisos.remove(usuario);
    } else {
      permisos[usuario] = mio;
    }
    try {
      await _social.guardar({
        'encargados': encargados,
        'permisos': {for (final u in encargados) u: permisos[u]!.toList()},
      });
      await _cargar();
    } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  /// Invitar a alguien de fuera del equipo (desde Tu asistencia).
  // Subsección (Victor, 2026-11-22): antes una hoja, y lo que se abría desde
  // ahí quedaba debajo.
  Future<void> abrirInvitados() => abrirSubseccionSocial(context, idEvento: _id, titulo: 'Invitadxs', contenido: _invitados);

  Future<void> participarAmigo() async {
    final e = _estado;
    if (e == null) return;
    await EditarTarjetas(context, _social, e, _cargar).participacion(amigo: true);
  }

  Future<void> abrirDeseos() async {
    final e = _estado;
    if (e == null) return;
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PistasScreen(repo: _social, inicial: e.perfil),
      ),
    );
    if (cambio == true) unawaited(_cargar());
  }

  // ─── Estás a cargo (Victor, 2026-11-20) ─────────────────────────────────
  // A quien nombraron encargadx le decimos de qué está a cargo, qué se espera
  // y le damos atajos para gestionarlo (comida, amigo secreto, playlist…).

  final _kComida = GlobalKey();

  /// Áreas de las que está a cargo quien mira (solo encargadxs, no quien creó el evento).
  List<String> _aCargoDe(EstadoSocial e) {
    final m = e.editable?['misPermisos'];
    if (!e.organiza || m is! List) return const [];
    return [
      for (final a in m)
        if (switch ('$a') {
          'comida' => e.modulo('comida'),
          'amigo' => e.modulo('amigoSecreto') || e.modulo('regaloRobado'),
          'extras' => e.playlist != null || e.dress != null,
          'invitados' => e.modulo('invitados'),
          'fecha' => true,
          _ => false,
        })
          '$a',
    ];
  }

  Widget _estasACargo(EstadoSocial e) {
    final p = context.pivot;
    final areas = _aCargoDe(e);
    final editar = EditarTarjetas(context, _social, e, _cargar);
    Widget atajo(IconData i, String t, VoidCallback f) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), alignment: Alignment.centerLeft),
        onPressed: f,
        icon: Icon(i),
        label: Text(t),
      ),
    );
    final faltan = [
      for (final c in e.comida)
        if (c.falta || (c.meta > 0 && c.aportado < c.meta)) c.nombre,
    ];
    return TarjetaSocial(
      titulo: 'Estás a cargo',
      icono: Icons.assignment_ind_outlined,
      children: [
        Text(
          'Quien organiza te dejó a cargo de esto. Puedes cambiarlo cuando quieras y quienes van verán los cambios.',
          style: TextStyle(color: p.textoSecundario),
        ),
        if (areas.contains('comida')) ...[
          const SizedBox(height: 12),
          Text(
            'Lo que lleva cada quien',
            style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
          ),
          const SizedBox(height: 2),
          Text(
            faltan.isEmpty
                ? 'Por ahora no falta nada. Si se necesita algo más, agrega una sección o márcala como "Hace falta".'
                : 'Falta aún para el evento: ${faltan.join(', ')}.',
            style: TextStyle(fontSize: 13, color: p.textoSecundario),
          ),
          atajo(Icons.restaurant_rounded, 'Gestionar lo que lleva cada quien', abrirQueLleva),
        ],
        if (areas.contains('amigo')) ...[
          if (e.modulo('amigoSecreto')) atajo(Icons.redeem_rounded, 'Editar el amigo secreto (tope y cierre)', editar.amigo),
          if (e.modulo('regaloRobado')) atajo(Icons.card_giftcard_rounded, 'Editar el regalo robado', editar.robado),
        ],
        if (areas.contains('extras')) ...[
          if (e.playlist != null) atajo(Icons.queue_music_rounded, 'Editar la playlist', editar.playlist),
          if (e.dress != null) atajo(Icons.checkroom_rounded, 'Editar el dress code', editar.dress),
        ],
        if (areas.contains('invitados')) atajo(Icons.person_add_alt_1_outlined, 'Editar lxs invitadxs', editar.invitados),
        if (areas.contains('fecha'))
          atajo(Icons.event_outlined, 'Cambiar fecha, hora o lugar', () async {
            await editarSocial(context, widget.repo, widget.evento);
            if (mounted) unawaited(_cargar());
          }),
      ],
    );
  }

  Widget _organizar(EstadoSocial e) {
    final p = context.pivot;
    final a = e.admin ?? const {};
    final cierre = e.cierre;
    final hoy = Fechas.hoy();
    final yaCerro = cierre != null && !hoy.isBefore(cierre);
    // Va al final de la tarjeta Amigo secreto (Victor, 2026-11-20: una sola tarjeta).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 28),
        Text(
          'Organizar',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.textoSecundario),
        ),
        const SizedBox(height: 6),
        Text(
          '${a['participantes'] ?? 0} personas en el amigo secreto (${a['invitados'] ?? 0} invitadxs)'
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
          if (_aCargoDe(e).isNotEmpty) _estasACargo(e),
          if (e.paraTi != null) ParaTiTarjeta(mensajes: e.paraTi!),
          if (e.homenaje != null) HomenajeTarjeta(repo: _social, estado: e, alCambiar: _cargar, alLiberar: e.organiza ? _liberar : null),
          // Vista nueva (Victor, 2026-11-21): Qué lleva resumida y fija, y las
          // actividades en cards que se deslizan. Cada una abre su subsección.
          if (e.modulo('comida'))
            KeyedSubtree(
              key: _kComida,
              child: QueLlevaResumen(repo: _social, estado: e, alCambiar: _cargar, alAbrir: abrirQueLleva),
            ),
          ActividadesSocial(estado: e, alAbrir: abrirActividad),
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
    var estado = estadosSociales[ev.id];
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
