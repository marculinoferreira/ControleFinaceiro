import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/telas/tela_ganhos.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';

const casa = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
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
  ],
);

Ganho ganho(String id, String membroId, double valor) => Ganho(
      id: id,
      mesRef: '2026-08',
      membroId: membroId,
      descricao: 'Salario',
      valor: valor,
      criadoEm: DateTime.utc(2026, 8, 1),
    );

Future<void> comLargura(WidgetTester tester, double largura) async {
  tester.view.physicalSize = Size(largura, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Monta a tela com repositorios fake e o mes fixado em agosto/2026, para
/// que o teste nao dependa da data em que roda.
Future<RepositorioGanhosFake> montar(
  WidgetTester tester, {
  List<Ganho> iniciais = const [],
}) async {
  final repo = RepositorioGanhosFake();
  for (final g in iniciais) {
    await repo.adicionar(g);
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioGanhosProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: TelaGanhos()),
  ));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('mostra uma coluna por membro', (tester) async {
    await comLargura(tester, 1400);
    await montar(tester);

    expect(find.byKey(const Key('coluna_marcos')), findsOneWidget);
    expect(find.byKey(const Key('coluna_silvia')), findsOneWidget);
    expect(find.text('Marcos'), findsOneWidget);
    expect(find.text('Silvia'), findsOneWidget);
  });

  testWidgets('lista os ganhos de cada pessoa na coluna certa',
      (tester) async {
    await comLargura(tester, 1400);
    await montar(tester, iniciais: [
      ganho('', 'marcos', 4000),
      ganho('', 'silvia', 3000),
    ]);

    expect(
      find.descendant(
        of: find.byKey(const Key('coluna_marcos')),
        matching: find.text(formatarReais(4000)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('coluna_silvia')),
        matching: find.text(formatarReais(3000)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('o subtotal de cada coluna soma so aquela pessoa',
      (tester) async {
    await comLargura(tester, 1400);
    await montar(tester, iniciais: [
      ganho('', 'marcos', 4000),
      ganho('', 'marcos', 500),
      ganho('', 'silvia', 3000),
    ]);

    expect(
      find.descendant(
        of: find.byKey(const Key('subtotal_marcos')),
        matching: find.text(formatarReais(4500)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('subtotal_silvia')),
        matching: find.text(formatarReais(3000)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('o total geral soma o casal', (tester) async {
    await comLargura(tester, 1400);
    await montar(tester, iniciais: [
      ganho('', 'marcos', 4500),
      ganho('', 'silvia', 3000),
    ]);

    expect(
      find.descendant(
        of: find.byKey(const Key('total_geral_ganhos')),
        matching: find.text(formatarReais(7500)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pessoa sem lancamento mostra subtotal zero, nao erro',
      (tester) async {
    await comLargura(tester, 1400);
    await montar(tester, iniciais: [ganho('', 'marcos', 4000)]);

    expect(
      find.descendant(
        of: find.byKey(const Key('subtotal_silvia')),
        matching: find.text(formatarReais(0)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('adicionar grava com o membro e o mes corretos', (tester) async {
    await comLargura(tester, 1400);
    final repo = await montar(tester);

    await tester.tap(find.byKey(const Key('novo_ganho')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('form_descricao')), 'Freela');
    await tester.enterText(find.byType(TextFormField).last, '120000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('form_salvar')));
    await tester.pumpAndSettle();

    expect(repo.todos, hasLength(1));
    expect(repo.todos.single.descricao, 'Freela');
    expect(repo.todos.single.valor, 1200.0);
    expect(repo.todos.single.mesRef, '2026-08');
    expect(repo.todos.single.membroId, 'marcos'); // primeiro membro, padrao
  });

  testWidgets('salvar sem descricao nao grava', (tester) async {
    await comLargura(tester, 1400);
    final repo = await montar(tester);

    await tester.tap(find.byKey(const Key('novo_ganho')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '5000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('form_salvar')));
    await tester.pumpAndSettle();

    expect(repo.todos, isEmpty);
    expect(find.text('Informe a descrição.'), findsOneWidget);
  });

  testWidgets('excluir remove o lancamento', (tester) async {
    await comLargura(tester, 1400);
    final repo = await montar(tester, iniciais: [ganho('', 'marcos', 4000)]);
    expect(repo.todos, hasLength(1));

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(repo.todos, isEmpty);
  });

  testWidgets('tocar numa linha abre o formulario preenchido para edicao',
      (tester) async {
    await comLargura(tester, 1400);
    final repo = await montar(tester, iniciais: [ganho('', 'marcos', 4000)]);
    final id = repo.todos.single.id;

    await tester.tap(find.byKey(Key('ganho_$id')));
    await tester.pumpAndSettle();

    expect(find.text('Salario'), findsWidgets);

    await tester.enterText(find.byKey(const Key('form_descricao')), 'Bonus');
    await tester.tap(find.byKey(const Key('form_salvar')));
    await tester.pumpAndSettle();

    expect(repo.todos, hasLength(1)); // editou, nao criou outro
    expect(repo.todos.single.descricao, 'Bonus');
    expect(repo.todos.single.id, id);
  });

  testWidgets('mobile empilha as secoes em vez de usar colunas',
      (tester) async {
    await comLargura(tester, 420);
    await montar(tester);

    // A chave so existe no ramo mobile; sua presenca e a prova do layout.
    expect(find.byKey(const Key('secoes_empilhadas')), findsOneWidget);
    expect(find.byKey(const Key('coluna_marcos')), findsOneWidget);
    expect(find.byKey(const Key('coluna_silvia')), findsOneWidget);
  });

  testWidgets('desktop nao usa o empilhamento do mobile', (tester) async {
    await comLargura(tester, 1400);
    await montar(tester);

    expect(find.byKey(const Key('secoes_empilhadas')), findsNothing);
  });
}
