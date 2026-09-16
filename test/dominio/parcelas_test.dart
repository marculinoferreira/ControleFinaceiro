import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/parcelas.dart';

Gasto gastoBase({
  String mesRef = '2026-08',
  double valor = 100,
  bool pixDebito = false,
}) =>
    Gasto(
      id: '',
      mesRef: mesRef,
      membroId: 'marcos',
      poteId: 'p2',
      descricao: 'Geladeira',
      valor: valor,
      criadoEm: DateTime.utc(2026, 8, 5),
      pixDebito: pixDebito,
      parcelado: false,
    );

void main() {
  group('gerarParcelas', () {
    test('10x a partir de agosto de 2026 termina em maio de 2027', () {
      final ps = gerarParcelas(
          base: gastoBase(), quantidade: 10, compraId: 'c1');

      expect(ps, hasLength(10));
      expect(ps.first.mesRef, '2026-08');
      expect(ps.last.mesRef, '2027-05');
    });

    test('numera as parcelas de 1 a N', () {
      final ps = gerarParcelas(
          base: gastoBase(), quantidade: 10, compraId: 'c1');

      expect(ps.map((g) => g.parcela).toList(),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(ps.every((g) => g.totalParcelas == 10), isTrue);
    });

    test('vira o ano corretamente', () {
      final ps = gerarParcelas(
          base: gastoBase(mesRef: '2026-12'), quantidade: 3, compraId: 'c1');

      expect(ps.map((g) => g.mesRef).toList(),
          ['2026-12', '2027-01', '2027-02']);
    });

    test('24x avanca exatamente dois anos', () {
      final ps = gerarParcelas(
          base: gastoBase(), quantidade: 24, compraId: 'c1');

      expect(ps.last.mesRef, '2028-07'); // parcela 24 = avancar(23)
    });

    test('todas compartilham compraId, pote e pessoa', () {
      final ps = gerarParcelas(
          base: gastoBase(), quantidade: 10, compraId: 'c1');

      expect(ps.every((g) => g.compraId == 'c1'), isTrue);
      expect(ps.every((g) => g.poteId == 'p2'), isTrue);
      expect(ps.every((g) => g.membroId == 'marcos'), isTrue);
      expect(ps.every((g) => g.parcelado), isTrue);
    });

    test('cada parcela vale o valor da parcela, nao o total', () {
      final ps = gerarParcelas(
          base: gastoBase(valor: 100), quantidade: 10, compraId: 'c1');

      expect(ps.every((g) => g.valor == 100), isTrue);
    });

    test('todas as parcelas herdam o pixDebito do base', () {
      final ps = gerarParcelas(
        base: gastoBase(pixDebito: true),
        quantidade: 10,
        compraId: 'c1',
      );

      expect(ps.every((g) => g.pixDebito), isTrue);
    });

    test('quantidade 1 tambem herda o pixDebito do base', () {
      final ps = gerarParcelas(
        base: gastoBase(pixDebito: true),
        quantidade: 1,
        compraId: 'c1',
      );

      expect(ps.single.pixDebito, isTrue);
    });

    test('quantidade 1 devolve um gasto simples, nao parcelado', () {
      final ps = gerarParcelas(
          base: gastoBase(), quantidade: 1, compraId: 'c1');

      expect(ps, hasLength(1));
      expect(ps.single.parcelado, isFalse);
      expect(ps.single.compraId, isNull);
      expect(ps.single.parcela, isNull);
      expect(ps.single.totalParcelas, isNull);
    });

    test('quantidade zero lanca ArgumentError', () {
      expect(
        () => gerarParcelas(base: gastoBase(), quantidade: 0, compraId: 'c1'),
        throwsArgumentError,
      );
    });

    test('quantidade negativa lanca ArgumentError', () {
      expect(
        () => gerarParcelas(base: gastoBase(), quantidade: -3, compraId: 'c1'),
        throwsArgumentError,
      );
    });

    test('mesRef invalido no base lanca FormatException', () {
      expect(
        () => gerarParcelas(
            base: gastoBase(mesRef: '2026-8'), quantidade: 3, compraId: 'c1'),
        throwsFormatException,
      );
    });
  });

  group('agruparParcelasEmAberto', () {
    final compra = gerarParcelas(
        base: gastoBase(), quantidade: 10, compraId: 'c1');

    test('agrupa pela compra e usa a parcela mais proxima do mes atual', () {
      final abertas = agruparParcelasEmAberto(
        gastos: compra,
        mesAtual: const MesRef(2026, 10), // parcela 3
      );

      expect(abertas, hasLength(1));
      expect(abertas.single.parcelaAtual, 3);
      expect(abertas.single.totalParcelas, 10);
      expect(abertas.single.parcelasRestantes, 7);
      expect(abertas.single.valorParcela, 100);
    });

    test('formata o resumo como no spec', () {
      final abertas = agruparParcelasEmAberto(
        gastos: compra,
        mesAtual: const MesRef(2026, 10),
      );

      expect(abertas.single.resumo,
          'Geladeira — parcela 3/10 — R\$ 100,00/mês — faltam 7 meses');
    });

    test('usa singular quando falta um mes', () {
      final abertas = agruparParcelasEmAberto(
        gastos: compra,
        mesAtual: const MesRef(2027, 4), // parcela 9, falta 1
      );

      expect(abertas.single.resumo, endsWith('falta 1 mês'));
    });

    test('ignora compras ja quitadas', () {
      final abertas = agruparParcelasEmAberto(
        gastos: compra,
        mesAtual: const MesRef(2027, 6), // depois da ultima parcela
      );

      expect(abertas, isEmpty);
    });

    test('inclui a ultima parcela quando ela e o mes atual', () {
      final abertas = agruparParcelasEmAberto(
        gastos: compra,
        mesAtual: const MesRef(2027, 5),
      );

      expect(abertas.single.parcelaAtual, 10);
      expect(abertas.single.parcelasRestantes, 0);
      expect(abertas.single.resumo, endsWith('ultima parcela'));
    });

    test('ignora gastos nao parcelados', () {
      final abertas = agruparParcelasEmAberto(
        gastos: [gastoBase().copyWith(id: 'g9')],
        mesAtual: const MesRef(2026, 8),
      );

      expect(abertas, isEmpty);
    });

    test('separa compras diferentes', () {
      final outra = gerarParcelas(
        base: gastoBase(mesRef: '2026-09', valor: 250)
            .copyWith(descricao: 'Sofa'),
        quantidade: 4,
        compraId: 'c2',
      );

      final abertas = agruparParcelasEmAberto(
        gastos: [...compra, ...outra],
        mesAtual: const MesRef(2026, 10),
      );

      expect(abertas, hasLength(2));
      expect(abertas.map((c) => c.compraId).toSet(), {'c1', 'c2'});
    });

    test('ordena da compra que termina primeiro para a que termina por ultimo', () {
      final outra = gerarParcelas(
        base: gastoBase(mesRef: '2026-09', valor: 250)
            .copyWith(descricao: 'Sofa'),
        quantidade: 4,
        compraId: 'c2',
      );

      final abertas = agruparParcelasEmAberto(
        gastos: [...compra, ...outra],
        mesAtual: const MesRef(2026, 10),
      );

      // Sofa: 4 parcelas desde 09, no mes 10 esta na 2, faltam 2.
      // Geladeira: faltam 7.
      expect(abertas.first.compraId, 'c2');
    });
  });
}
