part of 'cursos_screen.dart';

/// Nuevo curso paso a paso (Victor, 2026-11-17): tipo, nombre, clases con
/// sus temas, evaluación (se arma sola con los temas), equipo al aprobar,
/// precio y resumen. Los temas son habilidades de la lista de la liga (o
/// nuevas, cortas), así la evaluación llega a la ficha deportiva.
enum _PasoCurso { origen, tipo, nombre, para, clases, evaluacion, equipo, precio, resumen }

class _AsistenteCurso extends StatefulWidget {
  const _AsistenteCurso({
    this.curso,
    required this.equipos,
    required this.lugares,
    required this.habilidades,
    this.plantillas = const [],
    this.personas = const [],
    this.anteriores = const [],
    this.nivelPersonas = const {},
    this.borrador,
    this.alBorrador,
  });

  /// Cursos que ya armó la liga, para reutilizarlos (Victor, 2026-11-27).
  final List<Curso> anteriores;

  /// Nivel de cada persona (username → clave), para ver quiénes están en un nivel.
  final Map<String, String> nivelPersonas;

  /// Curso a medio armar que se retoma (ver [_AsistenteCursoState._borrador]).
  final Map<String, dynamic>? borrador;

  /// Guarda el borrador en cada paso (solo cursos nuevos).
  final void Function(Map<String, dynamic> datos)? alBorrador;

  /// Gente de la liga, para cursos individuales: (username, nombre, foto).
  final List<(String, String, String)> personas;
  final Curso? curso;
  final List<String> equipos, lugares;
  final List<Map<String, dynamic>> habilidades;

  /// Pre-armados (Freshmeat en roller derby y los que guarda la liga).
  final List<Map<String, dynamic>> plantillas;
  @override
  State<_AsistenteCurso> createState() => _AsistenteCursoState();
}

class _AsistenteCursoState extends State<_AsistenteCurso> {
  /// Un borrador se arma como un curso sin id; [_nuevo] dice si se edita uno guardado.
  late final Map<String, dynamic>? _b = widget.curso == null ? widget.borrador : null;
  late final Curso? o = widget.curso ?? (_b?['curso'] is Map ? Curso(Map<String, dynamic>.from(_b!['curso'] as Map)) : null);
  bool get _nuevo => widget.curso == null;
  late _PasoCurso _paso = _PasoCurso.values.where((x) => x.name == _b?['paso']).firstOrNull ?? (_nuevo && _hayOrigen ? _PasoCurso.origen : _PasoCurso.tipo);
  bool get _hayOrigen => widget.plantillas.isNotEmpty || _anteriores.isNotEmpty;

  /// Clases de la plantilla elegida, sin fechas todavía.
  late List<Map<String, dynamic>>? _dePlantilla = _b?['dePlantilla'] is List
      ? [for (final c in _b!['dePlantilla'] as List) Map<String, dynamic>.from(c as Map)]
      : null;
  bool _adelante = true;

  late String _tipo = o?.tipo ?? 'curso';

  // Curso abierto: se repite cada semana hasta que se termina (Victor, 2026-11-17).
  late bool _abierto = o?.abierto ?? false;
  late final Set<String> _dias = {for (final d in (o?.repite?['dias'] as List? ?? const [])) '$d'};
  late String _hora = '${o?.repite?['hora'] ?? _habitual.$1 ?? '19:00'}';
  late String? _termina = o?.repite?['termina'] as String?;
  late String _lugar = '${o?.repite?['lugar'] ?? _lugarHabitual}';

  /// Hora y lugar de siempre (Victor, 2026-11-26): los que más se repiten en
  /// los entrenamientos del calendario, para precargarlos.
  late final (String?, String?) _habitual = () {
    final evs = [...?EventosRepo.actual?.eventos.where((e) => e.tipo == 'Entrenamiento' && !e.cancelado)];
    String? masComun(Iterable<String> l) {
      final c = <String, int>{};
      for (final x in l) {
        if (x.isNotEmpty) c[x] = (c[x] ?? 0) + 1;
      }
      return c.isEmpty ? null : (c.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    }

    return (masComun(evs.map((e) => e.horaInicio)), masComun(evs.map((e) => e.lugar)));
  }();
  String get _lugarHabitual => widget.lugares.contains(_habitual.$2) ? _habitual.$2! : (widget.lugares.isEmpty ? '' : widget.lugares.first);
  late final List<String> _temasCurso = [...?o?.temasCurso];

  // Para quién: toda la liga, equipos, un nivel o personas.
  late String _paraTipo = '${o?.para['tipo'] ?? 'todos'}';
  late final Set<String> _paraValores = {for (final v in (o?.para['valores'] as List? ?? const [])) '$v'};
  bool get _clinica => _tipo == 'clinica';
  late final _nombre = TextEditingController(text: o?.nombre ?? '');
  late final _descripcion = TextEditingController(text: o?.descripcion ?? '');
  late final _precio = TextEditingController(
    text: _b?['precioTexto'] as String? ?? (o == null || o!.precio == 0 ? '' : '${o!.precio % 1 == 0 ? o!.precio.toInt() : o!.precio}'),
  );
  late bool _cobrar = _b?['cobrar'] as bool? ?? (o?.precio ?? 0) > 0;
  final _buscaPersona = TextEditingController();
  late bool _conCupo = o?.cupo != null;
  late int _cupo = o?.cupo ?? 20;
  late bool _cambiaEquipo = o?.cambiaEquipo ?? false;
  late String? _equipo = o?.equipoDestino;

  late final List<Map<String, dynamic>> _clases = [
    for (var i = 0; i < (o?.fechas.length ?? 0); i++)
      if (Curso.tipoFecha(o!.fechas, i) != 'evaluacion') {...o!.fechas[i], 'tipo': Curso.tipoFecha(o!.fechas, i)},
  ];
  late Map<String, dynamic>? _evalFecha = [
    for (var i = 0; i < (o?.fechas.length ?? 0); i++)
      if (Curso.tipoFecha(o!.fechas, i) == 'evaluacion') o!.fechas[i],
  ].firstOrNull;
  late bool _conEvaluacion = _b?['conEvaluacion'] as bool? ?? (o == null || _evalFecha != null || o!.temasEvaluacion.isNotEmpty);

  // Temas de la evaluación con su mínimo; los quitados a mano no vuelven solos.
  late final List<Map<String, dynamic>> _evalTemas = [for (final t in o?.temasEvaluacion ?? const <Map<String, dynamic>>[]) Map<String, dynamic>.from(t)];
  final Set<String> _quitados = {};

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _precio.dispose();
    _buscaPersona.dispose();
    super.dispose();
  }

  /// Sin cobrar: gratis. Cobrando: el precio tiene que ser mayor a 0.
  num? get _monto => !_cobrar ? 0 : num.tryParse(_precio.text.trim().replaceAll(',', '.'));

  /// Curso solo para habilidades avanzadas: los temas son solo avanzados.
  /// Curso para un solo nivel que no es el primero: los temas son de ese
  /// nivel (niveles de la liga, 2026-11-27).
  String? get _soloNivel {
    if (_paraTipo != 'nivel' || _paraValores.length != 1) return null;
    final v = switch (_paraValores.first) {
      'basicas' => 'basica',
      'avanzadas' => 'avanzada',
      final x => x,
    };
    return v != 'sin' && v != NivelesCoach.primero && NivelesCoach.lista.any((n) => n.clave == v) ? v : null;
  }

  List<_PasoCurso> get _pasos => [
    if (_nuevo && _hayOrigen) _PasoCurso.origen,
    _PasoCurso.tipo,
    _PasoCurso.nombre,
    _PasoCurso.para,
    _PasoCurso.clases,
    _PasoCurso.evaluacion,
    if (_conEvaluacion && widget.equipos.isNotEmpty) _PasoCurso.equipo,
    _PasoCurso.precio,
    _PasoCurso.resumen,
  ];

  /// Temas de todas las clases, en orden y sin repetir.
  List<String> get _temasClases {
    final out = <String>[if (_abierto) ..._temasCurso];
    for (final c in _clases) {
      for (final t in (c['temas'] as List? ?? const [])) {
        if (!out.any((x) => x.toLowerCase() == '$t'.toLowerCase())) out.add('$t');
      }
    }
    return out;
  }

  /// La evaluación suma sola los temas nuevos de las clases.
  void _sincronizarEvaluacion() {
    for (final t in _temasClases) {
      if (_quitados.contains(t.toLowerCase())) continue;
      if (!_evalTemas.any((x) => '${x['nombre']}'.toLowerCase() == t.toLowerCase())) _evalTemas.add({'nombre': t, 'minimo': 5});
    }
  }

  bool get _evalAntes => _evalFecha != null && _clases.isNotEmpty && '${_evalFecha!['fecha']}'.compareTo('${_clases.last['fecha']}') < 0;

  bool get _valido => switch (_paso) {
    _PasoCurso.origen || _PasoCurso.tipo => true,
    _PasoCurso.nombre => _nombre.text.trim().isNotEmpty,
    _PasoCurso.para => _paraTipo == 'todos' || _paraValores.isNotEmpty,
    _PasoCurso.clases => _abierto ? _dias.isNotEmpty : _clases.isNotEmpty,
    _PasoCurso.evaluacion => !_conEvaluacion || (!_evalAntes && _evalTemas.isNotEmpty),
    _PasoCurso.equipo => !_cambiaEquipo || _equipo != null,
    _PasoCurso.precio => !_cobrar || (_monto ?? 0) > 0,
    _PasoCurso.resumen => true,
  };

  void _ir(int d) {
    final l = _pasos;
    final i = l.indexOf(_paso) + d;
    if (i < 0) {
      Navigator.of(context).pop();
      return;
    }
    if (i >= l.length) return;
    setState(() {
      _adelante = d > 0;
      _paso = l[i];
      if (_paso == _PasoCurso.evaluacion) _sincronizarEvaluacion();
    });
    _guardarBorrador();
  }

  /// Curso a medio armar (Victor, 2026-11-27): se guarda en el servidor en
  /// cada paso para retomarlo con «Reanudar», desde cualquier teléfono.
  Map<String, dynamic> get _borrador => {
    'curso': _resultado,
    'paso': _paso.name,
    'conEvaluacion': _conEvaluacion,
    'cobrar': _cobrar,
    'precioTexto': _precio.text,
    'dePlantilla': ?_dePlantilla,
  };

  void _guardarBorrador() {
    if (!_nuevo || widget.alBorrador == null) return;
    // Sin nada armado todavía no hace falta guardar.
    if (_nombre.text.trim().isEmpty && _clases.isEmpty && _dePlantilla == null && _paso.index <= _PasoCurso.tipo.index) return;
    widget.alBorrador!(_borrador);
  }

  // ── Fechas ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _elegirFecha(Map<String, dynamic>? previa, DateTime sugerida, {required String tituloHora}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: previa == null ? sugerida : (Curso.fecha(previa) ?? sugerida),
      firstDate: Fechas.hoy().subtract(const Duration(days: 365)),
      lastDate: Fechas.hoy().add(const Duration(days: 730)),
    );
    if (d == null || !mounted) return null;
    final base = previa ?? (_clases.isEmpty ? null : _clases.last);
    final h = await elegirHoraTexto(context, inicial: '${base?['hora'] ?? _habitual.$1 ?? '09:00'}', titulo: tituloHora);
    if (h == null || !mounted) return null;
    var lugar = '${base?['lugar'] ?? _lugarHabitual}';
    if (widget.lugares.length > 1) {
      final l = await showModalBottomSheet<String>(
        useRootNavigator: true,
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('¿Dónde?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              for (final x in widget.lugares)
                ListTile(
                  leading: Icon(x == lugar ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                  title: Text(x),
                  onTap: () => Navigator.of(c).pop(x),
                ),
            ],
          ),
        ),
      );
      if (l == null) return null;
      lugar = l;
    }
    return {...?previa, 'fecha': Fechas.iso(d), 'hora': h, 'lugar': lugar};
  }

  static String _sumarHoras(String hhmm, int h) {
    final p = hhmm.split(':');
    final x = ((int.tryParse(p.first) ?? 9) + h) % 24;
    return '${x.toString().padLeft(2, '0')}:${p.length > 1 ? p[1] : '00'}';
  }

  Future<void> _clase([int? i, String tipo = 'clase']) async {
    final ultima = _clases.isEmpty ? null : Curso.fecha(_clases.last);
    var f = await _elegirFecha(i == null ? null : _clases[i], ultima == null ? Fechas.hoy() : ultima.add(const Duration(days: 7)), tituloHora: 'Empieza');
    if (f == null || !mounted) return;
    final t = i == null ? tipo : '${_clases[i]['tipo'] ?? 'clase'}';
    f = {...f, 'tipo': t};
    if (t == 'clinica' || _clinica) {
      final fin = await elegirHoraTexto(context, inicial: '${f['termina'] ?? _sumarHoras('${f['hora']}', _clinica ? 5 : 2)}', titulo: 'Termina');
      if (fin == null || !mounted) return;
      f['termina'] = fin;
    }
    final nueva = f;
    setState(() {
      if (_clinica) {
        _clases
          ..clear()
          ..add(nueva);
      } else if (i == null) {
        _clases.add(nueva);
      } else {
        _clases[i] = nueva;
      }
      _clases.sort((a, b) => '${a['fecha']}'.compareTo('${b['fecha']}'));
    });
  }

  /// Elige temas de la lista de habilidades o crea uno corto.
  Future<String?> _elegirTema({Set<String> ya = const {}}) => showModalBottomSheet<String>(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _HojaTemas(habilidades: widget.habilidades, ya: ya, soloNivel: _soloNivel),
  );

  Future<void> _agregarTema(int i) async {
    final ya = {for (final t in (_clases[i]['temas'] as List? ?? const [])) '$t'.toLowerCase()};
    final t = await _elegirTema(ya: ya);
    if (t == null || !mounted) return;
    setState(() {
      final l = [for (final x in (_clases[i]['temas'] as List? ?? const [])) '$x', t];
      _clases[i] = {..._clases[i], 'temas': l};
      _quitados.remove(t.toLowerCase());
    });
  }

  // ── Pasos ───────────────────────────────────────────────────────────────

  void _usarPlantilla(Map<String, dynamic>? pl) {
    setState(() {
      if (pl == null) {
        _dePlantilla = null;
      } else {
        _tipo = '${pl['tipo'] ?? 'curso'}';
        _nombre.text = '${pl['nombre']}';
        _descripcion.text = '${pl['descripcion'] ?? ''}';
        _dePlantilla = [for (final c in (pl['clases'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
        _clases.clear();
        _evalTemas
          ..clear()
          ..addAll([
            for (final t in ((pl['evaluacion'] as Map?)?['temas'] as List? ?? const []))
              {'nombre': '${(t as Map)['nombre']}', 'minimo': (t['minimo'] as num?)?.toInt() ?? 5},
          ]);
        _conEvaluacion = _evalTemas.isNotEmpty;
        // Un curso anterior trae también precio, cupo, para quién y equipo.
        if (pl['precio'] is num) {
          _cobrar = (pl['precio'] as num) > 0;
          final pr = pl['precio'] as num;
          _precio.text = pr == 0 ? '' : '${pr % 1 == 0 ? pr.toInt() : pr}';
        }
        if (pl.containsKey('cupo')) {
          _conCupo = pl['cupo'] != null;
          if (pl['cupo'] is num) _cupo = (pl['cupo'] as num).toInt();
        }
        if (pl['para'] is Map) {
          _paraTipo = '${(pl['para'] as Map)['tipo'] ?? 'todos'}';
          _paraValores
            ..clear()
            ..addAll([for (final v in ((pl['para'] as Map)['valores'] as List? ?? const [])) '$v']);
        }
        if (pl['cambiaEquipo'] is bool) {
          _cambiaEquipo = pl['cambiaEquipo'] as bool;
          _equipo = widget.equipos.contains(pl['equipoDestino']) ? '${pl['equipoDestino']}' : null;
        }
        _abierto = false;
      }
    });
    Future.delayed(const Duration(milliseconds: 180), () => mounted ? _ir(1) : null);
  }

  /// Fechas para las clases de la plantilla: una por semana desde el día elegido.
  Future<void> _fechasPlantilla() async {
    final f = await _elegirFecha(null, Fechas.hoy().add(const Duration(days: 7)), tituloHora: 'Empieza');
    if (f == null || !mounted) return;
    final inicio = Curso.fecha(f)!;
    setState(() {
      _clases
        ..clear()
        ..addAll([
          for (final (i, c) in (_dePlantilla ?? const <Map<String, dynamic>>[]).indexed)
            {
              ...f,
              'fecha': Fechas.iso(inicio.add(Duration(days: 7 * i))),
              'tipo': c['tipo'] ?? 'clase',
              if ((c['temas'] as List? ?? const []).isNotEmpty) 'temas': c['temas'],
            },
        ]);
      _dePlantilla = null;
    });
  }

  /// Cursos ya armados, en el mismo formato que una plantilla (Victor,
  /// 2026-11-27: «si ya tenías otros cursos, desde acá los usas de nuevo»).
  /// Los que se repiten cada semana no tienen clases fijas: no entran.
  late final List<Map<String, dynamic>> _anteriores = [
    for (final c in widget.anteriores)
      if (!c.abierto && c.fechas.isNotEmpty)
        {
          'id': 'curso:${c.id}',
          'nombre': c.nombre,
          'tipo': c.tipo,
          'descripcion': c.descripcion,
          'clases': [
            for (var i = 0; i < c.fechas.length; i++)
              if (Curso.tipoFecha(c.fechas, i) != 'evaluacion') {'tipo': Curso.tipoFecha(c.fechas, i), 'temas': c.fechas[i]['temas'] ?? const []},
          ],
          'evaluacion': {'temas': c.temasEvaluacion},
          'precio': c.precio,
          'cupo': c.cupo,
          'para': c.para,
          'cambiaEquipo': c.cambiaEquipo,
          'equipoDestino': c.equipoDestino,
        },
  ];

  /// Pre-armados (Victor, 2026-11-18 y 27): no se crea nada nuevo aquí, son
  /// lienzos ya hechos. Cada tarjeta se despliega con su precio, cupo, clases,
  /// temas y evaluación; al usarla solo falta poner las fechas.
  Widget _pasoOrigen(BuildContext context) {
    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        t,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.pivot.textoSecundario),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OpcionAsistente(
          icono: Icons.edit_note_rounded,
          titulo: 'Personalizado',
          texto: 'Crea tus clases y los temas que quieras. Aparecerán en los eventos del calendario y podrás guardarlos como cursos pre-armados para usarlos cuando quieras.',
          activa: _dePlantilla == null && _nombre.text.isEmpty,
          alTocar: () => _usarPlantilla(null),
        ),
        if (widget.plantillas.isNotEmpty) titulo('PRE-ARMADOS'),
        for (final pl in widget.plantillas)
          _TarjetaPreArmado(key: ValueKey('pl${pl['id']}'), pl: pl, equipos: widget.equipos, alUsar: () => _usarPlantilla(pl)),
        if (_anteriores.isNotEmpty) titulo('TUS CURSOS ANTERIORES'),
        for (final pl in _anteriores) _TarjetaPreArmado(key: ValueKey('${pl['id']}'), pl: pl, equipos: widget.equipos, alUsar: () => _usarPlantilla(pl)),
      ],
    );
  }

  Widget _pasoTipo(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      OpcionAsistente(
        icono: Icons.school_outlined,
        titulo: 'Clases',
        texto: 'Ideal para personas nuevas con habilidades básicas a pulir. Podrás agregar clínicas en medio del curso y sumar una evaluación al final.',
        activa: _tipo == 'curso' && !_abierto,
        alTocar: () {
          setState(() {
            _tipo = 'curso';
            _abierto = false;
          });
          Future.delayed(const Duration(milliseconds: 180), () => mounted ? _ir(1) : null);
        },
      ),
      OpcionAsistente(
        icono: Icons.all_inclusive_rounded,
        titulo: 'Clases que se repiten',
        texto: 'Crea un curso con clases fijas que se repiten al llegar a la última clase. Útil para pulir habilidades avanzadas. Podrás evaluar cuando quieras y armar o editar tu currícula en el proceso.',
        activa: _tipo == 'curso' && _abierto,
        alTocar: () {
          setState(() {
            _tipo = 'curso';
            _abierto = true;
          });
          Future.delayed(const Duration(milliseconds: 180), () => mounted ? _ir(1) : null);
        },
      ),
      OpcionAsistente(
        icono: Icons.star_outline_rounded,
        titulo: 'Clínica o curso avanzado de un solo día',
        texto: 'Crea una sesión intensiva.',
        activa: _tipo == 'clinica',
        alTocar: () {
          setState(() {
            _tipo = 'clinica';
            _abierto = false;
            if (_clases.length > 1) _clases.removeRange(1, _clases.length);
          });
          Future.delayed(const Duration(milliseconds: 180), () => mounted ? _ir(1) : null);
        },
      ),
    ],
  );

  Widget _pasoNombre(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      TextField(
        controller: _nombre,
        autofocus: true,
        maxLength: 40,
        onChanged: (_) => setState(() {}),
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: 'Nombre', hintText: _clinica ? 'Ej. Clínica intensiva de defensa' : 'Ej. Curso de iniciación de verano'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _descripcion,
        maxLines: 4,
        minLines: 3,
        maxLength: 140,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Descripción', hintText: 'Qué se verá y para quién es'),
      ),
    ],
  );

  /// Clases desde un Excel o .csv: se ven antes de agregarlas.
  Future<void> _subirExcel() async {
    final m = ScaffoldMessenger.of(context);
    ClasesImportadas? r;
    try {
      r = await importarClases();
    } catch (_) {
      m.showSnackBar(const SnackBar(content: Text('No se pudo leer el archivo. Usa la plantilla (Excel o .csv).')));
      return;
    }
    if (r == null || !mounted) return;
    if (r.clases.isEmpty) {
      m.showSnackBar(const SnackBar(content: Text('No encontramos clases. Revisa que la primera fila diga Fecha, Hora, Lugar y Temas.')));
      return;
    }
    final l = r.clases, saltadas = r.saltadas;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.length == 1 ? '1 clase encontrada' : '${l.length} clases encontradas'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in l)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${c['tipo'] == 'clinica' ? 'Clínica' : 'Clase'} · ${c['fecha']} · ${c['hora']}'),
                  subtitle: Text([if ('${c['lugar']}'.isNotEmpty) '${c['lugar']}', ...((c['temas'] as List?) ?? const []).map((x) => '$x')].join(' · ')),
                ),
              if (saltadas > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(saltadas == 1 ? '1 fila sin fecha válida no se agregó.' : '$saltadas filas sin fecha válida no se agregaron.'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(d).pop(true), child: Text(l.length == 1 ? 'Agregar' : 'Agregar ${l.length}')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _clases
        ..addAll(l)
        ..sort((a, b) => '${a['fecha']}'.compareTo('${b['fecha']}'));
    });
  }

  /// Al tocar una opción, su card se abre con lo que hay que elegir (Victor, 2026-11-18).
  Widget _pasoPara(BuildContext context) {
    const opciones = [
      ('todos', Icons.groups_rounded, 'Toda la liga', 'Disponible para toda la liga.'),
      ('equipos', Icons.group_outlined, 'Ciertos equipos', 'Disponible para los equipos que decidas.'),
      ('nivel', Icons.stacked_bar_chart_rounded, 'Por nivel', 'Según sus habilidades en Progreso.'),
      ('personas', Icons.person_outline_rounded, 'Para pocas personas', 'Un curso individual o para unas pocas personas, sin importar su equipo.'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (k, i, t, d) in opciones)
          _OpcionExpandible(
            icono: i,
            titulo: t,
            texto: d,
            activa: _paraTipo == k,
            alTocar: () => setState(() {
              if (_paraTipo != k) _paraValores.clear();
              _paraTipo = k;
            }),
            child: switch (k) {
              'equipos' => _chipsPara([for (final e in widget.equipos) (e, e)]),
              'nivel' => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _chipsPara([for (final e in nivelesCoachElegibles.entries) (e.key, e.value)]),
                  _personasDelNivel(context),
                ],
              ),
              'personas' => _elegirPersonas(context),
              _ => null,
            },
          ),
      ],
    );
  }

  /// Quiénes están en los niveles elegidos (Victor, 2026-11-27), con su foto.
  Widget _personasDelNivel(BuildContext context) {
    final p = context.pivot;
    String clave(String v) => switch (v) {
      'basicas' => 'basica',
      'avanzadas' => 'avanzada',
      final x => x,
    };
    final elegidos = {for (final v in _paraValores) clave(v)};
    final gente = [
      for (final x in widget.personas)
        if (elegidos.contains(clave(widget.nivelPersonas[x.$1] ?? 'sin'))) x,
    ];
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: elegidos.isEmpty || widget.nivelPersonas.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    gente.isEmpty
                        ? 'NADIE ESTÁ EN ESTE NIVEL TODAVÍA'
                        : (gente.length == 1 ? '1 PERSONA EN ESTE NIVEL' : '${gente.length} PERSONAS EN ESTE NIVEL'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                  ),
                  for (final x in gente)
                    ListTile(
                      key: ValueKey('n${x.$1}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: AvatarPersona(nombre: x.$2, foto: x.$3, tamano: 32),
                      title: Text(x.$2),
                      subtitle: Text(nivelesCoach[widget.nivelPersonas[x.$1]] ?? ''),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _chipsPara(List<(String, String)> valores) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final (v, t) in valores)
        FilterChip(label: Text(t), selected: _paraValores.contains(v), onSelected: (s) => setState(() => s ? _paraValores.add(v) : _paraValores.remove(v))),
    ],
  );

  /// Buscador con avatares: las elegidas quedan arriba.
  Widget _elegirPersonas(BuildContext context) {
    final p = context.pivot;
    final q = _buscaPersona.text.trim().toLowerCase();
    final elegidas = [
      for (final x in widget.personas)
        if (_paraValores.contains(x.$1)) x,
    ];
    final resto = [
      for (final x in widget.personas)
        if (!_paraValores.contains(x.$1) && (q.isEmpty || '${x.$1} ${x.$2}'.toLowerCase().contains(q))) x,
    ];
    Widget fila((String, String, String) x) {
      final si = _paraValores.contains(x.$1);
      return ListTile(
        key: ValueKey(x.$1),
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: AvatarPersona(nombre: x.$2, foto: x.$3, tamano: 36),
        title: Text(x.$2),
        trailing: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(si ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, key: ValueKey(si), color: si ? p.marcaTexto : p.textoSecundario),
        ),
        onTap: () => setState(() => si ? _paraValores.remove(x.$1) : _paraValores.add(x.$1)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: elegidas.isEmpty
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ESTAS PERSONAS RECIBIRÁN EL CURSO',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
                    ),
                    for (final x in elegidas) fila(x),
                    const Divider(),
                  ],
                ),
        ),
        TextField(
          controller: _buscaPersona,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar persona'),
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final x in resto) fila(x),
              if (resto.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(widget.personas.isEmpty ? 'Cargando personas…' : 'Nadie con ese nombre.', style: TextStyle(color: p.textoSecundario)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Curso abierto: qué días, a qué hora, dónde y sus temas.
  Widget _pasoRepite(BuildContext context) {
    final p = context.pivot;
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Se repite los',
          style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in dias)
              FilterChip(label: Text(d), selected: _dias.contains(d), onSelected: (v) => setState(() => v ? _dias.add(d) : _dias.remove(d))),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final h = await elegirHoraTexto(context, inicial: _hora, titulo: 'Empieza');
                  if (h != null) setState(() => _hora = h);
                },
                child: Text('Empieza ${horaAmPm(_hora)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final h = await elegirHoraTexto(context, inicial: _termina ?? _sumarHoras(_hora, 2), titulo: 'Termina');
                  if (h != null) setState(() => _termina = h);
                },
                child: Text(_termina == null ? 'Termina' : 'Termina ${horaAmPm(_termina!)}'),
              ),
            ),
          ],
        ),
        if (widget.lugares.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Dónde',
            style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final l in widget.lugares) ChoiceChip(label: Text(l), selected: _lugar == l, onSelected: (_) => setState(() => _lugar = l))],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Temas del curso',
          style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in _temasCurso) InputChip(label: Text(t), onDeleted: () => setState(() => _temasCurso.remove(t))),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tema'),
              onPressed: () async {
                final t = await _elegirTema(ya: {for (final x in _temasCurso) x.toLowerCase()});
                if (t != null) setState(() => _temasCurso.add(t));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _pasoClases(BuildContext context) {
    if (_abierto) return _pasoRepite(context);
    final p = context.pivot;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Plantilla elegida: falta decir cuándo empieza.
        if (_dePlantilla != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_dePlantilla!.length} clases con sus temas. ¿Cuándo empieza?',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.sobreSuave),
                ),
                const SizedBox(height: 4),
                Text(
                  'Se crea una clase por semana, el mismo día y a la misma hora. Después puedes cambiar cualquiera.',
                  style: TextStyle(fontSize: 13, color: p.sobreSuave),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: _fechasPlantilla, icon: const Icon(Icons.event_rounded), label: const Text('Elegir el primer día')),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Excel para no cargar clase por clase (Victor, 2026-11-17).
        if (!_clinica) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(onPressed: _subirExcel, icon: const Icon(Icons.upload_file_rounded), label: const Text('Subir Excel')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(onPressed: compartirPlantilla, icon: const Icon(Icons.download_rounded), label: const Text('Plantilla')),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < _clases.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
              decoration: BoxDecoration(color: p.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_clases[i]['tipo'] == 'clinica' || _clinica ? Icons.star_outline_rounded : Icons.event_outlined, color: p.marcaTexto),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => _clase(i),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_clinica ? 'Clínica' : (_clases[i]['tipo'] == 'clinica' ? 'Clínica' : 'Clase ${_clases.take(i + 1).where((x) => x['tipo'] != 'clinica').length}')} · '
                                '${Curso.fecha(_clases[i]) == null ? '' : '${Fechas.dia(Curso.fecha(_clases[i])!)} ${Fechas.corta(Curso.fecha(_clases[i])!)}'}',
                                style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                              ),
                              Text(
                                [
                                  '${_clases[i]['hora']}${'${_clases[i]['termina'] ?? ''}'.isNotEmpty ? ' a ${_clases[i]['termina']}' : ''}',
                                  if ('${_clases[i]['lugar'] ?? ''}'.isNotEmpty) '${_clases[i]['lugar']}',
                                ].join(' · '),
                                style: TextStyle(fontSize: 13, color: p.textoSecundario),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _clases.removeAt(i))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in (_clases[i]['temas'] as List? ?? const []))
                        InputChip(
                          label: Text('$t'),
                          onDeleted: () => setState(() {
                            _clases[i] = {
                              ..._clases[i],
                              'temas': [
                                for (final x in (_clases[i]['temas'] as List))
                                  if (x != t) x,
                              ],
                            };
                          }),
                        ),
                      ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: const Text('Tema'), onPressed: () => _agregarTema(i)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (!_clinica || _clases.isEmpty)
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => _clase(null, _clinica ? 'clinica' : 'clase'),
                icon: const Icon(Icons.add_rounded),
                label: Text(_clinica ? 'Elegir día y hora' : (_clases.isEmpty ? 'Agregar la primera clase' : 'Agregar clase')),
              ),
              if (!_clinica && _clases.isNotEmpty)
                TextButton.icon(onPressed: () => _clase(null, 'clinica'), icon: const Icon(Icons.star_outline_rounded), label: const Text('Agregar clínica')),
            ],
          ),
      ],
    );
  }

  Widget _pasoEvaluacion(BuildContext context) {
    final p = context.pivot;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_clinica ? 'Evaluar al terminar' : 'Evaluación final'),
          subtitle: const Text('Una nota del 1 al 10 por cada tema, para cada persona.'),
          value: _conEvaluacion,
          onChanged: (v) => setState(() => _conEvaluacion = v),
        ),
        if (_conEvaluacion) ...[
          if (!_clinica && !_abierto) ...[
            const SizedBox(height: 4),
            Material(
              color: p.tarjeta,
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(Icons.emoji_events_outlined, color: p.marcaTexto),
                title: Text(
                  _evalFecha == null
                      ? 'Día de la evaluación (opcional)'
                      : '${Fechas.dia(Curso.fecha(_evalFecha!)!)} ${Fechas.corta(Curso.fecha(_evalFecha!)!)} · ${_evalFecha!['hora']}',
                ),
                subtitle: Text(_evalFecha == null ? 'Sin día, se evalúa en la última clase' : '${_evalFecha!['lugar'] ?? ''}'),
                trailing: _evalFecha == null
                    ? const Icon(Icons.add_rounded)
                    : IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _evalFecha = null)),
                onTap: () async {
                  final ultima = _clases.isEmpty ? null : Curso.fecha(_clases.last);
                  final f = await _elegirFecha(
                    _evalFecha,
                    ultima == null ? Fechas.hoy() : ultima.add(const Duration(days: 7)),
                    tituloHora: 'Hora de la evaluación',
                  );
                  if (f != null) setState(() => _evalFecha = f);
                },
              ),
            ),
            if (_evalAntes)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('La evaluación tiene que ser después de la última clase.', style: TextStyle(fontSize: 13, color: p.marcaTexto)),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'TEMAS A EVALUAR',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
          ),
          const SizedBox(height: 4),
          Text('Se arman con los temas de las clases. Aprueba quien llega al mínimo en cada uno.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
          const SizedBox(height: 8),
          for (var i = 0; i < _evalTemas.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${_evalTemas[i]['nombre']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Mínimo para aprobar la evaluación: ${_evalTemas[i]['minimo']} de 10'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Bajar mínimo',
                    onPressed: (_evalTemas[i]['minimo'] as int) <= 1
                        ? null
                        : () => setState(() => _evalTemas[i]['minimo'] = (_evalTemas[i]['minimo'] as int) - 1),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  IconButton(
                    tooltip: 'Subir mínimo',
                    onPressed: (_evalTemas[i]['minimo'] as int) >= 10
                        ? null
                        : () => setState(() => _evalTemas[i]['minimo'] = (_evalTemas[i]['minimo'] as int) + 1),
                    icon: const Icon(Icons.add_rounded),
                  ),
                  IconButton(
                    tooltip: 'Quitar de la evaluación',
                    onPressed: () => setState(() => _quitados.add('${_evalTemas.removeAt(i)['nombre']}'.toLowerCase())),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          if (_evalTemas.isEmpty) Text('Agrega temas a las clases o aquí.', style: TextStyle(color: p.textoSecundario)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final t = await _elegirTema(ya: {for (final x in _evalTemas) '${x['nombre']}'.toLowerCase()});
                if (t != null) {
                  setState(() {
                    _evalTemas.add({'nombre': t, 'minimo': 5});
                    _quitados.remove(t.toLowerCase());
                  });
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar tema'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pasoEquipo(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      OpcionAsistente(
        icono: Icons.do_not_disturb_on_outlined,
        titulo: 'No cambia de equipo',
        texto: 'Las habilidades quedan en su ficha deportiva. Su estado en el equipo no cambia ni cambiará de equipo.',
        activa: !_cambiaEquipo,
        alTocar: () => setState(() => _cambiaEquipo = false),
      ),
      OpcionAsistente(
        icono: Icons.arrow_upward_rounded,
        titulo: 'Pasa a un equipo',
        texto: 'Quien aprueba entra a ese equipo.',
        activa: _cambiaEquipo,
        alTocar: () => setState(() => _cambiaEquipo = true),
      ),
      if (_cambiaEquipo) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in widget.equipos) ChoiceChip(label: Text(e), selected: _equipo == e, onSelected: (v) => setState(() => _equipo = v ? e : null)),
          ],
        ),
      ],
    ],
  );

  /// Cobrar y cupo con interruptores (Victor, 2026-11-18): encendidos piden el dato.
  Widget _pasoPrecio(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Cobrar el curso'),
        subtitle: Text(_cobrar ? 'Se paga al inscribirse, con los medios de la liga.' : 'Gratis.'),
        value: _cobrar,
        onChanged: (v) => setState(() => _cobrar = v),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.topCenter,
        child: _cobrar
            ? Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _precio,
                  autofocus: _precio.text.isEmpty,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: InputDecoration(labelText: 'Precio del curso', prefixText: '${Moneda.s} '),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Cupo limitado'),
        subtitle: Text(_conCupo ? 'Se cierra al llenarse.' : 'Sin límite de personas.'),
        value: _conCupo,
        onChanged: (v) => setState(() => _conCupo = v),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.topCenter,
        child: _conCupo
            ? SelectorNumero(valor: _cupo, min: 1, max: 200, etiqueta: _cupo == 1 ? 'lugar' : 'lugares', alCambiar: (v) => setState(() => _cupo = v.toInt()))
            : const SizedBox(width: double.infinity),
      ),
    ],
  );

  Widget _pasoResumen(BuildContext context) {
    final p = context.pivot;
    Widget fila(String a, String b, _PasoCurso ir) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(a, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
      subtitle: Text(
        b,
        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: p.texto),
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () => setState(() {
        _adelante = false;
        _paso = ir;
      }),
    );
    final n = _clases.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        fila(_clinica ? 'Clínica' : 'Curso', _nombre.text.trim(), _PasoCurso.nombre),
        fila('Para quién', switch (_paraTipo) {
          'equipos' => _paraValores.join(', '),
          'nivel' => _paraValores.map((v) => nivelesCoach[v] ?? v).join(', '),
          'personas' => '${_paraValores.length} ${_paraValores.length == 1 ? 'persona' : 'personas'}',
          _ => 'Toda la liga',
        }, _PasoCurso.para),
        fila(
          _clinica ? 'Cuándo' : 'Clases',
          _abierto
              ? 'Cada ${_dias.join(', ').toLowerCase()} · ${horaAmPm(_hora)}'
              : (_clinica ? (n == 0 ? '' : '${_clases.first['fecha']} · ${_clases.first['hora']}') : '$n ${n == 1 ? 'clase' : 'clases'}'),
          _PasoCurso.clases,
        ),
        fila(
          'Evaluación',
          !_conEvaluacion
              ? 'Sin evaluación'
              : '${_evalTemas.length} ${_evalTemas.length == 1 ? 'tema' : 'temas'}${_evalFecha == null ? '' : ' · ${_evalFecha!['fecha']}'}',
          _PasoCurso.evaluacion,
        ),
        if (_pasos.contains(_PasoCurso.equipo)) fila('Al aprobar', _cambiaEquipo ? 'Pasa a ${_equipo ?? ''}' : 'No cambia de equipo', _PasoCurso.equipo),
        fila('Precio', (_monto ?? 0) == 0 ? 'Gratis' : '${Moneda.s}$_monto${_conCupo ? ' · cupo de $_cupo' : ''}', _PasoCurso.precio),
      ],
    );
  }

  Map<String, Object?> get _resultado => {
    'id': _nuevo ? null : o?.id,
    'tipo': _tipo,
    'nombre': _nombre.text.trim(),
    'descripcion': _descripcion.text.trim(),
    'precio': _monto,
    'cupo': _conCupo ? _cupo : null,
    'para': {'tipo': _paraTipo, 'valores': _paraValores.toList()},
    'abierto': _abierto,
    if (_abierto) 'repite': {'dias': _dias.toList(), 'hora': _hora, 'termina': _termina, 'lugar': _lugar},
    'temas': _abierto ? _temasCurso : const <String>[],
    'cambiaEquipo': _conEvaluacion && _cambiaEquipo,
    'equipoDestino': _conEvaluacion && _cambiaEquipo ? _equipo : null,
    'evaluacion': {'temas': _conEvaluacion ? _evalTemas : const []},
    'fechas': [
      for (final f in _clases)
        {
          'fecha': f['fecha'],
          'hora': f['hora'],
          'lugar': f['lugar'],
          'tipo': _clinica ? 'clinica' : (f['tipo'] ?? 'clase'),
          'termina': ?f['termina'],
          'titulo': ?f['titulo'],
          'temas': ?f['temas'],
        },
      if (_conEvaluacion && !_clinica && _evalFecha != null)
        {'fecha': _evalFecha!['fecha'], 'hora': _evalFecha!['hora'], 'lugar': _evalFecha!['lugar'], 'tipo': 'evaluacion'},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final l = _pasos;
    final i = l.indexOf(_paso);
    final ultimo = _paso == l.last;
    return Asistente(
      titulo: _nuevo ? (_clinica ? 'Nueva clínica' : 'Nuevo curso') : (_clinica ? 'Editar clínica' : 'Editar curso'),
      indice: i,
      total: l.length,
      tituloPaso: switch (_paso) {
        _PasoCurso.origen => 'Elige un tipo de curso',
        _PasoCurso.tipo => '¿Qué vas a armar?',
        _PasoCurso.nombre => 'Nombre y descripción',
        _PasoCurso.para => '¿A quién está dirigido?',
        _PasoCurso.clases => _clinica ? '¿Cuándo es?' : (_abierto ? '¿Cuándo se repite?' : 'Clases y temas'),
        _PasoCurso.evaluacion => 'Evaluación',
        _PasoCurso.equipo => 'Al aprobar',
        _PasoCurso.precio => 'Precio y cupo',
        _PasoCurso.resumen => 'Revisa y guarda',
      },
      ayuda: switch (_paso) {
        _PasoCurso.tipo => 'Podrás editar la currícula cuando quieras, cobrar o no el curso y abrirlo a un equipo, a toda la liga o a personas específicas. Al crearlo queda guardado en tus cursos pre-armados para reutilizarlo o editarlo.',
        _PasoCurso.clases =>
          _abierto
              ? 'Aparece en el calendario cada semana hasta que termines el curso. Los temas (2 a 4 palabras) arman la evaluación.'
              : 'Cada clase queda en el calendario. Agrega los temas de cada una (2 a 4 palabras): la evaluación se arma con ellos.',
        _PasoCurso.resumen => 'Toca un punto para cambiarlo.',
        _ => null,
      },
      clavePaso: _paso,
      adelante: _adelante,
      alAtras: () => _ir(-1),
      cuerpo: switch (_paso) {
        _PasoCurso.origen => _pasoOrigen(context),
        _PasoCurso.tipo => _pasoTipo(context),
        _PasoCurso.nombre => _pasoNombre(context),
        _PasoCurso.para => _pasoPara(context),
        _PasoCurso.clases => _pasoClases(context),
        _PasoCurso.evaluacion => _pasoEvaluacion(context),
        _PasoCurso.equipo => _pasoEquipo(context),
        _PasoCurso.precio => _pasoPrecio(context),
        _PasoCurso.resumen => _pasoResumen(context),
      },
      textoBoton: _paso == _PasoCurso.origen || (_paso == _PasoCurso.tipo && _nuevo) ? null : (ultimo ? 'Guardar' : 'Siguiente'),
      alContinuar: !_valido ? null : (ultimo ? () => Navigator.of(context).pop(_resultado) : () => _ir(1)),
    );
  }
}

/// Opción del asistente que, activa, se abre con sus opciones dentro.
class _OpcionExpandible extends StatelessWidget {
  const _OpcionExpandible({required this.icono, required this.titulo, required this.texto, required this.activa, required this.alTocar, this.child});
  final IconData icono;
  final String titulo, texto;
  final bool activa;
  final VoidCallback alTocar;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: activa ? p.suave : p.tarjeta,
          borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
          border: Border.all(color: activa ? p.marca : p.tarjeta, width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: alTocar,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(icono, size: 28, color: p.marcaTexto),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
                            ),
                            const SizedBox(height: 2),
                            Text(texto, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                          ],
                        ),
                      ),
                      Icon(activa ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: activa ? p.marcaTexto : p.textoSecundario),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: activa && child != null
                    ? Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), child: child)
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Temas: de la lista de habilidades de la liga, o uno nuevo corto.
class _HojaTemas extends StatefulWidget {
  const _HojaTemas({required this.habilidades, required this.ya, this.soloNivel});
  final List<Map<String, dynamic>> habilidades;
  final Set<String> ya;

  /// Curso para un nivel: solo las habilidades de ese nivel.
  final String? soloNivel;
  @override
  State<_HojaTemas> createState() => _HojaTemasState();
}

class _HojaTemasState extends State<_HojaTemas> {
  final _q = TextEditingController();

  /// Filtro por nivel de la liga: null todas.
  String? _nivel;

  static String _nivelDe(Map h) => '${h['nivel'] ?? NivelesCoach.primero}';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final q = _q.text.trim();
    final nivel = widget.soloNivel ?? _nivel;
    final l = widget.habilidades
        .where(
          (h) =>
              !widget.ya.contains('${h['nombre']}'.toLowerCase()) &&
              (nivel == null || _nivelDe(h) == nivel) &&
              (q.isEmpty || '${h['nombre']} ${h['categoria']}'.toLowerCase().contains(q.toLowerCase())),
        )
        .toList();
    Widget seccion(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        t,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
      ),
    );
    Widget fila(Map<String, dynamic> h) =>
        ListTile(dense: true, title: Text('${h['nombre']}'), subtitle: Text('${h['categoria']}'), onTap: () => Navigator.of(context).pop('${h['nombre']}'));
    final existe = widget.habilidades.any((h) => '${h['nombre']}'.toLowerCase() == q.toLowerCase());
    final palabras = q.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).length;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _q,
                  autofocus: true,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Busca o escribe un tema nuevo', counterText: ''),
                ),
              ),
              if (widget.soloNivel != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    'Curso para ${NivelesCoach.nombre(widget.soloNivel!)}: solo se muestran sus habilidades.',
                    style: TextStyle(fontSize: 13, color: p.textoSecundario),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final (v, t) in [(null, 'Todas'), for (final n in NivelesCoach.lista) (n.clave, n.nombre)])
                        ChoiceChip(label: Text(t), selected: _nivel == v, onSelected: (_) => setState(() => _nivel = v)),
                    ],
                  ),
                ),
              if (q.isNotEmpty && !existe)
                ListTile(
                  leading: Icon(Icons.add_circle_outline_rounded, color: p.marcaTexto),
                  title: Text('Crear "$q"'),
                  subtitle: Text(palabras > 5 ? 'Mejor más corto: 2 a 4 palabras.' : 'Queda en la lista de habilidades de la liga.'),
                  onTap: palabras > 5 ? null : () => Navigator.of(context).pop(q),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: ListView(
                    key: ValueKey(nivel),
                    children: [
                      if (nivel == null) ...[
                        for (final n in NivelesCoach.lista)
                          if (l.any((h) => _nivelDe(h) == n.clave)) ...[
                            seccion(n.nombre.toUpperCase()),
                            for (final h in l.where((h) => _nivelDe(h) == n.clave)) fila(h),
                          ],
                      ] else
                        for (final h in l) fila(h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un pre-armado o un curso anterior: se despliega con lo que trae
/// (precio, cupo, para quién, clases con sus temas y evaluación) y se usa
/// con «Usar este curso» (Victor, 2026-11-27).
class _TarjetaPreArmado extends StatefulWidget {
  const _TarjetaPreArmado({super.key, required this.pl, required this.equipos, required this.alUsar});
  final Map<String, dynamic> pl;
  final List<String> equipos;
  final VoidCallback alUsar;
  @override
  State<_TarjetaPreArmado> createState() => _TarjetaPreArmadoState();
}

class _TarjetaPreArmadoState extends State<_TarjetaPreArmado> {
  bool _abierta = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final pl = widget.pl;
    final clases = [for (final c in (pl['clases'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
    final eval = [for (final t in ((pl['evaluacion'] as Map?)?['temas'] as List? ?? const [])) Map<String, dynamic>.from(t as Map)];
    final precio = pl['precio'] as num?;
    final cupo = pl['cupo'] as num?;
    final para = pl['para'] as Map?;
    final clinica = pl['tipo'] == 'clinica';
    final datos = [
      clinica ? 'Clínica' : (clases.length == 1 ? '1 clase' : '${clases.length} clases'),
      if (eval.isNotEmpty) 'con evaluación',
      if (precio != null) precio == 0 ? 'Gratis' : '${Moneda.s}${precio % 1 == 0 ? precio.toInt() : precio}',
      if (cupo != null) 'cupo de $cupo',
    ];
    String textoPara() {
      final v = [for (final x in (para?['valores'] as List? ?? const [])) '$x'];
      return switch ('${para?['tipo']}') {
        'equipos' => v.isEmpty ? 'Ciertos equipos' : v.join(', '),
        'nivel' => v.isEmpty ? 'Por nivel' : v.map((x) => nivelesCoach[x] ?? x).join(', '),
        'personas' => v.length == 1 ? '1 persona' : '${v.length} personas',
        _ => 'Toda la liga',
      };
    }

    TextStyle chica([Color? c]) => TextStyle(fontSize: 13, height: 1.35, color: c ?? p.textoSecundario);
    Widget seccion(String t) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        t,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
      ),
    );
    final sistema = pl['sistema'] == true;
    final anterior = '${pl['id']}'.startsWith('curso:');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _abierta = !_abierta),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Row(
                  children: [
                    IconoRecuadro(
                      icono: sistema ? Icons.verified_outlined : (anterior ? Icons.history_rounded : Icons.bookmark_outline_rounded),
                      seccion: 'entrenamientos',
                      tamano: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pl['nombre']}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.texto),
                          ),
                          const SizedBox(height: 2),
                          Text(datos.join(' · '), style: chica()),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _abierta ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(Icons.expand_more_rounded, color: p.textoSecundario),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_abierta
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if ('${pl['descripcion'] ?? ''}'.isNotEmpty) Text('${pl['descripcion']}', style: chica(p.texto)),
                          if (para != null) ...[seccion('PARA'), Text(textoPara(), style: chica(p.texto))],
                          if (pl['cambiaEquipo'] == true && '${pl['equipoDestino'] ?? ''}'.isNotEmpty) ...[
                            seccion('AL APROBAR'),
                            Text('Pasa a ${pl['equipoDestino']}', style: chica(p.texto)),
                          ],
                          if (clases.isNotEmpty) ...[
                            seccion(clinica ? 'TEMAS' : 'CLASES Y TEMAS'),
                            for (final (i, c) in clases.indexed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${clinica ? '' : '${i + 1}. '}${(c['temas'] as List? ?? const []).isEmpty ? 'Sin temas todavía' : (c['temas'] as List).join(', ')}',
                                  style: chica(p.texto),
                                ),
                              ),
                          ],
                          if (eval.isNotEmpty) ...[
                            seccion('EVALUACIÓN'),
                            Text(
                              '${eval.length == 1 ? '1 tema' : '${eval.length} temas'}, mínimo para aprobar: ${{for (final t in eval) (t['minimo'] as num?)?.toInt() ?? 5}.join(' o ')} de 10.',
                              style: chica(p.texto),
                            ),
                          ],
                          const SizedBox(height: 14),
                          FilledButton.icon(onPressed: widget.alUsar, icon: const Icon(Icons.check_rounded), label: const Text('Usar este curso')),
                          const SizedBox(height: 4),
                          Text(
                            'Después eliges las fechas y puedes cambiar lo que quieras.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: p.textoSecundario),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
