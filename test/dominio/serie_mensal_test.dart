import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/serie_mensal.dart';

Ganho ganho(String mesRef, double valor, {String membroId = 'marcos'}) => Ganho(
      id: 'g-$mesRef-$membroId-$valor',
      mesRef: mesRef,
      membroId: membroId,
      descricao: 'salario',
      valor: valor,
      criadoEm: DateTime.utc(2026, 1, 1),
    );

Gasto gasto(String mesRef, double valor, {String membroId = 'marcos'}) => Gasto(
      id: 'd-$mesRef-$membroId-$valor',
      mesRef: mesRef,
      membroId: membroId,
      poteId: 'p1',
      descricao: 'mercado',
      valor: valor,
      criadoEm: DateTime.utc(2026, 1, 1),
      parcelado: false,
    );

void main() {
  group('janelaAte', () {
    test('12 meses terminando em Ago/26 vao de Set/25 a Ago/26', () {
      final janela = janelaAte(const MesRef(2026, 8), 12);

      expect(janela, hasLength(12));
      expect(janela.first.valor, '2025-09');
      expect(janela.last.valor, '2026-08');
    });

    test('a janela cruza a virada de ano', () {
      final janela = janelaAte(const MesRef(2026, 1), 3);

      expect(janela.map((m) => m.valor).toList(),
          ['2025-11', '2025-12', '2026-01']);
    });

    test('janela de um mes devolve so o proprio mes', () {
      final janela = janelaAte(const MesRef(2026, 8), 1);
      expect(janela.map((m) => m.valor).toList(), ['2026-08']);
    });

    test('quantidade zero ou negativa e recusada', () {
      expect(() => janelaAte(const MesRef(2026, 8), 0), throwsArgumentError);
      expect(() => janelaAte(const MesRef(2026, 8), -3), throwsArgumentError);
    });
  });

  group('janelaDe', () {
    test('12 meses a partir de Ago/26 vao ate Jul/27', () {
      final janela = janelaDe(const MesRef(2026, 8), 12);

      expect(janela, hasLength(12));
      expect(janela.first.valor, '2026-08'); // inclusive
      expect(janela.last.valor, '2027-07');
    });

    test('quantidade zero e recusada', () {
      expect(() => janelaDe(const MesRef(2026, 8), 0), throwsArgumentError);
    });
  });

  group('montarSerie', () {
    test('agrupa ganhos e gastos por mes', () {
      final meses = janelaAte(const MesRef(2026, 3), 3); // Jan, Fev, Mar

      final serie = montarSerie(
        meses: meses,
        ganhos: [ganho('2026-01', 5000), ganho('2026-03', 6000)],
        gastos: [gasto('2026-01', 1200), gasto('2026-03', 900)],
      );

      expect(serie, hasLength(3));
      expect(serie[0].mes.valor, '2026-01');
      expect(serie[0].ganhos, 5000);
      expect(serie[0].gastos, 1200);
      expect(serie[2].ganhos, 6000);
      expect(serie[2].gastos, 900);
    });

    test('mes sem lancamento entra com zero, nao some da serie', () {
      final meses = janelaAte(const MesRef(2026, 3), 3);

      final serie = montarSerie(
        meses: meses,
        ganhos: [ganho('2026-01', 5000)],
        gastos: const [],
      );

      // Fevereiro nao teve nada, mas precisa existir: buraco na linha e
      // pior que um ponto em zero.
      expect(serie, hasLength(3));
      expect(serie[1].mes.valor, '2026-02');
      expect(serie[1].ganhos, 0);
      expect(serie[1].gastos, 0);
    });

    test('soma varios lancamentos do mesmo mes', () {
      final serie = montarSerie(
        meses: janelaAte(const MesRef(2026, 1), 1),
        ganhos: [ganho('2026-01', 5000), ganho('2026-01', 1500)],
        gastos: [gasto('2026-01', 200), gasto('2026-01', 300)],
      );

      expect(serie.single.ganhos, 6500);
      expect(serie.single.gastos, 500);
    });

    test('com membroId soma so aquela pessoa', () {
      final serie = montarSerie(
        meses: janelaAte(const MesRef(2026, 1), 1),
        ganhos: [
          ganho('2026-01', 5000, membroId: 'marcos'),
          ganho('2026-01', 4000, membroId: 'silvia'),
        ],
        gastos: [
          gasto('2026-01', 200, membroId: 'marcos'),
          gasto('2026-01', 700, membroId: 'silvia'),
        ],
        membroId: 'marcos',
      );

      expect(serie.single.ganhos, 5000);
      expect(serie.single.gastos, 200);
    });

    test('sem membroId soma o casal', () {
      final serie = montarSerie(
        meses: janelaAte(const MesRef(2026, 1), 1),
        ganhos: [
          ganho('2026-01', 5000, membroId: 'marcos'),
          ganho('2026-01', 4000, membroId: 'silvia'),
        ],
        gastos: const [],
      );

      expect(serie.single.ganhos, 9000);
    });

    test('ignora lancamento fora da janela', () {
      final serie = montarSerie(
        meses: janelaAte(const MesRef(2026, 3), 2), // Fev e Mar
        ganhos: [ganho('2026-01', 5000), ganho('2026-03', 6000)],
        gastos: const [],
      );

      expect(serie, hasLength(2));
      expect(serie.map((p) => p.ganhos).toList(), [0, 6000]);
    });

    test('a saida e cronologica mesmo com entrada fora de ordem', () {
      final serie = montarSerie(
        meses: janelaAte(const MesRef(2026, 3), 3),
        ganhos: [ganho('2026-03', 300), ganho('2026-01', 100)],
        gastos: [gasto('2026-02', 20)],
      );

      expect(serie.map((p) => p.mes.valor).toList(),
          ['2026-01', '2026-02', '2026-03']);
      expect(serie.map((p) => p.ganhos).toList(), [100, 0, 300]);
    });

    test('serie vazia quando a lista de meses e vazia', () {
      final serie = montarSerie(
        meses: const [],
        ganhos: [ganho('2026-01', 5000)],
        gastos: const [],
      );

      expect(serie, isEmpty);
    });

    test('parcelas contam como gasto do mes em que caem', () {
      final parcela = Gasto(
        id: 'x',
        mesRef: '2026-02',
        membroId: 'marcos',
        poteId: 'p1',
        descricao: 'geladeira',
        valor: 100,
        criadoEm: DateTime.utc(2026, 1, 1),
        parcelado: true,
        compraId: 'c1',
        parcela: 2,
        totalParcelas: 10,
      );

      final serie = montarSerie(
        meses: janelaAte(const MesRef(2026, 2), 2),
        ganhos: const [],
        gastos: [parcela],
      );

      expect(serie[1].gastos, 100);
    });
  });

  group('serieComprometimento', () {
    Gasto parcela(String mesRef, double valor, {int n = 2}) => Gasto(
          id: 'p-$mesRef',
          mesRef: mesRef,
          membroId: 'marcos',
          poteId: 'p1',
          descricao: 'geladeira',
          valor: valor,
          criadoEm: DateTime.utc(2026, 1, 1),
          parcelado: true,
          compraId: 'c1',
          parcela: 1,
          totalParcelas: n,
        );

    test('soma as parcelas de cada mes', () {
      final serie = serieComprometimento(
        meses: janelaDe(const MesRef(2026, 8), 3),
        parcelas: [
          parcela('2026-08', 100),
          parcela('2026-08', 50),
          parcela('2026-09', 100),
        ],
      );

      expect(serie.map((p) => p.valor).toList(), [150, 100, 0]);
    });

    test('a linha cai a zero depois da ultima parcela', () {
      final serie = serieComprometimento(
        meses: janelaDe(const MesRef(2026, 8), 4),
        parcelas: [parcela('2026-08', 100), parcela('2026-09', 100)],
      );

      // Sem os zeros a linha terminaria no ar, sugerindo divida perpetua.
      expect(serie, hasLength(4));
      expect(serie.last.valor, 0);
    });

    test('gasto nao parcelado nao entra no comprometimento', () {
      final simples = Gasto(
        id: 'x',
        mesRef: '2026-08',
        membroId: 'marcos',
        poteId: 'p1',
        descricao: 'mercado',
        valor: 900,
        criadoEm: DateTime.utc(2026, 8, 1),
        parcelado: false,
      );

      final serie = serieComprometimento(
        meses: janelaDe(const MesRef(2026, 8), 2),
        parcelas: [simples, parcela('2026-08', 100)],
      );

      expect(serie.first.valor, 100);
    });

    test('sem parcela nenhuma devolve a janela toda em zero', () {
      final serie = serieComprometimento(
        meses: janelaDe(const MesRef(2026, 8), 3),
        parcelas: const [],
      );

      expect(serie, hasLength(3));
      expect(serie.every((p) => p.valor == 0), isTrue);
    });

    test('com membroId, soma so as parcelas daquela pessoa', () {
      final deSilvia = Gasto(
        id: 's-2026-08',
        mesRef: '2026-08',
        membroId: 'silvia',
        poteId: 'p1',
        descricao: 'geladeira',
        valor: 200,
        criadoEm: DateTime.utc(2026, 1, 1),
        parcelado: true,
        compraId: 'c2',
        parcela: 1,
        totalParcelas: 2,
      );

      final serie = serieComprometimento(
        meses: janelaDe(const MesRef(2026, 8), 2),
        parcelas: [parcela('2026-08', 100), deSilvia],
        membroId: 'marcos',
      );

      expect(serie.first.valor, 100);
    });
  });

  group('serieProjecao', () {
    Gasto parcela(String mesRef, double valor, {String membroId = 'marcos'}) =>
        Gasto(
          id: 'p-$mesRef-$membroId',
          mesRef: mesRef,
          membroId: membroId,
          poteId: 'p1',
          descricao: 'geladeira',
          valor: valor,
          criadoEm: DateTime.utc(2026, 1, 1),
          parcelado: true,
          compraId: 'c1',
          parcela: 1,
          totalParcelas: 2,
        );

    test('renda repete o valor assumido em todos os meses', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 3),
        ganhoMensalAssumido: 5000,
        parcelas: const [],
      );

      expect(serie.map((p) => p.ganhos).toList(), [5000, 5000, 5000]);
    });

    test('gasto e o comprometido em parcelas daquele mes', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 3),
        ganhoMensalAssumido: 5000,
        parcelas: [parcela('2026-08', 100), parcela('2026-09', 100)],
      );

      expect(serie.map((p) => p.gastos).toList(), [100, 100, 0]);
    });

    test('saldo e ganhos menos gastos', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 1),
        ganhoMensalAssumido: 5000,
        parcelas: [parcela('2026-08', 6000)],
      );

      expect(serie.single.saldo, -1000);
    });

    test('filtra por membroId quando informado', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 1),
        ganhoMensalAssumido: 3000,
        parcelas: [
          parcela('2026-08', 100, membroId: 'marcos'),
          parcela('2026-08', 200, membroId: 'silvia'),
        ],
        membroId: 'silvia',
      );

      expect(serie.single.gastos, 200);
    });

    test('sem parcela nenhuma, gasto fica zero em todos os meses', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 2),
        ganhoMensalAssumido: 5000,
        parcelas: const [],
      );

      expect(serie.every((p) => p.gastos == 0), isTrue);
    });

    test('mes presente em ganhosConhecidos usa o valor do mapa', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 3),
        ganhoMensalAssumido: 5000,
        parcelas: const [],
        ganhosConhecidos: const {'2026-09': 5500},
      );

      expect(serie[0].ganhos, 5000); // 2026-08: nao esta no mapa
      expect(serie[1].ganhos, 5500); // 2026-09: esta no mapa
      expect(serie[2].ganhos, 5000); // 2026-10: nao esta no mapa
    });

    test('mapa vazio (default) se comporta como antes', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 2),
        ganhoMensalAssumido: 5000,
        parcelas: const [],
      );

      expect(serie.every((p) => p.ganhos == 5000), isTrue);
    });
  });

  group('serieGastoPote', () {
    Gasto gastoDoPote(String mesRef, String poteId, double valor,
            {String membroId = 'marcos'}) =>
        Gasto(
          id: 'g-$mesRef-$poteId-$membroId',
          mesRef: mesRef,
          membroId: membroId,
          poteId: poteId,
          descricao: 'Compra',
          valor: valor,
          criadoEm: DateTime.utc(2026, 1, 1),
          parcelado: false,
        );

    test('mes sem gasto no pote entra com zero', () {
      final serie = serieGastoPote(
        meses: janelaAte(const MesRef(2026, 8), 3),
        gastos: [gastoDoPote('2026-08', 'p1', 500)],
        poteId: 'p1',
      );

      expect(serie.map((p) => p.valor).toList(), [0, 0, 500]);
    });

    test('soma gastos do mesmo pote e mes', () {
      final serie = serieGastoPote(
        meses: janelaAte(const MesRef(2026, 8), 1),
        gastos: [
          gastoDoPote('2026-08', 'p1', 200),
          gastoDoPote('2026-08', 'p1', 150),
        ],
        poteId: 'p1',
      );

      expect(serie.single.valor, 350);
    });

    test('ignora gasto de outro pote', () {
      final serie = serieGastoPote(
        meses: janelaAte(const MesRef(2026, 8), 1),
        gastos: [gastoDoPote('2026-08', 'p2', 999)],
        poteId: 'p1',
      );

      expect(serie.single.valor, 0);
    });

    test('filtra por membroId quando informado', () {
      final serie = serieGastoPote(
        meses: janelaAte(const MesRef(2026, 8), 1),
        gastos: [
          gastoDoPote('2026-08', 'p1', 200, membroId: 'marcos'),
          gastoDoPote('2026-08', 'p1', 300, membroId: 'silvia'),
        ],
        poteId: 'p1',
        membroId: 'silvia',
      );

      expect(serie.single.valor, 300);
    });

    test('ignora gasto fora da janela', () {
      final serie = serieGastoPote(
        meses: janelaAte(const MesRef(2026, 8), 1),
        gastos: [gastoDoPote('2020-01', 'p1', 999)],
        poteId: 'p1',
      );

      expect(serie.single.valor, 0);
    });
  });
}
