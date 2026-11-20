// "Social o fiesta" (antes "Social"; Naviquinde, Victor 2026-11-19/20; ver
// NAVIQUINDE.md y las migraciones 20261119120000_evento_social.sql y
// 20261120100000_social_o_fiesta.sql). Módulo propio para no mezclarse con
// el resto de index.ts: `index.ts` solo deriva aquí las acciones de
// ACCIONES_SOCIAL con sus helpers (cliente de la liga, sesión, push).
//
// El valor guardado sigue siendo asistencias.tipo_evento = 'Social'. Se arma
// por piezas (amigo secreto, regalo robado, comida, +1, playlist, dress code,
// qué traer, homenaje, premios).
//
// Quién pide:
//  - cuenta de la liga: `token` de sesión (clave = username). Cualquiera crea
//    uno (`socialCrear`); quien lo crea y sus encargadxs lo editan;
//  - invitadx +1 sin cuenta: `invitadoToken` (clave = 'inv:<id>'). Solo ve lo
//    suyo, su amigo secreto y la comida (sin nombres de otras personas);
//  - Pivot: `adminToken`. Aprueba antes de que se publique (nunca una persona
//    homenajeada ni alguien que no debe enterarse; si no queda ningún Pivot
//    que pueda, se publica solo) y también organiza.
//
// Sorpresa: lxs homenajeadxs y quienes no deben enterarse reciben la vista
// "neutral" (nombre neutro, lugar y hora; sin motivo, homenaje, mensajes,
// regalo, premios ni la palabra sorpresa). Se aplica aquí, en el servidor:
// nunca se manda al cliente lo que no debe ver (reglas en social_reglas.ts).
//
// Sin la migración 20261120100000: las filas no traen las columnas nuevas y
// todo evento social cuenta como publicado y sin piezas nuevas (como en la
// primera versión); solo `socialCrear` y las piezas nuevas fallan con aviso.

import { type ParticipanteSorteo, sortearAmigoSecreto } from './social_sorteo.ts';
import { aplicar, type EstadoJuego, nuevoJuego, plantillaReglasRobado, reglasJuego, vistaJuego } from './social_juego.ts';
import {
  aprobadores, cambiosPara, diferencias, encargadxs, estaInvitadx, esSecretoPara, etiquetaSorpresa, type Foto, homenajeadxs, listaEs, mensajesAbiertos, soloImportantes,
  noEnterarse, PIEZAS_ELEGIBLES, personasEnSecreto, piezaVisible, publicado, puedeAprobar, tituloPara, type Vista, vistaDe,
} from './social_reglas.ts';

export interface DepsSocial {
  db: any;
  validarToken: (t: string) => Promise<string | null>;
  validarAdminToken: (t: string) => Promise<string | null>;
  ligaEnCurso: () => string;
  push?: (p: any) => Promise<unknown>;
  /// Pivots de la liga con su cuenta (`_administradorxs` de index.ts).
  pivots?: () => Promise<{ username: string; email: string; nombre?: string }[]>;
    appUrl: string;
  /// Áreas de un Pivot por email (`_areasDe` de index.ts).
  areasDe?: (email: string) => Promise<string[]>;
}

export const ACCIONES_SOCIAL = new Set([
  'socialGet', 'socialCrear', 'socialGuardarConfig', 'socialAgregarInvitado', 'socialQuitarInvitado', 'socialGuardarPerfil',
  'socialRevelar', 'socialAnotarComida', 'socialQuitarAporte', 'socialSortear',
  'socialEquipo', 'socialAprobar', 'socialRechazar',
        'socialAnotarTraer', 'socialQuitarTraer', 'socialMensaje', 'socialAportarRegalo', 'socialLiberarMensajes', 'socialComidaEditar', 'socialInvitadoNombre',
    'socialJuego', 'socialEditarPieza',
]);

/// Plantilla de reglas del regalo robado (editable por quien organiza).
/// Sin monto (Victor, 2026-11-20): el tope se muestra aparte. Reglas viejas con `{tope}` se reemplazan en la app.
export const PLANTILLA_REGALO_ROBADO = [
  '1. Cada persona trae un regalo envuelto y sin nombre. Solo juega quien trajo regalo.',
  '2. Todos los regalos se ponen juntos en una pila.',
  '3. Se sortea el orden de los turnos.',
  '4. En tu turno eliges: abres un regalo de la pila o robas uno que ya esté abierto.',
  '5. Si te roban, vuelves a elegir: abres uno de la pila o robas otro, pero no el que te acaban de quitar.',
  '6. Un mismo regalo se puede robar como máximo 3 veces. Al tercer robo se queda con esa persona.',
  '7. El juego termina cuando se abre el último regalo de la pila. Quien tuvo el primer turno puede, al final, cambiar su regalo por otro que todavía se pueda robar.',
  '8. Lo importante es pasarla bien juntxs: nada de enojos por un regalo.',
].join('\n');

const PLANTILLAS = ['fiesta', 'festividad', 'cumpleanos', 'aniversario', 'despedida', 'personalizado'];

type Quien = {
  tipo: 'miembro' | 'invitado' | 'pivot';
  clave: string | null;
  /// Cuenta de la persona (también la de un Pivot que entra solo con adminToken, si tiene fila en `equipo`).
  username: string | null;
  categoria: string | null;
  nombre: string;
  idEvento: string;
  invitado?: any;
  esPivot: boolean;
  pivotEmail: string | null;
};

const MAX_INVITADOS = 5;

/// Cuántxs +1 puede sumar cada persona (lo elige quien organiza; por defecto 1).
function _maxInvitados(v: unknown): number {
  const n = Math.floor(Number(v));
  return Number.isFinite(n) && n >= 1 ? Math.min(n, MAX_INVITADOS) : 1;
}
const MAX_LISTA = 30;
const MAX_WISHLIST = 20;
const MAX_FAVORITOS = 2;
// Cierre del amigo secreto (Victor, 2026-11-20): por defecto 2 semanas antes;
// quien organiza puede elegir cualquier fecha hasta 1 día antes del evento.
const DIAS_CIERRE = 14;
const DIAS_CIERRE_MIN = 1;
const FALTA_MIGRACION = 'Falta aplicar la migración del Social o fiesta (20261120100000). Avísale a un Pivot.';

function _texto(v: unknown, max: number): string {
  return String(v ?? '').replace(/\s+/g, ' ').trim().slice(0, max);
}

function _textoLargo(v: unknown, max: number): string {
  return String(v ?? '').replace(/\r/g, '').replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim().slice(0, max);
}

function _json(v: unknown): any {
  if (typeof v !== 'string') return v;
  try {
    return JSON.parse(v);
  } catch {
    return null;
  }
}

function _num(v: unknown): number | null {
  if (v === null || v === undefined || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

function _tokenNuevo(): string {
  const b = crypto.getRandomValues(new Uint8Array(24));
  return btoa(String.fromCharCode(...b)).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function _idCorto(): string {
  return crypto.randomUUID().substring(0, 8);
}

/** Ícono del calendario: el elegido, el de la festividad o el de la plantilla. */
const ICONO_FESTIVIDAD: Record<string, string> = { 'Navidad': 'navidad', 'Año nuevo': 'anio_nuevo', 'Halloween': 'halloween', 'Pascua': 'pascua' };
const ICONO_PLANTILLA: Record<string, string> = { cumpleanos: 'cumple', aniversario: 'aniversario', despedida: 'despedida' };
function _iconoSocial(cfg: any): string {
  return _piezas(cfg).icono || ICONO_FESTIVIDAD[cfg?.festividad ?? ''] || ICONO_PLANTILLA[cfg?.plantilla ?? ''] || 'fiesta';
}

/** 2 semanas antes; si eso ya pasó, el día anterior al evento. */
function _cierreDefecto(fecha: string): string {
  const d = _restarDias(fecha, DIAS_CIERRE);
  return d >= _hoyEc() ? d : _restarDias(fecha, DIAS_CIERRE_MIN);
}

function _restarDias(iso: string, dias: number): string {
  const d = new Date(iso.substring(0, 10) + 'T12:00:00Z');
  d.setUTCDate(d.getUTCDate() - dias);
  return d.toISOString().substring(0, 10);
}

function _ahoraEc(): string {
  return new Date(Date.now() - 5 * 3600 * 1000).toISOString();
}

function _hoyEc(): string {
  return _ahoraEc().substring(0, 10);
}

function _url(deps: DepsSocial, idEvento: string): string {
  return `${deps.appUrl.replace(/\/+$/, '')}/?evento=${encodeURIComponent(idEvento)}`;
}

function _esFaltaColumna(e: any): boolean {
  const m = String(e?.message ?? '');
  return /column|schema cache|does not exist|relation/i.test(m);
}

export async function accionSocial(action: string, params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  try {
    switch (action) {
      case 'socialGet': return await socialGet(params, deps);
      case 'socialCrear': return await socialCrear(params, deps);
            case 'socialGuardarConfig': return await socialGuardarConfig(params, deps);
            case 'socialComidaEditar': return await socialComidaEditar(params, deps);
      case 'socialInvitadoNombre': return await socialInvitadoNombre(params, deps);
      case 'socialAgregarInvitado': return await socialAgregarInvitado(params, deps);
      case 'socialQuitarInvitado': return await socialQuitarInvitado(params, deps);
      case 'socialGuardarPerfil': return await socialGuardarPerfil(params, deps);
      case 'socialRevelar': return await socialRevelar(params, deps);
      case 'socialAnotarComida': return await socialAnotarComida(params, deps);
      case 'socialQuitarAporte': return await socialQuitarAporte(params, deps);
      case 'socialSortear': return await socialSortear(params, deps);
      case 'socialEquipo': return await socialEquipo(params, deps);
      case 'socialAprobar': return await socialAprobar(params, deps);
      case 'socialRechazar': return await socialRechazar(params, deps);
      case 'socialAnotarTraer': return await socialAnotarTraer(params, deps);
      case 'socialQuitarTraer': return await socialQuitarTraer(params, deps);
      case 'socialMensaje': return await socialMensaje(params, deps);
            case 'socialAportarRegalo': return await socialAportarRegalo(params, deps);
            case 'socialJuego': return await socialJuego(params, deps);
      case 'socialEditarPieza': return await socialEditarPieza(params, deps);
      case 'socialLiberarMensajes': return await socialLiberarMensajes(params, deps);
    }
    return { exito: false, error: 'Acción desconocida: ' + action };
  } catch (e) {
    return { exito: false, error: (e as Error).message ?? 'Error interno.' };
  }
}

// ─── Identidad y lecturas comunes ─────────────────────────────────────────

async function _cuentaDePivot(db: any, email: string): Promise<any | null> {
  const { data } = await db.from('equipo').select('username, nombre_derby, categoria').ilike('email', email).is('eliminado_en', null).limit(1);
  return (data ?? [])[0] ?? null;
}

async function _quien(params: Record<string, any>, deps: DepsSocial): Promise<Quien | { error: string }> {
  const pivotEmail = params.adminToken ? await deps.validarAdminToken(String(params.adminToken)) : null;
  if (params.invitadoToken) {
    const { data: inv } = await deps.db.from('social_invitados').select('*').eq('token', String(params.invitadoToken)).maybeSingle();
    if (!inv) return { error: 'Este enlace ya no es válido. Pide uno nuevo a quien te invitó.' };
    return { tipo: 'invitado', clave: 'inv:' + inv.id, username: null, categoria: null, nombre: inv.nombre, idEvento: inv.id_evento, invitado: inv, esPivot: false, pivotEmail: null };
  }
  const idEvento = _texto(params.idEvento, 200);
  if (!idEvento) return { error: 'Evento inválido.' };
  const username = params.token ? await deps.validarToken(String(params.token)) : null;
  if (username) {
    const { data: eq } = await deps.db.from('equipo').select('username, nombre_derby, categoria').eq('username', username).maybeSingle();
    const nombre = (eq?.nombre_derby ?? '').trim() || username;
    return { tipo: 'miembro', clave: username, username, categoria: eq?.categoria ?? null, nombre, idEvento, esPivot: !!pivotEmail, pivotEmail };
  }
  if (pivotEmail) {
    const cuenta = await _cuentaDePivot(deps.db, pivotEmail);
    return {
      tipo: 'pivot', clave: null, username: cuenta?.username ?? null, categoria: cuenta?.categoria ?? null,
      nombre: (cuenta?.nombre_derby ?? '').trim() || cuenta?.username || pivotEmail, idEvento, esPivot: true, pivotEmail,
    };
  }
  return { error: 'Tu sesión venció. Vuelve a iniciar sesión.' };
}

async function _config(db: any, idEvento: string): Promise<any | null> {
  const { data } = await db.from('social_eventos').select('*').eq('id_evento', idEvento).maybeSingle();
  return data ?? null;
}

async function _evento(db: any, idEvento: string): Promise<any | null> {
  const { data } = await db.from('asistencias').select('id_evento, fecha, donde, inicia, termina, tipo_evento, estado, info_adicional, google_maps, id_regla').eq('id_evento', idEvento).maybeSingle();
  return data ?? null;
}

/// Qué ve quien pide. Lx +1 hereda de quien lx invitó (si a esa persona se le
/// esconde la sorpresa, a su +1 también).
function _vista(q: Quien, cfg: any): Vista {
  if (q.tipo === 'invitado') {
    if (!cfg) return 'completa';
    if (!publicado(cfg)) return 'oculta';
    return esSecretoPara(cfg, q.invitado.anfitrion) ? 'neutral' : 'completa';
  }
  return vistaDe(cfg, { username: q.username, esPivot: q.esPivot, categoria: q.categoria });
}

function _organiza(q: Quien, cfg: any): boolean {
  return _vista(q, cfg) === 'organiza';
}

// ─── Permisos de lxs encargadxs (Victor, 2026-11-20) ──────────────────────
// Regla de oro: quien crea el evento edita todo (los Pivots también). Cada
// encargadx edita solo sus áreas; sin permisos guardados, todo menos homenaje.
export const AREAS_SOCIAL = ['fecha', 'amigo', 'comida', 'extras', 'invitados', 'homenaje'] as const;
const AREAS_POR_DEFECTO = ['fecha', 'amigo', 'comida', 'extras', 'invitados'];

/// null = puede editar todo; si no, las áreas que le tocan.
function _misPermisos(q: Quien, cfg: any): string[] | null {
  if (!cfg || q.esPivot || (q.username && q.username === cfg.creador)) return null;
  const p = cfg.permisos && typeof cfg.permisos === 'object' ? cfg.permisos[q.username ?? ''] : null;
  return Array.isArray(p) ? p.filter((x: unknown) => (AREAS_SOCIAL as readonly string[]).includes(String(x))) : AREAS_POR_DEFECTO;
}

/// Saca de los datos del asistente lo que esa persona no puede cambiar.
/// Las piezas se mezclan con las guardadas: solo cambian las de sus áreas.
export function _filtrarPorPermisos(d: any, areas: string[], previa: any): any {
  const puede = (a: string) => areas.includes(a);
  const out: any = {};
  const copiar = (k: string) => { if (d[k] !== undefined) out[k] = d[k]; };
  if (puede('fecha')) ['fecha', 'inicia', 'termina', 'lugar', 'mapa'].forEach(copiar);
  if (puede('amigo')) ['topeAmigo', 'topeRobado', 'recordatorioRobado', 'reglasRobado', 'cierre'].forEach(copiar);
  if (puede('comida')) copiar('categorias');
  if (puede('homenaje')) ['sorpresa', 'homenajeados', 'noEnterarse', 'nombreNeutro', 'regaloTope', 'regaloCompra'].forEach(copiar);
  const m = d.modulos ?? {};
  const modulos: any = {};
  if (puede('amigo')) (modulos.amigoSecreto = m.amigoSecreto, modulos.regaloRobado = m.regaloRobado);
  if (puede('comida')) modulos.comida = m.comida;
  if (puede('invitados')) modulos.invitados = m.invitados;
  out.modulos = Object.fromEntries(Object.entries(modulos).filter(([, v]) => v !== undefined));
  if (d.piezas !== undefined) {
    const antes = _piezas(previa);
    const nuevas = d.piezas && typeof d.piezas === 'object' ? d.piezas : {};
            const porArea: Record<string, string[]> = {
      amigo: ['noTocar', 'juegoRobado'], comida: ['traer'], extras: ['playlist', 'dress', 'premios'], homenaje: ['homenaje', 'ocultas'], invitados: ['maxInvitados'],
    };
    const piezas: any = { ...antes };
    for (const [area, claves] of Object.entries(porArea)) {
      if (!puede(area)) continue;
      for (const k of claves) {
        if (nuevas[k] !== undefined) piezas[k] = nuevas[k];
        else delete piezas[k];
      }
    }
    out.piezas = piezas;
  }
  return out;
}

function _piezas(cfg: any): Record<string, any> {
  return cfg?.piezas && typeof cfg.piezas === 'object' ? cfg.piezas : {};
}

/// Usernames con "Asistiré" como última respuesta.
async function _asistentes(db: any, idEvento: string): Promise<Set<string>> {
  const { data } = await db.from('log_asistencias').select('nombre_usuario, estado, marca_temporal, origen')
    .eq('id_evento', idEvento).in('origen', ['Usuario', 'AsistenciaAnticipada']).order('marca_temporal', { ascending: true });
  const ultimo = new Map<string, string>();
  for (const f of data ?? []) ultimo.set(String(f.nombre_usuario), String(f.estado));
  return new Set([...ultimo].filter(([, e]) => e === 'Asistiré').map(([u]) => u));
}

async function _invitados(db: any, idEvento: string): Promise<any[]> {
  const { data } = await db.from('social_invitados').select('*').eq('id_evento', idEvento).order('created_at');
  return data ?? [];
}

async function _personas(db: any, usernames: string[]): Promise<Map<string, { nombre: string; foto: string }>> {
  const out = new Map<string, { nombre: string; foto: string }>();
  const unicos = [...new Set(usernames.filter(Boolean))];
  if (!unicos.length) return out;
  const { data } = await db.from('equipo').select('username, nombre_derby, foto_perfil').in('username', unicos);
  for (const r of data ?? []) out.set(r.username, { nombre: (r.nombre_derby ?? '').trim() || r.username, foto: r.foto_perfil ?? '' });
  for (const u of unicos) if (!out.has(u)) out.set(u, { nombre: u, foto: '' });
  return out;
}

const PERFIL_VACIO = { gustos: [], sobreMi: [], noRegalar: [], tallas: {}, wishlist: [], wishlistLink: '' };

function _perfilSalida(r: any): Record<string, any> {
  if (!r) return { ...PERFIL_VACIO };
    return {
    gustos: r.gustos ?? [], sobreMi: r.sobre_mi ?? [], noRegalar: r.no_regalar ?? [], tallas: r.tallas ?? {}, wishlist: r.wishlist ?? [],
    wishlistLink: r.wishlist_link ?? '',
  };
}

async function _perfil(db: any, liga: string, clave: string): Promise<Record<string, any>> {
  const { data } = await db.from('social_perfiles').select('*').eq('liga_id', liga).eq('clave', clave).maybeSingle();
  return _perfilSalida(data);
}

/// Ficha de quien te tocó: nombre, foto y sus pistas/wishlist. Nada más.
async function _ficha(db: any, liga: string, clave: string): Promise<Record<string, any>> {
  const perfil = await _perfil(db, liga, clave);
  if (clave.startsWith('inv:')) {
    const { data: inv } = await db.from('social_invitados').select('nombre, anfitrion').eq('id', clave.substring(4)).maybeSingle();
    const host = inv ? (await _personas(db, [inv.anfitrion])).get(inv.anfitrion)?.nombre : null;
    return { nombre: inv?.nombre ?? 'Invitadx', foto: '', invitadxDe: host ?? null, ...perfil };
  }
  const p = (await _personas(db, [clave])).get(clave)!;
  return { nombre: p.nombre, foto: p.foto, invitadxDe: null, ...perfil };
}

/// Quiénes entran al amigo secreto: asistentes + sus +1 (el grupo es la persona que invita).
function _participantes(asisten: Set<string>, invitados: any[]): ParticipanteSorteo[] {
  return [
    ...[...asisten].map((u) => ({ clave: u, grupo: u })),
        ...invitados.filter((i) => asisten.has(i.anfitrion) && !!i.nombre).map((i) => ({ clave: 'inv:' + i.id, grupo: i.anfitrion })),
  ];
}

function _enlace(deps: DepsSocial, token: string): string {
  return `${deps.appUrl.replace(/\/+$/, '')}/?social=${encodeURIComponent(token)}`;
}

/// Si quien pide participa del evento: Asistiré, o +1 de alguien que asiste.
function _asiste(q: Quien, asisten: Set<string>): boolean {
  if (q.tipo === 'invitado') return asisten.has(q.invitado.anfitrion);
  return !!q.clave && asisten.has(q.clave);
}

/// ¿Ya terminó el evento? (hora de pared de Ecuador).
function _termino(ev: any): boolean {
  const hoy = _hoyEc();
  const fecha = String(ev?.fecha ?? '').substring(0, 10);
  if (!fecha || fecha < hoy) return !!fecha;
  if (fecha > hoy) return false;
  const fin = String(ev?.termina ?? '').substring(0, 5);
  return !!fin && _ahoraEc().substring(11, 16) >= fin;
}

function _estado(cfg: any): 'publicado' | 'rechazado' | 'por_aprobar' {
  if (publicado(cfg)) return 'publicado';
  return cfg?.rechazado_en ? 'rechazado' : 'por_aprobar';
}

// ─── socialGet ────────────────────────────────────────────────────────────

async function socialGet(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  const ev = await _evento(db, q.idEvento);
  if (!ev) return { exito: false, error: 'No encontramos este evento.' };
  const cfg = await _config(db, q.idEvento);
  const { data: ligaRow } = await db.from('ligas').select('nombre, moneda').eq('id', liga).maybeSingle();
  const vista = _vista(q, cfg);
  if (vista === 'oculta') return { exito: false, error: 'Este evento todavía no está publicado.' };
  const neutral = vista === 'neutral', organiza = vista === 'organiza', esInv = q.tipo === 'invitado';
  const evento = {
    id: ev.id_evento, fecha: ev.fecha, lugar: ev.donde, inicia: ev.inicia, termina: ev.termina, tipo: ev.tipo_evento,
    estado: ev.estado, info: neutral ? '' : (ev.info_adicional ?? ''), mapa: esInv ? (ev.google_maps ?? '') : undefined,
    liga: ligaRow?.nombre ?? '', moneda: ligaRow?.moneda ?? '',
  };
  if (!cfg) return { exito: true, social: null, evento, esPivot: q.esPivot, organiza, vista };

  const piezas = _piezas(cfg);
  // Sorpresa por pieza: la vista neutral no recibe las piezas que se le esconden.
  const ve = (k: string) => piezaVisible(cfg, k, vista);
  const hom = homenajeadxs(cfg);
  const yoHomenajeadx = !!q.username && hom.includes(q.username);
  const [asisten, invitados, sorteo, personas] = await Promise.all([
    _asistentes(db, q.idEvento),
    _invitados(db, q.idEvento),
    db.from('social_sorteo').select('da, recibe, revelado_en').eq('id_evento', q.idEvento).then((r: any) => r.data ?? []),
    _personas(db, [...hom, ...noEnterarse(cfg), ...encargadxs(cfg), cfg.creador ?? '', cfg.regalo_compra ?? '']),
  ]);
  const nombreDe = (u: string) => personas.get(u)?.nombre ?? u;
    // Un +1 cuenta desde que abre su enlace y escribe su nombre.
  const invitadosQueCuentan = invitados.filter((i) => asisten.has(i.anfitrion) && !!i.nombre);
  const total = asisten.size + invitadosQueCuentan.length;
    const cierre = cfg.cierre ?? _cierreDefecto(ev.fecha);
  // Lo que ve la vista neutral: nada del motivo, del homenaje ni de la sorpresa.
  const social: Record<string, any> = {
    amigoSecreto: !!cfg.amigo_secreto && ve('amigoSecreto'), regaloRobado: !!cfg.regalo_robado && ve('regaloRobado'),
    comida: !!cfg.comida && ve('comida'), invitados: !!cfg.invitados && ve('invitados'),
        topeAmigo: cfg.tope_amigo, topeRobado: cfg.tope_robado, recordatorioRobado: cfg.recordatorio_robado ?? '',
    // Para editar desde las tarjetas (Victor, 2026-11-20).
    maxInvitados: _maxInvitados(_piezas(cfg).maxInvitados), juegoOpciones: reglasJuego(_piezas(cfg).juegoRobado), reglasPropias: cfg.reglas_robado ?? '',
    cierre, inscripcionAbierta: !cfg.sorteado_en && _hoyEc() <= cierre, sorteado: !!cfg.sorteado_en,
        // Sin reglas propias, la plantilla sigue las opciones del juego (Victor, 2026-11-20).
    reglasRobado: cfg.reglas_robado ?? plantillaReglasRobado(reglasJuego(_piezas(cfg).juegoRobado)), reglasPorDefecto: !cfg.reglas_robado,
    titulo: tituloPara(cfg, vista, nombreDe),
    sorpresa: esInv ? null : etiquetaSorpresa(cfg, vista, nombreDe),
    plantilla: neutral ? null : (cfg.plantilla ?? null),
    festividad: neutral ? null : (cfg.festividad ?? null),
    descripcion: neutral ? '' : (cfg.descripcion ?? ''),
    estado: _estado(cfg),
    rechazoMotivo: organiza ? (cfg.rechazo_motivo ?? '') : '',
    aprobado: publicado(cfg),
    playlist: piezas.playlist && ve('playlist') ? { link: piezas.playlist.link ?? '', nota: piezas.playlist.nota ?? '' } : null,
    dress: piezas.dress && ve('dress') ? { texto: piezas.dress.texto ?? '' } : null,
    traer: !!piezas.traer && ve('traer'),
    premios: !neutral && !esInv && piezas.premios ? (piezas.premios.lista ?? []) : null,
    // Lxs +1 (de alguien que no está en las listas) ven el homenaje solo para aportar al regalo.
    homenaje: !neutral && !yoHomenajeadx && !!piezas.homenaje && hom.length > 0 && (!esInv || piezas.homenaje.regalo === true),
  };

  const out: Record<string, any> = { exito: true, social, evento, esPivot: q.esPivot, tipo: q.tipo, organiza, vista };
    out.yo = { nombre: q.nombre, asiste: _asiste(q, asisten), anfitrion: null as string | null, necesitaNombre: esInv && !q.nombre };
  if (esInv) out.yo.anfitrion = (await _personas(db, [q.invitado.anfitrion])).get(q.invitado.anfitrion)?.nombre ?? '';
  // Lxs +1 no ven la lista de asistentes, solo cuántxs son (para la comida).
  out.conteo = { asistentes: asisten.size, invitados: invitadosQueCuentan.length, total };

  if (q.tipo !== 'invitado' && q.clave) {
    out.misInvitados = invitados.filter((i) => i.anfitrion === q.clave).map((i) => ({
            id: i.id, nombre: i.nombre, contacto: i.contacto ?? '', enlace: _enlace(deps, i.token), entro: !!i.nombre,
      enSorteo: sorteo.some((s: any) => s.da === 'inv:' + i.id),
    }));
  }
  if (q.clave) out.perfil = await _perfil(db, liga, q.clave);

  // Amigo secreto: estado y, si ya se reveló, la ficha de quien le tocó.
  if (social.amigoSecreto && q.clave) {
    const mio = sorteo.find((s: any) => s.da === q.clave);
    if (!cfg.sorteado_en) out.amigo = { estado: 'sin_sorteo' };
    else if (!mio) out.amigo = { estado: 'fuera' };
    else if (!mio.revelado_en) out.amigo = { estado: 'por_revelar' };
    else out.amigo = { estado: 'revelado', ficha: await _ficha(db, liga, mio.recibe) };
  }

    // Regalo robado en vivo: si ya empezó, quién dirige y si es el día.
  if (social.regaloRobado) {
    const { data: jr } = await db.from('social_regalo_juego').select('estado').eq('id_evento', q.idEvento).maybeSingle();
    out.juegoRobado = { fase: jr?.estado?.fase ?? null, dirige: _dirigeJuego(q, cfg), hoy: ev.fecha === _hoyEc() };
  }

  if (social.comida) {
    const { data: cats } = await db.from('social_comida_categorias').select('*').eq('id_evento', q.idEvento).order('orden');
    const ids = (cats ?? []).map((c: any) => c.id);
    const { data: aportes } = ids.length
      ? await db.from('social_comida_aportes').select('*').in('categoria_id', ids).order('created_at')
            : { data: [] };
    // Fotos de quienes llevan algo (para los avatares de la lista).
    const fotos = await _personas(db, [...new Set<string>((aportes ?? []).map((a: any) => String(a.clave)).filter((k: string) => !k.startsWith("inv:")))]);
    out.comida = (cats ?? []).map((c: any) => {
      const ap = (aportes ?? []).filter((a: any) => a.categoria_id === c.id);
      const aportado = ap.reduce((s: number, a: any) => s + Number(a.cantidad ?? 0), 0);
                        const meta = _metaSeccion(c, total);
      const limite = _limiteSeccion(c, total);
      const mias = ap.filter((a: any) => a.clave === q.clave);
      return {
        id: c.id, nombre: c.nombre, unidad: c.unidad, porPersona: Number(c.por_persona ?? 0), meta, aportado,
        modo: c.modo ?? 'meta', total: c.total == null ? null : Number(c.total),
        mias: c.modo === 'cada' || c.modo === 'libre' ? mias.length : mias.reduce((s: number, a: any) => s + Number(a.cantidad ?? 0), 0),
        falta: c.falta === true, sugerencias: Array.isArray(c.sugerencias) ? c.sugerencias : [],
                cupoTipo: c.cupo_tipo ?? '', cupo: c.cupo == null ? null : Number(c.cupo), limite,
        cerrada: (meta > 0 && aportado >= meta) || (limite > 0 && aportado >= limite),
        // Lxs +1 solo ven lo que llevan ellxs.
        aportes: ap.filter((a: any) => !esInv || a.clave === q.clave).map((a: any) => ({
                    id: a.id, nombre: a.nombre, cantidad: Number(a.cantidad), detalle: a.detalle ?? '', mio: a.clave === q.clave, paraTodxs: a.para_todxs ?? null,
          foto: fotos.get(a.clave)?.foto ?? '',
        })),
      };
    });
  }

  // Qué traer: lo arma quien organiza; cada quien se anota.
  if (social.traer) {
    const items: any[] = Array.isArray(piezas.traer.items) ? piezas.traer.items : [];
    const { data: anotes } = await db.from('social_traer_anotes').select('*').eq('id_evento', q.idEvento).order('created_at');
    out.traer = items.map((it: any) => {
      const de = (anotes ?? []).filter((a: any) => a.item === it.id);
      const cantidad = _num(it.cantidad);
      return {
        id: it.id, texto: it.texto, cantidad, anotados: de.length, completo: !!cantidad && de.length >= cantidad,
        personas: de.filter((a: any) => !esInv || a.clave === q.clave).map((a: any) => ({ id: a.id, nombre: a.nombre, detalle: a.detalle ?? '', mio: a.clave === q.clave })),
      };
    });
  }

  // Homenaje (nunca para la vista neutral, lxs +1 ni lxs homenajeadxs).
  if (social.homenaje) {
    const h = piezas.homenaje ?? {};
    const bloque: Record<string, any> = {
      personas: hom.map((u) => ({ username: u, nombre: nombreDe(u), foto: personas.get(u)?.foto ?? '' })),
      liberados: !!cfg.mensajes_liberados_en,
      mensajes: h.mensajes !== false && !esInv,
      regalo: null,
    };
    if (h.mensajes !== false && !esInv) {
      const { data: ms } = await db.from('social_mensajes').select('para, clave, texto').eq('id_evento', q.idEvento);
      const conteo: Record<string, number> = {};
      const mios: Record<string, string> = {};
      for (const m of ms ?? []) {
        conteo[m.para] = (conteo[m.para] ?? 0) + 1;
        if (m.clave === q.clave) mios[m.para] = m.texto;
      }
      bloque.conteo = conteo;
      bloque.mios = mios;
    }
    if (h.regalo) {
      const { data: ap } = await db.from('social_regalo_aportes').select('*').eq('id_evento', q.idEvento).order('created_at');
      const todos = (ap ?? []).map((a: any) => ({ id: a.id, nombre: a.nombre, monto: Number(a.monto), mio: a.clave === q.clave }));
      // Lxs +1 ven el total y lo suyo, no los nombres del resto.
      const lista = esInv ? todos.filter((a: any) => a.mio) : todos;
      bloque.regalo = {
        tope: cfg.regalo_tope == null ? null : Number(cfg.regalo_tope),
        nota: _texto(h.regaloNota, 300),
        compra: cfg.regalo_compra ? { username: cfg.regalo_compra, nombre: nombreDe(cfg.regalo_compra) } : null,
        aportes: lista,
        total: todos.reduce((s: number, a: any) => s + a.monto, 0),
      };
    }
    out.homenaje = bloque;
  }
    // Personas a cargo con su contacto (Victor, 2026-11-20), para consultarles
  // dudas. Solo para gente de la liga (lxs +1 no ven teléfonos).
  if (!esInv) {
    const aCargo = [...new Set([cfg.creador, ...encargadxs(cfg)].filter((u: unknown) => typeof u === 'string' && u && !String(u).includes('@')))] as string[];
    if (aCargo.length) {
            const { data: cs } = await db.from('equipo').select('username, nombre_derby, foto_perfil, telefono, prefijo, email, pronombres').in('username', aCargo);
            // De qué está a cargo cada quien (Victor, 2026-11-20), solo con lo que el evento tiene
      // y sin delatar el homenaje a quien no debe saberlo.
      const etiquetas = (u: string): string[] => {
        if (u === cfg.creador) return [];
        const p = cfg.permisos && typeof cfg.permisos === 'object' ? cfg.permisos[u] : null;
        const areas: string[] = Array.isArray(p) ? p : AREAS_POR_DEFECTO;
        const amigo = [cfg.amigo_secreto && 'el amigo secreto', cfg.regalo_robado && 'el regalo robado'].filter(Boolean).join(' y ');
        const extras = [piezas.playlist && 'la playlist', piezas.dress && 'el dress code', piezas.premios && 'los premios'].filter(Boolean) as string[];
        const out: string[] = [];
        if (areas.includes('fecha')) out.push('la fecha, hora y lugar');
        if (areas.includes('amigo') && amigo) out.push(amigo);
        if (areas.includes('comida') && cfg.comida) out.push('lo que lleva cada quien');
        if (areas.includes('extras') && extras.length) out.push(extras.join(', '));
        if (areas.includes('invitados') && cfg.invitados) out.push('lxs invitadxs +1');
        if (areas.includes('homenaje') && piezas.homenaje && !neutral && !yoHomenajeadx) out.push('el homenaje');
        return out;
      };
      out.aCargo = (cs ?? []).map((r: any) => ({
        aCargoDe: etiquetas(r.username),
        username: r.username, nombre: (r.nombre_derby ?? '').trim() || r.username, foto: r.foto_perfil ?? '',
                telefono: r.telefono ?? '', prefijo: r.prefijo ?? '', email: r.email ?? '', pronombres: r.pronombres ?? '', organiza: r.username === cfg.creador, yo: r.username === q.username,
      })).sort((a: any, b: any) => Number(b.organiza) - Number(a.organiza));
    }
  }
  // Mensajes para la persona homenajeada: después del evento o cuando se liberan.
  if (yoHomenajeadx && piezas.homenaje && piezas.homenaje.mensajes !== false && mensajesAbiertos(cfg, _termino(ev))) {
    const { data: ms } = await db.from('social_mensajes').select('nombre, texto, created_at').eq('id_evento', q.idEvento).eq('para', q.username).order('created_at');
    out.paraTi = (ms ?? []).map((m: any) => ({ nombre: m.nombre, texto: m.texto }));
  }

  if (organiza) {
    out.editable = {
      plantilla: cfg.plantilla ?? null, festividad: cfg.festividad ?? null, nombre: cfg.nombre ?? '', nombreNeutro: cfg.nombre_neutro ?? '',
      descripcion: cfg.descripcion ?? '', para: cfg.para ?? { tipo: 'liga', valores: [] }, sorpresa: !!cfg.sorpresa,
            homenajeados: hom, noEnterarse: noEnterarse(cfg), encargados: encargadxs(cfg), piezas,
      permisos: cfg.permisos ?? {}, misPermisos: _misPermisos(q, cfg),
      regaloTope: cfg.regalo_tope == null ? null : Number(cfg.regalo_tope), regaloCompra: cfg.regalo_compra ?? null,
      reglasRobado: cfg.reglas_robado ?? '', creador: cfg.creador ?? null, mapa: ev.google_maps ?? '',
      nombres: Object.fromEntries([...personas].map(([u, p]) => [u, p.nombre])),
      migracion: 'aprobado_en' in cfg,
    };
    const ps = _participantes(asisten, invitados);
    out.admin = {
      participantes: ps.length,
      invitados: invitadosQueCuentan.length,
      sorteados: sorteo.length,
      revelados: sorteo.filter((s: any) => s.revelado_en).length,
    };
  }
  return out;
}

// ─── Datos del asistente (crear y editar) ─────────────────────────────────

/// Usernames que existen en la liga (sin archivadxs).
async function _existentes(db: any, v: unknown, max = 200): Promise<string[]> {
  const pedidos = [...new Set((Array.isArray(v) ? v : []).map((x: unknown) => _texto(x, 80)).filter(Boolean))].slice(0, max) as string[];
  if (!pedidos.length) return [];
  const { data } = await db.from('equipo').select('username').in('username', pedidos).is('eliminado_en', null);
  const ok = new Set((data ?? []).map((r: any) => r.username));
  return pedidos.filter((u) => ok.has(u));
}

function _hora(v: unknown): string | null {
  const t = String(v ?? '').trim().substring(0, 5);
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(t) ? t : null;
}

function _reglas(v: unknown): string | null {
  const t = String(v ?? '').replace(/\r/g, '').trim().slice(0, 3000);
    if (!t || t === PLANTILLA_REGALO_ROBADO) return null;
  // Una plantilla sin cambios (de cualquier combinación de opciones) no se guarda: sigue a las opciones.
  for (let n = 0; n <= 10; n++) {
    for (const devolver of [false, true]) {
      for (const turnoFinal of [false, true]) if (t === plantillaReglasRobado({ robosMax: n, devolver, turnoFinal, describir: true })) return null;
    }
  }
  return t;
}

function _link(v: unknown): string {
  let l = _texto(v, 500);
  if (l && !/^https?:\/\//i.test(l)) l = 'https://' + l;
  return l;
}

/// Piezas nuevas (jsonb `piezas`): solo las que vienen prendidas.
function _leerPiezas(v: any): Record<string, any> {
  const p = v && typeof v === 'object' ? v : {};
  const out: Record<string, any> = {};
  if (p.playlist) out.playlist = { link: _link(p.playlist.link), nota: _texto(p.playlist.nota, 200) };
  if (p.dress) out.dress = { texto: _textoLargo(p.dress.texto, 400) };
    // "Qué traer" pasó a ser secciones de "¿Qué llevamos?" (Victor, 2026-11-20): ya no se guarda aquí.
  if (false && p.traer) {
    const items = (Array.isArray(p.traer.items) ? p.traer.items : []).slice(0, 40).map((x: any) => ({
      id: typeof x?.id === 'string' && /^[\w-]{1,40}$/.test(x.id) ? x.id : _idCorto(),
      texto: _texto(x?.texto, 80),
      cantidad: _num(x?.cantidad) ? Math.min(99, Math.floor(_num(x?.cantidad)!)) : null,
    })).filter((x: any) => x.texto);
    out.traer = { items };
  }
  if (p.premios) {
    const lista = (Array.isArray(p.premios.lista) ? p.premios.lista : []).slice(0, 40).map((x: any) => ({
      id: typeof x?.id === 'string' && /^[\w-]{1,40}$/.test(x.id) ? x.id : _idCorto(),
      premio: _texto(x?.premio, 80),
      para: _texto(x?.para, 80),
    })).filter((x: any) => x.premio);
    out.premios = { lista };
  }
  if (p.homenaje) out.homenaje = { mensajes: p.homenaje.mensajes !== false, regalo: p.homenaje.regalo === true, regaloNota: _texto(p.homenaje.regaloNota, 300) };
        // Opciones del regalo robado en vivo y límite de +1 (Victor, 2026-11-20).
  if (p.juegoRobado) out.juegoRobado = reglasJuego(p.juegoRobado);
  if (p.maxInvitados !== undefined && p.maxInvitados !== null) out.maxInvitados = _maxInvitados(p.maxInvitados);
      // Ícono elegido para una festividad propia (Victor, 2026-11-20).
  if (typeof p.icono === 'string' && /^[a-z_]{1,20}$/.test(p.icono)) out.icono = p.icono;
  // Amigo secreto: parejas que no se pueden tocar entre sí (Victor, 2026-11-20).
  // Solo las ve y edita quien organiza; valen en los dos sentidos.
  if (Array.isArray(p.noTocar)) {
    const vistas = new Set<string>();
    const pares: [string, string][] = [];
    for (const x of p.noTocar.slice(0, 60)) {
      const a = _texto(Array.isArray(x) ? x[0] : '', 80), b = _texto(Array.isArray(x) ? x[1] : '', 80);
      const k = [a, b].sort().join('\u0000');
      if (!a || !b || a === b || vistas.has(k)) continue;
      vistas.add(k);
      pares.push([a, b]);
    }
    if (pares.length) out.noTocar = pares;
  }
  // Sorpresa por pieza: las que NO ven homenajeadxs ni quienes no deben enterarse.
  if (Array.isArray(p.ocultas)) {
    const ocultas = [...new Set<string>(p.ocultas.map((x: unknown) => String(x)))].filter((k) => (PIEZAS_ELEGIBLES as readonly string[]).includes(k));
    if (ocultas.length) out.ocultas = ocultas;
  }
  return out;
}

/// Lee y valida los datos del asistente. `previa`: la fila actual al editar.
async function _leerDatos(db: any, d: any, previa: any, creador: string | null, miCategoria: string | null): Promise<{ error: string } | { fila: Record<string, any>; ev: Record<string, any>; categorias: any[] | null }> {
  const fila: Record<string, any> = {};
  const ev: Record<string, any> = {};
  if (d.plantilla !== undefined) fila.plantilla = PLANTILLAS.includes(String(d.plantilla)) ? String(d.plantilla) : 'personalizado';
  if (d.festividad !== undefined) fila.festividad = _texto(d.festividad, 40) || null;
  if (d.nombre !== undefined) fila.nombre = _texto(d.nombre, 80) || null;
  if (d.nombreNeutro !== undefined) fila.nombre_neutro = _texto(d.nombreNeutro, 80) || null;
  if (d.descripcion !== undefined) fila.descripcion = _textoLargo(d.descripcion, 1000) || null;

  if (d.para !== undefined) {
    let tipo = String(d.para?.tipo ?? 'liga');
    let valores = (Array.isArray(d.para?.valores) ? d.para.valores : []).map((x: unknown) => _texto(x, 80)).filter(Boolean).slice(0, 200);
    if (tipo === 'equipo') (tipo = 'equipos', valores = miCategoria ? [miCategoria] : []);
    if (tipo === 'personas') valores = await _existentes(db, valores);
    if (!['equipos', 'liga', 'personas'].includes(tipo)) tipo = 'liga';
    if (tipo !== 'liga' && !valores.length) return { error: tipo === 'personas' ? 'Elige al menos una persona para invitar.' : 'Elige al menos un equipo.' };
    fila.para = { tipo, valores: tipo === 'liga' ? [] : [...new Set(valores)] };
  }

  const m = d.modulos ?? {};
  if (m.amigoSecreto !== undefined) fila.amigo_secreto = m.amigoSecreto === true;
  if (m.regaloRobado !== undefined) fila.regalo_robado = m.regaloRobado === true;
  if (m.comida !== undefined) fila.comida = m.comida === true;
  if (m.invitados !== undefined) fila.invitados = m.invitados === true;
  if (d.topeAmigo !== undefined) fila.tope_amigo = _num(d.topeAmigo);
  if (d.topeRobado !== undefined) fila.tope_robado = _num(d.topeRobado);
  if (d.recordatorioRobado !== undefined) fila.recordatorio_robado = _texto(d.recordatorioRobado, 300) || null;
  if (d.reglasRobado !== undefined) fila.reglas_robado = _reglas(d.reglasRobado);
  if (d.piezas !== undefined) fila.piezas = _leerPiezas(d.piezas);
  if (d.regaloTope !== undefined) fila.regalo_tope = _num(d.regaloTope);

  // Homenaje y sorpresa.
  const sorpresa = d.sorpresa !== undefined ? d.sorpresa === true : !!previa?.sorpresa;
  const hom = d.homenajeados !== undefined ? await _existentes(db, d.homenajeados, 20) : homenajeadxs(previa);
  const nadie = d.noEnterarse !== undefined ? await _existentes(db, d.noEnterarse, 100) : noEnterarse(previa);
  const enc = d.encargados !== undefined ? (await _existentes(db, d.encargados, 10)).filter((u) => u !== creador) : encargadxs(previa);
  if (d.sorpresa !== undefined) fila.sorpresa = sorpresa;
  if (d.homenajeados !== undefined) fila.homenajeados = hom;
  if (d.noEnterarse !== undefined) fila.no_enterarse = sorpresa ? nadie.filter((u) => !hom.includes(u)) : [];
    if (d.encargados !== undefined) fila.encargados = enc;
  // Qué puede editar cada encargadx (solo quien crea o un Pivot lo cambia: el filtro saca `permisos` al resto).
  if (d.permisos !== undefined && d.permisos && typeof d.permisos === 'object') {
    const permisos: Record<string, string[]> = {};
    for (const u of enc) {
      const v = d.permisos[u];
      permisos[u] = Array.isArray(v) ? [...new Set(v.map((x: unknown) => String(x)).filter((x: string) => (AREAS_SOCIAL as readonly string[]).includes(x)))] : AREAS_POR_DEFECTO;
    }
    fila.permisos = permisos;
  }
  if (d.regaloCompra !== undefined) fila.regalo_compra = (await _existentes(db, [d.regaloCompra], 1))[0] ?? null;
  const secreto = new Set([...hom, ...(sorpresa ? nadie : [])]);
  if (sorpresa) {
    if (!hom.length && !nadie.length) return { error: 'Para que sea sorpresa, elige a quién homenajean o quiénes no deben enterarse.' };
    if (creador && secreto.has(creador)) return { error: 'Quien organiza una sorpresa no puede estar entre las personas homenajeadas ni entre quienes no deben enterarse.' };
    const choca = enc.filter((u) => secreto.has(u));
    if (choca.length) return { error: 'Unx encargadx no puede estar entre las personas homenajeadas ni entre quienes no deben enterarse.' };
    if (fila.regalo_compra && secreto.has(fila.regalo_compra)) return { error: 'Quien compra el regalo no puede ser una persona homenajeada.' };
    const neutro = fila.nombre_neutro !== undefined ? fila.nombre_neutro : previa?.nombre_neutro;
    if (!neutro) return { error: 'Escribe el nombre neutro que verán quienes no deben enterarse (por ejemplo, "Reunión del equipo").' };
  }

  // Fecha, hora y lugar (van al evento del calendario y a su regla).
  if (d.fecha !== undefined) {
    const f = String(d.fecha ?? '').substring(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(f)) return { error: 'Elige la fecha.' };
    if (f < _hoyEc() && f !== String(previa?.__fecha ?? '').substring(0, 10)) return { error: 'La fecha ya pasó.' };
    ev.fecha = f;
  }
  if (d.inicia !== undefined) {
    if (!_hora(d.inicia)) return { error: 'Elige la hora de inicio.' };
    ev.inicia = _hora(d.inicia);
  }
  if (d.termina !== undefined) ev.termina = _hora(d.termina);
  if (d.lugar !== undefined) {
    const l = _texto(d.lugar, 120);
    if (!l) return { error: 'Escribe dónde será.' };
    ev.lugar = l;
  }
  if (d.mapa !== undefined) ev.mapa = _link(d.mapa) || null;

    // Cierre del amigo secreto: como máximo 1 día antes (por defecto, 2 semanas).
  const fechaEv = ev.fecha ?? previa?.__fecha;
  if (fechaEv && (d.cierre !== undefined || ev.fecha)) {
    const limite = _restarDias(fechaEv, DIAS_CIERRE_MIN);
    let cierre = typeof d.cierre === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(d.cierre) ? d.cierre : (previa?.cierre ?? _cierreDefecto(fechaEv));
    if (cierre > limite) cierre = limite;
    fila.cierre = cierre;
  }
  const categorias = Array.isArray(d.categorias) ? d.categorias : null;
  return { fila, ev, categorias };
}

const MODOS_SECCION = ['meta', 'cada', 'total', 'libre'];

/// Comida o bebida (porciones o litros): sin cupo, siempre se puede llevar de más.
function _esComida(c: any): boolean {
  if (c.modo === 'cada' || c.modo === 'libre') return false;
  const u = String(c.unidad ?? '').trim().toLowerCase();
  return u.includes('porci') || /^(litros?|l|lts?)$/.test(u);
}

/// Cupo de las cosas (Victor, 2026-11-20): 0 = sin límite.
function _limiteSeccion(c: any, asistentes: number): number {
  const n = Number(c.cupo ?? 0);
  if (_esComida(c) || !(n > 0)) return 0;
  if (c.cupo_tipo === 'fijo') return n;
  if (c.cupo_tipo === 'persona') return Math.max(1, Math.ceil(asistentes / n));
  return 0;
}

/// Meta de una sección de "¿Qué llevamos?" según su modo.
function _metaSeccion(c: any, asistentes: number): number {
  const pp = Number(c.por_persona ?? 0);
  switch (c.modo) {
    case 'cada': return Math.ceil(asistentes * pp);
    case 'total': return Number(c.total ?? 0);
    case 'libre': return 0;
    default: return Math.ceil(asistentes * pp);
  }
}

/// Categorías de la comida: por id; las que se quitan se borran solo si
/// nadie se anotó todavía. Una app vieja (sin `modo`) no borra ninguna: no
/// conoce las secciones nuevas.
async function _guardarCategorias(db: any, liga: string, idEvento: string, cats: any[]): Promise<string[]> {
  const avisos: string[] = [];
  const { data: actuales } = await db.from('social_comida_categorias').select('id, nombre').eq('id_evento', idEvento);
  const vistos = new Set<string>();
  let orden = 0;
  for (const x of cats.slice(0, 20)) {
    const nombre = _texto(x?.nombre, 60);
    if (!nombre) continue;
            const datos: Record<string, any> = { nombre, unidad: _texto(x?.unidad, 30) || 'porciones', por_persona: _num(x?.porPersona) ?? 1, orden: orden++ };
    if (x?.modo !== undefined) datos.modo = MODOS_SECCION.includes(String(x.modo)) ? String(x.modo) : 'meta';
    if (x?.total !== undefined) datos.total = _num(x.total);
    if (x?.falta !== undefined) datos.falta = x.falta === true;
        if (x?.sugerencias !== undefined) datos.sugerencias = _sugerenciasComida(x.sugerencias);
    if (x?.cupoTipo !== undefined) {
      datos.cupo_tipo = x.cupoTipo === 'fijo' || x.cupoTipo === 'persona' ? x.cupoTipo : null;
      datos.cupo = datos.cupo_tipo ? _num(x.cupo) : null;
    }
    const id = typeof x?.id === 'string' && (actuales ?? []).some((a: any) => a.id === x.id) ? x.id : null;
    if (id) {
      vistos.add(id);
      await db.from('social_comida_categorias').update(datos).eq('id', id);
    } else {
      await db.from('social_comida_categorias').insert({ ...datos, id_evento: idEvento, liga_id: liga });
    }
  }
    const appNueva = cats.some((x: any) => x?.modo !== undefined);
  for (const a of actuales ?? []) {
    if (vistos.has(a.id) || !appNueva) continue;
    const { count } = await db.from('social_comida_aportes').select('id', { count: 'exact', head: true }).eq('categoria_id', a.id);
    if ((count ?? 0) > 0) avisos.push(`"${a.nombre}" no se quitó porque ya hay personas anotadas.`);
    else await db.from('social_comida_categorias').delete().eq('id', a.id);
  }
  return avisos;
}

const _DIAS = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

/// Cambia lugar, mapa, horario o fecha en el evento y en su regla (venue),
/// porque la regeneración de la ventana copia los datos del venue al evento.
async function _cambiarEvento(db: any, ev: any, e: Record<string, any>): Promise<string | null> {
  const cambioEv: Record<string, any> = {};
  const cambioVenue: Record<string, any> = {};
  if (e.lugar && e.lugar !== ev.donde) (cambioEv.donde = e.lugar, cambioVenue.lugar = e.lugar);
  if (e.mapa !== undefined && e.mapa !== (ev.google_maps ?? null)) (cambioEv.google_maps = e.mapa, cambioVenue.google_maps = e.mapa);
  if (e.inicia && e.inicia !== String(ev.inicia ?? '').substring(0, 5)) (cambioEv.inicia = e.inicia, cambioVenue.inicia = e.inicia);
  if (e.termina !== undefined && (e.termina ?? '') !== String(ev.termina ?? '').substring(0, 5)) (cambioEv.termina = e.termina, cambioVenue.finaliza = e.termina);
  if (e.fecha && e.fecha !== String(ev.fecha).substring(0, 10)) {
    const d = new Date(e.fecha + 'T12:00:00Z');
    cambioEv.fecha = e.fecha;
    cambioEv.mes = e.fecha.substring(0, 7);
    cambioEv.dia = _DIAS[d.getUTCDay()];
    cambioVenue.fecha_referencia = e.fecha;
  }
  if (!Object.keys(cambioEv).length) return null;
  const { error } = await db.from('asistencias').update(cambioEv).eq('id_evento', ev.id_evento);
  if (error) return 'No se pudo cambiar la fecha, el lugar o el horario: ' + error.message;
  if (ev.id_regla) await db.from('venues').update(cambioVenue).eq('id', ev.id_regla);
  return null;
}

/// Equipos invitados también en el evento (`asistencias.equipos`, alcance
/// de los avisos). Sin esa columna (migración 20261120030000) no pasa nada.
async function _equiposEnEvento(db: any, idEvento: string, para: any): Promise<void> {
  const equipos = para?.tipo === 'equipos' ? (para.valores ?? []) : null;
  try {
    await db.from('asistencias').update({ equipos: equipos?.length ? equipos : null }).eq('id_evento', idEvento);
  } catch { /* columna sin crear */ }
}

// ─── Crear (cualquier persona de la liga) ─────────────────────────────────

async function socialCrear(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien({ ...params, idEvento: '-' }, deps);
  if ('error' in q) return { exito: false, error: q.error };
    if (q.tipo === 'invitado' || (!q.username && !q.esPivot)) return { exito: false, error: 'Inicia sesión con tu cuenta para crear un evento.' };
  // Solo Pivots con el área de fiestas y eventos sociales (Victor, 2026-11-20).
  const areas = q.pivotEmail && deps.areasDe ? await deps.areasDe(q.pivotEmail) : [];
  if (!areas.includes('sociales')) return { exito: false, error: 'Solo los Pivots de fiestas y eventos sociales pueden crear estos eventos.' };
  const d = _json(params.datos) ?? {};
  for (const k of ['fecha', 'inicia', 'lugar']) if (d[k] === undefined) d[k] = '';
  const r = await _leerDatos(db, { ...d, sorpresa: d.sorpresa === true }, null, q.username, q.categoria);
  if ('error' in r) return { exito: false, error: r.error };
  if (!r.fila.nombre && !r.fila.nombre_neutro) return { exito: false, error: 'Ponle un nombre al evento.' };

  // Mismo mecanismo que "Nuevo evento": una regla (venue) de evento único y
  // la ventana de asistencias se regenera (id = EV-<venue>-<AAAAMMDD>).
  const { data: lugares } = await db.from('venues').select('lugar, google_maps').eq('lugar', r.ev.lugar).not('google_maps', 'is', null).limit(1);
  const { data: v, error: ev1 } = await db.from('venues').insert({
    lugar: r.ev.lugar, google_maps: r.ev.mapa ?? (lugares ?? [])[0]?.google_maps ?? null, tipo_icono: 'Social', requiere_reserva: false,
    info_adicional: null, tipo: 'unico', fecha_referencia: r.ev.fecha, inicia: r.ev.inicia, ...(r.ev.termina ? { finaliza: r.ev.termina } : {}),
  }).select('id').single();
  if (ev1 || !v?.id) return { exito: false, error: 'No se pudo crear el evento: ' + (ev1?.message ?? 'sin respuesta') };
  try {
    await db.rpc('regenerar_ventana_asistencias');
  } catch { /* el cron diario también la regenera */ }
  const idEvento = `EV-${v.id}-${r.ev.fecha.replace(/-/g, '')}`;
  const ev = await _evento(db, idEvento);
  if (!ev) {
    await db.from('venues').delete().eq('id', v.id);
    return { exito: false, error: 'Ese día no se pueden crear eventos (¿está dentro de una temporada de descanso?).' };
  }

  const fila: Record<string, any> = {
    id_evento: idEvento, liga_id: liga, creado_por: q.pivotEmail ?? q.username, creador: q.username,
    amigo_secreto: false, regalo_robado: false, comida: false, invitados: false, piezas: {}, para: { tipo: 'liga', valores: [] },
    ...r.fila, aprobado_en: null, actualizado_en: new Date().toISOString(),
  };
    if (!fila.cierre) fila.cierre = _cierreDefecto(r.ev.fecha);
  const { error: e2 } = await db.from('social_eventos').insert(fila);
  if (e2) {
    await db.from('asistencias').delete().eq('id_evento', idEvento);
    await db.from('venues').delete().eq('id', v.id);
    return { exito: false, error: _esFaltaColumna(e2) ? FALTA_MIGRACION : 'No se pudo guardar: ' + e2.message };
  }
  await _equiposEnEvento(db, idEvento, fila.para);
  const avisos = r.categorias && fila.comida ? await _guardarCategorias(db, liga, idEvento, r.categorias) : [];

  // Aprobación: un Pivot que puede aprobar lo publica al crearlo; si ningún
  // Pivot puede (todos homenajeadxs o no deben enterarse), se publica solo.
  const pivots = deps.pivots ? await deps.pivots() : [];
  const elegibles = aprobadores(pivots, fila);
  let publicadoYa = false;
  if ((q.esPivot && puedeAprobar(fila, q.username)) || !elegibles.length) {
    const pub = await _publicar(db, deps, idEvento, q.pivotEmail ?? 'sin aprobación');
    publicadoYa = pub.exito === true;
  } else {
    await _avisarPorAprobar(deps, fila, ev, elegibles.map((p) => p.username), q.nombre);
  }
  return {
    exito: true, idEvento, fecha: r.ev.fecha, publicado: publicadoYa, avisos,
    mensaje: publicadoYa ? 'Evento publicado en el calendario.' : 'Listo. Un Pivot lo revisa y, cuando lo apruebe, se publica en el calendario.',
  };
}

async function _avisarPorAprobar(deps: DepsSocial, cfg: any, ev: any, usernames: string[], quien: string): Promise<void> {
  if (!deps.push || !usernames.length) return;
  try {
    await deps.push({
      tipo: 'avisos_admin',
      include_external_user_ids: usernames,
      headings: { es: 'Hay un Social o fiesta por aprobar' },
      contents: { es: `${quien} creó "${cfg.nombre || cfg.nombre_neutro || 'Social o fiesta'}" para el ${_fechaCorta(ev.fecha)}. Revísalo en Notificaciones.` },
      url: _url(deps, ev.id_evento),
    });
  } catch { /* el aviso no frena la creación */ }
}

// ─── Editar (quien creó, encargadxs y Pivots) ─────────────────────────────

/// Datos de la primera versión (config + categorias + evento) al formato del asistente.
function _datosLegacy(params: Record<string, any>): any {
  const c = _json(params.config) ?? {}, e = _json(params.evento) ?? {};
  const d: any = {
    modulos: {
      amigoSecreto: c.amigoSecreto !== false, regaloRobado: c.regaloRobado === true, comida: c.comida !== false, invitados: c.invitados !== false,
    },
    topeAmigo: c.topeAmigo, topeRobado: c.topeRobado, recordatorioRobado: c.recordatorioRobado, cierre: c.cierre,
  };
  if (c.reglasRobado !== undefined) d.reglasRobado = c.reglasRobado;
  if (Array.isArray(c.encargados)) d.encargados = c.encargados;
  const cats = _json(params.categorias);
  if (Array.isArray(cats)) d.categorias = cats;
  if (e.lugar) d.lugar = e.lugar;
  if (e.mapa !== undefined) d.mapa = e.mapa;
  if (e.inicia) d.inicia = e.inicia;
  if (e.termina !== undefined) d.termina = e.termina;
  return d;
}

async function socialGuardarConfig(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  const idEvento = q.idEvento;
  const ev = await _evento(db, idEvento);
  if (!ev) return { exito: false, error: 'No encontramos este evento.' };
  if (ev.tipo_evento !== 'Social') return { exito: false, error: 'Solo los eventos de tipo Social o fiesta tienen estas opciones.' };
  const previa = await _config(db, idEvento);
  if (!previa && !q.esPivot) return { exito: false, error: 'Solo un Pivot puede configurar este evento.' };
  if (previa && !_organiza(q, previa)) return { exito: false, error: 'Solo quien creó el evento, sus encargadxs y los Pivots pueden cambiarlo.' };
    let d = params.datos !== undefined ? (_json(params.datos) ?? {}) : _datosLegacy(params);
  // Encargadxs: solo lo de sus áreas (quien crea y los Pivots, todo).
  const areas = previa ? _misPermisos(q, previa) : null;
  if (areas) d = _filtrarPorPermisos(d, areas, previa);
  const creador = previa?.creador ?? null;
  const r = await _leerDatos(db, d, previa ? { ...previa, __fecha: ev.fecha } : { __fecha: ev.fecha }, creador ?? q.username, q.categoria);
  if ('error' in r) return { exito: false, error: r.error };
  // Foto de antes para avisar los cambios de un evento ya publicado.
  const fotoAntes = previa && publicado(previa) ? await _foto(db, previa, ev) : null;
  const fila: Record<string, any> = { ...r.fila };
  if (previa && 'actualizado_en' in previa) fila.actualizado_en = new Date().toISOString();
    if (!fila.cierre && !previa?.cierre) fila.cierre = _cierreDefecto(r.ev.fecha ?? ev.fecha);
  const reenviar = params.reenviar === true || params.reenviar === 'true';
  if (reenviar && previa?.rechazado_en) (fila.rechazado_en = null, fila.rechazo_motivo = null);
  if (!previa) {
    Object.assign(fila, { id_evento: idEvento, liga_id: liga, creado_por: q.pivotEmail });
  }
  const { error } = previa
    ? await db.from('social_eventos').update(fila).eq('id_evento', idEvento)
    : await db.from('social_eventos').insert({ amigo_secreto: true, comida: true, invitados: true, ...fila });
  if (error) return { exito: false, error: _esFaltaColumna(error) ? FALTA_MIGRACION : 'No se pudo guardar: ' + error.message };
  const err = await _cambiarEvento(db, ev, r.ev);
  if (err) return { exito: false, error: err };
  if (fila.para) await _equiposEnEvento(db, idEvento, fila.para);
  const avisos = r.categorias ? await _guardarCategorias(db, liga, idEvento, r.categorias) : [];

  const cfg = await _config(db, idEvento);
  // Primera versión: un Pivot lo crea y lo publica de una vez.
  if (!previa && q.esPivot) await _publicar(db, deps, idEvento, q.pivotEmail!);
  else if (cfg && !publicado(cfg)) {
    const elegibles = aprobadores(deps.pivots ? await deps.pivots() : [], cfg);
    if (!elegibles.length || (q.esPivot && puedeAprobar(cfg, q.username) && (params.publicar === true || params.publicar === 'true'))) {
      await _publicar(db, deps, idEvento, q.pivotEmail ?? 'sin aprobación');
    } else if (reenviar) {
      await _avisarPorAprobar(deps, cfg, { ...ev, fecha: r.ev.fecha ?? ev.fecha }, elegibles.map((p) => p.username), q.nombre);
    }
  }
  const final = await _config(db, idEvento);
  if (fotoAntes && final && publicado(final)) {
    const evNuevo = (await _evento(db, idEvento)) ?? ev;
        await _avisarCambios(deps, final, evNuevo, soloImportantes(diferencias(fotoAntes, await _foto(db, final, evNuevo))), q.username);
  }
  return { exito: true, avisos, publicado: publicado(final) };
}

/// Lo que se compara para saber qué cambió (una entrada por parte del evento).
async function _foto(db: any, cfg: any, ev: any): Promise<Foto> {
  const p = _piezas(cfg);
  const { data: cats } = await db.from('social_comida_categorias').select('nombre, unidad, por_persona, orden').eq('id_evento', ev.id_evento).order('orden');
  const h = (x: unknown) => String(x ?? '').substring(0, 5);
  return {
    nombre: cfg.nombre ?? null, nombreNeutro: cfg.nombre_neutro ?? null, descripcion: cfg.descripcion ?? null,
    fecha: String(ev.fecha ?? '').substring(0, 10), hora: `${h(ev.inicia)}-${h(ev.termina)}`, lugar: ev.donde ?? '', mapa: ev.google_maps ?? '',
    comida: [!!cfg.comida, (cats ?? []).map((c: any) => [c.nombre, c.unidad, Number(c.por_persona)])],
    amigoSecreto: [!!cfg.amigo_secreto, cfg.tope_amigo == null ? null : Number(cfg.tope_amigo), cfg.cierre ?? null],
    regaloRobado: [!!cfg.regalo_robado, cfg.tope_robado == null ? null : Number(cfg.tope_robado), cfg.recordatorio_robado ?? null, cfg.reglas_robado ?? null],
    invitados: !!cfg.invitados,
    playlist: p.playlist ?? null, dress: p.dress ?? null, traer: p.traer ?? null, premios: p.premios ?? null,
    homenaje: [p.homenaje ?? null, homenajeadxs(cfg), cfg.regalo_tope == null ? null : Number(cfg.regalo_tope), cfg.regalo_compra ?? null],
  };
}

/// Un solo aviso "Cambios en …" por guardado, con el resumen de qué cambió.
/// Quienes no deben enterarse reciben la versión neutra y solo de lo que ven
/// (si no ven nada de lo que cambió, no les llega). El filtro de personas
/// activas y de invitadxs lo aplica sendPush (`evento`).
async function _avisarCambios(deps: DepsSocial, cfg: any, ev: any, cambios: ReturnType<typeof diferencias>, editor: string | null): Promise<void> {
  if (!deps.push || !cambios.length) return;
  try {
    const db = deps.db;
    const { data: filas } = await db.from('equipo').select('username, categoria').is('eliminado_en', null);
    const inv = (filas ?? []).filter((f: any) => f.username && f.username !== editor && estaInvitadx(cfg, f.username, f.categoria)).map((f: any) => String(f.username));
    const personas = await _personas(db, homenajeadxs(cfg));
    const nombreDe = (u: string) => personas.get(u)?.nombre ?? u;
    const grupos: [string[], Vista][] = [
      [inv.filter((u: string) => !esSecretoPara(cfg, u)), 'completa'],
      [inv.filter((u: string) => esSecretoPara(cfg, u)), 'neutral'],
    ];
    const ahora = [_fechaCorta(ev.fecha), String(ev.inicia ?? '').substring(0, 5), ev.donde].filter(Boolean).join(' · ');
    await Promise.allSettled(grupos.map(([us, vista]) => {
      const que = cambiosPara(cambios, cfg, vista);
      if (!us.length || !que.length) return Promise.resolve();
      const general = que.some((x) => ['la fecha', 'la hora', 'el lugar'].includes(x));
      return deps.push!({
        tipo: 'evento_editado', include_external_user_ids: us, evento: { idEvento: ev.id_evento },
        headings: { es: `Cambios en ${tituloPara(cfg, vista, nombreDe)}` },
        contents: { es: `Cambió ${listaEs(que)}.${general ? ` Ahora: ${ahora}.` : ''}` },
        url: _url(deps, ev.id_evento),
      });
    }));
  } catch { /* el aviso no frena el guardado */ }
}

// ─── Aprobación (Pivots) ──────────────────────────────────────────────────

/// Publica el evento (lo ve quien está invitadx) y avisa una sola vez: con el
/// nombre neutro a quienes no deben enterarse.
async function _publicar(db: any, deps: DepsSocial, idEvento: string, email: string): Promise<Record<string, any>> {
  const cfg = await _config(db, idEvento);
  if (!cfg) return { exito: false, error: 'Primero guarda la configuración del evento.' };
  if (cfg.aprobado_en) return { exito: true };
  const cambio: Record<string, any> = { aprobado_en: new Date().toISOString(), aprobado_por: email };
  if ('rechazado_en' in cfg) (cambio.rechazado_en = null, cambio.rechazo_motivo = null);
  const { error } = await db.from('social_eventos').update(cambio).eq('id_evento', idEvento);
  if (error) return { exito: false, error: 'No se pudo publicar: ' + error.message };
  const ev = await _evento(db, idEvento);
  if (deps.push && ev) {
    try {
      const { data: filas } = await db.from('equipo').select('username, categoria').is('eliminado_en', null);
      const listaInv = (filas ?? []).filter((f: any) => f.username && estaInvitadx(cfg, f.username, f.categoria)).map((f: any) => String(f.username));
      const personas = await _personas(db, homenajeadxs(cfg));
      const nombreDe = (u: string) => personas.get(u)?.nombre ?? u;
      const detalle = [_fechaCorta(ev.fecha), String(ev.inicia ?? '').substring(0, 5), ev.donde].filter(Boolean).join(' · ');
      const secreto = listaInv.filter((u: string) => esSecretoPara(cfg, u));
      const resto = listaInv.filter((u: string) => !esSecretoPara(cfg, u));
      const sorpresa = etiquetaSorpresa(cfg, 'completa', nombreDe);
      const envio = (us: string[], titulo: string, extra: string) => us.length ? deps.push!({
        tipo: 'evento_creado', include_external_user_ids: us, evento: { idEvento },
        headings: { es: `Nuevo: ${titulo}` }, contents: { es: `${detalle}. Confirma tu asistencia.${extra}` }, url: _url(deps, idEvento),
      }) : Promise.resolve();
      await Promise.allSettled([
        envio(resto, tituloPara(cfg, 'completa', nombreDe), sorpresa ? ` ${sorpresa}: que no se entere.` : ''),
        envio(secreto, tituloPara(cfg, 'neutral', nombreDe), ''),
      ]);
      // A quien lo creó: ya está aprobado.
      if (cfg.creador && email !== 'sin aprobación' && !(await _esPivotUsername(deps, cfg.creador, email))) {
        await deps.push({
          tipo: 'social', include_external_user_ids: [cfg.creador], personal: true,
          headings: { es: 'Tu evento ya está publicado' },
          contents: { es: `Un Pivot aprobó "${tituloPara(cfg, 'organiza', nombreDe)}". Ya aparece en el calendario.` }, url: _url(deps, idEvento),
        });
      }
    } catch { /* el aviso no frena la publicación */ }
  }
  return { exito: true, publicado: true };
}

async function _esPivotUsername(deps: DepsSocial, username: string, email: string): Promise<boolean> {
  const ps = deps.pivots ? await deps.pivots() : [];
  return ps.some((p) => p.username === username && p.email === String(email).toLowerCase());
}

function _fechaCorta(iso: string): string {
  const meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  const d = String(iso ?? '').substring(0, 10).split('-');
  return d.length === 3 ? `${Number(d[2])} de ${meses[Number(d[1]) - 1] ?? ''}` : String(iso ?? '');
}

/// Pivot que pide aprobar o rechazar: su cuenta (para saber si está en las listas).
async function _pivotQueAprueba(params: Record<string, any>, deps: DepsSocial): Promise<{ email: string; username: string | null } | null> {
  const email = await deps.validarAdminToken(String(params.adminToken ?? ''));
  if (!email) return null;
  const tokenUser = params.token ? await deps.validarToken(String(params.token)) : null;
  const username = tokenUser ?? (await _cuentaDePivot(deps.db, email))?.username ?? null;
  return { email, username };
}

async function socialAprobar(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db;
  const p = await _pivotQueAprueba(params, deps);
  if (!p) return { exito: false, error: 'Solo un Pivot puede aprobar.' };
  const idEvento = _texto(params.idEvento, 200);
  const [ev, cfg] = await Promise.all([_evento(db, idEvento), _config(db, idEvento)]);
  // Sin decir por qué: a una persona homenajeada no se le cuenta que hay algo.
  if (!ev || !cfg || !puedeAprobar(cfg, p.username)) return { exito: false, error: 'Este evento no está disponible.' };
  const pub = await _publicar(db, deps, idEvento, p.email);
  if (!pub.exito) return pub;
  return { exito: true, publicado: true };
}

async function socialRechazar(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db;
  const p = await _pivotQueAprueba(params, deps);
  if (!p) return { exito: false, error: 'Solo un Pivot puede hacer esto.' };
  const idEvento = _texto(params.idEvento, 200);
  const [ev, cfg] = await Promise.all([_evento(db, idEvento), _config(db, idEvento)]);
  if (!ev || !cfg || !puedeAprobar(cfg, p.username)) return { exito: false, error: 'Este evento no está disponible.' };
  if (publicado(cfg)) return { exito: false, error: 'Este evento ya está publicado.' };
  const motivo = _texto(params.motivo, 300);
  const { error } = await db.from('social_eventos').update({ rechazado_en: new Date().toISOString(), rechazo_motivo: motivo || null }).eq('id_evento', idEvento);
  if (error) return { exito: false, error: 'No se pudo guardar: ' + error.message };
  if (deps.push && cfg.creador) {
    try {
      await deps.push({
        tipo: 'social', include_external_user_ids: [cfg.creador], personal: true,
        headings: { es: 'Tu evento necesita cambios' },
        contents: { es: `Un Pivot revisó "${cfg.nombre || cfg.nombre_neutro || 'Social o fiesta'}".${motivo ? ' ' + motivo : ''} Edítalo y envíalo de nuevo.` },
        url: _url(deps, idEvento),
      });
    } catch { /* best-effort */ }
  }
  return { exito: true };
}

/// Para la Bandeja de Pivots (Notificaciones del Calendario): eventos por
/// aprobar que este Pivot puede aprobar. Sin la migración, ninguno.
export async function socialPorAprobar(adminEmail: string, deps: DepsSocial): Promise<any[]> {
  const db = deps.db;
  const { data, error } = await db.from('social_eventos').select('*').is('aprobado_en', null).is('rechazado_en', null);
  if (error || !(data ?? []).length) return [];
  const yo = (await _cuentaDePivot(db, adminEmail))?.username ?? null;
  const filas = (data ?? []).filter((c: any) => puedeAprobar(c, yo));
  if (!filas.length) return [];
  const { data: evs } = await db.from('asistencias').select('id_evento, fecha, donde, inicia, estado').in('id_evento', filas.map((c: any) => c.id_evento));
  const porId = new Map((evs ?? []).map((e: any) => [e.id_evento, e]));
  const personas = await _personas(db, filas.flatMap((c: any) => [c.creador ?? '', ...homenajeadxs(c)]));
  const nombreDe = (u: string) => personas.get(u)?.nombre ?? u;
  const hoy = _hoyEc();
  return filas.filter((c: any) => {
    const e: any = porId.get(c.id_evento);
    return e && String(e.fecha) >= hoy && !/cancel|eliminado/i.test(String(e.estado ?? ''));
  }).map((c: any) => {
    const e: any = porId.get(c.id_evento);
    const para = c.para?.tipo === 'personas' ? `${(c.para.valores ?? []).length} personas` : c.para?.tipo === 'equipos' ? (c.para.valores ?? []).join(', ') : 'Toda la liga';
    return {
      id: c.id_evento, nombre: c.creador ?? '', nombreMostrar: c.creador ? nombreDe(c.creador) : 'Un Pivot', foto: personas.get(c.creador)?.foto ?? '',
      titulo: tituloPara(c, 'organiza', nombreDe), sorpresa: etiquetaSorpresa(c, 'organiza', nombreDe), para,
      piezas: _resumenPiezas(c), creada: c.actualizado_en ?? c.created_at,
      evento: { idEvento: c.id_evento, fecha: e.fecha, lugar: e.donde ?? '', hora: String(e.inicia ?? '').substring(0, 5), tipo: 'Social o fiesta' },
    };
  });
}

function _resumenPiezas(c: any): string[] {
  const p = _piezas(c);
  return [
    c.comida && 'Comida y bebida', p.playlist && 'Playlist', c.amigo_secreto && 'Amigo secreto', c.regalo_robado && 'Regalo robado',
    p.dress && 'Dress code', p.traer && 'Qué traer', p.homenaje && 'Homenaje', p.premios && 'Premios', c.invitados && '+1',
  ].filter(Boolean) as string[];
}

/// Personas y equipos de la liga para elegir invitadxs, homenajeadxs y encargadxs.
async function socialEquipo(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const q = await _quien({ ...params, idEvento: '-' }, deps);
  if ('error' in q) return { exito: false, error: q.error };
  if (q.tipo === 'invitado') return { exito: false, error: 'Solo personas de la liga.' };
  const { data } = await deps.db.from('equipo').select('username, nombre_derby, categoria, foto_perfil').is('eliminado_en', null).order('username');
  const personas = (data ?? []).filter((r: any) => r.username).map((r: any) => ({
    username: r.username, nombre: (r.nombre_derby ?? '').trim() || r.username, equipo: r.categoria ?? '', foto: r.foto_perfil ?? '',
  }));
  personas.sort((a: any, b: any) => a.nombre.localeCompare(b.nombre));
  return { exito: true, personas, equipos: [...new Set(personas.map((p: any) => p.equipo).filter(Boolean))].sort(), yo: q.username, miEquipo: q.categoria };
}

// ─── Invitadxs +1 ─────────────────────────────────────────────────────────

async function socialAgregarInvitado(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  if (q.tipo !== 'miembro') return { exito: false, error: 'Solo personas de la liga pueden sumar invitadxs.' };
  const cfg = await _config(db, q.idEvento);
  const vInv = cfg ? _vista(q, cfg) : 'oculta';
  if (!cfg?.invitados || vInv === 'oculta' || !piezaVisible(cfg, 'invitados', vInv)) return { exito: false, error: 'Este evento no admite invitadxs.' };
  const asisten = await _asistentes(db, q.idEvento);
  if (!asisten.has(q.clave!)) return { exito: false, error: 'Primero marca Asistiré para sumar a tu +1.' };
    // +1 por enlace (Victor, 2026-11-20): el nombre es opcional; si no viene,
  // lo escribe el +1 al abrir su enlace.
  const nombre = _texto(params.nombre, 60);
  const contacto = _texto(params.contacto, 120);
  const { count } = await db.from('social_invitados').select('id', { count: 'exact', head: true }).eq('id_evento', q.idEvento).eq('anfitrion', q.clave);
    const max = _maxInvitados(_piezas(cfg).maxInvitados);
  if ((count ?? 0) >= max) return { exito: false, error: max === 1 ? 'Puedes sumar 1 invitadx.' : `Puedes sumar hasta ${max} invitadxs.` };
  const token = _tokenNuevo();
  const { data, error } = await db.from('social_invitados')
        .insert({ id_evento: q.idEvento, anfitrion: q.clave, nombre, contacto: contacto || null, token, liga_id: liga, ...(nombre ? { entro_en: new Date().toISOString() } : {}) })
    .select('id').single();
  if (error) return { exito: false, error: 'No se pudo guardar: ' + error.message };
  return { exito: true, invitado: { id: data.id, nombre, contacto, enlace: _enlace(deps, token), enSorteo: false, entro: !!nombre } };
}

/// El +1 escribe su nombre al abrir su enlace (y puede corregirlo).
async function socialInvitadoNombre(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  if (!params.invitadoToken) return { exito: false, error: 'Este enlace no es válido.' };
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  if (q.tipo !== 'invitado') return { exito: false, error: 'Este enlace no es válido.' };
  const nombre = _texto(params.nombre, 60);
  if (!nombre) return { exito: false, error: 'Escribe tu nombre.' };
  const { error } = await deps.db.from('social_invitados')
    .update({ nombre, ...(q.invitado.entro_en ? {} : { entro_en: new Date().toISOString() }) }).eq('id', q.invitado.id);
  if (error) return { exito: false, error: 'No se pudo guardar: ' + error.message };
  return { exito: true };
}

async function socialQuitarInvitado(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  if (q.tipo !== 'miembro') return { exito: false, error: 'Solo quien invitó puede quitar a su +1.' };
  const { data: inv } = await db.from('social_invitados').select('id, anfitrion, id_evento').eq('id', String(params.id ?? '')).maybeSingle();
  if (!inv || inv.anfitrion !== q.clave) return { exito: false, error: 'No encontramos a tu invitadx.' };
  const clave = 'inv:' + inv.id;
  const { data: sorteo } = await db.from('social_sorteo').select('da, recibe').eq('id_evento', inv.id_evento);
  if ((sorteo ?? []).some((s: any) => s.da === clave || s.recibe === clave)) return { exito: false, error: 'Tu invitadx ya está en el sorteo del amigo secreto. Pide a quien organiza que lo rehaga.' };
  await db.from('social_comida_aportes').delete().eq('clave', clave);
  try {
    await db.from('social_traer_anotes').delete().eq('clave', clave);
  } catch { /* tabla sin crear */ }
  await db.from('social_perfiles').delete().eq('liga_id', liga).eq('clave', clave);
  await db.from('social_invitados').delete().eq('id', inv.id);
  return { exito: true };
}

// ─── Pistas y wishlist ────────────────────────────────────────────────────

function _lista(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  const out: string[] = [];
  for (const x of v) {
    const t = _texto(x, 60);
    if (t && !out.some((y) => y.toLowerCase() === t.toLowerCase())) out.push(t);
    if (out.length >= MAX_LISTA) break;
  }
  return out;
}

async function socialGuardarPerfil(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  // El perfil es por persona (no por evento): con sesión no hace falta idEvento.
  const q = params.invitadoToken || params.idEvento ? await _quien(params, deps) : await _quien({ ...params, idEvento: '-' }, deps);
  if ('error' in q) return { exito: false, error: q.error };
  if (!q.clave) return { exito: false, error: 'Inicia sesión con tu cuenta para guardar tus pistas.' };
  const p = _json(params.perfil) ?? {};
  const tallas: Record<string, string> = {};
  if (p.tallas && typeof p.tallas === 'object') {
    for (const k of ['camiseta', 'medias', 'otra']) {
      const t = _texto(p.tallas[k], 30);
      if (t) tallas[k] = t;
    }
  }
  const wishlist: any[] = [];
  let favoritos = 0;
  for (const x of Array.isArray(p.wishlist) ? p.wishlist : []) {
    const texto = _texto(x?.texto, 80);
    if (!texto) continue;
    const link = _link(x?.link);
    const favorito = x?.favorito === true && favoritos < MAX_FAVORITOS;
    if (favorito) favoritos++;
    wishlist.push({ texto, nota: _texto(x?.nota, 200), link, favorito });
    if (wishlist.length >= MAX_WISHLIST) break;
  }
  const fila = {
    liga_id: liga, clave: q.clave,
    gustos: _lista(p.gustos), sobre_mi: _lista(p.sobreMi), no_regalar: _lista(p.noRegalar),
        tallas, wishlist, updated_at: new Date().toISOString(),
    // Wishlist externa opcional (Wishdeck, Amazon u otra; Victor, 2026-11-20).
    ...(p.wishlistLink !== undefined ? { wishlist_link: _link(p.wishlistLink) || null } : {}),
  };
  const { error } = await db.from('social_perfiles').upsert(fila, { onConflict: 'liga_id,clave' });
  if (error) return { exito: false, error: 'No se pudo guardar: ' + error.message };
  return { exito: true, perfil: _perfilSalida(fila) };
}

// ─── Ruleta: revelar el amigo secreto ─────────────────────────────────────

async function socialRevelar(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  if (!q.clave) return { exito: false, error: 'Solo quienes participan tienen amigo secreto.' };
  const { data: mio } = await db.from('social_sorteo').select('recibe, revelado_en').eq('id_evento', q.idEvento).eq('da', q.clave).maybeSingle();
  if (!mio) return { exito: false, error: 'No estás en el sorteo del amigo secreto.' };
  if (!mio.revelado_en) {
    await db.from('social_sorteo').update({ revelado_en: new Date().toISOString() }).eq('id_evento', q.idEvento).eq('da', q.clave);
  }
  return { exito: true, ficha: await _ficha(db, liga, mio.recibe) };
}

// ─── Comida compartida ────────────────────────────────────────────────────

function _sugerenciasComida(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  const out: string[] = [];
  for (const x of v) {
    const t = _texto(x, 40);
    if (t && !out.some((y) => y.toLowerCase() === t.toLowerCase())) out.push(t);
    if (out.length >= 12) break;
  }
  return out;
}

/// Quien está a cargo de la comida (o quien crea, o un Pivot) la administra
/// desde la tarjeta del evento: agrega, cambia o quita categorías, marca lo que
/// hace falta y deja sugerencias de qué traer (Victor, 2026-11-20).
async function socialComidaEditar(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  const cfg = await _config(db, q.idEvento);
  if (!cfg || !_organiza(q, cfg)) return { exito: false, error: 'Solo quienes organizan pueden cambiar la comida.' };
  const areas = _misPermisos(q, cfg);
  if (areas && !areas.includes('comida')) return { exito: false, error: 'No estás a cargo de la comida en este evento.' };
  const id = String(params.categoriaId ?? '');
  const { data: actual } = id ? await db.from('social_comida_categorias').select('*').eq('id', id).eq('id_evento', q.idEvento).maybeSingle() : { data: null };
  if (id && !actual) return { exito: false, error: 'No encontramos esa categoría.' };
  if (params.accion === 'borrar') {
    const { count } = await db.from('social_comida_aportes').select('id', { count: 'exact', head: true }).eq('categoria_id', id);
    if ((count ?? 0) > 0) return { exito: false, error: 'Alguien ya se anotó en esta categoría: no se puede quitar.' };
    await db.from('social_comida_categorias').delete().eq('id', id);
    return { exito: true };
  }
  const nombre = _texto(params.nombre ?? actual?.nombre, 60);
  if (!nombre) return { exito: false, error: 'Escribe el nombre de la categoría.' };
  const datos: Record<string, any> = {
    nombre, unidad: _texto(params.unidad ?? actual?.unidad, 30) || 'porciones',
    por_persona: _num(params.porPersona) ?? Number(actual?.por_persona ?? 1),
  };
    if (params.falta !== undefined) datos.falta = params.falta === true || params.falta === 'true';
  if (params.modo !== undefined) datos.modo = MODOS_SECCION.includes(String(params.modo)) ? String(params.modo) : 'meta';
    if (params.total !== undefined) datos.total = _num(params.total);
  if (params.sugerencias !== undefined) datos.sugerencias = _sugerenciasComida(_json(params.sugerencias) ?? params.sugerencias);
  if (params.cupoTipo !== undefined) {
    const t = String(params.cupoTipo);
    datos.cupo_tipo = t === 'fijo' || t === 'persona' ? t : null;
    datos.cupo = datos.cupo_tipo ? _num(params.cupo) : null;
  }
  if (actual) {
    await db.from('social_comida_categorias').update(datos).eq('id', id);
    // Avisa a lxs asistentes cuando algo pasa a "hace falta".
    if (datos.falta === true && actual.falta !== true && deps.push) {
      const asisten = [...(await _asistentes(db, q.idEvento))].filter((u) => u !== q.username);
      if (asisten.length) {
        deps.push({
          tipo: 'evento_editado', include_external_user_ids: asisten, evento: { idEvento: q.idEvento },
          headings: { es: 'Hace falta en la fiesta' }, contents: { es: `Falta ${nombre}. Si puedes llevar, anótate en el evento.` }, url: _url(deps, q.idEvento),
        }).catch(() => {});
      }
    }
  } else {
    const { data: ult } = await db.from('social_comida_categorias').select('orden').eq('id_evento', q.idEvento).order('orden', { ascending: false }).limit(1);
    await db.from('social_comida_categorias').insert({ ...datos, id_evento: q.idEvento, liga_id: liga, orden: Number(ult?.[0]?.orden ?? -1) + 1 });
    if (!cfg.comida) await db.from('social_eventos').update({ comida: true }).eq('id_evento', q.idEvento);
  }
  return { exito: true };
}


async function socialAnotarComida(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const { data: cat } = await db.from('social_comida_categorias').select('*').eq('id', String(params.categoriaId ?? '')).maybeSingle();
  if (!cat) return { exito: false, error: 'No encontramos esa categoría.' };
  const q = await _quien({ ...params, idEvento: cat.id_evento }, deps);
  if ('error' in q) return { exito: false, error: q.error };
  if (!q.clave || q.idEvento !== cat.id_evento) return { exito: false, error: 'No encontramos esa categoría.' };
  const cfgC = await _config(db, cat.id_evento);
  const vC = _vista(q, cfgC);
  if (vC === 'oculta' || !piezaVisible(cfgC, 'comida', vC)) return { exito: false, error: 'No encontramos esa categoría.' };
    // En secciones "cada persona lleva N" o libres, cada anotación es una cosa.
  const porCosa = cat.modo === 'cada' || cat.modo === 'libre';
  const cantidad = porCosa ? 1 : _num(params.cantidad);
  if (!cantidad || cantidad <= 0) return { exito: false, error: 'Indica cuánto llevas.' };
  if (porCosa && !_texto(params.detalle, 80)) return { exito: false, error: 'Escribe qué llevas.' };
    const asisten = await _asistentes(db, cat.id_evento);
  if (!_asiste(q, asisten)) return { exito: false, error: 'Primero confirma tu asistencia para anotarte.' };
  // Comida y bebida: siempre se puede llevar de más. Las cosas con cupo, hasta llenarlo (Victor, 2026-11-20).
  if (cat.cupo_tipo && !_esComida(cat)) {
    const [invitados, { data: aps }] = await Promise.all([
      _invitados(db, cat.id_evento),
      db.from('social_comida_aportes').select('cantidad').eq('categoria_id', cat.id),
    ]);
    const total = asisten.size + invitados.filter((i: any) => asisten.has(i.anfitrion) && i.nombre).length;
    const limite = _limiteSeccion(cat, total);
    const aportado = (aps ?? []).reduce((s: number, a: any) => s + Number(a.cantidad ?? 0), 0);
    if (limite > 0 && aportado + cantidad > limite) {
      return { exito: false, error: aportado >= limite ? `${cat.nombre} ya llegó a su cupo. Elige otra sección.` : `En ${cat.nombre} quedan ${limite - aportado}.` };
    }
  }


  const pt = params.paraTodxs;
  const { error } = await db.from('social_comida_aportes').insert({
    categoria_id: cat.id, clave: q.clave, nombre: q.nombre, cantidad, detalle: _texto(params.detalle, 80) || null, liga_id: liga,
    para_todxs: pt === true || pt === 'true' ? true : pt === false || pt === 'false' ? false : null,
  });
  if (error) return { exito: false, error: 'No se pudo guardar: ' + error.message };
  return { exito: true };
}

async function socialQuitarAporte(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db;
  const { data: ap } = await db.from('social_comida_aportes').select('id, clave, categoria_id').eq('id', String(params.id ?? '')).maybeSingle();
  if (!ap) return { exito: false, error: 'No encontramos ese aporte.' };
  const { data: cat } = await db.from('social_comida_categorias').select('id_evento').eq('id', ap.categoria_id).maybeSingle();
  const q = await _quien({ ...params, idEvento: cat?.id_evento ?? '-' }, deps);
  if ('error' in q) return { exito: false, error: q.error };
  if (ap.clave !== q.clave && !_organiza(q, await _config(db, cat?.id_evento ?? '-'))) return { exito: false, error: 'Solo puedes quitar lo que anotaste tú.' };
  await db.from('social_comida_aportes').delete().eq('id', ap.id);
  return { exito: true };
}

// ─── Qué traer ────────────────────────────────────────────────────────────

async function socialAnotarTraer(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  const cfg = await _config(db, q.idEvento);
  const vT = cfg ? _vista(q, cfg) : 'oculta';
  if (!q.clave || !cfg || vT === 'oculta' || !piezaVisible(cfg, 'traer', vT)) return { exito: false, error: 'No encontramos este evento.' };
  const items: any[] = _piezas(cfg).traer?.items ?? [];
  const it = items.find((x) => x.id === String(params.item ?? ''));
  if (!it) return { exito: false, error: 'Esa cosa ya no está en la lista.' };
  if (!_asiste(q, await _asistentes(db, q.idEvento))) return { exito: false, error: 'Primero confirma tu asistencia para anotarte.' };
  const { data: ya } = await db.from('social_traer_anotes').select('clave').eq('id_evento', q.idEvento).eq('item', it.id);
  if ((ya ?? []).some((a: any) => a.clave === q.clave)) return { exito: false, error: 'Ya te anotaste con esto.' };
  const cantidad = _num(it.cantidad);
  if (cantidad && (ya ?? []).length >= cantidad) return { exito: false, error: `"${it.texto}" ya está completo.` };
  const { error } = await db.from('social_traer_anotes').insert({
    id_evento: q.idEvento, item: it.id, clave: q.clave, nombre: q.nombre, detalle: _texto(params.detalle, 80) || null, liga_id: liga,
  });
  if (error) return { exito: false, error: _esFaltaColumna(error) ? FALTA_MIGRACION : 'No se pudo guardar: ' + error.message };
  return { exito: true };
}

async function socialQuitarTraer(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db;
  const { data: a } = await db.from('social_traer_anotes').select('id, clave, id_evento').eq('id', String(params.id ?? '')).maybeSingle();
  if (!a) return { exito: false, error: 'No encontramos esa anotación.' };
  const q = await _quien({ ...params, idEvento: a.id_evento }, deps);
  if ('error' in q) return { exito: false, error: q.error };
  if (a.clave !== q.clave && !_organiza(q, await _config(db, a.id_evento))) return { exito: false, error: 'Solo puedes quitar lo que anotaste tú.' };
  await db.from('social_traer_anotes').delete().eq('id', a.id);
  return { exito: true };
}

// ─── Editar una tarjeta (Victor, 2026-11-20) ───────────────────────────────
// Quien organiza cambia una pieza desde su tarjeta, sin pasar por el asistente.

const AREA_DE_PIEZA: Record<string, string> = { amigo: 'amigo', robado: 'amigo', playlist: 'extras', dress: 'extras', invitados: 'invitados' };

async function socialEditarPieza(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db;
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  const cfg = await _config(db, q.idEvento);
  const pieza = String(params.pieza ?? '');
  const area = AREA_DE_PIEZA[pieza];
  if (!cfg || !area) return { exito: false, error: 'No encontramos esa parte del evento.' };
  if (!_organiza(q, cfg)) return { exito: false, error: 'Solo quienes organizan pueden cambiar esto.' };
  const mis = _misPermisos(q, cfg);
  if (mis && !mis.includes(area)) return { exito: false, error: 'No estás a cargo de esta parte del evento.' };
  const d = _json(params.datos) ?? {};
  const piezas = { ..._piezas(cfg) };
  const fila: Record<string, any> = {};
  switch (pieza) {
    case 'amigo': {
      if (d.tope !== undefined) fila.tope_amigo = _num(d.tope);
      if (typeof d.cierre === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(d.cierre)) {
        if (cfg.sorteado_en) return { exito: false, error: 'El sorteo ya se hizo: el cierre no se puede cambiar.' };
        const ev = await _evento(db, q.idEvento);
        const limite = ev ? _restarDias(ev.fecha, DIAS_CIERRE_MIN) : d.cierre;
        fila.cierre = d.cierre > limite ? limite : d.cierre;
      }
      break;
    }
    case 'robado':
      if (d.tope !== undefined) fila.tope_robado = _num(d.tope);
      if (d.recordatorio !== undefined) fila.recordatorio_robado = _texto(d.recordatorio, 300) || null;
      if (d.reglas !== undefined) fila.reglas_robado = _reglas(d.reglas);
      if (d.juego !== undefined) piezas.juegoRobado = reglasJuego(d.juego);
      break;
    case 'playlist':
      piezas.playlist = { link: _link(d.link), nota: _texto(d.nota, 200) };
      break;
    case 'dress':
      piezas.dress = { texto: _textoLargo(d.texto, 400) };
      break;
    case 'invitados':
      if (d.activo !== undefined) fila.invitados = d.activo === true;
      if (d.max !== undefined) piezas.maxInvitados = _maxInvitados(d.max);
      break;
  }
  fila.piezas = piezas;
  if ('actualizado_en' in cfg) fila.actualizado_en = new Date().toISOString();
  const { error } = await db.from('social_eventos').update(fila).eq('id_evento', q.idEvento);
  if (error) return { exito: false, error: 'No se pudo guardar: ' + error.message };
  return { exito: true };
}

// ─── Regalo robado en vivo (Victor, 2026-11-20) ────────────────────────────
// Ver social_juego.ts. Lo dirige quien organiza o tiene el área "amigo";
// se activa el día del evento; todxs lo ven en vivo (sin notificaciones).

function _dirigeJuego(q: Quien, cfg: any): boolean {
  if (!_organiza(q, cfg)) return false;
  const a = _misPermisos(q, cfg);
  return a === null || a.includes('amigo');
}

async function socialJuego(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  const cfg = await _config(db, q.idEvento);
  if (!cfg || !cfg.regalo_robado || !piezaVisible(cfg, 'regaloRobado', _vista(q, cfg))) return { exito: false, error: 'Este evento no tiene regalo robado.' };
  const ev = await _evento(db, q.idEvento);
  if (!ev) return { exito: false, error: 'Evento inválido.' };
  const reglas = reglasJuego(_piezas(cfg).juegoRobado);
  const dirige = _dirigeJuego(q, cfg);
  const hoy = ev.fecha === _hoyEc();
  const { data: fila } = await db.from('social_regalo_juego').select('estado').eq('id_evento', q.idEvento).maybeSingle();
  let estado: EstadoJuego | null = fila?.estado?.fase ? fila.estado : null;
  const accion = String(params.accion ?? 'ver');
  const responder = () => ({ exito: true, dirige, hoy, reglas, juego: estado ? vistaJuego(estado, q.clave, reglas) : null });
  if (accion === 'ver') return responder();

  const guardar = async (e: EstadoJuego | null) => {
    if (e) {
      const { error } = await db.from('social_regalo_juego').upsert({ id_evento: q.idEvento, liga_id: liga, estado: e, updated_at: new Date().toISOString() });
      if (error) throw new Error('No se pudo guardar el juego.');
    } else {
      await db.from('social_regalo_juego').delete().eq('id_evento', q.idEvento);
    }
    estado = e;
  };

  // Cada quien puede marcar que dejó su regalo en la pila.
  if (accion === 'mio') {
    if (!estado || estado.fase !== 'pila') return { exito: false, error: 'Los regalos ya están en la pila.' };
    if (!estado.participantes.some((x) => x.clave === q.clave)) return { exito: false, error: 'No estás en la lista del juego.' };
    const r = aplicar(estado, 'dejo', { clave: q.clave, valor: params.valor }, reglas, _ahoraEc());
    if ('error' in r) return { exito: false, error: r.error };
    await guardar(r);
    return responder();
  }

  if (!dirige) return { exito: false, error: 'Solo quien dirige el regalo robado puede hacer esto.' };
  if (accion === 'iniciar') {
    if (!hoy) return { exito: false, error: 'El juego se activa el día del evento.' };
    if (estado && estado.fase !== 'terminado') return responder();
    const [asisten, invitados] = await Promise.all([_asistentes(db, q.idEvento), _invitados(db, q.idEvento)]);
    const ps = _participantes(asisten, invitados);
    const nombres = await _personas(db, ps.filter((x) => !x.clave.startsWith('inv:')).map((x) => x.clave));
    const inv = new Map(invitados.map((i: any) => [`inv:${i.id}`, String(i.nombre ?? '')]));
    const lista = ps.map((x) => ({ clave: x.clave, nombre: (x.clave.startsWith('inv:') ? inv.get(x.clave) : nombres.get(x.clave)?.nombre) || 'Alguien' }))
      .sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'));
    if (lista.length < 2) return { exito: false, error: 'Para jugar hacen falta al menos 2 personas con "Asistiré".' };
    await guardar(nuevoJuego(lista));
    return responder();
  }
  if (accion === 'reiniciar') {
    await guardar(null);
    return responder();
  }
  if (!estado) return { exito: false, error: 'El juego todavía no empezó.' };
  const r = aplicar(estado, accion, params, reglas, _ahoraEc());
  if ('error' in r) return { exito: false, error: r.error };
  await guardar(r);
  return responder();
}

// ─── Homenaje: mensajes y regalo entre todxs ──────────────────────────────

/// Quien puede escribir mensajes y aportar: cuenta de la liga que ve el
/// detalle completo y no es una persona homenajeada.
async function _paraHomenaje(params: Record<string, any>, deps: DepsSocial): Promise<{ q: Quien; cfg: any } | { error: string }> {
  const q = await _quien(params, deps);
  if ('error' in q) return q;
  const cfg = await _config(deps.db, q.idEvento);
  const v = cfg ? _vista(q, cfg) : 'oculta';
  if (!cfg || !q.clave || (v !== 'completa' && v !== 'organiza') || !_piezas(cfg).homenaje || homenajeadxs(cfg).includes(q.clave)) {
    return { error: 'No encontramos este evento.' };
  }
  return { q, cfg };
}

async function socialMensaje(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const r = await _paraHomenaje(params, deps);
  if ('error' in r) return { exito: false, error: r.error };
  const { q, cfg } = r;
  if (q.tipo === 'invitado') return { exito: false, error: 'Lxs +1 pueden aportar al regalo, pero no escribir mensajes.' };
  if (_piezas(cfg).homenaje.mensajes === false) return { exito: false, error: 'Este homenaje no tiene mensajes.' };
  const para = _texto(params.para, 80);
  if (!homenajeadxs(cfg).includes(para)) return { exito: false, error: 'Elige a quién le escribes.' };
  const texto = _textoLargo(params.texto, 1000);
  if (!texto) {
    await db.from('social_mensajes').delete().eq('id_evento', q.idEvento).eq('para', para).eq('clave', q.clave);
    return { exito: true, borrado: true };
  }
  const { error } = await db.from('social_mensajes').upsert({
    id_evento: q.idEvento, para, clave: q.clave, nombre: q.nombre, texto, updated_at: new Date().toISOString(), liga_id: liga,
  }, { onConflict: 'id_evento,para,clave' });
  if (error) return { exito: false, error: _esFaltaColumna(error) ? FALTA_MIGRACION : 'No se pudo guardar: ' + error.message };
  return { exito: true };
}

/// Regalo entre todxs: solo se anota quién aporta cuánto. No pasa por
/// Finanzas ni crea movimientos. Monto 0 o vacío quita el aporte.
async function socialAportarRegalo(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const r = await _paraHomenaje(params, deps);
  if ('error' in r) return { exito: false, error: r.error };
  const { q, cfg } = r;
  if (!_piezas(cfg).homenaje.regalo) return { exito: false, error: 'Este homenaje no tiene regalo entre todxs.' };
  const monto = _num(params.monto);
  if (!monto) {
    await db.from('social_regalo_aportes').delete().eq('id_evento', q.idEvento).eq('clave', q.clave);
    return { exito: true, borrado: true };
  }
  const { data: otros } = await db.from('social_regalo_aportes').select('clave, monto').eq('id_evento', q.idEvento);
  const resto = (otros ?? []).filter((a: any) => a.clave !== q.clave).reduce((s: number, a: any) => s + Number(a.monto ?? 0), 0);
  const tope = cfg.regalo_tope == null ? null : Number(cfg.regalo_tope);
  if (tope != null && resto + monto > tope) {
    const queda = Math.max(0, tope - resto);
    return { exito: false, error: queda > 0 ? `Con tu aporte se pasa del tope. Faltan ${Math.round(queda * 100) / 100}.` : 'Ya se juntó todo el regalo.' };
  }
  const { error } = await db.from('social_regalo_aportes').upsert({
    id_evento: q.idEvento, clave: q.clave, nombre: q.nombre, monto: Math.round(monto * 100) / 100, liga_id: liga,
  }, { onConflict: 'id_evento,clave' });
  if (error) return { exito: false, error: _esFaltaColumna(error) ? FALTA_MIGRACION : 'No se pudo guardar: ' + error.message };
  return { exito: true };
}

async function socialLiberarMensajes(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db;
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  const cfg = await _config(db, q.idEvento);
  if (!cfg || !_organiza(q, cfg)) return { exito: false, error: 'Solo quien organiza puede liberar los mensajes.' };
  if (cfg.mensajes_liberados_en) return { exito: true };
  const { error } = await db.from('social_eventos').update({ mensajes_liberados_en: new Date().toISOString() }).eq('id_evento', q.idEvento);
  if (error) return { exito: false, error: _esFaltaColumna(error) ? FALTA_MIGRACION : 'No se pudo guardar: ' + error.message };
  const hom = homenajeadxs(cfg);
  if (deps.push && hom.length) {
    try {
      await deps.push({
        tipo: 'social', include_external_user_ids: hom, personal: true,
        headings: { es: 'Tienes mensajes de tu liga' }, contents: { es: 'Entra al evento para leerlos.' }, url: _url(deps, q.idEvento),
      });
    } catch { /* best-effort */ }
  }
  return { exito: true };
}

// ─── Cierre y sorteo (quien organiza) ─────────────────────────────────────

async function socialSortear(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  const idEvento = q.idEvento;
  const [ev, cfg] = await Promise.all([_evento(db, idEvento), _config(db, idEvento)]);
  if (!ev || !cfg) return { exito: false, error: 'Este evento no tiene amigo secreto configurado.' };
  if (!_organiza(q, cfg)) return { exito: false, error: 'Solo quien organiza puede hacer el sorteo.' };
  const email = q.pivotEmail ?? q.clave ?? '';
  if (!publicado(cfg)) return { exito: false, error: 'Primero un Pivot tiene que aprobar el evento.' };
  if (!cfg.amigo_secreto) return { exito: false, error: 'Este evento no tiene amigo secreto.' };
  const rehacer = params.rehacer === true || params.rehacer === 'true';
  if (cfg.sorteado_en && !rehacer) return { exito: false, error: 'El sorteo ya se hizo.' };
  const [asisten, invitados] = await Promise.all([_asistentes(db, idEvento), _invitados(db, idEvento)]);
  // Amigo secreto escondido a quienes no deben enterarse: no entran al sorteo (ni sus +1).
  const fuera = (u: string) => !piezaVisible(cfg, 'amigoSecreto', esSecretoPara(cfg, u) ? 'neutral' : 'completa');
  const ps = _participantes(new Set([...asisten].filter((u) => !fuera(u))), invitados.filter((i) => !fuera(i.anfitrion)));
  const anio = Number(String(ev.fecha).substring(0, 4));
  // Historial: quién le regaló a quién el año anterior en esta liga.
  const { data: previas } = await db.from('social_sorteo').select('da, recibe').eq('liga_id', liga).eq('anio', anio - 1).neq('id_evento', idEvento);
    const noTocar: [string, string][] = Array.isArray(_piezas(cfg).noTocar) ? _piezas(cfg).noTocar : [];
  const r = sortearAmigoSecreto(ps, previas ?? [], Math.random, noTocar);
  if (!r.ok) return { exito: false, error: (r as { error: string }).error };
  await db.from('social_sorteo').delete().eq('id_evento', idEvento);
  const { error } = await db.from('social_sorteo').insert(r.pares.map((x) => ({ id_evento: idEvento, da: x.da, recibe: x.recibe, anio, liga_id: liga })));
  if (error) return { exito: false, error: 'No se pudo guardar el sorteo: ' + error.message };
  await db.from('social_eventos').update({ sorteado_en: new Date().toISOString(), sorteado_por: email }).eq('id_evento', idEvento);
  const miembros = ps.filter((p) => !p.clave.startsWith('inv:')).map((p) => p.clave);
  if (deps.push && miembros.length) {
    try {
      await deps.push({
        tipo: 'social',
        include_external_user_ids: miembros,
        headings: { es: '¡Ya hay amigo secreto!' },
        contents: { es: 'Ya se hizo el sorteo. Entra al evento para descubrir a quién le regalas.' },
        url: _url(deps, idEvento),
      });
    } catch { /* el aviso no frena el sorteo */ }
  }
  return { exito: true, participantes: ps.length, repiteAnterior: r.repiteAnterior };
}

// ─── Calendario ───────────────────────────────────────────────────────────

/// Eventos Social o fiesta en el calendario (lo llama getEventosRango de
/// index.ts): saca los que la persona no debe ver (sin aprobar, no invitadx)
/// y pone a cada uno el nombre que le toca (`socialTitulo`; el neutro para
/// quien no debe enterarse), `socialSorpresa` ("Sorpresa para X", nunca para
/// la vista neutral), `socialEstado` y `socialOrganiza`.
export async function filtrarEventosSociales(eventos: any[], params: Record<string, any>, deps: DepsSocial): Promise<any[]> {
  const sociales = eventos.filter((e) => e?.tipoIcono === 'Social');
  if (!sociales.length) return eventos;
  const { data, error } = await deps.db.from('social_eventos').select('*').in('id_evento', sociales.map((e) => e.idEvento));
  if (error) return eventos;
  const porId = new Map((data ?? []).map((r: any) => [r.id_evento, r]));
  const pivotEmail = params.adminToken ? await deps.validarAdminToken(String(params.adminToken)) : null;
  let username = params.token ? await deps.validarToken(String(params.token)) : null;
  let categoria: string | null = null;
  if (username) {
    const { data: eq } = await deps.db.from('equipo').select('categoria').eq('username', username).maybeSingle();
    categoria = eq?.categoria ?? null;
  } else if (pivotEmail) {
    const c = await _cuentaDePivot(deps.db, pivotEmail);
    (username = c?.username ?? null, categoria = c?.categoria ?? null);
  }
  const personas = await _personas(deps.db, (data ?? []).flatMap((c: any) => homenajeadxs(c)));
  const nombreDe = (u: string) => personas.get(u)?.nombre ?? u;
  const out: any[] = [];
  for (const e of eventos) {
    const cfg: any = e?.tipoIcono === 'Social' ? porId.get(e.idEvento) : null;
    if (!cfg) {
      out.push(e);
      continue;
    }
    const vista = vistaDe(cfg, { username, esPivot: !!pivotEmail, categoria });
    if (vista === 'oculta') continue;
    out.push({
      ...e,
      descripcion: vista === 'neutral' ? '' : (cfg.descripcion || e.descripcion || ''),
      socialTitulo: tituloPara(cfg, vista, nombreDe),
      socialSorpresa: etiquetaSorpresa(cfg, vista, nombreDe),
      socialEstado: _estado(cfg),
            socialOrganiza: vista === 'organiza',
                  // Ícono de fiesta en el calendario, nunca para quien no debe enterarse.
      socialFestivo: vista !== 'neutral',
      ...(vista !== 'neutral' ? { socialIcono: _iconoSocial(cfg) } : {}),
      // Cierre del amigo secreto para el aviso en "Tu asistencia" (Victor, 2026-11-20).
      ...(cfg.amigo_secreto && piezaVisible(cfg, 'amigoSecreto', vista) && e.fecha
        ? { socialCierre: cfg.cierre ?? _cierreDefecto(String(e.fecha).substring(0, 10)), socialSorteado: !!cfg.sorteado_en }
        : {}),
    });
  }
  return out;
}

/// Alcance de los avisos de un evento social (lo usa `_filtrarDestinatariosEvento`
/// de index.ts): sin publicar no le llega a nadie; publicado, solo a quienes
/// están invitadxs. null = no es un evento social (o falta la tabla).
export async function alcanceSocial(db: any, idEvento: string): Promise<{ publicado: boolean; invitadx: (u: string, categoria?: string | null) => boolean } | null> {
  if (!idEvento) return null;
  const { data, error } = await db.from('social_eventos').select('*').eq('id_evento', idEvento).maybeSingle();
  if (error || !data) return null;
  return { publicado: publicado(data), invitadx: (u, categoria) => estaInvitadx(data, u, categoria) };
}

// ─── Aviso del día antes ──────────────────────────────────────────────────

/// El día antes de un evento Social o fiesta publicado, avisa a quienes
/// marcaron Asistiré que lleven el regalo del amigo secreto y/o del regalo
/// robado. Una sola vez por evento (`recordatorio_enviado_en`; sin esa columna
/// no se manda, para no repetirlo). Lo llama cronDiario. Quien no debe
/// enterarse recibe el nombre neutro.
export async function cronSocialRecordatorios(deps: DepsSocial): Promise<number> {
  if (!deps.push) return 0;
  const db = deps.db, liga = deps.ligaEnCurso();
  const manana = _restarDias(_hoyEc(), -1);
  const { data: evs } = await db.from('asistencias').select('id_evento, fecha, inicia, donde, estado').eq('fecha', manana).eq('tipo_evento', 'Social');
  let enviados = 0;
  for (const ev of evs ?? []) {
    if (/cancel|sin entren|no se entrena|eliminado/i.test(String(ev.estado ?? ''))) continue;
    const cfg = await _config(db, ev.id_evento);
        if (!cfg || !('recordatorio_enviado_en' in cfg) || !publicado(cfg) || cfg.recordatorio_enviado_en || !(cfg.amigo_secreto || cfg.regalo_robado || cfg.comida)) continue;
    const asisten = [...(await _asistentes(db, ev.id_evento))];
    await db.from('social_eventos').update({ recordatorio_enviado_en: new Date().toISOString() }).eq('id_evento', ev.id_evento);
    if (!asisten.length) continue;
    const { data: ligaRow } = await db.from('ligas').select('moneda').eq('id', liga).maybeSingle();
    const tope = (n: any) => (n == null ? '' : ` (hasta ${Number(n)}${ligaRow?.moneda ? ' ' + ligaRow.moneda : ''})`);
    const partesDe = (vista: Vista) => [
      cfg.amigo_secreto && cfg.sorteado_en && piezaVisible(cfg, 'amigoSecreto', vista) ? `el regalo de tu amigo secreto${tope(cfg.tope_amigo)}` : '',
      cfg.regalo_robado && piezaVisible(cfg, 'regaloRobado', vista) ? `un regalo envuelto para el regalo robado${tope(cfg.tope_robado)}` : '',
    ].filter(Boolean);
        const personas = await _personas(db, homenajeadxs(cfg));
    const nombreDe = (u: string) => personas.get(u)?.nombre ?? u;
    // Lo que cada quien anotó en "¿Qué llevamos?" (Victor, 2026-11-20): "Mañana llevas: …".
    const llevo = new Map<string, string[]>();
    if (cfg.comida) {
      const { data: cats } = await db.from('social_comida_categorias').select('id, nombre, unidad, modo').eq('id_evento', ev.id_evento);
      const ids = (cats ?? []).map((c: any) => c.id);
      const { data: aps } = ids.length ? await db.from('social_comida_aportes').select('categoria_id, clave, cantidad, detalle').in('categoria_id', ids) : { data: [] };
      for (const a of aps ?? []) {
        const c = (cats ?? []).find((x: any) => x.id === a.categoria_id);
        const que = a.detalle || (c?.modo === 'cada' || c?.modo === 'libre' ? c?.nombre : `${Number(a.cantidad)} ${c?.unidad ?? ''} de ${c?.nombre ?? ''}`.trim());
        if (que) llevo.set(a.clave, [...(llevo.get(a.clave) ?? []), String(que).toLowerCase()]);
      }
    }
    for (const u of asisten) {
      const vista: Vista = esSecretoPara(cfg, u) ? 'neutral' : 'completa';
      const mio = vista === 'completa' || piezaVisible(cfg, 'comida', vista) ? (llevo.get(u) ?? []) : [];
      const partes = [...partesDe(vista), ...mio];
      if (!partes.length) continue;
      try {
        await deps.push({
          tipo: 'recordatorio_1dia',
          include_external_user_ids: [u],
          headings: { es: `¡Mañana es ${tituloPara(cfg, vista, nombreDe)}!` },
          contents: { es: mio.length ? `Mañana llevas: ${listaEs(partes)}.` : `No olvides llevar ${partes.join(' y ')}.` },
          url: _url(deps, ev.id_evento),
          evento: { idEvento: ev.id_evento },
        });
        enviados++;
      } catch { /* best-effort */ }
    }
  }
  return enviados;
}

/// Para pruebas y para index.ts: personas a las que se les esconde la sorpresa.
export { personasEnSecreto };
