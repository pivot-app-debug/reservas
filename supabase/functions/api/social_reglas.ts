// Reglas puras del "Social o fiesta" (Victor, 2026-11-20; NAVIQUINDE.md,
// "Segunda versión"). Sin base de datos: quién organiza, quién ve qué,
// quién puede aprobar y a quién se invita. Pruebas en social_reglas_test.ts.

/// Lo que estas reglas leen de una fila de `social_eventos`.
export interface CfgSocial {
  creador?: string | null;
  encargados?: string[] | null;
  sorpresa?: boolean | null;
  homenajeados?: string[] | null;
  no_enterarse?: string[] | null;
  para?: { tipo?: string; valores?: string[] } | null;
  aprobado_en?: string | null;
  nombre?: string | null;
  nombre_neutro?: string | null;
  mensajes_liberados_en?: string | null;
}

export interface Visitante {
  username: string | null;
  esPivot: boolean;
  categoria?: string | null;
}

/// organiza: edita y ve todo · completa: invitadx que ve todo el detalle ·
/// neutral: homenajeadx o "no debe enterarse" de una sorpresa (lo ve como un
/// evento normal) · oculta: no lo ve (sin publicar o no invitadx).
export type Vista = 'organiza' | 'completa' | 'neutral' | 'oculta';

const lista = (v: unknown): string[] => (Array.isArray(v) ? v.map((x) => String(x)).filter(Boolean) : []);

export function homenajeadxs(cfg: CfgSocial | null | undefined): string[] {
  return lista(cfg?.homenajeados);
}

export function noEnterarse(cfg: CfgSocial | null | undefined): string[] {
  return lista(cfg?.no_enterarse);
}

export function encargadxs(cfg: CfgSocial | null | undefined): string[] {
  return lista(cfg?.encargados);
}

/// Personas que nunca aprueban ni organizan: homenajeadxs y quienes no
/// deben enterarse (haya o no sorpresa).
export function personasEnSecreto(cfg: CfgSocial | null | undefined): Set<string> {
  return new Set([...homenajeadxs(cfg), ...noEnterarse(cfg)]);
}

/// ¿A esta persona hay que esconderle la sorpresa?
export function esSecretoPara(cfg: CfgSocial | null | undefined, username: string | null | undefined): boolean {
  return !!cfg?.sorpresa && !!username && personasEnSecreto(cfg).has(username);
}

/// Publicado en el calendario. Una fila sin la columna `aprobado_en`
/// (migración 20261120100000 sin aplicar) es de la primera versión: publicada.
export function publicado(cfg: CfgSocial | null | undefined): boolean {
  if (!cfg) return false;
  if (!('aprobado_en' in cfg)) return true;
  return !!cfg.aprobado_en;
}

/// Invitadxs: su equipo / varios equipos (`equipos`), toda la liga o personas
/// sueltas. Quien crea, sus encargadxs y lxs homenajeadxs siempre lo están.
export function estaInvitadx(cfg: CfgSocial | null | undefined, username: string | null | undefined, categoria?: string | null): boolean {
  if (!cfg) return true;
  if (username && (cfg.creador === username || encargadxs(cfg).includes(username) || homenajeadxs(cfg).includes(username))) return true;
  const para = cfg.para;
  const tipo = String(para?.tipo ?? 'liga');
  const valores = lista(para?.valores);
  if (tipo === 'liga' || (!valores.length && tipo !== 'personas')) return true;
  if (tipo === 'personas') return !!username && valores.includes(username);
  return !!categoria && valores.includes(String(categoria));
}

export function vistaDe(cfg: CfgSocial | null | undefined, v: Visitante): Vista {
  if (!cfg) return v.esPivot ? 'organiza' : 'completa';
  const oculta = esSecretoPara(cfg, v.username);
  // En las listas nunca organiza, salvo quien crea algo que no es sorpresa
  // (por ejemplo, su propia despedida).
  const enLista = !!v.username && personasEnSecreto(cfg).has(v.username);
  const puede = !enLista || (!cfg.sorpresa && cfg.creador === v.username);
  if (puede && (v.esPivot || (!!v.username && (cfg.creador === v.username || encargadxs(cfg).includes(v.username))))) return 'organiza';
  if (!publicado(cfg)) return 'oculta';
  if (!estaInvitadx(cfg, v.username, v.categoria)) return 'oculta';
  return oculta ? 'neutral' : 'completa';
}

/// Pivots que pueden aprobar: ninguna persona homenajeada ni que no deba
/// enterarse. Si no queda nadie, el evento se publica sin aprobación.
export function aprobadores<T extends { username: string }>(pivots: T[], cfg: CfgSocial | null | undefined): T[] {
  const fuera = personasEnSecreto(cfg);
  return pivots.filter((p) => !fuera.has(p.username));
}

export function puedeAprobar(cfg: CfgSocial | null | undefined, pivotUsername: string | null | undefined): boolean {
  return !pivotUsername || !personasEnSecreto(cfg).has(pivotUsername);
}

function _y(nombres: string[]): string {
  if (nombres.length <= 1) return nombres.join('');
  return nombres.slice(0, -1).join(', ') + ' y ' + nombres[nombres.length - 1];
}

/// "Sorpresa para Ana y Beto" (nunca para la vista neutral).
export function etiquetaSorpresa(cfg: CfgSocial | null | undefined, vista: Vista, nombreDe: (u: string) => string): string | null {
  if (!cfg?.sorpresa || vista === 'neutral' || vista === 'oculta') return null;
  const h = homenajeadxs(cfg);
  return h.length ? `Sorpresa para ${_y(h.map(nombreDe))}` : 'Es sorpresa';
}

/// Nombre que ve cada quien: el neutro para quien no debe enterarse.
export function tituloPara(cfg: CfgSocial | null | undefined, vista: Vista, nombreDe: (u: string) => string): string {
  const neutro = String(cfg?.nombre_neutro ?? '').trim();
  if (vista === 'neutral') return neutro || 'Social o fiesta';
  const nombre = String(cfg?.nombre ?? '').trim();
  if (nombre) return nombre;
  return etiquetaSorpresa(cfg, vista, nombreDe) ?? (neutro || 'Social o fiesta');
}

/// Lxs homenajeadxs leen sus mensajes cuando terminó el evento o cuando
/// quien organiza los libera.
export function mensajesAbiertos(cfg: CfgSocial | null | undefined, eventoTermino: boolean): boolean {
  return eventoTermino || !!cfg?.mensajes_liberados_en;
}
