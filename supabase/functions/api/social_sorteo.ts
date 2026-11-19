// Sorteo del amigo secreto (evento Social, NAVIQUINDE.md). Función pura,
// sin base de datos, para poder probarla con `deno test`.
//
// Arma UN ciclo A→B→C→…→A con todxs, así sirve para cualquier cantidad
// (par o impar) y nadie queda en un "par cerrado" aparte. Reglas:
//  - nadie se toca a sí mismx;
//  - personas del mismo `grupo` (una persona y sus +1) nunca se tocan entre sí;
//  - se evita repetir quién le regaló a quién el año anterior (`previas`);
//    si con esa regla no hay forma, se sortea sin ella y se avisa.
// Si las reglas fijas lo hacen imposible, devuelve un error claro.

export type ParticipanteSorteo = { clave: string; grupo: string };
export type ParejaSorteo = { da: string; recibe: string };
export type ResultadoSorteo =
  | { ok: true; pares: ParejaSorteo[]; repiteAnterior: boolean }
  | { ok: false; error: string };

const LIMITE_PASOS = 400000;

function _mezclar<T>(xs: T[], rng: () => number): T[] {
  const a = [...xs];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function _ciclo(ps: ParticipanteSorteo[], permitido: (a: ParticipanteSorteo, b: ParticipanteSorteo) => boolean, rng: () => number): ParticipanteSorteo[] | null {
  const orden = _mezclar(ps, rng);
  const n = orden.length;
  const usado = new Array(n).fill(false);
  const camino: number[] = [0];
  usado[0] = true;
  let pasos = 0;
  const buscar = (): boolean => {
    if (++pasos > LIMITE_PASOS) return false;
    const ultimo = orden[camino[camino.length - 1]];
    if (camino.length === n) return permitido(ultimo, orden[0]);
    for (const i of _mezclar([...Array(n).keys()], rng)) {
      if (usado[i] || !permitido(ultimo, orden[i])) continue;
      usado[i] = true;
      camino.push(i);
      if (buscar()) return true;
      camino.pop();
      usado[i] = false;
    }
    return false;
  };
  return buscar() ? camino.map((i) => orden[i]) : null;
}

// Respaldo determinista: grupos de mayor a menor, repartidos en las
// posiciones pares y luego impares (nunca quedan dos del mismo grupo juntos
// cuando ningún grupo pasa de la mitad). Se valida antes de usarlo.
function _intercalado(ps: ParticipanteSorteo[], permitido: (a: ParticipanteSorteo, b: ParticipanteSorteo) => boolean, rng: () => number): ParticipanteSorteo[] | null {
  const grupos = new Map<string, ParticipanteSorteo[]>();
  for (const p of _mezclar(ps, rng)) grupos.set(p.grupo, [...(grupos.get(p.grupo) ?? []), p]);
  const lista = [...grupos.values()].sort((a, b) => b.length - a.length).flat();
  const n = lista.length;
  const out = new Array<ParticipanteSorteo>(n);
  let k = 0;
  for (let i = 0; i < n; i += 2) out[i] = lista[k++];
  for (let i = 1; i < n; i += 2) out[i] = lista[k++];
  return out.every((p, i) => permitido(p, out[(i + 1) % n])) ? out : null;
}

export function sortearAmigoSecreto(ps: ParticipanteSorteo[], previas: ParejaSorteo[] = [], rng: () => number = Math.random): ResultadoSorteo {
  const claves = new Set(ps.map((p) => p.clave));
  if (claves.size !== ps.length) return { ok: false, error: 'Hay personas repetidas en el sorteo.' };
  if (ps.length < 2) return { ok: false, error: 'Se necesitan al menos 2 personas inscritas para sortear.' };
  // En un ciclo, dos personas del mismo grupo no pueden ir seguidas: si un
  // grupo tiene más de la mitad de lxs participantes, no hay forma.
  const porGrupo = new Map<string, number>();
  for (const p of ps) porGrupo.set(p.grupo, (porGrupo.get(p.grupo) ?? 0) + 1);
  const mayor = Math.max(...porGrupo.values());
  if (mayor * 2 > ps.length) {
    return {
      ok: false,
      error: ps.length === 2
        ? 'Solo están inscritas una persona y su invitadx: no pueden regalarse entre sí. Se necesita al menos una persona más.'
        : 'No se puede sortear: una persona y sus invitadxs son más de la mitad del grupo y no pueden tocarse entre sí. Se necesitan más personas inscritas.',
    };
  }
  const prev = new Set(previas.map((x) => `${x.da}\u0000${x.recibe}`));
  const base = (a: ParticipanteSorteo, b: ParticipanteSorteo) => a.clave !== b.clave && a.grupo !== b.grupo;
  const sinRepetir = (a: ParticipanteSorteo, b: ParticipanteSorteo) => base(a, b) && !prev.has(`${a.clave}\u0000${b.clave}`);
  let repiteAnterior = false;
  let ciclo = prev.size ? _ciclo(ps, sinRepetir, rng) : null;
  if (!ciclo) {
    ciclo = _ciclo(ps, base, rng) ?? _intercalado(ps, base, rng);
    repiteAnterior = prev.size > 0 && !!ciclo && ciclo.some((p, i) => prev.has(`${p.clave}\u0000${ciclo![(i + 1) % ciclo!.length].clave}`));
  }
  if (!ciclo) return { ok: false, error: 'No se encontró una forma de sortear con estas reglas. Revisa lxs inscritxs e intenta de nuevo.' };
  const pares = ciclo.map((p, i) => ({ da: p.clave, recibe: ciclo![(i + 1) % ciclo!.length].clave }));
  return { ok: true, pares, repiteAnterior };
}
