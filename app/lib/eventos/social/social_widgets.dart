import 'dart:math' as math;

import 'package:flutter/material.dart';
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
  const TarjetaSocial({super.key, required this.titulo, this.icono, required this.children, this.accion});
  final String titulo;
  final IconData? icono;
  final List<Widget> children;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
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
                if (icono != null) ...[Icon(icono, size: 20, color: p.marcaTexto), const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
                  ),
                ),
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
                  if (tope != null) Text('Tope: ${montoSocial(tope, simbolo)}', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
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
            'Wishlist',
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
            label: const Text('Ver su wishlist en otra app'),
          ),
        ],
      ],
    );
  }
}

// ─── Amigo secreto (estado, ruleta y ficha oculta) ────────────────────────

class AmigoSecretoTarjeta extends StatefulWidget {
  const AmigoSecretoTarjeta({super.key, required this.repo, required this.estado, required this.alCambiar, this.simbolo, this.pronombres});
  final SocialRepo repo;

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
        pageBuilder: (_, _, _) => RuletaScreen(repo: widget.repo, tope: widget.estado.topeAmigo, simbolo: widget.simbolo),
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
                    e.asiste
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
    final fuera = estado == 'fuera';
    contenido.add(
      ListTile(
        // Fuera del sorteo, las pistas y la wishlist quedan deshabilitadas.
        enabled: !fuera,
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.lightbulb_outline_rounded, color: fuera ? p.textoSecundario : p.marcaTexto),
        title: Text(
          'Mis pistas y wishlist',
          style: TextStyle(color: p.texto, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          fuera
              ? 'No hace falta: esta vez no participas'
              : pf.vacio
              ? 'Cuéntale a tu amigo secreto qué te gusta'
              : '${pf.gustos.length + pf.sobreMi.length + pf.noRegalar.length} pistas · ${pf.wishlist.length} en tu wishlist',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: fuera ? null : _pistas,
      ),
    );
    return TarjetaSocial(
      titulo: 'Amigo secreto',
      icono: Icons.redeem_rounded,
      accion: e.puedeArea('amigo') ? EditarTarjetas.boton(() => EditarTarjetas(context, widget.repo, e, widget.alCambiar).amigo()) : null,
      children: contenido,
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
  const ComidaTarjeta({super.key, required this.repo, required this.estado, required this.alCambiar});
  final SocialRepo repo;
  final EstadoSocial estado;
  final VoidCallback alCambiar;

  /// Anotarse (Victor, 2026-11-20): la comida se pregunta en personas que
  /// alcanza y la bebida en litros; si lo que escribes se reconoce (un pollo,
  /// una botella de vino) se calcula solo y avisa si el número no cuadra.
  /// Siempre se puede llevar de más, aunque la sección o tu parte ya estén cubiertas.
  Future<void> _anotar(BuildContext context, CategoriaComida c, {String? sugerencia}) async {
    final e = estado;
    final ref = e.refDe(c);
    final porPersonas = c.enPorciones && ref > 0;
    final enLitros = c.liquida;
    final inicial = sugerencia == null ? null : rendimientoDe(sugerencia);
    num? sugeridoDe(Rendimiento? r) => r == null ? null : (porPersonas ? r.personas : (enLitros ? r.litros : null));
    final valor = TextEditingController(text: _num(sugeridoDe(inicial) ?? (porPersonas ? 1 : (enLitros ? (ref > 0 ? ref : 1) : math.max(1, c.porPersona)))));
    final detalle = TextEditingController(text: sugerencia ?? '');
    bool? paraTodxs;
    var tocado = false;
    final yaParte = e.miParte;
    final ok = await hojaFormulario(
      context,
      titulo: c.nombre,
      accion: 'Me anoto',
      contenido: (d, set) {
        final p = d.pivot;
        final n = num.tryParse(valor.text.replaceAll(',', '.')) ?? 0;
        final cantidad = porPersonas ? n * ref : n;
        final r = rendimientoDe(detalle.text);
        final sug = sugeridoDe(r);
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
              onChanged: (v) => set(() {
                final s = sugeridoDe(rendimientoDe(v));
                if (!tocado && s != null) valor.text = _num(s);
              }),
            ),
            if (!c.porCosa) ...[
              const SizedBox(height: 16),
              Text(porPersonas ? '¿Para cuántas personas alcanza?' : (enLitros ? '¿Cuántos litros llevas?' : '¿Cuánto llevas?')),
              const SizedBox(height: 6),
              _Contador(
                controller: valor,
                paso: porPersonas ? 1 : (enLitros ? 0.5 : 1),
                sufijo: porPersonas ? (n == 1 ? 'persona' : 'personas') : c.unidad,
                alCambiar: () => set(() => tocado = true),
              ),
              const SizedBox(height: 6),
              if (porPersonas) Text('Una persona come unas ${_num(ref)} ${c.unidad}. Son ${_num(cantidad)} ${c.unidad}.', style: secundario),
              if (enLitros && ref > 0)
                Text(
                  'Una persona toma unos ${_num(ref)} litros. '
                  '${n / ref < 1 ? 'Alcanza para menos de 1 persona.' : 'Alcanza para unas ${(n / ref).round()} personas.'}',
                  style: secundario,
                ),
              // Ayuda para no equivocarse: un pollo no rinde 1 porción.
              if (r != null && sug != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                  decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 18, color: p.sobreSuave),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          porPersonas
                              ? '${r.texto} suele alcanzar para unas ${_num(sug)} personas.'
                              : (r.texto.startsWith('Escribiste') ? '${r.texto}.' : '${r.texto} tiene unos ${_num(sug)} litros.'),
                          style: TextStyle(fontSize: 13, color: p.sobreSuave),
                        ),
                      ),
                      if (n != sug)
                        TextButton(
                          onPressed: () => set(() {
                            valor.text = _num(sug);
                            tocado = true;
                          }),
                          child: const Text('Ajustar'),
                        ),
                    ],
                  ),
                ),
              ],
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
    final n = v == null ? null : (porPersonas ? v * ref : v);
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

  Future<void> _editar(BuildContext context, [CategoriaComida? c]) async {
    final nombre = TextEditingController(text: c?.nombre ?? '');
    final unidad = TextEditingController(text: c == null || c.porCosa ? 'porciones' : c.unidad);
    final porPersona = TextEditingController(text: c == null ? '1' : cantidadSocial(c.porPersona));
    final total = TextEditingController(text: c?.total == null ? '' : cantidadSocial(c!.total!));
    final ideas = TextEditingController(text: (c?.sugerencias ?? const []).join(', '));
    final cupo = TextEditingController(text: c?.cupo == null ? '' : cantidadSocial(c!.cupo!));
    var modo = c?.modo ?? 'libre';
    var cupoTipo = c?.cupoTipo ?? '';
    const espacio = SizedBox(height: 16);
    final ok = await hojaFormulario(
      context,
      titulo: c == null ? 'Agregar sección' : 'Editar ${c.nombre}',
      accion: 'Guardar',
      contenido: (d, set) {
        final p = d.pivot;
        final secundario = TextStyle(fontSize: 12, color: p.textoSecundario);
        // Comida y bebida no tienen cupo: siempre se puede llevar de más.
        final u = unidad.text.toLowerCase();
        final esComida = (modo == 'meta' || modo == 'total') && (u.contains('porci') || RegExp(r'^(litros?|l|lts?)$').hasMatch(u.trim()));
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
            DropdownButtonFormField<String>(
              initialValue: modo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '¿Cuánto se pide?'),
              items: const [
                DropdownMenuItem(value: 'libre', child: Text('Libre, sin cantidad')),
                DropdownMenuItem(value: 'cada', child: Text('Cada persona lleva algo')),
                DropdownMenuItem(value: 'total', child: Text('Un total fijo')),
                DropdownMenuItem(value: 'meta', child: Text('Según cuántas personas van')),
              ],
              onChanged: (v) => set(() => modo = v ?? 'libre'),
            ),
            const SizedBox(height: 6),
            Text(switch (modo) {
              'cada' => 'Cada persona que va lleva la cantidad de cosas que elijas.',
              'total' => 'Se pide una cantidad total, sin importar cuántas personas van.',
              'meta' => 'La cantidad crece con las personas que van. Para comida, una persona come unas 2 porciones; para bebida, 1 litro.',
              _ => 'Cada quien lleva lo que quiera, sin cantidad.',
            }, style: secundario),
            if (modo == 'meta' || modo == 'cada') ...[
              espacio,
              TextField(
                controller: porPersona,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: modo == 'cada' ? 'Cosas por persona' : 'Cantidad por persona'),
              ),
            ],
            if (modo == 'total') ...[
              espacio,
              TextField(
                controller: total,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Total'),
              ),
            ],
            if (modo == 'meta' || modo == 'total') ...[
              espacio,
              TextField(
                controller: unidad,
                maxLength: 30,
                onChanged: (_) => set(() {}),
                decoration: const InputDecoration(labelText: 'Unidad (porciones, litros, bolsas…)', counterText: ''),
              ),
            ],
            // Cupo (Victor, 2026-11-20): para que no lleguen 20 adornos.
            if (!esComida) ...[
              espacio,
              const Text('Cupo', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: '', label: Text('Sin límite')),
                    ButtonSegment(value: 'fijo', label: Text('Fijo')),
                    ButtonSegment(value: 'persona', label: Text('Por personas')),
                  ],
                  selected: {cupoTipo},
                  onSelectionChanged: (x) => set(() => cupoTipo = x.first),
                ),
              ),
              const SizedBox(height: 6),
              Text(switch (cupoTipo) {
                'fijo' => 'Cuando se anotan esas cosas, la sección se completa y nadie más se anota.',
                'persona' => 'El cupo crece con las personas que van: 1 cosa por cada cierta cantidad de personas.',
                _ => 'Se pueden anotar todas las personas que quieran.',
              }, style: secundario),
              if (cupoTipo.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: cupo,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: cupoTipo == 'fijo' ? 'Máximo de cosas' : '1 cosa por cada… personas',
                    suffixText: cupoTipo == 'fijo' ? 'cosas' : 'personas',
                  ),
                ),
              ],
            ],
            espacio,
            TextField(
              controller: ideas,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Ideas de qué llevar (opcional)'),
            ),
            const SizedBox(height: 6),
            Text('Sepáralas con comas.', style: secundario),
          ],
        );
      },
    );
    final n = nombre.text.trim(), u = unidad.text.trim();
    final pp = num.tryParse(porPersona.text.replaceAll(',', '.')), tt = num.tryParse(total.text.replaceAll(',', '.'));
    final cp = num.tryParse(cupo.text.replaceAll(',', '.'));
    final sug = [
      for (final x in ideas.text.split(','))
        if (x.trim().isNotEmpty) x.trim(),
    ];
    Future.delayed(const Duration(milliseconds: 400), () {
      for (final t in [nombre, unidad, porPersona, total, ideas, cupo]) {
        t.dispose();
      }
    });
    if (ok != true || !context.mounted) return;
    if (n.isEmpty) return avisarSocial(context, 'Escribe el nombre de la sección.');
    if (cupoTipo.isNotEmpty && (cp == null || cp <= 0)) return avisarSocial(context, 'Indica el cupo.');
    try {
      await repo.editarComida(
        categoriaId: c?.id,
        nombre: n,
        unidad: modo == 'cada' || modo == 'libre' ? 'cosas' : u,
        porPersona: pp,
        modo: modo,
        total: tt,
        sugerencias: sug,
        cupoTipo: cupoTipo,
        cupo: cupoTipo.isEmpty ? 0 : cp,
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

  Future<void> _quitar(BuildContext context, String id) async {
    try {
      await repo.quitarAporte(id);
      alCambiar();
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  static String _para(Object? v) => v == true ? 'para todxs' : (v == false ? 'solo para sí' : '');

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
    final masUno = e.conteo['invitados'] ?? 0;
    final admin = e.puedeComida;
    final abiertas = e.comida.where((c) => !c.cerrada).toList()..sort((a, b) => (b.falta ? 1 : 0) - (a.falta ? 1 : 0));
    final completas = e.comida.where((c) => c.cerrada).toList();
    // Lo que todavía le falta al grupo, con cuánto (Victor, 2026-11-20: "más directo").
    final faltan = [
      for (final c in abiertas)
        if (c.falta || (c.meta > 0 && c.aportado < c.meta))
          c.meta > 0 && c.aportado < c.meta ? '${c.nombre} (${cantidadSocial(c.meta - c.aportado)}${c.porCosa ? '' : ' ${c.unidad}'})' : c.nombre,
    ];
    final mias = [
      for (final c in e.comida)
        for (final a in c.aportes)
          if (a['mio'] == true) (c, a),
    ];
    return TarjetaSocial(
      titulo: 'Qué lleva cada quien',
      icono: Icons.restaurant_rounded,
      accion: admin ? IconButton(tooltip: 'Agregar sección', icon: const Icon(Icons.add_rounded), onPressed: () => t._editar(context)) : null,
      children: [
        Text(
          'Van $total ${total == 1 ? 'persona' : 'personas'}'
          '${masUno > 0 ? ' (${masUno == 1 ? 'incluye 1 invitadx' : 'incluye $masUno invitadxs'})' : ''}. '
          '${e.asiste ? 'Mira lo que ya lleva cada quien para no repetir.' : 'Confirma tu asistencia para anotarte.'}',
          style: TextStyle(fontSize: 13, color: p.textoSecundario),
        ),
        if (e.asiste && e.seccionesParte.isNotEmpty) _TuParte(valor: e.miParte, secciones: e.seccionesParte.length),
        if (mias.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
            decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tú llevas',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.sobreSuave),
                ),
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
                Text('Te lo recordamos el día anterior.', style: TextStyle(fontSize: 12, color: p.sobreSuave)),
              ],
            ),
          ),
        if (faltan.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Todavía falta para el grupo: ',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.marcaTexto),
                ),
                TextSpan(
                  text: faltan.join(', '),
                  style: TextStyle(color: p.texto),
                ),
              ],
            ),
          ),
        ],
        if (e.comida.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              admin ? 'Todavía no hay secciones. Toca + para agregar la primera.' : 'Quien organiza todavía no armó la lista.',
              style: TextStyle(color: p.textoSecundario),
            ),
          ),
        const SizedBox(height: 8),
        for (final c in abiertas) _seccion(context, p, c, admin),
        if (completas.isNotEmpty) ...[
          InkWell(
            borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
            onTap: () => setState(() => _verCompletadas = !_verCompletadas),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 20, color: p.textoSecundario),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Completadas (${completas.length})',
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.textoSecundario),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _verCompletadas ? 0.5 : 0,
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
            child: _verCompletadas ? Column(children: [for (final c in completas) _seccion(context, p, c, admin)]) : const SizedBox(width: double.infinity),
          ),
        ],
      ],
    );
  }

  Widget _seccion(BuildContext context, PivotPaleta p, CategoriaComida c, bool admin) {
    final t = widget.t;
    final abierta = _abierta[c.id] ?? _abiertaPorDefecto(c);
    final teFalta = _teFalta(c);
    final pide = switch (c.modo) {
      'cada' => 'Cada persona lleva ${cantidadSocial(c.porPersona)}',
      'total' => '${cantidadSocial(c.meta)} ${c.unidad} en total',
      'libre' => 'Libre',
      _ => '${cantidadSocial(c.porPersona)} ${c.unidad} por persona',
    }; // Cupo de las cosas: "· Cupo: 5".
    final pideConCupo = c.limite > 0 ? '$pide · Cupo: ${cantidadSocial(c.limite)}' : pide;
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
    final tomadas = {for (final a in c.aportes) '${a['detalle'] ?? ''}'.trim().toLowerCase()};
    final ideas = [
      for (final s in c.sugerencias)
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
            onTap: () => setState(() => _abierta[c.id] = !abierta),
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
      accion: repo != null && estado.puedeArea('amigo')
          ? EditarTarjetas.boton(() => EditarTarjetas(context, repo!, estado, alCambiar ?? () {}).robado())
          : null,
      children: [
        Text(
          estado.topeRobado != null
              ? 'Lleva un regalo de hasta ${montoSocial(estado.topeRobado, simbolo)}.'
              : 'Lleva un regalo para el juego del regalo robado.',
          style: TextStyle(color: p.texto),
        ),
        if (estado.recordatorioRobado.isNotEmpty) ...[const SizedBox(height: 6), Text(estado.recordatorioRobado, style: TextStyle(color: p.textoSecundario))],
        // Reglas del juego (plantilla o las que escribió quien organiza).
        if (estado.reglasRobado.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: p.tarjeta),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                'Reglas del juego',
                style: TextStyle(fontWeight: FontWeight.w600, color: p.texto),
              ),
              expandedAlignment: Alignment.topLeft,
              children: [
                Text(
                  estado.reglasRobado.replaceAll('{tope}', estado.topeRobado != null ? montoSocial(estado.topeRobado, simbolo) : 'el tope acordado'),
                  style: TextStyle(height: 1.4, color: p.texto),
                ),
              ],
            ),
          ),
        _boton(context, p),
      ],
    );
  }
}

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
  const ACargoTarjeta({super.key, required this.personas, this.redes = const []});
  final List<Map<String, dynamic>> personas;

  /// Apps de mensajería de la liga (Comunidad en Equipo): solo esas se ofrecen.
  final List<String> redes;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return TarjetaSocial(
      titulo: '¿Dudas? Pregúntales',
      icono: Icons.support_agent_rounded,
      children: [
        for (final x in personas)
          Builder(
            builder: (context) {
              final completo = telefonoInternacional('${x['telefono'] ?? ''}', prefijo: '${x['prefijo'] ?? ''}');
              final canales = canalesPara(completo, redes).where((c) => c.$1 != 'Mensaje de texto');
              final email = '${x['email'] ?? ''}';
              final yo = x['yo'] == true;
              return ListTile(
                contentPadding: EdgeInsets.zero,
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
  const _TuParte({required this.valor, required this.secciones});
  final double valor;

  /// Secciones de comida y bebida que cuentan: tu parte es 1 persona en cada una.
  final int secciones;

  int _personas() => math.max(1, ((1 - valor) * secciones).ceil());

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final lista = valor >= 1;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tu parte',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                ),
              ),
              if (lista)
                Icon(Icons.check_circle_rounded, size: 20, color: p.marcaTexto)
              else
                Text(
                  '${(valor * 100).round()} %',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.marcaTexto),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(PivotRadios.chip),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: valor.clamp(0, 1).toDouble()),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: p.suave, color: p.marca),
            ),
          ),
          const SizedBox(height: 4),
          // En una frase, qué te toca (Victor, 2026-11-20).
          Text(
            lista
                ? 'Ya cubriste tu parte ✓ Si quieres, puedes llevar más.'
                : valor <= 0
                ? 'Te toca llevar algo: con comida o bebida para ${_personas()} personas en cualquier sección cubres tu parte.'.replaceFirst(
                    'para 1 personas',
                    'para 1 persona',
                  )
                : 'Te falta poco: con comida o bebida para ${_personas()} ${_personas() == 1 ? 'persona' : 'personas'} más cubres tu parte.',
            style: TextStyle(fontSize: 13, fontWeight: lista ? FontWeight.w400 : FontWeight.w600, color: lista ? p.textoSecundario : p.texto),
          ),
        ],
      ),
    );
  }
}
