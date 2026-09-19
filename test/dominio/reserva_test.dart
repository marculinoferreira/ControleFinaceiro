import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/reserva.dart';

void main() {
  group('mesesDeCobertura', () {
    test('sem valor guardado devolve nulo', () {
      expect(
        mesesDeCobertura(valorGuardado: null, gastoDoMes: 1500),
        isNull,
      );
    });

    test('sem gasto no mes devolve nulo (nao ha o que dividir)', () {
      expect(
        mesesDeCobertura(valorGuardado: 6000, gastoDoMes: 0),
        isNull,
      );
    });

    test('caso normal', () {
      expect(
        mesesDeCobertura(valorGuardado: 6000, gastoDoMes: 1500),
        4,
      );
    });

    test('valor guardado zero mas presente da zero meses, nao nulo', () {
      expect(
        mesesDeCobertura(valorGuardado: 0, gastoDoMes: 1500),
        0,
      );
    });
  });
}
