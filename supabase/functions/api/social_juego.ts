// ─── Regalo robado en vivo (Victor, 2026-11-20) ─────────────────────────────
// Quien dirige el juego (organiza o encargadx del área "amigo") lo activa el
// día del evento: regalos a la pila, sorteo del orden y turnos. Todxs lo ven en
// vivo en la app; sin notificaciones. Aquí solo la lógica pura (con tests);
// la acción `socialJuego` está en social.ts.

export interface ReglasJuego {
  /// Veces que se puede robar un mismo regalo (0 = sin límite).
  robosMax: number;
  /// Si quien acaba de ser robadx puede robar de vuelta ese mismo regalo.
  devolver: boolean;
  /// Si quien tuvo el primer turno puede cambiar su regalo al final.
  turnoFinal: boolean;
  /// Si se escribe qué era cada regalo al abrirlo.
  describir: boolean;
}

export const REGLAS_JUEGO_POR_DEFECTO: ReglasJuego = { robosMax: 3, devolver: false, turnoFinal: true, describir: true };

export function reglasJuego(x: any): ReglasJuego {
  const r = x && typeof x === 'object' ? x : {};
  const n = Number(r.robosMax);
  return {
    robosMax: Number.isFinite(n) && n >= 0 && n <= 10 ? Math.floor(n) : REGLAS_JUEGO_POR_DEFECTO.robosMax,
    devolver: r.devolver === true,
    turnoFinal: r.turnoFinal !== false,
    describir: r.describir !== false,
  };
}

/// Reglas escritas según las opciones (cuando quien organiza no escribió otras).
export function plantillaReglasRobado(r: ReglasJuego): string {
  return [
    '1. Cada persona trae un regalo envuelto y sin nombre. Solo juega quien trajo regalo.',
    '2. Todos los regalos se ponen juntos en una pila.',
    '3. Se sortea el orden de los turnos.',
    '4. En tu turno eliges: abres un regalo de la pila o robas uno que ya esté abierto.',
    r.devolver
      ? '5. Si te roban, vuelves a elegir: abres uno de la pila o robas otro (también puedes recuperar el que te quitaron).'
      : '5. Si te roban, vuelves a elegir: abres uno de la pila o robas otro, pero no el que te acaban de quitar.',
    r.robosMax > 0
      ? `6. Un mismo regalo se puede robar como máximo ${r.robosMax} ${r.robosMax === 1 ? 'vez' : 'veces'}. Al llegar a ese número se queda con esa persona.`
      : '6. Un regalo se puede robar todas las veces que se quiera.',
    r.turnoFinal
      ? '7. El juego termina cuando se abre el último regalo de la pila. Quien tuvo el primer turno puede, al final, cambiar su regalo por otro que todavía se pueda robar.'
      : '7. El juego termina cuando se abre el último regalo de la pila.',
    '8. Lo importante es pasarla bien juntxs: nada de enojos por un regalo.',
  ].join('\n');
}

export interface Participante { clave: string; nombre: string; dejo: boolean }
export interface Regalo { id: number; duenx: string; desc: string; robos: number }
export type Fase = 'pila' | 'orden' | 'juego' | 'final' | 'terminado';

export interface EstadoJuego {
  fase: Fase;
  participantes: Participante[];
  orden: string[];
  idx: number;
  /// Quien tiene que elegir ahora (su turno o porque le robaron).
  actual: string | null;
  /// Ya eligió: falta que quien dirige pase al siguiente turno.
  esperando: boolean;
  regalos: Regalo[];
  ultimoRobo: { regalo: number; victima: string } | null;
  historial: { texto: string; en: string }[];
  /// Estados anteriores para "Deshacer" (sin su propio historial de deshacer).
  anteriores?: Omit<EstadoJuego, 'anteriores'>[];
}

export function nuevoJuego(participantes: { clave: string; nombre: string }[]): EstadoJuego {
  return {
    fase: 'pila', participantes: participantes.map((p) => ({ ...p, dejo: false })), orden: [], idx: 0,
    actual: null, esperando: false, regalos: [], ultimoRobo: null, historial: [],
  };
}

export function bloqueado(r: ReglasJuego, g: Regalo): boolean {
  return r.robosMax > 0 && g.robos >= r.robosMax;
}

export function enPila(e: EstadoJuego): number {
  return Math.max(0, e.participantes.filter((p) => p.dejo).length - e.regalos.length);
}

function nombre(e: EstadoJuego, clave: string | null): string {
  return e.participantes.find((p) => p.clave === clave)?.nombre ?? 'Alguien';
}

function anotar(e: EstadoJuego, texto: string, ahora: string) {
  e.historial = [{ texto, en: ahora }, ...e.historial].slice(0, 60);
}

/// Mezcla con números aleatorios seguros.
export function mezclar<T>(xs: T[], azar: (n: number) => number = (n) => crypto.getRandomValues(new Uint32Array(1))[0] % n): T[] {
  const a = [...xs];
  for (let i = a.length - 1; i > 0; i--) {
    const j = azar(i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/// Aplica una acción de quien dirige. Devuelve el estado nuevo o un error.
export function aplicar(
  previo: EstadoJuego, accion: string, p: Record<string, any>, r: ReglasJuego, ahora: string, azar?: (n: number) => number,
): EstadoJuego | { error: string } {
  if (accion === 'deshacer') {
    const ant = previo.anteriores ?? [];
    if (!ant.length) return { error: 'No hay nada para deshacer.' };
    return { ...structuredClone(ant[0]), anteriores: ant.slice(1) };
  }
  const { anteriores, ...sinAnt } = previo;
  const e: EstadoJuego = structuredClone(sinAnt) as EstadoJuego;
  const guardar = (): EstadoJuego => ({ ...e, anteriores: [sinAnt, ...(anteriores ?? [])].slice(0, 30) });
  const tieneRegalo = (clave: string | null) => e.regalos.some((g) => g.duenx === clave);

  switch (accion) {
    case 'dejo': {
      if (e.fase !== 'pila') return { error: 'Los regalos ya están en la pila.' };
      const x = e.participantes.find((y) => y.clave === String(p.clave ?? ''));
      if (!x) return { error: 'Esa persona no está en la lista.' };
      x.dejo = p.valor !== false && p.valor !== 'false';
      return guardar();
    }
    case 'sortear': {
      if (e.fase !== 'pila' && e.fase !== 'orden') return { error: 'El orden ya se sorteó y el juego empezó.' };
      const juegan = e.participantes.filter((y) => y.dejo).map((y) => y.clave);
      if (juegan.length < 2) return { error: 'Tienen que dejar su regalo en la pila al menos 2 personas.' };
      e.orden = mezclar(juegan, azar);
      e.fase = 'orden';
      anotar(e, `Se sorteó el orden de ${juegan.length} personas.`, ahora);
      return guardar();
    }
    case 'empezar': {
      if (e.fase !== 'orden') return { error: 'Primero sortea el orden.' };
      e.fase = 'juego';
      e.idx = 0;
      e.actual = e.orden[0];
      e.esperando = false;
      anotar(e, `¡Empezó el juego! Primer turno: ${nombre(e, e.actual)}.`, ahora);
      return guardar();
    }
    case 'abrir': {
      if (e.fase !== 'juego') return { error: 'No es momento de abrir regalos.' };
      if (e.esperando || tieneRegalo(e.actual)) return { error: 'Esta persona ya tiene regalo: pasa al siguiente turno.' };
      if (enPila(e) <= 0) return { error: 'Ya no quedan regalos en la pila.' };
      const desc = r.describir ? String(p.desc ?? '').trim().slice(0, 80) : '';
      const id = e.regalos.reduce((m, g) => Math.max(m, g.id), 0) + 1;
      e.regalos.push({ id, duenx: e.actual!, desc, robos: 0 });
      e.esperando = true;
      e.ultimoRobo = null;
      anotar(e, `${nombre(e, e.actual)} abrió un regalo${desc ? `: ${desc}` : ''}.`, ahora);
      return guardar();
    }
    case 'robar': {
      if (e.fase !== 'juego') return { error: 'No es momento de robar.' };
      if (e.esperando || tieneRegalo(e.actual)) return { error: 'Esta persona ya tiene regalo: pasa al siguiente turno.' };
      const g = e.regalos.find((x) => x.id === Number(p.regalo));
      if (!g) return { error: 'Ese regalo no existe.' };
      if (g.duenx === e.actual) return { error: 'Ese regalo ya es suyo.' };
      if (bloqueado(r, g)) return { error: 'Ese regalo ya no se puede robar.' };
      if (!r.devolver && e.ultimoRobo && e.ultimoRobo.victima === e.actual && e.ultimoRobo.regalo === g.id) {
        return { error: 'No se puede robar de vuelta enseguida el regalo que te acaban de quitar.' };
      }
      const victima = g.duenx;
      g.duenx = e.actual!;
      g.robos++;
      e.ultimoRobo = { regalo: g.id, victima };
      anotar(e, `${nombre(e, e.actual)} le robó ${g.desc ? `“${g.desc}”` : 'su regalo'} a ${nombre(e, victima)}${bloqueado(r, g) ? ' (ya no se puede robar más)' : ''}.`, ahora);
      e.actual = victima;
      return guardar();
    }
    case 'siguiente': {
      if (e.fase !== 'juego') return { error: 'No hay turno para pasar.' };
      if (!e.esperando) return { error: `Primero ${nombre(e, e.actual)} tiene que abrir o robar un regalo.` };
      e.idx++;
      e.esperando = false;
      e.ultimoRobo = null;
      if (e.idx < e.orden.length) {
        e.actual = e.orden[e.idx];
        anotar(e, `Turno de ${nombre(e, e.actual)}.`, ahora);
      } else if (r.turnoFinal && e.orden.length > 1) {
        e.fase = 'final';
        e.actual = e.orden[0];
        anotar(e, `Turno final de ${nombre(e, e.actual)}: puede cambiar su regalo.`, ahora);
      } else {
        e.fase = 'terminado';
        e.actual = null;
        anotar(e, '¡Terminó el juego!', ahora);
      }
      return guardar();
    }
    case 'final': {
      if (e.fase !== 'final') return { error: 'No es el turno final.' };
      if (p.regalo !== undefined && p.regalo !== null && p.regalo !== '') {
        const g = e.regalos.find((x) => x.id === Number(p.regalo));
        const mio = e.regalos.find((x) => x.duenx === e.actual);
        if (!g || !mio || g.duenx === e.actual) return { error: 'Elige un regalo de otra persona.' };
        if (bloqueado(r, g)) return { error: 'Ese regalo ya no se puede robar.' };
        const otrx = g.duenx;
        g.duenx = e.actual!;
        mio.duenx = otrx;
        anotar(e, `${nombre(e, e.actual)} cambió su regalo con ${nombre(e, otrx)}.`, ahora);
      } else {
        anotar(e, `${nombre(e, e.actual)} se quedó con su regalo.`, ahora);
      }
      e.fase = 'terminado';
      e.actual = null;
      anotar(e, '¡Terminó el juego!', ahora);
      return guardar();
    }
  }
  return { error: 'Acción desconocida.' };
}

/// Lo que ve cada persona (con sus nombres y su lugar en el orden).
export function vistaJuego(e: EstadoJuego, yo: string | null, r: ReglasJuego) {
  const nom = (c: string | null) => nombre(e, c);
  return {
    fase: e.fase,
    participantes: e.participantes.map((p) => ({ ...p, yo: p.clave === yo })),
    orden: e.orden.map((c, i) => ({ clave: c, nombre: nom(c), yo: c === yo, paso: i < e.idx || e.fase === 'final' || e.fase === 'terminado' })),
    idx: e.idx,
    actual: e.actual ? { clave: e.actual, nombre: nom(e.actual), yo: e.actual === yo } : null,
    esperando: e.esperando,
    pila: enPila(e),
    regalos: e.regalos.map((g) => ({
      id: g.id, desc: g.desc, robos: g.robos, bloqueado: bloqueado(r, g), duenx: g.duenx, nombre: nom(g.duenx), mio: g.duenx === yo,
      // Quien acaba de ser robadx no puede robar de vuelta enseguida ese regalo.
      vedado: !r.devolver && !!e.ultimoRobo && e.ultimoRobo.regalo === g.id && e.ultimoRobo.victima === e.actual,
    })),
    robado: e.ultimoRobo ? { victima: nom(e.ultimoRobo.victima), yo: e.ultimoRobo.victima === yo } : null,
    miTurno: yo ? e.orden.indexOf(yo) + 1 : 0,
    historial: e.historial.slice(0, 30),
    deshacer: (e.anteriores ?? []).length > 0,
  };
}
