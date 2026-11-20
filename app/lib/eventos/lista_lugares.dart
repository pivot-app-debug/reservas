import 'package:flutter/material.dart';

import '../core/asistente.dart';
import '../core/esqueleto.dart';
import '../core/tema.dart';

/// Paso "¿Dónde será?" de los asistentes (Victor, 2026-11-20): el mismo en
/// Nuevo evento y en Social o fiesta. Buscador, los lugares de la liga (uno
/// por nombre) y "Agregar un lugar". Debajo de cada lugar se dice si tiene
/// ubicación en el mapa, no el tipo de evento con el que se creó.
class ListaLugares extends StatefulWidget {
  const ListaLugares({super.key, required this.lugares, required this.elegido, required this.alElegir, required this.alAgregar, this.error, this.alReintentar});

  /// null = cargando.
  final List<Map<String, dynamic>>? lugares;
  final String? elegido;
  final void Function(Map<String, dynamic> lugar) alElegir;
  final VoidCallback alAgregar;
  final String? error;
  final VoidCallback? alReintentar;

  static bool tieneMapa(Map<String, dynamic> v) => '${v['google_maps'] ?? ''}'.trim().isNotEmpty;

  @override
  State<ListaLugares> createState() => _ListaLugaresState();
}

class _ListaLugaresState extends State<ListaLugares> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: widget.alReintentar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final todos = widget.lugares;
    if (todos == null) return const EsqueletoFilas();
    // Un mismo lugar puede tener varias filas (una por horario o evento): se
    // muestra una vez, prefiriendo la que tiene ubicación.
    final porNombre = <String, Map<String, dynamic>>{};
    for (final v in todos) {
      final k = '${v['lugar'] ?? ''}'.trim().toLowerCase();
      if (k.isEmpty) continue;
      final antes = porNombre[k];
      if (antes == null || (!ListaLugares.tieneMapa(antes) && ListaLugares.tieneMapa(v))) porNombre[k] = v;
    }
    final q = _busqueda.trim().toLowerCase();
    final lista = porNombre.entries.where((e) => q.isEmpty || e.key.contains(q)).map((e) => e.value).toList()
      ..sort((a, b) => '${a['lugar']}'.toLowerCase().compareTo('${b['lugar']}'.toLowerCase()));
    final elegido = widget.elegido?.trim().toLowerCase();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (porNombre.length > 5) ...[
          TextField(
            decoration: const InputDecoration(hintText: 'Buscar lugar', prefixIcon: Icon(Icons.search_rounded)),
            onChanged: (v) => setState(() => _busqueda = v),
          ),
          const SizedBox(height: 12),
        ],
        OpcionAsistente(
          icono: Icons.add_location_alt_outlined,
          titulo: 'Agregar un lugar',
          texto: 'Un lugar que todavía no está en la lista. La ubicación en el mapa es opcional.',
          activa: false,
          alTocar: widget.alAgregar,
        ),
        if (lista.isEmpty && q.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Ningún lugar coincide con la búsqueda.', style: TextStyle(color: p.textoSecundario)),
          ),
        for (final v in lista)
          OpcionAsistente(
            icono: ListaLugares.tieneMapa(v) ? Icons.place_outlined : Icons.location_off_outlined,
            titulo: '${v['lugar']}',
            texto: ListaLugares.tieneMapa(v) ? 'Con ubicación en el mapa' : 'Sin ubicación todavía',
            activa: elegido != null && elegido == '${v['lugar']}'.trim().toLowerCase(),
            alTocar: () => widget.alElegir(v),
          ),
      ],
    );
  }
}
