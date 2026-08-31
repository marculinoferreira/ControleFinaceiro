import 'dart:async';

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

/// Fake cujo observar() so emite quando `emitir` e chamado -- deixa o teste
/// capturar o estado de loading do potesProvider (achado 5).
class _PotesFakeControlavel implements RepositorioPotes {
  final _controlador = StreamController<List<Pote>>();

  @override
  Stream<List<Pote>> observar() => _controlador.stream;

  @override
  Future<void> salvarTodos(List<Pote> potes) async {}

  @override
  Future<void> remover(String id) async {}

  void emitir(List<Pote> lista) => _controlador.add(lista);

  Future<void> fechar() => _controlador.close();
}

/// Fake cujo adicionar() fica preso ate o teste chamar `liberar` -- sem
/// nenhum Future.delayed, entao nao depende do relogio falso. Usado para
/// os achados 3 (fecha antes de escrever) e 3b (guarda de reentrancia).
class _GastosFakeComEspera extends RepositorioGastosFake {
  int chamadasAdicionar = 0;
  final _pendentes = <Completer<void>>[];

  @override
  Future<void> adicionar({
    required Gasto base,
    required int quantidadeParcelas,
  }) async {
    chamadasAdicionar++;
    final completer = Completer<void>();
    _pendentes.add(completer);
    await completer.future;
    await super.adicionar(base: base, quantidadeParcelas: quantidadeParcelas);
  }

  void liberar() {
    for (final c in _pendentes) {
      if (!c.isCompleted) c.complete();
    }
    _pendentes.clear();
  }
}

/// Fake cujo adicionar() sempre falha -- achado 6.
class _GastosFakeQueFalha extends RepositorioGastosFake {
  @override
  Future<void> adicionar({
    required Gasto base,
    required int quantidadeParcelas,
  }) =>
      Future.error(Exception('offline'));
}

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

/// Monta o formulario ABERTO por `abrirFormularioGasto` (dialogo, na largura
/// de desktop usada aqui), e nao mais direto num Scaffold: desde que o
/// formulario passou a fechar primeiro e escrever depois (mesma ordem de
/// tela_ganhos), quem grava e o chamador que recebe o resultado do pop --
/// so existe se o formulario for aberto pelo fluxo real.
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
      home: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('abrir_formulario'),
              onPressed: () => abrirFormularioGasto(
                context: context,
                ref: ref,
                existente: existente,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('abrir_formulario')));
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

  testWidgets('o preview reage a mudanca no valor depois do switch ligado',
      (tester) async {
    await montar(tester);
    await preencher(tester);
    await tester.tap(find.byKey(const Key('gasto_parcelado')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('gasto_quantidade')), '10');
    await tester.pump();

    // Muda o valor da parcela DEPOIS de ligar o parcelamento: o preview
    // precisa recalcular sem que nada mais force o rebuild.
    await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('gasto_valor')),
          matching: find.byType(TextFormField),
        ),
        '20000');
    await tester.pump();

    final preview = tester
        .widget<Text>(find.descendant(
          of: find.byKey(const Key('gasto_preview')),
          matching: find.byType(Text),
        ))
        .data!;

    expect(preview, contains(formatarReais(200)));
    expect(preview, contains(formatarReais(2000)));
    expect(preview, isNot(contains(formatarReais(1000))));
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

  testWidgets(
      'editar uma parcela de compra parcelada preserva compraId, parcela e '
      'totalParcelas', (tester) async {
    final repo = RepositorioGastosFake();
    await repo.adicionar(
      base: Gasto(
        id: '',
        mesRef: '2026-08',
        membroId: 'marcos',
        poteId: 'p1',
        descricao: 'Geladeira',
        valor: 100,
        criadoEm: DateTime.utc(2026, 8, 2),
        parcelado: false, // gerarParcelas ignora este campo com quantidade>1
      ),
      quantidadeParcelas: 10,
    );
    final original = repo.todos.firstWhere((g) => g.parcela == 3);

    await montar(tester, existente: original, comRepo: repo);

    await tester.enterText(
        find.byKey(const Key('gasto_descricao')), 'Geladeira nova');
    await tester.tap(find.byKey(const Key('gasto_salvar')));
    await tester.pumpAndSettle();

    // A descricao descreve a compra: vai para as 10 sem perguntar nada.
    expect(find.text('Alterar o valor'), findsNothing);
    expect(repo.todos.every((g) => g.descricao == 'Geladeira nova'), isTrue);

    expect(repo.todos, hasLength(10)); // nenhuma parcela criada ou apagada
    final editado = repo.todos.firstWhere((g) => g.id == original.id);
    expect(editado.descricao, 'Geladeira nova');
    expect(editado.id, original.id);
    expect(editado.mesRef, original.mesRef);
    expect(editado.compraId, original.compraId);
    expect(editado.compraId, isNotNull);
    expect(editado.parcela, original.parcela);
    expect(editado.totalParcelas, original.totalParcelas);
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

  testWidgets(
      'achado 2 — editar um gasto cujo pote foi apagado nao derruba a tela',
      (tester) async {
    final gastoComPoteOrfao = Gasto(
      id: 'g1',
      mesRef: '2026-08',
      membroId: 'marcos',
      poteId: 'pote-fantasma',
      descricao: 'Conta antiga',
      valor: 50,
      criadoEm: DateTime.utc(2026, 8, 2),
      parcelado: false,
    );

    // Sem a correcao, montar isto lanca o assert do DropdownButtonFormField
    // de "gasto_pote" durante o pump.
    await montar(tester, existente: gastoComPoteOrfao);

    expect(tester.takeException(), isNull);
    // A tela nao trava com o pote orfao: reseta para um pote valido (o
    // primeiro da lista) em vez de manter o id que nao existe mais.
    expect(
      find.descendant(
        of: find.byKey(const Key('gasto_pote')),
        matching: find.text('Custo fixo'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'achado 4 — sem membros cadastrados, o validador de "De quem" '
      'bloqueia o salvar', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const casaSemMembros = Casa(id: 'principal', nome: 'Casa', membros: []);
    final repo = RepositorioGastosFake();
    final container = ProviderContainer(overrides: [
      repositorioCasaProvider
          .overrideWithValue(RepositorioCasaFake(casaSemMembros)),
      repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
      repositorioGastosProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container
        .read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));
    container.listen(potesProvider, (_, _) {});
    container.listen(casaProvider, (_, _) {});

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: FormularioGasto()),
      ),
    ));
    await tester.pumpAndSettle();

    await preencher(tester, descricao: 'Teste sem membro');
    await tester.tap(find.byKey(const Key('gasto_salvar')));
    await tester.pumpAndSettle();

    expect(repo.todos, isEmpty);
    expect(find.text('Selecione quem gastou.'), findsOneWidget);
  });

  testWidgets(
      'achado 5 — enquanto potes carrega, nao mostra o formulario nem o '
      'validador de pote indevidamente', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final potesFake = _PotesFakeControlavel();
    addTearDown(potesFake.fechar);
    final repo = RepositorioGastosFake();
    final container = ProviderContainer(overrides: [
      repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
      repositorioPotesProvider.overrideWithValue(potesFake),
      repositorioGastosProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container
        .read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));
    container.listen(casaProvider, (_, _) {});
    // De proposito NAO aquecemos potesProvider aqui: queremos capturar o
    // estado de loading antes de qualquer emissao.

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: FormularioGasto()),
      ),
    ));
    await tester.pump();

    // Sem a correcao (`.value ?? []`), o dropdown de pote e o validador
    // "Cadastre um pote antes." apareceriam mesmo com os potes ainda
    // carregando.
    expect(find.byKey(const Key('gasto_pote')), findsNothing);
    expect(find.textContaining('Cadastre um pote antes'), findsNothing);

    potesFake.emitir(potes);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gasto_pote')), findsOneWidget);
  });

  testWidgets(
      'achado 3 — fecha o formulario antes da escrita completar (nao trava '
      'offline)', (tester) async {
    final repo = _GastosFakeComEspera();
    await montar(tester, comRepo: repo);
    await preencher(tester);

    await tester.tap(find.byKey(const Key('gasto_salvar')));
    // pumpAndSettle so se importa com frames/animacoes pendentes, nao com
    // Futures soltos -- ele assenta a transicao de fechamento do dialogo
    // mesmo com a escrita ainda presa no Completer.
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gasto_descricao')), findsNothing);
    expect(repo.todos, isEmpty); // a escrita ainda nao completou

    repo.liberar();
    await tester.pumpAndSettle();

    expect(repo.todos, hasLength(1));
  });

  testWidgets('achado 3b — dois toques rapidos no salvar gravam uma vez so',
      (tester) async {
    final repo = _GastosFakeComEspera();
    await montar(tester, comRepo: repo);
    await preencher(tester);

    // Chama onPressed direto duas vezes em sequencia, em vez de dois
    // tester.tap(): o primeiro pop() ja torna o botao inalcancavel por
    // hit-test antes de qualquer pump (o dialogo comeca a fechar), entao um
    // segundo tap "de verdade" nao reproduziria o toque duplo. Chamando o
    // mesmo callback que um toque real dispararia, reentramos em _salvar()
    // exatamente como dois toques quase simultaneos fariam.
    final botao =
        tester.widget<FilledButton>(find.byKey(const Key('gasto_salvar')));
    botao.onPressed?.call();
    botao.onPressed?.call();

    // O pop() resolve a Future de mostrarFormulario via microtask: um pump
    // deixa abrirFormularioGasto retomar e chamar repo.adicionar (que entao
    // registra o Completer que liberar() completa).
    await tester.pump();
    repo.liberar();
    await tester.pumpAndSettle();

    expect(repo.chamadasAdicionar, 1);
    expect(repo.todos, hasLength(1));
    // Sem a guarda, o segundo Navigator.pop() nao e um no-op inofensivo:
    // ele fecha a TELA POR TRAS do formulario tambem (o classico bug do
    // "duplo pop"), deixando a tela que abriu o formulario inacessivel.
    expect(find.byKey(const Key('abrir_formulario')), findsOneWidget);
  });

  testWidgets('achado 6 — erro ao salvar gasto mostra um aviso',
      (tester) async {
    final repo = _GastosFakeQueFalha();
    await montar(tester, comRepo: repo);
    await preencher(tester);

    await tester.tap(find.byKey(const Key('gasto_salvar')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
