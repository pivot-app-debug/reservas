import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/espacio_barra.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/moneda.dart';
import '../../core/pronombres.dart';
import '../../core/tema.dart';
import '../widgets_comunes.dart';
import 'mensajeria.dart';
import 'pistas_screen.dart';
import 'que_lleva_calculo.dart';
import 'social_editar_tarjetas.dart';
import 'social_juego_screen.dart';
import 'social_repo.dart';

/// Piezas del evento Social que comparten la cuenta del equipo (detalle del
/// evento) y lx invitadx +1 sin cuenta (InvitadoSocialScreen).

class TarjetaSocial extends StatelessWidget {
  const TarjetaSocial({super.key, required this.titulo, this.icono, required this.children, this.accion, this.estado, this.estadoActivo = true});
  final String titulo;
  final IconData? icono;
  final List<Widget> children;
  final Widget? accion;

  /// Pastilla de estado a la derecha del título ("Participas", "50 %"), para
  /// saber qué te toca sin leer la tarjeta (Victor, 2026-11-20).
  final String? estado;

  /// Rosada si te toca o ya estás; gris si es solo un dato.
  final bool estadoActivo;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    // Dentro de una subsección va sin marco ni título: los pone la pantalla, y
    // el lápiz sube a su barra (Victor, 2026-11-21: los lápices se veían colgados).
    final sinMarco = context.dependOnInheritedWidgetOfExactType<SinMarcoSocial>();
    if (sinMarco != null) {
      final barra = sinMarco.accion;
      if (barra != null) WidgetsBinding.instance.addPostFrameCallback((_) => barra.value = accion);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (accion != null && barra == null) Align(alignment: Alignment.centerRight, child: accion),
          ...children,
        ],
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.grande)),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icono != null) ...[IconoTarjetaSocial(icono: icono!), const SizedBox(width: 10)],
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
                  ),
                ),
                if (estado != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Etiqueta(texto: estado!, apagada: !estadoActivo),
                  ),
                ],
                ?accion,
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Ícono de tarjeta en un cuadrito de color (mismo formato en toda la fiesta).
class IconoTarjetaSocial extends StatelessWidget {
  const IconoTarjetaSocial({super.key, required this.icono});
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.chip)),
      child: Icon(icono, size: 18, color: p.marcaTexto),
    );
  }
}

/// Marca que una tarjeta va dentro de otra (filas de "Detalles").
class SinMarcoSocial extends InheritedWidget {
  const SinMarcoSocial({super.key, required super.child, this.accion});

  /// Si está, el lápiz de la tarjeta va a la barra de la pantalla.
  final ValueNotifier<Widget?>? accion;
  static bool de(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SinMarcoSocial>() != null;
  @override
  bool updateShouldNotify(SinMarcoSocial oldWidget) => false;
}

/// Detalles de la fiesta en filas (Victor, 2026-11-20): dress code, playlist,
/// premios y dudas. Cada fila muestra una línea y se abre al tocarla.
class DetallesSocial extends StatefulWidget {
  const DetallesSocial({super.key, required this.filas});

  /// (ícono, título, resumen, contenido)
  final List<(IconData, String, String, Widget)> filas;

  @override
  State<DetallesSocial> createState() => _DetallesSocialState();
}

class _DetallesSocialState extends State<DetallesSocial> {
  final _abiertas = <String>{};

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.grande)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Detalles',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.textoSecundario),
            ),
          ),
          for (final (i, (icono, titulo, resumen, contenido)) in widget.filas.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: p.tarjetaBorde),
            InkWell(
              onTap: () => setState(() => _abiertas.contains(titulo) ? _abiertas.remove(titulo) : _abiertas.add(titulo)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(icono, size: 20, color: p.marcaTexto),
                    const SizedBox(width: 12),
                    Text(
                      titulo,
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.texto),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _abiertas.contains(titulo) ? '' : resumen,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 13, color: p.textoSecundario),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _abiertas.contains(titulo) ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more_rounded, color: p.textoSecundario),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _abiertas.contains(titulo)
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: SinMarcoSocial(child: contenido),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

String montoSocial(num? n, [String? simbolo]) {
  if (n == null) return '';
  final s = (simbolo == null || simbolo.isEmpty) ? Moneda.s : simbolo;
  return '$s${n == n.roundToDouble() ? n.toInt() : n.toStringAsFixed(2)}';
}

String cantidadSocial(num n) => n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(1);

/// Formulario en un panel que sube desde abajo (Victor, 2026-11-20): se pone
/// encima del teclado, usa todo el alto libre y los botones siempre se ven.
Future<bool?> hojaFormulario(
  BuildContext context, {
  required String titulo,
  required String accion,
  required Widget Function(BuildContext context, StateSetter set) contenido,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (h) => StatefulBuilder(
      builder: (h, set) {
        final teclado = MediaQuery.viewInsetsOf(h).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: teclado),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(titulo, style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Flexible(
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 8), child: contenido(h, set)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 12 + (teclado > 0 ? 0 : MediaQuery.paddingOf(h).bottom)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(h, false), child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () => Navigator.pop(h, true), child: Text(accion)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Al marcar Asistiré en una fiesta (Victor, 2026-11-20): ¿participas del
/// amigo secreto y del regalo robado? Se pregunta una vez; si se cierra sin
/// responder, cuenta como que sí participa.
Future<void> preguntarParticipacion(BuildContext context, SocialRepo repo, EstadoSocial e, VoidCallback alCambiar) async {
  final fase = e.juegoRobado['fase'];
  final amigo = e.modulo('amigoSecreto') && e.inscripcionAbierta && !e.sorteado;
  final robado = e.modulo('regaloRobado') && e.inscripcionAbierta && (fase == null || fase == 'pila');
  if (!e.asiste || e.respondioParticipa || (!amigo && !robado)) return;
  var siAmigo = e.participaAmigo, siRobado = e.participaRobado;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (h) => StatefulBuilder(
      builder: (h, set) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¡Vas a la fiesta!', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Cuéntanos si participas, así se te toma en cuenta. Lo puedes cambiar después desde cada tarjeta.',
                style: TextStyle(color: h.pivot.textoSecundario),
              ),
              const SizedBox(height: 8),
              if (amigo)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.redeem_rounded),
                  title: const Text('Participo del amigo secreto'),
                  value: siAmigo,
                  onChanged: (v) => set(() => siAmigo = v),
                ),
              if (robado)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.card_giftcard_rounded),
                  title: const Text('Juego al regalo robado'),
                  value: siRobado,
                  onChanged: (v) => set(() => siRobado = v),
                ),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => Navigator.pop(h), child: const Text('Listo')),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    await repo.participar(amigo: amigo ? siAmigo : null, robado: robado ? siRobado : null);
    alCambiar();
  } catch (_) {}
}

/// Formulario grande en su propia pantalla (Victor, 2026-11-20): lo que tiene
/// muchos campos va en una subsección; lo corto, en [hojaFormulario].
Future<bool?> pantallaFormulario(
  BuildContext context, {
  required String titulo,
  required String accion,
  required Widget Function(BuildContext context, StateSetter set) contenido,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => StatefulBuilder(
        builder: (h, set) => Scaffold(
          appBar: AppBar(
            title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 16), child: contenido(h, set)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () => Navigator.pop(h, true),
                    child: Text(accion),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void avisarSocial(BuildContext context, String texto) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
}

// ─── Ficha del amigo secreto ──────────────────────────────────────────────

class FichaAmigoVista extends StatelessWidget {
  const FichaAmigoVista({super.key, required this.ficha, this.tope, this.simbolo});
  final FichaAmigo ficha;
  final num? tope;
  final String? simbolo;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final pf = ficha.perfil;
    Widget bloque(String titulo, List<String> items, {bool apagado = false}) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textoSecundario),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in items) Etiqueta(texto: t, apagada: apagado)],
            ),
          ],
        ),
      );
    }

    final tallas = [
      if ((pf.tallas['camiseta'] ?? '').isNotEmpty) 'Camiseta: ${pf.tallas['camiseta']}',
      if ((pf.tallas['medias'] ?? '').isNotEmpty) 'Medias: ${pf.tallas['medias']}',
      if ((pf.tallas['otra'] ?? '').isNotEmpty) '${pf.tallas['otra']}',
    ];
    final deseos = pf.wishlist;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AvatarPersona(nombre: ficha.nombre, foto: ficha.foto, tamano: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ficha.nombre,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.texto),
                  ),
                  if (ficha.invitadxDe != null) Text('Invitadx de ${ficha.invitadxDe}', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                  if (tope != null) Text('Tope del regalo: ${montoSocial(tope, simbolo)}', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                ],
              ),
            ),
          ],
        ),
        if (pf.vacio)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Todavía no agregó pistas. Vuelve a mirar más adelante.', style: TextStyle(color: p.textoSecundario)),
          ),
        bloque('Le gusta', pf.gustos),
        bloque('Sobre su persona', pf.sobreMi),
        bloque('Prefiere que no le regalen', pf.noRegalar, apagado: true),
        bloque('Tallas', tallas),
        if (deseos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Lista de deseos',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textoSecundario),
          ),
          for (final d in deseos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.card_giftcard_rounded, color: p.textoSecundario),
              title: Text(d.texto, style: TextStyle(color: p.texto)),
              subtitle: d.nota.isEmpty ? null : Text(d.nota),
              trailing: d.link.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Abrir enlace',
                      icon: const Icon(Icons.open_in_new_rounded),
                      onPressed: () => launchUrl(Uri.parse(d.link), mode: LaunchMode.externalApplication),
                    ),
            ),
        ],
        // Wishlist externa (Wishdeck, Amazon u otra).
        if (pf.wishlistLink.isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(pf.wishlistLink), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Ver su lista de deseos en otra app'),
          ),
        ],
      ],
    );
  }
}

// ─── Amigo secreto (estado, ruleta y ficha oculta) ────────────────────────

class AmigoSecretoTarjeta extends StatefulWidget {
  const AmigoSecretoTarjeta({super.key, required this.repo, required this.estado, required this.alCambiar, this.simbolo, this.pronombres, this.organizar});
  final SocialRepo repo;

  /// Para quien organiza: inscritxs, cierre y sorteo, en la misma tarjeta (Victor, 2026-11-20).
  final Widget? organizar;

  /// Pronombres de quien mira: los textos para la persona se adaptan (Victor, 2026-11-20).
  final Object? pronombres;
  final EstadoSocial estado;
  final VoidCallback alCambiar;
  final String? simbolo;

  @override
  State<AmigoSecretoTarjeta> createState() => _AmigoSecretoTarjetaState();
}

class _AmigoSecretoTarjetaState extends State<AmigoSecretoTarjeta> {
  bool _visible = false;

  Future<void> _girar() async {
    final ficha = await Navigator.of(context).push<FichaAmigo>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => EspacioBarraAbajo(
          child: RuletaScreen(repo: widget.repo, tope: widget.estado.topeAmigo, simbolo: widget.simbolo),
        ),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
    if (ficha != null) widget.alCambiar();
  }

  Future<void> _pistas() async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PistasScreen(repo: widget.repo, inicial: widget.estado.perfil),
      ),
    );
    if (cambio == true) widget.alCambiar();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final e = widget.estado;
    final cierre = e.cierre;
    final estado = e.estadoAmigo;
    final pf = e.perfil;
    final ficha = e.ficha;
    final List<Widget> contenido = [];
    if (e.topeAmigo != null) {
      contenido.add(Text('Tope del regalo: ${montoSocial(e.topeAmigo, widget.simbolo)}', style: TextStyle(color: p.texto)));
      contenido.add(const SizedBox(height: 6));
    }
    switch (estado) {
      case 'sin_sorteo' when e.asiste && !e.participaAmigo:
        // Eligió no participar (Victor, 2026-11-20).
        contenido.add(
          Text(
            'Elegiste no participar del amigo secreto. Igual vienes a la fiesta.${e.inscripcionAbierta ? ' Para cambiarlo, toca el lápiz.' : ''}',
            style: TextStyle(color: p.textoSecundario),
          ),
        );
      case 'sin_sorteo':
        contenido.add(
          Text(
            !e.asiste
                ? 'Confirma tu asistencia para entrar al amigo secreto.'
                : e.inscripcionAbierta && cierre != null
                ? conPronombres(
                    'Estás inscritx. El sorteo se hace al cerrar la inscripción, el ${cierre.day}/${cierre.month}. Mientras tanto, completa tus pistas.',
                    widget.pronombres,
                  )
                : 'La inscripción cerró. Pronto se hará el sorteo.',
            style: TextStyle(color: p.textoSecundario),
          ),
        );

      case 'fuera':
        // Fuera del sorteo: se dice por qué y no se piden pistas (Victor, 2026-11-20).
        contenido.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: p.marcaTexto),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.asiste && !e.participaAmigo
                        ? 'Elegiste no participar del amigo secreto. Igual vienes a la fiesta.'
                        : e.asiste
                        ? 'No participas en el amigo secreto: marcaste Asistiré después de que se hizo el sorteo. Igual vienes a la fiesta.'
                        : 'El sorteo del amigo secreto ya se hizo. Si marcas Asistiré, vienes a la fiesta pero no participas en el amigo secreto.',
                    style: TextStyle(color: p.sobreSuave),
                  ),
                ),
              ],
            ),
          ),
        );
      case 'por_revelar':
        contenido.add(Text('¡Ya se hizo el sorteo! Gira tu ruleta para saber a quién le regalas.', style: TextStyle(color: p.texto)));
        contenido.add(const SizedBox(height: 12));
        contenido.add(
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _girar,
            icon: const Icon(Icons.casino_outlined),
            label: const Text('Girar mi ruleta'),
          ),
        );
      case 'revelado':
        if (e.amigoEntregaDespues) {
          contenido.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Tu amigo secreto no podrá ir a la fiesta, pero sigue participando: entrégale tu regalo después.',
                style: TextStyle(fontWeight: FontWeight.w600, color: p.marcaTexto),
              ),
            ),
          );
        }
        contenido.add(
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            onPressed: () => setState(() => _visible = !_visible),
            icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            label: Text(_visible ? 'Ocultar' : 'Ver mi amigo secreto'),
          ),
        );
        contenido.add(
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SizeTransition(sizeFactor: a, child: c),
            ),
            child: _visible && ficha != null
                ? Padding(
                    key: const ValueKey('ficha'),
                    padding: const EdgeInsets.only(top: 14),
                    child: FichaAmigoVista(ficha: ficha, tope: e.topeAmigo, simbolo: widget.simbolo),
                  )
                : const SizedBox(key: ValueKey('oculta'), width: double.infinity),
          ),
        );
    }
    contenido.add(const SizedBox(height: 12));
    final fuera = estado == 'fuera' || (e.asiste && !e.participaAmigo);
    contenido.add(
      ListTile(
        // Fuera del sorteo, las pistas y la wishlist quedan deshabilitadas.
        enabled: !fuera,
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.lightbulb_outline_rounded, color: fuera ? p.textoSecundario : p.marcaTexto),
        title: Text(
          'Mis pistas y lista de deseos',
          style: TextStyle(color: p.texto, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          fuera
              ? 'No hace falta: esta vez no participas'
              : pf.vacio
              ? 'Cuéntale a tu amigo secreto qué te gusta'
              : '${pf.gustos.length + pf.sobreMi.length + pf.noRegalar.length} pistas · ${pf.wishlist.length} en tu lista de deseos',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: fuera ? null : _pistas,
      ),
    );
    return TarjetaSocial(
      titulo: 'Amigo secreto',
      icono: Icons.redeem_rounded,
      estado: e.asiste ? (e.participaAmigo ? 'Participas' : 'No participas') : null,
      estadoActivo: e.participaAmigo,
      // Lápiz (Victor, 2026-11-20): quien organiza edita la tarjeta (y su participación);
      // el resto, solo si participa, hasta el cierre.
      accion: e.puedeArea('amigo')
          ? EditarTarjetas.boton(() => EditarTarjetas(context, widget.repo, e, widget.alCambiar).amigo())
          : e.asiste && e.inscripcionAbierta && !e.sorteado
          ? EditarTarjetas.boton(() => EditarTarjetas(context, widget.repo, e, widget.alCambiar).participacion(amigo: true))
          : null,
      children: [...contenido, ?widget.organizar],
    );
  }
}

/// Ruleta: gira suave, se detiene y revela a quién le regalas. El sorteo ya
/// está hecho en el servidor; la ruleta solo lo muestra.
class RuletaScreen extends StatefulWidget {
  const RuletaScreen({super.key, required this.repo, this.tope, this.simbolo});
  final SocialRepo repo;
  final num? tope;
  final String? simbolo;

  @override
  State<RuletaScreen> createState() => _RuletaScreenState();
}

class _RuletaScreenState extends State<RuletaScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _giro = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late Animation<double> _angulo = const AlwaysStoppedAnimation(0);
  FichaAmigo? _ficha;
  String? _error;
  bool _girando = false, _listo = false;

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  Future<void> _girar() async {
    if (_girando) return;
    setState(() {
      _girando = true;
      _error = null;
    });
    final azar = math.Random();
    final fin = 2 * math.pi * (6 + azar.nextDouble());
    _angulo = Tween<double>(begin: 0, end: fin).animate(CurvedAnimation(parent: _giro, curve: Curves.easeOutQuart));
    final vuelta = _giro.forward(from: 0);
    try {
      final f = await widget.repo.revelar();
      await vuelta.orCancel.catchError((_) {});
      if (!mounted) return;
      setState(() {
        _ficha = f;
        _listo = true;
      });
    } catch (e) {
      _giro.stop();
      if (mounted) {
        setState(() {
          _girando = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu amigo secreto'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop(_ficha)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: c),
              ),
              child: _listo && _ficha != null
                  ? Column(
                      key: const ValueKey('revelado'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '¡Te tocó!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.marcaTexto),
                        ),
                        const SizedBox(height: 16),
                        FichaAmigoVista(ficha: _ficha!, tope: widget.tope, simbolo: widget.simbolo),
                        const SizedBox(height: 20),
                        Text(
                          'Es secreto: no se lo cuentes a nadie. Lo puedes volver a ver en "Ver mi amigo secreto".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.textoSecundario),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: () => Navigator.of(context).pop(_ficha),
                          child: const Text('Listo'),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('ruleta'),
                      children: [
                        const SizedBox(height: 12),
                        Icon(Icons.arrow_drop_down_rounded, size: 56, color: p.texto),
                        AspectRatio(
                          aspectRatio: 1,
                          child: AnimatedBuilder(
                            animation: _giro,
                            builder: (_, _) => Transform.rotate(
                              angle: _angulo.value,
                              child: CustomPaint(
                                painter: _PintorRuleta(colores: PivotPaleta.confeti, borde: p.tarjeta, texto: p.sobreMarca),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.marcaTexto),
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          onPressed: _girando ? null : _girar,
                          icon: const Icon(Icons.casino_outlined),
                          label: Text(_girando ? 'Girando…' : 'Girar'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PintorRuleta extends CustomPainter {
  _PintorRuleta({required this.colores, required this.borde, required this.texto});
  final List<Color> colores;
  final Color borde, texto;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    const n = 12;
    final rect = Rect.fromCircle(center: c, radius: r);
    final sweep = 2 * math.pi / n;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(rect, i * sweep - math.pi / 2, sweep, true, Paint()..color = colores[i % colores.length]);
      canvas.drawArc(
        rect,
        i * sweep - math.pi / 2,
        sweep,
        true,
        Paint()
          ..color = borde
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final ang = i * sweep - math.pi / 2 + sweep / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: '?',
          style: TextStyle(color: texto, fontSize: r * 0.16, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = c + Offset(math.cos(ang), math.sin(ang)) * r * 0.7;
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
    canvas.drawCircle(c, r * 0.16, Paint()..color = borde);
  }

  @override
  bool shouldRepaint(_PintorRuleta old) => old.colores != colores || old.borde != borde || old.texto != texto;
}

// ─── Comida compartida ────────────────────────────────────────────────────

/// "¿Qué llevamos?" (Victor, 2026-11-20): comida, bebida y cosas en una sola
/// lista de secciones. Todxs ven quién lleva qué para no repetir; quien está a
/// cargo arma las secciones desde aquí, marca lo que hace falta y deja ideas.
class ComidaTarjeta extends StatelessWidget {
  const ComidaTarjeta({
    super.key,
    required this.repo,
    required this.estado,
    required this.alCambiar,
    this.vista = 'todo',
    this.asisten = const [],
    this.alAgregar,
  });
  final SocialRepo repo;
  final EstadoSocial estado;
  final VoidCallback alCambiar;

  /// Qué llevar en 3 pestañas (Victor, 2026-11-22): 'mio' (Yo llevo),
  /// 'resto' (El resto lleva) o 'falta' (lo que hay que llevar). 'todo' = todo junto.
  final String vista;

  /// Quienes van (usuario, nombre): quien organiza ve en "El resto lleva" a quién le falta.
  final List<(String, String)> asisten;

  /// "Agregar algo" en Yo llevo: pasa a la pestaña Falta.
  final VoidCallback? alAgregar;

  /// Anotarse en una sección (desde la tarjeta resumida).
  Future<void> anotarEn(BuildContext context, CategoriaComida c) => _anotar(context, c);

  /// Anotarse (Victor, 2026-11-20): cuánto rinde lo que llevas lo decides tú,
  /// en la unidad de la sección (porciones, litros…).
  /// Siempre se puede llevar de más, aunque la sección o tu parte ya estén cubiertas.
  Future<void> _anotar(BuildContext context, CategoriaComida c, {String? sugerencia}) async {
    final e = estado;
    // Cuánto rinde lo decide quien lleva (Victor, 2026-11-20: "un pollo rinde
    // más"): se pregunta en la unidad de la sección, sin cálculos de la app.
    final enLitros = c.liquida;
    final valor = TextEditingController(text: c.enPorciones || enLitros ? '' : _num(math.max(1, c.porPersona)));
    final detalle = TextEditingController(text: sugerencia ?? '');
    bool? paraTodxs;
    final yaParte = e.miParte;
    final ok = await hojaFormulario(
      context,
      titulo: c.nombre,
      accion: 'Me anoto',
      contenido: (d, set) {
        final p = d.pivot;
        final n = num.tryParse(valor.text.replaceAll(',', '.')) ?? 0;
        final cantidad = n;
        final parte = paraTodxs == false || !e.asiste ? 0.0 : e.parteDe(c, cantidad);
        final secundario = TextStyle(fontSize: 13, color: p.textoSecundario);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.cerrada || c.limite > 0)
              Text(
                c.limite > 0
                    ? 'Quedan ${cantidadSocial(math.max(0, c.limite - c.aportado))} de ${cantidadSocial(c.limite)}.'
                    : 'Esta sección ya está completa, pero igual puedes llevar más.',
                style: secundario,
              )
            else if (c.meta > 0 && !c.porCosa)
              Text('Faltan ${cantidadSocial(math.max(0, c.meta - c.aportado))} ${c.unidad}.', style: secundario),
            if (c.cerrada || c.limite > 0 || (c.meta > 0 && !c.porCosa)) const SizedBox(height: 12),
            TextField(
              controller: detalle,
              autofocus: sugerencia == null,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: c.porCosa ? '¿Qué llevas?' : '¿Qué llevas? (opcional)', counterText: ''),
              onChanged: (_) => set(() {}),
            ),
            if (!c.porCosa) ...[
              const SizedBox(height: 16),
              Text(c.enPorciones ? '¿Cuántas porciones rinde lo que llevas?' : (enLitros ? '¿Cuántos litros llevas?' : '¿Cuánto llevas?')),
              const SizedBox(height: 6),
              _Contador(controller: valor, paso: enLitros ? 0.5 : 1, sufijo: c.unidad, alCambiar: () => set(() {})),
              if (c.enPorciones || enLitros) ...[const SizedBox(height: 6), Text('Tú decides cuánto rinde.', style: secundario)],
            ],
            // "¿Para quién?" solo con cosas de uso personal (vasos, platos,
            // cubiertos): la comida o las servilletas son para todxs (Victor, 2026-11-20).
            if (esDeUsoPersonal(c.nombre) || esDeUsoPersonal(detalle.text)) ...[
              const SizedBox(height: 16),
              const Text('¿Para quién?'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: true, label: Text('Para todxs')),
                    ButtonSegment(value: false, label: Text('Solo para mí')),
                  ],
                  selected: {?paraTodxs},
                  onSelectionChanged: (s) => set(() => paraTodxs = s.isEmpty ? null : s.first),
                ),
              ),
            ],
            if (e.asiste && e.cuentaParaParte(c) && paraTodxs != false) ...[
              const SizedBox(height: 10),
              Text(
                yaParte >= 1
                    ? 'Ya cubriste tu parte. Esto suma de más, ¡gracias!'
                    : (yaParte + parte >= 1 ? 'Con esto cubres tu parte ✓' : 'Con esto llegas al ${((yaParte + parte) * 100).round()} % de tu parte.'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.marcaTexto),
              ),
            ],
          ],
        );
      },
    );
    final v = c.porCosa ? 1 : num.tryParse(valor.text.replaceAll(',', '.'));
    final n = v;
    final texto = detalle.text.trim();
    // Se liberan cuando terminó de cerrarse la ventana (la animación todavía los usa).
    Future.delayed(const Duration(milliseconds: 400), () {
      valor.dispose();
      detalle.dispose();
    });
    if (ok != true || !context.mounted) return;
    if (c.porCosa && texto.isEmpty) return avisarSocial(context, 'Escribe qué llevas.');
    if (n == null || n <= 0) return avisarSocial(context, 'Indica cuánto llevas.');
    try {
      // Si no se preguntó, no se guarda (cuenta como para todxs).
      await repo.anotarComida(c.id, n, texto, paraTodxs: esDeUsoPersonal(c.nombre) || esDeUsoPersonal(texto) ? paraTodxs : null);
      alCambiar();
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  /// Número corto: 1, 1.5, 0.75.
  static String _num(num n) => n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

  // ─── Quien está a cargo ──────────────────────────────────────────────────

  // ─── Secciones por tipo (Victor, 2026-11-20) ──────────────────────────────
  // Comida (porciones) y Bebida (litros): se pide según cuántas personas
  // asisten y lo que come y toma cada una en promedio (lápiz de la tarjeta).
  // Cosas: sin límite, hasta N o 1 cada X personas.

  static const _sugeridas = <(String, String, IconData)>[
    ('Platos salados', 'comida', Icons.dinner_dining_outlined),
    ('Acompañantes', 'comida', Icons.rice_bowl_outlined),
    ('Postres', 'comida', Icons.cake_outlined),
    ('Snacks', 'comida', Icons.cookie_outlined),
    ('Pan', 'comida', Icons.bakery_dining_outlined),
    ('Bebidas', 'bebida', Icons.local_drink_outlined),
    ('Alcohol', 'bebida', Icons.wine_bar_outlined),
    ('Jugos', 'bebida', Icons.emoji_food_beverage_outlined),
    ('Hielo', 'cosas', Icons.ac_unit_rounded),
    ('Vasos y platos', 'cosas', Icons.local_cafe_outlined),
    ('Cubiertos', 'cosas', Icons.restaurant_rounded),
    ('Servilletas', 'cosas', Icons.layers_outlined),
    ('Adornos', 'cosas', Icons.celebration_outlined),
  ];

  /// "+": sugiere lo que todavía no está; o una sección propia.
  Future<void> _agregar(BuildContext context) async {
    final hay = {for (final c in estado.comida) c.nombre.trim().toLowerCase()};
    final libres = [
      for (final x in _sugeridas)
        if (!hay.contains(x.$1.toLowerCase())) x,
    ];
    final elegida = await showModalBottomSheet<(String, String, IconData)?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (h) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Qué agregamos?', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (libres.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final x in libres) ActionChip(avatar: Icon(x.$3, size: 18), label: Text(x.$1), onPressed: () => Navigator.pop(h, x))],
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                onPressed: () => Navigator.pop(h, ('', '', Icons.add_rounded)),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Otra sección'),
              ),
            ],
          ),
        ),
      ),
    );
    if (elegida == null || !context.mounted) return;
    if (elegida.$1.isEmpty) return _editar(context);
    try {
      await repo.editarComida(
        nombre: elegida.$1,
        unidad: switch (elegida.$2) {
          'comida' => 'porciones',
          'bebida' => 'litros',
          _ => 'cosas',
        },
        porPersona: switch (elegida.$2) {
          'comida' => estado.consumoPorciones,
          'bebida' => estado.consumoLitros,
          _ => 1,
        },
        modo: elegida.$2 == 'cosas' ? 'libre' : 'meta',
        cupoTipo: '',
        cupo: 0,
      );
      alCambiar();
      if (context.mounted) avisarSocial(context, 'Se agregó ${elegida.$1}.');
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  /// Lápiz: cuánto come y toma cada persona en promedio.
  Future<void> _consumo(BuildContext context) async {
    final porciones = TextEditingController(text: cantidadSocial(estado.consumoPorciones));
    final litros = TextEditingController(text: cantidadSocial(estado.consumoLitros));
    final ok = await hojaFormulario(
      context,
      titulo: 'Cuánto come y toma cada persona',
      accion: 'Guardar',
      contenido: (d, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Con esto se calcula cuánto pedir según cuántas personas asisten. Si se suma alguien, se ajusta solo para que no falte nada.',
            style: TextStyle(fontSize: 13, color: d.pivot.textoSecundario),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: porciones,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Porciones de comida por persona', suffixText: 'porciones'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: litros,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Bebida por persona', suffixText: 'litros'),
          ),
        ],
      ),
    );
    final po = num.tryParse(porciones.text.replaceAll(',', '.')), li = num.tryParse(litros.text.replaceAll(',', '.'));
    Future.delayed(const Duration(milliseconds: 400), () {
      porciones.dispose();
      litros.dispose();
    });
    if (ok != true || !context.mounted) return;
    try {
      await repo.editarConsumo(porciones: po, litros: li);
      alCambiar();
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  Future<void> _editar(BuildContext context, [CategoriaComida? c]) async {
    final nombre = TextEditingController(text: c?.nombre ?? '');
    final ideas = TextEditingController(text: (c?.sugerencias ?? const []).join(', '));
    // Tipo de la sección (comida, bebida o cosas).
    var tipo = c == null ? 'comida' : (c.enPorciones ? 'comida' : (c.liquida ? 'bebida' : 'cosas'));
    // Cosas: 'libre' | 'hasta' | 'cada'.
    var limite = c == null || c.modo == 'libre' || c.modo == 'cada' ? 'libre' : (c.modo == 'total' ? 'hasta' : 'cada');
    final hasta = TextEditingController(text: c?.modo == 'total' && c?.total != null ? cantidadSocial(c!.total!) : '');
    final cadaX = TextEditingController(
      text: c != null && c.modo == 'meta' && !c.enPorciones && !c.liquida && c.porPersona > 0 ? cantidadSocial(1 / c.porPersona) : '',
    );
    const espacio = SizedBox(height: 16);
    final ok = await pantallaFormulario(
      context,
      titulo: c == null ? 'Agregar sección' : 'Editar ${c.nombre}',
      accion: 'Guardar',
      contenido: (d, set) {
        final secundario = TextStyle(fontSize: 13, color: d.pivot.textoSecundario);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nombre,
              autofocus: c == null,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre de la sección', counterText: ''),
            ),
            espacio,
            const Text('¿Qué es?', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'comida', label: Text('Comida'), icon: Icon(Icons.restaurant_rounded)),
                  ButtonSegment(value: 'bebida', label: Text('Bebida'), icon: Icon(Icons.local_drink_outlined)),
                  ButtonSegment(value: 'cosas', label: Text('Cosas'), icon: Icon(Icons.inventory_2_outlined)),
                ],
                selected: {tipo},
                onSelectionChanged: (x) => set(() => tipo = x.first),
              ),
            ),
            const SizedBox(height: 8),
            if (tipo == 'comida')
              Text(
                'Se pide según cuántas personas asisten: ${cantidadSocial(estado.consumoPorciones)} porciones por persona (lo cambias con el lápiz de la tarjeta).',
                style: secundario,
              ),
            if (tipo == 'bebida')
              Text(
                'Se pide según cuántas personas asisten: ${cantidadSocial(estado.consumoLitros)} litros por persona (lo cambias con el lápiz de la tarjeta).',
                style: secundario,
              ),
            if (tipo == 'cosas') ...[
              espacio,
              const Text('¿Cuántas se necesitan?', style: TextStyle(fontWeight: FontWeight.w700)),
              RadioGroup<String>(
                groupValue: limite,
                onChanged: (v) => set(() => limite = v ?? 'libre'),
                child: Column(
                  children: [
                    const RadioListTile(
                      contentPadding: EdgeInsets.zero,
                      value: 'libre',
                      title: Text('Sin límite'),
                      subtitle: Text('Cada quien lleva lo que quiera.'),
                    ),
                    RadioListTile(
                      contentPadding: EdgeInsets.zero,
                      value: 'hasta',
                      title: const Text('Hasta un número de cosas'),
                      subtitle: limite == 'hasta'
                          ? TextField(
                              controller: hasta,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Máximo', suffixText: 'cosas'),
                            )
                          : null,
                    ),
                    RadioListTile(
                      contentPadding: EdgeInsets.zero,
                      value: 'cada',
                      title: const Text('1 cosa por cada cierto número de personas'),
                      subtitle: limite == 'cada'
                          ? TextField(
                              controller: cadaX,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: '1 cosa por cada…', suffixText: 'personas'),
                            )
                          : const Text('Se ajusta sola con quienes asisten.'),
                    ),
                  ],
                ),
              ),
            ],
            espacio,
            TextField(
              controller: ideas,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Ejemplos para quien se anota (opcional)'),
            ),
            const SizedBox(height: 6),
            Text('Separados por comas. Aparecen como sugerencias para anotarse (ej. en Postres: torta, flan).', style: secundario),
          ],
        );
      },
    );
    final n = nombre.text.trim();
    final h = num.tryParse(hasta.text.replaceAll(',', '.')), x = num.tryParse(cadaX.text.replaceAll(',', '.'));
    final sug = [
      for (final s in ideas.text.split(','))
        if (s.trim().isNotEmpty) s.trim(),
    ];
    Future.delayed(const Duration(milliseconds: 400), () {
      for (final t in [nombre, ideas, hasta, cadaX]) {
        t.dispose();
      }
    });
    if (ok != true || !context.mounted) return;
    if (n.isEmpty) return avisarSocial(context, 'Escribe el nombre de la sección.');
    if (tipo == 'cosas' && limite == 'hasta' && (h == null || h <= 0)) return avisarSocial(context, 'Indica el máximo.');
    if (tipo == 'cosas' && limite == 'cada' && (x == null || x <= 0)) return avisarSocial(context, 'Indica cada cuántas personas.');
    try {
      await repo.editarComida(
        categoriaId: c?.id,
        nombre: n,
        unidad: switch (tipo) {
          'comida' => 'porciones',
          'bebida' => 'litros',
          _ => 'cosas',
        },
        porPersona: switch (tipo) {
          'comida' => estado.consumoPorciones,
          'bebida' => estado.consumoLitros,
          _ => limite == 'cada' ? 1 / x! : 1,
        },
        modo: tipo != 'cosas' ? 'meta' : (limite == 'libre' ? 'libre' : (limite == 'hasta' ? 'total' : 'meta')),
        total: tipo == 'cosas' && limite == 'hasta' ? h : null,
        sugerencias: sug,
        cupoTipo: '',
        cupo: 0,
      );
      alCambiar();
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  Future<void> _accionSeccion(BuildContext context, CategoriaComida c, String accion) async {
    try {
      switch (accion) {
        case 'editar':
          return await _editar(context, c);
        case 'falta':
          await repo.editarComida(categoriaId: c.id, falta: !c.falta);
        case 'borrar':
          final si = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: Text('¿Quitar ${c.nombre}?'),
              content: const Text('Solo se puede si nadie se anotó todavía.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Volver')),
                FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Quitar')),
              ],
            ),
          );
          if (si != true) return;
          await repo.editarComida(categoriaId: c.id, borrar: true);
      }
      alCambiar();
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  /// Para el resumen de la tarjeta (Victor, 2026-11-21: quitar con un "−").
  Future<void> quitarAporte(BuildContext context, String id) => _quitar(context, id);

  Future<void> _quitar(BuildContext context, String id) async {
    try {
      await repo.quitarAporte(id);
      alCambiar();
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  // Sin "para todxs" (Victor, 2026-11-22): es lo normal; solo se aclara lo que es solo para sí.
  static String _para(Object? v) => v == false ? 'solo para sí' : '';

  @override
  Widget build(BuildContext context) => _ListaQueLleva(t: this);
}

/// Rediseño de "Qué lleva cada quien" (Victor, 2026-11-20): cada sección es
/// una fila compacta (nombre, barra fina y un indicador) que se despliega con
/// quién lleva qué. Abiertas solo las que hacen falta y las que te faltan;
/// las completas van al final, agrupadas.
class _ListaQueLleva extends StatefulWidget {
  const _ListaQueLleva({required this.t});
  final ComidaTarjeta t;

  @override
  State<_ListaQueLleva> createState() => _ListaQueLlevaState();
}

class _ListaQueLlevaState extends State<_ListaQueLleva> {
  final Map<String, bool> _abierta = {};
  bool _verCompletadas = false;

  EstadoSocial get _e => widget.t.estado;

  bool _teFalta(CategoriaComida c) => _e.asiste && c.modo == 'cada' && !c.cerrada && c.mias < c.porPersona;
  bool _abiertaPorDefecto(CategoriaComida c) => !c.cerrada && (c.falta || _teFalta(c));

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final t = widget.t;
    final e = _e;
    final total = e.conteo['total'] ?? 0;
    final admin = e.puedeComida;
    final abiertas = e.comida.where((c) => !c.cerrada).toList()..sort((a, b) => (b.falta ? 1 : 0) - (a.falta ? 1 : 0));
    final completas = e.comida.where((c) => c.cerrada).toList();
    // Lo que todavía le falta al grupo, con cuánto (Victor, 2026-11-20: "más directo").
    bool falta(CategoriaComida c) => c.falta || (c.meta > 0 && c.aportado < c.meta);
    final faltan = [
      for (final c in abiertas)
        if (falta(c)) c,
    ];
    final resto = [
      for (final c in abiertas)
        if (!falta(c)) c,
    ];
    final mias = [
      for (final c in e.comida)
        for (final a in c.aportes)
          if (a['mio'] == true) (c, a),
    ];
    if (t.vista == 'mio') return _vistaMia(context, p, mias);
    if (t.vista == 'resto') return _vistaResto(context, p);
    return TarjetaSocial(
      titulo: 'Qué llevar',
      icono: Icons.restaurant_rounded,
      // Lápiz: cuánto come y toma cada persona; "+": agregar con sugerencias (Victor, 2026-11-20).
      accion: admin
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(tooltip: 'Cuánto come y toma cada persona', icon: const Icon(Icons.edit_outlined), onPressed: () => t._consumo(context)),
                IconButton(tooltip: 'Agregar sección', icon: const Icon(Icons.add_rounded), onPressed: () => t._agregar(context)),
              ],
            )
          : null,
      children: [
        Text(
          // Solo cuántxs asisten (Victor, 2026-11-20).
          '${total == 1 ? 'Asiste 1 persona' : 'Asisten $total personas'}.${e.asiste ? '' : ' Confirma tu asistencia para anotarte.'}',
          style: TextStyle(fontSize: 13, color: p.textoSecundario),
        ),
        // Tiene dieta o alergias en Salud sin prender para eventos (solo lo ve esa persona).
        if (e.yo['comidaSinUsar'] == true)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Tienes una dieta o alergias en Salud que no se están tomando en cuenta. Si quieres que se usen (sin tu nombre), '
              'préndelas en Mi perfil → Salud y emergencia → Comida en eventos.',
              style: TextStyle(fontSize: 13, color: p.textoSecundario),
            ),
          ),
        // Alergias e intolerancias de quienes van, sin nombres (Victor, 2026-11-20).
        if (e.comidaAlergias.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: p.sobreSuave),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ten en cuenta: entre quienes van hay alergias o intolerancias a ${e.comidaAlergias.join(', ')}. '
                    'Si lo que llevas lo tiene, avísalo en lo que escribes.',
                    style: TextStyle(color: p.sobreSuave),
                  ),
                ),
              ],
            ),
          ),
        // Tu parte (Victor, 2026-11-20): el termómetro siempre a la vista;
        // la frase y lo que llevas, plegados.
        if (t.vista == 'todo' && ((e.asiste && e.seccionesParte.isNotEmpty) || mias.isNotEmpty))
          _TuParte(
            valor: e.asiste && e.seccionesParte.isNotEmpty ? e.miParte : null,
            secciones: e.seccionesParte.length,
            abierta: _tuParteAbierta,
            alTocar: () => setState(() => _tuParteAbierta = !_tuParteAbierta),
            lleva: [
              for (final (c, a) in mias)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          '${a['detalle'] ?? ''}'.isEmpty ? c.nombre : '${a['detalle']}',
                          if (!c.porCosa) '${cantidadSocial(a['cantidad'] as num)} ${c.unidad}',
                          if (ComidaTarjeta._para(a['paraTodxs']).isNotEmpty) ComidaTarjeta._para(a['paraTodxs']),
                        ].join(' · '),
                        style: TextStyle(color: p.sobreSuave),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Quitar',
                      icon: Icon(Icons.close_rounded, size: 18, color: p.sobreSuave),
                      onPressed: () => t._quitar(context, '${a['id']}'),
                    ),
                  ],
                ),
            ],
          ),
        if (e.comida.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              admin ? 'Todavía no hay secciones. Toca + para agregar la primera.' : 'Quien organiza todavía no armó la lista.',
              style: TextStyle(color: p.textoSecundario),
            ),
          ),
        const SizedBox(height: 4),
        // Falta (Victor, 2026-11-22): todo lo que falta a la vista, sin
        // desplegables ni las completadas.
        if (t.vista == 'falta') ...[
          if (faltan.isEmpty && resto.isEmpty && e.comida.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('No falta nada: todo está cubierto.', style: TextStyle(color: p.textoSecundario)),
            ),
          for (final c in [...faltan, ...resto]) _seccion(context, p, c, admin, fija: true),
        ] else ...[
          // Mismo formato en los tres grupos (Victor, 2026-11-20); solo "Falta aún" en rojo.
          if (faltan.isNotEmpty)
            _grupo(
              p,
              icono: Icons.error_outline_rounded,
              titulo: 'Falta aún para el evento (${faltan.length})',
              color: p.marcaTexto,
              abierto: _verFaltan,
              alTocar: () => setState(() => _verFaltan = !_verFaltan),
              hijos: [for (final c in faltan) _seccion(context, p, c, admin)],
            ),
          if (resto.isNotEmpty)
            _grupo(
              p,
              icono: Icons.add_circle_outline_rounded,
              titulo: 'Abiertas (${resto.length})',
              color: p.textoSecundario,
              abierto: _verResto,
              alTocar: () => setState(() => _verResto = !_verResto),
              hijos: [for (final c in resto) _seccion(context, p, c, admin)],
            ),
          if (completas.isNotEmpty)
            _grupo(
              p,
              icono: Icons.check_circle_rounded,
              titulo: 'Completadas (${completas.length})',
              color: p.textoSecundario,
              abierto: _verCompletadas,
              alTocar: () => setState(() => _verCompletadas = !_verCompletadas),
              hijos: [for (final c in completas) _seccion(context, p, c, admin)],
            ),
        ],
      ],
    );
  }

  bool _tuParteAbierta = false, _verFaltan = true, _verResto = true;

  String _linea(CategoriaComida c, Map a) => [
    '${a['detalle'] ?? ''}'.isEmpty ? c.nombre : '${a['detalle']}',
    if (!c.porCosa) '${cantidadSocial(a['cantidad'] as num)} ${c.unidad}',
    if (ComidaTarjeta._para(a['paraTodxs']).isNotEmpty) ComidaTarjeta._para(a['paraTodxs']),
  ].join(' · ');

  /// Yo llevo: tu parte, lo que llevas (con quitar) y "Agregar algo".
  Widget _vistaMia(BuildContext context, PivotPaleta p, List<(CategoriaComida, Map<String, dynamic>)> mias) {
    final e = _e, t = widget.t;
    final v = e.asiste && e.seccionesParte.isNotEmpty ? e.miParte.clamp(0, 1).toDouble() : null;
    return TarjetaSocial(
      titulo: 'Yo llevo',
      children: [
        if (v != null) ...[
          Row(
            children: [
              Text(
                'Tu parte',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(PivotRadios.chip),
                  child: LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: p.suave, color: p.marca),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(v * 100).round()} %',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.marcaTexto),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            v >= 1 ? 'Ya cubriste tu parte. Si quieres, puedes llevar más.' : 'Con comida o bebida en cualquier sección cubres tu parte.',
            style: TextStyle(fontSize: 13, color: p.textoSecundario),
          ),
          const SizedBox(height: 12),
        ],
        if (!e.asiste)
          Text('Confirma tu asistencia para anotarte.', style: TextStyle(color: p.textoSecundario))
        else if (mias.isEmpty)
          Text('Todavía no te anotaste en ninguna sección.', style: TextStyle(color: p.textoSecundario))
        else
          for (final (c, a) in mias)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: BoxDecoration(
                border: Border.all(color: p.bordeSuave),
                borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nombre, style: TextStyle(fontSize: 12, color: p.textoSecundario)),
                        Text(
                          _linea(c, a),
                          style: TextStyle(fontWeight: FontWeight.w600, color: p.texto),
                        ),
                      ],
                    ),
                  ),
                  IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close_rounded), onPressed: () => t._quitar(context, '${a['id']}')),
                ],
              ),
            ),
        if (e.asiste) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            onPressed: t.alAgregar,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar algo'),
          ),
        ],
      ],
    );
  }

  /// El resto lleva: por sección, quién lleva qué. Quien organiza ve además a
  /// quién le falta completar su parte.
  /// El resto lleva (Victor, 2026-11-22): más grande y claro. Arriba, a quién
  /// le falta completar su parte y cuánto; después cada sección en su
  /// recuadro, con quién lleva qué.
  Widget _vistaResto(BuildContext context, PivotPaleta p) {
    final e = _e;
    final secciones = [
      for (final c in e.comida)
        if (c.aportes.any((a) => a['mio'] != true)) c,
    ];
    final faltaA = e.organiza && e.seccionesParte.isNotEmpty
        ? [
            for (final (u, n) in widget.t.asisten)
              if (e.parteDeUsuario(u) < 1) (u, n, e.parteDeUsuario(u)),
          ]
        : const <(String, String, double)>[];
    final fotos = {
      for (final c in e.comida)
        for (final a in c.aportes) '${a['usuario'] ?? ''}'.toLowerCase(): '${a['foto'] ?? ''}',
    };
    return TarjetaSocial(
      titulo: 'El resto lleva',
      children: [
        if (faltaA.isNotEmpty) ...[
          Text(
            faltaA.length == 1 ? 'A 1 persona le falta completar su parte' : 'A ${faltaA.length} personas les falta completar su parte',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.marcaTexto),
          ),
          const SizedBox(height: 8),
          for (final (u, n, parte) in faltaA)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  AvatarPersona(nombre: n, foto: fotos[u.toLowerCase()] ?? '', tamano: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.texto),
                              ),
                            ),
                            Text(
                              parte <= 0 ? 'Sin anotar' : 'Le falta ${((1 - parte) * 100).round()} %',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.marcaTexto),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(PivotRadios.chip),
                          child: LinearProgressIndicator(value: parte.clamp(0, 1).toDouble(), minHeight: 6, backgroundColor: p.suave, color: p.marca),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (secciones.isEmpty) Text('Nadie más se anotó todavía.', style: TextStyle(fontSize: 15, color: p.textoSecundario)),
        for (final c in secciones)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            decoration: BoxDecoration(
              border: Border.all(color: p.bordeSuave),
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.nombre,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.texto),
                      ),
                    ),
                    Text(
                      '${c.aportes.where((a) => a['mio'] != true).length}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: p.textoSecundario),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final a in c.aportes)
                  if (a['mio'] != true)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          AvatarPersona(nombre: '${a['nombre'] ?? ''}', foto: '${a['foto'] ?? ''}', tamano: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${a['nombre']}',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                                ),
                                Text(_linea(c, a), style: TextStyle(color: p.textoSecundario)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _grupo(
    PivotPaleta p, {
    required IconData icono,
    required String titulo,
    required Color color,
    required bool abierto,
    required VoidCallback alTocar,
    required List<Widget> hijos,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InkWell(
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icono, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
              ),
              AnimatedRotation(
                turns: abierto ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more_rounded, color: color),
              ),
            ],
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: abierto ? Column(children: hijos) : const SizedBox(width: double.infinity),
      ),
    ],
  );

  Widget _seccion(BuildContext context, PivotPaleta p, CategoriaComida c, bool admin, {bool fija = false}) {
    final t = widget.t;
    final abierta = fija || (_abierta[c.id] ?? _abiertaPorDefecto(c));
    final teFalta = _teFalta(c);
    final pide = switch (c.modo) {
      'cada' => 'Cada persona lleva ${cantidadSocial(c.porPersona)}',
      'total' => '${cantidadSocial(c.meta)} ${c.unidad} en total',
      'libre' => 'Libre',
      _ => '${cantidadSocial(c.porPersona)} ${c.unidad} por persona',
    }; // Cupo de las cosas: "· Cupo: 5". Las de dieta dicen de dónde salen.
    final pideConCupo = c.dieta ? '$pide · por la dieta de quienes van' : (c.limite > 0 ? '$pide · Cupo: ${cantidadSocial(c.limite)}' : pide);
    // Un solo indicador a la derecha.
    final Widget indicador = c.cerrada
        ? Icon(Icons.check_circle_rounded, size: 22, color: p.marcaTexto)
        : c.falta
        ? Etiqueta(texto: 'Hace falta', icono: Icons.priority_high_rounded)
        : teFalta
        ? Text(
            'Te ${(c.porPersona - c.mias).ceil() == 1 ? 'falta 1' : 'faltan ${(c.porPersona - c.mias).ceil()}'}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.marcaTexto),
          )
        : Text(
            c.limite > 0
                ? '${cantidadSocial(c.aportado)} de ${cantidadSocial(c.limite)}'
                : c.meta > 0
                ? '${cantidadSocial(c.aportado)} de ${cantidadSocial(c.meta)}'
                : (c.aportes.isEmpty ? 'Nadie aún' : '${c.aportes.length}'),
            style: TextStyle(fontSize: 13, color: p.textoSecundario),
          );
/// Sugerencias contextuales según la categoría y festividad/plantilla (Victor, 2026-11-23).
List<String> sugerenciasParaCategoria(CategoriaComida c, EstadoSocial estado) {
  final base = c.sugerencias;
  if (base.isNotEmpty) return base;

  final nombre = c.nombre.toLowerCase();
  final evNombre = '${estado.evento['nombre'] ?? ''} ${estado.titulo} ${estado.social?['festividad'] ?? ''}'.toLowerCase();
  final esNavidad = evNombre.contains('navi') || evNombre.contains('navidad');
  final esAnoNuevo = evNombre.contains('año nuevo') || evNombre.contains('fin de año') || evNombre.contains('ano nuevo');
  final esHalloween = evNombre.contains('halloween') || evNombre.contains('miedo');

  if (nombre.contains('acompañ')) {
    if (esNavidad) return const ['Arroz navideño', 'Puré de manzana', 'Ensalada rusa'];
    if (esAnoNuevo) return const ['Arroz con frutos secos', 'Ensalada waldorf', 'Papas rústicas'];
    return const ['Arroz', 'Papas fritas', 'Ensalada'];
  }
  if (nombre.contains('salado') || nombre.contains('plato') || nombre.contains('comida')) {
    if (esNavidad) return const ['Pavo', 'Pernil', 'Pollo relleno'];
    if (esAnoNuevo) return const ['Pernil', 'Lasaña', 'Picadas'];
    return const ['Pizza', 'Lasaña', 'Empanadas', 'Pollo asado'];
  }
  if (nombre.contains('bebida') || nombre.contains('trago') || nombre.contains('tomar') || nombre.contains('alcohol')) {
    if (esNavidad) return const ['Ponche navideño', 'Vino tinto', 'Gaseosas'];
    if (esAnoNuevo) return const ['Vino espumante', 'Champaña', 'Cerveza', 'Gaseosas'];
    return const ['Gaseosa', 'Cerveza', 'Agua mineral', 'Jugo'];
  }
  if (nombre.contains('postre') || nombre.contains('dulce')) {
    if (esNavidad) return const ['Panetón', 'Galletas navideñas', 'Tronco navideño'];
    if (esAnoNuevo) return const ['Uvas para las 12', 'Mousse', 'Torta'];
    return const ['Torta', 'Brownies', 'Cheesecake', 'Helado'];
  }
  if (nombre.contains('snack') || nombre.contains('bocadito')) {
    return const ['Papas fritas', 'Doritos', 'Nachos con queso', 'Frutos secos'];
  }
  if (nombre.contains('vaso') || nombre.contains('plato') || nombre.contains('cubierto') || nombre.contains('vajilla')) {
    return const ['Vasos descartables', 'Platos descartables', 'Cubiertos'];
  }
  if (nombre.contains('adorno') || nombre.contains('decor')) {
    if (esNavidad) return const ['Luces navideñas', 'Guirnalda', 'Gorro navideño'];
    if (esAnoNuevo) return const ['Globos dorados', 'Cotillón', 'Serpentinas'];
    if (esHalloween) return const ['Telarañas', 'Calabazas', 'Velas'];
    return const ['Globos', 'Cartel de bienvenida', 'Mantel'];
  }
  return const [];
}

    final tomadas = {for (final a in c.aportes) '${a['detalle'] ?? ''}'.trim().toLowerCase()};
    final rawIdeas = c.sugerencias.isNotEmpty ? c.sugerencias : sugerenciasParaCategoria(c, _e);
    final ideas = [
      for (final s in rawIdeas)
        if (!tomadas.contains(s.trim().toLowerCase())) s,
    ];
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(color: c.falta && !c.cerrada ? p.marca : p.bordeSuave),
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
            onTap: fija ? null : () => setState(() => _abierta[c.id] = !abierta),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.nombre,
                          style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                        ),
                        Text(pideConCupo, style: TextStyle(fontSize: 12, color: p.textoSecundario)),
                      ],
                    ),
                  ),
                  indicador,
                  // Siempre se puede llevar de más, salvo las cosas con el cupo lleno (Victor, 2026-11-20).
                  if (!c.llena)
                    IconButton(
                      tooltip: c.cerrada ? 'Llevar más' : 'Me anoto',
                      icon: Icon(Icons.add_circle_outline_rounded, color: _e.asiste ? p.marcaTexto : p.textoSecundario),
                      onPressed: _e.asiste ? () => t._anotar(context, c) : null,
                    ),
                  if (admin)
                    PopupMenuButton<String>(
                      tooltip: 'Opciones',
                      iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      position: PopupMenuPosition.under,
                      onSelected: (a) => t._accionSeccion(context, c, a),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'editar', child: Text('Editar')),
                        PopupMenuItem(value: 'falta', child: Text(c.falta ? 'Ya no hace falta' : 'Hace falta')),
                        const PopupMenuItem(value: 'borrar', child: Text('Quitar')),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (c.meta > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PivotRadios.chip),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: c.avance),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 4, backgroundColor: p.suave, color: p.marca),
                ),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !abierta
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (c.aportes.isEmpty) Text('Nadie se anotó todavía.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                        // Quién lleva qué, con su avatar.
                        for (final a in c.aportes)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                AvatarPersona(nombre: '${a['nombre'] ?? ''}', foto: '${a['foto'] ?? ''}', tamano: 28),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    [
                                      a['mio'] == true ? 'Tú' : '${a['nombre']}',
                                      if ('${a['detalle'] ?? ''}'.isNotEmpty) '${a['detalle']}',
                                      if (!c.porCosa) '${cantidadSocial(a['cantidad'] as num)} ${c.unidad}',
                                      if (ComidaTarjeta._para(a['paraTodxs']).isNotEmpty) ComidaTarjeta._para(a['paraTodxs']),
                                    ].join(' · '),
                                    style: TextStyle(fontSize: 13, color: p.texto),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Solo las ideas que nadie tomó todavía.
                        if (ideas.isNotEmpty && !c.cerrada) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final s in ideas)
                                ActionChip(
                                  avatar: const Icon(Icons.add_rounded, size: 16),
                                  label: Text(s),
                                  onPressed: _e.asiste ? () => t._anotar(context, c, sugerencia: s) : null,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Regalo robado: tope y recordatorio.
class RegaloRobadoTarjeta extends StatelessWidget {
  const RegaloRobadoTarjeta({super.key, required this.estado, this.simbolo, this.repo, this.alCambiar});
  final EstadoSocial estado;
  final String? simbolo;

  /// Para el juego en vivo (sin repo, solo la información).
  final SocialRepo? repo;
  final VoidCallback? alCambiar;

  /// "Jugar al regalo robado" (Victor, 2026-11-20): quien dirige lo activa el
  /// día del evento; si ya empezó, todxs entran a verlo en vivo.
  Future<void> _jugar(BuildContext context) async {
    final r = repo;
    if (r == null) return;
    final j = estado.juegoRobado;
    if (j['fase'] == null) {
      final si = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('¿Empezamos el regalo robado?'),
          content: const Text(
            'Todas las personas que van verán el juego en vivo en la app. Te guiamos paso a paso: '
            'regalos a la pila, sorteo del orden y turnos.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Todavía no')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Empezar')),
          ],
        ),
      );
      if (si != true || !context.mounted) return;
      try {
        await r.juego('iniciar');
      } catch (e) {
        if (context.mounted) avisarSocial(context, e.toString());
        return;
      }
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RegaloRobadoJuegoScreen(repo: r)));
    alCambiar?.call();
  }

  Widget _boton(BuildContext context, PivotPaleta p) {
    final j = estado.juegoRobado;
    final fase = j['fase'];
    final dirige = j['dirige'] == true, hoy = j['hoy'] == true;
    final activo = repo != null && (fase != null || (dirige && hoy));
    final nota = fase == 'terminado'
        ? 'El juego terminó: mira quién se llevó qué.'
        : fase != null
        ? 'El juego está en vivo: entra para ver los turnos.'
        : !hoy
        ? 'Se activa el día del evento.'
        : dirige
        ? 'Tú diriges el juego: actívalo cuando estén listxs.'
        : 'Quien dirige el juego todavía no lo activa.';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (repo != null && estado.asiste && !estado.participaRobado) ...[
            Text(
              estado.inscripcionAbierta ? 'Elegiste no jugar al regalo robado. Para cambiarlo, toca el lápiz.' : 'Elegiste no jugar al regalo robado.',
              style: TextStyle(fontSize: 13, color: p.textoSecundario),
            ),
            const SizedBox(height: 6),
          ],
          FilledButton.icon(
            onPressed: activo ? () => _jugar(context) : null,
            icon: const Icon(Icons.casino_rounded),
            label: const Text('Jugar al regalo robado'),
          ),
          const SizedBox(height: 6),
          Text(
            nota,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.textoSecundario),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return TarjetaSocial(
      titulo: 'Regalo robado',
      icono: Icons.card_giftcard_rounded,
      estado: estado.asiste ? (estado.participaRobado ? 'Participas' : 'No participas') : null,
      estadoActivo: estado.participaRobado,
      accion: repo != null && estado.puedeArea('amigo')
          ? EditarTarjetas.boton(() => EditarTarjetas(context, repo!, estado, alCambiar ?? () {}).robado())
          : repo != null && estado.asiste && estado.inscripcionAbierta
          ? EditarTarjetas.boton(() => EditarTarjetas(context, repo!, estado, alCambiar ?? () {}).participacion(amigo: false))
          : null,
      children: [
        Text(
          estado.topeRobado != null
              ? 'Lleva un regalo de hasta ${montoSocial(estado.topeRobado, simbolo)}.'
              : 'Lleva un regalo para el juego del regalo robado.',
          style: TextStyle(color: p.texto),
        ),
        if (estado.recordatorioRobado.isNotEmpty) ...[const SizedBox(height: 6), Text(estado.recordatorioRobado, style: TextStyle(color: p.textoSecundario))],
        // Reglas del juego siempre a la vista, en pasos numerados (Victor, 2026-11-22).
        // Salen de la plantilla con las opciones del evento, o de lo que escribió
        // quien organiza: cada línea es un paso.
        if (estado.reglasRobado.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Reglas del juego',
            style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
          ),
          const SizedBox(height: 8),
          for (final (i, paso) in pasosReglas(
            estado.reglasRobado.replaceAll('{tope}', estado.topeRobado != null ? montoSocial(estado.topeRobado, simbolo) : 'el tope acordado'),
          ).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.suave, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.sobreSuave),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(paso, style: TextStyle(height: 1.35, color: p.texto)),
                  ),
                ],
              ),
            ),
        ],
        _boton(context, p),
      ],
    );
  }
}

/// Reglas en pasos: una por línea, sin la numeración o viñeta que traiga.
List<String> pasosReglas(String texto) => [
  for (final l in texto.split(RegExp(r'\n+')))
    if (l.trim().replaceFirst(RegExp(r'^(\d+[.)]|[-•*])\s*'), '').isNotEmpty) l.trim().replaceFirst(RegExp(r'^(\d+[.)]|[-•*])\s*'), ''),
];

String _aCargoDe(Map<String, dynamic> x) {
  if (x['organiza'] == true) return 'Organiza todo el evento';
  final de = [for (final a in (x['aCargoDe'] as List? ?? const [])) '$a'];
  final quien = conPronombres('Encargadx', x['pronombres']);
  if (de.isEmpty) return quien;
  final lista = de.length == 1 ? de.first : '${de.sublist(0, de.length - 1).join(', ')} y ${de.last}';
  return '$quien de $lista';
}

/// Personas a cargo del evento con botones de contacto.
class ACargoTarjeta extends StatelessWidget {
  const ACargoTarjeta({super.key, required this.personas, this.redes = const [], this.alEditar, this.alTocarPersona});
  final List<Map<String, dynamic>> personas;

  /// Quien organiza toca a unx encargadx para cambiar de qué está a cargo (Victor, 2026-11-22).
  final void Function(String usuario)? alTocarPersona;

  /// Quien creó el evento (o un Pivot) cambia responsables y responsabilidades.
  final VoidCallback? alEditar;

  /// Apps de mensajería de la liga (Comunidad en Equipo): solo esas se ofrecen.
  final List<String> redes;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return TarjetaSocial(
      titulo: '¿Dudas? Pregúntales',
      icono: Icons.support_agent_rounded,
      accion: alEditar == null ? null : IconButton(tooltip: 'Cambiar responsables', icon: const Icon(Icons.edit_outlined), onPressed: alEditar),
      children: [
        for (final x in personas)
          Builder(
            builder: (context) {
              final completo = telefonoInternacional('${x['telefono'] ?? ''}', prefijo: '${x['prefijo'] ?? ''}');
              final canales = canalesPara(completo, redes).where((c) => c.$1 != 'Mensaje de texto');
              final email = '${x['email'] ?? ''}';
              final yo = x['yo'] == true;
              final tocar = alTocarPersona != null && x['organiza'] != true ? () => alTocarPersona!('${x['username']}') : null;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: tocar,
                leading: AvatarPersona(nombre: '${x['nombre'] ?? ''}', foto: '${x['foto'] ?? ''}', tamano: 40),
                title: Text('${x['nombre'] ?? ''}${yo ? ' (tú)' : ''}', style: TextStyle(color: p.texto)),
                // De qué está a cargo cada quien, para saber a quién preguntar (Victor, 2026-11-20).
                subtitle: Text(_aCargoDe(x)),
                trailing: yo
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (nombre, icono, uri) in canales)
                            IconButton(
                              tooltip: nombre,
                              icon: Icon(icono),
                              onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
                            ),
                          if (completo.isNotEmpty)
                            IconButton(tooltip: 'Llamar', icon: const Icon(Icons.call_rounded), onPressed: () => launchUrl(Uri.parse('tel:+$completo'))),
                          if (completo.isEmpty && email.contains('@'))
                            IconButton(
                              tooltip: 'Correo',
                              icon: const Icon(Icons.mail_outline_rounded),
                              onPressed: () => launchUrl(Uri(scheme: 'mailto', path: email)),
                            ),
                        ],
                      ),
              );
            },
          ),
      ],
    );
  }
}

/// − [número] + para anotarse.
class _Contador extends StatelessWidget {
  const _Contador({required this.controller, required this.paso, required this.sufijo, required this.alCambiar});
  final TextEditingController controller;
  final num paso;
  final String sufijo;
  final VoidCallback alCambiar;

  void _mover(int dir) {
    final v = num.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
    final n = math.max(paso, v + dir * paso);
    controller.text = ComidaTarjeta._num(n);
    alCambiar();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton.outlined(tooltip: 'Menos', icon: const Icon(Icons.remove_rounded), onPressed: () => _mover(-1)),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: sufijo, isDense: true),
          onChanged: (_) => alCambiar(),
        ),
      ),
      const SizedBox(width: 8),
      IconButton.outlined(tooltip: 'Más', icon: const Icon(Icons.add_rounded), onPressed: () => _mover(1)),
    ],
  );
}

/// Cuánto cubriste de lo que te toca llevar.
class _TuParte extends StatelessWidget {
  const _TuParte({required this.valor, required this.secciones, required this.abierta, required this.alTocar, required this.lleva});

  /// Cuánto cubriste (0 a 1); null si no cuenta (sin secciones de comida o bebida).
  final double? valor;

  /// Secciones de comida y bebida que cuentan: tu parte es 1 persona en cada una.
  final int secciones;
  final bool abierta;
  final VoidCallback alTocar;

  /// Lo que llevas (filas con "Quitar").
  final List<Widget> lleva;

  int _personas(double v) => math.max(1, ((1 - v) * secciones).ceil());

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final v = valor;
    final lista = v != null && v >= 1;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 10),
      decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
            onTap: alTocar,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tu parte',
                      style: TextStyle(fontWeight: FontWeight.w700, color: p.sobreSuave),
                    ),
                  ),
                  if (lista)
                    Icon(Icons.check_circle_rounded, size: 20, color: p.marcaTexto)
                  else if (v != null)
                    Text(
                      '${(v * 100).round()} %',
                      style: TextStyle(fontWeight: FontWeight.w700, color: p.marcaTexto),
                    ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: abierta ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, color: p.sobreSuave),
                  ),
                ],
              ),
            ),
          ),
          if (v != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PivotRadios.chip),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: v.clamp(0, 1).toDouble()),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, x, _) => LinearProgressIndicator(value: x, minHeight: 6, backgroundColor: p.tarjeta, color: p.marca),
                ),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !abierta
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (v != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 8, 8, 4),
                          // En una frase, qué te toca (Victor, 2026-11-20).
                          child: Text(
                            lista
                                ? 'Ya cubriste tu parte ✓ Si quieres, puedes llevar más.'
                                : v <= 0
                                ? 'Te toca llevar algo: con comida o bebida para ${_personas(v)} ${_personas(v) == 1 ? 'persona' : 'personas'} en cualquier sección cubres tu parte.'
                                : 'Te falta poco: con comida o bebida para ${_personas(v)} ${_personas(v) == 1 ? 'persona' : 'personas'} más cubres tu parte.',
                            style: TextStyle(fontSize: 13, color: p.sobreSuave),
                          ),
                        ),
                      if (lleva.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Tú llevas',
                            style: TextStyle(fontWeight: FontWeight.w700, color: p.sobreSuave),
                          ),
                        ),
                        ...lleva,
                        Text('Te lo recordamos el día anterior.', style: TextStyle(fontSize: 12, color: p.sobreSuave)),
                      ] else
                        Text('Todavía no te anotaste en ninguna sección.', style: TextStyle(fontSize: 12, color: p.sobreSuave)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
