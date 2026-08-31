import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/cascata.dart';
import 'package:controle_financeiro/dominio/graficos.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';

const potes = [
  Pote(
      id: 'p1',
      nome: 'Custo fixo',
      percentual: 60,
      ordem: 0,
      cor: '#2E7D32',
      icone: 'casa'),
  Pote(
      id: 'p2',
      nome: 'Conforto',
      percentual: 40,
      ordem: 1,
      cor: '#1565C0',
      icone: 'sofa'),
];

void main() {
  group('fatiasPorPote', () {
    test('uma fatia por pote com gasto, na ordem de prioridade', () {
      final fatias = fatiasPorPote(
        porPote: const {'p2': 300, 'p1': 700},
        potes: potes,
      );

      expect(fatias.map((f) => f.poteId).toList(), ['p1', 'p2']);
      expect(fatias.map((f) => f.valor).toList(), [700, 300]);
      expect(fatias.first.nome, 'Custo fixo');
      expect(fatias.first.cor, '#2E7D32');
    });

    test('pote sem gasto nao vira fatia de tamanho zero', () {
      final fatias = fatiasPorPote(
        porPote: const {'p1': 700},
        potes: potes,
      );

      expect(fatias, hasLength(1));
      expect(fatias.single.poteId, 'p1');
    });

    test('gasto em pote apagado cai em Outros, no fim', () {
      final fatias = fatiasPorPote(
        porPote: const {'p1': 700, 'fantasma': 50},
        potes: potes,
      );

      expect(fatias, hasLength(2));
      expect(fatias.last.nome, 'Outros');
      expect(fatias.last.valor, 50);
    });

    test('varios potes apagados somam num Outros so', () {
      final fatias = fatiasPorPote(
        porPote: const {'p1': 700, 'fantasma': 50, 'sumiu': 30},
        potes: potes,
      );

      expect(fatias, hasLength(2));
      expect(fatias.last.nome, 'Outros');
      expect(fatias.last.valor, 80);
    });

    test('sem gasto nenhum devolve lista vazia', () {
      expect(fatiasPorPote(porPote: const {}, potes: potes), isEmpty);
    });

    test('valor abaixo da tolerancia de centavo nao vira fatia', () {
      final fatias = fatiasPorPote(
        porPote: const {'p1': 700, 'p2': 0.001},
        potes: potes,
      );

      expect(fatias, hasLength(1));
    });

    test('valor negativo (estorno) nao vira fatia', () {
      final fatias = fatiasPorPote(
        porPote: const {'p1': 700, 'p2': -50},
        potes: potes,
      );

      expect(fatias.map((f) => f.poteId).toList(), ['p1']);
    });

    test('total soma todas as fatias', () {
      final fatias = fatiasPorPote(
        porPote: const {'p1': 700, 'p2': 300},
        potes: potes,
      );

      expect(totalDasFatias(fatias), 1000);
    });
  });

  group('barrasPrevistoGasto', () {
    test('uma barra por pote, com previsto e gasto', () {
      final linhas = [
        LinhaCascata(
            pote: potes[0], previsto: 6000, consumido: 6000, sobra: 0),
        LinhaCascata(
            pote: potes[1], previsto: 4000, consumido: 0, sobra: 4000),
      ];

      final barras = barrasPrevistoGasto(
        linhas: linhas,
        porPote: const {'p1': 5500, 'p2': 900},
      );

      expect(barras, hasLength(2));
      expect(barras[0].nome, 'Custo fixo');
      expect(barras[0].previsto, 6000);
      expect(barras[0].gasto, 5500);
      expect(barras[1].previsto, 4000);
      expect(barras[1].gasto, 900);
    });

    test('pote sem gasto entra com gasto zero, e nao some', () {
      final linhas = [
        LinhaCascata(
            pote: potes[0], previsto: 6000, consumido: 0, sobra: 6000),
        LinhaCascata(
            pote: potes[1], previsto: 4000, consumido: 0, sobra: 4000),
      ];

      final barras = barrasPrevistoGasto(
        linhas: linhas,
        porPote: const {'p1': 100},
      );

      // O previsto de um pote importa mesmo sem gasto nenhum.
      expect(barras, hasLength(2));
      expect(barras[1].gasto, 0);
    });

    test('o gasto pode ultrapassar o previsto, sem travar no teto', () {
      final linhas = [
        LinhaCascata(
            pote: potes[0], previsto: 1000, consumido: 1000, sobra: 0),
      ];

      final barras = barrasPrevistoGasto(
        linhas: linhas,
        porPote: const {'p1': 2500},
      );

      // O usuario precisa ver que estourou; cortar em 1000 esconderia isso.
      expect(barras.single.gasto, 2500);
      expect(barras.single.gasto, greaterThan(barras.single.previsto));
    });

    test('gasto de pote que nao esta na cascata e ignorado', () {
      final linhas = [
        LinhaCascata(
            pote: potes[0], previsto: 1000, consumido: 0, sobra: 1000),
      ];

      final barras = barrasPrevistoGasto(
        linhas: linhas,
        porPote: const {'p1': 100, 'fantasma': 999},
      );

      expect(barras, hasLength(1));
      expect(barras.single.gasto, 100);
    });

    test('sem potes devolve lista vazia', () {
      expect(
        barrasPrevistoGasto(linhas: const [], porPote: const {'p1': 100}),
        isEmpty,
      );
    });

    test('o teto da barra e o maior entre previsto e gasto', () {
      final linhas = [
        LinhaCascata(
            pote: potes[0], previsto: 1000, consumido: 1000, sobra: 0),
        LinhaCascata(
            pote: potes[1], previsto: 4000, consumido: 0, sobra: 4000),
      ];

      final barras = barrasPrevistoGasto(
        linhas: linhas,
        porPote: const {'p1': 6500},
      );

      expect(tetoDasBarras(barras), 6500);
    });

    test('teto de lista vazia e zero, sem lancar', () {
      expect(tetoDasBarras(const []), 0);
    });
  });
}
