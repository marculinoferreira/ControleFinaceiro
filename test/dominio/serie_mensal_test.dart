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
}
