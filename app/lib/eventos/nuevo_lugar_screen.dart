import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';

import '../core/asistente.dart';
import '../core/selector_ubicacion.dart';
import 'eventos_repo.dart';

enum _Paso { nombre, ubicacion, video }

/// "Agregar un lugar", con el mismo marco que el resto de los asistentes.
/// Nombre → ubicación en el mapa (opcional: se puede agregar después) → video
/// instructivo (solo al guardarlo en la lista de la liga). Sin tipo de evento
/// (Victor, 2026-11-20): un lugar sirve para cualquier evento.
/// Con [guardar] en false (Social o fiesta) no se guarda en la lista: devuelve
/// `{lugar, google_maps}` y el lugar se crea junto con el evento.
class NuevoLugarScreen extends StatefulWidget {
  const NuevoLugarScreen({super.key, required this.repo, this.guardar = true});
  final EventosRepo repo;
  final bool guardar;

  @override
  State<NuevoLugarScreen> createState() => _NuevoLugarScreenState();
}

class _NuevoLugarScreenState extends State<NuevoLugarScreen> {
  _Paso _paso = _Paso.nombre;
  bool _adelante = true;
  final _nombre = TextEditingController();
  LatLng? _pin;
  final _video = TextEditingController();
  bool _guardando = false;

  List<_Paso> get _pasos => [_Paso.nombre, _Paso.ubicacion, if (widget.guardar) _Paso.video];

  @override
  void dispose() {
    _nombre.dispose();
    _video.dispose();
    super.dispose();
  }

  bool get _valido => switch (_paso) {
    _Paso.nombre => _nombre.text.trim().isNotEmpty,
    _Paso.ubicacion => true,
    _Paso.video => _video.text.trim().isEmpty || Uri.tryParse(_video.text.trim())?.hasScheme == true,
  };

  void _ir(int delta) {
    final i = _pasos.indexOf(_paso) + delta;
    if (i < 0) {
      Navigator.of(context).pop();
      return;
    }
    if (i >= _pasos.length) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _adelante = delta > 0;
      _paso = _pasos[i];
    });
  }

  String get _mapa => _pin == null ? '' : SelectorUbicacion.enlaceGoogleMaps(_pin!);

  Future<void> _guardar() async {
    if (!widget.guardar) {
      Navigator.of(context).pop(<String, dynamic>{'lugar': _nombre.text.trim(), 'google_maps': _mapa});
      return;
    }
    setState(() => _guardando = true);
    try {
      final fila = await widget.repo.crearLugar(nombre: _nombre.text, mapsUrl: _mapa, video: _video.text);
      if (mounted) Navigator.of(context).pop(fila);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear el lugar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ultimo = _paso == _pasos.last;
    return Asistente(
      titulo: 'Nuevo lugar',
      indice: _pasos.indexOf(_paso),
      total: _pasos.length,
      tituloPaso: switch (_paso) {
        _Paso.nombre => '¿Cómo se llama?',
        _Paso.ubicacion => '¿Dónde queda?',
        _Paso.video => 'Video para llegar',
      },
      ayuda: switch (_paso) {
        _Paso.nombre => 'Como lo conoce la liga. Ej.: Cumandá, Casa de Ana.',
        _Paso.ubicacion => 'Opcional. Búscalo o mueve el mapa hasta dejar el pin. Si ahora no la tienes, sigue sin ubicación y agrégala después.',
        _Paso.video => 'Opcional: un video de cómo llegar o entrar.',
      },
      clavePaso: _paso,
      adelante: _adelante,
      alAtras: () => _ir(-1),
      cuerpo: switch (_paso) {
        _Paso.nombre => _pasoNombre(context),
        _Paso.ubicacion => _pasoUbicacion(context),
        _Paso.video => _pasoVideo(context),
      },
      textoBoton: _paso == _Paso.ubicacion && _pin == null
          ? 'Seguir sin ubicación'
          : ultimo
          ? (widget.guardar ? 'Crear lugar' : 'Usar este lugar')
          : 'Siguiente',
      alContinuar: !_valido ? null : (ultimo ? _guardar : () => _ir(1)),
      ocupado: _guardando,
    );
  }

  Widget _pasoNombre(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nombre,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre del lugar', counterText: ''),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _valido ? _ir(1) : null,
        ),
      ],
    );
  }

  Widget _pasoUbicacion(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SelectorUbicacion(inicial: _pin, consultaInicial: _nombre.text.trim(), alCambiar: (p) => setState(() => _pin = p)),
    );
  }

  Widget _pasoVideo(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _video,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Enlace del video (opcional)', hintText: 'https://…'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
