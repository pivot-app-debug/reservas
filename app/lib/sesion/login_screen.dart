import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../liga/crear_liga_screen.dart';
import '../core/api.dart';
import 'boton_google.dart';
import '../core/fondo_dinamico.dart';
import '../core/iconos_marca.dart';
import '../core/tema.dart';
import 'sesion.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.sesion});
  final Sesion sesion;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _ocupado = false;
  bool _modoPin = false;
  String? _error;
  final _identificador = TextEditingController();
  final _pin = TextEditingController();

  // Correo (preparado, Victor 2026-11-13): solo aparece si el servidor lo activa.
  bool _correoActivo = false;
  String _modoCorreo = ''; // '' | 'correo' | 'codigo' | 'nueva'
  String? _registroToken;
  final _correo = TextEditingController();
  final _codigo = TextEditingController();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();

  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleWeb;
  bool _googleWebListo = false;

  @override
  void initState() {
    super.initState();
    widget.sesion.loginCorreoActivo().then((v) {
      if (mounted && v) setState(() => _correoActivo = true);
    });
    if (kIsWeb) _prepararGoogleWeb();
  }

  Future<void> _prepararGoogleWeb() async {
    try {
      final eventos = await widget.sesion.prepararGoogleWeb();
      _googleWeb = eventos.listen(
        (e) {
          if (e is! GoogleSignInAuthenticationEventSignIn) return;
          // El asistente de crear liga está esperando esta cuenta.
          final c = Sesion.capturaGoogle;
          if (c != null) return c(e.user);
          _ejecutar(() => widget.sesion.conCuentaGoogle(e.user));
        },
        onError: (Object _) {
          if (mounted) setState(() => _error = 'No se pudo iniciar sesión con Google.');
        },
      );
      if (mounted) setState(() => _googleWebListo = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Google no está disponible. Entra con usuario y contraseña.');
    }
  }

  @override
  void dispose() {
    for (final c in [_identificador, _pin, _correo, _codigo, _nombre, _telefono]) {
      c.dispose();
    }
    _googleWeb?.cancel();
    super.dispose();
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await accion();
    } on LoginFallido catch (e) {
      if (mounted && e.mensaje.isNotEmpty) setState(() => _error = e.mensaje);
    } on ApiException catch (e) {
      // El servidor respondió con un error (por ejemplo "Código incorrecto o
      // vencido."): se muestra tal cual, no como falta de conexión.
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: FondoDinamico(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ClipRRect(borderRadius: BorderRadius.circular(PivotRadios.grande), child: Image.asset('assets/logo.png', width: 88, height: 88)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Inicia sesión o crea una cuenta',
                      textAlign: TextAlign.center,
                      style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 32),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _modoCorreo.isNotEmpty ? _formCorreo() : (_modoPin ? _formPin(t) : _botonesInicio()),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _error == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: t.bodyMedium?.copyWith(color: context.pivot.marcaTexto),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Inicio (QA 2026-11-18): todos los botones del mismo ancho, en orden:
  /// Google, correo o usuario y, al final, crear la liga.
  Widget _botonesInicio() {
    return Column(
      key: const ValueKey('inicio'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kIsWeb)
          // Web: el botón oficial de Google (no se puede abrir desde uno
          // propio), con el mismo ancho que los demás.
          LayoutBuilder(
            builder: (context, c) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _googleWebListo && !_ocupado
                  ? Center(child: botonGoogleWeb(ancho: c.maxWidth))
                  : const SizedBox(height: 52, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5))),
            ),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _ocupado ? null : () => _ejecutar(widget.sesion.conGoogle),
            icon: _ocupado ? null : Icon(IconosMarca.google, size: 18),
            label: _ocupado
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: context.pivot.sobreMarca))
                : const Text('Continuar con Google'),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _ocupado ? null : () => setState(() => _modoPin = true),
          child: const Text('Iniciar sesión con correo o nombre de usuario', textAlign: TextAlign.center),
        ),
        const SizedBox(height: 28),
        // Crear una liga (Victor, 2026-11-17).
        Text(
          '¿Tu liga todavía no está en Pivot?',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pivot.textoSecundario),
        ),
        TextButton.icon(
          onPressed: _ocupado ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CrearLigaScreen(sesion: widget.sesion))),
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('Crea tu liga'),
        ),
      ],
    );
  }

  Widget _formCorreo() {
    final boton = _ocupado
        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: context.pivot.sobreMarca))
        : Text(switch (_modoCorreo) {
            'correo' => 'Enviarme un código',
            'codigo' => 'Entrar',
            _ => 'Crear cuenta',
          });
    return Column(
      key: ValueKey('correo-$_modoCorreo'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_modoCorreo == 'correo')
          TextField(
            controller: _correo,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Tu correo', border: OutlineInputBorder()),
            onSubmitted: (_) => _siguienteCorreo(),
          ),
        if (_modoCorreo == 'codigo') ...[
          Text('Te enviamos un código a ${_correo.text.trim()}.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextField(
            controller: _codigo,
            autofocus: true,
            keyboardType: TextInputType.number,
            // El largo del código lo define Supabase (hoy 8 dígitos).
            maxLength: 10,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 4, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
            onSubmitted: (_) => _siguienteCorreo(),
          ),
        ],
        if (_modoCorreo == 'nueva') ...[
          const Text('Ese correo no tiene cuenta. Créala en un paso:', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Tu nombre', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Tu teléfono', prefixText: '+593 ', border: OutlineInputBorder()),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _ocupado ? null : _siguienteCorreo,
          child: boton,
        ),
        TextButton(
          onPressed: _ocupado
              ? null
              : () => setState(() {
                  _modoCorreo = _modoCorreo == 'correo' ? '' : 'correo';
                  _error = null;
                }),
          child: const Text('Volver'),
        ),
      ],
    );
  }

  void _siguienteCorreo() {
    final s = widget.sesion;
    switch (_modoCorreo) {
      case 'correo':
        if (!_correo.text.contains('@')) {
          setState(() => _error = 'Escribe tu correo.');
          return;
        }
        _ejecutar(() async {
          await s.enviarCodigoCorreo(_correo.text);
          if (mounted) setState(() => _modoCorreo = 'codigo');
        });
      case 'codigo':
        _ejecutar(() async {
          final t = await s.verificarCodigoCorreo(_correo.text, _codigo.text);
          if (t != null && mounted) {
            setState(() {
              _registroToken = t;
              _modoCorreo = 'nueva';
            });
          }
        });
      default:
        if (_nombre.text.trim().isEmpty || _telefono.text.trim().isEmpty) {
          setState(() => _error = 'Escribe tu nombre y tu teléfono.');
          return;
        }
        _ejecutar(
          () => s.crearCuentaCorreo(email: _correo.text, registroToken: _registroToken ?? '', nombre: _nombre.text, prefijo: '593', telefono: _telefono.text),
        );
    }
  }

  Widget _formPin(TextTheme t) {
    return Column(
      key: const ValueKey('pin'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _identificador,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Tu nombre de usuario o correo', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Contraseña o PIN', border: OutlineInputBorder()),
          onSubmitted: (_) => _entrarConPin(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _ocupado ? null : _entrarConPin,
          child: _ocupado
              ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: context.pivot.sobreMarca))
              : const Text('Entrar'),
        ),
        // Código por correo (solo si el servidor lo activa): vive aquí para que
        // el inicio tenga dos botones parejos (QA 2026-11-18).
        if (_correoActivo)
          TextButton(
            onPressed: _ocupado
                ? null
                : () => setState(() {
                    _modoPin = false;
                    _modoCorreo = 'correo';
                    _error = null;
                  }),
            child: const Text('Entrar o crear cuenta con un código por correo', textAlign: TextAlign.center),
          ),
        TextButton(onPressed: _ocupado ? null : () => setState(() => _modoPin = false), child: const Text('Volver')),
      ],
    );
  }

  void _entrarConPin() {
    if (_identificador.text.trim().isEmpty || _pin.text.isEmpty) {
      setState(() => _error = 'Escribe tu usuario y tu contraseña o PIN.');
      return;
    }
    _ejecutar(() => widget.sesion.conPin(_identificador.text, _pin.text));
  }
}
