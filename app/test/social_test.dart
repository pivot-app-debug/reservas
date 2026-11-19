import 'package:coach/eventos/social/social_repo.dart';
import 'package:coach/eventos/tipos_evento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('El tipo guardado "Evento" se muestra como "Otro"', () {
    expect(etiquetaTipoEvento('Evento'), 'Otro');
    expect(etiquetaTipoEvento('Social'), 'Social');
    expect(etiquetaOpcionTipo('Otro'), 'Personalizado');
    expect(kTiposEventoBase, containsAll(['Reunión de equipo', 'Social', 'Evento']));
  });

  test('Pistas y wishlist van y vuelven sin perder datos', () {
    final p = PerfilSocial(
      gustos: ['Café'],
      noRegalar: ['Tazas'],
      tallas: {'camiseta': 'M'},
      wishlist: [ItemDeseo(texto: 'Libro', link: 'https://x.y', favorito: true)],
    );
    final q = PerfilSocial.desde(p.aJson());
    expect(q.gustos, ['Café']);
    expect(q.noRegalar, ['Tazas']);
    expect(q.tallas['camiseta'], 'M');
    expect(q.wishlist.single.favorito, isTrue);
    expect(q.vacio, isFalse);
  });

  test('Avance de la comida', () {
    final c = CategoriaComida({'id': '1', 'nombre': 'Postres', 'unidad': 'porciones', 'porPersona': 1, 'meta': 10, 'aportado': 4, 'cerrada': false});
    expect(c.avance, closeTo(0.4, 0.001));
    expect(CategoriaComida({'meta': 0, 'aportado': 3}).avance, 0);
  });
}
