import { _filtrarPorPermisos } from './social.ts';

Deno.test('encargadx de comida solo cambia la comida; las piezas de otras áreas quedan como estaban', () => {
  const previa = { piezas: { playlist: { link: 'a', nota: 'vieja' }, traer: { items: [] } } };
  const d = {
    nombre: 'Otro nombre', fecha: '2026-12-20', categorias: [{ nombre: 'Hielo' }],
    modulos: { comida: true, amigoSecreto: false },
    piezas: { playlist: { link: 'b', nota: 'nueva' }, traer: { items: [{ texto: 'Vasos' }] } },
  };
  const r = _filtrarPorPermisos(d, ['comida'], previa);
  if (r.nombre !== undefined || r.fecha !== undefined) throw new Error('no debía pasar nombre ni fecha');
  if (!r.categorias || r.modulos.comida !== true || 'amigoSecreto' in r.modulos) throw new Error('módulos mal filtrados');
  if (r.piezas.playlist.nota !== 'vieja') throw new Error('la playlist no se debía tocar');
  if (r.piezas.traer.items.length !== 1) throw new Error('qué traer sí se cambia');
});

Deno.test('encargadx de extras cambia la playlist', () => {
  const r = _filtrarPorPermisos({ piezas: { playlist: { link: 'b', nota: 'nueva' } } }, ['extras'], { piezas: { playlist: { link: 'a', nota: 'vieja' } } });
  if (r.piezas.playlist.nota !== 'nueva') throw new Error('debía cambiar');
});
