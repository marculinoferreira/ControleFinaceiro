import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/ui/widgets/dialogo_exclusao.dart';

Gasto parcela(int n) => Gasto(
      id: 'g$n',
      mesRef: '2026-08',
      membroId: 'marcos',
      poteId: 'p2',
      descricao: 'Geladeira',
      valor: 100,
      criadoEm: DateTime.utc(2026, 8, 1),
      parcelado: true,
      compraId: 'c1',
      parcela: n,
      totalParcelas: 10,
    );

Widget montar(List<ModoExclusao?> capturado) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              capturado.add(await perguntarModoExclusao(
                context: context,
                gasto: parcela(3),
              ));
            },
            child: const Text('Excluir'),
          ),
        ),
      ),
    );

/// Prepara um repositorio com uma compra de 10 parcelas ja gravada.
Future<RepositorioGastosFake> comCompra() async {
  final repo = RepositorioGastosFake();
  await repo.adicionar(
    base: Gasto(
      id: '',
      mesRef: '2026-08',
      membroId: 'marcos',
      poteId: 'p2',
      descricao: 'Geladeira',
      valor: 100,
      criadoEm: DateTime.utc(2026, 8, 1),
      parcelado: false,
    ),
    quantidadeParcelas: 10,
  );
  return repo;
}

void main() {
  group('perguntarModoExclusao', () {
    testWidgets('mostra os tres modos e identifica a parcela', (tester) async {
      await tester.pumpWidget(montar([]));
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('3/10'), findsOneWidget);
      expect(find.text('Só esta parcela'), findsOneWidget);
      expect(find.text('Esta e as futuras'), findsOneWidget);
      expect(find.text('Todas as parcelas'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('escolher "so esta" devolve somenteEsta', (tester) async {
      final c = <ModoExclusao?>[];
      await tester.pumpWidget(montar(c));
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Só esta parcela'));
      await tester.pumpAndSettle();

      expect(c, [ModoExclusao.somenteEsta]);
    });

    testWidgets('escolher "esta e as futuras" devolve estaEFuturas',
        (tester) async {
      final c = <ModoExclusao?>[];
      await tester.pumpWidget(montar(c));
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Esta e as futuras'));
      await tester.pumpAndSettle();

      expect(c, [ModoExclusao.estaEFuturas]);
    });

    testWidgets('escolher "todas" devolve todas', (tester) async {
      final c = <ModoExclusao?>[];
      await tester.pumpWidget(montar(c));
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas as parcelas'));
      await tester.pumpAndSettle();

      expect(c, [ModoExclusao.todas]);
    });

    testWidgets('cancelar devolve null', (tester) async {
      final c = <ModoExclusao?>[];
      await tester.pumpWidget(montar(c));
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(c, [null]);
    });
  });

  group('aplicarExclusao', () {
    test('somenteEsta apaga uma parcela e nao renumera as outras', () async {
      final repo = await comCompra();
      final alvo = repo.todos.firstWhere((g) => g.parcela == 3);

      await aplicarExclusao(
          repo: repo, gasto: alvo, modo: ModoExclusao.somenteEsta);

      expect(repo.todos, hasLength(9));
      expect(repo.todos.any((g) => g.parcela == 3), isFalse);
      // O historico da compra nao muda: quem sobrou continua "n/10".
      expect(repo.todos.every((g) => g.totalParcelas == 10), isTrue);
      expect(repo.todos.firstWhere((g) => g.parcela == 4).rotuloParcela,
          '4/10');
    });

    test('estaEFuturas apaga da parcela em diante', () async {
      final repo = await comCompra();
      final alvo = repo.todos.firstWhere((g) => g.parcela == 4);

      await aplicarExclusao(
          repo: repo, gasto: alvo, modo: ModoExclusao.estaEFuturas);

      expect(repo.todos.map((g) => g.parcela).toList(), [1, 2, 3]);
    });

    test('todas apaga a compra inteira', () async {
      final repo = await comCompra();
      final alvo = repo.todos.first;

      await aplicarExclusao(repo: repo, gasto: alvo, modo: ModoExclusao.todas);

      expect(repo.todos, isEmpty);
    });

    test('gasto simples cai em removerUma qualquer que seja o modo', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(
        base: Gasto(
          id: '',
          mesRef: '2026-08',
          membroId: 'marcos',
          poteId: 'p1',
          descricao: 'Mercado',
          valor: 300,
          criadoEm: DateTime.utc(2026, 8, 2),
          parcelado: false,
        ),
        quantidadeParcelas: 1,
      );

      await aplicarExclusao(
          repo: repo, gasto: repo.todos.single, modo: ModoExclusao.todas);

      expect(repo.todos, isEmpty);
    });
  });
}
