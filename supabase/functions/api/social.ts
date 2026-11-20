// Evento social (Naviquinde, Victor 2026-11-19; ver NAVIQUINDE.md y la
// migración 20261119120000_evento_social.sql). Módulo propio para no
// mezclarse con el resto de index.ts: `index.ts` solo deriva aquí las
// acciones de ACCIONES_SOCIAL con sus helpers (cliente de la liga, sesión).
//
// Quién pide:
//  - cuenta del equipo: `token` de sesión (clave = username);
//  - invitadx +1 sin cuenta: `invitadoToken` (clave = 'inv:<id>'). Solo ve lo
//    suyo, su amigo secreto y la comida (sin nombres de otras personas);
//  - Pivot: `adminToken` para configurar, aprobar y sortear.
//  - Encargadxs (2ª ronda, Victor 2026-11-20): personas del equipo que un
//    Pivot elige. Editan la configuración (queda "pendiente de aprobación"
//    hasta que un Pivot la aprueba) y pueden cerrar la inscripción y sortear.
//    El evento solo se ve en el calendario del resto cuando un Pivot lo
//    aprobó (`aprobado_en`; ver filtrarEventosSociales).

import { type ParticipanteSorteo, sortearAmigoSecreto } from './social_sorteo.ts';

export interface DepsSocial {
  db: any;
  validarToken: (t: string) => Promise<string | null>;
  validarAdminToken: (t: string) => Promise<string | null>;
  ligaEnCurso: () => string;
  push?: (p: any) => Promise<unknown>;
  appUrl: string;
}

export const ACCIONES_SOCIAL = new Set([
  'socialGet', 'socialGuardarConfig', 'socialAgregarInvitado', 'socialQuitarInvitado', 'socialGuardarPerfil',
  'socialRevelar', 'socialAnotarComida', 'socialQuitarAporte', 'socialSortear',
  'socialEquipo', 'socialAprobar', 'socialDescartarPendiente',
]);

/// Plantilla de reglas del regalo robado (editable por encargadxs y Pivots).
/// `{tope}` se reemplaza en la app por el tope configurado.
export const PLANTILLA_REGALO_ROBADO = [
  '1. Cada persona trae un regalo envuelto y sin nombre, de hasta {tope}. Solo juega quien trajo regalo.',
  '2. Todos los regalos se ponen juntos en una pila.',
  '3. Se sortea el orden de los turnos.',
  '4. En tu turno eliges: abres un regalo de la pila o robas uno que ya esté abierto.',
  '5. Si te roban, vuelves a elegir: abres uno de la pila o robas otro, pero no el que te acaban de quitar.',
  '6. Un mismo regalo se puede robar como máximo 3 veces. Al tercer robo se queda con esa persona.',
  '7. El juego termina cuando se abre el último regalo de la pila. Quien tuvo el primer turno puede, al final, cambiar su regalo por otro que todavía se pueda robar.',
  '8. Lo importante es pasarla bien juntxs: nada de enojos por un regalo.',
].join('\n');

type Quien = {
  tipo: 'miembro' | 'invitado' | 'pivot';
  clave: string | null;
  nombre: string;
  idEvento: string;
  invitado?: any;
  esPivot: boolean;
  pivotEmail: string | null;
};

const MAX_INVITADOS = 5;
const MAX_LISTA = 30;
const MAX_WISHLIST = 20;
const MAX_FAVORITOS = 2;
const DIAS_CIERRE = 14;

function _texto(v: unknown, max: number): string {
  return String(v ?? '').replace(/\s+/g, ' ').trim().slice(0, max);
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

function _restarDias(iso: string, dias: number): string {
  const d = new Date(iso.substring(0, 10) + 'T12:00:00Z');
  d.setUTCDate(d.getUTCDate() - dias);
  return d.toISOString().substring(0, 10);
}

function _hoyEc(): string {
  return new Date(Date.now() - 5 * 3600 * 1000).toISOString().substring(0, 10);
}

export async function accionSocial(action: string, params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  try {
    switch (action) {
      case 'socialGet': return await socialGet(params, deps);
      case 'socialGuardarConfig': return await socialGuardarConfig(params, deps);
      case 'socialAgregarInvitado': return await socialAgregarInvitado(params, deps);
      case 'socialQuitarInvitado': return await socialQuitarInvitado(params, deps);
      case 'socialGuardarPerfil': return await socialGuardarPerfil(params, deps);
      case 'socialRevelar': return await socialRevelar(params, deps);
      case 'socialAnotarComida': return await socialAnotarComida(params, deps);
      case 'socialQuitarAporte': return await socialQuitarAporte(params, deps);
      case 'socialSortear': return await socialSortear(params, deps);
      case 'socialEquipo': return await socialEquipo(params, deps);
      case 'socialAprobar': return await socialAprobar(params, deps);
      case 'socialDescartarPendiente': return await socialDescartarPendiente(params, deps);
    }
    return { exito: false, error: 'Acción desconocida: ' + action };
  } catch (e) {
    return { exito: false, error: (e as Error).message ?? 'Error interno.' };
  }
}

// ─── Identidad y lecturas comunes ─────────────────────────────────────────

async function _quien(params: Record<string, any>, deps: DepsSocial): Promise<Quien | { error: string }> {
  const pivotEmail = params.adminToken ? await deps.validarAdminToken(String(params.adminToken)) : null;
  if (params.invitadoToken) {
    const { data: inv } = await deps.db.from('social_invitados').select('*').eq('token', String(params.invitadoToken)).maybeSingle();
    if (!inv) return { error: 'Este enlace ya no es válido. Pide uno nuevo a quien te invitó.' };
    return { tipo: 'invitado', clave: 'inv:' + inv.id, nombre: inv.nombre, idEvento: inv.id_evento, invitado: inv, esPivot: false, pivotEmail: null };
  }
  const idEvento = _texto(params.idEvento, 200);
  if (!idEvento) return { error: 'Evento inválido.' };
  const username = params.token ? await deps.validarToken(String(params.token)) : null;
  if (username) {
    const { data: eq } = await deps.db.from('equipo').select('username, nombre_derby').eq('username', username).maybeSingle();
    const nombre = (eq?.nombre_derby ?? '').trim() || username;
    return { tipo: 'miembro', clave: username, nombre, idEvento, esPivot: !!pivotEmail, pivotEmail };
  }
  if (pivotEmail) return { tipo: 'pivot', clave: null, nombre: pivotEmail, idEvento, esPivot: true, pivotEmail };
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

function _encargados(cfg: any): string[] {
  return Array.isArray(cfg?.encargados) ? cfg.encargados.map((x: unknown) => String(x)) : [];
}

/// Pivots y encargadxs organizan (editan, sortean).
function _organiza(q: Quien, cfg: any): boolean {
  return q.esPivot || (q.tipo === 'miembro' && !!q.clave && _encargados(cfg).includes(q.clave));
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
  if (!usernames.length) return out;
  const { data } = await db.from('equipo').select('username, nombre_derby, foto_perfil').in('username', usernames);
  for (const r of data ?? []) out.set(r.username, { nombre: (r.nombre_derby ?? '').trim() || r.username, foto: r.foto_perfil ?? '' });
  for (const u of usernames) if (!out.has(u)) out.set(u, { nombre: u, foto: '' });
  return out;
}

const PERFIL_VACIO = { gustos: [], sobreMi: [], noRegalar: [], tallas: {}, wishlist: [] };

function _perfilSalida(r: any): Record<string, any> {
  if (!r) return { ...PERFIL_VACIO };
  return { gustos: r.gustos ?? [], sobreMi: r.sobre_mi ?? [], noRegalar: r.no_regalar ?? [], tallas: r.tallas ?? {}, wishlist: r.wishlist ?? [] };
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
    ...invitados.filter((i) => asisten.has(i.anfitrion)).map((i) => ({ clave: 'inv:' + i.id, grupo: i.anfitrion })),
  ];
}

function _enlace(deps: DepsSocial, token: string): string {
  return `${deps.appUrl.replace(/\/+$/, '')}/?social=${encodeURIComponent(token)}`;
}

/// Si quien pide participa del evento (para la comida): Asistiré, o +1 de alguien que asiste.
function _asiste(q: Quien, asisten: Set<string>): boolean {
  if (q.tipo === 'invitado') return asisten.has(q.invitado.anfitrion);
  return !!q.clave && asisten.has(q.clave);
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
  const evento = {
    id: ev.id_evento, fecha: ev.fecha, lugar: ev.donde, inicia: ev.inicia, termina: ev.termina, tipo: ev.tipo_evento,
    estado: ev.estado, info: ev.info_adicional ?? '', mapa: q.tipo === 'invitado' ? (ev.google_maps ?? '') : undefined,
    liga: ligaRow?.nombre ?? '', moneda: ligaRow?.moneda ?? '',
  };
  if (!cfg) return { exito: true, social: null, evento, esPivot: q.esPivot };
  const organiza = _organiza(q, cfg);
  if (!cfg.aprobado_en && !organiza) return { exito: false, error: 'Este evento todavía no está publicado.' };

  const [asisten, invitados, sorteo] = await Promise.all([
    _asistentes(db, q.idEvento),
    _invitados(db, q.idEvento),
    db.from('social_sorteo').select('da, recibe, revelado_en').eq('id_evento', q.idEvento).then((r: any) => r.data ?? []),
  ]);
  const invitadosQueCuentan = invitados.filter((i) => asisten.has(i.anfitrion));
  const total = asisten.size + invitadosQueCuentan.length;
  const cierre = cfg.cierre ?? _restarDias(ev.fecha, DIAS_CIERRE);
  const social = {
    amigoSecreto: cfg.amigo_secreto, regaloRobado: cfg.regalo_robado, comida: cfg.comida, invitados: cfg.invitados,
    topeAmigo: cfg.tope_amigo, topeRobado: cfg.tope_robado, recordatorioRobado: cfg.recordatorio_robado ?? '',
    cierre, inscripcionAbierta: !cfg.sorteado_en && _hoyEc() <= cierre, sorteado: !!cfg.sorteado_en,
    reglasRobado: cfg.reglas_robado ?? PLANTILLA_REGALO_ROBADO, reglasPorDefecto: !cfg.reglas_robado,
    aprobado: !!cfg.aprobado_en,
  };

  const out: Record<string, any> = { exito: true, social, evento, esPivot: q.esPivot, tipo: q.tipo, organiza };
  out.yo = { nombre: q.nombre, asiste: _asiste(q, asisten), anfitrion: null as string | null };
  if (q.tipo === 'invitado') out.yo.anfitrion = (await _personas(db, [q.invitado.anfitrion])).get(q.invitado.anfitrion)?.nombre ?? '';
  // Lxs +1 no ven la lista de asistentes, solo cuántxs son (para la comida).
  out.conteo = { asistentes: asisten.size, invitados: invitadosQueCuentan.length, total };

  if (q.tipo === 'miembro') {
    out.misInvitados = invitados.filter((i) => i.anfitrion === q.clave).map((i) => ({
      id: i.id, nombre: i.nombre, contacto: i.contacto ?? '', enlace: _enlace(deps, i.token),
      enSorteo: sorteo.some((s: any) => s.da === 'inv:' + i.id),
    }));
  }
  if (q.clave) out.perfil = await _perfil(db, liga, q.clave);

  // Amigo secreto: estado y, si ya se reveló, la ficha de quien le tocó.
  if (cfg.amigo_secreto && q.clave) {
    const mio = sorteo.find((s: any) => s.da === q.clave);
    if (!cfg.sorteado_en) out.amigo = { estado: 'sin_sorteo' };
    else if (!mio) out.amigo = { estado: 'fuera' };
    else if (!mio.revelado_en) out.amigo = { estado: 'por_revelar' };
    else out.amigo = { estado: 'revelado', ficha: await _ficha(db, liga, mio.recibe) };
  }

  if (cfg.comida) {
    const { data: cats } = await db.from('social_comida_categorias').select('*').eq('id_evento', q.idEvento).order('orden');
    const ids = (cats ?? []).map((c: any) => c.id);
    const { data: aportes } = ids.length
      ? await db.from('social_comida_aportes').select('*').in('categoria_id', ids).order('created_at')
      : { data: [] };
    out.comida = (cats ?? []).map((c: any) => {
      const ap = (aportes ?? []).filter((a: any) => a.categoria_id === c.id);
      const aportado = ap.reduce((s: number, a: any) => s + Number(a.cantidad ?? 0), 0);
      const meta = Math.ceil(total * Number(c.por_persona ?? 0));
      return {
        id: c.id, nombre: c.nombre, unidad: c.unidad, porPersona: Number(c.por_persona ?? 0), meta, aportado,
        cerrada: meta > 0 && aportado >= meta,
        // Lxs +1 solo ven lo que llevan ellxs.
        aportes: ap.filter((a: any) => q.tipo !== 'invitado' || a.clave === q.clave).map((a: any) => ({
          id: a.id, nombre: a.nombre, cantidad: Number(a.cantidad), detalle: a.detalle ?? '', mio: a.clave === q.clave,
        })),
      };
    });
  }

  if (organiza) {
    const enc = _encargados(cfg);
    const nombres = await _personas(db, enc);
    out.encargados = enc.map((u) => ({ username: u, nombre: nombres.get(u)?.nombre ?? u }));
    out.esEncargadx = q.tipo === 'miembro' && enc.includes(q.clave ?? '');
    if (cfg.pendiente) {
      out.pendiente = { ...cfg.pendiente, por: cfg.pendiente_por ?? '', en: cfg.pendiente_en };
    }
  }
  if (organiza) {
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

// ─── Configuración (solo Pivots) ──────────────────────────────────────────

async function socialGuardarConfig(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  const idEvento = q.idEvento;
  const ev = await _evento(db, idEvento);
  if (!ev) return { exito: false, error: 'No encontramos este evento.' };
  if (ev.tipo_evento !== 'Social') return { exito: false, error: 'Solo los eventos de tipo Social tienen estas opciones.' };
  const previa = await _config(db, idEvento);
  if (!previa && !q.esPivot) return { exito: false, error: 'Solo un Pivot puede crear el evento social.' };
  if (previa && !_organiza(q, previa)) return { exito: false, error: 'Solo Pivots y encargadxs pueden cambiar el evento.' };
  const cambios = { config: _json(params.config) ?? {}, categorias: _json(params.categorias), evento: _json(params.evento) ?? {} };
  if (q.esPivot) {
    const r = await _aplicarConfig(db, liga, ev, previa, cambios, q.pivotEmail!, true);
    if (!r.exito) return r;
    if (params.publicar === true || params.publicar === 'true') {
      const pub = await _publicar(db, deps, idEvento, q.pivotEmail!);
      if (!pub.exito) return pub;
    }
    return r;
  }
  // Encargadx: queda pendiente hasta que un Pivot lo apruebe.
  const resumen = await _resumenCambios(db, ev, previa, cambios);
  if (!resumen.length) return { exito: true, pendiente: false, avisos: ['No hay cambios.'] };
  const { error } = await db.from('social_eventos').update({
    pendiente: { ...cambios, resumen }, pendiente_por: q.nombre, pendiente_en: new Date().toISOString(),
  }).eq('id_evento', idEvento);
  if (error) return { exito: false, error: 'No se pudo guardar: ' + error.message };
  return { exito: true, pendiente: true, avisos: ['Tus cambios quedan pendientes hasta que un Pivot los apruebe.'] };
}

/// Qué cambia una propuesta, en palabras (para quien aprueba).
async function _resumenCambios(db: any, ev: any, cfg: any, cambios: any): Promise<string[]> {
  const c = cambios.config ?? {}, e = cambios.evento ?? {};
  const out: string[] = [];
  const si = (b: boolean) => (b ? 'sí' : 'no');
  const bool = (k: string, col: string, etiqueta: string, def: boolean) => {
    if (c[k] === undefined) return;
    const nuevo = def ? c[k] !== false : c[k] === true;
    if (nuevo !== !!cfg?.[col]) out.push(`${etiqueta}: ${si(nuevo)}`);
  };
  bool('amigoSecreto', 'amigo_secreto', 'Amigo secreto', true);
  bool('regaloRobado', 'regalo_robado', 'Regalo robado', false);
  bool('comida', 'comida', 'Comida compartida', true);
  bool('invitados', 'invitados', 'Se admiten +1', true);
  const num = (k: string, col: string, etiqueta: string) => {
    if (c[k] === undefined) return;
    const a = cfg?.[col] == null ? null : Number(cfg[col]), b = _num(c[k]);
    if (a !== b) out.push(`${etiqueta}: ${a ?? 'sin tope'} → ${b ?? 'sin tope'}`);
  };
  num('topeAmigo', 'tope_amigo', 'Tope del amigo secreto');
  num('topeRobado', 'tope_robado', 'Tope del regalo robado');
  if (c.recordatorioRobado !== undefined && (_texto(c.recordatorioRobado, 300) || null) !== (cfg?.recordatorio_robado ?? null)) out.push('Recordatorio del regalo robado');
  if (c.reglasRobado !== undefined && _reglas(c.reglasRobado) !== (cfg?.reglas_robado ?? null)) out.push('Reglas del regalo robado');
  if (typeof c.cierre === 'string' && c.cierre !== cfg?.cierre) out.push(`Cierre de la inscripción: ${c.cierre}`);
  if (e.lugar !== undefined && _texto(e.lugar, 120) && _texto(e.lugar, 120) !== (ev.donde ?? '')) out.push(`Lugar: ${_texto(e.lugar, 120)}`);
  if (e.mapa !== undefined && _texto(e.mapa, 500) !== (ev.google_maps ?? '')) out.push('Enlace del mapa');
  const h = (x: unknown) => String(x ?? '').substring(0, 5);
  if ((e.inicia !== undefined && _hora(e.inicia) && _hora(e.inicia) !== h(ev.inicia)) || (e.termina !== undefined && (_hora(e.termina) ?? '') !== h(ev.termina))) {
    out.push(`Horario: ${_hora(e.inicia) ?? h(ev.inicia)}${_hora(e.termina) ? ' – ' + _hora(e.termina) : ''}`);
  }
  if (Array.isArray(cambios.categorias)) {
    const { data: actuales } = await db.from('social_comida_categorias').select('id, nombre, unidad, por_persona').eq('id_evento', ev.id_evento).order('orden');
    const firma = (xs: any[]) => JSON.stringify(xs.map((x) => [x.id ?? null, _texto(x.nombre, 60), _texto(x.unidad, 30) || 'porciones', Number(x.por_persona ?? x.porPersona ?? 1)]));
    if (firma((actuales ?? []).map((x: any) => x)) !== firma(cambios.categorias.filter((x: any) => _texto(x?.nombre, 60)))) out.push('Categorías de comida');
  }
  return out;
}

function _hora(v: unknown): string | null {
  const t = String(v ?? '').trim().substring(0, 5);
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(t) ? t : null;
}

function _reglas(v: unknown): string | null {
  const t = String(v ?? '').replace(/\r/g, '').trim().slice(0, 3000);
  return t && t !== PLANTILLA_REGALO_ROBADO ? t : null;
}

/// Aplica una configuración (de un Pivot, o una propuesta aprobada).
async function _aplicarConfig(db: any, liga: string, ev: any, previa: any, cambios: any, email: string, conEncargados: boolean): Promise<Record<string, any>> {
  const idEvento = ev.id_evento;
  const c = cambios.config ?? {};
  const limite = _restarDias(ev.fecha, DIAS_CIERRE);
  let cierre = typeof c.cierre === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(c.cierre) ? c.cierre : (previa?.cierre ?? limite);
  if (cierre > limite) cierre = limite;
  const fila: Record<string, any> = {
    id_evento: idEvento,
    amigo_secreto: c.amigoSecreto !== false,
    regalo_robado: c.regaloRobado === true,
    comida: c.comida !== false,
    invitados: c.invitados !== false,
    tope_amigo: _num(c.topeAmigo),
    tope_robado: _num(c.topeRobado),
    recordatorio_robado: _texto(c.recordatorioRobado, 300) || null,
    reglas_robado: c.reglasRobado === undefined ? (previa?.reglas_robado ?? null) : _reglas(c.reglasRobado),
    cierre,
    pendiente: null, pendiente_por: null, pendiente_en: null,
    liga_id: liga,
  };
  if (conEncargados && Array.isArray(c.encargados)) {
    const pedidos = [...new Set(c.encargados.map((x: unknown) => _texto(x, 80)).filter(Boolean))].slice(0, 10) as string[];
    const { data: existen } = pedidos.length ? await db.from('equipo').select('username').in('username', pedidos).is('eliminado_en', null) : { data: [] };
    fila.encargados = (existen ?? []).map((r: any) => r.username);
  }
  if (!previa) fila.creado_por = email;
  const { error } = await db.from('social_eventos').upsert(fila, { onConflict: 'id_evento' });
  if (error) return { exito: false, error: 'No se pudo guardar: ' + error.message };

  // Lugar y horario: en el evento y en su regla (venue), porque la
  // regeneración de la ventana copia los datos del venue al evento.
  const e = cambios.evento ?? {};
  const cambioEv: Record<string, any> = {};
  const cambioVenue: Record<string, any> = {};
  const lugar = _texto(e.lugar, 120);
  if (e.lugar !== undefined && lugar && lugar !== ev.donde) (cambioEv.donde = lugar, cambioVenue.lugar = lugar);
  if (e.mapa !== undefined) {
    const mapa = _texto(e.mapa, 500) || null;
    if (mapa !== (ev.google_maps ?? null)) (cambioEv.google_maps = mapa, cambioVenue.google_maps = mapa);
  }
  if (e.inicia !== undefined && _hora(e.inicia)) (cambioEv.inicia = _hora(e.inicia), cambioVenue.inicia = _hora(e.inicia));
  if (e.termina !== undefined) (cambioEv.termina = _hora(e.termina), cambioVenue.finaliza = _hora(e.termina));
  if (Object.keys(cambioEv).length) {
    const { error: e1 } = await db.from('asistencias').update(cambioEv).eq('id_evento', idEvento);
    if (e1) return { exito: false, error: 'No se pudo cambiar el lugar u horario: ' + e1.message };
    if (ev.id_regla) await db.from('venues').update(cambioVenue).eq('id', ev.id_regla);
  }

  // Categorías de la comida: se actualizan por id; las que se quitan se
  // borran solo si nadie se anotó todavía.
  const cats = cambios.categorias;
  const avisos: string[] = [];
  if (Array.isArray(cats)) {
    const { data: actuales } = await db.from('social_comida_categorias').select('id, nombre').eq('id_evento', idEvento);
    const vistos = new Set<string>();
    let orden = 0;
    for (const x of cats.slice(0, 20)) {
      const nombre = _texto(x?.nombre, 60);
      if (!nombre) continue;
      const datos = { nombre, unidad: _texto(x?.unidad, 30) || 'porciones', por_persona: _num(x?.porPersona) ?? 1, orden: orden++ };
      const id = typeof x?.id === 'string' && (actuales ?? []).some((a: any) => a.id === x.id) ? x.id : null;
      if (id) {
        vistos.add(id);
        await db.from('social_comida_categorias').update(datos).eq('id', id);
      } else {
        await db.from('social_comida_categorias').insert({ ...datos, id_evento: idEvento, liga_id: liga });
      }
    }
    for (const a of actuales ?? []) {
      if (vistos.has(a.id)) continue;
      const { count } = await db.from('social_comida_aportes').select('id', { count: 'exact', head: true }).eq('categoria_id', a.id);
      if ((count ?? 0) > 0) avisos.push(`"${a.nombre}" no se quitó porque ya hay personas anotadas.`);
      else await db.from('social_comida_categorias').delete().eq('id', a.id);
    }
  }
  return { exito: true, cierre, avisos };
}

/// Publica el evento (lo ve todo el equipo) y avisa la primera vez.
async function _publicar(db: any, deps: DepsSocial, idEvento: string, email: string): Promise<Record<string, any>> {
  const cfg = await _config(db, idEvento);
  if (!cfg) return { exito: false, error: 'Primero guarda la configuración del evento.' };
  if (cfg.aprobado_en) return { exito: true };
  const { error } = await db.from('social_eventos').update({ aprobado_en: new Date().toISOString(), aprobado_por: email }).eq('id_evento', idEvento);
  if (error) return { exito: false, error: 'No se pudo publicar: ' + error.message };
  const ev = await _evento(db, idEvento);
  if (deps.push && ev) {
    try {
      await deps.push({
        tipo: 'evento_creado',
        broadcastEquipo: true,
        headings: { es: `Nuevo evento social: ${_fechaCorta(ev.fecha)}` },
        contents: { es: [String(ev.inicia ?? '').substring(0, 5), ev.donde].filter(Boolean).join(' · ') + '. Confirma tu asistencia.' },
        url: `${deps.appUrl.replace(/\/+$/, '')}/?evento=${encodeURIComponent(idEvento)}`,
      });
    } catch { /* el aviso no frena la publicación */ }
  }
  return { exito: true, publicado: true };
}

function _fechaCorta(iso: string): string {
  const meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  const d = String(iso ?? '').substring(0, 10).split('-');
  return d.length === 3 ? `${Number(d[2])} de ${meses[Number(d[1]) - 1] ?? ''}` : String(iso ?? '');
}

async function socialAprobar(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const email = await deps.validarAdminToken(String(params.adminToken ?? ''));
  if (!email) return { exito: false, error: 'Solo un Pivot puede aprobar.' };
  const idEvento = _texto(params.idEvento, 200);
  const [ev, cfg] = await Promise.all([_evento(db, idEvento), _config(db, idEvento)]);
  if (!ev || !cfg) return { exito: false, error: 'Este evento no tiene configuración.' };
  let avisos: string[] = [];
  if (cfg.pendiente) {
    const r = await _aplicarConfig(db, liga, ev, cfg, cfg.pendiente, email, false);
    if (!r.exito) return r;
    avisos = r.avisos ?? [];
  }
  const pub = await _publicar(db, deps, idEvento, email);
  if (!pub.exito) return pub;
  return { exito: true, publicado: pub.publicado === true, avisos };
}

async function socialDescartarPendiente(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db;
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  const cfg = await _config(db, q.idEvento);
  if (!cfg || !_organiza(q, cfg)) return { exito: false, error: 'Solo Pivots y encargadxs pueden hacer esto.' };
  await db.from('social_eventos').update({ pendiente: null, pendiente_por: null, pendiente_en: null }).eq('id_evento', q.idEvento);
  return { exito: true };
}

/// Personas del equipo para elegir encargadxs (solo Pivots).
async function socialEquipo(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  if (!(await deps.validarAdminToken(String(params.adminToken ?? '')))) return { exito: false, error: 'Solo Pivots.' };
  const { data } = await deps.db.from('equipo').select('username, nombre_derby').is('eliminado_en', null).order('username');
  return {
    exito: true,
    personas: (data ?? []).map((r: any) => ({ username: r.username, nombre: (r.nombre_derby ?? '').trim() || r.username })),
  };
}

// ─── Invitadxs +1 ─────────────────────────────────────────────────────────

async function socialAgregarInvitado(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  if (q.tipo !== 'miembro') return { exito: false, error: 'Solo personas del equipo pueden sumar invitadxs.' };
  const cfg = await _config(db, q.idEvento);
  if (!cfg?.invitados) return { exito: false, error: 'Este evento no admite invitadxs.' };
  const asisten = await _asistentes(db, q.idEvento);
  if (!asisten.has(q.clave!)) return { exito: false, error: 'Primero marca Asistiré para sumar a tu +1.' };
  const nombre = _texto(params.nombre, 60);
  if (!nombre) return { exito: false, error: 'Escribe el nombre de tu invitadx.' };
  const contacto = _texto(params.contacto, 120);
  const { count } = await db.from('social_invitados').select('id', { count: 'exact', head: true }).eq('id_evento', q.idEvento).eq('anfitrion', q.clave);
  if ((count ?? 0) >= MAX_INVITADOS) return { exito: false, error: `Puedes sumar hasta ${MAX_INVITADOS} invitadxs.` };
  const token = _tokenNuevo();
  const { data, error } = await db.from('social_invitados')
    .insert({ id_evento: q.idEvento, anfitrion: q.clave, nombre, contacto: contacto || null, token, liga_id: liga }).select('id').single();
  if (error) return { exito: false, error: 'No se pudo guardar: ' + error.message };
  return { exito: true, invitado: { id: data.id, nombre, contacto, enlace: _enlace(deps, token), enSorteo: false } };
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
    let link = _texto(x?.link, 500);
    if (link && !/^https?:\/\//i.test(link)) link = 'https://' + link;
    const favorito = x?.favorito === true && favoritos < MAX_FAVORITOS;
    if (favorito) favoritos++;
    wishlist.push({ texto, nota: _texto(x?.nota, 200), link, favorito });
    if (wishlist.length >= MAX_WISHLIST) break;
  }
  const fila = {
    liga_id: liga, clave: q.clave,
    gustos: _lista(p.gustos), sobre_mi: _lista(p.sobreMi), no_regalar: _lista(p.noRegalar),
    tallas, wishlist, updated_at: new Date().toISOString(),
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

async function socialAnotarComida(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const { data: cat } = await db.from('social_comida_categorias').select('*').eq('id', String(params.categoriaId ?? '')).maybeSingle();
  if (!cat) return { exito: false, error: 'No encontramos esa categoría.' };
  const q = await _quien({ ...params, idEvento: cat.id_evento }, deps);
  if ('error' in q) return { exito: false, error: q.error };
  if (!q.clave || q.idEvento !== cat.id_evento) return { exito: false, error: 'No encontramos esa categoría.' };
  const cantidad = _num(params.cantidad);
  if (!cantidad || cantidad <= 0) return { exito: false, error: 'Indica cuánto llevas.' };
  const [asisten, invitados, aportes] = await Promise.all([
    _asistentes(db, cat.id_evento),
    _invitados(db, cat.id_evento),
    db.from('social_comida_aportes').select('cantidad').eq('categoria_id', cat.id).then((r: any) => r.data ?? []),
  ]);
  if (!_asiste(q, asisten)) return { exito: false, error: 'Primero confirma tu asistencia para anotarte.' };
  const total = asisten.size + invitados.filter((i) => asisten.has(i.anfitrion)).length;
  const meta = Math.ceil(total * Number(cat.por_persona ?? 0));
  const aportado = aportes.reduce((s: number, a: any) => s + Number(a.cantidad ?? 0), 0);
  if (meta > 0 && aportado >= meta) return { exito: false, error: `${cat.nombre} ya está completo. Elige otra categoría.` };
  const { error } = await db.from('social_comida_aportes').insert({
    categoria_id: cat.id, clave: q.clave, nombre: q.nombre, cantidad, detalle: _texto(params.detalle, 80) || null, liga_id: liga,
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
  if (ap.clave !== q.clave && !q.esPivot) return { exito: false, error: 'Solo puedes quitar lo que anotaste tú.' };
  await db.from('social_comida_aportes').delete().eq('id', ap.id);
  return { exito: true };
}

// ─── Cierre y sorteo (solo Pivots) ────────────────────────────────────────

async function socialSortear(params: Record<string, any>, deps: DepsSocial): Promise<Record<string, any>> {
  const db = deps.db, liga = deps.ligaEnCurso();
  const q = await _quien(params, deps);
  if ('error' in q) return { exito: false, error: q.error };
  const idEvento = q.idEvento;
  const [ev, cfg] = await Promise.all([_evento(db, idEvento), _config(db, idEvento)]);
  if (!ev || !cfg) return { exito: false, error: 'Este evento no tiene amigo secreto configurado.' };
  if (!_organiza(q, cfg)) return { exito: false, error: 'Solo Pivots y encargadxs pueden hacer el sorteo.' };
  const email = q.pivotEmail ?? q.clave ?? '';
  if (!cfg.aprobado_en) return { exito: false, error: 'Primero un Pivot tiene que aprobar y publicar el evento.' };
  if (!cfg.amigo_secreto) return { exito: false, error: 'Este evento no tiene amigo secreto.' };
  const rehacer = params.rehacer === true || params.rehacer === 'true';
  if (cfg.sorteado_en && !rehacer) return { exito: false, error: 'El sorteo ya se hizo.' };
  const [asisten, invitados] = await Promise.all([_asistentes(db, idEvento), _invitados(db, idEvento)]);
  const ps = _participantes(asisten, invitados);
  const anio = Number(String(ev.fecha).substring(0, 4));
  // Historial: quién le regaló a quién el año anterior en esta liga.
  const { data: previas } = await db.from('social_sorteo').select('da, recibe').eq('liga_id', liga).eq('anio', anio - 1).neq('id_evento', idEvento);
  const r = sortearAmigoSecreto(ps, previas ?? []);
  if (!r.ok) return { exito: false, error: r.error };
  await db.from('social_sorteo').delete().eq('id_evento', idEvento);
  const { error } = await db.from('social_sorteo').insert(r.pares.map((x) => ({ id_evento: idEvento, da: x.da, recibe: x.recibe, anio, liga_id: liga })));
  if (error) return { exito: false, error: 'No se pudo guardar el sorteo: ' + error.message };
  await db.from('social_eventos').update({ sorteado_en: new Date().toISOString(), sorteado_por: email }).eq('id_evento', idEvento);
  const miembros = ps.filter((p) => !p.clave.startsWith('inv:')).map((p) => p.clave);
  if (deps.push && miembros.length) {
    try {
      await deps.push({
        tipo: 'social_sorteo',
        include_external_user_ids: miembros,
        headings: { es: '¡Ya hay amigo secreto!' },
        contents: { es: 'Gira tu ruleta para saber a quién le regalas.' },
        url: `${deps.appUrl.replace(/\/+$/, '')}/?evento=${encodeURIComponent(idEvento)}`,
      });
    } catch { /* el aviso no frena el sorteo */ }
  }
  return { exito: true, participantes: ps.length, repiteAnterior: r.repiteAnterior };
}

// ─── Calendario: eventos sociales sin publicar ────────────────────────────

/// Saca del calendario los eventos Social que ningún Pivot aprobó todavía,
/// salvo para Pivots y sus encargadxs (que los ven marcados `socialBorrador`).
/// Lo llama getEventosRango de index.ts.
export async function filtrarEventosSociales(eventos: any[], params: Record<string, any>, deps: DepsSocial): Promise<any[]> {
  const sociales = eventos.filter((e) => e?.tipoIcono === 'Social');
  if (!sociales.length) return eventos;
  const { data } = await deps.db.from('social_eventos').select('id_evento, aprobado_en, encargados, pendiente_en').in('id_evento', sociales.map((e) => e.idEvento));
  const porId = new Map((data ?? []).map((r: any) => [r.id_evento, r]));
  let quien: string | null | undefined, pivot: boolean | undefined;
  const out: any[] = [];
  for (const e of eventos) {
    if (e?.tipoIcono !== 'Social') {
      out.push(e);
      continue;
    }
    const cfg: any = porId.get(e.idEvento);
    if (cfg?.aprobado_en) {
      out.push(cfg.pendiente_en ? { ...e, socialPendiente: true } : e);
      continue;
    }
    if (pivot === undefined) pivot = !!(params.adminToken && (await deps.validarAdminToken(String(params.adminToken))));
    if (quien === undefined) quien = params.token ? await deps.validarToken(String(params.token)) : null;
    if (pivot || (quien && _encargados(cfg).includes(quien))) out.push({ ...e, socialBorrador: true, socialPendiente: !!cfg?.pendiente_en });
  }
  return out;
}

// ─── Aviso del día antes ──────────────────────────────────────────────────

/// El día antes de un evento Social publicado, avisa a quienes marcaron
/// Asistiré que lleven el regalo del amigo secreto y/o del regalo robado.
/// Una sola vez por evento (`recordatorio_enviado_en`). Lo llama cronDiario.
export async function cronSocialRecordatorios(deps: DepsSocial): Promise<number> {
  if (!deps.push) return 0;
  const db = deps.db, liga = deps.ligaEnCurso();
  const manana = _restarDias(_hoyEc(), -1);
  const { data: evs } = await db.from('asistencias').select('id_evento, fecha, inicia, donde, estado').eq('fecha', manana).eq('tipo_evento', 'Social');
  let enviados = 0;
  for (const ev of evs ?? []) {
    if (/cancel|sin entren|no se entrena|eliminado/i.test(String(ev.estado ?? ''))) continue;
    const cfg = await _config(db, ev.id_evento);
    if (!cfg?.aprobado_en || cfg.recordatorio_enviado_en || !(cfg.amigo_secreto || cfg.regalo_robado)) continue;
    const asisten = [...(await _asistentes(db, ev.id_evento))];
    await db.from('social_eventos').update({ recordatorio_enviado_en: new Date().toISOString() }).eq('id_evento', ev.id_evento);
    if (!asisten.length) continue;
    const { data: ligaRow } = await db.from('ligas').select('moneda').eq('id', liga).maybeSingle();
    const tope = (n: any) => (n == null ? '' : ` (hasta ${Number(n)}${ligaRow?.moneda ? ' ' + ligaRow.moneda : ''})`);
    const partes = [
      cfg.amigo_secreto && cfg.sorteado_en ? `el regalo de tu amigo secreto${tope(cfg.tope_amigo)}` : '',
      cfg.regalo_robado ? `un regalo envuelto para el regalo robado${tope(cfg.tope_robado)}` : '',
    ].filter(Boolean);
    if (!partes.length) continue;
    try {
      await deps.push({
        tipo: 'recordatorio_1dia',
        include_external_user_ids: asisten,
        headings: { es: '¡Mañana es el evento social!' },
        contents: { es: `No olvides llevar ${partes.join(' y ')}.` },
        url: `${deps.appUrl.replace(/\/+$/, '')}/?evento=${encodeURIComponent(ev.id_evento)}`,
      });
      enviados += asisten.length;
    } catch { /* best-effort */ }
  }
  return enviados;
}
