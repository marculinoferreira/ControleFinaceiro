import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/totais.dart';

Ganho ganho(String membroId, double valor, {String mesRef = '2026-08'}) =>
    Ganho(
      id: 'g${valor.toInt()}',
      mesRef: mesRef,
      membroId: membroId,
      descricao: 'Renda',
      valor: valor,
      criadoEm: DateTime.utc(2026, 8, 1),
    );

Gasto gasto(
  String membroId,
  String poteId,
  double valor, {
  String mesRef = '2026-08',
  bool parcelado = false,
}) =>
    Gasto(
      id: 'x${valor.toInt()}',
      mesRef: mesRef,
      membroId: membroId,
      poteId: poteId,
      descricao: 'Compra',
      valor: valor,
      criadoEm: DateTime.utc(2026, 8, 1),
      parcelado: parcelado,
      compraId: parcelado ? 'c1' : null,
      parcela: parcelado ? 1 : null,
      totalParcelas: parcelado ? 5 : null,
    );

void main() {
  final ganhos = [
    ganho('marcos', 4000),
    ganho('marcos', 500),
    ganho('silvia', 3000),
  ];

  final gastos = [
    gasto('marcos', 'p1', 1200),
    gasto('marcos', 'p2', 300),
    gasto('silvia', 'p1', 800),
  ];

  group('calcularTotais', () {
    test('sem membroId soma o casal', () {
      final t = calcularTotais(ganhos: ganhos, gastos: gastos);
      expect(t.ganhos, 7500);
      expect(t.gastos, 2300);
      expect(t.saldo, 5200);
    });

    test('com membroId filtra a pessoa', () {
      final t = calcularTotais(
          ganhos: ganhos, gastos: gastos, membroId: 'marcos');
      expect(t.ganhos, 4500);
      expect(t.gastos, 1500);
      expect(t.saldo, 3000);
    });

    test('membro sem lancamento devolve zeros, nao erro', () {
      final t = calcularTotais(
          ganhos: ganhos, gastos: gastos, membroId: 'joao');
      expect(t.ganhos, 0);
      expect(t.gastos, 0);
      expect(t.saldo, 0);
    });

    test('listas vazias devolvem zeros', () {
      final t = calcularTotais(ganhos: const [], gastos: const []);
      expect(t.saldo, 0);
    });

    test('saldo negativo quando gasta mais do que ganha', () {
      final t = calcularTotais(
        ganhos: [ganho('marcos', 1000)],
        gastos: [gasto('marcos', 'p1', 1600)],
      );
      expect(t.saldo, -600);
    });
  });

  group('somarGanhosPorMembro', () {
    test('soma as entradas de cada pessoa', () {
      expect(somarGanhosPorMembro(ganhos),
          {'marcos': 4500.0, 'silvia': 3000.0});
    });

    test('lista vazia devolve mapa vazio', () {
      expect(somarGanhosPorMembro(const []), isEmpty);
    });
  });

  group('somarGastosPorPote', () {
    test('agrupa por pote somando o casal', () {
      expect(somarGastosPorPote(gastos), {'p1': 2000.0, 'p2': 300.0});
    });

    test('filtra por membro quando pedido', () {
      expect(somarGastosPorPote(gastos, membroId: 'marcos'),
          {'p1': 1200.0, 'p2': 300.0});
    });
  });

  group('somarGastosPorMembro', () {
    test('agrupa por pessoa', () {
      expect(somarGastosPorMembro(gastos),
          {'marcos': 1500.0, 'silvia': 800.0});
    });
  });

  group('comprometidoNoMes', () {
    final futuros = [
      gasto('marcos', 'p2', 100, mesRef: '2026-09', parcelado: true),
      gasto('silvia', 'p2', 250, mesRef: '2026-09', parcelado: true),
      gasto('marcos', 'p2', 100, mesRef: '2026-10', parcelado: true),
      gasto('marcos', 'p1', 900, mesRef: '2026-09'), // nao parcelado
    ];

    test('soma so as parcelas do mes pedido', () {
      expect(comprometidoNoMes(futuros, '2026-09'), 350);
    });

    test('ignora gastos nao parcelados', () {
      expect(comprometidoNoMes(futuros, '2026-09'), isNot(1250));
    });

    test('mes sem parcelas devolve zero', () {
      expect(comprometidoNoMes(futuros, '2027-01'), 0);
    });

    test('com membroId, soma so as parcelas daquela pessoa', () {
      expect(comprometidoNoMes(futuros, '2026-09', membroId: 'silvia'), 250);
    });

    test('membroId nulo soma o casal inteiro', () {
      expect(comprometidoNoMes(futuros, '2026-09', membroId: null), 350);
    });
  });
}
