import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/telas/tela_potes.dart';

const tresPotes = [
  Pote(id: 'p1', nome: 'Custo fixo', percentual: 55, ordem: 0,
      cor: '#2E7D32', icone: 'casa'),
  Pote(id: 'p2', nome: 'Conforto', percentual: 30, ordem: 1,
      cor: '#1565C0', icone: 'sofa'),
  Pote(id: 'p3', nome: 'Prazer', percentual: 15, ordem: 2,
      cor: '#AD1457', icone: 'presente'),
];

Future<RepositorioPotesFake> montar(
  WidgetTester tester, {
  List<Pote> iniciais = tresPotes,
}) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = RepositorioPotesFake(iniciais);
  await tester.pumpWidget(ProviderScope(
    overrides: [repositorioPotesProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: TelaPotes()),
  ));
  await tester.pumpAndSettle();
  return repo;
}

ReorderableListView lista(WidgetTester tester) =>
    tester.widget<ReorderableListView>(find.byType(ReorderableListView));

void main() {
  group('rotuloSoma', () {
    test('exatamente 100 fecha', () {
      expect(rotuloSoma(100), '100%');
      expect(somaFechada(100), isTrue);
    });

    test('dentro da tolerancia de centavo ainda fecha', () {
      expect(somaFechada(100.004), isTrue);
      expect(somaFechada(99.996), isTrue);
    });

    test('abaixo de 100 diz quanto falta', () {
      expect(rotuloSoma(97), contains('faltam'));
      expect(rotuloSoma(97), contains('3%'));
      expect(somaFechada(97), isFalse);
    });

    test('acima de 100 diz quanto sobra', () {
      expect(rotuloSoma(103), contains('a mais'));
      expect(rotuloSoma(103), contains('3%'));
      expect(somaFechada(103), isFalse);
    });
  });

  testWidgets('lista os potes na ordem gravada', (tester) async {
    await montar(tester);

    expect(find.text('Custo fixo'), findsOneWidget);
    expect(find.text('Conforto'), findsOneWidget);
    expect(find.text('Prazer'), findsOneWidget);
    expect(lista(tester).itemCount, 3);
  });

  testWidgets('a soma inicial aparece no indicador', (tester) async {
    await montar(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('soma_potes')),
        matching: find.text('100%'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('salvar esta habilitado quando a soma fecha', (tester) async {
    await montar(tester);

    final botao =
        tester.widget<FilledButton>(find.byKey(const Key('salvar_potes')));
    expect(botao.onPressed, isNotNull);
  });

  testWidgets('mudar um percentual quebra os 100% e desabilita o salvar',
      (tester) async {
    await montar(tester);

    await tester.enterText(find.byKey(const Key('percentual_0')), '40');
    await tester.pump();

    final botao =
        tester.widget<FilledButton>(find.byKey(const Key('salvar_potes')));
    expect(botao.onPressed, isNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('soma_potes')),
        matching: find.textContaining('faltam'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reordenar e salvar grava a nova ordem', (tester) async {
    final repo = await montar(tester);

    // Move o terceiro pote (Prazer) para o topo.
    lista(tester).onReorder(2, 0);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('salvar_potes')));
    await tester.pumpAndSettle();

    expect(repo.todos.map((p) => p.nome).toList(),
        ['Prazer', 'Custo fixo', 'Conforto']);
    expect(repo.todos.map((p) => p.ordem).toList(), [0, 1, 2]);
  });

  testWidgets('salvar mantem a soma em 100 e nao altera percentuais',
      (tester) async {
    final repo = await montar(tester);

    await tester.tap(find.byKey(const Key('salvar_potes')));
    await tester.pumpAndSettle();

    expect(repo.todos.fold<double>(0, (a, p) => a + p.percentual), 100);
  });

  testWidgets('nao passa de 6 potes', (tester) async {
    await montar(tester, iniciais: const [
      Pote(id: 'a', nome: 'A', percentual: 50, ordem: 0,
          cor: '#2E7D32', icone: 'casa'),
      Pote(id: 'b', nome: 'B', percentual: 10, ordem: 1,
          cor: '#1565C0', icone: 'casa'),
      Pote(id: 'c', nome: 'C', percentual: 10, ordem: 2,
          cor: '#00838F', icone: 'casa'),
      Pote(id: 'd', nome: 'D', percentual: 10, ordem: 3,
          cor: '#EF6C00', icone: 'casa'),
      Pote(id: 'e', nome: 'E', percentual: 10, ordem: 4,
          cor: '#AD1457', icone: 'casa'),
      Pote(id: 'f', nome: 'F', percentual: 10, ordem: 5,
          cor: '#4527A0', icone: 'casa'),
    ]);

    final botao = tester
        .widget<OutlinedButton>(find.byKey(const Key('adicionar_pote')));
    expect(botao.onPressed, isNull);
    expect(lista(tester).itemCount, maximoPotes);
  });

  testWidgets('adicionar cria um pote a mais com 0%', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('adicionar_pote')));
    await tester.pumpAndSettle();

    expect(lista(tester).itemCount, 4);
    // Soma continua 100 porque o novo entra com zero.
    expect(
      find.descendant(
        of: find.byKey(const Key('soma_potes')),
        matching: find.text('100%'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('remover tira o pote da lista e muda a soma', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('remover_2')));
    await tester.pumpAndSettle();

    expect(lista(tester).itemCount, 2);
    final botao =
        tester.widget<FilledButton>(find.byKey(const Key('salvar_potes')));
    expect(botao.onPressed, isNull); // 85%, nao fecha
  });
}
