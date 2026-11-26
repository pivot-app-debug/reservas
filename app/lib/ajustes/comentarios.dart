import 'package:flutter/material.dart';

import 'componentes.dart' show abrirFormulario;
import 'package:url_launcher/url_launcher.dart';

import '../core/tema.dart';

/// Enviar comentarios (web "Feedback"): un error, una sugerencia u otra cosa,
/// por WhatsApp o por correo al equipo que mantiene la app.
Future<void> enviarComentarios(BuildContext context) async {
  const whatsapp = '593962773052', correo = 'quindesvolcanicosrd@gmail.com';
  var tipo = 'Sugerencia';
  final texto = TextEditingController();
  await abrirFormulario<void>(context, builder: (h) => StatefulBuilder(
      builder: (h, set) {
        final p = h.pivot;
        final listo = texto.text.trim().isNotEmpty;
        final mensaje = '[$tipo] ${texto.text.trim()}';
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(h).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Enviar comentarios', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('¿Algo no funciona o tienes una idea? Cuéntanos.', style: TextStyle(color: p.textoSecundario)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (t, i) in const [
                      ('Error', Icons.bug_report_outlined),
                      ('Sugerencia', Icons.lightbulb_outline_rounded),
                      ('Otro', Icons.chat_bubble_outline_rounded),
                    ])
                      ChoiceChip(showCheckmark: false, avatar: Icon(i, size: 18), label: Text(t), selected: tipo == t, onSelected: (_) => set(() => tipo = t)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: texto,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => set(() {}),
                  decoration: const InputDecoration(hintText: 'Escribe aquí. Si es un error, cuenta qué estabas haciendo.'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: listo
                      ? () {
                          launchUrl(Uri.parse('https://wa.me/$whatsapp?text=${Uri.encodeComponent(mensaje)}'), mode: LaunchMode.externalApplication);
                          Navigator.of(h).pop();
                        }
                      : null,
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Enviar por WhatsApp'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: listo
                      ? () {
                          final asunto = Uri.encodeComponent('App Pivot — $tipo');
                          launchUrl(Uri.parse('mailto:$correo?subject=$asunto&body=${Uri.encodeComponent(mensaje)}'));
                          Navigator.of(h).pop();
                        }
                      : null,
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: const Text('Enviar por correo'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
