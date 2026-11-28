import 'package:flutter/material.dart';

import '../core/tema.dart';
import 'niveles_coach.dart';

/// Mi progreso como protagonista de Entreno (Victor, 2026-11-27, mockup A):
/// el nivel, cuánto falta para completar el siguiente, lo que estás
/// trabajando y lo último que te dejaron. [compacto] para entrenadorxs.
class MiProgresoHero extends StatelessWidget {
  const MiProgresoHero({super.key, required this.d, required this.alTocar, this.compacto = false});

  /// La respuesta de getFichaDeportiva de la persona (null: cargando).
  final Map<String, dynamic>? d;
  final VoidCallback alTocar;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final (degradado, sobre) = PivotPaleta.seccion('reservas', Theme.of(context).brightness);
    final d = this.d;
    final habs = [for (final h in (d?['habilidades'] as List? ?? const [])) Map<String, dynamic>.from(h as Map)];
    final logros = {for (final x in (d?['logros'] as List? ?? const [])) '${(x as Map)['clave']}'};
    // Logros por grupo (Victor, 2026-11-27): cuántos grupos completos tiene.
    final gruposLogrados = (d?['logros'] as List? ?? const []).where((x) => (x as Map)['tipo'] == 'grupo').length;
    // El primer nivel sin completar: se completa con todas sus habilidades.
    NivelCoach? actual;
    var ok = 0, total = 0;
    for (final n in NivelesCoach.lista) {
      final hs = habs.where((h) => '${h['tipo'] ?? NivelesCoach.primero}' == n.clave).toList();
      if (hs.isEmpty || logros.contains(n.clave)) continue;
      actual = n;
      total = hs.length;
      ok = hs.where((h) => h['nivel'] == 'logrado').length;
      break;
    }
    final falta = (total - ok).clamp(0, total);
    // Niveles ya completos, en orden.
    final completos = [
      for (final n in NivelesCoach.lista)
        if (logros.contains(n.clave)) n,
    ];
    final enProceso = habs.where((h) => h['nivel'] == 'proceso').map((h) => '${h['nombre']}').toList();
    final pruebas = [for (final x in (d?['pruebas'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    final ultima = pruebas.where((x) => x['mejor'] != null).firstOrNull;
    final notas = (d?['notas'] as List? ?? const []).length;
    TextStyle st(double size, [FontWeight w = FontWeight.w600, double alfa = 1]) => TextStyle(
      fontSize: size,
      fontWeight: w,
      color: sobre.withValues(alpha: alfa),
      height: 1.3,
    );
    Widget chip(String texto) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: sobre.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(PivotRadios.chip)),
      child: Text(texto, style: st(12, FontWeight.w700)),
    );
    return Semantics(
      button: true,
      label: 'Mi progreso',
      child: Material(
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta + 6),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(gradient: degradado),
          child: InkWell(
            onTap: alTocar,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // El título es el nivel en el que estás trabajando; los
                    // completos van como logro debajo (QA 2026-11-27: decía
                    // «Habilidades básicas» y parecía que seguías en básicas).
                    Text(actual == null ? 'MI PROGRESO' : 'MI PROGRESO · TRABAJANDO EN', style: st(12.5, FontWeight.w800, 0.9)),
                    const SizedBox(height: 4),
                    Text(
                      d == null ? ' ' : (actual?.nombre ?? nivelesCoach['${d['nivel'] ?? 'sin'}'] ?? 'Aprendiendo lo básico'),
                      style: st(compacto ? 20 : 24, FontWeight.w900),
                    ),
                    if (d != null && completos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final n in completos)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: sobre.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(PivotRadios.chip)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 15, color: sobre),
                                  const SizedBox(width: 5),
                                  Text('${n.nombre} completas', style: st(12, FontWeight.w700)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (d != null && actual != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(PivotRadios.chip),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: total == 0 ? 0 : ok / total),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) =>
                              LinearProgressIndicator(value: v, minHeight: 10, backgroundColor: sobre.withValues(alpha: 0.28), color: sobre),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(ok == 1 ? '1 de $total habilidades logradas' : '$ok de $total habilidades logradas', style: st(13, FontWeight.w700)),
                          ),
                          Text('${total == 0 ? 0 : (ok * 100 / total).round()} %', style: st(13, FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        falta == 0
                            ? 'Ya casi: falta que el equipo técnico lo marque.'
                            // Con el nombre del nivel: antes parecía que faltaban básicas (QA 2026-11-27).
                            : 'Te ${falta == 1 ? 'falta 1 habilidad' : 'faltan $falta habilidades'} para completar este nivel.',
                        style: st(14),
                      ),
                    ] else if (d != null) ...[
                      const SizedBox(height: 8),
                      Text(habs.isEmpty ? 'Todavía no hay habilidades en tu liga.' : 'Completaste todos los niveles.', style: st(14)),
                    ],
                    if (!compacto && d != null && (enProceso.isNotEmpty || ultima != null || notas > 0 || gruposLogrados > 0)) ...[
                      if (enProceso.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: sobre.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                          child: Text('Trabajando: ${enProceso.take(3).join(', ')}${enProceso.length > 3 ? '…' : ''}', style: st(13)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (ultima != null)
                            chip('${ultima['nombre']}: ${_num(ultima['mejor'])}${'${ultima['unidad'] ?? ''}'.isEmpty ? '' : ' ${ultima['unidad']}'}'),
                          if (notas > 0) chip(notas == 1 ? '1 nota del equipo técnico' : '$notas notas del equipo técnico'),
                          if (gruposLogrados > 0) chip(gruposLogrados == 1 ? '1 grupo completo' : '$gruposLogrados grupos completos'),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ver todo mi progreso', style: st(14, FontWeight.w800)),
                        Icon(Icons.chevron_right_rounded, color: sobre),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _num(Object? v) {
    final n = v is num ? v : num.tryParse('$v') ?? 0;
    return n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(1).replaceAll('.', ',');
  }
}
