import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../sesion/sesion.dart';
import '../core/moneda.dart';

/// Recompensas automáticas (Victor, 2026-11-15): reglas que un Pivot arma
/// para premiar la asistencia. Se otorgan solas y avisan a la persona.
class ReglaRecompensa {
  ReglaRecompensa(this.d);
  final Map<String, dynamic> d;
  String? get id => d['id'] as String?;
  String get nombre => '${d['nombre'] ?? 'Recompensa'}';
  bool get activa => d['activa'] != false;
  String? get equipo => (d['equipo'] as String?)?.isEmpty == true ? null : d['equipo'] as String?;
  Map<String, dynamic> get condicion => (d['condicion'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get premio => (d['premio'] as Map?)?.cast<String, dynamic>() ?? const {};
  int get otorgadas => (d['otorgadas'] as num?)?.toInt() ?? 0;
  String get resumen => 'Por ${d['condicionTexto'] ?? ''}: ${d['premioTexto'] ?? ''}';
}

class RecompensasRepo {
  RecompensasRepo(this.s);
  final Sesion s;

  Future<List<ReglaRecompensa>> _llamar(Map<String, Object?> extra) async {
    final r = await s.api.post('adminRecompensas', {'adminToken': s.adminToken, ...extra});
    if (r['exito'] == false) throw ApiException('${r['error'] ?? 'No se pudo completar.'}');
    return [
      for (final x in (r['reglas'] as List? ?? const []))
        if (x is Map<String, dynamic>) ReglaRecompensa(x),
    ];
  }

  Future<List<ReglaRecompensa>> listar() => _llamar({'op': 'listar'});
  Future<List<ReglaRecompensa>> guardar(Map<String, Object?> regla) => _llamar({'op': 'guardar', 'regla': regla});
  Future<List<ReglaRecompensa>> eliminar(String id) => _llamar({'op': 'eliminar', 'id': id});
}

/// Asistente por pasos: qué se premia, cuánto, para quién, qué se recibe y
/// resumen. Con [regla] edita una existente (rige desde que se guarda).
class RecompensaAsistenteScreen extends StatefulWidget {
  const RecompensaAsistenteScreen({super.key, required this.repo, required this.equipos, this.regla});
  final RecompensasRepo repo;
  final List<String> equipos;
  final ReglaRecompensa? regla;

  @override
  State<RecompensaAsistenteScreen> createState() => _RecompensaAsistenteScreenState();
}

class _Tipo {
  const _Tipo(this.clave, this.icono, this.titulo, this.texto, this.opciones, this.unidad);
  final String clave, titulo, texto;
  final IconData icono;
  final List<int> opciones;
  final String Function(int) unidad;
}

const _tipos = [
  _Tipo('racha', Icons.local_fire_department_outlined, 'Asistir seguido', 'Cada vez que alguien llega a N asistencias seguidas sin faltar.', [
    3,
    5,
    8,
    10,
    15,
    20,
  ], _veces),
  _Tipo(
    'asistencias_mes',
    Icons.event_available_outlined,
    'Venir muchas veces en el mes',
    'Al cerrar el mes, a quien asistió N veces o más a entrenamientos.',
    [4, 6, 8, 10, 12, 16],
    _veces,
  ),
  _Tipo(
    'porcentaje_mes',
    Icons.percent_rounded,
    'Porcentaje de asistencia del mes',
    'Al cerrar el mes, a quien asistió a ese porcentaje de los entrenamientos o más.',
    [50, 75, 80, 90, 100],
    _porc,
  ),
];
String _veces(int n) => '$n ${n == 1 ? 'vez' : 'veces'}';
String _porc(int n) => '$n %';

class _RecompensaAsistenteScreenState extends State<RecompensaAsistenteScreen> {
  int _paso = 0;
  bool _adelante = true;
  late String _tipo = '${widget.regla?.condicion['tipo'] ?? ''}';
  late int _valor = (widget.regla?.condicion['valor'] as num?)?.toInt() ?? 0;
  late String? _equipo = widget.regla?.equipo;
  late int _puntos = (widget.regla?.premio['puntos'] as num?)?.toInt() ?? 0;
  late bool _conPuntos = widget.regla == null || _puntos > 0;
  late bool _clase = widget.regla?.premio['claseGratis'] == true;
  late bool _mensualidad = widget.regla?.premio['mensualidadGratis'] == true;
  late bool _conSaldo = ((widget.regla?.premio['saldo'] as num?) ?? 0) > 0;
  late final _saldo = TextEditingController(text: _conSaldo ? '${widget.regla!.premio['saldo']}' : '');
  late final _nombre = TextEditingController(text: widget.regla?.nombre ?? '');
  bool _nombreTocado = false, _guardando = false;

  @override
  void initState() {
    super.initState();
    if (_puntos == 0) _puntos = 2;
    _nombreTocado = widget.regla != null;
  }

  @override
  void dispose() {
    _saldo.dispose();
    _nombre.dispose();
    super.dispose();
  }

  _Tipo? get _t => _tipos.where((t) => t.clave == _tipo).firstOrNull;
  num get _montoSaldo => num.tryParse(_saldo.text.replaceAll(',', '.')) ?? 0;

  String get _textoPremio {
    final p = [
      if (_conPuntos) _puntos == 1 ? 'un punto extra' : '$_puntos puntos extra',
      if (_clase) 'una clase gratis',
      if (_mensualidad) 'la mensualidad del mes siguiente gratis',
      if (_conSaldo && _montoSaldo > 0) '${Moneda.s}${_montoSaldo % 1 == 0 ? _montoSaldo.toInt() : _montoSaldo} de saldo a favor',
    ];
    return p.length > 1 ? '${p.sublist(0, p.length - 1).join(', ')} y ${p.last}' : (p.isEmpty ? '' : p.first);
  }

  String get _textoCondicion {
    final t = _t;
    if (t == null) return '';
    return switch (t.clave) {
      'racha' => 'asistir $_valor veces seguidas',
      'asistencias_mes' => 'asistir ${_veces(_valor)} en el mes',
      _ => 'asistir al $_valor % de los entrenamientos del mes',
    };
  }

  String get _nombreSugerido => switch (_tipo) {
    'racha' => 'Racha de $_valor',
    'asistencias_mes' => '$_valor asistencias en el mes',
    _ => _valor == 100 ? 'Asistencia perfecta' : '$_valor % de asistencia',
  };

  bool get _pasoListo => switch (_paso) {
    0 => _t != null,
    1 => _valor > 0,
    2 => true,
    3 => _textoPremio.isNotEmpty,
    _ => _nombre.text.trim().isNotEmpty,
  };

  void _ir(int d) {
    setState(() {
      _adelante = d > 0;
      _paso += d;
      if (_paso == 4 && !_nombreTocado) _nombre.text = _nombreSugerido;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await widget.repo.guardar({
        if (widget.regla?.id != null) 'id': widget.regla!.id,
        'nombre': _nombre.text.trim(),
        'activa': widget.regla?.activa ?? true,
        'equipo': _equipo,
        'condicion': {'tipo': _tipo, 'valor': _valor},
        'premio': {'puntos': _conPuntos ? _puntos : 0, 'claseGratis': _clase, 'mensualidadGratis': _mensualidad, 'saldo': _conSaldo ? _montoSaldo : 0},
      });
      m.showSnackBar(SnackBar(content: Text(widget.regla == null ? 'Recompensa creada. Rige desde hoy.' : 'Guardado. Rige desde ahora.')));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Borrar "${widget.regla!.nombre}"?'),
        content: const Text('Deja de darse desde ahora. Lo que ya se dio no cambia.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    try {
      await widget.repo.eliminar(widget.regla!.id!);
      m.showSnackBar(const SnackBar(content: Text('Recompensa borrada.')));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo borrar. Revisa tu conexión.')));
    }
  }

  Widget _tarjetaOpcion({required bool sel, required VoidCallback alTocar, required Widget child}) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: sel ? p.suave : p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        child: InkWell(
          borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
          onTap: alTocar,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              border: Border.all(color: sel ? p.marca : p.tarjetaBorde, width: sel ? 1.6 : 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _premio(IconData icono, String titulo, String texto, bool valor, ValueChanged<bool> alCambiar, {Widget? extra}) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, color: p.textoSecundario),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                      ),
                      Text(texto, style: TextStyle(fontSize: 13, height: 1.35, color: p.textoSecundario)),
                    ],
                  ),
                ),
                Switch(value: valor, onChanged: alCambiar),
              ],
            ),
            if (extra != null)
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: valor ? Padding(padding: const EdgeInsets.only(left: 36, top: 10), child: extra) : const SizedBox(width: double.infinity),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    final p = context.pivot;
    final t = _t;
    switch (_paso) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final x in _tipos)
              _tarjetaOpcion(
                sel: _tipo == x.clave,
                alTocar: () => setState(() {
                  if (_tipo != x.clave) _valor = 0;
                  _tipo = x.clave;
                }),
                child: Row(
                  children: [
                    Icon(x.icono, color: _tipo == x.clave ? p.marcaTexto : p.textoSecundario),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            x.titulo,
                            style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                          ),
                          const SizedBox(height: 2),
                          Text(x.texto, style: TextStyle(fontSize: 13, height: 1.35, color: p.textoSecundario)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in t!.opciones) ChoiceChip(label: Text(t.unidad(n)), selected: _valor == n, onSelected: (_) => setState(() => _valor = n)),
              ],
            ),
            const SizedBox(height: 14),
            if (_tipo == 'racha')
              Text(
                'Se cuentan las asistencias marcadas a horario o tarde, una detrás de otra. Faltar a un evento reinicia la cuenta.',
                style: TextStyle(fontSize: 13, height: 1.4, color: p.textoSecundario),
              )
            else
              Text(
                'Se cuentan los entrenamientos del mes no cancelados y las asistencias a horario o tarde. Se revisa el primer día del mes siguiente.',
                style: TextStyle(fontSize: 13, height: 1.4, color: p.textoSecundario),
              ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in <String?>[null, ...widget.equipos])
              _tarjetaOpcion(
                sel: _equipo == e,
                alTocar: () => setState(() => _equipo = e),
                child: Text(
                  e ?? 'Toda la liga',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                ),
              ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _premio(
              Icons.star_outline_rounded,
              'Puntos extra',
              'Se suman a sus puntos del mes.',
              _conPuntos,
              (v) => setState(() => _conPuntos = v),
              extra: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in [1, 2, 3, 5, 10])
                    ChoiceChip(label: Text('$n ${n == 1 ? 'punto' : 'puntos'}'), selected: _puntos == n, onSelected: (_) => setState(() => _puntos = n)),
                ],
              ),
            ),
            _premio(
              Icons.local_activity_outlined,
              'Clase gratis',
              'Para reservar una clase suelta sin pagar. No se acumula.',
              _clase,
              (v) => setState(() => _clase = v),
            ),
            _premio(
              Icons.calendar_month_outlined,
              'Mensualidad gratis',
              'No paga la mensualidad del mes siguiente. Si ya la pagó, se le da como saldo a favor.',
              _mensualidad,
              (v) => setState(() => _mensualidad = v),
            ),
            _premio(
              Icons.savings_outlined,
              'Saldo a favor',
              'Un monto para su próximo pago, como un descuento.',
              _conSaldo,
              (v) => setState(() => _conSaldo = v),
              extra: TextField(
                controller: _saldo,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(labelText: 'Monto', prefixText: '${Moneda.s} '),
              ),
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nombre,
              onChanged: (_) => setState(() => _nombreTocado = true),
              decoration: const InputDecoration(labelText: 'Nombre de la recompensa'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
              child: Text(
                '${_equipo == null ? 'En toda la liga' : 'En $_equipo'}, quien logra $_textoCondicion recibe $_textoPremio. '
                'Se da sola y le llega un aviso.',
                style: TextStyle(height: 1.45, color: p.sobreSuave),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _tipo == 'racha'
                  ? 'Rige desde que la guardas: cuenta para las asistencias que se marquen desde ahora.'
                  : 'Rige desde que la guardas: se revisa con los meses completos que empiecen después.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: p.textoSecundario),
            ),
          ],
        );
    }
  }

  static const _titulos = ['¿Qué quieres premiar?', '¿Cuánto?', '¿Para quién?', '¿Qué se recibe?', 'Revisa y guarda'];

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final ultimo = _paso == _titulos.length - 1;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: Text(widget.regla == null ? 'Nueva recompensa' : 'Editar recompensa', style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [if (widget.regla?.id != null) IconButton(tooltip: 'Borrar', icon: const Icon(Icons.delete_outline_rounded), onPressed: _borrar)],
      ),
      body: Column(
        children: [
          SizedBox(height: altoBarra(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                for (var i = 0; i < _titulos.length; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: i <= _paso ? p.marca : p.bordeSuave, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: Offset(_adelante ? 0.08 : -0.08, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
              child: ListView(
                key: ValueKey(_paso),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                children: [
                  Text(
                    _titulos[_paso],
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.texto),
                  ),
                  if (_paso == 0) ...[
                    const SizedBox(height: 6),
                    Text('Se da sola cuando alguien cumple la condición, con un aviso.', style: TextStyle(fontSize: 14, color: p.textoSecundario)),
                  ],
                  const SizedBox(height: 16),
                  _contenido(),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.paddingOf(context).bottom),
            child: Row(
              children: [
                if (_paso > 0) ...[
                  Expanded(
                    child: OutlinedButton(onPressed: () => _ir(-1), child: const Text('Atrás')),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: !_pasoListo || _guardando ? null : (ultimo ? _guardar : () => _ir(1)),
                    child: Text(ultimo ? (_guardando ? 'Guardando…' : 'Guardar') : 'Siguiente'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
