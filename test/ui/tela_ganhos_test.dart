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

/// Fake cujas escritas falham enquanto `falhar` for true -- achado 6
/// (nenhum caminho de escrita tinha tratamento de erro). Comeca em true;
/// desligue para semear dados antes de montar a tela.
class _GanhosFakeQueFalha extends RepositorioGanhosFake {
  bool falhar = true;

  @override
  Future<void> adicionar(Ganho ganho) =>
      falhar ? Future.error(Exception('offline')) : super.adicionar(ganho);

  @override
  Future<void> remover(String id) =>
      falhar ? Future.error(Exception('offline')) : super.remover(id);
}

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
  Casa comCasa = casa,
}) async {
  final repo = RepositorioGanhosFake();
  for (final g in iniciais) {
    await repo.adicionar(g);
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(comCasa)),
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

  testWidgets('excluir so remove o lancamento depois do "Sim"',
      (tester) async {
    await comLargura(tester, 1400);
    final repo = await montar(tester, iniciais: [ganho('', 'marcos', 4000)]);
    expect(repo.todos, hasLength(1));

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Excluir ganho'), findsOneWidget);
    expect(repo.todos, hasLength(1)); // o dialogo por si nao apaga

    await tester.tap(find.byKey(const Key('sim_excluir')));
    await tester.pumpAndSettle();

    expect(repo.todos, isEmpty);
  });

  testWidgets('no mobile a exclusao tambem pede confirmacao', (tester) async {
    // 700 fica abaixo do breakpoint (layout empilhado) sem estourar a linha
    // do total: a fonte de teste desenha cada glifo como um quadrado cheio.
    await comLargura(tester, 700);
    final repo = await montar(tester, iniciais: [ganho('', 'marcos', 4000)]);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Excluir ganho'), findsOneWidget);
    expect(repo.todos, hasLength(1));

    await tester.tap(find.byKey(const Key('sim_excluir')));
    await tester.pumpAndSettle();

    expect(repo.todos, isEmpty);
  });

  testWidgets('responder "Nao" mantem o ganho', (tester) async {
    await comLargura(tester, 1400);
    final repo = await montar(tester, iniciais: [ganho('', 'marcos', 4000)]);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nao_excluir')));
    await tester.pumpAndSettle();

    expect(repo.todos, hasLength(1));
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

  testWidgets(
      'achado 6 — erro ao adicionar ganho mostra um aviso em vez de nao '
      'fazer nada', (tester) async {
    await comLargura(tester, 1400);
    final repo = _GanhosFakeQueFalha();
    final container = ProviderContainer(overrides: [
      repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
      repositorioGanhosProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container
        .read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TelaGanhos()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('novo_ganho')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('form_descricao')), 'Freela');
    await tester.enterText(find.byType(TextFormField).last, '120000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('form_salvar')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets(
      'achado 6 — erro ao excluir ganho mostra um aviso em vez de nao '
      'fazer nada', (tester) async {
    await comLargura(tester, 1400);
    final repo = _GanhosFakeQueFalha()..falhar = false;
    await repo.adicionar(ganho('', 'marcos', 4000));
    repo.falhar = true;
    final container = ProviderContainer(overrides: [
      repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
      repositorioGanhosProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container
        .read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TelaGanhos()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sim_excluir')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repo.todos, hasLength(1)); // nao apagou
    expect(find.byType(SnackBar), findsOneWidget);
  });

  group('membro removido (achado 1 da revisao final)', () {
    final casaComSilviaRemovida = Casa(
      id: 'principal',
      nome: 'Casa',
      membros: [
        casa.membros[0],
        Membro(
          id: 'silvia',
          nome: 'Silvia',
          email: 's@x.com',
          cor: '#6A1B9A',
          ordem: 1,
          removidoEm: DateTime.utc(2026, 8, 1),
        ),
      ],
    );

    testWidgets('a coluna de quem foi removido continua mostrando o historico',
        (tester) async {
      await comLargura(tester, 1400);
      await montar(
        tester,
        comCasa: casaComSilviaRemovida,
        iniciais: [ganho('', 'silvia', 3000)],
      );

      expect(find.byKey(const Key('coluna_silvia')), findsOneWidget);
      expect(find.text('Silvia'), findsOneWidget);
    });

    testWidgets('"Novo ganho" nao oferece quem foi removido no seletor',
        (tester) async {
      await comLargura(tester, 1400);
      await montar(tester, comCasa: casaComSilviaRemovida);

      await tester.tap(find.byKey(const Key('novo_ganho')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('form_membro')));
      await tester.pumpAndSettle();

      // Restrito ao AlertDialog do formulario: a coluna "Silvia" continua
      // no fundo da tela (rotulagem do historico), entao um find.text solto
      // pegaria os dois.
      final dentroDoDialogo = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Silvia'),
      );
      expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('Marcos')),
        findsWidgets,
      );
      expect(dentroDoDialogo, findsNothing);
    });

    testWidgets(
        'editar um ganho de quem esta ativo nao oferece quem foi removido',
        (tester) async {
      // A coluna de quem edita (Marcos, ativo) nao tem relacao com Silvia
      // (removida): o dropdown de edicao precisa vir da lista de ativos, nao
      // da lista completa de membros da casa.
      await comLargura(tester, 1400);
      final repo = await montar(
        tester,
        comCasa: casaComSilviaRemovida,
        iniciais: [ganho('', 'marcos', 4000)],
      );
      final id = repo.todos.single.id;

      await tester.tap(find.byKey(Key('ganho_$id')));
      await tester.pumpAndSettle();

      // Antes de abrir o dropdown, a unica ocorrencia de "Silvia" na tela
      // vem do rotulo historico da coluna dela, no fundo (por baixo do
      // dialogo) -- nao do formulario. O menu do dropdown e inserido no
      // Overlay raiz (fora da subarvore do AlertDialog), entao restringir a
      // busca a `find.descendant(of: find.byType(AlertDialog), ...)` nao
      // pegaria um item de menu mesmo que ele existisse -- por isso o teste
      // compara a contagem total de "Silvia" antes e depois de abrir o
      // dropdown, em vez de restringir o escopo da busca.
      final ocorrenciasAntes = find.text('Silvia').evaluate().length;
      expect(ocorrenciasAntes, 1);

      await tester.tap(find.byKey(const Key('form_membro')));
      await tester.pumpAndSettle();

      // Sem a correcao, abrir o dropdown de edicao oferece Silvia (removida)
      // como opcao extra, mesmo o ganho sendo do Marcos (ativo) -- uma
      // segunda ocorrencia de "Silvia" aparece no menu. Com a correcao, o
      // dropdown vem de membrosAtivos e a contagem nao muda.
      final ocorrenciasDepois = find.text('Silvia').evaluate().length;
      expect(ocorrenciasDepois, ocorrenciasAntes);
    });

    testWidgets(
        'editar um ganho de quem foi removido continua funcionando, sem '
        'reatribuir a pessoa sozinho', (tester) async {
      await comLargura(tester, 1400);
      final repo = await montar(
        tester,
        comCasa: casaComSilviaRemovida,
        iniciais: [ganho('', 'silvia', 3000)],
      );
      final id = repo.todos.single.id;

      await tester.tap(find.byKey(Key('ganho_$id')));
      await tester.pumpAndSettle();

      // Nao derruba o assert do DropdownButtonFormField so por abrir a
      // edicao de um lancamento de quem ja saiu.
      expect(tester.takeException(), isNull);

      // Salvar sem mexer no seletor mantem o ganho com a Silvia removida --
      // abrir a edicao nao pode reatribuir sozinho.
      await tester.tap(find.byKey(const Key('form_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.single.membroId, 'silvia');
    });
  });
}
