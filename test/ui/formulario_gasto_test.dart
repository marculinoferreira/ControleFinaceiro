import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/telas/formulario_gasto.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';

const casa = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
    Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
        cor: '#2E7D32', ordem: 0),
    Membro(id: 'silvia', nome: 'Silvia', email: 's@x.com',
        cor: '#6A1B9A', ordem: 1),
  ],
);

const potes = [
  Pote(id: 'p1', nome: 'Custo fixo', percentual: 60, ordem: 0,
      cor: '#2E7D32', icone: 'casa'),
  Pote(id: 'p2', nome: 'Conforto', percentual: 40, ordem: 1,
      cor: '#1565C0', icone: 'sofa'),
];

/// Monta o formulario isolado, num Scaffold, com os fakes injetados.
Future<RepositorioGastosFake> montar(
  WidgetTester tester, {
  Gasto? existente,
  RepositorioGastosFake? comRepo,
}) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = comRepo ?? RepositorioGastosFake();
  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioGastosProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(potesProvider, (_, _) {});
  container.listen(casaProvider, (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: FormularioGasto(existente: existente)),
    ),
  ));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> preencher(WidgetTester tester,
    {String descricao = 'Geladeira', String centavos = '10000'}) async {
  await tester.enterText(find.byKey(const Key('gasto_descricao')), descricao);
  await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('gasto_valor')),
        matching: find.byType(TextFormField),
      ),
      centavos);
  await tester.pump();
}

void main() {
  testWidgets('sem parcelamento grava um unico documento', (tester) async {
    final repo = await montar(tester);
    await preencher(tester);

    await tester.tap(find.byKey(const Key('gasto_salvar')));
    await tester.pumpAndSettle();

    expect(repo.todos, hasLength(1));
    expect(repo.todos.single.parcelado, isFalse);
    expect(repo.todos.single.valor, 100.0);
    expect(repo.todos.single.mesRef, '2026-08');
    expect(repo.todos.single.membroId, 'marcos');
    expect(repo.todos.single.poteId, 'p1');
  });

  testWidgets('o switch revela quantidade e preview', (tester) async {
    await montar(tester);
    await preencher(tester);

    expect(find.byKey(const Key('gasto_quantidade')), findsNothing);

    await tester.tap(find.byKey(const Key('gasto_parcelado')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gasto_quantidade')), findsOneWidget);
    expect(find.byKey(const Key('gasto_preview')), findsOneWidget);
  });

  testWidgets('o preview mostra parcela, total e intervalo de meses',
      (tester) async {
    await montar(tester);
    await preencher(tester);
    await tester.tap(find.byKey(const Key('gasto_parcelado')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('gasto_quantidade')), '10');
    await tester.pump();

    final preview = tester
        .widget<Text>(find.descendant(
          of: find.byKey(const Key('gasto_preview')),
          matching: find.byType(Text),
        ))
        .data!;

    expect(preview, contains('10x'));
    expect(preview, contains(formatarReais(100)));
    expect(preview, contains(formatarReais(1000)));
    expect(preview, contains('Ago/26'));
    expect(preview, contains('Mai/27'));
  });

  testWidgets('parcelado grava um documento por mes com o mesmo compraId',
      (tester) async {
    final repo = await montar(tester);
    await preencher(tester);
    await tester.tap(find.byKey(const Key('gasto_parcelado')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('gasto_quantidade')), '10');
    await tester.pump();

    await tester.tap(find.byKey(const Key('gasto_salvar')));
    await tester.pumpAndSettle();

    expect(repo.todos, hasLength(10));
    expect(repo.todos.map((g) => g.compraId).toSet(), hasLength(1));
    expect(repo.todos.map((g) => g.mesRef).toSet(), contains('2027-05'));
    expect(repo.todos.every((g) => g.valor == 100), isTrue);
  });

  testWidgets('descricao vazia nao grava', (tester) async {
    final repo = await montar(tester);
    await preencher(tester, descricao: '');

    await tester.tap(find.byKey(const Key('gasto_salvar')));
    await tester.pumpAndSettle();

    expect(repo.todos, isEmpty);
    expect(find.text('Informe a descrição.'), findsOneWidget);
  });

  testWidgets('valor zero nao grava', (tester) async {
    final repo = await montar(tester);
    await preencher(tester, centavos: '0');

    await tester.tap(find.byKey(const Key('gasto_salvar')));
    await tester.pumpAndSettle();

    expect(repo.todos, isEmpty);
  });

  testWidgets('parcelado com quantidade 1 e recusado', (tester) async {
    final repo = await montar(tester);
    await preencher(tester);
    await tester.tap(find.byKey(const Key('gasto_parcelado')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('gasto_quantidade')), '1');
    await tester.pump();

    await tester.tap(find.byKey(const Key('gasto_salvar')));
    await tester.pumpAndSettle();

    expect(repo.todos, isEmpty);
    expect(find.textContaining('pelo menos 2'), findsOneWidget);
  });

  testWidgets('editar altera o documento existente e nao cria outro',
      (tester) async {
    // Semeia o repositorio ANTES de montar, e injeta o mesmo repositorio na
    // tela: so assim o teste observa a edicao de um documento que existe.
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
    final original = repo.todos.single;

    await montar(tester, existente: original, comRepo: repo);

    await tester.enterText(
        find.byKey(const Key('gasto_descricao')), 'Mercado grande');
    await tester.tap(find.byKey(const Key('gasto_salvar')));
    await tester.pumpAndSettle();

    expect(repo.todos, hasLength(1)); // editou, nao criou outro
    expect(repo.todos.single.id, original.id);
    expect(repo.todos.single.descricao, 'Mercado grande');
    expect(repo.todos.single.valor, 300); // valor intocado
  });

  testWidgets('editar nao deixa ligar o parcelamento', (tester) async {
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

    await montar(tester, existente: repo.todos.single, comRepo: repo);

    final switchTile = tester.widget<SwitchListTile>(
        find.byKey(const Key('gasto_parcelado')));
    expect(switchTile.onChanged, isNull);
  });
}
