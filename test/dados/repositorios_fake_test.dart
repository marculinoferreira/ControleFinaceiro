import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';

Gasto base({String mesRef = '2026-08'}) => Gasto(
      id: '',
      mesRef: mesRef,
      membroId: 'marcos',
      poteId: 'p2',
      descricao: 'Geladeira',
      valor: 100,
      criadoEm: DateTime.utc(2026, 8, 5),
      parcelado: false,
    );

void main() {
  group('RepositorioGastosFake', () {
    test('adicionar com 1 parcela grava um gasto simples', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 1);

      final gastos = await repo.observarMes('2026-08').first;
      expect(gastos, hasLength(1));
      expect(gastos.single.parcelado, isFalse);
    });

    test('adicionar com 10 parcelas grava uma em cada mes', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 10);

      expect(await repo.observarMes('2026-08').first, hasLength(1));
      expect(await repo.observarMes('2027-05').first, hasLength(1));
      expect(await repo.observarMes('2027-06').first, isEmpty);
    });

    test('todas as parcelas recebem ids distintos e o mesmo compraId',
        () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 10);

      final todos = repo.todos;
      expect(todos.map((g) => g.id).toSet(), hasLength(10));
      expect(todos.map((g) => g.compraId).toSet(), hasLength(1));
      expect(todos.first.compraId, isNotNull);
    });

    test('removerUma apaga so aquela parcela', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 10);
      final alvo = repo.todos.firstWhere((g) => g.parcela == 3);

      await repo.removerUma(alvo.id);

      expect(repo.todos, hasLength(9));
      expect(repo.todos.any((g) => g.parcela == 3), isFalse);
      expect(repo.todos.any((g) => g.parcela == 4), isTrue);
    });

    test('removerDesta apaga a parcela e as futuras', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 10);
      final compraId = repo.todos.first.compraId!;

      await repo.removerDesta(compraId, 4);

      expect(repo.todos, hasLength(3));
      expect(repo.todos.map((g) => g.parcela).toList(), [1, 2, 3]);
    });

    test('removerCompra apaga a compra inteira', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 10);
      final compraId = repo.todos.first.compraId!;

      await repo.removerCompra(compraId);

      expect(repo.todos, isEmpty);
    });

    test('observarParceladosDesde traz so parcelas do mes em diante', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 10);
      await repo.adicionar(base: base(), quantidadeParcelas: 1); // simples

      final abertas = await repo.observarParceladosDesde('2026-10').first;

      expect(abertas, hasLength(8)); // parcelas 3..10
      expect(abertas.every((g) => g.parcelado), isTrue);
    });

    test('o stream reemite depois de cada escrita', () async {
      final repo = RepositorioGastosFake();
      final emissoes = <int>[];
      final assinatura =
          repo.observarMes('2026-08').listen((l) => emissoes.add(l.length));

      await repo.adicionar(base: base(), quantidadeParcelas: 1);
      await repo.adicionar(base: base(), quantidadeParcelas: 1);
      await Future<void>.delayed(Duration.zero);
      await assinatura.cancel();

      expect(emissoes.last, 2);
    });
  });

  // Os quatro fakes compartilham a mesma mecanica de stream. O teste acima
  // cobre gastos; estes travam o mesmo contrato nos outros tres, onde o
  // gerador async* original perdia escritas em silencio.
  group('demais fakes reemitem depois de escrever', () {
    test('ganhos', () async {
      final repo = RepositorioGanhosFake();
      final emissoes = <int>[];
      final assinatura =
          repo.observarMes('2026-08').listen((l) => emissoes.add(l.length));

      await repo.adicionar(Ganho(
        id: '',
        mesRef: '2026-08',
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 4000,
        criadoEm: DateTime.utc(2026, 8, 1),
      ));
      await repo.adicionar(Ganho(
        id: '',
        mesRef: '2026-08',
        membroId: 'silvia',
        descricao: 'Salario',
        valor: 3000,
        criadoEm: DateTime.utc(2026, 8, 1),
      ));
      await Future<void>.delayed(Duration.zero);
      await assinatura.cancel();

      expect(emissoes.last, 2);
    });

    test('potes', () async {
      final repo = RepositorioPotesFake();
      final emissoes = <int>[];
      final assinatura = repo.observar().listen((l) => emissoes.add(l.length));

      await repo.salvarTodos([
        const Pote(
            id: 'p1',
            nome: 'Essencial',
            percentual: 60,
            ordem: 0,
            cor: '#4CAF50',
            icone: 'casa'),
        const Pote(
            id: 'p2',
            nome: 'Livre',
            percentual: 40,
            ordem: 1,
            cor: '#2196F3',
            icone: 'estrela'),
      ]);
      await Future<void>.delayed(Duration.zero);
      await assinatura.cancel();

      expect(emissoes.first, 0);
      expect(emissoes.last, 2);
    });

    test('casa', () async {
      final repo = RepositorioCasaFake();
      final emissoes = <Casa?>[];
      final assinatura = repo.observar().listen(emissoes.add);

      await repo.criar(const Casa(
        id: 'casa1',
        nome: 'Nossa casa',
        membros: [],
      ));
      await Future<void>.delayed(Duration.zero);
      await assinatura.cancel();

      expect(emissoes.first, isNull);
      expect(emissoes.last?.nome, 'Nossa casa');
    });
  });
}
