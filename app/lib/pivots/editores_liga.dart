import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/selector_plazo.dart';
import '../core/tema.dart';
import '../core/zonas_horarias.dart';
import '../sesion/sesion.dart';
import '../core/moneda.dart';
import '../core/monedas_mundo.dart';

/// Editores de los ajustes de la liga, compartidos por Mi Liga, Reglas,
/// Cobros y los ajustes de cada equipo (Victor, 2026-11-14).
String plataLiga(num? v) => v == null ? 'Sin definir' : '${Moneda.s}${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(2)}';

Future<void> guardarLiga(BuildContext context, ConfigLiga c, Map<String, Object?> cambios) async {
  final m = ScaffoldMessenger.of(context);
  try {
    await c.guardar(cambios);
    m.showSnackBar(const SnackBar(content: Text('Guardado')));
  } catch (e) {
    m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
  }
}

/// Todas las zonas horarias del mundo con buscador (Victor, 2026-11-14).
Future<void> elegirZonaLiga(BuildContext context, ConfigLiga c) async {
  var q = '';
  String sinTildes(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úü]'), 'u');
  final v = await showModalBottomSheet<String>(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (h) => StatefulBuilder(
      builder: (h, set) {
        final l = [
          for (final e in zonasHorarias.entries)
            if (q.isEmpty || sinTildes('${e.value} ${e.key}').contains(sinTildes(q))) e,
        ];
        return SizedBox(
          height: MediaQuery.sizeOf(h).height * 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  autofocus: true,
                  onChanged: (x) => set(() => q = x.trim()),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'País o ciudad'),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: 16 + MediaQuery.viewInsetsOf(h).bottom),
                  itemCount: l.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(l[i].value),
                    trailing: l[i].key == c.zonaHoraria ? Icon(Icons.check_rounded, color: h.pivot.marcaTexto) : null,
                    onTap: () => Navigator.of(h).pop(l[i].key),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  if (v != null && v != c.zonaHoraria && context.mounted) await guardarLiga(context, c, {'zonaHoraria': v});
}

Future<void> elegirLiga(BuildContext context, ConfigLiga c, String titulo, Map<String, String> opciones, String actual, String clave, {String? ayuda}) async {
  final v = await showModalBottomSheet<String>(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (h) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(titulo, style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (ayuda != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(ayuda, style: TextStyle(fontSize: 13.5, color: h.pivot.textoSecundario)),
            ),
          for (final e in opciones.entries)
            ListTile(
              leading: clave == 'canal' ? Icon(ConfigLiga.iconoDe(e.key)) : null,
              title: Text(e.value),
              trailing: e.key == actual ? Icon(Icons.check_rounded, color: h.pivot.marcaTexto) : null,
              onTap: () => Navigator.of(h).pop(e.key),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (v != null && v != actual && context.mounted) await guardarLiga(context, c, {clave: v});
}

Future<void> precioLiga(BuildContext context, ConfigLiga c, String titulo, num? actual, String clave) async {
  final ctl = TextEditingController(text: actual == null ? '' : '$actual');
  final v = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: ctl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(prefixText: '${Moneda.s} '),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(d).pop(ctl.text.replaceAll(',', '.')), child: const Text('Guardar')),
      ],
    ),
  );
  final n = num.tryParse(v ?? '');
  if (n != null && context.mounted) await guardarLiga(context, c, {clave: n});
}

Future<void> numeroLiga(BuildContext context, ConfigLiga c, String titulo, String clave, int actual, int min, int max, String etiqueta) async {
  var v = actual;
  final ok = await showModalBottomSheet<bool>(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    builder: (h) => StatefulBuilder(
      builder: (h, set) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titulo, style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              SelectorNumero(valor: v, min: min, max: max, paso: max > 100 ? 5 : 1, etiqueta: etiqueta, alCambiar: (n) => set(() => v = n.toInt())),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.of(h).pop(true), child: const Text('Guardar')),
            ],
          ),
        ),
      ),
    ),
  );
  if (ok != true || v == actual || !context.mounted) return;
  final m = ScaffoldMessenger.of(context);
  try {
    await c.guardarReglas({clave: v});
    m.showSnackBar(const SnackBar(content: Text('Guardado')));
  } catch (e) {
    m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
  }
}

Future<void> guardarReglaLiga(BuildContext context, ConfigLiga c, Map<String, Object?> cambios) async {
  final m = ScaffoldMessenger.of(context);
  try {
    await c.guardarReglas(cambios);
    m.showSnackBar(const SnackBar(content: Text('Guardado')));
  } catch (e) {
    m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
  }
}

String textoGracia(ConfigLiga c) {
  final g = c.graciaPorEquipo;
  if (g.isEmpty) return 'Ningún equipo tiene clases de gracia';
  return [for (final e in g.entries) '${e.key}: ${e.value == 0 ? 'paga antes' : '${e.value} ${e.value == 1 ? 'clase' : 'clases'}'}'].join(' · ');
}

/// Clases de gracia por equipo (Victor, 2026-11-14).
Future<void> editarGracia(BuildContext context, Sesion sesion, ConfigLiga c, {String? soloEquipo}) async {
  final m = ScaffoldMessenger.of(context);
  List<String> equipos;
  try {
    final r = await sesion.api.get('getTiers', {'adminToken': sesion.adminToken});
    equipos = [for (final t in (r['tiers'] as List? ?? const [])) '${(t as Map)['nombre']}'];
  } catch (_) {
    m.showSnackBar(const SnackBar(content: Text('No se pudieron cargar los equipos. Revisa tu conexión.')));
    return;
  }
  if (!context.mounted) return;
  final v = <String, int?>{for (final e in equipos) e: c.graciaClases(e)};
  // Se guardan todos los equipos aunque se edite uno solo (si no, se borraban los demás).
  final visibles = soloEquipo == null ? equipos : equipos.where((e) => e == soloEquipo).toList();
  // Equipos que pagan por clase o no pagan: no aplica (Victor, 2026-11-16).
  bool porMes(String e) => const {'mes', 'elige', 'segun_equipamiento'}.contains('${c.cobroEquipo(e)['modo']}');
  String ejemplo(String e) {
    final n = v[e];
    if (!porMes(e)) return '$e no paga mensualidad, así que no usa clases de gracia: cada clase se reserva y se paga.';
    if (n == null) return '$e no usa clases de gracia: quien no ha pagado la cuota sigue su forma de pago.';
    if (n == 0) return 'En $e, quien no ha pagado la cuota del mes debe pagar antes de marcar Asistiré.';
    return 'En $e, quien no ha pagado la cuota puede venir a $n ${n == 1 ? 'clase' : 'clases'} del mes. Desde la clase ${n + 1}, al marcar Asistiré se le pide pagar.';
  }

  // Subsección en vez de hoja (Victor, 2026-11-15).
  final ok = await abrirSubseccion(
    context,
    titulo: 'Clases de gracia',
    contenido: (set) => [
      Text('Clases del mes a las que se puede venir sin haber pagado la cuota.', style: TextStyle(color: context.pivot.textoSecundario)),
      for (final e in visibles) ...[
        const SizedBox(height: 14),
        if (!porMes(e))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Paga por clase: no usa clases de gracia'),
          )
        else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(v[e] == null ? 'No usa clases de gracia' : 'Usa clases de gracia'),
            value: v[e] != null,
            onChanged: (x) => set(() => v[e] = x ? 1 : null),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: v[e] == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SelectorNumero(
                      valor: v[e]!,
                      min: 0,
                      max: 10,
                      etiqueta: v[e] == 0 ? 'clases: debe pagar antes' : (v[e] == 1 ? 'clase al mes' : 'clases al mes'),
                      alCambiar: (x) => set(() => v[e] = x.toInt()),
                    ),
                  ),
          ),
        ],
      ],
      const SizedBox(height: 16),
      for (final e in visibles)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(ejemplo(e)),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: context.pivot.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: Text(ejemplo(e), style: TextStyle(height: 1.4, color: context.pivot.sobreSuave)),
          ),
        ),
    ],
  );
  if (ok != true || !context.mounted) return;
  await guardarReglaLiga(context, c, {
    'graciaClases': {
      for (final e in v.entries)
        if (e.value != null) e.key: e.value,
    },
  });
}

String textoVencimiento(ConfigLiga c) {
  final d = c.cuotaVenceDia >= 1 && c.cuotaVenceDia <= 28 ? c.cuotaVenceDia : 15; // igual que el servidor
  final g = c.cuotaRecargo > 0 && c.cuotaGraciaDias > 0 ? ' (+${c.cuotaGraciaDias} ${c.cuotaGraciaDias == 1 ? 'día' : 'días'} de margen)' : '';
  final monto = c.recargoPorcentaje ? '${c.cuotaRecargo % 1 == 0 ? c.cuotaRecargo.toInt() : c.cuotaRecargo} %' : plataLiga(c.cuotaRecargo);
  final r = c.cuotaRecargo > 0 ? ' · recargo $monto${c.recargoMensual ? ' por mes de atraso' : ''}$g' : ' · sin recargo';
  return 'Día $d de cada mes$r';
}

/// A quién aplica un ajuste (Victor, 2026-11-14): "Toda la liga" o "Solo Quindes".
class ChipAlcance extends StatelessWidget {
  const ChipAlcance({super.key, this.equipo});

  /// null = toda la liga.
  final String? equipo;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final propio = equipo != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: propio ? p.marcaTexto : p.apagadoEtiqueta, borderRadius: BorderRadius.circular(PivotRadios.chip)),
      child: Text(
        propio ? 'Solo $equipo' : 'Toda la liga',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: propio ? p.sobreMarca : p.textoSecundario),
      ),
    );
  }
}

/// Moneda de la liga (Mi Liga → Datos de la liga): símbolo de todos los
/// montos. Lista completa de monedas del mundo con buscador (Victor,
/// 2026-11-16) o un símbolo escrito a mano.
Future<void> elegirMonedaLiga(BuildContext context, ConfigLiga c) async {
  var q = '';
  String sinTildes(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úü]'), 'u');
  final v = await showModalBottomSheet<(String, String)>(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (h) => StatefulBuilder(
      builder: (h, set) {
        final l = [
          for (final m in monedasMundo)
            if (q.isEmpty || sinTildes('${m.$1} ${m.$2} ${m.$3}').contains(sinTildes(q))) m,
        ];
        final propio = q.isNotEmpty && q.length <= 5;
        return SizedBox(
          height: MediaQuery.sizeOf(h).height * 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  autofocus: true,
                  onChanged: (x) => set(() => q = x.trim()),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'País, moneda o código'),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: 16 + MediaQuery.viewInsetsOf(h).bottom),
                  itemCount: l.length + (propio ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == l.length) {
                      return ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: Text('Usar "$q" como símbolo'),
                        onTap: () => Navigator.of(h).pop((q, '')),
                      );
                    }
                    final (cod, nombre, simbolo) = l[i];
                    final elegida = cod == c.monedaCodigo || (c.monedaCodigo.isEmpty && cod == 'USD' && c.moneda == r'$');
                    return ListTile(
                      leading: SizedBox(
                        width: 44,
                        child: Text(
                          simbolo,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800, color: h.pivot.marcaTexto),
                        ),
                      ),
                      title: Text(nombre),
                      subtitle: Text(cod),
                      trailing: elegida ? Icon(Icons.check_rounded, color: h.pivot.marcaTexto) : null,
                      onTap: () => Navigator.of(h).pop((simbolo, cod)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  if (v == null || !context.mounted) return;
  if (v.$1 == c.moneda && v.$2 == c.monedaCodigo) return;
  await guardarLiga(context, c, {'moneda': v.$1, 'monedaCodigo': v.$2});
}

/// Nombre de la moneda para la fila de Datos de la liga.
String textoMonedaLiga(ConfigLiga c) {
  for (final m in monedasMundo) {
    if (m.$1 == c.monedaCodigo) return '${m.$2} (${m.$3})';
  }
  return c.moneda == r'$' && c.monedaCodigo.isEmpty ? r'Dólar estadounidense ($)' : c.moneda;
}

/// Subsección para editar algo con "Guardar" (Victor, 2026-11-15: nada de
/// hojas inferiores enormes). Devuelve true si se guarda.
Future<bool?> abrirSubseccion(
  BuildContext context, {
  required String titulo,
  required List<Widget> Function(StateSetter set) contenido,
  String boton = 'Guardar',
}) {
  return Navigator.of(context).push<bool>(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => StatefulBuilder(
        builder: (h, set) => Scaffold(
          appBar: AppBar(
            title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewInsetsOf(h).bottom),
              children: [
                ...contenido(set),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => Navigator.of(h).pop(true),
                  child: Text(boton),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionsBuilder: (_, a, _, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(c),
            child: child,
          ),
        );
      },
    ),
  );
}
