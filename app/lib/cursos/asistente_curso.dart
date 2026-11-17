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
  });

  /// Gente de la liga, para cursos individuales: (username, nombre).
  final List<(String, String)> personas;
  final Curso? curso;
  final List<String> equipos, lugares;
  final List<Map<String, dynamic>> habilidades;

  /// Cursos prearmados (Freshmeat en roller derby y los que guarda la liga).
  final List<Map<String, dynamic>> plantillas;
  @override
  State<_AsistenteCurso> createState() => _AsistenteCursoState();
}

class _AsistenteCursoState extends State<_AsistenteCurso> {
  late final o = widget.curso;
  late _PasoCurso _paso = o == null && widget.plantillas.isNotEmpty ? _PasoCurso.origen : _PasoCurso.tipo;

  /// Clases de la plantilla elegida, sin fechas todavía.
  List<Map<String, dynamic>>? _dePlantilla;
  bool _adelante = true;

  late String _tipo = o?.tipo ?? 'curso';

  // Curso abierto: se repite cada semana hasta que se termina (Victor, 2026-11-17).
  late bool _abierto = o?.abierto ?? false;
  late final Set<String> _dias = {for (final d in (o?.repite?['dias'] as List? ?? const [])) '$d'};
  late String _hora = '${o?.repite?['hora'] ?? '19:00'}';
  late String? _termina = o?.repite?['termina'] as String?;
  late String _lugar = '${o?.repite?['lugar'] ?? (widget.lugares.isEmpty ? '' : widget.lugares.first)}';
  late final List<String> _temasCurso = [...?o?.temasCurso];

  // Para quién: toda la liga, equipos, un nivel o personas.
  late String _paraTipo = '${o?.para['tipo'] ?? 'todos'}';
  late final Set<String> _paraValores = {for (final v in (o?.para['valores'] as List? ?? const [])) '$v'};
  bool get _clinica => _tipo == 'clinica';
  late final _nombre = TextEditingController(text: o?.nombre ?? '');
  late final _descripcion = TextEditingController(text: o?.descripcion ?? '');
  late final _precio = TextEditingController(text: o == null ? '' : '${o!.precio % 1 == 0 ? o!.precio.toInt() : o!.precio}');
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
  late bool _conEvaluacion = o == null || _evalFecha != null || o!.temasEvaluacion.isNotEmpty;

  // Temas de la evaluación con su mínimo; los quitados a mano no vuelven solos.
  late final List<Map<String, dynamic>> _evalTemas = [for (final t in o?.temasEvaluacion ?? const <Map<String, dynamic>>[]) Map<String, dynamic>.from(t)];
  final Set<String> _quitados = {};

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _precio.dispose();
    super.dispose();
  }

  num? get _monto => _precio.text.trim().isEmpty ? 0 : num.tryParse(_precio.text.replaceAll(',', '.'));

  List<_PasoCurso> get _pasos => [
    if (o == null && widget.plantillas.isNotEmpty) _PasoCurso.origen,
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
    _PasoCurso.precio => _monto != null,
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
    final h = await elegirHoraTexto(context, inicial: '${base?['hora'] ?? '09:00'}', titulo: tituloHora);
    if (h == null || !mounted) return null;
    var lugar = '${base?['lugar'] ?? (widget.lugares.isEmpty ? '' : widget.lugares.first)}';
    if (widget.lugares.length > 1) {
      final l = await showModalBottomSheet<String>(
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
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _HojaTemas(habilidades: widget.habilidades, ya: ya),
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

  Widget _pasoOrigen(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      OpcionAsistente(
        icono: Icons.edit_note_rounded,
        titulo: 'Desde cero',
        texto: 'Armas las clases y los temas.',
        activa: _dePlantilla == null && _nombre.text.isEmpty,
        alTocar: () => _usarPlantilla(null),
      ),
      for (final pl in widget.plantillas)
        OpcionAsistente(
          icono: pl['sistema'] == true ? Icons.verified_outlined : Icons.bookmark_outline_rounded,
          titulo: '${pl['nombre']}',
          texto: [if ('${pl['descripcion'] ?? ''}'.isNotEmpty) '${pl['descripcion']}', '${(pl['clases'] as List? ?? const []).length} clases'].join(' · '),
          activa: _nombre.text == '${pl['nombre']}',
          alTocar: () => _usarPlantilla(pl),
        ),
    ],
  );

  Widget _pasoTipo(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      OpcionAsistente(
        icono: Icons.school_outlined,
        titulo: 'Curso',
        texto: 'Varias clases con inscripción. Puede tener clínicas en medio y una evaluación final.',
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
        titulo: 'Curso abierto',
        texto: 'Se repite cada semana hasta que lo terminas. Sirve para pulir habilidades: evalúas cuando quieras.',
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
        titulo: 'Clínica',
        texto: 'Una sola sesión intensiva, por ejemplo con jugadorxs invitadxs de otra liga.',
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
        onChanged: (_) => setState(() {}),
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: 'Nombre', hintText: _clinica ? 'Ej. Clínica intensiva de defensa' : 'Ej. Curso de iniciación de verano'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _descripcion,
        maxLines: 6,
        minLines: 3,
        maxLength: 1000,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Descripción', hintText: 'Qué se verá, quién la da, para quién es y qué se necesita'),
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

  Widget _pasoPara(BuildContext context) {
    const opciones = [
      ('todos', Icons.groups_rounded, 'Toda la liga', 'Aparece para todxs en Cursos.'),
      ('equipos', Icons.group_outlined, 'Ciertos equipos', 'Solo lo ven esos equipos.'),
      ('nivel', Icons.stacked_bar_chart_rounded, 'Un nivel', 'Según sus habilidades en Coach.'),
      (
        'personas',
        Icons.person_outline_rounded,
        'Personas específicas',
        'Un curso individual o para unas pocas personas, sin importar su equipo. Les llega la invitación.',
      ),
    ];
    final valores = switch (_paraTipo) {
      'equipos' => [for (final e in widget.equipos) (e, e)],
      'nivel' => [('sin', 'Aprendiendo lo básico'), ('basicas', 'Habilidades básicas'), ('avanzadas', 'Habilidades avanzadas')],
      'personas' => widget.personas,
      _ => const <(String, String)>[],
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (k, i, t, d) in opciones)
          OpcionAsistente(
            icono: i,
            titulo: t,
            texto: d,
            activa: _paraTipo == k,
            alTocar: () => setState(() {
              if (_paraTipo != k) _paraValores.clear();
              _paraTipo = k;
            }),
          ),
        if (valores.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (v, t) in valores)
                FilterChip(
                  label: Text(t),
                  selected: _paraValores.contains(v),
                  onSelected: (s) => setState(() => s ? _paraValores.add(v) : _paraValores.remove(v)),
                ),
            ],
          ),
        ],
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
              subtitle: Text('Mínimo ${_evalTemas[i]['minimo']} de 10'),
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
        texto: 'Las habilidades quedan en su ficha y su equipo sigue según los requisitos de la liga.',
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

  Widget _pasoPrecio(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      TextField(
        controller: _precio,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(labelText: 'Precio', prefixText: '${Moneda.s} ', helperText: 'Vacío o 0: gratis'),
      ),
      const SizedBox(height: 8),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Cupo limitado'), value: _conCupo, onChanged: (v) => setState(() => _conCupo = v)),
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
          'nivel' => _paraValores.map((v) => const {'sin': 'Aprendiendo lo básico', 'basicas': 'Básicas', 'avanzadas': 'Avanzadas'}[v] ?? v).join(', '),
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
    'id': o?.id,
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
      titulo: o == null ? (_clinica ? 'Nueva clínica' : 'Nuevo curso') : (_clinica ? 'Editar clínica' : 'Editar curso'),
      indice: i,
      total: l.length,
      tituloPaso: switch (_paso) {
        _PasoCurso.origen => '¿Cómo empiezas?',
        _PasoCurso.tipo => '¿Qué vas a armar?',
        _PasoCurso.nombre => '¿Cómo se llama?',
        _PasoCurso.para => '¿Para quién es?',
        _PasoCurso.clases => _clinica ? '¿Cuándo es?' : (_abierto ? '¿Cuándo se repite?' : 'Clases y temas'),
        _PasoCurso.evaluacion => 'Evaluación',
        _PasoCurso.equipo => 'Al aprobar',
        _PasoCurso.precio => 'Precio y cupo',
        _PasoCurso.resumen => 'Revisa y guarda',
      },
      ayuda: switch (_paso) {
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
      textoBoton: _paso == _PasoCurso.origen || (_paso == _PasoCurso.tipo && o == null) ? null : (ultimo ? 'Guardar' : 'Siguiente'),
      alContinuar: !_valido ? null : (ultimo ? () => Navigator.of(context).pop(_resultado) : () => _ir(1)),
    );
  }
}

/// Temas: de la lista de habilidades de la liga, o uno nuevo corto.
class _HojaTemas extends StatefulWidget {
  const _HojaTemas({required this.habilidades, required this.ya});
  final List<Map<String, dynamic>> habilidades;
  final Set<String> ya;
  @override
  State<_HojaTemas> createState() => _HojaTemasState();
}

class _HojaTemasState extends State<_HojaTemas> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final q = _q.text.trim();
    final l = widget.habilidades
        .where(
          (h) =>
              !widget.ya.contains('${h['nombre']}'.toLowerCase()) && (q.isEmpty || '${h['nombre']} ${h['categoria']}'.toLowerCase().contains(q.toLowerCase())),
        )
        .toList();
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
              if (q.isNotEmpty && !existe)
                ListTile(
                  leading: Icon(Icons.add_circle_outline_rounded, color: p.marcaTexto),
                  title: Text('Crear "$q"'),
                  subtitle: Text(palabras > 5 ? 'Mejor más corto: 2 a 4 palabras.' : 'Queda en la lista de habilidades de la liga.'),
                  onTap: palabras > 5 ? null : () => Navigator.of(context).pop(q),
                ),
              Expanded(
                child: ListView(
                  children: [
                    for (final h in l)
                      ListTile(
                        dense: true,
                        title: Text('${h['nombre']}'),
                        subtitle: Text('${h['categoria']}'),
                        onTap: () => Navigator.of(context).pop('${h['nombre']}'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
