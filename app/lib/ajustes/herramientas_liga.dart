import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/tema.dart';
import '../sesion/sesion.dart';
import 'componentes.dart';

/// Funciones que cada liga activa o desactiva (Victor, 2026-11-19): Finanzas
/// y Coach salieron de la barra de abajo y viven en Ajustes → Herramientas de
/// la liga. Se guardan en `reglas_liga` (`finanzasActiva`, `coachActivo`);
/// sin guardar, están activas.
class FuncionesLiga {
  FuncionesLiga._();

  static bool finanzas(Sesion s) => ConfigLiga.de(s).reglas['finanzasActiva'] != false;
  static bool coach(Sesion s) => ConfigLiga.de(s).reglas['coachActivo'] != false;

  /// Coach aprobadx y la liga usa Coach: ve las herramientas de coach
  /// (Habilidades en Equipo, Evaluar en los entrenamientos, Coach en Ajustes).
  static bool usaCoach(Sesion s) => s.esCoach && coach(s);

  /// Un Pivot puede activar o desactivar Coach para la liga.
  static bool puedeCambiarCoach(Sesion s) => s.esAdmin && s.adminToken != null;

  /// Guarda la activación. Si el servidor no la recuerda, avisa y devuelve false.
  static Future<bool> cambiar(BuildContext context, Sesion s, String clave, bool valor) async {
    final m = ScaffoldMessenger.of(context);
    final config = ConfigLiga.de(s);
    try {
      await config.guardarReglas({clave: valor});
      if ((config.reglas[clave] != false) != valor) {
        m.showSnackBar(const SnackBar(content: Text('No se pudo guardar este cambio todavía. Inténtalo más tarde.')));
        return false;
      }
      m.showSnackBar(SnackBar(content: Text(valor ? 'Activado para toda la liga.' : 'Desactivado para toda la liga.')));
      return true;
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'No se pudo guardar. Revisa tu conexión.')));
      return false;
    }
  }
}

/// Grupo "Herramientas de la liga" en Ajustes: Mi Liga, Finanzas y Coach,
/// cada una solo para quien le corresponde.
class GrupoHerramientasLiga extends StatelessWidget {
  const GrupoHerramientasLiga({super.key, required this.sesion});
  final Sesion sesion;

  /// Hay algo que mostrar para esta persona.
  static bool visible(Sesion s) => (s.esAdmin && s.adminToken != null) || s.tieneArea('finanzas');

  Future<void> _activar(BuildContext context, String clave, String nombre, String que) async {
    final ok = await showModalBottomSheet<bool>(
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
              Text('¿Activar $nombre?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(que, style: TextStyle(height: 1.35, color: h.pivot.textoSecundario)),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.of(h).pop(true), child: Text('Activar $nombre')),
            ],
          ),
        ),
      ),
    );
    if (ok == true && context.mounted) await FuncionesLiga.cambiar(context, sesion, clave, true);
  }

  @override
  Widget build(BuildContext context) {
    // En Mi Liga (Victor, 2026-11-22): activar o no Finanzas y Coach para la
    // liga. Salió de Mi perfil; Finanzas se abre desde la pestaña de Liga.
    return ListenableBuilder(
      listenable: Listenable.merge([sesion, ConfigLiga.de(sesion)]),
      builder: (context, _) {
        if (!FuncionesLiga.puedeCambiarCoach(sesion)) return const SizedBox.shrink();
        final finanzas = FuncionesLiga.finanzas(sesion);
        final coach = FuncionesLiga.coach(sesion);
        const textoFinanzas = 'Tesorería, cuotas, cobros y comprobantes de la liga, para quienes gestionan finanzas.';
        const textoCoach = 'Lxs entrenadorxs siguen las habilidades de cada persona, evalúan los entrenamientos y arman cursos.';
        return GrupoAjustes(
          pie: 'Si la liga no las usa, se ocultan para todo el mundo.',
          filas: [
            FilaAjuste(
              icono: Icons.account_balance_wallet_rounded,
              seccion: 'recaudacion',
              titulo: 'Finanzas',
              valor: finanzas ? 'Activada' : 'Desactivada',
              alTocar: finanzas ? null : () => _activar(context, 'finanzasActiva', 'Finanzas', textoFinanzas),
              derecha: Switch(value: finanzas, onChanged: (v) => FuncionesLiga.cambiar(context, sesion, 'finanzasActiva', v)),
            ),
            FilaAjuste(
              icono: Icons.sports_rounded,
              seccion: 'entrenamientos',
              titulo: 'Entreno',
              valor: coach ? 'Activado' : 'Desactivado',
              alTocar: coach ? null : () => _activar(context, 'coachActivo', 'Entreno', textoCoach),
              derecha: Switch(value: coach, onChanged: (v) => FuncionesLiga.cambiar(context, sesion, 'coachActivo', v)),
            ),
          ],
        );
      },
    );
  }
}
