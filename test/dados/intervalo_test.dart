import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';

Ganho ganho(String mesRef, double valor) => Ganho(
      id: '',
      mesRef: mesRef,
      membroId: 'marcos',
      descricao: 'salario',
      valor: valor,
      criadoEm: DateTime.utc(2026, 1, 1),
    );

Gasto gasto(String mesRef, double valor) => Gasto(
      id: '',
      mesRef: mesRef,
      membroId: 'marcos',
      poteId: 'p1',
      descricao: 'mercado',
      valor: valor,
      criadoEm: DateTime.utc(2026, 1, 1),
      parcelado: false,
    );

void main() {
  group('RepositorioGanhosFake.observarIntervalo', () {
    test('devolve so o que cai dentro da janela, extremos inclusive',
        () async {
      final repo = RepositorioGanhosFake();
      await repo.adicionar(ganho('2025-12', 100));
      await repo.adicionar(ganho('2026-01', 200));
      await repo.adicionar(ganho('2026-03', 300));
      await repo.adicionar(ganho('2026-04', 400));

      final lista = await repo.observarIntervalo('2026-01', '2026-03').first;

      expect(lista.map((g) => g.valor).toList()..sort(), [200, 300]);
    });

    test('emite de novo quando algo e gravado dentro da janela', () async {
      final repo = RepositorioGanhosFake();
      final emissoes = <int>[];
      final assinatura = repo
          .observarIntervalo('2026-01', '2026-03')
          .listen((l) => emissoes.add(l.length));

      await Future<void>.delayed(Duration.zero);
      await repo.adicionar(ganho('2026-02', 500));
      await Future<void>.delayed(Duration.zero);

      await assinatura.cancel();
      expect(emissoes, [0, 1]);
    });

    test('janela de um mes so', () async {
      final repo = RepositorioGanhosFake();
      await repo.adicionar(ganho('2026-01', 100));
      await repo.adicionar(ganho('2026-02', 200));

      final lista = await repo.observarIntervalo('2026-01', '2026-01').first;

      expect(lista.single.valor, 100);
    });

    test('janela que cruza o ano', () async {
      final repo = RepositorioGanhosFake();
      await repo.adicionar(ganho('2025-11', 100));
      await repo.adicionar(ganho('2025-12', 200));
      await repo.adicionar(ganho('2026-01', 300));
      await repo.adicionar(ganho('2026-02', 400));

      final lista = await repo.observarIntervalo('2025-12', '2026-01').first;

      expect(lista.map((g) => g.valor).toList()..sort(), [200, 300]);
    });
  });

  group('RepositorioGastosFake.observarIntervalo', () {
    test('devolve so o que cai dentro da janela', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: gasto('2025-12', 10), quantidadeParcelas: 1);
      await repo.adicionar(base: gasto('2026-01', 20), quantidadeParcelas: 1);
      await repo.adicionar(base: gasto('2026-05', 50), quantidadeParcelas: 1);

      final lista = await repo.observarIntervalo('2026-01', '2026-03').first;

      expect(lista.single.valor, 20);
    });

    test('parcelas entram pelo mes de cada uma, nao pelo da compra', () async {
      final repo = RepositorioGastosFake();
      // 10x a partir de Ago/26: Ago/26 ate Mai/27.
      await repo.adicionar(base: gasto('2026-08', 100), quantidadeParcelas: 10);

      final lista = await repo.observarIntervalo('2026-10', '2026-12').first;

      expect(lista, hasLength(3));
      expect(lista.map((g) => g.mesRef).toList()..sort(),
          ['2026-10', '2026-11', '2026-12']);
    });

    test('janela sem nada devolve lista vazia, nao erro', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: gasto('2026-01', 20), quantidadeParcelas: 1);

      final lista = await repo.observarIntervalo('2027-01', '2027-06').first;

      expect(lista, isEmpty);
    });
  });
}
