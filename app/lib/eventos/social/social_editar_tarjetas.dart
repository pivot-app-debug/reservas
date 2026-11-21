import 'package:flutter/material.dart';

import '../../core/fechas.dart';
import '../../core/tema.dart';
import 'social_plantillas.dart';
import 'social_repo.dart';
import 'social_widgets.dart';

/// Editar una tarjeta del evento desde la tarjeta misma (Victor, 2026-11-20),
/// sin pasar por todo el asistente: solo lo de esa tarjeta.
class EditarTarjetas {
  EditarTarjetas(this.context, this.repo, this.estado, this.alCambiar);
  final BuildContext context;
  final SocialRepo repo;
  final EstadoSocial estado;
  final VoidCallback alCambiar;

  /// Botón de lápiz para la esquina de la tarjeta.
  static Widget boton(VoidCallback alTocar) => IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit_outlined), onPressed: alTocar);

  static num? _num(TextEditingController c) => num.tryParse(c.text.trim().replaceAll(',', '.'));
  static String _n(num? n) => n == null ? '' : cantidadSocial(n);

  Future<void> _guardar(String pieza, Map<String, Object?> datos) async {
    try {
      await repo.editarPieza(pieza, datos);
      alCambiar();
      if (context.mounted) avisarSocial(context, 'Cambios guardados.');
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  void _tarde(List<TextEditingController> cs) => Future.delayed(const Duration(milliseconds: 400), () {
    for (final c in cs) {
      c.dispose();
    }
  });

  /// Solo "¿Participas?" (quien no organiza): amigo secreto o regalo robado.
  Future<void> participacion({required bool amigo}) async {
    var si = amigo ? estado.participaAmigo : estado.participaRobado;
    final ok = await hojaFormulario(
      context,
      titulo: amigo ? 'Amigo secreto' : 'Regalo robado',
      accion: 'Guardar',
      contenido: (d, set) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(amigo ? 'Participo del amigo secreto' : 'Juego al regalo robado'),
        subtitle: const Text('Se puede cambiar hasta el cierre de la inscripción.'),
        value: si,
        onChanged: (v) => set(() => si = v),
      ),
    );
    if (ok != true) return;
    await _participar(amigo: amigo, si: si);
  }

  Future<void> _participar({required bool amigo, required bool si}) async {
    if (si == (amigo ? estado.participaAmigo : estado.participaRobado)) return;
    try {
      await repo.participar(amigo: amigo ? si : null, robado: amigo ? null : si);
      alCambiar();
      if (context.mounted) avisarSocial(context, 'Cambios guardados.');
    } catch (e) {
      if (context.mounted) avisarSocial(context, e.toString());
    }
  }

  Future<void> amigo() async {
    final tope = TextEditingController(text: _n(estado.topeAmigo));
    DateTime? cierre = estado.cierre;
    final puedeParticipar = estado.asiste && estado.inscripcionAbierta && !estado.sorteado;
    var participo = estado.participaAmigo;
    final evento = DateTime.tryParse('${estado.evento['fecha'] ?? ''}');
    final ok = await hojaFormulario(
      context,
      titulo: 'Amigo secreto',
      accion: 'Guardar',
      contenido: (d, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (puedeParticipar)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Participo del amigo secreto'),
              value: participo,
              onChanged: (v) => set(() => participo = v),
            ),
          TextField(
            controller: tope,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tope del regalo (opcional)'),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: !estado.sorteado,
            leading: Icon(Icons.event_busy_outlined, color: d.pivot.marcaTexto),
            title: const Text('Cierre de la inscripción'),
            subtitle: Text(estado.sorteado ? 'El sorteo ya se hizo.' : (cierre == null ? 'Sin fecha' : '${Fechas.dia(cierre!)} ${Fechas.corta(cierre!)}')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final hoy = Fechas.hoy();
              final ultimo = evento == null ? hoy.add(const Duration(days: 365)) : evento.subtract(const Duration(days: 1));
              if (ultimo.isBefore(hoy)) return;
              final f = await showDatePicker(
                context: d,
                firstDate: hoy,
                lastDate: ultimo,
                initialDate: cierre != null && !cierre!.isBefore(hoy) && !cierre!.isAfter(ultimo) ? cierre! : ultimo,
              );
              if (f != null) set(() => cierre = f);
            },
          ),
        ],
      ),
    );
    final t = _num(tope);
    _tarde([tope]);
    if (ok != true) return;
    await _guardar('amigo', {'tope': t, if (cierre != null && !estado.sorteado) 'cierre': Fechas.iso(cierre!)});
    if (puedeParticipar) await _participar(amigo: true, si: participo);
  }

  Future<void> robado() async {
    final o = estado.juegoOpciones;
    final tope = TextEditingController(text: _n(estado.topeRobado));
    final recordatorio = TextEditingController(text: estado.recordatorioRobado);
    final reglas = TextEditingController(text: estado.reglasPropias);
    var robosMax = (o['robosMax'] as num?)?.toInt() ?? 3;
    var devolver = o['devolver'] == true, turnoFinal = o['turnoFinal'] != false, describir = o['describir'] != false;
    final puedeJugar = estado.asiste && estado.inscripcionAbierta;
    var juego = estado.participaRobado;
    // Muchos campos: subsección, no hoja (Victor, 2026-11-20).
    final ok = await pantallaFormulario(
      context,
      titulo: 'Regalo robado',
      accion: 'Guardar',
      contenido: (d, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (puedeJugar)
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Juego al regalo robado'), value: juego, onChanged: (v) => set(() => juego = v)),
          TextField(
            controller: tope,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tope del regalo (opcional)'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: recordatorio,
            maxLength: 300,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Recordatorio (opcional)', counterText: ''),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: robosMax,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '¿Cuántas veces se puede robar un regalo?'),
            items: [
              for (final n in [1, 2, 3, 4, 5]) DropdownMenuItem(value: n, child: Text(n == 1 ? '1 vez' : '$n veces')),
              const DropdownMenuItem(value: 0, child: Text('Sin límite')),
            ],
            onChanged: (v) => set(() => robosMax = v ?? 3),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Se puede robar de vuelta enseguida'),
            value: devolver,
            onChanged: (v) => set(() => devolver = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Turno final para la primera persona'),
            value: turnoFinal,
            onChanged: (v) => set(() => turnoFinal = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Escribir qué era cada regalo'),
            value: describir,
            onChanged: (v) => set(() => describir = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: reglas,
            maxLines: null,
            minLines: 3,
            maxLength: 3000,
            decoration: const InputDecoration(labelText: 'Reglas propias (opcional)', alignLabelWithHint: true, counterText: ''),
          ),
          const SizedBox(height: 6),
          Text(
            'Si las dejas vacías, se usan las reglas de siempre con las opciones de arriba.',
            style: TextStyle(fontSize: 12, color: d.pivot.textoSecundario),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => set(() => reglas.text = reglasRegaloRobado(robosMax: robosMax, devolver: devolver, turnoFinal: turnoFinal)),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Usar la plantilla para editarla'),
            ),
          ),
        ],
      ),
    );
    final datos = <String, Object?>{
      'tope': _num(tope),
      'recordatorio': recordatorio.text.trim(),
      'reglas': reglas.text.trim(),
      'juego': {'robosMax': robosMax, 'devolver': devolver, 'turnoFinal': turnoFinal, 'describir': describir},
    };
    _tarde([tope, recordatorio, reglas]);
    if (ok != true) return;
    await _guardar('robado', datos);
    if (puedeJugar) await _participar(amigo: false, si: juego);
  }

  Future<void> playlist() async {
    final pl = estado.playlist ?? const {};
    final link = TextEditingController(text: '${pl['link'] ?? ''}');
    final nota = TextEditingController(text: '${pl['nota'] ?? ''}');
    final ok = await hojaFormulario(
      context,
      titulo: 'Playlist colaborativa',
      accion: 'Guardar',
      contenido: (d, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: link,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Enlace de la playlist'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nota,
            maxLength: 200,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nota (opcional)', counterText: ''),
          ),
        ],
      ),
    );
    final datos = <String, Object?>{'link': link.text.trim(), 'nota': nota.text.trim()};
    _tarde([link, nota]);
    if (ok != true) return;
    await _guardar('playlist', datos);
  }

  Future<void> dress() async {
    final texto = TextEditingController(text: '${estado.dress?['texto'] ?? ''}');
    final ok = await hojaFormulario(
      context,
      titulo: 'Dress code',
      accion: 'Guardar',
      contenido: (d, set) => TextField(
        controller: texto,
        maxLength: 400,
        maxLines: null,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: '¿Cómo vienen vestidxs?', counterText: ''),
      ),
    );
    final t = texto.text.trim();
    _tarde([texto]);
    if (ok != true) return;
    await _guardar('dress', {'texto': t});
  }

  Future<void> invitados() async {
    var activo = estado.modulo('invitados');
    var max = estado.maxInvitados;
    final ok = await hojaFormulario(
      context,
      titulo: 'Invitadxs',
      accion: 'Guardar',
      contenido: (d, set) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Se pueden sumar invitadxs'),
            subtitle: const Text('Cada persona que va manda un enlace a quien invita.'),
            value: activo,
            onChanged: (v) => set(() => activo = v),
          ),
          if (activo) ...[
            const SizedBox(height: 8),
            const Text('¿Cuántxs puede invitar cada persona?'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 1, label: Text('+1')),
                  ButtonSegment(value: 2, label: Text('+2')),
                  ButtonSegment(value: 3, label: Text('+3')),
                ],
                selected: {max.clamp(1, 3)},
                onSelectionChanged: (s) => set(() => max = s.first),
              ),
            ),
          ],
        ],
      ),
    );
    if (ok != true) return;
    await _guardar('invitados', {'activo': activo, 'max': max});
  }
}
