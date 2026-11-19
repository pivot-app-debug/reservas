import 'package:flutter/material.dart';

import '../../core/fechas.dart';
import '../../core/moneda.dart';
import '../../core/tema.dart';
import 'social_repo.dart';

/// Opciones del evento Social (solo Pivots): módulos, topes, cierre de la
/// inscripción al amigo secreto (máximo 2 semanas antes) y categorías de la
/// comida compartida. Se abre al crear un evento Social y desde su detalle.
class SocialConfigScreen extends StatefulWidget {
  const SocialConfigScreen({super.key, required this.repo, required this.fechaEvento, this.actual});
  final SocialRepo repo;
  final DateTime fechaEvento;
  final EstadoSocial? actual;

  @override
  State<SocialConfigScreen> createState() => _SocialConfigScreenState();
}

class _Categoria {
  _Categoria({this.id, String nombre = '', String unidad = 'porciones', num porPersona = 1})
    : nombre = TextEditingController(text: nombre),
      unidad = TextEditingController(text: unidad),
      porPersona = TextEditingController(text: '$porPersona');
  final String? id;
  final TextEditingController nombre, unidad, porPersona;

  void dispose() {
    nombre.dispose();
    unidad.dispose();
    porPersona.dispose();
  }
}

class _SocialConfigScreenState extends State<SocialConfigScreen> {
  bool _amigo = true, _robado = false, _comida = true, _invitados = true, _guardando = false;
  final _topeAmigo = TextEditingController(), _topeRobado = TextEditingController(), _recordatorio = TextEditingController();
  late DateTime _cierre = _limite;
  final List<_Categoria> _cats = [];

  DateTime get _limite => widget.fechaEvento.subtract(const Duration(days: 14));

  @override
  void initState() {
    super.initState();
    final a = widget.actual;
    if (a != null && a.configurado) {
      _amigo = a.modulo('amigoSecreto');
      _robado = a.modulo('regaloRobado');
      _comida = a.modulo('comida');
      _invitados = a.modulo('invitados');
      if (a.topeAmigo != null) _topeAmigo.text = '${a.topeAmigo}';
      if (a.topeRobado != null) _topeRobado.text = '${a.topeRobado}';
      _recordatorio.text = a.recordatorioRobado;
      if (a.cierre != null) _cierre = a.cierre!;
      for (final c in a.comida) {
        _cats.add(_Categoria(id: c.id, nombre: c.nombre, unidad: c.unidad, porPersona: c.porPersona));
      }
    } else {
      _cats.addAll([
        _Categoria(nombre: 'Bebidas', unidad: 'litros', porPersona: 0.5),
        _Categoria(nombre: 'Salado', porPersona: 1),
        _Categoria(nombre: 'Snacks', porPersona: 1),
        _Categoria(nombre: 'Postres', porPersona: 1),
      ]);
    }
  }

  @override
  void dispose() {
    _topeAmigo.dispose();
    _topeRobado.dispose();
    _recordatorio.dispose();
    for (final c in _cats) {
      c.dispose();
    }
    super.dispose();
  }

  num? _n(TextEditingController c) => num.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _elegirCierre() async {
    final hoy = Fechas.hoy();
    final primero = hoy.isAfter(_limite) ? _limite : hoy;
    final f = await showDatePicker(context: context, firstDate: primero, lastDate: _limite, initialDate: _cierre.isAfter(_limite) ? _limite : _cierre);
    if (f != null) setState(() => _cierre = f);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final r = await widget.repo.guardarConfig(
        {
          'amigoSecreto': _amigo,
          'regaloRobado': _robado,
          'comida': _comida,
          'invitados': _invitados,
          'topeAmigo': _n(_topeAmigo),
          'topeRobado': _n(_topeRobado),
          'recordatorioRobado': _recordatorio.text.trim(),
          'cierre': Fechas.iso(_cierre),
        },
        [
          for (final c in _cats)
            if (c.nombre.text.trim().isNotEmpty)
              {'id': c.id, 'nombre': c.nombre.text.trim(), 'unidad': c.unidad.text.trim(), 'porPersona': _n(c.porPersona) ?? 1},
        ],
      );
      if (!mounted) return;
      final avisos = [for (final x in (r['avisos'] as List? ?? const [])) '$x'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(avisos.isEmpty ? 'Evento social guardado.' : avisos.join('\n'))));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _seccion(String t) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        t,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
      ),
    );
  }

  Widget _desplegable(bool visible, Widget child) => AnimatedSize(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: visible ? 1 : 0,
      child: visible ? child : const SizedBox(width: double.infinity),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Scaffold(
      appBar: AppBar(title: const Text('Evento social')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text('Elige qué tendrá el evento. Lo puedes cambiar después.', style: TextStyle(color: p.textoSecundario)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Amigo secreto'),
            subtitle: const Text('Sorteo con ruleta, pistas y wishlist'),
            value: _amigo,
            onChanged: (v) => setState(() => _amigo = v),
          ),
          _desplegable(
            _amigo,
            Column(
              children: [
                TextField(
                  controller: _topeAmigo,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Tope del regalo (opcional)', prefixText: Moneda.s),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_busy_outlined),
                  title: const Text('Cierre de la inscripción'),
                  subtitle: Text('${Fechas.corta(_cierre)} · como máximo 2 semanas antes del evento. Quien se suma después no entra al amigo secreto.'),
                  onTap: _elegirCierre,
                ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Regalo robado'),
            subtitle: const Text('Tope de presupuesto y recordatorio'),
            value: _robado,
            onChanged: (v) => setState(() => _robado = v),
          ),
          _desplegable(
            _robado,
            Column(
              children: [
                TextField(
                  controller: _topeRobado,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Tope del regalo robado (opcional)', prefixText: Moneda.s),
                ),
                TextField(
                  controller: _recordatorio,
                  maxLength: 300,
                  maxLines: null,
                  decoration: const InputDecoration(labelText: 'Recordatorio (opcional)', hintText: 'Ej.: Envuelto y sin nombre'),
                ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Invitadxs +1'),
            subtitle: const Text('Cada persona puede sumar invitadxs, que entran con un enlace y sin cuenta'),
            value: _invitados,
            onChanged: (v) => setState(() => _invitados = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Comida compartida'),
            subtitle: const Text('Categorías con meta por asistente; cada quien se anota con lo que lleva'),
            value: _comida,
            onChanged: (v) => setState(() => _comida = v),
          ),
          _desplegable(
            _comida,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _seccion('Categorías'),
                Text('Cantidad por asistente: la meta es asistentes (con sus +1) × cantidad.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                for (final c in _cats)
                  Padding(
                    key: ObjectKey(c),
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: c.nombre,
                            decoration: const InputDecoration(labelText: 'Nombre'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: c.unidad,
                            decoration: const InputDecoration(labelText: 'Unidad'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: c.porPersona,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Por persona'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quitar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            setState(() => _cats.remove(c));
                            WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
                          },
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => setState(() => _cats.add(_Categoria())),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar categoría'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _guardando ? null : _guardar,
            child: Text(_guardando ? 'Guardando…' : 'Guardar'),
          ),
        ),
      ),
    );
  }
}
