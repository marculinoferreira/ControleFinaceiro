import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/mes_do_gasto.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';

void main() {
  group('calcularMesDoGasto', () {
    test('pix/debito sempre cai no mes de hoje, mesmo com outro mes selecionado', () {
      final resultado = calcularMesDoGasto(
        hoje: DateTime(2026, 9, 20),
        pixDebito: true,
        diaVencimento: 5,
        mesSelecionado: const MesRef(2026, 3),
      );

      expect(resultado, const MesRef(2026, 9));
    });

    test('credito sem vencimento cadastrado usa o mes selecionado na tela', () {
      final resultado = calcularMesDoGasto(
        hoje: DateTime(2026, 9, 20),
        pixDebito: false,
        diaVencimento: null,
        mesSelecionado: const MesRef(2026, 11),
      );

      expect(resultado, const MesRef(2026, 11));
    });

    test('credito antes do fechamento cai no mes de hoje', () {
      final resultado = calcularMesDoGasto(
        hoje: DateTime(2026, 9, 4),
        pixDebito: false,
        diaVencimento: 5,
        mesSelecionado: const MesRef(2026, 1),
      );

      expect(resultado, const MesRef(2026, 9));
    });

    test('exatamente no dia do fechamento ainda conta no mes de hoje', () {
      final resultado = calcularMesDoGasto(
        hoje: DateTime(2026, 9, 5),
        pixDebito: false,
        diaVencimento: 5,
        mesSelecionado: const MesRef(2026, 1),
      );

      expect(resultado, const MesRef(2026, 9));
    });

    test('credito depois do fechamento cai na fatura do mes que vem', () {
      final resultado = calcularMesDoGasto(
        hoje: DateTime(2026, 9, 6),
        pixDebito: false,
        diaVencimento: 5,
        mesSelecionado: const MesRef(2026, 1),
      );

      expect(resultado, const MesRef(2026, 10));
    });

    test('depois do fechamento em dezembro vira o ano', () {
      final resultado = calcularMesDoGasto(
        hoje: DateTime(2026, 12, 20),
        pixDebito: false,
        diaVencimento: 5,
        mesSelecionado: const MesRef(2026, 1),
      );

      expect(resultado, const MesRef(2027, 1));
    });
  });
}
