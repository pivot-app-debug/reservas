import 'package:flutter/material.dart';

import '../core/moneda.dart';
import '../core/tema.dart';
import '../eventos/eventos_repo.dart';
import '../reservas/reserva_screen.dart';
import '../reservas/reservas_repo.dart';

/// Pantalla de pago cuando alguien le debe al equipo (Victor, 2026-11-26).
/// Solo si la liga eligió "Pantalla de pago al abrir la app" (reglas →
/// `deudaModo: 'bloqueo'`). No se puede cerrar: se sale pagando (o mandando
/// el comprobante, que ya cuenta) o cerrando sesión. Lo que debe lo calcula el
/// servidor (`getMiDeuda`): Pivots, coaches y exentxs nunca la ven.
class PantallaDeuda extends StatefulWidget {
  const PantallaDeuda({super.key, required this.repo, required this.inicial});
  final EventosRepo repo;
  final Map<String, dynamic> inicial;

  /// Al abrir la app: si la liga bloquea y la persona debe, la muestra.
  static Future<void> siCorresponde(BuildContext context, EventosRepo repo) async {
    if (repo.sesion.esAdmin) return;
    try {
      final r = await repo.sesion.api.get('getMiDeuda');
      if (r['bloquea'] != true || !context.mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, _, _) => PantallaDeuda(repo: repo, inicial: r),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic), child: child),
        ),
      );
    } catch (_) {
      // Sin conexión o error: nunca dejar a alguien fuera por un fallo nuestro.
    }
  }

  @override
  State<PantallaDeuda> createState() => _PantallaDeudaState();
}

class _PantallaDeudaState extends State<PantallaDeuda> {
  late Map<String, dynamic> _r = widget.inicial;
  bool _cargando = false;

  Future<void> _revisar() async {
    setState(() => _cargando = true);
    try {
      final r = await widget.repo.sesion.api.get('getMiDeuda');
      if (!mounted) return;
      if (r['bloquea'] != true) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listo, ya puedes usar la app.')));
        return;
      }
      setState(() => _r = r);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo revisar. Revisa tu conexión.')));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _pagar(Map<String, dynamic> x) async {
    final mes = DateTime.tryParse('${x['mes'] ?? ''}-01');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReservaScreen(repo: widget.repo, tipo: TipoReserva.mes, mesInicial: mes == null ? null : DateTime(mes.year, mes.month)),
      ),
    );
    if (mounted) await _revisar();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final items = [for (final x in (_r['items'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    final total = (_r['total'] as num?) ?? 0;
    final soloSaldo = items.every((x) => x['tipo'] == 'saldo');
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 56, color: p.marcaTexto),
              const SizedBox(height: 16),
              Text('Tienes un pago pendiente', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Para seguir usando la app, ponte al día con el equipo. Apenas mandes tu comprobante, puedes seguir usándola mientras un Pivot lo revisa.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textoSecundario, height: 1.35),
              ),
              const SizedBox(height: 20),
              for (final x in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: p.tarjeta,
                    borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                    child: ListTile(
                      title: Text('${x['que']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${x['motivo'] ?? ''}'),
                      trailing: Text('${Moneda.s}${((x['monto'] as num?) ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text('Total: ${Moneda.s}${total.toStringAsFixed(2)}', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _cargando ? null : () => _pagar(items.firstWhere((x) => x['tipo'] == 'cuota', orElse: () => items.first)),
                icon: const Icon(Icons.payments_outlined),
                label: Text(soloSaldo ? 'Pagar junto con mi próxima cuota' : 'Pagar ahora'),
              ),
              if (soloSaldo)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Si prefieres pagarla aparte, avísale a un Pivot: lo registra y se desbloquea al instante.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: p.textoSecundario),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _cargando ? null : _revisar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Ya pagué: revisar de nuevo'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.repo.sesion.cerrar();
                },
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
