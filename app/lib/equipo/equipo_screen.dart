import '../core/atajos_color.dart';
import '../finanzas/tesoreria_repo.dart' show TesoreriaRepo, plata;
import 'inventario_modelos.dart' show InventarioRepo;
import '../core/navegacion.dart';
import '../core/deporte.dart';

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/sincroniza.dart';

import '../core/fechas.dart';
import '../core/tema.dart';
import '../core/vidrio.dart';
import '../eventos/widgets_comunes.dart';
import '../ajustes/componentes.dart';
import '../ajustes/herramientas_liga.dart' show FuncionesLiga;
import '../coach/coach_screen.dart' show CoachScreen, CoachesScreen;
import '../eventos/eventos_repo.dart';
import '../finanzas/tesoreria_screen.dart';
import '../pivots/categorias_screen.dart' show VerEquipoScreen, NuevoEquipoScreen;
import '../pivots/ajustes_liga_screen.dart' show AjustesLigaScreen;
import '../pivots/archivadas_screen.dart' show ArchivadasScreen;
import '../pivots/pivots_screen.dart' show PivotsScreen;
import 'buscador_equipo.dart';
import 'avisos_liga.dart';
import 'cosas_para_llevar.dart';
import 'comunidad_screen.dart';
import 'inventario_screen.dart';
import 'emergencia_screen.dart';
import 'equipo_modelos.dart';
import 'equipo_repo.dart';
import 'persona_screen.dart';
import '../core/esqueleto.dart';

/// Pestaña Equipo (Victor, 2026-11-07; plan en el Claude Doc "Pivot app —
/// Equipo, Tareas, Ajustes y Mi Liga"): favoritos en una fila de avatares,
/// Quindes, Mirlxs e Inactivxs como acordeón (siempre una sección abierta:
/// abrir otra cierra la anterior, Victor 2026-11-07) con tu fila primero, un
/// dato relevante por persona que rota con fundido, buscador inteligente y,
/// para admins, emergencia (marcadx hoy) y archivar (en Inactivxs).
class EquipoScreen extends StatefulWidget {
  const EquipoScreen({super.key, required this.repo});
  final EquipoRepo repo;

  @override
  State<EquipoScreen> createState() => _EquipoScreenState();
}

/// Pestañas de Liga (Victor, 2026-11-22): Comunidad (la gente), Redes,
/// Inventario y, para quien gestiona finanzas, Finanzas.
enum PestanaLiga { comunidad, redes, inventario, finanzas, miLiga }

class _EquipoScreenState extends State<EquipoScreen> with TickerProviderStateMixin {
  EquipoRepo get repo => widget.repo;

  bool get _pivot => repo.sesion.esAdmin && repo.sesion.adminToken != null;
  AvisosLiga get _avisos => AvisosLiga.de(repo.sesion);

  /// Liga sin pestañas (Victor, 2026-11-26): Equipos es la pantalla y arriba
  /// van los íconos de Comunicación, Inventario, Finanzas y Ajustes, cada uno
  /// solo con acceso. Cada uno abre su subsección.
  List<PestanaLiga> _atajos() => [
    PestanaLiga.redes,
    PestanaLiga.inventario,
    if (repo.sesion.tieneArea('finanzas') && FuncionesLiga.finanzas(repo.sesion)) PestanaLiga.finanzas,
    if (_pivot) PestanaLiga.miLiga,
  ];

  static String _nombreLiga(PestanaLiga x) => switch (x) {
    PestanaLiga.comunidad => 'Equipos',
    PestanaLiga.redes => 'Comunicación',
    PestanaLiga.inventario => 'Inventario',
    PestanaLiga.finanzas => 'Finanzas',
    PestanaLiga.miLiga => 'Ajustes de la liga',
  };

  static IconData _iconoLiga(PestanaLiga x) => switch (x) {
    PestanaLiga.comunidad => Icons.groups_rounded,
    PestanaLiga.redes => Icons.forum_outlined,
    PestanaLiga.inventario => Icons.content_paste_rounded,
    PestanaLiga.finanzas => Icons.account_balance_wallet_outlined,
    PestanaLiga.miLiga => Icons.settings_outlined,
  };

  // Lo que hay adentro de cada atajo, para verlo sin entrar.
  int? _enlaces, _prestamos;
  num? _totalCuentas;

  Future<void> _cargarAtajos() async {
    final s = repo.sesion;
    final c = ComunidadRepo.de(s);
    c.cargar().then((_) {
      if (mounted) setState(() => _enlaces = c.enlaces.length);
    }, onError: (_) {});
    final inv = InventarioRepo(s);
    inv.cargar().then((_) {
      if (mounted) setState(() => _prestamos = inv.prestamos.where((x) => x.activo && (inv.esPivot || x.mio)).length);
    }, onError: (_) {});
    if (_atajos().contains(PestanaLiga.finanzas)) {
      TesoreriaRepo(s).accion('resumen').then((r) {
        if (mounted) setState(() => _totalCuentas = (r['total'] as num?) ?? 0);
      }, onError: (_) {});
    }
  }

  List<AtajoColor> _atajosColor() => [
    for (final x in _atajos())
      AtajoColor(
        icono: _iconoLiga(x),
        color: switch (x) {
          PestanaLiga.redes => PivotPaleta.atajoAzul,
          PestanaLiga.inventario => PivotPaleta.atajoNaranja,
          PestanaLiga.finanzas => PivotPaleta.atajoVerde,
          _ => PivotPaleta.atajoMorado,
        },
        titulo: x == PestanaLiga.miLiga ? 'Ajustes' : _nombreLiga(x),
        punto: x == PestanaLiga.inventario && _avisos.inventario,
        detalle: switch (x) {
          PestanaLiga.redes =>
            _enlaces == null ? null : (_enlaces == 0 ? 'Grupos y redes de la liga' : (_enlaces == 1 ? '1 grupo o red' : '$_enlaces grupos y redes')),
          PestanaLiga.inventario =>
            _prestamos == null
                ? null
                : (_prestamos == 0 ? 'Equipamiento de la liga' : '$_prestamos ${_prestamos == 1 ? 'préstamo activo' : 'préstamos activos'}'),
          PestanaLiga.finanzas => _totalCuentas == null ? null : '${plata(_totalCuentas!)} en cuentas',
          _ => 'Reglas, cuotas y equipos',
        },
        alTocar: () => _abrirAtajo(x),
      ),
  ];

  void _abrirAtajo(PestanaLiga x) {
    final s = repo.sesion;
    _focoBusqueda.unfocus();
    SubAjustes.abrir(context, switch (x) {
      PestanaLiga.redes => ComunidadScreen(repo: ComunidadRepo.de(s)),
      PestanaLiga.inventario => InventarioScreen(sesion: s),
      PestanaLiga.finanzas => TesoreriaScreen(sesion: s),
      PestanaLiga.miLiga => AjustesLigaScreen(sesion: s, pestana: true),
      PestanaLiga.comunidad => const SizedBox.shrink(),
    }).then((_) {
      if (mounted) _cargarAtajos();
    });
  }

  final _busqueda = TextEditingController();
  final _focoBusqueda = FocusNode();

  /// Sección abierta del acordeón; null = la tuya (o la primera con gente).
  String? _abierto;

  /// Reloj común de las filas: todas cambian de dato a la vez.
  final _tick = ValueNotifier<int>(0);
  Timer? _reloj;
  bool _scrolleando = false;

  @override
  void initState() {
    super.initState();
    repo.cargar(forzar: repo.personas != null); // al abrir, siempre al día
    _cargarAtajos();
    _reloj = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_scrolleando && mounted) _tick.value++;
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _tick.dispose();
    _busqueda.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _abrir(Integrante p) {
    _avisos.verPersona(p);
    PersonaScreen.abrir(context, repo, p.username);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    return PopScope(
      // Atrás con texto en el buscador: primero lo borra.
      canPop: _busqueda.text.isEmpty,
      onPopInvokedWithResult: (hizo, _) {
        if (!hizo) setState(_busqueda.clear);
      },
      child: Scaffold(
        // Barra de vidrio: la lista pasa por detrás (Victor, 2026-11-13).
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          flexibleSpace: const Vidrio(child: SizedBox.expand()),
          // Liga, opción B del mockup (Victor, 2026-11-27): el buscador con
          // filtros va en la barra y los atajos en tarjetas debajo.
          toolbarHeight: 64,
          titleSpacing: 12,
          title: _buscador(p),
        ),
        body: _comunidad(context, p),
      ),
    );
  }

  Widget _comunidad(BuildContext context, PivotPaleta p) => ListenableBuilder(
    listenable: Listenable.merge([repo, _avisos]),
    builder: (context, _) {
      final personas = repo.personas;
      final Widget cuerpo;
      if (personas == null) {
        cuerpo = repo.error != null
            ? Center(
                key: const ValueKey('error'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(repo.error!),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => repo.cargar(forzar: true), child: const Text('Reintentar')),
                  ],
                ),
              )
            : const Esqueleto(forma: FormaEsqueleto.lista, key: ValueKey('cargando'));
      } else if (_busqueda.text.trim().isNotEmpty) {
        cuerpo = Builder(key: const ValueKey('resultados'), builder: (c) => _resultados(c, p, personas));
      } else {
        cuerpo = Builder(key: const ValueKey('lista'), builder: (c) => _lista(c, p, personas));
      }
      // El buscador queda fijo debajo de la barra; la lista empieza debajo de él.
      final mq = MediaQuery.of(context);
      final arriba = altoBarra(context);
      return Stack(
        children: [
          MediaQuery(
            data: mq.copyWith(padding: mq.padding.copyWith(top: arriba)),
            child: AnimatedSwitcher(duration: const Duration(milliseconds: 240), child: cuerpo),
          ),
          Positioned(
            top: arriba,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: repo.cargando && personas != null ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const LinearProgressIndicator(minHeight: 2),
            ),
          ),
        ],
      );
    },
  );

  /// Buscar y filtrar en la barra de Liga.
  Widget _buscador(PivotPaleta p) => SizedBox(
    height: 48,
    child: TextField(
      controller: _busqueda,
      focusNode: _focoBusqueda,
      // Sin foco automático (bug 2026-11-27: al volver de una sección se abría el buscador).
      textInputAction: TextInputAction.search,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Buscar en la liga',
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busqueda.text.isNotEmpty)
              IconButton(tooltip: 'Borrar texto', icon: const Icon(Icons.close_rounded), onPressed: () => setState(_busqueda.clear)),
            IconButton(
              tooltip: 'Filtros',
              onPressed: _abrirFiltros,
              icon: Badge(isLabelVisible: repo.hayFiltros, smallSize: 8, child: const Icon(Icons.tune_rounded)),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _envolverScroll(Widget hijo) => NotificationListener<ScrollNotification>(
    onNotification: (n) {
      if (n is ScrollStartNotification) _scrolleando = true;
      if (n is ScrollEndNotification) _scrolleando = false;
      return false;
    },
    child: Sincroniza(edgeOffset: MediaQuery.paddingOf(context).top, onRefresh: () => repo.cargar(forzar: true), child: hijo),
  );

  Widget _lista(BuildContext context, PivotPaleta p, List<Integrante> personas) {
    final hoy = Fechas.hoy();
    List<Integrante> grupo(String g) {
      // Coaches (Victor, 2026-11-22): quienes son coach, estén en un equipo o inactivxs.
      final l =
          personas.where((x) {
            final matchesGroup = g == 'Coaches' ? x.esCoach : (g == 'Pivots' ? x.esAdminMiembro : x.grupo == g);
            return matchesGroup && repo.pasaRoles(x);
          }).toList()..sort((a, b) {
            // Tu fila primero; después por nombre.
            if (repo.esYo(a) != repo.esYo(b)) return repo.esYo(a) ? -1 : 1;
            return BuscadorEquipo.normalizar(a.nombreMostrar).compareTo(BuscadorEquipo.normalizar(b.nombreMostrar));
          });
      return l;
    }

    final favoritos = personas.where((x) => repo.favoritos.contains(x.username)).toList();
    final mio = personas.where(repo.esYo).map((x) => x.grupo).firstOrNull;
    // Tu grupo arriba: si eres Mirlxs, Mirlxs va antes que Quindes (Victor, 2026-11-07).
    final coaches = FuncionesLiga.coach(repo.sesion);
    final secciones = [
      ...(mio == 'Mirlxs' ? const ['Mirlxs', 'Quindes', 'Inactivxs'] : const ['Quindes', 'Mirlxs', 'Inactivxs']),
      if (coaches) 'Coaches',
      if (_pivot) 'Pivots',
    ];
    final grupos = {for (final g in secciones) g: grupo(g)};
    final conGente = [
      for (final g in secciones)
        if (grupos[g]!.isNotEmpty) g,
    ];
    final abierto = conGente.contains(_abierto) ? _abierto : (conGente.contains(mio) ? mio : conGente.firstOrNull);

    return _envolverScroll(
      CustomScrollView(
        key: const ValueKey('lista'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).top)),
          if (!repo.hayFiltros)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: ListenableBuilder(
                  listenable: _avisos,
                  builder: (context, _) => GrillaAtajos(atajos: _atajosColor()),
                ),
              ),
            ),
          if (repo.hayFiltros) SliverToBoxAdapter(child: _filtrosActivos(p)),
          // Cosas para llevar hoy o mañana, para Pivots (Victor, 2026-11-22).
          if (!repo.hayFiltros && _pivot && EventosRepo.actual != null)
            SliverToBoxAdapter(
              child: AvisoCosasParaLlevar(eventos: EventosRepo.actual!, equipo: repo),
            ),
          if (favoritos.isNotEmpty && !repo.hayFiltros) ...[
            _encabezado(p, 'Favoritos', favoritos.length),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final f in favoritos)
                      InkWell(
                        borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                        onTap: () => _abrir(f),
                        child: SizedBox(
                          width: 76,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _AvatarEstado(p: f, tamano: 52, hero: false),
                              const SizedBox(height: 6),
                              // Nombre largo: se desliza con fundido en los bordes (Victor, 2026-11-07).
                              TextoDeslizante(
                                texto: f.nombreMostrar,
                                estilo: TextStyle(fontSize: 12, color: p.texto),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          for (final g in conGente)
            SliverMainAxisGroup(
              slivers: [
                _seccion(p, g, grupos[g]!.length, abierta: g == abierto),
                SliverToBoxAdapter(
                  child: _Plegable(
                    abierto: g == abierto,
                    child: Column(
                      children: [for (final x in grupos[g]!) g == 'Coaches' ? _filaCoach(context, p, x) : _fila(context, x, hoy), _accionesSeccion(g)],
                    ),
                  ),
                ),
              ],
            ),
          if (conGente.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Nadie coincide con estos filtros.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.textoSecundario),
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }

  bool _seEntra(String titulo) {
    // Sin actividad lleva a Personas archivadas, solo para Pivots (QA 2026-11-26).
    if (titulo == 'Inactivxs') return _pivot;
    if (titulo == 'Coaches') return FuncionesLiga.usaCoach(repo.sesion) || _pivot;
    return true;
  }

  String _label(String grupo) => switch (grupo) {
    'Inactivxs' => 'Sin actividad',
    'Coaches' => 'Entrenadorxs',
    _ => grupo,
  };

  void _entrar(String titulo) {
    final s = repo.sesion;
    _focoBusqueda.unfocus();
    // Entrenadorxs lleva a Entrenamiento en la barra de abajo (bug 2026-11-27).
    if (titulo == 'Coaches' && s.esCoach && FuncionesLiga.coach(s)) {
      Navegacion.entrenamiento.value = 'entrenamiento';
      Navegacion.ir.value = Pestana.entrenamiento;
      return;
    }
    if (titulo == 'Coaches') {
      SubAjustes.abrir(context, s.esCoach && EventosRepo.actual != null ? CoachScreen(sesion: s, eventos: EventosRepo.actual!) : CoachesScreen(sesion: s));
    } else if (titulo == 'Inactivxs') {
      // Solo Pivots pueden ver personas archivadas
      if (!s.esAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solo Pivots pueden ver personas archivadas.')));
        return;
      }
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ArchivadasScreen(repo: repo)));
    } else if (titulo == 'Pivots') {
      SubAjustes.abrir(context, PivotsScreen(sesion: s));
    } else {
      SubAjustes.abrir(context, VerEquipoScreen(sesion: s, nombre: titulo));
    }
  }

  /// Coach en la lista: solo lo básico y su ficha, sin estadísticas.
  Widget _filaCoach(BuildContext context, PivotPaleta p, Integrante x) => ListTile(
    key: ValueKey('coach-${x.username}'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    leading: AvatarPersona(nombre: x.nombreMostrar, foto: x.foto, tamano: 44),
    title: Text(
      x.nombreMostrar,
      style: TextStyle(fontWeight: FontWeight.w600, color: p.texto),
    ),
    subtitle: Text(x.grupo, style: TextStyle(color: p.textoSecundario)),
    trailing: Icon(Icons.chevron_right_rounded, color: p.textoSecundario),
    onTap: () => _abrir(x),
  );

  /// Botones al final de cada sección (Victor, QA 2026-11-26): tocar el
  /// título se veía poco, así que cada lista termina con "Gestionar …" y, en
  /// los equipos, "Crear equipo" al lado (solo Pivots).
  Widget _accionesSeccion(String g) {
    final s = repo.sesion;
    final esEquipo = g != 'Inactivxs' && g != 'Coaches' && g != 'Pivots';
    final String? texto = switch (g) {
      'Inactivxs' => _pivot ? 'Personas archivadas' : null,
      'Coaches' => _seEntra('Coaches') ? (_pivot ? 'Gestionar entrenadorxs' : 'Ver entrenadorxs') : null,
      'Pivots' => _pivot ? 'Gestionar Pivots' : null,
      _ => _pivot ? 'Gestionar $g' : 'Ver $g',
    };
    if (texto == null) return const SizedBox(height: 8);
    final gestionar = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
      onPressed: () => _entrar(g),
      icon: Icon(esEquipo && _pivot ? Icons.tune_rounded : (g == 'Inactivxs' ? Icons.inventory_outlined : Icons.chevron_right_rounded), size: 20),
      label: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: esEquipo && _pivot
          ? Row(
              children: [
                Expanded(child: gestionar),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: () async {
                      await SubAjustes.abrir<void>(context, NuevoEquipoScreen(sesion: s));
                      if (mounted) repo.cargar(forzar: true);
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Crear equipo', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            )
          : gestionar,
    );
  }

  /// Encabezado del acordeón: tarjeta con nombre, cantidad y flecha.
  /// Tocar la abierta no hace nada (siempre queda una abierta).
  Widget _seccion(PivotPaleta p, String titulo, int n, {required bool abierta}) {
    const dur = Duration(milliseconds: 300);
    return SliverPersistentHeader(
      pinned: true,
      delegate: _Encabezado(
        Container(
          color: p.fondo,
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
          child: AnimatedContainer(
            duration: dur,
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              color: abierta ? p.tarjeta : p.fondo,
              borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
              border: Border.all(color: abierta ? p.tarjeta : p.suave),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(PivotRadios.tarjeta),
                // Abierta: tocar de nuevo lleva al equipo o a los ajustes de
                // coaches (Victor, 2026-11-22).
                onTap: () {
                  if (!abierta) {
                    setState(() => _abierto = titulo);
                  } else if (_seEntra(titulo)) {
                    _entrar(titulo);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: dur,
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: abierta ? p.texto : p.textoSecundario),
                        child: Text(_label(titulo)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                        decoration: BoxDecoration(color: p.suave, borderRadius: BorderRadius.circular(PivotRadios.chip)),
                        child: Text(
                          '$n',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.sobreSuave),
                        ),
                      ),
                      const Spacer(),
                      // Abierta y se puede entrar: flecha hacia el costado.
                      AnimatedSwitcher(
                        duration: dur,
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: RotationTransition(turns: Tween(begin: 0.75, end: 1.0).animate(a), child: c),
                        ),
                        child: Icon(
                          abierta && _seEntra(titulo) ? Icons.chevron_right_rounded : (abierta ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                          key: ValueKey('${abierta && _seEntra(titulo)}-$abierta'),
                          color: abierta && _seEntra(titulo) ? p.texto : p.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        alto: 58,
      ),
    );
  }

  Widget _encabezado(PivotPaleta p, String titulo, int n) {
    final contenido = Container(
      color: p.fondo,
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Row(
        children: [
          Text(
            titulo,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: p.textoSecundario),
          ),
          const SizedBox(width: 6),
          Text('$n', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
        ],
      ),
    );
    return SliverPersistentHeader(pinned: true, delegate: _Encabezado(contenido));
  }

  Widget _fila(BuildContext context, Integrante x, DateTime hoy, {List<String>? motivos}) {
    final datos = datosRelevantes(x, hoy);
    return _FilaIntegrante(
      key: ValueKey('fila-${x.username}'),
      p: x,
      yo: repo.esYo(x),
      datos: datos,
      motivos: motivos,
      tick: _tick,
      alTocar: () => _abrir(x),
      // Emergencia solo para quien fue marcadx hoy a tiempo o tarde (Victor, 2026-11-07).
      emergencia: !kIsWeb && repo.esAdmin && x.presenteHoy && !repo.esYo(x) ? () => EmergenciaScreen.abrir(context, repo, x) : null,
      archivar: repo.esAdmin && x.inactivx && !repo.esYo(x) ? () => _archivar(x) : null,
    );
  }

  /// Fila de filtros activos, cada uno con su ✕ (web: badge del botón Filtros).
  Widget _filtrosActivos(PivotPaleta p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [for (final r in repo.filtroRoles) InputChip(label: Text(nombreRol(r)), onDeleted: () => repo.alternarRol(r), onPressed: _abrirFiltros)],
      ),
    );
  }

  void _abrirFiltros() {
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _HojaFiltros(repo: repo),
    );
  }

  /// Archivar desde la lista de Inactivxs (el servidor lo impide con reservas
  /// activas o cuotas pendientes y explica por qué).
  Future<void> _archivar(Integrante x) async {
    final m = ScaffoldMessenger.of(context);
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Archivar a ${x.nombreMostrar}?'),
        content: const Text(
          'Deja de aparecer en Liga. Su historial se conserva y, si vuelve a ingresar, sale de archivo y queda activx. No se puede archivar si tiene reservas activas o cuotas pendientes.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Archivar')),
        ],
      ),
    );
    if (si != true) return;
    try {
      await repo.archivar(x);
      m.showSnackBar(SnackBar(content: Text('${x.nombreMostrar} quedó archivadx')));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _resultados(BuildContext context, PivotPaleta p, List<Integrante> personas) {
    final hoy = Fechas.hoy();
    final res = BuscadorEquipo.buscar(_busqueda.text, personas, favoritos: repo.favoritos, esAdmin: repo.esAdmin, hoy: hoy);
    if (res.isEmpty) {
      return ListView(
        key: const ValueKey('sin-resultados'),
        // La barra de vidrio está encima del cuerpo: el texto empieza debajo de ella (QA 2026-11-18).
        padding: EdgeInsets.fromLTRB(32, 32 + MediaQuery.paddingOf(context).top, 32, 32),
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: p.textoSecundario),
          const SizedBox(height: 12),
          Text(
            'Nadie coincide con "${_busqueda.text.trim()}".',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.texto),
          ),
          const SizedBox(height: 8),
          Text(
            'Prueba con un nombre, un rol (${Deporte.ejemploRolBusqueda}), un mes (diciembre), "cumple", "de viaje" o un número.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: p.textoSecundario),
          ),
        ],
      );
    }
    return _envolverScroll(
      ListView.builder(
        key: const ValueKey('resultados'),
        padding: EdgeInsets.only(top: 4 + MediaQuery.paddingOf(context).top, bottom: 32),
        itemCount: res.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            final resumen = BuscadorEquipo.resumen(_busqueda.text, res, hoy: hoy);
            if (resumen == null) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: Text('${res.length} ${res.length == 1 ? 'persona' : 'personas'}', style: TextStyle(fontSize: 13, color: p.textoSecundario)),
              );
            }
            // Búsqueda por rol o por mes: la frase y los avatares de quienes coinciden.
            final visibles = res.take(5).toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resumen,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.texto),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final (j, r) in visibles.indexed)
                        Transform.translate(
                          offset: Offset(-8.0 * j, 0),
                          child: AvatarPersona(nombre: r.persona.nombreMostrar, foto: r.persona.foto, tamano: 30, borde: p.fondo),
                        ),
                      if (res.length > visibles.length)
                        Transform.translate(
                          offset: Offset(-8.0 * visibles.length + 4, 0),
                          child: Text(
                            '+${res.length - visibles.length}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.textoSecundario),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }
          final r = res[i - 1];
          return _fila(context, r.persona, hoy, motivos: r.motivos);
        },
      ),
    );
  }
}

class _Encabezado extends SliverPersistentHeaderDelegate {
  _Encabezado(this.hijo, {this.alto = 42});
  final Widget hijo;
  final double alto;

  @override
  double get minExtent => alto;
  @override
  double get maxExtent => alto;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: hijo);

  @override
  bool shouldRebuild(_Encabezado old) => true;
}

/// Avatar con un anillo de estado (de viaje, lesionadx) y Hero hacia la ficha.
class _AvatarEstado extends StatelessWidget {
  const _AvatarEstado({required this.p, this.tamano = 48, this.hero = true});
  final Integrante p;
  final double tamano;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final pal = context.pivot;
    final anillo = p.deViaje || p.lesionadx;
    final avatar = Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: anillo ? pal.marca : Colors.transparent, width: 2),
      ),
      child: AvatarPersona(nombre: p.nombreMostrar, foto: p.foto, tamano: tamano),
    );
    // Punto si se fue de viaje o se lesionó y no lo viste (Victor, 2026-11-22).
    final conPunto = Badge(isLabelVisible: AvisosLiga.actual?.nueva(p) ?? false, smallSize: 11, backgroundColor: pal.marca, child: avatar);
    return hero ? HeroAvatar(tag: 'avatar-${p.username}', child: conPunto) : conPunto;
  }
}

class _FilaIntegrante extends StatelessWidget {
  const _FilaIntegrante({
    super.key,
    required this.p,
    required this.yo,
    required this.datos,
    required this.tick,
    required this.alTocar,
    this.motivos,
    this.emergencia,
    this.archivar,
  });
  final Integrante p;
  final bool yo;
  final List<DatoFila> datos;
  final List<String>? motivos;
  final ValueNotifier<int> tick;
  final VoidCallback alTocar;
  final VoidCallback? emergencia;
  final VoidCallback? archivar;

  @override
  Widget build(BuildContext context) {
    final pal = context.pivot;
    final reducir = MediaQuery.of(context).disableAnimations;
    return InkWell(
      onTap: alTocar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            _AvatarEstado(p: p),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.nombreMostrar,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: pal.texto),
                        ),
                      ),
                      if (p.numero.isNotEmpty) Text('  #${p.numero}', style: TextStyle(fontSize: 13, color: pal.textoSecundario)),
                      // Solo Pivots: tiene las notificaciones apagadas (Victor, 2026-11-18).
                      if (p.avisosApagados && !yo) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Notificaciones apagadas',
                          child: Icon(Icons.notifications_off_outlined, size: 16, color: pal.textoSecundario),
                        ),
                      ],
                      if (yo) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: pal.suave, borderRadius: BorderRadius.circular(PivotRadios.chip)),
                          child: Text(
                            'Tú',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pal.sobreSuave),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  // En la búsqueda: por qué aparece. En la lista: el dato que rota.
                  if (motivos != null)
                    Text(
                      motivos!.isEmpty ? (p.roles.isEmpty ? '@${p.username}' : p.roles.map(nombreRol).join(' · ')) : motivos!.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: pal.textoSecundario),
                    )
                  else
                    ValueListenableBuilder<int>(
                      valueListenable: tick,
                      builder: (context, n, _) {
                        final rota = datos.where((d) => !d.fijo).toList();
                        final DatoFila? dato = datos.isEmpty ? null : (datos.first.fijo || rota.length <= 1 || reducir ? datos.first : rota[n % rota.length]);
                        final linea = dato == null
                            ? Text(
                                p.roles.isEmpty ? '@${p.username}' : p.roles.map(nombreRol).join(' · '),
                                key: const ValueKey('base'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: pal.textoSecundario),
                              )
                            : Row(
                                key: ValueKey(dato.texto),
                                children: [
                                  Icon(dato.icono, size: 15, color: pal.marcaTexto),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      dato.texto,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: pal.marcaTexto),
                                    ),
                                  ),
                                ],
                              );
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 450),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          layoutBuilder: (actual, previos) => Stack(alignment: Alignment.centerLeft, children: [...previos, ?actual]),
                          child: linea,
                        );
                      },
                    ),
                ],
              ),
            ),
            if (emergencia != null)
              IconButton(
                tooltip: 'Emergencia',
                onPressed: emergencia,
                icon: Icon(Icons.emergency_outlined, color: pal.marcaTexto),
              ),
            if (archivar != null)
              IconButton(
                tooltip: 'Archivar',
                onPressed: archivar,
                icon: Icon(Icons.archive_outlined, color: pal.textoSecundario),
              ),
          ],
        ),
      ),
    );
  }
}

/// Contenido de una sección del acordeón: se abre y cierra deslizando la
/// altura (desde arriba) con fundido; la que se cierra y la que se abre usan
/// la misma curva y duración, así el resto de la lista no da saltos.
class _Plegable extends StatefulWidget {
  const _Plegable({required this.abierto, required this.child});
  final bool abierto;
  final Widget child;

  @override
  State<_Plegable> createState() => _PlegableState();
}

class _PlegableState extends State<_Plegable> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 340), value: widget.abierto ? 1 : 0);
  late final _altura = CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);
  late final _opacidad = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
    reverseCurve: const Interval(0.5, 1, curve: Curves.easeIn),
  );

  @override
  void didUpdateWidget(_Plegable old) {
    super.didUpdateWidget(old);
    if (old.abierto == widget.abierto) return;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = widget.abierto ? 1 : 0;
    } else {
      widget.abierto ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      // Cerrada del todo no se construye (ni rota su dato).
      builder: (context, hijo) => _c.isDismissed
          ? const SizedBox(width: double.infinity)
          : ClipRect(
              child: SizeTransition(
                sizeFactor: _altura,
                alignment: Alignment.topCenter,
                child: FadeTransition(opacity: _opacidad, child: hijo),
              ),
            ),
      child: widget.child,
    );
  }
}

/// Filtros de Equipo: período de los stats (mes o histórico) y roles.
class _HojaFiltros extends StatelessWidget {
  const _HojaFiltros({required this.repo});
  final EquipoRepo repo;

  @override
  Widget build(BuildContext context) {
    final p = context.pivot;
    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        t,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: p.textoSecundario),
      ),
    );
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Filtros', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: repo.hayFiltros ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(onPressed: repo.hayFiltros ? repo.limpiarFiltros : null, child: const Text('Limpiar')),
                  ),
                ],
              ),
            ),
            titulo('Roles'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final r in repo.rolesCatalogo)
                    FilterChip(label: Text(nombreRol(r)), selected: repo.filtroRoles.contains(r), onSelected: (_) => repo.alternarRol(r)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Listo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
