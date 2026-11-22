import '../eventos/eventos_repo.dart' show EventosRepo;
import '../ajustes/ajustes_screen.dart' show AjustesScreen;
import '../core/navegacion.dart';
import '../ajustes/componentes.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../coach/coach_screen.dart';
import '../core/pronombres.dart';
import '../core/sincroniza.dart';

import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/config_liga.dart';
import '../core/fechas.dart';
import '../core/tema.dart';
import '../eventos/widgets_comunes.dart';
import '../pivots/pivots_screen.dart';
import 'emergencia_screen.dart';
import 'equipo_modelos.dart';
import 'estadisticas.dart';
import 'equipo_repo.dart';
import 'registrar_pago_screen.dart';
import '../core/vidrio.dart';
import '../core/esqueleto.dart';

/// Ficha de una persona del equipo (web: `_eqRenderPerfil()`): encabezado,
/// acciones (WhatsApp, llamar, favorito y, para admins, Emergencia), stats
/// con desglose de puntos y, para admins, la sección de administración.
/// Se abre desde la lista de Equipo o tocando un avatar en un evento.
class PersonaScreen extends StatelessWidget {
  const PersonaScreen({super.key, required this.repo, required this.username});
  final EquipoRepo repo;
  final String username;

  static Future<void> abrir(BuildContext context, EquipoRepo repo, String username) {
    repo.cargar();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonaScreen(repo: repo, username: username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final per = repo.persona(username);
        if (per == null) {
          return Scaffold(
            appBar: AppBar(),
            body: repo.personas == null ? const Esqueleto(forma: FormaEsqueleto.ajustes) : const Center(child: Text('No se encontró a esta persona.')),
          );
        }
        return _Ficha(repo: repo, p: per);
      },
    );
  }
}

class _Ficha extends StatefulWidget {
  const _Ficha({required this.repo, required this.p});
  final EquipoRepo repo;
  final Integrante p;

  @override
  State<_Ficha> createState() => _FichaState();
}

class _FichaState extends State<_Ficha> {
  EquipoRepo get repo => widget.repo;
  Integrante get p => widget.p;

  // Tour de la ficha de una persona (Victor, 2026-11-15).
  bool _tituloEnBarra = false;
  final _kPivot = GlobalKey(debugLabel: 'tour-ficha-pivot');

  @override
  void initState() {
    super.initState();
    // Sin tour en la ficha (Victor, 2026-11-17).
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pivot;
    final t = Theme.of(context).textTheme;
    final yo = repo.esYo(p);
    final fav = repo.favoritos.contains(p.username);
    final estado = datosRelevantes(p, Fechas.hoy()).where((d) => d.fijo).firstOrNull;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const Vidrio(child: SizedBox.expand()),
        title: AnimatedOpacity(
          opacity: _tituloEnBarra ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Row(
            children: [
              AvatarPersona(nombre: p.nombreMostrar, foto: p.foto, tamano: 30),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  p.nombreMostrar,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!yo)
            IconButton(
              tooltip: fav ? 'Quitar de favoritos' : 'Agregar a favoritos',
              onPressed: () => repo.alternarFavorito(p.username),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                // Estrella redondeada, como la del jammer (Victor, 2026-11-07).
                child: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded, key: ValueKey(fav), size: 28, color: fav ? pal.marca : null),
              ),
            ),
        ],
      ),
      body: Sincroniza(
        onRefresh: () => repo.cargar(forzar: true),
        child: NotificationListener<ScrollNotification>(
          // Al desplazar, el nombre y la foto pasan a la barra (Victor, 2026-11-17).
          onNotification: (n) {
            final ver = n.metrics.axis == Axis.vertical && n.metrics.pixels > 150;
            if (ver != _tituloEnBarra) setState(() => _tituloEnBarra = ver);
            return false;
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8 + altoBarra(context), 16, 40 + MediaQuery.paddingOf(context).bottom),
            children: [
              // Ficha como Ajustes (Victor, 2026-11-17, opción A): lo esencial
              // centrado, acciones redondas, roles deslizables y filas.
              Center(
                child: HeroAvatar(
                  tag: 'avatar-${p.username}',
                  child: AvatarPersona(nombre: p.nombreMostrar, foto: p.foto, tamano: 96),
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: p.nombreMostrar),
                    if (p.numero.isNotEmpty)
                      TextSpan(
                        text: ' #${p.numero}',
                        style: TextStyle(color: pal.textoSecundario),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                ['@${p.username}', if (p.pronombres.isNotEmpty) p.pronombres].join(' · '),
                textAlign: TextAlign.center,
                style: TextStyle(color: pal.textoSecundario),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  Etiqueta(texto: p.categoria),
                  if (estado != null) Etiqueta(texto: estado.texto),
                ],
              ),
              const SizedBox(height: 18),
              _acciones(context, pal, yo),
              if (p.roles.isNotEmpty) ...[
                _tituloSeccion(pal, 'ROLES'),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: p.roles.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: pal.tarjeta, borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
                      child: Text(
                        p.roles[i],
                        style: TextStyle(fontWeight: FontWeight.w700, color: pal.texto),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              GrupoAjustes(
                titulo: 'EN EL EQUIPO',
                filas: [
                  FilaAjuste(
                    icono: Icons.insights_rounded,
                    seccion: 'reservas',
                    titulo: 'Estadísticas',
                    valor: 'Asistencia y puntos',
                    alTocar: () => EstadisticasScreen.abrir(context, repo, p),
                  ),
                  if (yo || repo.esAdmin || repo.sesion.esCoach)
                    FilaAjuste(
                      icono: Icons.sports_score_rounded,
                      seccion: 'entrenamientos',
                      titulo: 'Ficha deportiva',
                      valor: 'Habilidades y notas',
                      alTocar: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FichaDeportivaScreen(sesion: repo.sesion, username: yo ? null : p.username, nombre: p.nombreMostrar),
                        ),
                      ),
                    ),
                  if (p.fechaIngreso != null)
                    // "En la liga": la persona puede cambiar de equipo (Victor, 2026-11-17).
                    FilaAjuste(icono: Icons.event_available_rounded, seccion: 'ingreso', titulo: 'En la liga desde', valor: Fechas.corta(p.fechaIngreso!)),
                  // Tu perfil se edita en Ajustes (Victor, 2026-11-17).
                  if (yo)
                    FilaAjuste(
                      icono: Icons.edit_rounded,
                      seccion: 'cuenta',
                      titulo: 'Editar mi perfil',
                      valor: 'Foto, nombre, número, roles y más',
                      // Se abre como una subsección, deslizando (Victor, 2026-11-17).
                      alTocar: () {
                        final ev = EventosRepo.actual;
                        if (ev == null) {
                          Navegacion.ir.value = Pestana.perfil;
                        } else {
                          SubAjustes.abrir(context, AjustesScreen(sesion: repo.sesion, eventos: ev));
                        }
                      },
                    ),
                ],
              ),
              // También en tu propia ficha: un Pivot puede registrar su pago.
              if (repo.esAdmin) ...[
                const SizedBox(height: 18),
                KeyedSubtree(
                  key: _kPivot,
                  child: _Administracion(repo: repo, p: p),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tituloSeccion(PivotPaleta pal, String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      t,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: pal.textoSecundario),
    ),
  );

  Widget _acciones(BuildContext context, PivotPaleta pal, bool yo) {
    final canal = ConfigLiga.de(repo.sesion);

    final tel = p.telefono;
    final completo = tel.isEmpty ? '' : '+${p.prefijo.isEmpty ? '593' : p.prefijo}${tel.startsWith('0') ? tel.substring(1) : tel}';
    final botones = <Widget>[
      if (!yo && tel.isNotEmpty)
        // Con la app que use la liga (Ajustes de la liga → Canal de comunicación).
        _Accion(icono: canal.icono, texto: canal.nombreCanalCorto, alTocar: () => canal.escribir(completo)),
      if (!yo && tel.isNotEmpty) _Accion(icono: Icons.call_rounded, texto: 'Llamar', alTocar: () => launchUrl(Uri.parse('tel:$completo'))),
      // En Equipo, Emergencia está siempre disponible para admins (Victor, 2026-11-07).
      if (repo.esAdmin && !yo && !kIsWeb)
        _Accion(icono: Icons.emergency_rounded, texto: 'Emergencia', roja: true, alTocar: () => EmergenciaScreen.abrir(context, repo, p)),
    ];
    if (botones.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [for (final b in botones) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: b)],
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({required this.icono, required this.texto, required this.alTocar, this.roja = false});
  final bool roja;
  final IconData icono;
  final String texto;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return Column(
      children: [
        Material(
          color: roja ? p.marca : p.suave,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: alTocar,
            child: SizedBox(width: 56, height: 56, child: Icon(icono, color: roja ? p.sobreMarca : p.sobreSuave)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          texto,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.texto),
        ),
      ],
    );
  }
}

/// Sección de administración (solo admins; web `_eqAdminBloqueHtml()`).
class _Administracion extends StatefulWidget {
  const _Administracion({required this.repo, required this.p});
  final EquipoRepo repo;
  final Integrante p;

  @override
  State<_Administracion> createState() => _AdministracionState();
}

class _AdministracionState extends State<_Administracion> {
  bool _ocupado = false;
  bool? _cupon;

  Future<void> _hacer(Future<void> Function() f, String ok) async {
    setState(() => _ocupado = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await f();
      m.showSnackBar(SnackBar(content: Text(ok)));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  String _textoViaje(Integrante p) {
    final d = p.viajeDesde, h = p.viajeHasta;
    if (d == null && h == null) return 'De viaje';
    if (d == null) return 'De viaje hasta el ${Fechas.corta(h!)}';
    if (h == null) return 'De viaje desde el ${Fechas.corta(d)}';
    return 'De viaje del ${Fechas.corta(d)} al ${Fechas.corta(h)}';
  }

  /// Automático (según puntos) o fijo en un equipo de la liga.
  Future<void> _elegirEquipo() async {
    final p = widget.p;
    List<String> equipos = const [];
    try {
      final r = await widget.repo.sesion.api.get('getTiers', {'adminToken': widget.repo.sesion.adminToken});
      equipos = [
        for (final t in (r['tiers'] as List? ?? const []))
          if (t is Map) '${t['nombre']}',
      ];
    } catch (_) {}
    if (!mounted) return;
    if (equipos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudieron cargar los equipos. Revisa tu conexión.')));
      return;
    }
    final v = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (h) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Equipo de ${p.nombreMostrar}', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.auto_mode_rounded),
              title: const Text('Automático'),
              subtitle: const Text('Sube o baja según los requisitos de cada equipo'),
              trailing: p.tierModo == 'auto' ? Icon(Icons.check_rounded, color: h.pivot.marcaTexto) : null,
              onTap: () => Navigator.of(h).pop(''),
            ),
            for (final e in equipos)
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: Text('Fijo en $e'),
                trailing: p.tierModo != 'auto' && p.categoria == e ? Icon(Icons.check_rounded, color: h.pivot.marcaTexto) : null,
                onTap: () => Navigator.of(h).pop(e),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (v == null || !mounted) return;
    await _hacer(() => widget.repo.cambiarTier(p, v.isEmpty ? 'auto' : 'fijo', equipo: v), 'Equipo actualizado');
  }

  /// Cupón manual: elegir el % o quitarlo.
  Future<void> _elegirDescuento(Integrante p) async {
    final pct = await showModalBottomSheet<int>(
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
              Text('Descuento para ${p.nombreMostrar}', style: Theme.of(h).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Se aplica solo en su próximo pago y se usa una vez. Le llega un aviso.', style: TextStyle(color: h.pivot.textoSecundario)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in const [10, 15, 25, 50, 100])
                    ChoiceChip(label: Text(n == 100 ? 'Gratis' : '$n %'), selected: p.cuponDescuento == n, onSelected: (_) => Navigator.of(h).pop(n)),
                ],
              ),
              if (p.cuponDescuento != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.of(h).pop(0), child: const Text('Quitar descuento')),
              ],
            ],
          ),
        ),
      ),
    );
    if (pct == null) return;
    await _hacer(() => widget.repo.cuponDescuento(p, pct), pct == 0 ? 'Descuento quitado' : 'Descuento de $pct % listo');
  }

  /// Subsección propia (Victor, 2026-11-21): abre al instante y permite
  /// mensualidad, clase o saldo a favor.
  Future<void> _registrarPago() async {
    final ok = await SubAjustes.abrir<bool>(context, RegistrarPagoScreen(repo: widget.repo, persona: widget.p));
    if (ok == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago registrado')));
  }

  Future<void> _noPagaMes() async {
    final p = widget.p;
    final mes = await showModalBottomSheet<DateTime>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (hoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('¿Qué mes no paga ${p.nombreMostrar}?', style: Theme.of(hoja).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            // Últimos 6 meses, este y los próximos 6 (Victor, 2026-11-21), con su
            // estado: un mes pagado no se puede elegir (2026-11-22).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FutureBuilder<Map<String, String>>(
                future: widget.repo.mesesCuota(p),
                builder: (hoja, f) {
                  if (f.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final estados = f.data ?? const {};
                  String clave(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (f.hasError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('No se pudo ver qué meses tiene pagados.', style: TextStyle(color: hoja.pivot.textoSecundario)),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final m in RegistrarPagoScreen.meses())
                            switch (estados[clave(m)]) {
                              'pagado' => ActionChip(
                                avatar: const Icon(Icons.check_rounded, size: 18),
                                label: Text('${Fechas.mesAnio(m)} · Pagado'),
                                onPressed: null,
                              ),
                              'no_paga' => ActionChip(
                                avatar: const Icon(Icons.event_busy_outlined, size: 18),
                                label: Text('${Fechas.mesAnio(m)} · No paga'),
                                onPressed: null,
                              ),
                              final e => ActionChip(
                                label: Text(e == 'en_revision' ? '${Fechas.mesAnio(m)} · En revisión' : Fechas.mesAnio(m)),
                                onPressed: () => Navigator.of(hoja).pop(m),
                              ),
                            },
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (mes == null || !mounted) return;
    if (!await _confirmar(
      '¿No paga ${Fechas.mes(mes)} ${mes.year}?',
      '${p.nombreMostrar} no deberá la cuota de ese mes. Queda registrado en su historial.',
      'Confirmar',
    )) {
      return;
    }
    await _hacer(() => widget.repo.noPagaMes(p, mes), 'Listo: no paga ${Fechas.mes(mes)} ${mes.year}');
  }

  Future<void> _marcarViaje() async {
    final hoy = Fechas.hoy();
    // Como pantalla en el mismo navegador (Victor, 2026-11-21): el gesto de
    // volver cierra el calendario y deja la ficha donde estaba.
    final r = await Navigator.of(context).push<DateTimeRange>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DateRangePickerDialog(
          firstDate: hoy.subtract(const Duration(days: 60)),
          lastDate: hoy.add(const Duration(days: 365)),
          initialDateRange: DateTimeRange(start: hoy, end: hoy.add(const Duration(days: 7))),
          helpText: 'Fechas del viaje',
          saveText: 'Guardar',
        ),
      ),
    );
    if (r == null || !mounted) return;
    setState(() => _ocupado = true);
    final m = ScaffoldMessenger.of(context);
    try {
      final aviso = await widget.repo.marcarViaje(widget.p, r.start, r.end);
      m.showSnackBar(SnackBar(content: Text(aviso ?? 'Viaje guardado')));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  static const _estados = {
    'Activx': (Icons.directions_run_rounded, 'Entrena con normalidad.'),
    'Ausente': (Icons.event_busy_rounded, 'Fuera por un tiempo, avisado.'),
    'Lesionadx': (Icons.healing_rounded, 'En recuperación de una lesión.'),
    'Enfermedad': (Icons.sick_outlined, 'Fuera por enfermedad. El equipo solo ve "Fuera por un tiempo".'),
    'Situación personal': (Icons.support_outlined, 'Situación personal o fuerza mayor. El equipo no ve el motivo.'),
    'Otro': (Icons.more_horiz_rounded, 'Fuera por otro motivo. El equipo no ve el motivo.'),
  };

  Future<void> _elegirEstado() async {
    final p = widget.p;
    final e = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (c) {
        final pal = c.pivot;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Estado de ${p.nombreMostrar}', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ),
              for (final x in _estados.entries)
                ListTile(
                  leading: Icon(x.value.$1, color: x.key == p.estado ? pal.marcaTexto : pal.textoSecundario),
                  title: Text(conPronombres(x.key, p.pronombres), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(x.value.$2),
                  trailing: x.key == p.estado ? Icon(Icons.check_rounded, color: pal.marcaTexto) : null,
                  onTap: () => Navigator.of(c).pop(x.key),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (e == null || e == p.estado || !mounted) return;
    if (!await _confirmar('¿Cambiar el estado?', '${p.nombreMostrar} pasa de ${p.estadoMostrar} a ${conPronombres(e, p.pronombres)}.', 'Cambiar')) return;
    await _hacer(() => widget.repo.cambiarEstado(p, e), 'Estado actualizado');
  }

  Future<bool> _confirmar(String titulo, String texto, String si) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: Text(si)),
        ],
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pivot;
    final p = widget.p;
    final repo = widget.repo;
    return Material(
      color: pal.tarjeta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PivotRadios.tarjeta)),
      clipBehavior: Clip.antiAlias,
      // Siempre abierta y sin título (Victor, 2026-11-07): solo la ven admins.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _ocupado ? 0.5 : 1,
          child: IgnorePointer(
            ignoring: _ocupado,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Título para encontrarla (Victor, 2026-11-13: no la veía).
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings_outlined, size: 20, color: pal.marcaTexto),
                    const SizedBox(width: 8),
                    Text(
                      'Funciones de Pivot',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: pal.texto),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Solo las ven los Pivots: pagos, Equipo, permisos y más.', style: TextStyle(fontSize: 13, color: pal.textoSecundario)),
                const SizedBox(height: 14),
                Text('Equipo', style: TextStyle(fontSize: 13, color: pal.textoSecundario)),
                const SizedBox(height: 6),
                // Equipos de la liga, no fijos (Victor, 2026-11-17).
                Material(
                  color: pal.suave,
                  borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                    onTap: _ocupado ? null : _elegirEquipo,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(p.tierModo == 'auto' ? Icons.auto_mode_rounded : Icons.push_pin_outlined, color: pal.sobreSuave),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p.tierModo == 'auto' ? 'Automático · ahora en ${p.categoria}' : 'Fijo en ${p.categoria}',
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: pal.sobreSuave),
                            ),
                          ),
                          Icon(Icons.unfold_more_rounded, color: pal.sobreSuave),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Selector tipo desplegable (más claro que las pills) y con
                // confirmación: no se cambia por accidente (Victor, 2026-11-07).
                // "De viaje" se marca abajo con fechas.
                Text('Estado', style: TextStyle(fontSize: 13, color: pal.textoSecundario)),
                const SizedBox(height: 6),
                Material(
                  color: pal.suave,
                  borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                    onTap: _ocupado ? null : _elegirEstado,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(_estados[p.estado]?.$1 ?? Icons.flight_takeoff_rounded, color: pal.sobreSuave),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p.estadoMostrar,
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: pal.sobreSuave),
                            ),
                          ),
                          Icon(Icons.unfold_more_rounded, color: pal.sobreSuave),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Cupón manual (Victor, 2026-11-16).
                if (!p.exentaCuota)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.local_offer_outlined, color: pal.marcaTexto),
                    title: Text(p.cuponDescuento == null ? 'Dar un descuento' : 'Descuento de ${p.cuponDescuento} %'),
                    subtitle: Text(p.cuponDescuento == null ? 'Para su próximo pago, una sola vez' : 'Se aplica en su próximo pago'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _elegirDescuento(p),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Paga cuota'),
                  value: !p.exentaCuota,
                  onChanged: (v) => _hacer(() => repo.cambiarPagaCuota(p, v), v ? 'Ahora paga cuota' : 'Ya no paga cuota'),
                ),
                // Acceso de Pivot (Victor, 2026-11-13): se gestiona en Mi Liga →
                // Pivots y permisos; aquí queda solo un atajo.
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.admin_panel_settings_outlined, color: pal.marcaTexto),
                  title: Text(p.esAdminMiembro ? 'Pivot' : 'Nombrar Pivot'),
                  subtitle: Text(
                    p.esAdminMiembro ? 'Ver sus áreas y permisos' : (p.email.isEmpty ? 'Necesita un correo para ser Pivot' : 'Elegir qué áreas gestiona'),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  enabled: p.esAdminMiembro || p.email.isNotEmpty,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PivotsScreen(sesion: repo.sesion, persona: p),
                      ),
                    );
                    repo.cargar(forzar: true);
                  },
                ),

                // Viaje (web `_eqAbrirSheetViaje()`): "De viaje" solo se marca con fechas.
                if (p.deViaje)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.flight_takeoff_rounded, color: pal.marcaTexto),
                    title: Text(_textoViaje(p)),
                    trailing: TextButton(
                      onPressed: () async {
                        if (!await _confirmar(
                          '¿Cancelar el viaje?',
                          conPronombres('${p.nombreMostrar} vuelve a quedar Activx.', p.pronombres),
                          'Cancelar viaje',
                        )) {
                          return;
                        }
                        await _hacer(() => repo.cancelarViaje(p), 'Viaje cancelado');
                      },
                      child: const Text('Cancelar'),
                    ),
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.flight_takeoff_rounded, color: pal.marcaTexto),
                    title: const Text('Marcar viaje'),
                    subtitle: const Text('Mientras esté de viaje no cuenta como inactividad.'),
                    onTap: _marcarViaje,
                  ),
                // Pagos desde la ficha (etapa 3, Victor 2026-11-12).
                if (!p.exentaCuota) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.payments_outlined, color: pal.marcaTexto),
                    title: const Text('Registrar pago'),
                    subtitle: const Text('Cuota pagada en efectivo, De Una o transferencia.'),
                    onTap: _registrarPago,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.event_busy_outlined, color: pal.marcaTexto),
                    title: const Text('No paga un mes'),
                    subtitle: const Text('Excepción de ese mes. Queda en su historial.'),
                    onTap: _noPagaMes,
                  ),
                ],
                // Ver y registrar en una subsección (Victor, 2026-11-21).
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.add_task_rounded, color: pal.marcaTexto),
                  title: const Text('Asistencias externas'),
                  subtitle: const Text('Entrenamientos fuera de la liga. Suman puntos de asistencia.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => SubAjustes.abrir<void>(context, _ExternasScreen(repo: widget.repo, p: widget.p)),
                ),
                // Clase gratis de bienvenida (web "Cupones", Victor 2026-11-14).
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(Icons.local_activity_outlined, color: pal.marcaTexto),
                  title: const Text('Clase gratis disponible'),
                  subtitle: const Text('Cupón de bienvenida para reservar una clase sin pagar.'),
                  // Cambia al instante y se guarda detrás (Victor, 2026-11-21: tardaba).
                  value: _cupon ?? p.cuponDisponible,
                  onChanged: (v) async {
                    setState(() => _cupon = v);
                    final m = ScaffoldMessenger.of(context);
                    try {
                      await repo.cambiarCupon(p, v);
                      m.showSnackBar(SnackBar(content: Text(v ? 'Tiene una clase gratis' : 'Ya no tiene clase gratis')));
                    } catch (e) {
                      if (mounted) setState(() => _cupon = !v);
                      m.showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                ),
                // Archivar solo con inactividad (Victor, 2026-11-07); el
                // servidor además lo impide con reservas o cuotas activas.
                if (p.inactivx && !repo.esYo(p))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.archive_outlined, color: pal.marcaTexto),
                    title: Text('Archivar a ${p.nombreMostrar}', style: TextStyle(color: pal.marcaTexto)),
                    subtitle: const Text('Deja de aparecer en Liga. Su historial se conserva y, si vuelve a ingresar, sale de archivo y queda activx.'),
                    onTap: () async {
                      final nav = Navigator.of(context);
                      if (!await _confirmar('¿Archivar?', 'No se puede archivar si tiene reservas activas o cuotas pendientes.', 'Archivar')) return;
                      await _hacer(() => repo.archivar(p), conPronombres('Archivadx', p.pronombres));
                      if (repo.persona(p.username) == null) nav.pop();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asistencias externas de una persona: la lista (con borrar) y registrar
/// una nueva, en la misma subsección (Victor, 2026-11-21).
class _ExternasScreen extends StatefulWidget {
  const _ExternasScreen({required this.repo, required this.p});
  final EquipoRepo repo;
  final Integrante p;

  @override
  State<_ExternasScreen> createState() => _ExternasScreenState();
}

class _ExternasScreenState extends State<_ExternasScreen> {
  List<Map<String, dynamic>>? _l;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final l = await widget.repo.asistenciasExternas(widget.p);
      if (mounted) setState(() => _l = l);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'No se pudieron cargar. Revisa tu conexión.');
    }
  }

  void _aviso(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _nueva() async {
    final res = await showModalBottomSheet<(DateTime, String)>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _HojaAsistenciaExterna(),
    );
    if (res == null) return;
    try {
      await widget.repo.registrarAsistenciaExterna(widget.p, res.$1, res.$2);
      _aviso('Asistencia externa registrada');
      await _cargar();
    } catch (e) {
      _aviso(e.toString());
    }
  }

  Future<void> _borrar(Map<String, dynamic> x) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Borrar esta asistencia externa?'),
        content: const Text('Se le restan los puntos de asistencia de ese mes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repo.eliminarAsistenciaExterna('${x['idEvento']}');
      setState(() => _l?.remove(x));
      _aviso('Asistencia externa borrada');
    } catch (e) {
      _aviso(e is ApiException ? e.message : 'No se pudo borrar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    final l = _l;
    return Scaffold(
      appBar: AppBar(title: const Text('Asistencias externas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Entrenamientos de ${widget.p.nombreMostrar} fuera de la liga. Borrar una le resta los puntos de ese mes.',
              style: TextStyle(color: p.textoSecundario),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _nueva,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Registrar asistencia externa'),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: TextStyle(color: p.marcaTexto))
            else if (l == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (l.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No tiene asistencias externas.', style: TextStyle(color: p.textoSecundario)),
              )
            else
              for (final x in l)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.event_available_rounded, color: p.marcaTexto),
                  title: Text(DateTime.tryParse('${x['fecha']}') == null ? '${x['fecha']}' : Fechas.corta(DateTime.parse('${x['fecha']}'))),
                  subtitle: '${x['lugar'] ?? ''}'.isEmpty ? null : Text('${x['lugar']}'),
                  trailing: IconButton(tooltip: 'Borrar', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _borrar(x)),
                ),
          ],
        ),
      ),
    );
  }
}

/// Fecha (hasta hoy) y lugar (opcional, 60 caracteres) de una asistencia externa.
class _HojaAsistenciaExterna extends StatefulWidget {
  const _HojaAsistenciaExterna();

  @override
  State<_HojaAsistenciaExterna> createState() => _HojaAsistenciaExternaState();
}

class _HojaAsistenciaExternaState extends State<_HojaAsistenciaExterna> {
  DateTime? _fecha;
  final _lugar = TextEditingController();

  @override
  void dispose() {
    _lugar.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = Fechas.hoy();
    final f = await showDatePicker(context: context, firstDate: DateTime(hoy.year - 1, hoy.month, hoy.day), lastDate: hoy, initialDate: _fecha ?? hoy);
    if (f != null) setState(() => _fecha = f);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Asistencia externa', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _elegirFecha,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(_fecha == null ? 'Elegir fecha' : Fechas.corta(_fecha!)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lugar,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Lugar (opcional)'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _fecha == null ? null : () => Navigator.of(context).pop((_fecha!, _lugar.text)),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }
}
