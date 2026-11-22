import 'package:flutter/material.dart';

import '../../core/fechas.dart';
import '../../core/tema.dart';
import '../widgets_comunes.dart';
import 'que_lleva_calculo.dart';
import 'social_repo.dart';
import 'social_widgets.dart';

// ─── Vista de una fiesta (Victor, 2026-11-21) ──────────────────────────────
// Cards con lo importante para ti; el detalle completo de cada cosa se abre en
// una subsección (y ahí se edita, desde su barra). Arriba de todo, un banner
// con lo que te falta completar.

/// Último estado cargado de cada fiesta (solo en memoria) y un aviso cuando
/// cambia, para que el detalle del evento y las subsecciones se refresquen.
final estadosSociales = <String, EstadoSocial>{};
final versionSocial = ValueNotifier<int>(0);

void guardarEstadoSocial(String idEvento, EstadoSocial e) {
  estadosSociales[idEvento] = e;
  versionSocial.value++;
}

/// Subsección de una pieza de la fiesta: se refresca sola al guardar y el
/// lápiz de la tarjeta queda en la barra.
Future<void> abrirSubseccionSocial(
  BuildContext context, {
  required String idEvento,
  required String titulo,
  required Widget Function(EstadoSocial e) contenido,
}) {
  final accion = ValueNotifier<Widget?>(null);
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(titulo),
          actions: [
            ValueListenableBuilder<Widget?>(
              valueListenable: accion,
              builder: (_, a, _) => AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: a ?? const SizedBox.shrink()),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: ValueListenableBuilder<int>(
            valueListenable: versionSocial,
            builder: (context, _, _) {
              final e = estadosSociales[idEvento];
              if (e == null) return const Center(child: CircularProgressIndicator());
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [SinMarcoSocial(accion: accion, child: contenido(e))],
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Card de una pieza: ícono, título, una línea de estado y se toca para abrir.
class _CardPieza extends StatelessWidget {
  const _CardPieza({required this.icono, required this.titulo, required this.texto, this.estado, this.estadoActivo = true, required this.alTocar});
  final IconData icono;
  final String titulo, texto;
  final String? estado;
  final bool estadoActivo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return SizedBox(
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.grande),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconoTarjetaSocial(icono: icono),
                    const Spacer(),
                    if (estado != null)
                      Flexible(
                        child: Etiqueta(texto: estado!, apagada: !estadoActivo),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.texto),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: p.textoSecundario),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Qué lleva cada quien" resumido: tu parte, lo que llevas (con "−"), lo que
/// falta y "+" para anotarte. Tocarla abre todo el detalle.
class QueLlevaResumen extends StatelessWidget {
  const QueLlevaResumen({super.key, required this.repo, required this.estado, required this.alCambiar, required this.alAbrir});
  final SocialRepo repo;
  final EstadoSocial estado;
  final VoidCallback alCambiar;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final e = estado;
    final t = ComidaTarjeta(repo: repo, estado: e, alCambiar: alCambiar);
    final mias = [
      for (final c in e.comida)
        for (final a in c.aportes)
          if (a['mio'] == true) (c, a),
    ];
    final faltan = [
      for (final c in e.comida)
        if (!c.cerrada && (c.falta || (c.meta > 0 && c.aportado < c.meta))) c.nombre,
    ];
    final cuenta = e.asiste && e.seccionesParte.isNotEmpty;
    final parte = e.miParte.clamp(0, 1).toDouble();
    final total = (e.conteo['total'] as num?) ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.grande),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alAbrir,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconoTarjetaSocial(icono: Icons.restaurant_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Qué lleva cada quien',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
                      ),
                    ),
                    if (e.asiste) IconButton(tooltip: 'Anotar algo', icon: const Icon(Icons.add_rounded), onPressed: alAbrir),
                    Icon(Icons.chevron_right_rounded, color: p.textoSecundario),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        '${total == 1 ? 'Asiste 1 persona' : 'Asisten $total personas'}${e.asiste ? '' : '. Confirma tu asistencia para anotarte.'}',
                        style: TextStyle(fontSize: 13, color: p.textoSecundario),
                      ),
                      if (cuenta) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'Tu parte',
                              style: TextStyle(fontWeight: FontWeight.w600, color: p.texto),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(PivotRadios.chip),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: parte),
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, x, _) => LinearProgressIndicator(value: x, minHeight: 6, backgroundColor: p.suave, color: p.marca),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(parte * 100).round()} %',
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.marcaTexto),
                            ),
                          ],
                        ),
                      ],
                      if (mias.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final (c, a) in mias)
                              InputChip(
                                label: Text(
                                  [
                                    '${a['detalle'] ?? ''}'.isEmpty ? c.nombre : '${a['detalle']}',
                                    if (!c.porCosa) '${cantidadSocial(a['cantidad'] as num)} ${c.unidad}',
                                  ].join(' · '),
                                ),
                                deleteIcon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                                deleteButtonTooltipMessage: 'Quitar',
                                onDeleted: () => t.quitarAporte(context, '${a['id']}'),
                              ),
                          ],
                        ),
                      ],
                      if (faltan.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Falta aún: ${faltan.join(', ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.marcaTexto),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Actividades del evento en cards que se deslizan (amigo secreto, regalo
/// robado, playlist, dress code, premios). Cada una abre su subsección.
class ActividadesSocial extends StatelessWidget {
  const ActividadesSocial({super.key, required this.estado, required this.alAbrir});
  final EstadoSocial estado;

  /// 'amigo' | 'robado' | 'playlist' | 'dress' | 'premios'
  final void Function(String) alAbrir;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final e = estado;
    final cierre = e.cierre;
    final cards = <Widget>[
      if (e.modulo('amigoSecreto'))
        _CardPieza(
          icono: Icons.redeem_rounded,
          titulo: 'Amigo secreto',
          estado: e.asiste ? (e.participaAmigo ? 'Participas' : 'No participas') : null,
          estadoActivo: e.participaAmigo,
          texto: !e.asiste
              ? 'Marca Asistiré para participar.'
              : !e.participaAmigo
              ? (e.inscripcionAbierta ? 'Todavía puedes sumarte.' : 'Esta vez no participas.')
              : e.sorteado
              ? 'Ya puedes ver a quién le regalas.'
              : [
                  if (e.topeAmigo != null) 'Tope ${cantidadSocial(e.topeAmigo!)}',
                  if (cierre != null) 'Sorteo el ${Fechas.corta(cierre)}',
                  e.perfil.wishlist.isEmpty ? 'Lista de deseos vacía' : '${e.perfil.wishlist.length} en tu lista de deseos',
                ].join(' · '),
          alTocar: () => alAbrir('amigo'),
        ),
      if (e.modulo('regaloRobado'))
        _CardPieza(
          icono: Icons.card_giftcard_rounded,
          titulo: 'Regalo robado',
          estado: e.asiste ? (e.participaRobado ? 'Participas' : 'No participas') : null,
          estadoActivo: e.participaRobado,
          texto: [
            if (e.topeRobado != null) 'Tope ${cantidadSocial(e.topeRobado!)}',
            e.juegoRobado['fase'] != null ? 'El juego ya empezó' : 'Trae un regalo envuelto',
          ].join(' · '),
          alTocar: () => alAbrir('robado'),
        ),
      if (e.playlist != null)
        _CardPieza(
          icono: Icons.queue_music_rounded,
          titulo: 'Playlist',
          texto: '${e.playlist!['link'] ?? ''}'.isEmpty ? 'Sin enlace todavía.' : 'Agrega tus canciones.',
          alTocar: () => alAbrir('playlist'),
        ),
      if (e.dress != null)
        _CardPieza(
          icono: Icons.checkroom_rounded,
          titulo: 'Dress code',
          texto: '${e.dress!['texto'] ?? ''}'.trim().isEmpty ? 'Ven como quieras.' : '${e.dress!['texto']}'.trim(),
          alTocar: () => alAbrir('dress'),
        ),
      if (e.premios != null)
        _CardPieza(
          icono: Icons.emoji_events_outlined,
          titulo: 'Premios',
          texto: e.premios!.isEmpty ? 'Por definir.' : '${e.premios!.length} ${e.premios!.length == 1 ? 'premio' : 'premios'}',
          alTocar: () => alAbrir('premios'),
        ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Text(
            'Actividades del evento',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.textoSecundario),
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(width: cards.length == 1 ? MediaQuery.sizeOf(context).width - 32 : 220, child: cards[i]),
          ),
        ),
      ],
    );
  }
}

/// Lo que te falta completar en la fiesta, con atajos (arriba del todo).
class PendientesFiesta extends StatelessWidget {
  const PendientesFiesta({super.key, required this.estado, required this.alParticipar, required this.alDeseos, required this.alComida});
  final EstadoSocial estado;
  final VoidCallback alParticipar, alDeseos, alComida;

  static List<(IconData, String, String, String)> pendientes(EstadoSocial e) => [
    if (e.asiste && e.modulo('amigoSecreto') && !e.participaAmigo && e.inscripcionAbierta && !e.sorteado)
      (Icons.redeem_rounded, 'No participas del amigo secreto. ¿Quieres participar?', 'Participar', 'amigo'),
    if (e.asiste && e.modulo('amigoSecreto') && e.participaAmigo && e.perfil.vacio)
      (Icons.list_alt_rounded, 'No completaste tu lista de deseos. ¿La completas?', 'Completar', 'deseos'),
    if (e.asiste && e.modulo('comida') && e.seccionesParte.isNotEmpty && e.miParte < 1)
      (
        Icons.restaurant_rounded,
        e.miParte <= 0 ? 'Aún no pusiste qué llevarás al evento.' : 'Te falta completar lo que llevas.',
        e.miParte <= 0 ? 'Anotar' : 'Completar',
        'comida',
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = pendientes(estado);
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: l.isEmpty
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.grande)),
              child: Column(
                children: [
                  for (final (i, (icono, texto, boton, que)) in l.indexed) ...[
                    if (i > 0) Divider(height: 1, color: p.bordeSuave),
                    Row(
                      children: [
                        Icon(icono, size: 20, color: p.marcaTexto),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(texto, style: TextStyle(fontSize: 14, color: p.sobreSuave)),
                          ),
                        ),
                        TextButton(
                          onPressed: switch (que) {
                            'amigo' => alParticipar,
                            'deseos' => alDeseos,
                            _ => alComida,
                          },
                          child: Text(boton),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
