import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/esqueleto.dart';
import '../core/tema.dart';
import '../sesion/sesion.dart';
import 'tesoreria_repo.dart' show categoriasTesoreria, plata;

const _meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

/// Si la liga muestra sus cuentas (Finanzas › Transparencia). Se consulta una
/// vez por sesión para mostrar u ocultar la fila en Mi perfil.
final transparenciaActiva = ValueNotifier<bool>(false);

Future<void> revisarTransparencia(Sesion s) async {
  try {
    final r = await s.api.post('getTransparencia');
    transparenciaActiva.value = r['activa'] == true;
  } catch (_) {}
}

/// Cuentas de la liga para todo el equipo (Victor, 2026-11-27): total en
/// cuentas, lo de cada mes y los cierres anuales. Solo totales, nunca datos
/// de personas.
class TransparenciaScreen extends StatefulWidget {
  const TransparenciaScreen({super.key, required this.sesion});
  final Sesion sesion;

  @override
  State<TransparenciaScreen> createState() => _TransparenciaScreenState();
}

class _TransparenciaScreenState extends State<TransparenciaScreen> {
  Map<String, dynamic>? _r;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await widget.sesion.api.post('getTransparencia');
      if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo cargar.'}');
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'No se pudo cargar. Revisa tu conexión.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas de la liga')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: r == null
            ? (_error == null ? const Esqueleto(forma: FormaEsqueleto.tarjetas, key: ValueKey('c')) : Center(key: const ValueKey('e'), child: Text(_error!)))
            : r['activa'] != true
            ? Center(
                key: const ValueKey('no'),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'La liga no está mostrando sus cuentas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.textoSecundario),
                  ),
                ),
              )
            : RefreshIndicator(
                key: const ValueKey('l'),
                onRefresh: _cargar,
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: _contenido(p, r)),
              ),
      ),
    );
  }

  Widget _titulo(PivotPaleta p, String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      t,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.texto),
    ),
  );

  Widget _linea(PivotPaleta p, String a, num v, {bool fuerte = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(a, style: TextStyle(color: fuerte ? p.texto : p.textoSecundario)),
        ),
        Text(
          plata(v),
          style: TextStyle(fontWeight: fuerte ? FontWeight.w800 : FontWeight.w600, color: p.texto),
        ),
      ],
    ),
  );

  Widget _tarjeta(List<Widget> hijos) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: hijos),
    ),
  );

  List<Widget> _gastos(PivotPaleta p, Map gastos, {String clave = ''}) {
    final l = [
      for (final e in gastos.entries) (e.key as String, clave.isEmpty ? (e.value as num? ?? 0) : ((e.value as Map?)?[clave] as num? ?? 0)),
    ].where((x) => x.$2 > 0).toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final (k, v) in l) _linea(p, categoriasTesoreria[k] ?? k, v)];
  }

  List<Widget> _contenido(PivotPaleta p, Map<String, dynamic> r) {
    final meses = ((r['meses'] as Map?) ?? const {}).cast<String, dynamic>();
    final claves = meses.keys.toList()..sort((a, b) => b.compareTo(a));
    final cierres = [for (final c in (r['cierres'] as List? ?? const [])) (c as Map).cast<String, dynamic>()];
    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: PivotPaleta.degradadoMarca, borderRadius: BorderRadius.circular(PivotRadios.grande)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total en cuentas', style: TextStyle(color: PivotPaleta.sobreSeccion.withValues(alpha: 0.85))),
            Text(
              plata((r['total'] as num?) ?? 0),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: PivotPaleta.sobreSeccion),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text('Solo se muestran totales: nunca datos de personas.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
      if (cierres.isNotEmpty) ...[
        _titulo(p, 'Cierres de año'),
        for (final c in cierres)
          _tarjeta([
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 18, color: p.marcaTexto),
                const SizedBox(width: 6),
                Text(
                  '${c['anio']}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.texto),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _linea(p, 'Ingresos', (c['ingresos'] as num?) ?? 0),
            _linea(p, 'Egresos', (c['egresos'] as num?) ?? 0),
            _linea(p, 'Resultado del año', (c['resultado'] as num?) ?? 0, fuerte: true),
            _linea(p, 'Saldo al 31 de diciembre', (c['saldoFinal'] as num?) ?? 0, fuerte: true),
            if (((c['categorias'] as Map?) ?? const {}).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'En qué se gastó',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.textoSecundario),
              ),
              ..._gastos(p, (c['categorias'] as Map?) ?? const {}, clave: 'egresos'),
            ],
          ]),
      ],
      _titulo(p, 'Últimos 12 meses'),
      if (claves.isEmpty) Text('Todavía no hay movimientos.', style: TextStyle(color: p.textoSecundario)),
      for (final k in claves)
        _tarjeta([
          Text(
            '${_meses[int.parse(k.substring(5, 7)) - 1][0].toUpperCase()}${_meses[int.parse(k.substring(5, 7)) - 1].substring(1)} ${k.substring(0, 4)}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.texto),
          ),
          const SizedBox(height: 6),
          _linea(p, 'Ingresos', (meses[k]['ingresos'] as num?) ?? 0),
          _linea(p, 'Egresos', (meses[k]['egresos'] as num?) ?? 0),
          ..._gastos(p, (meses[k]['gastos'] as Map?) ?? const {}),
        ]),
    ];
  }
}
