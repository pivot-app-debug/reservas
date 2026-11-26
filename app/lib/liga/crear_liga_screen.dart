import '../core/selector_hora.dart';

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../ajustes/componentes.dart' show abrirFormulario;

import '../liga/directorio_screen.dart';
import '../core/monedas_mundo.dart';
import '../core/tema.dart';
import '../core/fondo_dinamico.dart';
import '../sesion/boton_google.dart';
import '../sesion/sesion.dart';

/// Asistente para crear una liga (Victor, 2026-11-17): cuenta (Google o
/// correo con código), lo básico, Rápido o Paso a paso, resumen editable,
/// tu perfil y la bienvenida como Pivot. La liga se crea recién al final.

/// País → (nombre, moneda, zona horaria principal).
const _paises = <String, (String, String, String)>{
  'AR': ('Argentina', 'ARS', 'America/Argentina/Buenos_Aires'),
  'BO': ('Bolivia', 'BOB', 'America/La_Paz'),
  'BR': ('Brasil', 'BRL', 'America/Sao_Paulo'),
  'CA': ('Canadá', 'CAD', 'America/Toronto'),
  'CL': ('Chile', 'CLP', 'America/Santiago'),
  'CO': ('Colombia', 'COP', 'America/Bogota'),
  'CR': ('Costa Rica', 'CRC', 'America/Costa_Rica'),
  'CU': ('Cuba', 'CUP', 'America/Havana'),
  'DO': ('República Dominicana', 'DOP', 'America/Santo_Domingo'),
  'EC': ('Ecuador', 'USD', 'America/Guayaquil'),
  'ES': ('España', 'EUR', 'Europe/Madrid'),
  'GT': ('Guatemala', 'GTQ', 'America/Guatemala'),
  'HN': ('Honduras', 'HNL', 'America/Tegucigalpa'),
  'MX': ('México', 'MXN', 'America/Mexico_City'),
  'NI': ('Nicaragua', 'NIO', 'America/Managua'),
  'PA': ('Panamá', 'PAB', 'America/Panama'),
  'PE': ('Perú', 'PEN', 'America/Lima'),
  'PR': ('Puerto Rico', 'USD', 'America/Puerto_Rico'),
  'PY': ('Paraguay', 'PYG', 'America/Asuncion'),
  'SV': ('El Salvador', 'USD', 'America/El_Salvador'),
  'US': ('Estados Unidos', 'USD', 'America/New_York'),
  'UY': ('Uruguay', 'UYU', 'America/Montevideo'),
  'VE': ('Venezuela', 'VES', 'America/Caracas'),
  'GB': ('Reino Unido', 'GBP', 'Europe/London'),
  'DE': ('Alemania', 'EUR', 'Europe/Berlin'),
  'FR': ('Francia', 'EUR', 'Europe/Paris'),
  'IT': ('Italia', 'EUR', 'Europe/Rome'),
  'PT': ('Portugal', 'EUR', 'Europe/Lisbon'),
  'AU': ('Australia', 'AUD', 'Australia/Sydney'),
};

/// Deportes de equipo. Por ahora solo roller derby está habilitado.
const _deportes = <(String, String)>[
  ('roller_derby', 'Roller derby'),
  ('futbol', 'Fútbol'),
  ('futsal', 'Fútbol sala'),
  ('basquet', 'Básquet'),
  ('voley', 'Vóley'),
  ('handball', 'Handball'),
  ('rugby', 'Rugby'),
  ('hockey_patines', 'Hockey sobre patines'),
  ('hockey_cesped', 'Hockey sobre césped'),
  ('hockey_hielo', 'Hockey sobre hielo'),
  ('waterpolo', 'Waterpolo'),
  ('ultimate', 'Ultimate frisbee'),
  ('beisbol', 'Béisbol'),
  ('softbol', 'Sóftbol'),
  ('futbol_americano', 'Fútbol americano'),
  ('quidditch', 'Quadball'),
  ('cricket', 'Críquet'),
  ('lacrosse', 'Lacrosse'),
  ('korfball', 'Korfball'),
  ('netball', 'Netball'),
];

const _rolesDerby = ['Jammer', 'Blocker', 'Pivot', 'Bench', 'Coach', 'Árbitrx (SO)', 'NSO', 'Staff'];
const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

/// Pasos del asistente.
enum _Paso { cuenta, basico, modo, equipos, cuota, clase, medios, entrenamientos, asistencia, roles, premios, resumen, perfil }

const _pasosAvanzados = [_Paso.equipos, _Paso.cuota, _Paso.clase, _Paso.medios, _Paso.entrenamientos, _Paso.asistencia, _Paso.roles, _Paso.premios];

class CrearLigaScreen extends StatefulWidget {
  const CrearLigaScreen({super.key, required this.sesion});
  final Sesion sesion;
  @override
  State<CrearLigaScreen> createState() => _CrearLigaScreenState();
}

class _CrearLigaScreenState extends State<CrearLigaScreen> {
  Sesion get s => widget.sesion;
  _Paso _paso = _Paso.cuenta;
  bool _adelante = true;
  bool _ocupado = false;
  String? _error;

  // Cuenta.
  String? _idToken;
  String? _registroToken;
  String _email = '';
  bool _codigoEnviado = false;
  final _correo = TextEditingController();
  final _codigo = TextEditingController();
  StreamSubscription<Object>? _googleWeb;

  // Básico.
  final _nombre = TextEditingController();
  final _ciudad = TextEditingController();
  String _deporte = 'roller_derby';
  late String _pais = _paisDelTelefono();
  bool _avisoRepetida = false;

  // Camino.
  bool _avanzado = false;

  // Paso a paso.
  final List<Map<String, dynamic>> _equipos = [
    {'nombre': 'Equipo principal', 'nuevxs': true, 'cuota': ''},
  ];
  bool _cobra = false;
  final _monto = TextEditingController(text: '20');
  bool _cuotaIgual = true;
  int _vence = 15;
  bool _recargo = false;
  final _recargoMonto = TextEditingController(text: '2');
  String _recargoTipo = 'fijo';
  bool _vendeClase = false;
  final _precioClase = TextEditingController(text: '5');
  final List<Map<String, dynamic>> _medios = [];
  final List<Map<String, dynamic>> _entrenamientos = [];
  bool _cambiosEquipo = false;
  final List<String> _roles = [..._rolesDerby];
  bool _premios = false;

  // Perfil.
  final _usuario = TextEditingController();
  final _derby = TextEditingController();
  final _numero = TextEditingController();
  final Set<String> _pronombres = {};
  final Set<String> _misRoles = {};
  DateTime? _nacimiento;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      Sesion.capturaGoogle = (cuenta) {
        final t = cuenta.authentication.idToken;
        if (t == null || !mounted) return;
        setState(() {
          _idToken = t;
          _email = cuenta.email;
        });
        _siguiente();
      };
    }
  }

  @override
  void dispose() {
    Sesion.capturaGoogle = null;
    _googleWeb?.cancel();
    for (final c in [_correo, _codigo, _nombre, _ciudad, _monto, _recargoMonto, _precioClase, _usuario, _derby, _numero]) {
      c.dispose();
    }
    super.dispose();
  }

  /// País del teléfono (configuración regional), o Ecuador.
  static String _paisDelTelefono() {
    final c = WidgetsBinding.instance.platformDispatcher.locale.countryCode?.toUpperCase();
    return c != null && _paises.containsKey(c) ? c : 'EC';
  }

  String get _monedaCodigo => _paises[_pais]?.$2 ?? 'USD';
  String get _monedaSimbolo => monedasMundo.where((m) => m.$1 == _monedaCodigo).map((m) => m.$3).firstOrNull ?? r'$';

  List<_Paso> get _pasos => [_Paso.cuenta, _Paso.basico, _Paso.modo, if (_avanzado) ..._pasosAvanzados, _Paso.resumen, _Paso.perfil];

  void _ir(_Paso p) => setState(() {
    _adelante = _pasos.indexOf(p) >= _pasos.indexOf(_paso);
    _paso = p;
    _error = null;
  });

  Future<void> _siguiente() async {
    final l = _pasos;
    if (_paso == _Paso.basico && !await _revisarNombre()) return;
    final i = l.indexOf(_paso);
    if (i < l.length - 1) _ir(l[i + 1]);
  }

  void _atras() {
    final l = _pasos;
    final i = l.indexOf(_paso);
    if (i <= 0) {
      Navigator.of(context).maybePop();
    } else {
      _ir(l[i - 1]);
    }
  }

  /// Si ya hay una liga con ese nombre del mismo deporte, pregunta.
  Future<bool> _revisarNombre() async {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'Ponle un nombre a tu liga.');
      return false;
    }
    if (_avisoRepetida) return true;
    try {
      final r = await s.api.get('verificarNombreLiga', {'nombre': _nombre.text.trim(), 'deporte': _deporte});
      final l = (r['ligas'] as List? ?? const []);
      if (r['existe'] == true && l.isNotEmpty && mounted) {
        final x = l.first as Map;
        final donde = [x['ciudad'], _paises[x['pais']]?.$1 ?? x['pais']].where((v) => '${v ?? ''}'.isNotEmpty).join(', ');
        final seguir = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('¿Es la tuya?'),
            content: Text(
              'Ya hay una liga de ${_nombreDeporte(_deporte).toLowerCase()} llamada "${x['nombre']}"${donde.isEmpty ? '' : ' en $donde'}. Si es tu liga, pide a un Pivot de ahí tu enlace de inscripción en vez de crear otra.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Es mi liga')),
              FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Es otra, seguir')),
            ],
          ),
        );
        if (seguir != true) {
          if (mounted) Navigator.of(context).maybePop();
          return false;
        }
        _avisoRepetida = true;
      }
    } catch (_) {
      // Sin señal: se revisa igual en el servidor al crear.
    }
    return true;
  }

  static String _nombreDeporte(String id) => _deportes.firstWhere((d) => d.$1 == id, orElse: () => _deportes.first).$2;

  Future<void> _conGoogle() async {
    setState(() => _ocupado = true);
    try {
      final t = await s.idTokenGoogle();
      if (!mounted) return;
      setState(() {
        _idToken = t;
        _ocupado = false;
      });
      _siguiente();
    } on LoginFallido catch (e) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _error = e.mensaje.isEmpty ? null : e.mensaje;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _error = 'No se pudo usar Google.';
        });
      }
    }
  }

  Future<void> _enviarCodigo() async {
    final e = _correo.text.trim().toLowerCase();
    if (!e.contains('@')) return setState(() => _error = 'Escribe un correo válido.');
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await s.enviarCodigoCorreo(e);
      if (mounted) {
        setState(() {
          _ocupado = false;
          _codigoEnviado = true;
          _email = e;
        });
      }
    } on LoginFallido catch (x) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _error = x.mensaje;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _error = 'No se pudo enviar el código. Revisa tu conexión.';
        });
      }
    }
  }

  Future<void> _verificarCodigo() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final t = await s.registroDeCorreo(_email, _codigo.text);
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _registroToken = t;
      });
      _siguiente();
    } on LoginFallido catch (x) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _error = x.mensaje;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _error = 'No se pudo verificar el código.';
        });
      }
    }
  }

  Map<String, Object?> _datos() => {
    'nombre': _nombre.text.trim(),
    'deporte': _deporte,
    'pais': _pais,
    'ciudad': _ciudad.text.trim(),
    'zonaHoraria': _paises[_pais]?.$3 ?? 'America/Guayaquil',
    'moneda': _monedaSimbolo,
    'monedaCodigo': _monedaCodigo,
    'modo': _avanzado ? 'pasos' : 'rapido',
    if (_avanzado) ...{
      'equipos': _equipos,
      'cuota': {
        'cobra': _cobra,
        'monto': num.tryParse(_monto.text.replaceAll(',', '.')) ?? 0,
        'igual': _cuotaIgual,
        'dia': _vence,
        'recargo': _recargo ? (num.tryParse(_recargoMonto.text.replaceAll(',', '.')) ?? 0) : 0,
        'recargoTipo': _recargoTipo,
      },
      'claseSuelta': {'vende': _vendeClase, 'precio': num.tryParse(_precioClase.text.replaceAll(',', '.')) ?? 0},
      'medios': _medios,
      'entrenamientos': _entrenamientos,
      'cambiosEquipo': _cambiosEquipo,
      'roles': _roles,
      'premios': _premios && _cobra,
    },
    'perfil': {
      'usuario': _usuario.text.trim(),
      'nombreDerby': _derby.text.trim(),
      'numeroDerby': _numero.text.trim(),
      'pronombres': _pronombres.join(', '),
      'roles': _misRoles.toList(),
      if (_nacimiento != null)
        'fechaNac': '${_nacimiento!.year}-${_nacimiento!.month.toString().padLeft(2, '0')}-${_nacimiento!.day.toString().padLeft(2, '0')}',
    },
  };

  Future<void> _crear() async {
    final u = _usuario.text.trim();
    if (!RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'\-]{2,40}$").hasMatch(u)) {
      return setState(() => _error = 'Tu nombre de usuario solo puede tener letras y espacios.');
    }
    if (_nacimiento == null) return setState(() => _error = 'Elige tu fecha de nacimiento.');
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await s.crearLiga({
        'datos': _datos(),
        if (_idToken != null) 'idToken': _idToken else ...{'email': _email, 'registroToken': _registroToken},
      });
      await PrimerosPasos.activar();
      if (!_avanzado) await SugerenciaReglas.marcarPendiente();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, _, _) => _BienvenidaPivot(liga: _nombre.text.trim(), rapido: !_avanzado),
          transitionsBuilder: (_, a, _, h) => FadeTransition(opacity: a, child: h),
        ),
      );
    } on LoginFallido catch (x) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _error = x.mensaje;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _error = 'No se pudo crear la liga. Revisa tu conexión.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _pasos;
    final i = l.indexOf(_paso);
    final avanzadoActual = _pasosAvanzados.contains(_paso);
    return PopScope(
      canPop: i == 0,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) _atras();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _ocupado ? null : _atras),
          title: const Text('Crea tu liga', style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [if (avanzadoActual) TextButton(onPressed: () => _ir(_Paso.resumen), child: const Text('Terminar ahora'))],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (i + 1) / l.length),
              duration: const Duration(milliseconds: 300),
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 4, backgroundColor: p.apagadoFondo, color: p.marca),
            ),
          ),
        ),
        // Mismo fondo que el inicio de sesión (QA 2026-11-18).
        body: FondoDinamico(
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (h, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: Offset(_adelante ? 0.06 : -0.06, 0), end: Offset.zero).animate(a),
                  child: h,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_paso),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    ..._contenido(context),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(
                                _error!,
                                style: TextStyle(color: p.marcaTexto, fontWeight: FontWeight.w600),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    if (_paso != _Paso.cuenta && _paso != _Paso.modo)
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: _ocupado ? null : (_paso == _Paso.perfil ? _crear : _siguiente),
                        child: _ocupado
                            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: p.sobreMarca))
                            : Text(switch (_paso) {
                                _Paso.resumen => 'Todo bien, seguir con mi perfil',
                                _Paso.perfil => 'Crear mi liga',
                                _ => 'Siguiente',
                              }),
                      ),
                    if (avanzadoActual) TextButton(onPressed: _siguiente, child: const Text('Lo veo después')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titulo(String t, [String? sub]) {
    final p = context.pivot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.15, color: p.texto),
          ),
          if (sub != null) ...[const SizedBox(height: 6), Text(sub, style: TextStyle(fontSize: 15, height: 1.4, color: p.textoSecundario))],
        ],
      ),
    );
  }

  Widget _interruptor(String t, bool v, ValueChanged<bool> c, [String? sub]) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: sub == null ? null : Text(sub),
    value: v,
    onChanged: (x) => setState(() => c(x)),
  );

  Widget _abrir(bool v, List<Widget> hijos) => AnimatedSize(
    duration: const Duration(milliseconds: 220),
    alignment: Alignment.topCenter,
    child: v ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos) : const SizedBox(width: double.infinity),
  );

  TextField _numeroCampo(TextEditingController c, String etiqueta) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: etiqueta, prefixText: '$_monedaSimbolo '),
  );

  List<Widget> _contenido(BuildContext context) {
    final p = context.pivot;
    switch (_paso) {
      case _Paso.cuenta:
        return [
          _titulo('Primero, tu cuenta', 'Con ella entrarás a Pivot y quedarás como Pivot de tu liga.'),
          if (kIsWeb)
            Center(child: botonGoogleWeb() ?? const SizedBox.shrink())
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _ocupado ? null : _conGoogle,
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('Continuar con Google'),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('o con tu correo', style: TextStyle(color: p.textoSecundario)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _correo,
            enabled: !_codigoEnviado,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo'),
          ),
          _abrir(_codigoEnviado, [
            const SizedBox(height: 10),
            Text('Te enviamos un código de 6 dígitos a $_email.', style: TextStyle(color: p.textoSecundario)),
            const SizedBox(height: 8),
            TextField(
              controller: _codigo,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Código', counterText: ''),
            ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _ocupado ? null : (_codigoEnviado ? _verificarCodigo : _enviarCodigo),
            child: Text(_codigoEnviado ? 'Verificar código' : 'Enviarme un código'),
          ),
          if (_codigoEnviado) TextButton(onPressed: _ocupado ? null : () => setState(() => _codigoEnviado = false), child: const Text('Usar otro correo')),
        ];
      case _Paso.basico:
        return [
          _titulo('Tu liga'),
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _avisoRepetida = false,
            decoration: const InputDecoration(labelText: 'Nombre de la liga', hintText: 'Ej. Quindes Volcánicos'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _deporte,
            decoration: const InputDecoration(labelText: 'Deporte'),
            items: [
              for (final d in _deportes)
                DropdownMenuItem(
                  value: d.$1,
                  enabled: d.$1 == 'roller_derby',
                  child: Text(d.$1 == 'roller_derby' ? d.$2 : '${d.$2} · Próximamente', style: TextStyle(color: d.$1 == 'roller_derby' ? null : p.apagado)),
                ),
            ],
            onChanged: (v) => setState(() => _deporte = v ?? 'roller_derby'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _pais,
            decoration: const InputDecoration(labelText: 'País'),
            items: [
              for (final e in (_paises.entries.toList()..sort((a, b) => a.value.$1.compareTo(b.value.$1))))
                DropdownMenuItem(value: e.key, child: Text(e.value.$1)),
            ],
            onChanged: (v) => setState(() => _pais = v ?? _pais),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ciudad,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Ciudad'),
          ),
          const SizedBox(height: 10),
          Text(
            'Moneda: $_monedaCodigo ($_monedaSimbolo) · Hora: ${_paises[_pais]?.$3.split('/').last.replaceAll('_', ' ')}. Puedes cambiarlas después en Liga → Ajustes.',
            style: TextStyle(fontSize: 13, color: p.textoSecundario),
          ),
        ];
      case _Paso.modo:
        Widget opcion(bool avanzado, IconData i, String t, String d) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: p.tarjeta,
            borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                setState(() => _avanzado = avanzado);
                _siguiente();
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(i, size: 30, color: p.marcaTexto),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.texto),
                          ),
                          const SizedBox(height: 4),
                          Text(d, style: TextStyle(height: 1.35, color: p.textoSecundario)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
        );
        return [
          _titulo('¿Cómo quieres armarla?'),
          opcion(
            false,
            Icons.bolt_rounded,
            'Rápido',
            'Tu liga queda lista con valores por defecto. Después, desde Liga → Ajustes, ajustas equipos, cuotas y reglas cuando quieras.',
          ),
          opcion(
            true,
            Icons.tune_rounded,
            'Paso a paso',
            'Unas preguntas cortas sobre equipos, cuota, entrenamientos y más. Puedes saltar cualquiera o terminar cuando quieras.',
          ),
        ];
      case _Paso.equipos:
        return [
          _titulo('Tus equipos', 'Por ejemplo A, B y principiantes. Marca a cuál entra la gente nueva.'),
          for (var i = 0; i < _equipos.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Aquí entra la gente nueva',
                    icon: Icon(_equipos[i]['nuevxs'] == true ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                    onPressed: () => setState(() {
                      for (final e in _equipos) {
                        e['nuevxs'] = false;
                      }
                      _equipos[i]['nuevxs'] = true;
                    }),
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: '${_equipos[i]['nombre']}',
                      textCapitalization: TextCapitalization.words,
                      onChanged: (v) => _equipos[i]['nombre'] = v,
                      decoration: InputDecoration(labelText: 'Equipo ${i + 1}', helperText: _equipos[i]['nuevxs'] == true ? 'Aquí entra la gente nueva' : null),
                    ),
                  ),
                  if (_equipos.length > 1)
                    IconButton(tooltip: 'Quitar', onPressed: () => setState(() => _equipos.removeAt(i)), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
          if (_equipos.length < 12)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _equipos.add({'nombre': 'Equipo ${_equipos.length + 1}', 'nuevxs': false, 'cuota': ''})),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar equipo'),
              ),
            ),
        ];
      case _Paso.cuota:
        return [
          _titulo('Cuota mensual'),
          _interruptor('¿Cobran cuota mensual?', _cobra, (v) => _cobra = v),
          _abrir(_cobra, [
            if (_equipos.length > 1) _interruptor('La misma para todos los equipos', _cuotaIgual, (v) => _cuotaIgual = v),
            const SizedBox(height: 6),
            if (_cuotaIgual || _equipos.length < 2)
              _numeroCampo(_monto, 'Cuánto es la cuota')
            else
              for (final e in _equipos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextFormField(
                    initialValue: '${e['cuota'] ?? ''}',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => e['cuota'] = v,
                    decoration: InputDecoration(labelText: 'Cuota de ${e['nombre']}', prefixText: '$_monedaSimbolo '),
                  ),
                ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text('Vence el día', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(onPressed: _vence <= 1 ? null : () => setState(() => _vence--), icon: const Icon(Icons.remove_rounded)),
                Text('$_vence', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                IconButton(onPressed: _vence >= 28 ? null : () => setState(() => _vence++), icon: const Icon(Icons.add_rounded)),
              ],
            ),
            Text('de cada mes', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
            _interruptor('¿Cobran recargo por atraso?', _recargo, (v) => _recargo = v),
            _abrir(_recargo, [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'fijo', label: Text('Monto fijo')),
                  ButtonSegment(value: 'porcentaje', label: Text('Porcentaje')),
                ],
                selected: {_recargoTipo},
                onSelectionChanged: (v) => setState(() => _recargoTipo = v.first),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _recargoMonto,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Recargo',
                  prefixText: _recargoTipo == 'fijo' ? '$_monedaSimbolo ' : null,
                  suffixText: _recargoTipo == 'porcentaje' ? '%' : null,
                ),
              ),
            ]),
          ]),
        ];
      case _Paso.clase:
        return [
          _titulo('Clases sueltas', 'Para quien no paga cuota o viene de vez en cuando.'),
          _interruptor('¿Venden clases sueltas?', _vendeClase, (v) => _vendeClase = v, 'Se reservan y pagan desde la app.'),
          _abrir(_vendeClase, [_numeroCampo(_precioClase, 'Precio por clase')]),
        ];
      case _Paso.medios:
        return [
          _titulo('¿Cómo les pagan?', 'Aparecen al pagar una cuota o una clase. Puedes agregar más datos después.'),
          for (var i = 0; i < _medios.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (_medios[i]['tipo']) {
                'efectivo' => Icons.payments_outlined,
                'enlace' => Icons.link_rounded,
                _ => Icons.account_balance_outlined,
              }),
              title: Text('${_medios[i]['nombre']}'),
              subtitle: '${_medios[i]['enlace'] ?? ''}'.isEmpty ? null : Text('${_medios[i]['enlace']}'),
              trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _medios.removeAt(i))),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in const [('transferencia', 'Transferencia'), ('efectivo', 'Efectivo'), ('enlace', 'Enlace de pago')])
                ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: Text(t.$2), onPressed: () => _nuevoMedio(t.$1, t.$2)),
            ],
          ),
        ];
      case _Paso.entrenamientos:
        return [
          _titulo('Entrenamientos', 'Se crean solos en el calendario, todas las semanas.'),
          for (var i = 0; i < _entrenamientos.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_repeat_rounded),
              title: Text((_entrenamientos[i]['dias'] as List).join(', ')),
              subtitle: Text('${_entrenamientos[i]['inicia']} a ${_entrenamientos[i]['finaliza']} · ${_entrenamientos[i]['lugar']}'),
              trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _entrenamientos.removeAt(i))),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: _nuevoEntrenamiento, icon: const Icon(Icons.add_rounded), label: const Text('Agregar horario')),
          ),
        ];
      case _Paso.asistencia:
        return [
          _titulo('Asistencia', 'Cada asistencia suma puntos y se ven en Estadísticas.'),
          if (_equipos.length > 1)
            _interruptor(
              '¿Las personas cambian de equipo según cuánto vienen?',
              _cambiosEquipo,
              (v) => _cambiosEquipo = v,
              'Cada mes se revisa y un Pivot aprueba los cambios.',
            )
          else
            Text('Con un solo equipo no hay cambios de equipo. Si agregas más, lo activas en Liga → Ajustes.', style: TextStyle(color: p.textoSecundario)),
        ];
      case _Paso.roles:
        return [
          _titulo('Roles del equipo', 'Cada persona elige los suyos en su perfil. Agrega, cambia o quita los que quieras.'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Coach es fijo: no se borra (Victor, 2026-11-17).
              for (final r in _roles)
                r == 'Coach'
                    ? const InputChip(label: Text('Coach'), avatar: Icon(Icons.lock_outline_rounded, size: 16), onPressed: null)
                    : InputChip(label: Text(r), onDeleted: () => setState(() => _roles.remove(r))),
              ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: const Text('Agregar'), onPressed: _nuevoRol),
            ],
          ),
        ];
      case _Paso.premios:
        return [
          _titulo('Premios', 'Pequeños empujones para que la gente pague y venga.'),
          if (_cobra)
            _interruptor('Premiar a quien paga a tiempo', _premios, (v) => _premios = v, 'Recibe un punto extra al pagar antes de la fecha límite.')
          else
            Text(
              'Como no cobran cuota, no hay premio por pagar a tiempo. Las recompensas por asistencia se arman en Reglas.',
              style: TextStyle(color: p.textoSecundario),
            ),
        ];
      case _Paso.resumen:
        Widget fila(String t, String v, _Paso destino) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(v),
          trailing: const Icon(Icons.edit_outlined, size: 18),
          onTap: () => _ir(destino),
        );
        return [
          _titulo('Revisa tu liga', 'Toca cualquier punto para cambiarlo.'),
          fila(
            'Liga',
            [
              _nombre.text.trim(),
              _nombreDeporte(_deporte),
              [_ciudad.text.trim(), _paises[_pais]?.$1].where((x) => (x ?? '').isNotEmpty).join(', '),
            ].join(' · '),
            _Paso.basico,
          ),
          fila('Camino', _avanzado ? 'Paso a paso' : 'Rápido, con valores por defecto', _Paso.modo),
          if (_avanzado) ...[
            fila('Equipos', _equipos.map((e) => '${e['nombre']}${e['nuevxs'] == true ? ' (nuevxs)' : ''}').join(', '), _Paso.equipos),
            fila(
              'Cuota',
              !_cobra
                  ? 'Sin cuota mensual'
                  : '${_cuotaIgual || _equipos.length < 2 ? '$_monedaSimbolo ${_monto.text}' : 'Distinta por equipo'} · vence el $_vence${_recargo ? ' · recargo ${_recargoTipo == 'fijo' ? '$_monedaSimbolo ' : ''}${_recargoMonto.text}${_recargoTipo == 'porcentaje' ? ' %' : ''}' : ''}',
              _Paso.cuota,
            ),
            fila('Clases sueltas', _vendeClase ? '$_monedaSimbolo ${_precioClase.text} por clase' : 'No', _Paso.clase),
            fila('Medios de pago', _medios.isEmpty ? 'Los agregas después' : _medios.map((m) => '${m['nombre']}').join(', '), _Paso.medios),
            fila('Entrenamientos', _entrenamientos.isEmpty ? 'Los creas después en el calendario' : '${_entrenamientos.length} horarios', _Paso.entrenamientos),
            fila('Cambios de equipo', _cambiosEquipo ? 'Cada mes, aprobados por un Pivot' : 'No', _Paso.asistencia),
            fila('Roles', _roles.join(', '), _Paso.roles),
            fila('Premio por pagar a tiempo', _premios && _cobra ? 'Sí' : 'No', _Paso.premios),
          ],
        ];
      case _Paso.perfil:
        return [
          _titulo('Ahora tú', 'Así te verá tu liga. Quedarás como Pivot.'),
          TextField(
            controller: _usuario,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre de usuario', helperText: 'Con él entras a Pivot. Solo letras y espacios.'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _derby,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: _deporte == 'roller_derby' ? 'Nombre derby (opcional)' : 'Apodo (opcional)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _numero,
            decoration: const InputDecoration(labelText: 'Número (opcional)'),
          ),
          const SizedBox(height: 14),
          const Text('Pronombres', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final x in const ['Ella', 'Él', 'Elle'])
                FilterChip(
                  label: Text(x),
                  selected: _pronombres.contains(x),
                  onSelected: (v) => setState(() => v ? _pronombres.add(x) : _pronombres.remove(x)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Tus roles', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _roles)
                FilterChip(label: Text(r), selected: _misRoles.contains(r), onSelected: (v) => setState(() => v ? _misRoles.add(r) : _misRoles.remove(r))),
            ],
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cake_outlined),
            title: Text(_nacimiento == null ? 'Fecha de nacimiento' : '${_nacimiento!.day}/${_nacimiento!.month}/${_nacimiento!.year}'),
            subtitle: const Text('Pivot es para mayores de 18 años.'),
            onTap: () async {
              final hoy = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: _nacimiento ?? DateTime(hoy.year - 25),
                firstDate: DateTime(1920),
                lastDate: DateTime(hoy.year - 18, hoy.month, hoy.day),
              );
              if (d != null) setState(() => _nacimiento = d);
            },
          ),
        ];
    }
  }

  Future<void> _nuevoMedio(String tipo, String etiqueta) async {
    final nombre = TextEditingController(text: tipo == 'efectivo' ? 'Efectivo' : '');
    final enlace = TextEditingController();
    final ok = await abrirFormulario<bool>(context, builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(c).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombre,
              autofocus: true,
              decoration: InputDecoration(labelText: tipo == 'transferencia' ? 'Banco o cuenta' : 'Nombre', hintText: etiqueta),
            ),
            if (tipo == 'enlace') ...[
              const SizedBox(height: 10),
              TextField(
                controller: enlace,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Enlace'),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Agregar')),
            ),
          ],
        ),
      ),
    );
    if (ok == true && nombre.text.trim().isNotEmpty) {
      setState(() => _medios.add({'tipo': tipo, 'nombre': nombre.text.trim(), 'enlace': enlace.text.trim()}));
    }
  }

  Future<void> _nuevoEntrenamiento() async {
    final dias = <String>{};
    var inicia = const TimeOfDay(hour: 19, minute: 0);
    var finaliza = const TimeOfDay(hour: 21, minute: 0);
    final lugar = TextEditingController();
    String h(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final ok = await abrirFormulario<bool>(context, builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(c).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Días', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in _dias)
                    FilterChip(label: Text(d.substring(0, 3)), selected: dias.contains(d), onSelected: (v) => set(() => v ? dias.add(d) : dias.remove(d))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await elegirHora(c, inicial: inicia, titulo: 'Empieza');
                        if (t != null) set(() => inicia = t);
                      },
                      child: Text('Empieza ${h(inicia)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final t = await elegirHora(c, inicial: finaliza, titulo: 'Termina');
                        if (t != null) set(() => finaliza = t);
                      },
                      child: Text('Termina ${h(finaliza)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lugar,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Lugar'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: dias.isEmpty ? null : () => Navigator.of(c).pop(true), child: const Text('Agregar')),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && dias.isNotEmpty) {
      setState(
        () => _entrenamientos.add({
          'dias': [
            for (final d in _dias)
              if (dias.contains(d)) d,
          ],
          'inicia': h(inicia),
          'finaliza': h(finaliza),
          'lugar': lugar.text.trim().isEmpty ? 'Por definir' : lugar.text.trim(),
        }),
      );
    }
  }

  Future<void> _nuevoRol() async {
    final c = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        scrollable: true,
        title: const Text('Nuevo rol'),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(d).pop(c.text.trim()), child: const Text('Agregar')),
        ],
      ),
    );
    if (r != null && r.isNotEmpty && !_roles.contains(r)) setState(() => _roles.add(r));
  }
}

/// Bienvenida como Pivot, después de crear la liga.
class _BienvenidaPivot extends StatefulWidget {
  const _BienvenidaPivot({required this.liga, required this.rapido});
  final String liga;
  final bool rapido;
  @override
  State<_BienvenidaPivot> createState() => _BienvenidaPivotState();
}

class _BienvenidaPivotState extends State<_BienvenidaPivot> {
  final _pag = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final tarjetas = <(IconData, String, String)>[
      (Icons.celebration_rounded, '¡${widget.liga} ya está en Pivot!', 'Eres su Pivot: quien organiza la liga en la app, con todos los permisos.'),
      (
        Icons.settings_rounded,
        'Todo se cambia en Liga → Ajustes',
        'En Liga → Ajustes, con el ícono del engranaje, están las cuotas, las reglas y los datos de la liga; los equipos, coaches y Pivots están en Liga → Equipos.',
      ),
      (Icons.qr_code_2_rounded, 'Invita a tu gente', 'En Liga → Equipos, con «Gestionar» en cada equipo, tienes el enlace y el código QR de inscripción de cada equipo para compartirlo.'),
      (
        Icons.group_add_rounded,
        'No lo hagas sin ayuda',
        'Suma más Pivots en Liga → Equipos → Pivots, y reparte las áreas: finanzas, asistencia, equipamiento…',
      ),
    ];
    final ultima = _i == tarjetas.length - 1;
    return Scaffold(
      body: FondoDinamico(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pag,
                  onPageChanged: (i) => setState(() => _i = i),
                  children: [
                    for (final t in tarjetas)
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(t.$1, size: 72, color: p.marcaTexto),
                            const SizedBox(height: 22),
                            Text(
                              t.$2,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.texto),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t.$3,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, height: 1.45, color: p.textoSecundario),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < tarjetas.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      width: i == _i ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(color: i == _i ? p.marca : p.apagadoFondo, borderRadius: BorderRadius.circular(PivotRadios.chip)),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => ultima
                      ? Navigator.of(context).popUntil((r) => r.isFirst)
                      : _pag.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic),
                  child: Text(ultima ? 'Entrar a mi liga' : 'Siguiente'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
