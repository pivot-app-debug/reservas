import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/fechas.dart';
import '../core/iconos_marca.dart';
import '../core/tema.dart';
import '../equipo/comunidad_screen.dart' show ComunidadRepo, EnlaceComunidad;
import '../equipo/equipo_repo.dart';
import 'deco_fiesta.dart';
import 'eventos_repo.dart';
import 'modelos.dart';
import 'widgets_comunes.dart';

/// Tarjeta de cumpleaños (timeline y Novedades). Por venir u hoy: tan
/// llamativa como el offseason; el confeti solo cae el mismo día. Ya pasó:
/// fondo apagado y el confeti quieto (Victor, 2026-11-22).
class TarjetaCumple extends StatelessWidget {
  const TarjetaCumple({super.key, required this.cumple});
  final Cumple cumple;

  @override
  Widget build(BuildContext context) {
    final hoy = Fechas.hoy();
    final dia = Fechas.soloDia(cumple.fecha);
    final pasado = dia.isBefore(hoy);
    if (pasado) return _construir(context, pasado: true);
    final (_, t, sec, _) = PivotPaleta.festivo('cumple');
    return Theme(
      data: Theme.of(context).copyWith(extensions: [context.pivot.sobreFestivo(t, sec)]),
      child: Builder(builder: (c) => _construir(c, pasado: false)),
    );
  }

  Widget _construir(BuildContext context, {required bool pasado}) {
    final p = context.pivot;
    final hoy = Fechas.hoy();
    final esHoy = Fechas.soloDia(cumple.fecha) == hoy;
    final anios = cumple.aniosEquipo;
    final titulo = anios != null ? 'Aniversario en el equipo' : 'Cumpleaños de ${cumple.nombre}';
    final detalle = anios == null ? textoCumple(cumple, hoy) : '${esHoy ? 'Hoy cumples' : 'Cumples'} $anios ${anios == 1 ? 'año' : 'años'} en el equipo';
    final (degradado, _, _, borde) = PivotPaleta.festivo('cumple');
    final sesion = EventosRepo.actual?.sesion;
    final esMio = sesion != null && sesion.nombreMostrar.toLowerCase() == cumple.nombre.toLowerCase();
    final contenido = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarPersona(nombre: cumple.nombre, foto: cumple.fotoPerfil, tamano: 44, borde: esHoy ? borde : null),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.texto),
                    ),
                    const SizedBox(height: 2),
                    Text(detalle, style: TextStyle(fontSize: 13, color: p.textoSecundario)),
                  ],
                ),
              ),
              Icon(anios != null ? Icons.celebration_rounded : Icons.cake_rounded, size: 22, color: p.marcaTexto),
            ],
          ),
          // Hoy: escribirle en el grupo de WhatsApp de la comunidad.
          if (esHoy && anios == null && !esMio && sesion != null) _MensajeGrupo(cumple: cumple),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        gradient: pasado
            ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.apagadoEtiqueta, p.recuerdoFondo], stops: const [0, 0.75])
            : degradado,
        border: esHoy ? Border.all(color: borde, width: 2) : null,
        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Sin confeti si todavía no es el día.
          if (esHoy || pasado)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoFiesta(clave: 'cumple', animada: esHoy, fuerte: !pasado),
              ),
            ),
          contenido,
        ],
      ),
    );
  }
}

/// "Mándale un mensaje en el grupo": solo si la comunidad usa WhatsApp. Con
/// varios grupos, pregunta a cuál.
class _MensajeGrupo extends StatefulWidget {
  const _MensajeGrupo({required this.cumple});
  final Cumple cumple;

  @override
  State<_MensajeGrupo> createState() => _MensajeGrupoState();
}

class _MensajeGrupoState extends State<_MensajeGrupo> {
  ComunidadRepo? get _repo {
    final s = EventosRepo.actual?.sesion;
    return s == null ? null : ComunidadRepo.de(s);
  }

  @override
  void initState() {
    super.initState();
    final r = _repo;
    if (r != null && !r.cargado) r.cargar();
  }

  Future<void> _enviar(List<EnlaceComunidad> grupos) async {
    var elegido = grupos.length == 1 ? grupos.first : null;
    if (elegido == null) {
      final s = EventosRepo.actual?.sesion;
      final persona = s == null
          ? null
          : EquipoRepo.de(s).personas?.where((x) => x.nombreMostrar.toLowerCase() == widget.cumple.nombre.toLowerCase()).firstOrNull;
      final quien = widget.cumple.nombre;
      elegido = await showModalBottomSheet<EnlaceComunidad>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        builder: (h) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  persona == null
                      ? '¿En qué grupo de WhatsApp quieres escribirle a $quien?'
                      : '$quien está en ${persona.categoria}. ¿En qué grupo de WhatsApp quieres escribirle?',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              for (final g in grupos)
                ListTile(
                  leading: Icon(IconosMarca.whatsapp),
                  title: Text(g.nombre.isEmpty ? 'Grupo de WhatsApp' : g.nombre),
                  onTap: () => Navigator.of(h).pop(g),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }
    if (elegido == null || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    // WhatsApp no deja escribir en un grupo desde un enlace: el saludo queda copiado.
    await Clipboard.setData(ClipboardData(text: '¡Feliz cumpleaños, ${widget.cumple.nombre}! 🎉'));
    m.showSnackBar(const SnackBar(content: Text('Copiamos un saludo para que lo pegues en el grupo.')));
    await launchUrl(Uri.parse(elegido.url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final r = _repo;
    if (r == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: r,
      builder: (context, _) {
        final grupos = r.enlaces.where((e) => e.red == 'whatsapp' && e.url.isNotEmpty).toList();
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: grupos.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      backgroundColor: context.pivot.suave,
                      foregroundColor: context.pivot.sobreSuave,
                    ),
                    onPressed: () => _enviar(grupos),
                    icon: Icon(IconosMarca.whatsapp, size: 18),
                    label: const Text('Mándale un mensaje en el grupo'),
                  ),
                ),
        );
      },
    );
  }
}

/// Fondo festivo con su decoración y el texto claro encima (Novedades usa el
/// mismo diseño que el timeline, Victor 2026-11-22).
class FondoFestivo extends StatelessWidget {
  const FondoFestivo({super.key, required this.clave, required this.child, this.animada = true});
  final String clave;
  final bool animada;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final (degradado, t, sec, _) = PivotPaleta.festivo(clave);
    return Container(
      decoration: BoxDecoration(gradient: degradado, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(extensions: [context.pivot.sobreFestivo(t, sec)]),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoFiesta(clave: clave, animada: animada, fuerte: true),
              ),
            ),
            Material(type: MaterialType.transparency, child: child),
          ],
        ),
      ),
    );
  }
}
