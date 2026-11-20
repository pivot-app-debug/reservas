import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/moneda.dart';
import '../../core/pronombres.dart';
import '../../core/tema.dart';
import '../widgets_comunes.dart';
import 'mensajeria.dart';
import 'pistas_screen.dart';
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
    return TarjetaSocial(titulo: 'Amigo secreto', icono: Icons.redeem_rounded, children: contenido);
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

class ComidaTarjeta extends StatelessWidget {
  const ComidaTarjeta({super.key, required this.repo, required this.estado, required this.alCambiar});
  final SocialRepo repo;
  final EstadoSocial estado;
  final VoidCallback alCambiar;

  Future<void> _anotar(BuildContext context, CategoriaComida c) async {
    final cantidad = TextEditingController(text: cantidadSocial(math.max(1, c.porPersona)));
    final detalle = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Llevo ${c.nombre.toLowerCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: detalle,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(labelText: '¿Qué llevas?', hintText: 'Ej.: Limonada'),
            ),
            TextField(
              controller: cantidad,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Cantidad', suffixText: c.unidad),
            ),
            const SizedBox(height: 8),
            Text('Faltan ${cantidadSocial(math.max(0, c.meta - c.aportado))} ${c.unidad}.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Anotarme')),
        ],
      ),
    );
    final n = num.tryParse(cantidad.text.replaceAll(',', '.'));
    final texto = detalle.text;
    cantidad.dispose();
    detalle.dispose();
    if (ok != true || !context.mounted) return;
    if (n == null || n <= 0) {
      avisarSocial(context, 'Indica cuánto llevas.');
      return;
    }
    try {
      await repo.anotarComida(c.id, n, texto);
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

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final cats = estado.comida;
    final total = estado.conteo['total'] ?? 0;
    return TarjetaSocial(
      titulo: 'Comida compartida',
      icono: Icons.restaurant_rounded,
      children: [
        Text(
          'La meta se calcula con $total ${total == 1 ? 'persona confirmada' : 'personas confirmadas'} (con sus +1).',
          style: TextStyle(fontSize: 13, color: p.textoSecundario),
        ),
        if (!estado.asiste) ...[
          const SizedBox(height: 6),
          Text('Confirma tu asistencia para anotarte.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
        ],
        if (cats.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Quien organiza todavía no armó las categorías.', style: TextStyle(color: p.textoSecundario)),
          ),
        for (final c in cats)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.nombre,
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                      ),
                    ),
                    Text('${cantidadSocial(c.aportado)} / ${cantidadSocial(c.meta)} ${c.unidad}', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(PivotRadios.chip),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: c.avance),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: p.suave, color: p.marca),
                  ),
                ),
                for (final a in c.aportes)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${a['mio'] == true ? 'Tú' : a['nombre']}: ${cantidadSocial(a['cantidad'] as num)} ${c.unidad}${'${a['detalle']}'.isEmpty ? '' : ' · ${a['detalle']}'}',
                            style: TextStyle(fontSize: 13, color: p.texto),
                          ),
                        ),
                        if (a['mio'] == true)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Quitar',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => _quitar(context, '${a['id']}'),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: c.cerrada
                      ? Etiqueta(texto: 'Completo', icono: Icons.check_rounded)
                      : TextButton.icon(
                          onPressed: estado.asiste ? () => _anotar(context, c) : null,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Me anoto'),
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Regalo robado: tope y recordatorio.
class RegaloRobadoTarjeta extends StatelessWidget {
  const RegaloRobadoTarjeta({super.key, required this.estado, this.simbolo});
  final EstadoSocial estado;
  final String? simbolo;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return TarjetaSocial(
      titulo: 'Regalo robado',
      icono: Icons.card_giftcard_rounded,
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
      ],
    );
  }
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
                subtitle: Text(x['organiza'] == true ? 'Organiza' : conPronombres('Encargadx', x['pronombres'])),
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
