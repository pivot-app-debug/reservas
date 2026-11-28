import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/fechas.dart';
import '../core/tema.dart';
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
