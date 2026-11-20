// deno test supabase/functions/api/social_reglas_test.ts
import { aprobadores, type CfgSocial, estaInvitadx, etiquetaSorpresa, mensajesAbiertos, publicado, puedeAprobar, tituloPara, vistaDe } from './social_reglas.ts';

function igual(a: unknown, b: unknown, msg = '') {
  if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`${msg} esperado ${JSON.stringify(b)}, vino ${JSON.stringify(a)}`);
}

const base: CfgSocial = {
  creador: 'ana', encargados: ['beto'], sorpresa: true, homenajeados: ['caro'], no_enterarse: ['dani'],
  para: { tipo: 'liga', valores: [] }, aprobado_en: '2026-11-20T10:00:00Z', nombre: 'Cumple de Caro', nombre_neutro: 'Reunión del equipo',
};
const nombre = (u: string) => u.toUpperCase();

Deno.test('quien crea y encargadxs organizan; homenajeadxs y no deben enterarse ven la vista neutral', () => {
  igual(vistaDe(base, { username: 'ana', esPivot: false }), 'organiza');
  igual(vistaDe(base, { username: 'beto', esPivot: false }), 'organiza');
  igual(vistaDe(base, { username: 'caro', esPivot: false }), 'neutral');
  igual(vistaDe(base, { username: 'dani', esPivot: false }), 'neutral');
  igual(vistaDe(base, { username: 'eva', esPivot: false }), 'completa');
});

Deno.test('un Pivot homenajeadx no organiza ni ve la sorpresa', () => {
  igual(vistaDe(base, { username: 'caro', esPivot: true }), 'neutral');
  igual(vistaDe(base, { username: 'eva', esPivot: true }), 'organiza');
});

Deno.test('sin aprobar: solo quienes organizan lo ven', () => {
  const c = { ...base, aprobado_en: null };
  igual(vistaDe(c, { username: 'eva', esPivot: false }), 'oculta');
  igual(vistaDe(c, { username: 'caro', esPivot: true }), 'oculta');
  igual(vistaDe(c, { username: 'ana', esPivot: false }), 'organiza');
  igual(vistaDe(c, { username: 'eva', esPivot: true }), 'organiza');
});

Deno.test('fila de la primera versión (sin columna aprobado_en): publicada', () => {
  igual(publicado({ creador: null }), true);
  igual(publicado({ aprobado_en: null }), false);
});

Deno.test('a quién invita', () => {
  const eq = { ...base, para: { tipo: 'equipos', valores: ['Quindes'] } };
  igual(estaInvitadx(eq, 'eva', 'Quindes'), true);
  igual(estaInvitadx(eq, 'eva', 'Mirlxs'), false);
  igual(estaInvitadx(eq, 'caro', 'Mirlxs'), true, 'homenajeadx siempre');
  const per = { ...base, para: { tipo: 'personas', valores: ['eva'] } };
  igual(estaInvitadx(per, 'eva'), true);
  igual(estaInvitadx(per, 'fer'), false);
  igual(vistaDe(per, { username: 'fer', esPivot: false }), 'oculta');
});

Deno.test('quién aprueba: nunca homenajeadxs ni no deben enterarse; si no queda nadie, sin aprobación', () => {
  const pivots = [{ username: 'caro' }, { username: 'dani' }, { username: 'eva' }];
  igual(aprobadores(pivots, base).map((p) => p.username), ['eva']);
  igual(aprobadores([{ username: 'caro' }, { username: 'dani' }], base).length, 0);
  igual(puedeAprobar(base, 'caro'), false);
  igual(puedeAprobar({ ...base, sorpresa: false }, 'caro'), false, 'homenajeadx sin sorpresa tampoco aprueba');
  igual(puedeAprobar(base, 'eva'), true);
});

Deno.test('títulos: neutro para quien no debe enterarse, "Sorpresa para" para el resto', () => {
  igual(tituloPara(base, 'neutral', nombre), 'Reunión del equipo');
  igual(tituloPara(base, 'completa', nombre), 'Cumple de Caro');
  igual(tituloPara({ ...base, nombre: '' }, 'completa', nombre), 'Sorpresa para CARO');
  igual(etiquetaSorpresa(base, 'neutral', nombre), null);
  igual(etiquetaSorpresa({ ...base, homenajeados: ['caro', 'gabi', 'hugo'] }, 'organiza', nombre), 'Sorpresa para CARO, GABI y HUGO');
  igual(etiquetaSorpresa({ ...base, sorpresa: false }, 'completa', nombre), null);
});

Deno.test('sin sorpresa, quien crea su propia despedida organiza', () => {
  const c = { ...base, sorpresa: false, homenajeados: ['ana'] };
  igual(vistaDe(c, { username: 'ana', esPivot: false }), 'organiza');
  igual(vistaDe(c, { username: 'dani', esPivot: false }), 'completa');
});

Deno.test('mensajes: después del evento o al liberarlos', () => {
  igual(mensajesAbiertos(base, false), false);
  igual(mensajesAbiertos(base, true), true);
  igual(mensajesAbiertos({ ...base, mensajes_liberados_en: '2026-12-01' }, false), true);
});

import { cambiosPara, diferencias, listaEs, piezaVisible } from './social_reglas.ts';

Deno.test('sorpresa por pieza: por defecto la ven; homenaje y premios nunca', () => {
  const c = { ...base, piezas: { ocultas: ['playlist', 'homenaje'] } };
  igual(piezaVisible(c, 'comida', 'neutral'), true);
  igual(piezaVisible(c, 'playlist', 'neutral'), false);
  igual(piezaVisible(c, 'playlist', 'completa'), true);
  igual(piezaVisible({ piezas: {} }, 'homenaje', 'neutral'), false);
  igual(piezaVisible({ piezas: {} }, 'premios', 'neutral'), false);
});

Deno.test('avisos de cambios: la vista neutral solo se entera de lo que ve', () => {
  const antes = { nombre: 'Cumple de Caro', nombreNeutro: 'Reunión', hora: '19:00', playlist: { link: 'a' }, homenaje: { regalo: false }, comida: [1] };
  const cfg = { piezas: { ocultas: ['playlist'] } };
  const soloOcultos = diferencias(antes, { ...antes, playlist: { link: 'b' }, homenaje: { regalo: true }, nombre: 'Cumple 30' });
  igual(cambiosPara(soloOcultos, cfg, 'neutral'), [], 'nada que vea: no le llega');
  igual(cambiosPara(soloOcultos, cfg, 'completa'), ['el nombre', 'la playlist', 'el homenaje']);
  const varios = diferencias(antes, { ...antes, hora: '20:00', comida: [2], nombreNeutro: 'Junta' });
  igual(cambiosPara(varios, cfg, 'neutral'), ['el nombre', 'la hora', 'la comida y bebida']);
  igual(cambiosPara(varios, cfg, 'completa'), ['la hora', 'la comida y bebida']);
  igual(listaEs(['a', 'b', 'c']), 'a, b y c');
});
