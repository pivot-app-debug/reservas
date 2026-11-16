import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'instalar_web.dart';
import 'tema.dart';

/// Versión web en teléfonos (Victor, 2026-11-16, igual que la web vieja):
/// hay que instalar Pivot en la pantalla de inicio para usarla y recibir
/// avisos. Android con Chrome, iPhone con Safari; otro navegador recibe el
/// enlace para abrirlo en el correcto. En computadora no aparece.
class PuertaInstalar extends StatefulWidget {
  const PuertaInstalar({super.key, required this.child});
  final Widget child;

  @override
  State<PuertaInstalar> createState() => _PuertaInstalarState();
}

class _PuertaInstalarState extends State<PuertaInstalar> {
  late final bool _mostrar = kIsWeb && plataformaWeb() != PlataformaWeb.escritorio && !esAppInstalada();
  Timer? _reloj;
  int _ticks = 0;
  bool _directo = false, _instalada = false, _copiado = false;

  @override
  void initState() {
    super.initState();
    if (!_mostrar) return;
    // Chrome avisa en unos segundos si se puede instalar con un toque.
    _reloj = Timer.periodic(const Duration(milliseconds: 500), (t) {
      final d = puedeInstalarDirecto(), r = recienInstalada();
      if (d != _directo || r != _instalada) setState(() => (_directo = d, _instalada = r));
      if (++_ticks > 20 && !_directo) t.cancel();
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _instalar() async {
    final ok = await instalarDirecto();
    if (mounted) setState(() => (_directo = false, _instalada = ok));
  }

  @override
  Widget build(BuildContext context) {
    if (!_mostrar) return widget.child;
    final p = context.pivot;
    final ios = plataformaWeb() == PlataformaWeb.ios;
    final compatible = navegadorCompatible();
    final List<(IconData, String)> pasos;
    String titulo = 'Instala la app', texto = 'Para usar Pivot y recibir avisos, instálala en tu pantalla de inicio. Es gratis y no ocupa casi espacio.';
    if (_instalada) {
      titulo = '¡Listo!';
      texto = 'Pivot ya está en tu pantalla de inicio. Cierra esta ventana y ábrela desde ahí.';
      pasos = const [];
    } else if (!compatible) {
      titulo = ios ? 'Abre Pivot en Safari' : 'Abre Pivot en Chrome';
      texto = ios
          ? 'En iPhone y iPad, Pivot se instala desde Safari. Este navegador no lo permite.'
          : 'En Android, Pivot se instala desde Google Chrome. Este navegador no lo permite.';
      pasos = [
        (Icons.content_copy_rounded, 'Copia el enlace con el botón de abajo'),
        (ios ? Icons.explore_outlined : Icons.open_in_browser_rounded, ios ? 'Abre Safari y pega el enlace' : 'Abre Chrome y pega el enlace'),
        (Icons.add_to_home_screen_rounded, 'Sigue los pasos para instalarla'),
      ];
    } else if (ios) {
      pasos = const [
        (Icons.ios_share_rounded, 'Toca el botón Compartir de Safari (el cuadro con la flecha ↑)'),
        (Icons.add_box_outlined, 'Elige "Agregar a inicio" (o "Agregar a pantalla de inicio")'),
        (Icons.check_circle_outline_rounded, 'Toca "Agregar" y abre Pivot desde tu pantalla de inicio'),
      ];
    } else {
      pasos = const [
        (Icons.more_vert_rounded, 'Toca el menú ⋮ de Chrome (arriba a la derecha)'),
        (Icons.add_to_home_screen_rounded, 'Elige "Instalar app" o "Agregar a la pantalla principal"'),
        (Icons.check_circle_outline_rounded, 'Confirma y abre Pivot desde tu pantalla de inicio'),
      ];
    }
    return Material(
      color: p.fondo,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 84,
                      height: 84,
                      errorBuilder: (_, _, _) => Icon(Icons.install_mobile_rounded, size: 64, color: p.marcaTexto),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.texto),
                ),
                const SizedBox(height: 8),
                Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.4, color: p.textoSecundario),
                ),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _directo && compatible && !_instalada
                      ? FilledButton.icon(
                          key: const ValueKey('d'),
                          onPressed: _instalar,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Instalar app'),
                        )
                      : Column(
                          key: const ValueKey('p'),
                          children: [
                            for (final (i, (icono, t)) in pasos.indexed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color: p.tarjeta,
                                  borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: p.suave,
                                          child: Text(
                                            '${i + 1}',
                                            style: TextStyle(fontWeight: FontWeight.w800, color: p.sobreSuave),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(icono, color: p.textoSecundario),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(t, style: TextStyle(height: 1.35, color: p.texto)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                if (!compatible && !_instalada) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: direccionActual()));
                      if (mounted) setState(() => _copiado = true);
                    },
                    icon: Icon(_copiado ? Icons.check_rounded : Icons.content_copy_rounded),
                    label: Text(_copiado ? 'Enlace copiado' : 'Copiar enlace'),
                  ),
                ],
                if (compatible && !_instalada) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Si ya la instalaste, ábrela desde tu pantalla de inicio. Al abrirla, activa los avisos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: p.textoSecundario),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
