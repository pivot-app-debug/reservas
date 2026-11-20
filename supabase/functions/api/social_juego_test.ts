// Pruebas del regalo robado en vivo: `deno test supabase/functions/api/social_juego_test.ts`
function assertEquals(a: unknown, b: unknown) {
  if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`Esperaba ${JSON.stringify(b)} y fue ${JSON.stringify(a)}`);
}
import { aplicar, type EstadoJuego, nuevoJuego, plantillaReglasRobado, reglasJuego, vistaJuego } from './social_juego.ts';

const R = reglasJuego({});
const T = '2026-12-19T20:00:00Z';
function paso(e: EstadoJuego, a: string, p: Record<string, unknown> = {}, r = R): EstadoJuego {
  const x = aplicar(e, a, p, r, T, () => 0);
  if ('error' in x) throw new Error(x.error);
  return x;
}

Deno.test('Regalo robado: pila, sorteo, abrir, robar, sin devolver enseguida, turno final', () => {
  let e = nuevoJuego([{ clave: 'a', nombre: 'Ana' }, { clave: 'b', nombre: 'Beto' }, { clave: 'c', nombre: 'Cami' }]);
  for (const c of ['a', 'b', 'c']) e = paso(e, 'dejo', { clave: c });
  e = paso(e, 'sortear');
  assertEquals(e.orden.length, 3);
  e = paso(e, 'empezar');
  const [p1, p2] = e.orden;
  e = paso(e, 'abrir', { desc: 'Taza' });
  assertEquals('error' in aplicar(e, 'abrir', {}, R, T), true); // ya tiene regalo
  e = paso(e, 'siguiente');
  assertEquals(e.actual, p2);
  e = paso(e, 'robar', { regalo: 1 });
  assertEquals(e.actual, p1); // le toca a quien robaron
  // No puede robar de vuelta enseguida.
  assertEquals('error' in aplicar(e, 'robar', { regalo: 1 }, R, T), true);
  e = paso(e, 'abrir', { desc: 'Vela' });
  e = paso(e, 'siguiente');
  e = paso(e, 'abrir');
  e = paso(e, 'siguiente');
  assertEquals(e.fase, 'final');
  assertEquals(e.actual, e.orden[0]);
  e = paso(e, 'final', { regalo: 1 });
  assertEquals(e.fase, 'terminado');
  // Deshacer vuelve al turno final.
  e = paso(e, 'deshacer');
  assertEquals(e.fase, 'final');
  const v = vistaJuego(e, 'a', R);
  assertEquals(v.pila, 0);
});

Deno.test('Regalo robado: tope de robos y plantilla según opciones', () => {
  const r = reglasJuego({ robosMax: 1, devolver: true, turnoFinal: false });
  let e = nuevoJuego([{ clave: 'a', nombre: 'A' }, { clave: 'b', nombre: 'B' }, { clave: 'c', nombre: 'C' }]);
  for (const c of ['a', 'b', 'c']) e = paso(e, 'dejo', { clave: c }, r);
  e = paso(paso(e, 'sortear', {}, r), 'empezar', {}, r);
  e = paso(paso(e, 'abrir', {}, r), 'siguiente', {}, r);
  e = paso(e, 'robar', { regalo: 1 }, r);
  // Con 1 robo queda bloqueado.
  assertEquals('error' in aplicar(e, 'robar', { regalo: 1 }, r, T), true);
  assertEquals(plantillaReglasRobado(r).includes('como máximo 1 vez'), true);
  assertEquals(plantillaReglasRobado(r).includes('Quien tuvo el primer turno'), false);
});
