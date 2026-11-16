import 'package:flutter/material.dart';

import '../ajustes/componentes.dart';
import '../core/config_liga.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../pivots/buscador_liga.dart';
import '../pivots/editores_liga.dart';
import '../pivots/formas_pago_screen.dart';
import '../pivots/vencimiento_screen.dart';
import '../sesion/sesion.dart';
import 'planes_screen.dart';
import '../cursos/cursos_screen.dart';

/// Tesorería → Cobros (Victor, 2026-11-14): todo lo que se cobra en un solo
/// lugar. Cada modalidad dice a quién aplica (hoy fijo, como en la web; se
/// podrá cambiar con el asistente de reglas).
class CobrosScreen extends StatefulWidget {
  const CobrosScreen({super.key, required this.sesion, this.resaltar});
  final Sesion sesion;
  final String? resaltar;

  @override
  State<CobrosScreen> createState() => _CobrosScreenState();
}

class _CobrosScreenState extends State<CobrosScreen> {
  final _resaltado = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    final x = widget.resaltar;
    if (x != null) WidgetsBinding.instance.addPostFrameCallback((_) => _resaltado.value = x);
  }

  @override
  void dispose() {
    _resaltado.dispose();
    super.dispose();
  }

  Widget _modalidad(BuildContext context, String id, String nombre, num? precio, String aQuien, VoidCallback editar) {
    final p = context.pivot;
    return Resaltable(
      id: id,
      resaltado: _resaltado,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: p.tarjeta,
          borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
          child: InkWell(
            borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
            onTap: editar,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nombre,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.texto),
                        ),
                      ),
                      Text(
                        plataLiga(precio),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: p.texto),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(aQuien, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                  const SizedBox(height: 8),
                  Text(
                    'Toca para cambiar el precio',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.marcaTexto),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final c = ConfigLiga.de(widget.sesion);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: const Text('Cobros', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 40),
          children: [
            Text(
              'Qué se cobra, cuánto y por dónde. Cambiar un precio rige para los pagos nuevos; los ya hechos no cambian.',
              style: TextStyle(fontSize: 14, height: 1.4, color: p.texto),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                'MODALIDADES',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.textoSecundario),
              ),
            ),
            _modalidad(
              context,
              'mensualidad',
              'Mensualidad',
              c.precioMensual,
              'Quindes, y Mirlxs con equipamiento propio que eligen pagar por mes.',
              () => precioLiga(context, c, 'Mensualidad', c.precioMensual, 'precioMensual'),
            ),
            _modalidad(
              context,
              'clase',
              'Valor por clase',
              c.precioPorClase,
              'Mirlxs sin equipamiento propio, y Mirlxs con equipamiento propio que eligen pagar por clase.',
              () => precioLiga(context, c, 'Valor por clase', c.precioPorClase, 'precioPorClase'),
            ),
            const SizedBox(height: 8),
            GrupoAjustes(
              titulo: 'Cómo y hasta cuándo',
              filas: [
                Resaltable(
                  id: 'formas',
                  resaltado: _resaltado,
                  child: FilaAjuste(
                    icono: Icons.credit_card_rounded,
                    seccion: 'cuota',
                    titulo: 'Formas de pago',
                    valor: c.mediosActivos.isEmpty ? 'Sin medios de pago' : c.mediosActivos.map((m) => m.nombre).join(' · '),
                    alTocar: () => SubAjustes.abrir(context, FormasPagoScreen(config: c)),
                  ),
                ),
                Resaltable(
                  id: 'planes',
                  resaltado: _resaltado,
                  child: FilaAjuste(
                    icono: Icons.inventory_outlined,
                    seccion: 'cuota',
                    titulo: 'Planes de pago',
                    valor: 'Paquetes de meses o clases con precio propio',
                    alTocar: () => SubAjustes.abrir(context, PlanesScreen(sesion: widget.sesion)),
                  ),
                ),
                FilaAjuste(
                  icono: Icons.school_outlined,
                  seccion: 'cuota',
                  titulo: 'Cursos',
                  valor: 'Freshmeat con try out, con precio y cupo propios',
                  alTocar: () => SubAjustes.abrir(context, CursosScreen(sesion: widget.sesion)),
                ),
                Resaltable(
                  id: 'vencimiento',
                  resaltado: _resaltado,
                  child: FilaAjuste(
                    icono: Icons.event_busy_outlined,
                    seccion: 'cuota',
                    titulo: 'Fecha límite de pago',
                    valor: textoVencimiento(c),
                    alTocar: () => SubAjustes.abrir(context, VencimientoScreen(config: c)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
