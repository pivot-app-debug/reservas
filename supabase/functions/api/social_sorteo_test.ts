// Pruebas del sorteo del amigo secreto: `deno test supabase/functions/api/social_sorteo_test.ts`
import { type ParejaSorteo, type ParticipanteSorteo, sortearAmigoSecreto } from './social_sorteo.ts';

function afirmar(c: unknown, msg: string): asserts c {
  if (!c) throw new Error(msg);
}

// Comprueba que el resultado es UN ciclo con todxs y que respeta las reglas fijas.
function cicloValido(ps: ParticipanteSorteo[], pares: ParejaSorteo[]) {
  const grupo = new Map(ps.map((p) => [p.clave, p.grupo]));
  afirmar(pares.length === ps.length, 'cada persona da un regalo');
  afirmar(new Set(pares.map((x) => x.da)).size === ps.length, 'nadie da dos veces');
  afirmar(new Set(pares.map((x) => x.recibe)).size === ps.length, 'nadie recibe dos veces');
  for (const x of pares) {
    afirmar(x.da !== x.recibe, 'nadie se toca a sí mismx');
    afirmar(grupo.get(x.da) !== grupo.get(x.recibe), 'persona y su +1 no se tocan');
  }
  const sig = new Map(pares.map((x) => [x.da, x.recibe]));
  let actual = ps[0].clave, n = 0;
  do {
    actual = sig.get(actual)!;
    n++;
  } while (actual !== ps[0].clave && n <= ps.length);
  afirmar(n === ps.length, 'es un solo ciclo');
}

const p = (clave: string, grupo = clave): ParticipanteSorteo => ({ clave, grupo });

Deno.test('3 personas', () => {
  const ps = [p('ana'), p('beto'), p('caro')];
  for (let i = 0; i < 50; i++) {
    const r = sortearAmigoSecreto(ps);
    afirmar(r.ok, 'debe sortear');
    cicloValido(ps, r.pares);
  }
});

Deno.test('3 personas + 1 invitadx', () => {
  const ps = [p('ana'), p('inv:1', 'ana'), p('beto'), p('caro')];
  for (let i = 0; i < 50; i++) {
    const r = sortearAmigoSecreto(ps);
    afirmar(r.ok, 'debe sortear');
    cicloValido(ps, r.pares);
  }
});

Deno.test('cantidad impar grande con varios +1', () => {
  const ps = [...Array(21).keys()].map((i) => p(`u${i}`));
  ps.push(p('inv:a', 'u0'), p('inv:b', 'u0'), p('inv:c', 'u5'), p('inv:d', 'u7'));
  const r = sortearAmigoSecreto(ps);
  afirmar(r.ok, 'debe sortear');
  cicloValido(ps, r.pares);
});

Deno.test('solo una persona y su +1: imposible', () => {
  const r = sortearAmigoSecreto([p('ana'), p('inv:1', 'ana')]);
  afirmar(!r.ok && r.error.includes('invitadx'), 'error claro');
});

Deno.test('un grupo con más de la mitad: imposible', () => {
  const r = sortearAmigoSecreto([p('ana'), p('inv:1', 'ana'), p('inv:2', 'ana'), p('beto')]);
  afirmar(!r.ok, 'no se puede');
});

Deno.test('menos de 2 personas: imposible', () => {
  afirmar(!sortearAmigoSecreto([p('ana')]).ok, 'una sola persona');
  afirmar(!sortearAmigoSecreto([]).ok, 'nadie');
});

Deno.test('grupo justo en la mitad sí se puede', () => {
  const ps = [p('ana'), p('inv:1', 'ana'), p('inv:2', 'ana'), p('beto'), p('caro'), p('dani')];
  for (let i = 0; i < 30; i++) {
    const r = sortearAmigoSecreto(ps);
    afirmar(r.ok, 'debe sortear');
    cicloValido(ps, r.pares);
  }
});

Deno.test('evita la pareja del año anterior', () => {
  const ps = [p('ana'), p('beto'), p('caro'), p('dani'), p('eli')];
  const previas = [{ da: 'ana', recibe: 'beto' }, { da: 'beto', recibe: 'caro' }, { da: 'caro', recibe: 'ana' }];
  for (let i = 0; i < 50; i++) {
    const r = sortearAmigoSecreto(ps, previas);
    afirmar(r.ok && !r.repiteAnterior, 'debe sortear sin repetir');
    cicloValido(ps, r.pares);
    for (const x of r.pares) afirmar(!previas.some((v) => v.da === x.da && v.recibe === x.recibe), 'no repite');
  }
});

Deno.test('si no hay forma sin repetir, sortea igual y avisa', () => {
  const ps = [p('ana'), p('beto')];
  const r = sortearAmigoSecreto(ps, [{ da: 'ana', recibe: 'beto' }]);
  afirmar(r.ok && r.repiteAnterior, 'sortea y avisa');
  cicloValido(ps, r.pares);
});

Deno.test('parejas que no se pueden tocar nunca se tocan', () => {
  const ps = ['a', 'b', 'c', 'd', 'e'].map((c) => ({ clave: c, grupo: c }));
  for (let i = 0; i < 50; i++) {
    const r = sortearAmigoSecreto(ps, [], Math.random, [['a', 'b']]);
    if (!r.ok) throw new Error('debía sortear');
    for (const x of r.pares) if ((x.da === 'a' && x.recibe === 'b') || (x.da === 'b' && x.recibe === 'a')) throw new Error('a y b se tocaron');
  }
});

Deno.test('sin forma de sortear con las parejas prohibidas avisa', () => {
  const ps = ['a', 'b', 'c'].map((c) => ({ clave: c, grupo: c }));
  const r = sortearAmigoSecreto(ps, [], Math.random, [['a', 'b'], ['b', 'c']]);
  if (r.ok) throw new Error('no debía poder');
});
