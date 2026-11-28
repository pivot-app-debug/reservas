import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/fechas.dart';
import '../core/tema.dart';
import '../eventos/eventos_repo.dart';
import 'reservas_repo.dart';

/// Elige la captura del pago y la sube a esas reservas (Victor, 2026-11-14).
/// Devuelve true si se subió. La copia temporal que deja el selector se
/// borra enseguida: los comprobantes no se guardan en el teléfono.
Future<bool> subirComprobante(BuildContext context, ReservasRepo repo, List<String> ids) async {
  final m = ScaffoldMessenger.of(context);
  final XFile? x;
  try {
    x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 72, maxWidth: 1600, maxHeight: 2400);
  } catch (_) {
    m.showSnackBar(const SnackBar(content: Text('No pudimos abrir tus fotos. Revisa los permisos de la app.')));
    return false;
  }
  if (x == null) return false;
  m.showSnackBar(const SnackBar(content: Text('Subiendo el comprobante…'), duration: Duration(seconds: 20)));
  try {
    final bytes = await x.readAsBytes();
    await repo.subirComprobante(ids, bytes);
    m.hideCurrentSnackBar();
    m.showSnackBar(const SnackBar(content: Text('¡Listo! Un Pivot revisará tu pago.')));
    return true;
  } catch (e) {
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo subir. Revisa tu conexión e intenta de nuevo.')));
    return false;
  } finally {
    if (!kIsWeb) {
      try {
        await File(x.path).delete();
      } catch (_) {}
    }
  }
}

/// Elige la captura del pago sin subirla todavía (Victor, 2026-11-27): la
/// suscripción con transferencia o billetera no se crea sin la foto.
Future<List<int>?> elegirFotoPago(BuildContext context) async {
  final m = ScaffoldMessenger.of(context);
  final XFile? x;
  try {
    x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 72, maxWidth: 1600, maxHeight: 2400);
  } catch (_) {
    m.showSnackBar(const SnackBar(content: Text('No pudimos abrir tus fotos. Revisa los permisos de la app.')));
    return null;
  }
  if (x == null) return null;
  try {
    return await x.readAsBytes();
  } finally {
    if (!kIsWeb) {
      try {
        await File(x.path).delete();
      } catch (_) {}
    }
  }
}

/// Reserva o suscripción pendiente sin comprobante (Victor, 2026-11-19): si un
/// Pivot lo pidió, muestra "Esperando comprobante" con el plazo de 24 h; en
/// cualquier caso, el botón para adjuntarlo desde la pantalla de pagos.
class ComprobanteFaltante extends StatelessWidget {
  const ComprobanteFaltante({super.key, required this.r, required this.repo, required this.alSubir});
  final ReservaActiva r;
  final ReservasRepo repo;
  final VoidCallback alSubir;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final fin = r.comprobanteLimite;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: !r.faltaComprobante || r.id.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fin != null)
                    Text(
                      'Esperando comprobante: adjúntalo antes del ${Fechas.corta(fin)} a las ${Fechas.hora(fin)}; si no, la solicitud se descarta y tendrás que volver a ${r.mensual ? 'suscribirte' : 'reservar'}.',
                      style: TextStyle(fontSize: 13, color: p.marcaTexto),
                    ),
                  const SizedBox(height: 4),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      if (await subirComprobante(context, repo, [r.id])) alSubir();
                    },
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: const Text('Adjuntar comprobante'),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Insistir con el comprobante (Victor, 2026-11-28): cada vez que se abre la
/// app, si hay un pago sin comprobante, se avisa que sin él no se aprueba.
Future<void> recordarComprobante(BuildContext context, EventosRepo eventos) async {
  if (eventos.cuota == null) {
    try {
      await eventos.recargarCuota();
    } catch (_) {
      return;
    }
  }
  final c = eventos.cuota;
  if (c == null || !context.mounted) return;
  final faltan = ReservasRepo.activas(c).where((r) => r.faltaComprobante && r.id.isNotEmpty).toList();
  if (faltan.isEmpty) return;
  final p = context.pivot;
  final si = await showModalBottomSheet<bool>(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    builder: (h) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.receipt_long_outlined, size: 40, color: p.marcaTexto),
            const SizedBox(height: 10),
            Text(
              faltan.length == 1 ? 'Falta tu comprobante' : 'Faltan ${faltan.length} comprobantes',
              textAlign: TextAlign.center,
              style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${faltan.map((r) => r.titulo).join(' · ')}. Si no adjuntas la captura del pago, tu pago no se aprobará.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.4, color: p.texto),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.of(h).pop(true),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Adjuntar comprobante'),
            ),
            TextButton(onPressed: () => Navigator.of(h).pop(false), child: const Text('Más tarde')),
          ],
        ),
      ),
    ),
  );
  if (si != true || !context.mounted) return;
  if (await subirComprobante(context, ReservasRepo(eventos.sesion), [for (final r in faltan) r.id])) {
    await eventos.recargarCuota();
  }
}
