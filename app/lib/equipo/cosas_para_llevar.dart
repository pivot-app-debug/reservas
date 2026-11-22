import 'package:flutter/material.dart';

import '../core/fechas.dart';
import '../core/tema.dart';
import '../eventos/eventos_repo.dart';
import '../eventos/modelos.dart';
import '../eventos/widgets_comunes.dart';
import 'equipo_repo.dart';

/// Cosas para llevar a los eventos de hoy y mañana (Victor, 2026-11-22): solo
/// para Pivots. Sale de las suscripciones con talla de patines o protecciones.
/// Cuando el evento termina, desaparece.
class CosasParaLlevar {
  CosasParaLlevar._();

  /// (evento, [(usuario, qué)]) de hoy y mañana que todavía no terminan.
  static Future<List<(Evento, List<(String, String)>)>> cargar(EventosRepo eventos) async {
    if (!eventos.sesion.esAdmin || eventos.sesion.adminToken == null) return const [];
    final m = await eventos.queLlevar();
    final hoy = Fechas.hoy(), manana = hoy.add(const Duration(days: 1));
    final out = <(Evento, List<(String, String)>)>[];
    for (final e in m.entries) {
      final ev = eventos.porId(e.key);
      if (ev == null || ev.cancelado || ev.finalizado) continue;
      final dia = Fechas.soloDia(ev.fecha);
      if (dia != hoy && dia != manana) continue;
      out.add((ev, [for (final x in e.value.entries) (x.key, x.value)]));
    }
    out.sort((a, b) => a.$1.fecha.compareTo(b.$1.fecha));
    return out;
  }
}

/// Aviso arriba de Comunidad; al tocarlo, el desglose.
class AvisoCosasParaLlevar extends StatelessWidget {
  const AvisoCosasParaLlevar({super.key, required this.eventos, required this.equipo, this.margen = const EdgeInsets.fromLTRB(16, 8, 16, 4)});
  final EventosRepo eventos;
  final EquipoRepo equipo;
  final EdgeInsets margen;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return FutureBuilder<List<(Evento, List<(String, String)>)>>(
      future: CosasParaLlevar.cargar(eventos),
      builder: (context, f) {
        final l = f.data ?? const [];
        final cosas = l.fold<int>(0, (n, x) => n + x.$2.length);
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: l.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: margen,
                  child: Material(
                    color: p.suave,
                    borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CosasParaLlevarScreen(eventos: eventos, equipo: equipo),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          children: [
                            Icon(Icons.content_paste_rounded, color: p.sobreSuave),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cosas == 1 ? 'Hay 1 cosa para llevar' : 'Hay $cosas cosas para llevar',
                                    style: TextStyle(fontWeight: FontWeight.w800, color: p.sobreSuave),
                                  ),
                                  Text(
                                    l.map((x) => '${x.$1.titulo} ${Fechas.soloDia(x.$1.fecha) == Fechas.hoy() ? 'hoy' : 'mañana'}').join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: p.sobreSuave),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: p.sobreSuave),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// Desglose: por evento, qué llevar y para quién, con su avatar.
class CosasParaLlevarScreen extends StatelessWidget {
  const CosasParaLlevarScreen({super.key, required this.eventos, required this.equipo});
  final EventosRepo eventos;
  final EquipoRepo equipo;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Scaffold(
      appBar: AppBar(title: const Text('Cosas para llevar')),
      body: FutureBuilder<List<(Evento, List<(String, String)>)>>(
        future: CosasParaLlevar.cargar(eventos),
        builder: (context, f) {
          if (f.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final l = f.data ?? const [];
          if (l.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No hay que llevar nada hoy ni mañana.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textoSecundario),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              for (final (ev, cosas) in l) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    '${ev.titulo} · ${Fechas.soloDia(ev.fecha) == Fechas.hoy() ? 'hoy' : 'mañana'} ${ev.rangoHorario}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: p.texto),
                  ),
                ),
                for (final (u, que) in cosas)
                  Builder(
                    builder: (context) {
                      final per = equipo.personas?.where((x) => x.username.toLowerCase() == u).firstOrNull;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: AvatarPersona(nombre: per?.nombreMostrar ?? u, foto: per?.foto ?? '', tamano: 40),
                          title: Text(que, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(per?.nombreMostrar ?? u),
                        ),
                      );
                    },
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
