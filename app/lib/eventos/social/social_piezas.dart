import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tema.dart';
import '../widgets_comunes.dart';
import 'social_repo.dart';
import 'social_widgets.dart';

/// Piezas nuevas del "Social o fiesta" (Victor, 2026-11-20): encabezado,
/// playlist, dress code, qué traer, homenaje (mensajes y regalo entre todxs),
/// premios y los mensajes para la persona homenajeada. Lo que cada quien ve ya
/// viene filtrado del servidor (la vista neutral no trae nada del homenaje).

/// Nombre, "Sorpresa para X", descripción y estado de la aprobación.
class EncabezadoSocial extends StatelessWidget {
  const EncabezadoSocial({super.key, required this.estado, this.accion});
  final EstadoSocial estado;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final e = estado;
    final aprobacion = switch (e.estadoAprobacion) {
      'por_aprobar' => 'Esperando la aprobación de un Pivot. Solo quienes organizan lo ven por ahora.',
      'rechazado' => 'Un Pivot pidió cambios${e.rechazoMotivo.isEmpty ? '' : ': ${e.rechazoMotivo}'}. Edítalo y envíalo de nuevo.',
      _ => null,
    };
    return TarjetaSocial(
      titulo: e.titulo.isEmpty ? 'Social o fiesta' : e.titulo,
      icono: Icons.celebration_outlined,
      accion: accion,
      children: [
        if (e.sorpresa != null) ...[Etiqueta(texto: e.sorpresa!, icono: Icons.visibility_off_outlined), const SizedBox(height: 8)],
        if (aprobacion != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: Text(aprobacion, style: TextStyle(color: p.sobreSuave)),
          ),
        if (e.descripcion.isNotEmpty) Text(e.descripcion, style: TextStyle(color: p.texto)),
        if (e.sorpresa != null) ...[
          const SizedBox(height: 6),
          Text(
            'Las personas homenajeadas y quienes no deben enterarse lo ven con otro nombre. No le cuentes.',
            style: TextStyle(fontSize: 13, color: p.textoSecundario),
          ),
        ],
      ],
    );
  }
}

Future<void> _abrir(BuildContext context, String link) async {
  final u = Uri.tryParse(link);
  if (u == null || !await launchUrl(u, mode: LaunchMode.externalApplication)) {
    if (context.mounted) avisarSocial(context, 'No se pudo abrir el enlace.');
  }
}

class PlaylistTarjeta extends StatelessWidget {
  const PlaylistTarjeta({super.key, required this.datos});
  final Map<String, dynamic> datos;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final link = '${datos['link'] ?? ''}';
    final nota = '${datos['nota'] ?? ''}';
    return TarjetaSocial(
      titulo: 'Playlist colaborativa',
      icono: Icons.queue_music_rounded,
      children: [
        if (nota.isNotEmpty) Text(nota, style: TextStyle(color: p.texto)),
        if (link.isEmpty)
          Text('Quien organiza todavía no compartió el enlace.', style: TextStyle(color: p.textoSecundario))
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonalIcon(
              onPressed: () => _abrir(context, link),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir la playlist'),
            ),
          ),
      ],
    );
  }
}

class DressTarjeta extends StatelessWidget {
  const DressTarjeta({super.key, required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return TarjetaSocial(
      titulo: 'Dress code',
      icono: Icons.checkroom_rounded,
      children: [Text(texto.isEmpty ? 'Ven como quieras.' : texto, style: TextStyle(color: p.texto))],
    );
  }
}

/// Lista de qué traer: cada quien se anota (lxs +1 solo ven lo suyo).
class TraerTarjeta extends StatelessWidget {
  const TraerTarjeta({super.key, required this.repo, required this.estado, required this.alCambiar});
  final SocialRepo repo;
  final EstadoSocial estado;
  final VoidCallback alCambiar;

  Future<void> _anotar(BuildContext context, Map<String, dynamic> it) async {
    final detalle = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Llevo: ${it['texto']}'),
        content: TextField(
          controller: detalle,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Detalle (opcional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Anotarme')),
        ],
      ),
    );
    final t = detalle.text;
    detalle.dispose();
    if (ok != true || !context.mounted) return;
    try {
      await repo.anotarTraer('${it['id']}', t);
      alCambiar();
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  Future<void> _quitar(BuildContext context, String id) async {
    try {
      await repo.quitarTraer(id);
      alCambiar();
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final items = estado.traer;
    return TarjetaSocial(
      titulo: 'Qué traer',
      icono: Icons.checklist_rtl_rounded,
      children: [
        if (!estado.asiste) Text('Confirma tu asistencia para anotarte.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
        if (items.isEmpty) Text('La lista está vacía por ahora.', style: TextStyle(color: p.textoSecundario)),
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${it['texto']}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                      ),
                    ),
                    if (it['cantidad'] != null) Text('${it['anotados']} / ${it['cantidad']}', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                  ],
                ),
                for (final a in (it['personas'] as List? ?? const []).cast<Map>())
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${a['mio'] == true ? 'Tú' : a['nombre']}${'${a['detalle']}'.isEmpty ? '' : ' · ${a['detalle']}'}',
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: it['completo'] == true
                      ? Etiqueta(texto: 'Cubierto', icono: Icons.check_rounded)
                      : (it['personas'] as List? ?? const []).any((a) => a is Map && a['mio'] == true)
                      ? const SizedBox.shrink()
                      : TextButton.icon(
                          onPressed: estado.asiste ? () => _anotar(context, it) : null,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Lo llevo'),
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class PremiosTarjeta extends StatelessWidget {
  const PremiosTarjeta({super.key, required this.lista});
  final List<Map<String, dynamic>> lista;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return TarjetaSocial(
      titulo: 'Premios y reconocimientos',
      icono: Icons.emoji_events_outlined,
      children: [
        if (lista.isEmpty) Text('Todavía no hay premios.', style: TextStyle(color: p.textoSecundario)),
        for (final x in lista)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.star_outline_rounded, color: p.marcaTexto),
            title: Text('${x['premio']}'),
            subtitle: Text('${x['para'] ?? ''}'.isEmpty ? 'Por decidir' : '${x['para']}'),
          ),
      ],
    );
  }
}

/// Homenaje: mensajes de todxs para cada persona homenajeada y el regalo
/// entre todxs (solo se anota quién aporta cuánto; no pasa por Finanzas).
class HomenajeTarjeta extends StatelessWidget {
  const HomenajeTarjeta({super.key, required this.repo, required this.estado, required this.alCambiar, this.alLiberar, this.simbolo});
  final SocialRepo repo;
  final EstadoSocial estado;
  final VoidCallback alCambiar;

  /// Solo para quien organiza: liberar los mensajes antes del evento.
  final VoidCallback? alLiberar;
  final String? simbolo;

  Future<void> _escribir(BuildContext context, Map<String, dynamic> persona, String actual) async {
    final c = TextEditingController(text: actual);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Para ${persona['nombre']}'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 1000,
          maxLines: 6,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Escribe tu mensaje'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Guardar')),
        ],
      ),
    );
    final t = c.text;
    c.dispose();
    if (ok != true || !context.mounted) return;
    try {
      await repo.mensaje('${persona['username']}', t);
      if (context.mounted) avisarSocial(context, t.trim().isEmpty ? 'Mensaje borrado.' : 'Mensaje guardado. Lo leerá después del evento.');
      alCambiar();
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  Future<void> _aportar(BuildContext context, num? actual, num? falta) async {
    final c = TextEditingController(text: actual == null ? '' : cantidadSocial(actual));
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Cuánto aportas?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(prefixText: simbolo, hintText: '0 para quitar tu aporte'),
            ),
            const SizedBox(height: 8),
            Text(
              '${falta == null ? '' : 'Faltan ${montoSocial(falta, simbolo)}. '}Solo se anota: se lo das a quien compra.',
              style: TextStyle(fontSize: 13, color: d.pivot.textoSecundario),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Guardar')),
        ],
      ),
    );
    final n = num.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
    c.dispose();
    if (ok != true || !context.mounted) return;
    try {
      await repo.aportarRegalo(n);
      alCambiar();
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final h = estado.homenaje!;
    final personas = [for (final x in (h['personas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    final conteo = Map<String, dynamic>.from((h['conteo'] as Map?) ?? const {});
    final mios = Map<String, dynamic>.from((h['mios'] as Map?) ?? const {});
    final regalo = h['regalo'] is Map ? Map<String, dynamic>.from(h['regalo'] as Map) : null;
    return TarjetaSocial(
      titulo: 'Homenaje',
      icono: Icons.favorite_border_rounded,
      children: [
        Text('Para ${personas.map((x) => x['nombre']).join(', ')}.', style: TextStyle(color: p.texto)),
        if (h['mensajes'] == true) ...[
          const SizedBox(height: 12),
          Text(
            'Mensajes',
            style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
          ),
          Text(
            h['liberados'] == true ? 'Ya los pueden leer.' : 'Los leen después del evento o cuando quien organiza los libere.',
            style: TextStyle(fontSize: 13, color: p.textoSecundario),
          ),
          for (final x in personas)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(mios.containsKey(x['username']) ? Icons.mark_email_read_outlined : Icons.edit_note_rounded, color: p.marcaTexto),
              title: Text('${x['nombre']}'),
              subtitle: Text(
                '${conteo[x['username']] ?? 0} ${(conteo[x['username']] ?? 0) == 1 ? 'mensaje' : 'mensajes'}${mios.containsKey(x['username']) ? ' · ya escribiste el tuyo' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _escribir(context, x, '${mios[x['username']] ?? ''}'),
            ),
          if (alLiberar != null && h['liberados'] != true)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: alLiberar, icon: const Icon(Icons.lock_open_rounded), label: const Text('Liberar los mensajes ahora')),
            ),
        ],
        if (regalo != null) ...[
          const SizedBox(height: 12),
          Text(
            'Regalo entre todxs',
            style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
          ),
          if ('${regalo['nota'] ?? ''}'.isNotEmpty) Text('${regalo['nota']}', style: TextStyle(color: p.texto)),
          Text(
            [
              'Juntado: ${montoSocial(regalo['total'] as num? ?? 0, simbolo)}${regalo['tope'] != null ? ' de ${montoSocial(regalo['tope'] as num, simbolo)}' : ''}',
              if (regalo['compra'] is Map) 'Compra: ${(regalo['compra'] as Map)['nombre']}',
            ].join(' · '),
            style: TextStyle(fontSize: 13, color: p.textoSecundario),
          ),
          if (regalo['tope'] != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(PivotRadios.chip),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 0,
                  end: ((regalo['tope'] as num) <= 0 ? 0 : ((regalo['total'] as num? ?? 0) / (regalo['tope'] as num))).clamp(0, 1).toDouble(),
                ),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: p.suave, color: p.marca),
              ),
            ),
          ],
          for (final a in (regalo['aportes'] as List? ?? const []).cast<Map>())
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${a['mio'] == true ? 'Tú' : a['nombre']}: ${montoSocial(a['monto'] as num, simbolo)}',
                style: TextStyle(fontSize: 13, color: p.texto),
              ),
            ),
          Builder(
            builder: (context) {
              final mio = (regalo['aportes'] as List? ?? const []).cast<Map>().where((a) => a['mio'] == true).firstOrNull;
              final tope = regalo['tope'] as num?;
              final falta = tope == null ? null : math.max(0, tope - (regalo['total'] as num? ?? 0) + ((mio?['monto'] as num?) ?? 0));
              return Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _aportar(context, mio?['monto'] as num?, falta),
                  icon: Icon(mio == null ? Icons.add_rounded : Icons.edit_outlined),
                  label: Text(mio == null ? 'Aporto' : 'Cambiar mi aporte'),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Lo que ve la persona homenajeada cuando se liberan sus mensajes.
class ParaTiTarjeta extends StatelessWidget {
  const ParaTiTarjeta({super.key, required this.mensajes});
  final List<Map<String, dynamic>> mensajes;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return TarjetaSocial(
      titulo: 'Mensajes para ti',
      icono: Icons.favorite_rounded,
      children: [
        if (mensajes.isEmpty) Text('Todavía no hay mensajes.', style: TextStyle(color: p.textoSecundario)),
        for (final m in mensajes)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m['texto']}', style: TextStyle(color: p.sobreSuave)),
                const SizedBox(height: 4),
                Text(
                  '— ${m['nombre']}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.sobreSuave),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
