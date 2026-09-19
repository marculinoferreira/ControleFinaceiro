import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/cascata.dart';
import 'package:controle_financeiro/dominio/graficos.dart';
import 'package:controle_financeiro/dominio/models/cartao.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
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

const cartoes = [
  Cartao(id: 'nubank', nome: 'Nubank', ordem: 0),
  Cartao(id: 'inter', nome: 'Inter', ordem: 1),
];

void main() {
  group('fatiasPorPote', () {
    test('uma fatia por pote com gasto, na ordem de prioridade', () {
      final fatias = fatiasPorPote(
        porPote: const {'p2': 300, 'p1': 700},
        potes: potes,
      );

      expect(fatias.map((f) => f.id).toList(), ['p1', 'p2']);
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
      expect(fatias.single.id, 'p1');
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

      expect(fatias.map((f) => f.id).toList(), ['p1']);
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

  group('fatiasPorMembro', () {
    const membros = [
      Membro(
          id: 'marcos',
          nome: 'Marcos',
          email: 'm@x.com',
          cor: '#2E7D32',
          ordem: 0),
      Membro(
          id: 'silvia',
          nome: 'Silvia',
          email: 's@x.com',
          cor: '#6A1B9A',
          ordem: 1),
    ];

    test('uma fatia por pessoa, na ordem cadastrada', () {
      final fatias = fatiasPorMembro(
        porMembro: const {'silvia': 4000, 'marcos': 6000},
        membros: membros,
      );

      expect(fatias.map((f) => f.id).toList(), ['marcos', 'silvia']);
      expect(fatias.map((f) => f.valor).toList(), [6000, 4000]);
      expect(fatias.first.cor, '#2E7D32');
    });

    test('pessoa sem ganho no mes nao vira fatia invisivel', () {
      final fatias = fatiasPorMembro(
        porMembro: const {'marcos': 6000},
        membros: membros,
      );

      expect(fatias, hasLength(1));
      expect(fatias.single.nome, 'Marcos');
    });

    test('ganho de membro removido cai em Outros', () {
      final fatias = fatiasPorMembro(
        porMembro: const {'marcos': 6000, 'ex': 1000},
        membros: membros,
      );

      expect(fatias.last.nome, 'Outros');
      expect(fatias.last.valor, 1000);
    });

    test('sem ganho nenhum devolve lista vazia', () {
      expect(fatiasPorMembro(porMembro: const {}, membros: membros), isEmpty);
    });
  });

  group('fatiasPorCartao', () {
    test('uma fatia por cartao, na ordem cadastrada, com cor da paleta', () {
      final fatias = fatiasPorCartao(
        porCartao: const {'inter': 300, 'nubank': 700},
        cartoes: cartoes,
      );

      expect(fatias.map((f) => f.id).toList(), ['nubank', 'inter']);
      expect(fatias.map((f) => f.valor).toList(), [700, 300]);
      expect(fatias[0].cor, paletaCartoes[0]);
      expect(fatias[1].cor, paletaCartoes[1]);
    });

    test('cartao sem gasto nao vira fatia', () {
      final fatias = fatiasPorCartao(
        porCartao: const {'nubank': 700},
        cartoes: cartoes,
      );

      expect(fatias, hasLength(1));
    });

    test('gasto sem cartao (chave vazia) cai em Sem cartao, no fim', () {
      final fatias = fatiasPorCartao(
        porCartao: const {'nubank': 700, '': 50},
        cartoes: cartoes,
      );

      expect(fatias, hasLength(2));
      expect(fatias.last.nome, 'Sem cartão');
      expect(fatias.last.valor, 50);
    });

    test('gasto de cartao apagado tambem cai em Sem cartao', () {
      final fatias = fatiasPorCartao(
        porCartao: const {'nubank': 700, 'fantasma': 30},
        cartoes: cartoes,
      );

      expect(fatias.last.nome, 'Sem cartão');
      expect(fatias.last.valor, 30);
    });

    test('sem gasto nenhum devolve lista vazia', () {
      expect(fatiasPorCartao(porCartao: const {}, cartoes: cartoes), isEmpty);
    });

    test('mais cartoes que cores na paleta cicla de volta ao inicio', () {
      final muitosCartoes = [
        for (var i = 0; i < paletaCartoes.length + 1; i++)
          Cartao(id: 'c$i', nome: 'Cartao $i', ordem: i),
      ];
      final porCartao = {for (final c in muitosCartoes) c.id: 10.0};

      final fatias =
          fatiasPorCartao(porCartao: porCartao, cartoes: muitosCartoes);

      expect(fatias.first.cor, fatias.last.cor);
    });
  });

  group('posicaoDoGasto', () {
    ResultadoCascata resumo(
        {required double ganhos, required double gastos}) {
      return calcularCascata(
          potes: potes, totalGanhos: ganhos, totalGastos: gastos);
    }

    test('metade do previsto consumido fica no meio', () {
      final p = posicaoDoGasto(resumo(ganhos: 10000, gastos: 5000));
      expect(p, closeTo(0.5, 0.001));
    });

    test('nada gasto fica no comeco', () {
      expect(posicaoDoGasto(resumo(ganhos: 10000, gastos: 0)), 0);
    });

    test('gasto que passa de tudo trava no fim, sem passar de 1', () {
      expect(posicaoDoGasto(resumo(ganhos: 10000, gastos: 25000)), 1.0);
    });

    test('sem renda devolve zero, e nao NaN', () {
      final p = posicaoDoGasto(resumo(ganhos: 0, gastos: 500));
      expect(p, 0);
      expect(p.isNaN, isFalse);
    });
  });

  group('pesosDaCascata', () {
    test('o peso acompanha a proporcao do previsto', () {
      final resumo =
          calcularCascata(potes: potes, totalGanhos: 10000, totalGastos: 0);
      final pesos = pesosDaCascata(resumo);

      expect(pesos, hasLength(2));
      // 60/40 -> 600000/400000.
      expect(pesos[0] / pesos[1], closeTo(1.5, 0.001));
    });

    test('pote pequeno nao arredonda para zero e some da barra', () {
      const miudos = [
        Pote(
            id: 'g',
            nome: 'Grande',
            percentual: 99,
            ordem: 0,
            cor: '#2E7D32',
            icone: 'casa'),
        Pote(
            id: 'p',
            nome: 'Pequeno',
            percentual: 1,
            ordem: 1,
            cor: '#1565C0',
            icone: 'sofa'),
      ];
      final resumo =
          calcularCascata(potes: miudos, totalGanhos: 100, totalGastos: 0);

      expect(pesosDaCascata(resumo)[1], greaterThan(0));
    });

    test('sem renda todos os pesos sao zero', () {
      final resumo =
          calcularCascata(potes: potes, totalGanhos: 0, totalGastos: 0);
      expect(pesosDaCascata(resumo).every((p) => p == 0), isTrue);
    });
  });

  group('serieVazia', () {
    test('tudo zero e vazio', () {
      expect(serieVazia([0, 0, 0]), isTrue);
    });

    test('um valor acima da tolerancia ja nao e vazio', () {
      expect(serieVazia([0, 0, 5]), isFalse);
    });

    test('centavos abaixo da tolerancia contam como vazio', () {
      expect(serieVazia([0.001, 0]), isTrue);
    });

    test('lista vazia e vazia', () {
      expect(serieVazia(const []), isTrue);
    });
  });

  group('barrasComparativasPorPote', () {
    test('uma barra por pote, na ordem de prioridade, com os dois valores', () {
      final barras = barrasComparativasPorPote(
        porPoteA: const {'p1': 700},
        porPoteB: const {'p1': 300, 'p2': 200},
        potes: potes,
      );

      expect(barras.map((b) => b.id).toList(), ['p1', 'p2']);
      expect(barras[0].valorA, 700);
      expect(barras[0].valorB, 300);
      expect(barras[0].nome, 'Custo fixo');
      expect(barras[0].cor, '#2E7D32');
      expect(barras[1].valorA, 0);
      expect(barras[1].valorB, 200);
    });

    test('pote sem gasto de nenhuma das duas pessoas nao entra', () {
      final barras = barrasComparativasPorPote(
        porPoteA: const {'p1': 700},
        porPoteB: const {},
        potes: potes,
      );

      expect(barras, hasLength(1));
      expect(barras.single.id, 'p1');
    });

    test('pote com gasto de so uma das duas ainda entra', () {
      final barras = barrasComparativasPorPote(
        porPoteA: const {},
        porPoteB: const {'p2': 200},
        potes: potes,
      );

      expect(barras, hasLength(1));
      expect(barras.single.id, 'p2');
      expect(barras.single.valorA, 0);
      expect(barras.single.valorB, 200);
    });

    test('gasto em pote apagado de qualquer uma das duas cai em Outros', () {
      final barras = barrasComparativasPorPote(
        porPoteA: const {'p1': 700, 'fantasma': 50},
        porPoteB: const {'fantasma2': 20},
        potes: potes,
      );

      expect(barras, hasLength(2));
      expect(barras.last.nome, 'Outros');
      expect(barras.last.valorA, 50);
      expect(barras.last.valorB, 20);
    });
  });

  group('barrasComparativasPorCartao', () {
    test('uma barra por cartao, na ordem cadastrada, com cor da paleta', () {
      final barras = barrasComparativasPorCartao(
        porCartaoA: const {'inter': 300, 'nubank': 700},
        porCartaoB: const {'nubank': 100},
        cartoes: cartoes,
      );

      expect(barras.map((b) => b.id).toList(), ['nubank', 'inter']);
      expect(barras[0].valorA, 700);
      expect(barras[0].valorB, 100);
      expect(barras[0].cor, paletaCartoes[0]);
      expect(barras[1].valorA, 300);
      expect(barras[1].valorB, 0);
    });

    test('gasto sem cartao (chave vazia) de qualquer uma cai em Sem cartao', () {
      final barras = barrasComparativasPorCartao(
        porCartaoA: const {'nubank': 700, '': 50},
        porCartaoB: const {},
        cartoes: cartoes,
      );

      expect(barras.last.nome, 'Sem cartão');
      expect(barras.last.valorA, 50);
      expect(barras.last.valorB, 0);
    });
  });
}
