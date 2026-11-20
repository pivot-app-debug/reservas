import 'package:flutter/material.dart';

import '../../core/tema.dart';
import 'social_repo.dart';

/// Pistas sobre mí y wishlist (como Drawnames). Quedan guardadas para el año
/// siguiente; se pueden actualizar cuando quieras.
class PistasScreen extends StatefulWidget {
  const PistasScreen({super.key, required this.repo, required this.inicial});
  final SocialRepo repo;
  final PerfilSocial inicial;

  @override
  State<PistasScreen> createState() => _PistasScreenState();
}

const _sugerenciasGustos = [
  'Chocolate', 'Café', 'Té', 'Libros', 'Plantas', 'Música', 'Videojuegos', 'Juegos de mesa', 'Manualidades', 'Equipamiento deportivo', //
  'Cocina', 'Viajes', 'Maquillaje', 'Stickers', 'Velas', 'Cómics', 'Anime', 'Mascotas', 'Fotografía', 'Accesorios', 'Snacks salados',
];
const _sugerenciasSobreMi = [
  'Soy vegetarianx', 'Soy veganx', 'Tengo mascota', 'Prefiero lo práctico', 'Colecciono cosas', 'Siempre tengo frío', //
  'Me encanta lo hecho a mano', 'Tomo café todos los días', 'No tomo alcohol', 'Me gusta lo personalizado',
];
const _sugerenciasNo = ['Ropa', 'Perfumes', 'Dulces', 'Alcohol', 'Peluches', 'Adornos', 'Tazas', 'Cosas con olor fuerte', 'Maquillaje'];
const _tallasCamiseta = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

class _PistasScreenState extends State<PistasScreen> {
  late final PerfilSocial _p = PerfilSocial.desde(widget.inicial.aJson());
  final _medias = TextEditingController();
  late final _link = TextEditingController(text: _p.wishlistLink);
  bool _guardando = false, _cambios = false;

  @override
  void initState() {
    super.initState();
    _medias.text = _p.tallas['medias'] ?? '';
  }

  @override
  void dispose() {
    _medias.dispose();
    _link.dispose();
    super.dispose();
  }

  void _cambio(VoidCallback f) => setState(() {
    f();
    _cambios = true;
  });

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    _p.wishlistLink = _link.text.trim();
    final m = _medias.text.trim();
    if (m.isEmpty) {
      _p.tallas.remove('medias');
    } else {
      _p.tallas['medias'] = m;
    }
    try {
      await widget.repo.guardarPerfil(_p);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pistas guardadas. Quedan listas también para el próximo año.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool> _salir() async {
    if (!_cambios) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Tus cambios en las pistas no se guardarán.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Seguir editando')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Salir')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _editarDeseo([ItemDeseo? item]) async {
    final texto = TextEditingController(text: item?.texto ?? '');
    final nota = TextEditingController(text: item?.nota ?? '');
    final link = TextEditingController(text: item?.link ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(item == null ? 'Agregar a mi wishlist' : 'Editar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: texto,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(labelText: '¿Qué te gustaría?'),
              ),
              TextField(
                controller: nota,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Nota (opcional)', hintText: 'Color, marca, talla…'),
              ),
              TextField(
                controller: link,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Enlace (opcional)', hintText: 'Pega el enlace de la tienda'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Guardar')),
        ],
      ),
    );
    final t = texto.text.trim(), n = nota.text.trim(), l = link.text.trim();
    texto.dispose();
    nota.dispose();
    link.dispose();
    if (ok != true || t.isEmpty) return;
    _cambio(() {
      if (item == null) {
        _p.wishlist.add(ItemDeseo(texto: t, nota: n, link: l));
      } else {
        item
          ..texto = t
          ..nota = n
          ..link = l;
      }
    });
  }

  void _favorito(ItemDeseo d) {
    if (!d.favorito && _p.wishlist.where((x) => x.favorito).length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puedes marcar hasta 2 favoritos.')));
      return;
    }
    _cambio(() => d.favorito = !d.favorito);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final ideas = _p.gustos.where((g) => !_p.wishlist.any((w) => w.texto.toLowerCase() == g.toLowerCase())).toList();
    return PopScope(
      canPop: !_cambios,
      onPopInvokedWithResult: (hecho, _) async {
        if (hecho) return;
        final nav = Navigator.of(context);
        if (await _salir()) nav.pop(false);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Mis pistas')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text('Ayuda a tu amigo secreto: solo la persona que te toque verá esto.', style: TextStyle(color: p.textoSecundario)),
            _ListaPistas(titulo: 'Cosas que me gustan', items: _p.gustos, sugerencias: _sugerenciasGustos, alCambiar: () => _cambio(() {})),
            _ListaPistas(titulo: 'Cosas sobre mí', items: _p.sobreMi, sugerencias: _sugerenciasSobreMi, alCambiar: () => _cambio(() {})),
            _ListaPistas(titulo: 'No quiero que me regalen', items: _p.noRegalar, sugerencias: _sugerenciasNo, alCambiar: () => _cambio(() {})),
            const SizedBox(height: 24),
            Text(
              'Tallas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
            ),
            const SizedBox(height: 8),
            Text('Camiseta', style: TextStyle(color: p.textoSecundario)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _tallasCamiseta)
                  ChoiceChip(
                    label: Text(t),
                    selected: _p.tallas['camiseta'] == t,
                    onSelected: (s) => _cambio(() => s ? _p.tallas['camiseta'] = t : _p.tallas.remove('camiseta')),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _medias,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'Medias (opcional)', hintText: 'Ej.: 38-40'),
              onChanged: (_) => _cambios = true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Wishlist',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
                  ),
                ),
                TextButton.icon(
                  onPressed: _p.wishlist.length >= 20 ? null : () => _editarDeseo(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            Text('Marca con la estrella hasta 2 favoritos.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
            if (ideas.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Ideas desde lo que te gusta', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final g in ideas)
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: Text(g),
                      onPressed: _p.wishlist.length >= 20 ? null : () => _cambio(() => _p.wishlist.add(ItemDeseo(texto: g))),
                    ),
                ],
              ),
            ],
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Column(
                children: [
                  for (final d in _p.wishlist)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: IconButton(
                        tooltip: d.favorito ? 'Quitar de favoritos' : 'Marcar como favorito',
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                          child: Icon(
                            d.favorito ? Icons.star_rounded : Icons.star_outline_rounded,
                            key: ValueKey(d.favorito),
                            color: d.favorito ? p.marcaTexto : p.textoSecundario,
                          ),
                        ),
                        onPressed: () => _favorito(d),
                      ),
                      title: Text(d.texto),
                      subtitle: (d.nota.isEmpty && d.link.isEmpty)
                          ? null
                          : Text([d.nota, if (d.link.isNotEmpty) 'Con enlace'].where((x) => x.isNotEmpty).join(' · ')),
                      onTap: () => _editarDeseo(d),
                      trailing: IconButton(
                        tooltip: 'Quitar',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _cambio(() => _p.wishlist.remove(d)),
                      ),
                    ),
                ],
              ),
            ),
            // Wishlist externa (Victor, 2026-11-20): para quien prefiere armarla en otra app.
            const SizedBox(height: 20),
            Text(
              '¿Prefieres armarla en otra app?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
            ),
            const SizedBox(height: 4),
            Text(
              'Puedes crear tu lista en Wishdeck (wishdeck.app), Amazon u otra app, con fotos y links de cualquier tienda, y pegar aquí el link para compartirla. '
              'Solo la ve quien te regala. Ojo: cualquiera que tenga ese link puede abrir la lista.',
              style: TextStyle(fontSize: 13, color: p.textoSecundario),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Link de mi wishlist (opcional)', prefixIcon: Icon(Icons.link_rounded)),
              onChanged: (_) => setState(() => _cambios = true),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'Guardando…' : 'Guardar mis pistas'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista de pistas con un campo para escribir y sugerencias en chips que se
/// agregan a la lista con un toque.
class _ListaPistas extends StatefulWidget {
  const _ListaPistas({required this.titulo, required this.items, required this.sugerencias, required this.alCambiar});
  final String titulo;
  final List<String> items;
  final List<String> sugerencias;
  final VoidCallback alCambiar;

  @override
  State<_ListaPistas> createState() => _ListaPistasState();
}

class _ListaPistasState extends State<_ListaPistas> {
  final _campo = TextEditingController();

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  bool _tiene(String t) => widget.items.any((x) => x.toLowerCase() == t.toLowerCase());

  void _agregar(String t) {
    final v = t.trim();
    if (v.isEmpty || _tiene(v) || widget.items.length >= 30) return;
    widget.items.add(v);
    _campo.clear();
    widget.alCambiar();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final sugeridas = widget.sugerencias.where((s) => !_tiene(s)).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.titulo,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
            ),
            const SizedBox(height: 8),
            if (widget.items.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in widget.items)
                    InputChip(
                      label: Text(t),
                      selected: true,
                      showCheckmark: false,
                      onDeleted: () {
                        widget.items.remove(t);
                        widget.alCambiar();
                      },
                    ),
                ],
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _campo,
              maxLength: 60,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Escribe y presiona Agregar',
                counterText: '',
                suffixIcon: IconButton(tooltip: 'Agregar', icon: const Icon(Icons.add_rounded), onPressed: () => _agregar(_campo.text)),
              ),
              onSubmitted: _agregar,
            ),
            if (sugeridas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in sugeridas.take(12)) ActionChip(avatar: const Icon(Icons.add_rounded, size: 16), label: Text(s), onPressed: () => _agregar(s)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
