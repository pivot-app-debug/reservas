import 'package:flutter_test/flutter_test.dart';
import 'package:coach/core/api.dart';
import 'package:coach/core/periodos_sin_cobro.dart';
import 'package:coach/reservas/reservas_repo.dart';
import 'package:coach/sesion/sesion.dart';

void main() {
  final hoy = DateTime.now();
  final a = hoy.year + 1;
  final periodos = PeriodoSinCobro.lista([
    {
      'id': 'm',
      'tipo': 'mes',
      'meses': ['$a-12'],
      'equipos': [],
    },
    {
      'id': 'p',
      'tipo': 'periodo',
      'desde': '$a-11-19',
      'hasta': '$a-11-25',
      'clasesPct': 50,
      'cuota': 'proporcional',
      'equipos': ['Mirlxs'],
    },
  ]);

  test('lee meses y periodos', () {
    expect(periodos.length, 2);
    expect(periodos.first.porMes, isTrue);
    expect(periodos.last.clasesPct, 50);
    expect(periodos.first.aviso, 'Diciembre $a no se cobra.');
  });

  test('porcentaje de una clase según la fecha y el equipo', () {
    expect(PeriodoSinCobro.pctClase(periodos, DateTime(a, 12, 3), equipo: 'Quindes'), 0);
    expect(PeriodoSinCobro.pctClase(periodos, DateTime(a, 11, 20), equipo: 'Mirlxs'), 50);
    expect(PeriodoSinCobro.pctClase(periodos, DateTime(a, 11, 20), equipo: 'Quindes'), 100);
    expect(PeriodoSinCobro.pctClase(periodos, DateTime(a, 11, 26), equipo: 'Mirlxs'), 100);
    expect(PeriodoSinCobro.mesSinCobro(periodos, DateTime(a, 12), equipo: 'Quindes'), isTrue);
  });

  test('total por clase: las que no se cobran no gastan cupón y las demás valen su %', () {
    final p = Precios(10, 40, periodos: periodos.where((x) => x.porMes || x.equipos.contains('Mirlxs')).toList());
    final t = ReservasRepo(
      Sesion(Api()),
    ).total(tipo: TipoReserva.clase, cantidad: 3, p: p, creditos: 0, cupon: true, fechasClases: [DateTime(a, 12, 2), DateTime(a, 11, 20), DateTime(a, 11, 28)]);
    expect(t.sinCobro, 1);
    expect(t.cupon, 1);
    expect(t.cobradas, 1);
    expect(t.monto, 10);
  });
}
