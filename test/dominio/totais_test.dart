import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/totais.dart';
import 'package:controle_financeiro/dominio/cascata.dart' show toleranciaCentavo;

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
  String? cartaoId,
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
      cartaoId: cartaoId,
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

  group('somarGastosPorCartao', () {
    test('agrupa por cartao somando o casal', () {
      final gastosComCartao = [
        gasto('marcos', 'p1', 1200, cartaoId: 'nubank'),
        gasto('marcos', 'p2', 300, cartaoId: 'nubank'),
        gasto('silvia', 'p1', 800, cartaoId: 'inter'),
      ];
      expect(somarGastosPorCartao(gastosComCartao),
          {'nubank': 1500.0, 'inter': 800.0});
    });

    test('gasto sem cartao cai na chave vazia', () {
      final gastosComCartao = [
        gasto('marcos', 'p1', 1200, cartaoId: 'nubank'),
        gasto('marcos', 'p2', 300),
      ];
      expect(somarGastosPorCartao(gastosComCartao),
          {'nubank': 1200.0, '': 300.0});
    });

    test('filtra por membro quando pedido', () {
      final gastosComCartao = [
        gasto('marcos', 'p1', 1200, cartaoId: 'nubank'),
        gasto('silvia', 'p1', 800, cartaoId: 'nubank'),
      ];
      expect(somarGastosPorCartao(gastosComCartao, membroId: 'marcos'),
          {'nubank': 1200.0});
    });

    test('lista vazia devolve mapa vazio', () {
      expect(somarGastosPorCartao(const []), isEmpty);
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

  group('percentualComprometido', () {
    test('sem renda devolve nulo', () {
      expect(
        percentualComprometido(comprometido: 300, renda: 0),
        isNull,
      );
    });

    test('comprometido zero da 0%', () {
      expect(
        percentualComprometido(comprometido: 0, renda: 1000),
        0,
      );
    });

    test('comprometido igual a renda da 100%', () {
      expect(
        percentualComprometido(comprometido: 1000, renda: 1000),
        1,
      );
    });

    test('fracao normal', () {
      expect(
        percentualComprometido(comprometido: 300, renda: 1000),
        closeTo(0.3, 0.0001),
      );
    });

    test('renda dentro da tolerancia de centavo tambem conta como sem renda',
        () {
      expect(
        percentualComprometido(
          comprometido: 100,
          renda: toleranciaCentavo / 2,
        ),
        isNull,
      );
    });
  });

  group('ganhosEfetivos', () {
    Ganho ganhoMarcado(String membroId, double valor, {required bool previsto}) =>
        Ganho(
          id: 'g-$membroId-$previsto',
          mesRef: '2026-10',
          membroId: membroId,
          descricao: previsto ? 'Salario previsto' : 'Salario',
          valor: valor,
          criadoEm: DateTime.utc(2026, 9, 1),
          previsto: previsto,
        );

    test('pessoa so com real: usa o real', () {
      final efetivos = ganhosEfetivos([
        ganhoMarcado('marcos', 5000, previsto: false),
      ]);

      expect(efetivos, hasLength(1));
      expect(efetivos.single.valor, 5000);
      expect(efetivos.single.previsto, isFalse);
    });

    test('pessoa so com previsto: usa o previsto', () {
      final efetivos = ganhosEfetivos([
        ganhoMarcado('marcos', 3800, previsto: true),
      ]);

      expect(efetivos, hasLength(1));
      expect(efetivos.single.valor, 3800);
      expect(efetivos.single.previsto, isTrue);
    });

    test('pessoa com real e previsto no mesmo mes: real vence, previsto some',
        () {
      final efetivos = ganhosEfetivos([
        ganhoMarcado('marcos', 5000, previsto: false),
        ganhoMarcado('marcos', 3800, previsto: true),
      ]);

      expect(efetivos, hasLength(1));
      expect(efetivos.single.valor, 5000);
      expect(efetivos.single.previsto, isFalse);
    });

    test('duas pessoas, cada uma com sua propria regra', () {
      final efetivos = ganhosEfetivos([
        ganhoMarcado('marcos', 5000, previsto: false),
        ganhoMarcado('silvia', 3200, previsto: true),
      ]);

      expect(efetivos, hasLength(2));
      expect(efetivos.firstWhere((g) => g.membroId == 'marcos').valor, 5000);
      expect(efetivos.firstWhere((g) => g.membroId == 'silvia').valor, 3200);
    });

    test('lista vazia devolve lista vazia', () {
      expect(ganhosEfetivos(const []), isEmpty);
    });
  });

  group('ganhosEfetivosNaJanela', () {
    Ganho ganhoNoMes(String mesRef, String membroId, double valor,
            {required bool previsto}) =>
        Ganho(
          id: 'g-$mesRef-$membroId-$previsto',
          mesRef: mesRef,
          membroId: membroId,
          descricao: previsto ? 'Salario previsto' : 'Salario',
          valor: valor,
          criadoEm: DateTime.utc(2026, 9, 1),
          previsto: previsto,
        );

    test('real em um mes nao suprime previsto da mesma pessoa em outro mes',
        () {
      final efetivos = ganhosEfetivosNaJanela([
        ganhoNoMes('2026-09', 'marcos', 5000, previsto: false),
        ganhoNoMes('2026-11', 'marcos', 3800, previsto: true),
      ]);

      expect(efetivos, hasLength(2));
      expect(
        efetivos.firstWhere((g) => g.mesRef == '2026-09').valor,
        5000,
      );
      expect(
        efetivos.firstWhere((g) => g.mesRef == '2026-11').valor,
        3800,
      );
    });

    test('dentro do mesmo mes, real ainda vence previsto', () {
      final efetivos = ganhosEfetivosNaJanela([
        ganhoNoMes('2026-10', 'marcos', 5000, previsto: false),
        ganhoNoMes('2026-10', 'marcos', 3800, previsto: true),
      ]);

      expect(efetivos, hasLength(1));
      expect(efetivos.single.valor, 5000);
      expect(efetivos.single.previsto, isFalse);
    });

    test('meses e pessoas diferentes, cada um com sua propria regra', () {
      final efetivos = ganhosEfetivosNaJanela([
        ganhoNoMes('2026-09', 'marcos', 5000, previsto: false),
        ganhoNoMes('2026-09', 'silvia', 3200, previsto: true),
        ganhoNoMes('2026-10', 'silvia', 3300, previsto: false),
      ]);

      expect(efetivos, hasLength(3));
      expect(
        efetivos
            .firstWhere((g) => g.mesRef == '2026-09' && g.membroId == 'marcos')
            .valor,
        5000,
      );
      expect(
        efetivos
            .firstWhere((g) => g.mesRef == '2026-09' && g.membroId == 'silvia')
            .valor,
        3200,
      );
      expect(
        efetivos
            .firstWhere((g) => g.mesRef == '2026-10' && g.membroId == 'silvia')
            .valor,
        3300,
      );
    });

    test('lista vazia devolve lista vazia', () {
      expect(ganhosEfetivosNaJanela(const []), isEmpty);
    });
  });
}
