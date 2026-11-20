import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/asistente.dart';
import '../../core/fechas.dart';
import '../../core/moneda.dart';
import '../../core/selector_hora.dart';
import '../../core/tema.dart';
import '../../sesion/sesion.dart';
import 'social_plantillas.dart';
import 'social_repo.dart';
import 'social_widgets.dart';

enum _P { plantilla, datos, invitados, piezas, config, homenaje, encargados, resumen }

class _Cat {
  _Cat({this.id, String nombre = '', String unidad = 'porciones', num porPersona = 1})
    : nombre = TextEditingController(text: nombre),
      unidad = TextEditingController(text: unidad),
      porPersona = TextEditingController(text: cantidadSocial(porPersona));
  final String? id;
  final TextEditingController nombre, unidad, porPersona;
  void dispose() {
    nombre.dispose();
    unidad.dispose();
    porPersona.dispose();
  }
}

class _Item {
  _Item({this.id, String texto = '', String cantidad = ''}) : texto = TextEditingController(text: texto), cantidad = TextEditingController(text: cantidad);
  final String? id;
  final TextEditingController texto, cantidad;
  void dispose() {
    texto.dispose();
    cantidad.dispose();
  }
}

class _Premio {
  _Premio({this.id, String premio = '', String para = ''}) : premio = TextEditingController(text: premio), para = TextEditingController(text: para);
  final String? id;
  final TextEditingController premio, para;
  void dispose() {
    premio.dispose();
    para.dispose();
  }
}

/// Asistente del "Social o fiesta" (Victor, 2026-11-20): cualquier persona de
/// la liga lo crea. Qué vas a armar → nombre, fecha, hora y lugar → a quién
/// invitas → piezas → configuración de cada pieza → homenaje y sorpresa →
/// encargadxs → resumen y "Enviar para aprobar". Con `actual` edita un evento
/// ya creado: abre en el resumen y cada fila lleva a su paso.
class CrearSocialScreen extends StatefulWidget {
  const CrearSocialScreen({super.key, required this.sesion, this.repo, this.actual});
  final Sesion sesion;
  final SocialRepo? repo;
  final EstadoSocial? actual;

  @override
  State<CrearSocialScreen> createState() => _CrearSocialScreenState();
}

class _CrearSocialScreenState extends State<CrearSocialScreen> {
  late final bool _editando = widget.actual != null && widget.repo != null;
  late _P _paso = _editando ? _P.resumen : _P.plantilla;
  bool _adelante = true, _guardando = false;

  EquipoSocial? _equipo;
  String? _errorEquipo;

  String? _plantilla, _festividad;
  final _festividadOtra = TextEditingController();

  /// Ícono de una festividad propia (Victor, 2026-11-20).
  String _icono = 'fiesta';

  /// Permisos de quien edita (Victor, 2026-11-20). null = todo: quien crea el
  /// evento, un Pivot o un evento nuevo. Áreas: fecha, amigo, comida, extras,
  /// invitados, homenaje. El servidor aplica lo mismo al guardar.
  List<String>? get _mis {
    final v = widget.actual?.editable?['misPermisos'];
    return v is List ? [for (final x in v) '$x'] : null;
  }

  bool get _todo => _mis == null;
  bool _puede(String area) => _mis == null || _mis!.contains(area);
  bool _puedePieza(Pieza pz) => _puede(switch (pz) {
    Pieza.comida || Pieza.traer => 'comida',
    Pieza.amigoSecreto || Pieza.regaloRobado => 'amigo',
    Pieza.invitados => 'invitados',
    Pieza.homenaje => 'homenaje',
    _ => 'extras',
  });

  /// Qué puede editar cada encargadx (solo lo cambia quien crea el evento).
  final Map<String, Set<String>> _permisos = {};
  final _nombre = TextEditingController(), _descripcion = TextEditingController(), _lugar = TextEditingController(), _mapa = TextEditingController();
  DateTime? _fecha;
  TimeOfDay? _inicia, _termina;

  String _para = 'liga';
  final Set<String> _equipos = {}, _personas = {};

  final Set<Pieza> _piezas = {};
  final List<_Cat> _cats = [];
  final _playlist = TextEditingController(), _playlistNota = TextEditingController();
  final _topeAmigo = TextEditingController(), _topeRobado = TextEditingController(), _recordatorio = TextEditingController(), _reglas = TextEditingController();
  DateTime? _cierre;

  /// Amigo secreto: parejas que no se pueden tocar entre sí (Victor, 2026-11-20).
  final List<(String, String)> _noTocar = [];
  final _dress = TextEditingController();
  final List<_Item> _traer = [];
  final List<_Premio> _premios = [];

  final Set<String> _homenajeados = {}, _noEnterarse = {}, _encargados = {};

  /// Sorpresa por pieza: las que NO ven homenajeadxs ni quienes no deben enterarse (por defecto, todas se ven).
  final Set<Pieza> _ocultas = {};
  static const _elegibles = [Pieza.comida, Pieza.playlist, Pieza.amigoSecreto, Pieza.regaloRobado, Pieza.dress, Pieza.traer, Pieza.invitados];
  bool _sorpresa = false, _mensajes = true, _regalo = false;
  final _neutro = TextEditingController(), _regaloTope = TextEditingController(), _regaloNota = TextEditingController();
  String? _regaloCompra;

  Sugerencias get _sug => sugerenciasDe(_plantilla ?? 'personalizado', _festividad);
  bool get _esPivot => widget.sesion.esAdmin && widget.sesion.adminToken != null;

  @override
  void initState() {
    super.initState();
    _cargarEquipo();
    if (_editando) _desdeActual(widget.actual!);
  }

  Future<void> _cargarEquipo() async {
    try {
      final e = await SocialRepo.equipo(widget.sesion.api, adminToken: widget.sesion.adminToken);
      if (mounted) setState(() => _equipo = e);
    } catch (e) {
      if (mounted) setState(() => _errorEquipo = e.toString());
    }
  }

  TimeOfDay? _horaDe(Object? v) {
    final p = '${v ?? ''}'.split(':');
    final h = int.tryParse(p.first), m = p.length > 1 ? int.tryParse(p[1]) : null;
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }

  void _desdeActual(EstadoSocial a) {
    final ed = a.editable ?? const {};
    final ev = a.evento;
    final piezas = Map<String, dynamic>.from((ed['piezas'] as Map?) ?? const {});
    _plantilla = '${ed['plantilla'] ?? 'personalizado'}';
    final fest = ed['festividad'] as String?;
    if (fest != null && !kFestividades.any((f) => f.nombre == fest)) {
      _festividad = 'Otra';
      _festividadOtra.text = fest;
      _icono = '${piezas['icono'] ?? 'fiesta'}';
    } else {
      _festividad = fest;
    }
    _nombre.text = '${ed['nombre'] ?? ''}';
    _neutro.text = '${ed['nombreNeutro'] ?? ''}';
    _descripcion.text = '${ed['descripcion'] ?? ''}';
    _lugar.text = '${ev['lugar'] ?? ''}';
    _mapa.text = '${ed['mapa'] ?? ''}';
    _fecha = DateTime.tryParse('${ev['fecha'] ?? ''}');
    _inicia = _horaDe(ev['inicia']);
    _termina = _horaDe(ev['termina']);
    final para = Map<String, dynamic>.from((ed['para'] as Map?) ?? const {});
    _para = '${para['tipo'] ?? 'liga'}';
    final valores = [for (final x in (para['valores'] as List? ?? const [])) '$x'];
    (_para == 'personas' ? _personas : _equipos).addAll(valores);
    if (a.modulo('comida')) _piezas.add(Pieza.comida);
    if (a.modulo('amigoSecreto')) _piezas.add(Pieza.amigoSecreto);
    if (a.modulo('regaloRobado')) _piezas.add(Pieza.regaloRobado);
    if (a.modulo('invitados')) _piezas.add(Pieza.invitados);
    for (final (k, pz) in [
      ('playlist', Pieza.playlist),
      ('dress', Pieza.dress),
      ('traer', Pieza.traer),
      ('premios', Pieza.premios),
      ('homenaje', Pieza.homenaje),
    ]) {
      if (piezas[k] != null) _piezas.add(pz);
    }
    for (final c in a.comida) {
      _cats.add(_Cat(id: c.id, nombre: c.nombre, unidad: c.unidad, porPersona: c.porPersona));
    }
    if (_cats.isEmpty) _cats.addAll(_catsSugeridas());
    final pl = (piezas['playlist'] as Map?) ?? const {};
    _playlist.text = '${pl['link'] ?? ''}';
    _playlistNota.text = '${pl['nota'] ?? ''}';
    if (a.topeAmigo != null) _topeAmigo.text = cantidadSocial(a.topeAmigo!);
    if (a.topeRobado != null) _topeRobado.text = cantidadSocial(a.topeRobado!);
    _recordatorio.text = a.recordatorioRobado;
    _reglas.text = a.reglasRobado;
    _cierre = a.cierre;
    for (final x in (piezas['noTocar'] as List? ?? const [])) {
      if (x is List && x.length == 2) _noTocar.add(('${x[0]}', '${x[1]}'));
    }
    _dress.text = '${((piezas['dress'] as Map?) ?? const {})['texto'] ?? ''}';
    for (final x in (((piezas['traer'] as Map?) ?? const {})['items'] as List? ?? const [])) {
      final m = x as Map;
      _traer.add(_Item(id: '${m['id']}', texto: '${m['texto'] ?? ''}', cantidad: m['cantidad'] == null ? '' : '${m['cantidad']}'));
    }
    for (final x in (((piezas['premios'] as Map?) ?? const {})['lista'] as List? ?? const [])) {
      final m = x as Map;
      _premios.add(_Premio(id: '${m['id']}', premio: '${m['premio'] ?? ''}', para: '${m['para'] ?? ''}'));
    }
    final h = (piezas['homenaje'] as Map?) ?? const {};
    _mensajes = h['mensajes'] != false;
    _regalo = h['regalo'] == true;
    _regaloNota.text = '${h['regaloNota'] ?? ''}';
    if (ed['regaloTope'] != null) _regaloTope.text = cantidadSocial(ed['regaloTope'] as num);
    _regaloCompra = ed['regaloCompra'] as String?;
    _sorpresa = ed['sorpresa'] == true;
    _homenajeados.addAll([for (final x in (ed['homenajeados'] as List? ?? const [])) '$x']);
    _noEnterarse.addAll([for (final x in (ed['noEnterarse'] as List? ?? const [])) '$x']);
    _encargados.addAll([for (final x in (ed['encargados'] as List? ?? const [])) '$x']);
    final perms = (ed['permisos'] as Map?) ?? const {};
    for (final u in _encargados) {
      final v = perms[u];
      _permisos[u] = v is List ? {for (final x in v) '$x'} : {..._permisosPorDefecto};
    }
    final ocultas = {for (final x in (piezas['ocultas'] as List? ?? const [])) '$x'};
    _ocultas.addAll(_elegibles.where((pz) => ocultas.contains(pz.name)));
  }

  List<_Cat> _catsSugeridas() => [for (final c in _sug.comida) _Cat(nombre: c.nombre, unidad: c.unidad, porPersona: c.porPersona)];

  /// Al elegir plantilla o festividad: preselecciona piezas y carga sus sugerencias.
  void _aplicarSugerencias() {
    final s = _sug;
    _piezas
      ..clear()
      ..addAll(s.piezas);
    for (final c in _cats) {
      c.dispose();
    }
    _cats
      ..clear()
      ..addAll(_catsSugeridas());
    if (_cats.isEmpty) _cats.add(_Cat(nombre: 'Bebidas', unidad: 'litros', porPersona: 0.5));
    for (final t in _traer) {
      t.dispose();
    }
    _traer
      ..clear()
      ..addAll([for (final t in s.traer) _Item(texto: t)]);
    for (final x in _premios) {
      x.dispose();
    }
    _premios
      ..clear()
      ..addAll([for (final t in s.premios) _Premio(premio: t)]);
    _dress.text = '';
    _playlistNota.text = s.playlist;
    final nombre = _plantilla == 'festividad' && _festividad == 'Otra' ? _festividadOtra.text.trim() : s.nombre;
    _nombre.text = nombre;
  }

  @override
  void dispose() {
    for (final c in [
      _festividadOtra, _nombre, _descripcion, _lugar, _mapa, _playlist, _playlistNota, _topeAmigo, _topeRobado, _recordatorio, _reglas, _dress, _neutro, //
      _regaloTope, _regaloNota,
    ]) {
      c.dispose();
    }
    for (final c in _cats) {
      c.dispose();
    }
    for (final t in _traer) {
      t.dispose();
    }
    for (final x in _premios) {
      x.dispose();
    }
    super.dispose();
  }

  // ─── Navegación ─────────────────────────────────────────────────────────

  static const _orden = _P.values;

  void _ir(_P p) {
    FocusScope.of(context).unfocus();
    setState(() {
      _adelante = _orden.indexOf(p) > _orden.indexOf(_paso);
      _paso = p;
    });
  }

  /// El paso Homenaje y sorpresa solo sale si elegiste la pieza Homenaje (Victor, 2026-11-20).
  bool _saltar(_P p) => p == _P.homenaje && !_piezas.contains(Pieza.homenaje) && _homenajeados.isEmpty && !_sorpresa;

  void _siguiente() {
    if (_editando) return _ir(_P.resumen);
    var i = _orden.indexOf(_paso) + 1;
    while (i < _orden.length - 1 && _saltar(_orden[i])) {
      i++;
    }
    if (i < _orden.length) _ir(_orden[i]);
  }

  void _atras() {
    if (_editando) {
      if (_paso == _P.resumen) {
        Navigator.of(context).maybePop();
      } else {
        _ir(_P.resumen);
      }
      return;
    }
    var i = _orden.indexOf(_paso) - 1;
    while (i > 0 && _saltar(_orden[i])) {
      i--;
    }
    if (i >= 0) _ir(_orden[i]);
  }

  String? get _falta => switch (_paso) {
    _P.plantilla =>
      _plantilla == null
          ? 'Elige qué vas a armar.'
          : _plantilla == 'festividad' && (_festividad == null || (_festividad == 'Otra' && _festividadOtra.text.trim().isEmpty))
          ? 'Elige la festividad.'
          : null,
    _P.datos =>
      _nombre.text.trim().isEmpty
          ? 'Ponle un nombre.'
          : _fecha == null
          ? 'Elige la fecha.'
          : _inicia == null
          ? 'Elige la hora.'
          : _lugar.text.trim().isEmpty
          ? 'Escribe dónde será.'
          : null,
    _P.invitados =>
      _para == 'equipo' && (_equipo?.miEquipo ?? '').isEmpty
          ? 'No tienes equipo asignado: elige otra opción.'
          : _para == 'equipos' && _equipos.isEmpty
          ? 'Elige al menos un equipo.'
          : _para == 'personas' && _personas.isEmpty
          ? 'Elige al menos una persona.'
          : null,
    _P.homenaje =>
      _piezas.contains(Pieza.homenaje) && _homenajeados.isEmpty
          ? 'Elige a quién homenajean (o apaga Homenaje en "Qué tendrá").'
          : _sorpresa && _homenajeados.isEmpty && _noEnterarse.isEmpty
          ? 'Elige quiénes no deben enterarse.'
          : _sorpresa && _neutro.text.trim().isEmpty
          ? 'Escribe el nombre neutro.'
          : _sorpresa && widget.sesion.nombre != null && {..._homenajeados, ..._noEnterarse}.contains(widget.sesion.nombre)
          ? 'Si es sorpresa, tú no puedes estar en estas listas.'
          : null,
    _ => null,
  };

  static const _titulos = {
    _P.plantilla: '¿Qué vas a armar?',
    _P.datos: 'Nombre, fecha y lugar',
    _P.invitados: '¿A quién invitas?',
    _P.piezas: '¿Qué tendrá tu fiesta?',
    _P.config: 'Configura lo que tendrá',
    _P.homenaje: 'Homenaje y sorpresa',
    _P.encargados: 'Encargadxs',
    _P.resumen: 'Resumen',
  };

  String? get _ayuda => switch (_paso) {
    _P.plantilla => 'La plantilla solo propone qué tendrá y algunas sugerencias. Todo se puede cambiar.',
    _P.invitados => 'Solo quienes invites lo ven en su calendario y reciben los avisos.',
    _P.piezas => 'Elige lo que tendrá. Puedes cambiarlo después.',
    _P.homenaje => 'Opcional. Las personas homenajeadas y quienes no deben enterarse lo ven como un evento normal.',
    _P.encargados => 'Opcional. Pueden editar el evento contigo.',
    _P.resumen =>
      _editando
          ? 'Toca una fila para cambiarla.'
          : (_esPivot ? 'Como eres Pivot, se publica al crearlo.' : 'Un Pivot lo revisa antes de que aparezca en el calendario.'),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final idx = _orden.indexOf(_paso);
    final falta = _falta;
    final ultimo = _paso == _P.resumen;
    final rechazado = widget.actual?.estadoAprobacion == 'rechazado';
    return Asistente(
      titulo: _editando ? 'Editar Social o fiesta' : 'Nuevo Social o fiesta',
      indice: _editando ? (ultimo ? 0 : 1) : idx,
      total: _editando ? 2 : _orden.length,
      tituloPaso: _titulos[_paso]!,
      ayuda: falta != null && _paso != _P.plantilla ? falta : _ayuda,
      clavePaso: _paso,
      adelante: _adelante,
      alAtras: _atras,
      cuerpo: _cuerpo(context),
      textoBoton: _paso == _P.plantilla && _plantilla != 'festividad' && !_editando
          ? null
          : ultimo
          ? (_editando ? (rechazado ? 'Guardar y enviar de nuevo' : 'Guardar cambios') : (_esPivot ? 'Crear y publicar' : 'Enviar para aprobar'))
          : (_editando ? 'Listo' : 'Siguiente'),
      alContinuar: falta != null ? null : (ultimo ? _enviar : _siguiente),
      ocupado: _guardando,
    );
  }

  Widget _cuerpo(BuildContext context) => switch (_paso) {
    _P.plantilla => _pasoPlantilla(context),
    _P.datos => _pasoDatos(context),
    _P.invitados => _pasoInvitados(context),
    _P.piezas => _pasoPiezas(context),
    _P.config => _pasoConfig(context),
    _P.homenaje => _pasoHomenaje(context),
    _P.encargados => _pasoEncargados(context),
    _P.resumen => _pasoResumen(context),
  };

  Widget _desplegable(bool visible, Widget child) => AnimatedSize(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: visible ? 1 : 0,
      child: visible ? child : const SizedBox(width: double.infinity),
    ),
  );

  Widget _titulo(String t, {String? ayuda}) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
          ),
          if (ayuda != null) ...[const SizedBox(height: 2), Text(ayuda, style: TextStyle(fontSize: 13, color: p.textoSecundario))],
        ],
      ),
    );
  }

  // ─── Paso 1: plantilla ──────────────────────────────────────────────────

  Widget _pasoPlantilla(BuildContext context) {
    final p = context.pivot;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final pl in kPlantillas) ...[
          OpcionAsistente(
            icono: pl.icono,
            titulo: pl.titulo,
            texto: pl.texto,
            activa: _plantilla == pl.id,
            alTocar: () {
              setState(() {
                final cambio = _plantilla != pl.id;
                _plantilla = pl.id;
                if (pl.id != 'festividad') _festividad = null;
                if (cambio && !_editando && pl.id != 'festividad') _aplicarSugerencias();
              });
              if (pl.id != 'festividad' && !_editando) {
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (mounted && _paso == _P.plantilla) _siguiente();
                });
              }
            },
          ),
          if (pl.id == 'festividad')
            _desplegable(
              _plantilla == 'festividad',
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in [...kFestividades.map((f) => (f.nombre, f.icono)), ('Otra', Icons.edit_outlined)])
                          ChoiceChip(
                            avatar: Icon(f.$2, size: 18, color: p.marcaTexto),
                            label: Text(f.$1),
                            selected: _festividad == f.$1,
                            onSelected: (_) => setState(() {
                              _festividad = f.$1;
                              if (!_editando) _aplicarSugerencias();
                            }),
                          ),
                      ],
                    ),
                    _desplegable(
                      _festividad == 'Otra',
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextField(
                          controller: _festividadOtra,
                          maxLength: 40,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(labelText: '¿Cuál?', hintText: 'Ej.: Carnaval'),
                          onChanged: (_) => setState(() {
                            if (!_editando) _nombre.text = _festividadOtra.text.trim();
                          }),
                        ),
                      ),
                    ),
                    // Ícono de la festividad propia: se ve en el calendario.
                    _desplegable(
                      _festividad == 'Otra',
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ícono en el calendario',
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final e in kIconosSocial.entries)
                                  ChoiceChip(
                                    showCheckmark: false,
                                    label: Icon(e.value, size: 22, color: _icono == e.key ? p.marcaTexto : p.textoSecundario),
                                    selected: _icono == e.key,
                                    onSelected: (_) => setState(() => _icono = e.key),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  // ─── Paso 2: datos ──────────────────────────────────────────────────────

  Future<void> _elegirFecha() async {
    final hoy = Fechas.hoy();
    final f = await showDatePicker(
      context: context,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
      initialDate: _fecha != null && !_fecha!.isBefore(hoy) ? _fecha! : hoy.add(const Duration(days: 7)),
    );
    if (f != null) setState(() => _fecha = f);
  }

  Future<void> _elegirHora(bool inicio) async {
    final h = await elegirHora(
      context,
      inicial: (inicio ? _inicia : _termina) ?? const TimeOfDay(hour: 19, minute: 0),
      titulo: inicio ? '¿A qué hora empieza?' : '¿A qué hora termina?',
    );
    if (h != null) setState(() => inicio ? _inicia = h : _termina = h);
  }

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _pasoDatos(BuildContext context) {
    final p = context.pivot;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_todo)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _puede('fecha')
                  ? 'El nombre y la descripción los cambia quien creó el evento.'
                  : 'La fecha, la hora y el lugar los cambia quien creó el evento o quien esté a cargo de eso.',
              style: TextStyle(fontSize: 13, color: p.textoSecundario),
            ),
          ),
        TextField(
          controller: _nombre,
          enabled: _todo,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej.: Fiesta de fin de año'),
          onChanged: (_) => setState(() {}),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.event_outlined, color: p.marcaTexto),
          title: Text(_fecha == null ? 'Elige la fecha' : '${Fechas.dia(_fecha!)} ${Fechas.corta(_fecha!)}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _puede('fecha') ? _elegirFecha : null,
        ),
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.schedule_rounded, color: p.marcaTexto),
                title: Text(_inicia == null ? 'Empieza' : _hhmm(_inicia!)),
                onTap: _puede('fecha') ? () => _elegirHora(true) : null,
              ),
            ),
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_termina == null ? 'Termina (opcional)' : _hhmm(_termina!)),
                trailing: _termina == null
                    ? null
                    : IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => _termina = null)),
                onTap: _puede('fecha') ? () => _elegirHora(false) : null,
              ),
            ),
          ],
        ),
        TextField(
          controller: _lugar,
          enabled: _puede('fecha'),
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Lugar', hintText: 'Ej.: Casa de Ana'),
          onChanged: (_) => setState(() {}),
        ),
        TextField(
          controller: _mapa,
          enabled: _puede('fecha'),
          maxLength: 500,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Enlace del mapa (opcional)', hintText: 'Google Maps u otra app'),
        ),
        TextField(
          controller: _descripcion,
          enabled: _todo,
          maxLength: 1000,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
        ),
      ],
    );
  }

  // ─── Paso 3: invitadxs ──────────────────────────────────────────────────

  Widget _cargandoEquipo() {
    final p = context.pivot;
    if (_errorEquipo != null) {
      return Column(
        children: [
          Text(_errorEquipo!, style: TextStyle(color: p.textoSecundario)),
          TextButton(
            onPressed: () {
              setState(() => _errorEquipo = null);
              _cargarEquipo();
            },
            child: const Text('Reintentar'),
          ),
        ],
      );
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _pasoInvitados(BuildContext context) {
    final eq = _equipo;
    final opciones = [
      ('equipo', Icons.groups_2_outlined, 'Mi equipo', (eq?.miEquipo ?? '').isEmpty ? 'No tienes equipo asignado' : eq!.miEquipo!),
      ('equipos', Icons.diversity_3_outlined, 'Varios equipos', 'Eliges cuáles'),
      ('liga', Icons.public_rounded, 'Toda la liga', 'Todas las personas de la liga'),
      ('personas', Icons.person_search_outlined, 'Personas sueltas', 'Eliges una por una'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final o in opciones)
          OpcionAsistente(
            icono: o.$2,
            titulo: o.$3,
            texto: o.$4,
            activa: _para == o.$1,
            habilitada: o.$1 != 'equipo' || (eq?.miEquipo ?? '').isNotEmpty,
            alTocar: () => setState(() => _para = o.$1),
          ),
        _desplegable(
          _para == 'equipos',
          eq == null
              ? _cargandoEquipo()
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in eq.equipos)
                      FilterChip(label: Text(e), selected: _equipos.contains(e), onSelected: (v) => setState(() => v ? _equipos.add(e) : _equipos.remove(e))),
                  ],
                ),
        ),
        _desplegable(
          _para == 'personas',
          _filaPersonas('Invitadxs', _personas, () async {
            final r = await _elegirPersonas('¿A quién invitas?', _personas);
            if (r != null) {
              setState(
                () => _personas
                  ..clear()
                  ..addAll(r),
              );
            }
          }),
        ),
      ],
    );
  }

  /// Fila con chips de las personas elegidas y un botón para cambiarlas.
  Widget _filaPersonas(String titulo, Set<String> sel, VoidCallback alElegir, {String? vacio}) {
    final p = context.pivot;
    final eq = _equipo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sel.isEmpty && vacio != null) Text(vacio, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final u in sel)
              InputChip(
                label: Text(eq?.nombreDe(u) ?? widget.actual?.editable?['nombres']?[u]?.toString() ?? u),
                onDeleted: () => setState(() => sel.remove(u)),
              ),
          ],
        ),
        TextButton.icon(onPressed: alElegir, icon: const Icon(Icons.person_add_alt_rounded), label: Text(sel.isEmpty ? 'Elegir' : 'Cambiar')),
      ],
    );
  }

  Future<Set<String>?> _elegirPersonas(String titulo, Set<String> actual, {Set<String> excluir = const {}}) async {
    if (_equipo == null) {
      avisarSocial(context, _errorEquipo ?? 'Cargando a las personas de la liga…');
      return null;
    }
    final personas = _equipo!.personas.where((x) => !excluir.contains(x.username)).toList();
    final sel = {...actual};
    var busqueda = '';
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (h) => StatefulBuilder(
        builder: (h, set) {
          final p = h.pivot;
          final q = busqueda.trim().toLowerCase();
          final lista = q.isEmpty ? personas : personas.where((x) => x.nombre.toLowerCase().contains(q) || x.equipo.toLowerCase().contains(q)).toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(h).size.height * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.texto),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar por nombre o equipo'),
                          onChanged: (v) => set(() => busqueda = v),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: lista.length,
                      itemBuilder: (_, i) {
                        final x = lista[i];
                        return CheckboxListTile(
                          value: sel.contains(x.username),
                          title: Text(x.nombre),
                          subtitle: x.equipo.isEmpty ? null : Text(x.equipo),
                          onChanged: (v) => set(() => v == true ? sel.add(x.username) : sel.remove(x.username)),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      onPressed: () => Navigator.pop(h, sel),
                      child: Text(sel.isEmpty ? 'Listo' : 'Listo (${sel.length})'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Paso 4: piezas ─────────────────────────────────────────────────────

  Widget _pasoPiezas(BuildContext context) {
    final p = context.pivot;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        for (final pz in Pieza.values)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(pz.icono, color: _piezas.contains(pz) ? p.marcaTexto : p.textoSecundario),
            title: Text(pz.titulo),
            subtitle: Text(pz.texto),
            value: _piezas.contains(pz),
            // Sin permiso para esa parte: se ve, pero no se cambia.
            onChanged: !_puedePieza(pz)
                ? null
                : (v) => setState(() {
                    v ? _piezas.add(pz) : _piezas.remove(pz);
                    if (v && pz == Pieza.comida && _cats.isEmpty) {
                      _cats.addAll(_catsSugeridas().isEmpty ? [_Cat(nombre: 'Bebidas', unidad: 'litros', porPersona: 0.5)] : _catsSugeridas());
                    }
                  }),
          ),
      ],
    );
  }

  // ─── Paso 5: configuración ──────────────────────────────────────────────

  // Cierre libre hasta 1 día antes; por defecto, 2 semanas antes (Victor, 2026-11-20).
  DateTime? get _limiteCierre => _fecha?.subtract(const Duration(days: 1));

  DateTime? get _cierrePorDefecto {
    final f = _fecha;
    if (f == null) return null;
    final d = f.subtract(const Duration(days: 14));
    return d.isBefore(Fechas.hoy()) ? _limiteCierre : d;
  }

  DateTime? get _cierreElegido {
    final limite = _limiteCierre;
    return _cierre == null || (limite != null && _cierre!.isAfter(limite)) ? _cierrePorDefecto : _cierre;
  }

  bool get _cierreJusto {
    final c = _cierreElegido, f = _fecha;
    return c != null && f != null && f.difference(c).inDays < 14;
  }

  Future<void> _elegirCierre() async {
    final limite = _limiteCierre;
    if (limite == null) return;
    final hoy = Fechas.hoy();
    if (limite.isBefore(hoy)) {
      avisarSocial(context, 'El evento es mañana o antes: cierra la inscripción y sortea cuando quieras desde el evento.');
      return;
    }
    final elegido = _cierreElegido;
    final actual = elegido == null || elegido.isBefore(hoy) ? limite : elegido;
    final f = await showDatePicker(context: context, firstDate: hoy, lastDate: limite, initialDate: actual);
    if (f != null) setState(() => _cierre = f);
  }

  Future<void> _agregarNoTocar() async {
    final r = await _elegirPersonas('Elige 2 personas que no se pueden tocar', const {});
    if (r == null || !mounted) return;
    if (r.length != 2) {
      avisarSocial(context, 'Elige exactamente 2 personas.');
      return;
    }
    final l = r.toList()..sort();
    if (_noTocar.any((x) => x.$1 == l[0] && x.$2 == l[1])) return;
    setState(() => _noTocar.add((l[0], l[1])));
  }

  Widget _numero(TextEditingController c, String etiqueta) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: etiqueta, prefixText: Moneda.s),
  );

  Widget _quitar(VoidCallback f) => IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close_rounded), onPressed: f);

  Widget _pasoConfig(BuildContext context) {
    final p = context.pivot;
    final s = _sug;
    final secciones = <Widget>[];
    if (_piezas.contains(Pieza.comida) && _puedePieza(Pieza.comida)) {
      secciones.addAll([
        _titulo('Comida y bebida', ayuda: 'Cantidad por asistente: la meta es asistentes (con sus +1) × cantidad.'),
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
                    decoration: const InputDecoration(labelText: 'Categoría'),
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
                _quitar(() {
                  setState(() => _cats.remove(c));
                  WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
                }),
              ],
            ),
          ),
        Wrap(
          spacing: 6,
          children: [
            for (final sc in s.comida.where((x) => !_cats.any((c) => c.nombre.text.trim().toLowerCase() == x.nombre.toLowerCase())))
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 16),
                label: Text(sc.nombre),
                onPressed: () => setState(() => _cats.add(_Cat(nombre: sc.nombre, unidad: sc.unidad, porPersona: sc.porPersona))),
              ),
            ActionChip(avatar: const Icon(Icons.add_rounded, size: 16), label: const Text('Otra'), onPressed: () => setState(() => _cats.add(_Cat()))),
          ],
        ),
      ]);
    }
    if (_piezas.contains(Pieza.playlist) && _puedePieza(Pieza.playlist)) {
      secciones.addAll([
        _titulo('Playlist colaborativa', ayuda: 'Pega el enlace de una lista colaborativa de Spotify u otra app.'),
        TextField(
          controller: _playlist,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Enlace de la playlist', hintText: 'https://open.spotify.com/…'),
        ),
        TextField(
          controller: _playlistNota,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Nota (opcional)', hintText: 'Ej.: Suma 3 canciones'),
        ),
      ]);
    }
    if (_piezas.contains(Pieza.amigoSecreto) && _puedePieza(Pieza.amigoSecreto)) {
      final cierre = _cierreElegido;
      secciones.addAll([
        _titulo('Amigo secreto'),
        _numero(_topeAmigo, 'Tope del regalo (opcional)'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_busy_outlined),
          title: const Text('Cierre de la inscripción'),
          subtitle: Text(
            '${cierre == null ? 'Elige primero la fecha' : Fechas.corta(cierre)} · hasta 1 día antes del evento. Quien se suma después no entra al amigo secreto.'
            '${_cierreJusto ? '\nCon menos de 2 semanas, la gente tiene poco tiempo para comprar el regalo.' : ''}',
          ),
          onTap: _elegirCierre,
        ),
        // Reglas: personas que no se pueden tocar (por ejemplo, una pareja). Solo lo ve quien organiza.
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'No se pueden tocar',
            style: TextStyle(fontWeight: FontWeight.w700, color: context.pivot.texto),
          ),
        ),
        Text(
          'Por ejemplo, una pareja o personas que viven juntas: no se regalan entre sí en ningún sentido. Solo lo ves tú y quienes organizan.',
          style: TextStyle(fontSize: 13, color: context.pivot.textoSecundario),
        ),
        for (final (i, (a, b)) in _noTocar.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.block_rounded),
            title: Text('${_nombres({a})} y ${_nombres({b})}'),
            trailing: _quitar(() => setState(() => _noTocar.removeAt(i))),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: _agregarNoTocar, icon: const Icon(Icons.add_rounded), label: const Text('Agregar personas que no se pueden tocar')),
        ),
      ]);
    }
    if (_piezas.contains(Pieza.regaloRobado) && _puedePieza(Pieza.regaloRobado)) {
      secciones.addAll([
        _titulo('Regalo robado'),
        _numero(_topeRobado, 'Tope del regalo (opcional)'),
        TextField(
          controller: _recordatorio,
          maxLength: 300,
          maxLines: null,
          decoration: const InputDecoration(labelText: 'Recordatorio (opcional)', hintText: 'Ej.: Envuelto y sin nombre'),
        ),
        TextField(
          controller: _reglas,
          maxLines: null,
          minLines: 3,
          maxLength: 3000,
          decoration: const InputDecoration(labelText: 'Reglas', hintText: 'Vacío = reglas de siempre (se ven en el evento)', alignLabelWithHint: true),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _reglas.text = kReglasRegaloRobado),
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Usar la plantilla de reglas para editarla'),
          ),
        ),
      ]);
    }
    if (_piezas.contains(Pieza.dress) && _puedePieza(Pieza.dress)) {
      final ideas = {...s.dress, ...kFestividades.expand((f) => f.sugerencias.dress)}.take(8);
      secciones.addAll([
        _titulo('Dress code o disfraces'),
        TextField(
          controller: _dress,
          maxLength: 400,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: '¿Cómo venir?', hintText: 'Ej.: Disfraz libre'),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in ideas)
              ActionChip(label: Text(t), onPressed: () => setState(() => _dress.text = _dress.text.trim().isEmpty ? t : '${_dress.text.trim()}. $t')),
          ],
        ),
      ]);
    }
    if (_piezas.contains(Pieza.traer) && _puedePieza(Pieza.traer)) {
      secciones.addAll([
        _titulo('Qué traer', ayuda: 'Cada quien se anota con lo que lleva. Cantidad vacía = sin límite.'),
        for (final t in _traer)
          Padding(
            key: ObjectKey(t),
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 7,
                  child: TextField(
                    controller: t.texto,
                    decoration: const InputDecoration(labelText: 'Qué'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: t.cantidad,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cuántxs'),
                  ),
                ),
                _quitar(() {
                  setState(() => _traer.remove(t));
                  WidgetsBinding.instance.addPostFrameCallback((_) => t.dispose());
                }),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _traer.add(_Item())), icon: const Icon(Icons.add_rounded), label: const Text('Agregar')),
        ),
      ]);
    }
    if (_piezas.contains(Pieza.premios) && _puedePieza(Pieza.premios)) {
      secciones.addAll([
        _titulo('Premios o reconocimientos', ayuda: '"Para" es opcional: puedes decidirlo después.'),
        for (final x in _premios)
          Padding(
            key: ObjectKey(x),
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: x.premio,
                    decoration: const InputDecoration(labelText: 'Premio'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: x.para,
                    decoration: const InputDecoration(labelText: 'Para'),
                  ),
                ),
                _quitar(() {
                  setState(() => _premios.remove(x));
                  WidgetsBinding.instance.addPostFrameCallback((_) => x.dispose());
                }),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _premios.add(_Premio())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar premio'),
          ),
        ),
      ]);
    }
    if (_piezas.contains(Pieza.invitados) && _puedePieza(Pieza.invitados)) {
      secciones.addAll([
        _titulo('+1 con enlace'),
        Text(
          'Cada persona que marque Asistiré puede sumar hasta 5 invitadxs. Cada +1 recibe su enlace para entrar sin cuenta.',
          style: TextStyle(color: p.textoSecundario),
        ),
      ]);
    }
    if (secciones.isEmpty) {
      secciones.add(
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            _piezas.contains(Pieza.homenaje) ? 'El homenaje se configura en el paso siguiente.' : 'Lo que elegiste no necesita configuración.',
            style: TextStyle(color: p.textoSecundario),
          ),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: secciones);
  }

  // ─── Paso 6: homenaje y sorpresa ────────────────────────────────────────

  Widget _pasoHomenaje(BuildContext context) {
    final p = context.pivot;
    final yo = widget.sesion.nombre;
    final eq = _equipo;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _titulo('Personas homenajeadas', ayuda: 'Por ejemplo, quien cumple años, se va o llega.'),
        _filaPersonas('Homenajeadxs', _homenajeados, () async {
          final r = await _elegirPersonas('¿A quién homenajean?', _homenajeados, excluir: _sorpresa && yo != null ? {yo} : const {});
          if (r != null) {
            setState(() {
              _homenajeados
                ..clear()
                ..addAll(r);
              _noEnterarse.removeAll(r);
              _encargados.removeAll(r);
              if (r.isNotEmpty) _piezas.add(Pieza.homenaje);
            });
          }
        }, vacio: 'Nadie por ahora.'),
        _desplegable(
          _piezas.contains(Pieza.homenaje) || _homenajeados.isNotEmpty,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Homenaje'),
                subtitle: const Text('Mensajes y regalo entre todxs para las personas homenajeadas'),
                value: _piezas.contains(Pieza.homenaje),
                onChanged: (v) => setState(() => v ? _piezas.add(Pieza.homenaje) : _piezas.remove(Pieza.homenaje)),
              ),
              _desplegable(
                _piezas.contains(Pieza.homenaje),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mensajes de todxs'),
                      subtitle: const Text('Los leen después del evento o cuando tú los liberes'),
                      value: _mensajes,
                      onChanged: (v) => setState(() => _mensajes = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Regalo entre todxs'),
                      subtitle: const Text('Solo se anota quién aporta cuánto y quién compra. No pasa por Finanzas.'),
                      value: _regalo,
                      onChanged: (v) => setState(() => _regalo = v),
                    ),
                    _desplegable(
                      _regalo,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _numero(_regaloTope, 'Tope del regalo (opcional)'),
                          TextField(
                            controller: _regaloNota,
                            maxLength: 300,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(labelText: 'Idea del regalo (opcional)'),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.shopping_bag_outlined),
                            title: const Text('Quién compra'),
                            subtitle: Text(_regaloCompra == null ? 'Sin elegir' : (eq?.nombreDe(_regaloCompra!) ?? _regaloCompra!)),
                            onTap: () async {
                              final r = await _elegirPersonas('¿Quién compra el regalo?', {?_regaloCompra}, excluir: _homenajeados);
                              if (r != null) setState(() => _regaloCompra = r.isEmpty ? null : r.last);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(Icons.visibility_off_outlined, color: _sorpresa ? p.marcaTexto : p.textoSecundario),
          title: const Text('Es sorpresa'),
          subtitle: const Text('Las personas homenajeadas y quienes no deben enterarse lo ven como un evento normal, con un nombre neutro.'),
          value: _sorpresa,
          onChanged: (v) => setState(() => _sorpresa = v),
        ),
        _desplegable(
          _sorpresa,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _neutro,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre neutro', hintText: 'Lo que ven quienes no deben enterarse'),
                onChanged: (_) => setState(() {}),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final t in kSugerenciasNeutras) ActionChip(label: Text(t), onPressed: () => setState(() => _neutro.text = t))],
              ),
              _titulo('No deben enterarse', ayuda: 'Además de las personas homenajeadas.'),
              _filaPersonas('No deben enterarse', _noEnterarse, () async {
                final r = await _elegirPersonas('¿Quiénes no deben enterarse?', _noEnterarse, excluir: {..._homenajeados, ?yo});
                if (r != null) {
                  setState(() {
                    _noEnterarse
                      ..clear()
                      ..addAll(r);
                    _encargados.removeAll(r);
                  });
                }
              }, vacio: 'Solo las personas homenajeadas.'),
              _titulo('¿Qué ven?', ayuda: 'Homenaje, mensajes, regalo entre todxs y premios nunca los ven. Lo demás, sí, salvo que lo apagues.'),
              for (final pz in _elegibles.where(_piezas.contains))
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(pz.icono, color: _ocultas.contains(pz) ? p.textoSecundario : p.marcaTexto),
                  title: Text(pz.titulo),
                  subtitle: Text(_ocultas.contains(pz) ? 'No lo ve la persona homenajeada' : 'Lo ve la persona homenajeada'),
                  value: !_ocultas.contains(pz),
                  onChanged: (v) => setState(() => v ? _ocultas.remove(pz) : _ocultas.add(pz)),
                ),
              const SizedBox(height: 8),
              Text('Lo que sí ven, escríbelo sin pistas de la sorpresa.', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Paso 7: encargadxs ─────────────────────────────────────────────────

  static const _permisosPorDefecto = {'fecha', 'amigo', 'comida', 'extras', 'invitados'};
  static const _areas = [
    ('fecha', 'Fecha, hora y lugar', Icons.event_outlined),
    ('amigo', 'Amigo secreto y regalo robado', Icons.redeem_rounded),
    ('comida', 'Comida y qué traer', Icons.restaurant_rounded),
    ('extras', 'Playlist, dress code y premios', Icons.music_note_rounded),
    ('invitados', 'Invitadxs (+1)', Icons.person_add_alt_rounded),
    ('homenaje', 'Homenaje y sorpresa', Icons.favorite_border_rounded),
  ];

  Widget _pasoEncargados(BuildContext context) {
    final p = context.pivot;
    final yo = widget.sesion.nombre;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _filaPersonas('Encargadxs', _encargados, () async {
          final r = await _elegirPersonas('Encargadxs', _encargados, excluir: {?yo, if (_sorpresa) ..._homenajeados, if (_sorpresa) ..._noEnterarse});
          if (r != null) {
            setState(() {
              _encargados
                ..clear()
                ..addAll(r);
              _permisos.removeWhere((u, _) => !r.contains(u));
              for (final u in r) {
                _permisos.putIfAbsent(u, () => {..._permisosPorDefecto});
              }
            });
          }
        }, vacio: 'Solo tú por ahora.'),
        // Qué puede cambiar cada encargadx (Victor, 2026-11-20). Quien crea el evento cambia todo.
        if (_encargados.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Quien crea el evento puede cambiar todo. Elige qué puede cambiar cada encargadx:', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
          for (final u in _encargados)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nombres({u}),
                    style: TextStyle(fontWeight: FontWeight.w700, color: p.texto),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (clave, texto, icono) in _areas)
                        FilterChip(
                          avatar: Icon(icono, size: 16),
                          label: Text(texto),
                          selected: _permisos[u]?.contains(clave) ?? false,
                          onSelected: !_todo
                              ? null
                              : (v) => setState(() {
                                  final s = _permisos.putIfAbsent(u, () => {..._permisosPorDefecto});
                                  v ? s.add(clave) : s.remove(clave);
                                }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  // ─── Paso 8: resumen ────────────────────────────────────────────────────

  String get _textoPlantilla {
    final pl = kPlantillas.where((x) => x.id == _plantilla).firstOrNull;
    if (pl == null) return 'Personalizado';
    if (pl.id != 'festividad') return pl.titulo;
    return 'Festividad: ${_festividad == 'Otra' ? _festividadOtra.text.trim() : _festividad ?? ''}';
  }

  String get _textoPara => switch (_para) {
    'equipo' => 'Mi equipo (${_equipo?.miEquipo ?? ''})',
    'equipos' => _equipos.join(', '),
    'personas' => _personas.length == 1 ? '1 persona' : '${_personas.length} personas',
    _ => 'Toda la liga',
  };

  String _nombres(Set<String> us) => us.map((u) => _equipo?.nombreDe(u) ?? '${widget.actual?.editable?['nombres']?[u] ?? u}').join(', ');

  Widget _pasoResumen(BuildContext context) {
    final p = context.pivot;
    final estado = widget.actual?.estadoAprobacion;
    // Encargadxs: solo abren lo que les toca; el resto se ve con candado.
    bool abre(_P paso) => switch (paso) {
      _P.plantilla || _P.invitados || _P.encargados => _todo,
      _P.datos => _todo || _puede('fecha'),
      _P.piezas => _todo || Pieza.values.any(_puedePieza),
      _P.config => _todo || ['amigo', 'comida', 'extras', 'invitados'].any(_puede),
      _P.homenaje => _puede('homenaje'),
      _ => true,
    };
    Widget fila(_P paso, IconData icono, String titulo, String texto) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icono, color: abre(paso) ? p.marcaTexto : p.textoSecundario),
      title: Text(titulo),
      subtitle: Text(texto.isEmpty ? '—' : texto),
      trailing: Icon(abre(paso) ? Icons.edit_outlined : Icons.lock_outline_rounded, size: 18, color: p.textoSecundario),
      onTap: abre(paso) ? () => _ir(paso) : () => avisarSocial(context, 'Esto lo cambia quien creó el evento.'),
    );
    final hora = [if (_inicia != null) _hhmm(_inicia!), if (_termina != null) _hhmm(_termina!)].join(' – ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (estado == 'rechazado')
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
            child: Text(
              'Un Pivot pidió cambios${widget.actual!.rechazoMotivo.isEmpty ? '' : ': ${widget.actual!.rechazoMotivo}'}',
              style: TextStyle(color: p.sobreSuave),
            ),
          ),
        fila(_P.plantilla, Icons.extension_outlined, 'Qué vas a armar', _textoPlantilla),
        fila(
          _P.datos,
          Icons.event_note_outlined,
          _nombre.text.trim(),
          [if (_fecha != null) '${Fechas.dia(_fecha!)} ${Fechas.corta(_fecha!)}', hora, _lugar.text.trim()].where((x) => x.isNotEmpty).join(' · '),
        ),
        fila(_P.invitados, Icons.groups_outlined, 'Invitadxs', _textoPara),
        fila(
          _P.piezas,
          Icons.widgets_outlined,
          'Qué tendrá',
          [
            for (final pz in Pieza.values)
              if (_piezas.contains(pz)) pz.titulo,
          ].join(', '),
        ),
        fila(_P.config, Icons.tune_rounded, 'Configuración', 'Comida, topes, reglas, playlist y más'),
        fila(
          _P.homenaje,
          Icons.favorite_border_rounded,
          'Homenaje y sorpresa',
          [
            if (_homenajeados.isNotEmpty) 'Para ${_nombres(_homenajeados)}',
            if (_sorpresa) 'Sorpresa: ven "${_neutro.text.trim()}"',
            if (_sorpresa && _noEnterarse.isNotEmpty) 'Tampoco se enteran: ${_nombres(_noEnterarse)}',
            // Sin homenaje no se le recuerda nada (Victor, 2026-11-20); queda la fila para agregarlo.
            if (_homenajeados.isEmpty && !_sorpresa) 'Sin homenaje ni sorpresa',
          ].join('\n'),
        ),
        fila(_P.encargados, Icons.manage_accounts_outlined, 'Encargadxs', _nombres(_encargados)),
      ],
    );
  }

  // ─── Enviar ─────────────────────────────────────────────────────────────

  num? _n(TextEditingController c) => num.tryParse(c.text.trim().replaceAll(',', '.'));

  Map<String, Object?> _datos() {
    final festividad = _plantilla == 'festividad' ? (_festividad == 'Otra' ? _festividadOtra.text.trim() : _festividad) : null;
    final cierre = _cierreElegido;
    final piezas = <String, Object?>{
      if (_piezas.contains(Pieza.playlist)) 'playlist': {'link': _playlist.text.trim(), 'nota': _playlistNota.text.trim()},
      if (_piezas.contains(Pieza.dress)) 'dress': {'texto': _dress.text.trim()},
      if (_piezas.contains(Pieza.traer))
        'traer': {
          'items': [
            for (final t in _traer)
              if (t.texto.text.trim().isNotEmpty) {'id': t.id, 'texto': t.texto.text.trim(), 'cantidad': int.tryParse(t.cantidad.text.trim())},
          ],
        },
      if (_piezas.contains(Pieza.premios))
        'premios': {
          'lista': [
            for (final x in _premios)
              if (x.premio.text.trim().isNotEmpty) {'id': x.id, 'premio': x.premio.text.trim(), 'para': x.para.text.trim()},
          ],
        },
      if (_piezas.contains(Pieza.homenaje)) 'homenaje': {'mensajes': _mensajes, 'regalo': _regalo, 'regaloNota': _regaloNota.text.trim()},
      if (_piezas.contains(Pieza.amigoSecreto) && _noTocar.isNotEmpty)
        'noTocar': [
          for (final (a, b) in _noTocar) [a, b],
        ],
      if (_plantilla == 'festividad' && _festividad == 'Otra') 'icono': _icono,
      'ocultas': _sorpresa
          ? [
              for (final pz in _ocultas)
                if (_piezas.contains(pz)) pz.name,
            ]
          : <String>[],
    };
    return {
      'plantilla': _plantilla ?? 'personalizado',
      'festividad': festividad,
      'nombre': _nombre.text.trim(),
      'nombreNeutro': _sorpresa ? _neutro.text.trim() : '',
      'descripcion': _descripcion.text.trim(),
      'fecha': _fecha == null ? null : Fechas.iso(_fecha!),
      'inicia': _inicia == null ? null : _hhmm(_inicia!),
      'termina': _termina == null ? null : _hhmm(_termina!),
      'lugar': _lugar.text.trim(),
      'mapa': _mapa.text.trim(),
      'para': {
        'tipo': _para,
        'valores': _para == 'personas'
            ? _personas.toList()
            : _para == 'equipos'
            ? _equipos.toList()
            : <String>[],
      },
      'modulos': {
        'amigoSecreto': _piezas.contains(Pieza.amigoSecreto),
        'regaloRobado': _piezas.contains(Pieza.regaloRobado),
        'comida': _piezas.contains(Pieza.comida),
        'invitados': _piezas.contains(Pieza.invitados),
      },
      'topeAmigo': _n(_topeAmigo),
      'topeRobado': _n(_topeRobado),
      'recordatorioRobado': _recordatorio.text.trim(),
      'reglasRobado': _reglas.text.trim(),
      'cierre': cierre == null ? null : Fechas.iso(cierre),
      if (_piezas.contains(Pieza.comida))
        'categorias': [
          for (final c in _cats)
            if (c.nombre.text.trim().isNotEmpty)
              {'id': c.id, 'nombre': c.nombre.text.trim(), 'unidad': c.unidad.text.trim(), 'porPersona': _n(c.porPersona) ?? 1},
        ],
      'piezas': piezas,
      'sorpresa': _sorpresa,
      'homenajeados': _homenajeados.toList(),
      'noEnterarse': _sorpresa ? _noEnterarse.toList() : <String>[],
      'regaloTope': _n(_regaloTope),
      'regaloCompra': _regaloCompra,
      'encargados': _encargados.toList(),
      if (_todo) 'permisos': {for (final u in _encargados) u: (_permisos[u] ?? _permisosPorDefecto).toList()},
    };
  }

  Future<void> _enviar() async {
    setState(() => _guardando = true);
    final m = ScaffoldMessenger.of(context);
    try {
      if (_editando) {
        final r = await widget.repo!.guardar(_datos(), reenviar: widget.actual?.estadoAprobacion == 'rechazado');
        if (!mounted) return;
        final avisos = [for (final x in (r['avisos'] as List? ?? const [])) '$x'];
        m.showSnackBar(SnackBar(content: Text(avisos.isEmpty ? 'Cambios guardados.' : avisos.join('\n'))));
        Navigator.of(context).pop(true);
      } else {
        final r = await SocialRepo.crear(widget.sesion.api, _datos(), adminToken: widget.sesion.adminToken);
        if (!mounted) return;
        Navigator.of(context).pop({'social': r['idEvento'], 'fecha': _fecha, 'mensaje': r['mensaje'] ?? 'Evento creado.'});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
    }
  }
}
