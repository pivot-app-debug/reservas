// Evento social (Naviquinde, Victor 2026-11-19; ver NAVIQUINDE.md y la
// migración 20261119120000_evento_social.sql). Módulo propio para no
// mezclarse con el resto de index.ts: `index.ts` solo deriva aquí las
// acciones de ACCIONES_SOCIAL con sus helpers (cliente de la liga, sesión).
//
// Quién pide:
//  - cuenta del equipo: `token` de sesión (clave = username);
//  - invitadx +1 sin cuenta: `invitadoToken` (clave = 'inv:<id>'). Solo ve lo
//    suyo, su amigo secreto y la comida (sin nombres de otras personas);
//  - Pivot: `adminToken` para configurar y sortear.

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
]);

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
  const { data } = await db.from('asistencias').select('id_evento, fecha, donde, inicia, termina, tipo_evento, estado, info_adicional, google_maps').eq('id_evento', idEvento).maybeSingle();
  return data ?? null;
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
  };

  const out: Record<string, any> = { exito: true, social, evento, esPivot: q.esPivot, tipo: q.tipo };
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

  if (q.esPivot) {
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
  const email = await deps.validarAdminToken(String(params.adminToken ?? ''));
  if (!email) return { exito: false, error: 'Solo Pivots pueden configurar el evento social.' };
  const idEvento = _texto(params.idEvento, 200);
  const ev = await _evento(db, idEvento);
  if (!ev) return { exito: false, error: 'No encontramos este evento.' };
  if (ev.tipo_evento !== 'Social') return { exito: false, error: 'Solo los eventos de tipo Social tienen estas opciones.' };
  const c = _json(params.config) ?? {};
  const limite = _restarDias(ev.fecha, DIAS_CIERRE);
  let cierre = typeof c.cierre === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(c.cierre) ? c.cierre : limite;
  if (cierre > limite) cierre = limite;
  const previa = await _config(db, idEvento);
  const fila: Record<string, any> = {
    id_evento: idEvento,
    amigo_secreto: c.amigoSecreto !== false,
    regalo_robado: c.regaloRobado === true,
    comida: c.comida !== false,
    invitados: c.invitados !== false,
    tope_amigo: _num(c.topeAmigo),
    tope_robado: _num(c.topeRobado),
    recordatorio_robado: _texto(c.recordatorioRobado, 300) || null,
    cierre,
    liga_id: liga,
  };
  if (!previa) fila.creado_por = email;
  const { error } = await db.from('social_eventos').upsert(fila, { onConflict: 'id_evento' });
  if (error) return { exito: false, error: 'No se pudo guardar: ' + error.message };

  // Categorías de la comida: se actualizan por id; las que se quitan se
  // borran solo si nadie se anotó todavía.
  const cats = _json(params.categorias);
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
  const email = await deps.validarAdminToken(String(params.adminToken ?? ''));
  if (!email) return { exito: false, error: 'Solo Pivots pueden hacer el sorteo.' };
  const idEvento = _texto(params.idEvento, 200);
  const [ev, cfg] = await Promise.all([_evento(db, idEvento), _config(db, idEvento)]);
  if (!ev || !cfg) return { exito: false, error: 'Este evento no tiene amigo secreto configurado.' };
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
