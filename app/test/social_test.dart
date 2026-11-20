import 'package:coach/eventos/social/social_plantillas.dart';
import 'package:coach/eventos/social/social_repo.dart';
import 'package:coach/eventos/tipos_evento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('El tipo guardado "Evento" se muestra como "Otro"', () {
    expect(etiquetaTipoEvento('Evento'), 'Otro');
    expect(etiquetaTipoEvento('Social'), 'Social o fiesta');
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

  test('La Naviquinde: Festividad de temporada "Navidad" trae amigo secreto, regalo robado, comida y +1', () {
    final s = sugerenciasDe('festividad', 'Navidad');
    expect(s.piezas, containsAll([Pieza.amigoSecreto, Pieza.regaloRobado, Pieza.comida, Pieza.invitados]));
    expect(s.comida, isNotEmpty);
    expect(sugerenciasDe('festividad', 'Día de muertos').comida.map((c) => c.nombre), containsAll(['Colada morada', 'Guaguas de pan']));
    expect(sugerenciasDe('festividad', 'Carnaval').piezas, contains(Pieza.comida));
    expect(sugerenciasDe('cumpleanos', null).piezas, contains(Pieza.homenaje));
    expect(sugerenciasDe('personalizado', null).piezas, isEmpty);
  });

  test('Vista neutral: sin sorpresa, homenaje ni premios', () {
    final e = EstadoSocial({
      'vista': 'neutral',
      'organiza': false,
      'social': {'titulo': 'Reunión del equipo', 'sorpresa': null, 'premios': null, 'estado': 'publicado', 'comida': true},
    });
    expect(e.titulo, 'Reunión del equipo');
    expect(e.sorpresa, isNull);
    expect(e.homenaje, isNull);
    expect(e.premios, isNull);
    expect(e.organiza, isFalse);
    expect(e.modulo('comida'), isTrue);
  });

  test('Vista de quien organiza: sorpresa, estado y piezas', () {
    final e = EstadoSocial({
      'vista': 'organiza',
      'organiza': true,
      'social': {
        'titulo': 'Cumple de Caro',
        'sorpresa': 'Sorpresa para Caro',
        'estado': 'por_aprobar',
        'playlist': {'link': 'https://open.spotify.com/x', 'nota': ''},
        'premios': [
          {'premio': 'Mejor disfraz', 'para': ''},
        ],
      },
      'homenaje': {
        'personas': [
          {'username': 'caro', 'nombre': 'Caro'},
        ],
        'mensajes': true,
      },
      'editable': {'sorpresa': true},
    });
    expect(e.sorpresa, 'Sorpresa para Caro');
    expect(e.estadoAprobacion, 'por_aprobar');
    expect(e.playlist?['link'], startsWith('https://'));
    expect(e.premios!.single['premio'], 'Mejor disfraz');
    expect(e.homenaje, isNotNull);
    expect(e.editable?['sorpresa'], isTrue);
  });
}
