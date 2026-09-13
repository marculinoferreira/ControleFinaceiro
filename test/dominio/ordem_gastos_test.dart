import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/cartao.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/dominio/ordem_gastos.dart';

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

Gasto gasto(
  String descricao, {
  required int dia,
  String poteId = 'p1',
  String? cartaoId,
  int mes = 8,
  double valor = 100,
}) =>
    Gasto(
      id: '$descricao-$dia',
      mesRef: '2026-${mes.toString().padLeft(2, '0')}',
      membroId: 'marcos',
      poteId: poteId,
      descricao: descricao,
      valor: valor,
      criadoEm: DateTime.utc(2026, 8, 1),
      data: DateTime(2026, mes, dia),
      cartaoId: cartaoId,
      parcelado: false,
    );

void main() {
  group('OrdemGastos.data', () {
    test('agrupa por dia, do mais recente para o mais antigo', () {
      final grupos = agruparGastos(
        gastos: [
          gasto('Meli', dia: 10),
          gasto('Feira', dia: 12),
          gasto('Padaria', dia: 10),
          gasto('Freezer', dia: 12),
        ],
        ordem: OrdemGastos.data,
        potes: potes,
      );

      expect(grupos.map((g) => g.titulo).toList(),
          ['12/08/2026', '10/08/2026']);
      expect(grupos[0].itens.map((g) => g.descricao).toList(),
          ['Feira', 'Freezer']);
      expect(grupos[1].itens.map((g) => g.descricao).toList(),
          ['Meli', 'Padaria']);
    });

    test('o cabecalho vem no formato brasileiro', () {
      final grupos = agruparGastos(
        gastos: [gasto('Feira', dia: 3)],
        ordem: OrdemGastos.data,
        potes: potes,
      );

      expect(grupos.single.titulo, '03/08/2026'); // com zero a esquerda
    });

    test('ordena corretamente atravessando a virada de mes', () {
      final grupos = agruparGastos(
        gastos: [
          gasto('Janeiro', dia: 5, mes: 1),
          gasto('Dezembro', dia: 30, mes: 12),
        ],
        ordem: OrdemGastos.data,
        potes: potes,
      );

      // 05/01 e mais recente que 30/12 do mesmo ano-calendario do teste.
      expect(grupos.first.titulo, '30/12/2026');
      expect(grupos.last.titulo, '05/01/2026');
    });

    test('dentro do dia ordena pela descricao, ignorando maiuscula', () {
      final grupos = agruparGastos(
        gastos: [
          gasto('padaria', dia: 12),
          gasto('Açougue', dia: 12),
          gasto('Banco', dia: 12),
        ],
        ordem: OrdemGastos.data,
        potes: potes,
      );

      expect(grupos.single.itens.map((g) => g.descricao).toList(),
          ['Açougue', 'Banco', 'padaria']);
    });

    test('horas diferentes no mesmo dia caem no mesmo grupo', () {
      final manha = Gasto(
        id: 'a',
        mesRef: '2026-08',
        membroId: 'marcos',
        poteId: 'p1',
        descricao: 'Cafe',
        valor: 10,
        criadoEm: DateTime.utc(2026, 8, 1),
        data: DateTime(2026, 8, 12, 8, 30),
        parcelado: false,
      );
      final noite = manha.copyWith(
          id: 'b', descricao: 'Janta', data: DateTime(2026, 8, 12, 21, 0));

      final grupos = agruparGastos(
        gastos: [manha, noite],
        ordem: OrdemGastos.data,
        potes: potes,
      );

      expect(grupos, hasLength(1));
      expect(grupos.single.itens, hasLength(2));
    });
  });

  group('OrdemGastos.alfabetica', () {
    test('devolve um grupo unico, sem cabecalho', () {
      final grupos = agruparGastos(
        gastos: [gasto('Meli', dia: 10), gasto('Feira', dia: 12)],
        ordem: OrdemGastos.alfabetica,
        potes: potes,
      );

      expect(grupos, hasLength(1));
      expect(grupos.single.titulo, isEmpty);
    });

    test('ordena por descricao, ignorando maiuscula', () {
      final grupos = agruparGastos(
        gastos: [
          gasto('padaria', dia: 1),
          gasto('Açougue', dia: 2),
          gasto('Meli', dia: 3),
        ],
        ordem: OrdemGastos.alfabetica,
        potes: potes,
      );

      expect(grupos.single.itens.map((g) => g.descricao).toList(),
          ['Açougue', 'Meli', 'padaria']);
    });

    test('a data nao influencia a ordem alfabetica', () {
      final grupos = agruparGastos(
        gastos: [gasto('Zebra', dia: 28), gasto('Abacaxi', dia: 1)],
        ordem: OrdemGastos.alfabetica,
        potes: potes,
      );

      expect(grupos.single.itens.first.descricao, 'Abacaxi');
    });
  });

  group('OrdemGastos.pote', () {
    test('um grupo por pote, na ordem de prioridade da cascata', () {
      final grupos = agruparGastos(
        gastos: [
          gasto('Freezer', dia: 10, poteId: 'p2'),
          gasto('Aluguel', dia: 5, poteId: 'p1'),
        ],
        ordem: OrdemGastos.pote,
        potes: potes,
      );

      expect(grupos.map((g) => g.titulo).toList(), ['Custo fixo', 'Conforto']);
    });

    test('pote sem gasto nenhum nao vira grupo vazio', () {
      final grupos = agruparGastos(
        gastos: [gasto('Aluguel', dia: 5, poteId: 'p1')],
        ordem: OrdemGastos.pote,
        potes: potes,
      );

      expect(grupos, hasLength(1));
      expect(grupos.single.titulo, 'Custo fixo');
    });

    test('gasto de pote apagado cai em Outros, no fim', () {
      final grupos = agruparGastos(
        gastos: [
          gasto('Aluguel', dia: 5, poteId: 'p1'),
          gasto('Fantasma', dia: 6, poteId: 'sumiu'),
        ],
        ordem: OrdemGastos.pote,
        potes: potes,
      );

      expect(grupos.map((g) => g.titulo).toList(), ['Custo fixo', 'Outros']);
      expect(grupos.last.itens.single.descricao, 'Fantasma');
    });

    test('varios potes apagados somam num Outros so', () {
      final grupos = agruparGastos(
        gastos: [
          gasto('A', dia: 5, poteId: 'sumiu1'),
          gasto('B', dia: 6, poteId: 'sumiu2'),
        ],
        ordem: OrdemGastos.pote,
        potes: potes,
      );

      expect(grupos, hasLength(1));
      expect(grupos.single.titulo, 'Outros');
      expect(grupos.single.itens, hasLength(2));
    });

    test('dentro do pote ordena por data, do mais recente para o mais antigo',
        () {
      final grupos = agruparGastos(
        gastos: [
          gasto('Zebra', dia: 5, poteId: 'p1'),
          gasto('Abacaxi', dia: 6, poteId: 'p1'),
        ],
        ordem: OrdemGastos.pote,
        potes: potes,
      );

      expect(grupos.single.itens.map((g) => g.descricao).toList(),
          ['Abacaxi', 'Zebra']);
    });

    test('dentro do pote, mesma data desempata pela descricao', () {
      final grupos = agruparGastos(
        gastos: [
          gasto('Zebra', dia: 5, poteId: 'p1'),
          gasto('Abacaxi', dia: 5, poteId: 'p1'),
        ],
        ordem: OrdemGastos.pote,
        potes: potes,
      );

      expect(grupos.single.itens.map((g) => g.descricao).toList(),
          ['Abacaxi', 'Zebra']);
    });

    test('sem potes cadastrados tudo cai em Outros', () {
      final grupos = agruparGastos(
        gastos: [gasto('Aluguel', dia: 5)],
        ordem: OrdemGastos.pote,
        potes: const [],
      );

      expect(grupos.single.titulo, 'Outros');
    });
  });

  group('OrdemGastos.cartao', () {
    const cartoes = [
      Cartao(id: 'ct1', nome: 'Nubank', ordem: 0),
      Cartao(id: 'ct2', nome: 'Inter', ordem: 1),
    ];

    test('um grupo por cartao, na ordem cadastrada', () {
      final grupos = agruparGastos(
        gastos: [
          gasto('Freezer', dia: 10, cartaoId: 'ct2'),
          gasto('Feira', dia: 12, cartaoId: 'ct1'),
        ],
        ordem: OrdemGastos.cartao,
        potes: potes,
        cartoes: cartoes,
      );

      expect(grupos.map((g) => g.titulo).toList(), ['Nubank', 'Inter']);
    });

    test('gasto sem cartao vai para "Sem cartão", depois dos cartoes', () {
      final grupos = agruparGastos(
        gastos: [
          gasto('Padaria', dia: 11),
          gasto('Feira', dia: 12, cartaoId: 'ct1'),
        ],
        ordem: OrdemGastos.cartao,
        potes: potes,
        cartoes: cartoes,
      );

      expect(grupos.map((g) => g.titulo).toList(), ['Nubank', 'Sem cartão']);
      expect(grupos.last.itens.single.descricao, 'Padaria');
    });

    test('cartao removido vira "Outros", separado de "Sem cartão"', () {
      final grupos = agruparGastos(
        gastos: [
          gasto('Feira', dia: 12, cartaoId: 'ct1'),
          gasto('Padaria', dia: 11),
          gasto('Antigo', dia: 10, cartaoId: 'sumiu'),
        ],
        ordem: OrdemGastos.cartao,
        potes: potes,
        cartoes: cartoes,
      );

      // Dinheiro e cartao-encerrado sao coisas diferentes.
      expect(grupos.map((g) => g.titulo).toList(),
          ['Nubank', 'Sem cartão', 'Outros']);
      expect(grupos.last.itens.single.descricao, 'Antigo');
    });

    test('cartao sem gasto nenhum nao vira grupo vazio', () {
      final grupos = agruparGastos(
        gastos: [gasto('Feira', dia: 12, cartaoId: 'ct1')],
        ordem: OrdemGastos.cartao,
        potes: potes,
        cartoes: cartoes,
      );

      expect(grupos, hasLength(1));
      expect(grupos.single.titulo, 'Nubank');
    });

    test(
        'dentro do cartao ordena por data, do mais recente para o mais antigo',
        () {
      final grupos = agruparGastos(
        gastos: [
          gasto('Zebra', dia: 10, cartaoId: 'ct1'),
          gasto('Abacaxi', dia: 12, cartaoId: 'ct1'),
        ],
        ordem: OrdemGastos.cartao,
        potes: potes,
        cartoes: cartoes,
      );

      expect(grupos.single.itens.map((g) => g.descricao).toList(),
          ['Abacaxi', 'Zebra']);
    });

    test('dentro do cartao, mesma data desempata pela descricao', () {
      final grupos = agruparGastos(
        gastos: [
          gasto('Zebra', dia: 12, cartaoId: 'ct1'),
          gasto('Abacaxi', dia: 12, cartaoId: 'ct1'),
        ],
        ordem: OrdemGastos.cartao,
        potes: potes,
        cartoes: cartoes,
      );

      expect(grupos.single.itens.map((g) => g.descricao).toList(),
          ['Abacaxi', 'Zebra']);
    });

    test('sem cartao cadastrado tudo cai em "Sem cartão"', () {
      final grupos = agruparGastos(
        gastos: [gasto('Padaria', dia: 11)],
        ordem: OrdemGastos.cartao,
        potes: potes,
        cartoes: const [],
      );

      expect(grupos.single.titulo, 'Sem cartão');
    });
  });

  group('bordas', () {
    test('lista vazia devolve nenhum grupo, em qualquer ordem', () {
      for (final ordem in OrdemGastos.values) {
        expect(
          agruparGastos(
              gastos: const [], ordem: ordem, potes: potes, cartoes: const []),
          isEmpty,
          reason: 'falhou para $ordem',
        );
      }
    });

    test('nenhum gasto se perde no agrupamento, em qualquer ordem', () {
      final gastos = [
        gasto('Feira', dia: 12, poteId: 'p1'),
        gasto('Meli', dia: 10, poteId: 'p2'),
        gasto('Orfao', dia: 11, poteId: 'sumiu'),
      ];

      for (final ordem in OrdemGastos.values) {
        final grupos = agruparGastos(
          gastos: gastos,
          ordem: ordem,
          potes: potes,
          cartoes: const [Cartao(id: 'ct1', nome: 'Nubank', ordem: 0)],
        );
        final total = grupos.fold(0, (n, g) => n + g.itens.length);
        expect(total, 3, reason: 'falhou para $ordem');
      }
    });
  });
}
