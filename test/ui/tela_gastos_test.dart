import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/cartao.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';
import 'package:controle_financeiro/ui/telas/tela_gastos.dart';

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

Gasto simples(String membroId, String poteId, double valor, String desc) =>
    Gasto(
      id: '',
      mesRef: '2026-08',
      membroId: membroId,
      poteId: poteId,
      descricao: desc,
      valor: valor,
      criadoEm: DateTime.utc(2026, 8, 2),
      parcelado: false,
    );

/// Fake cujo observar() emite erro -- simula uma permissao negada no
/// Firestore para o achado 5 (leitura assincrona sem os tres ramos).
class _PotesFakeQueErra implements RepositorioPotes {
  @override
  Stream<List<Pote>> observar() => Stream.error(Exception('sem permissao'));

  @override
  Future<void> salvarTodos(List<Pote> potes) async {}

  @override
  Future<void> remover(String id) async {}
}

/// Fake cujo removerUma sempre falha -- simula o achado 6 (nenhum caminho de
/// escrita tinha tratamento de erro).
class _GastosFakeQueFalhaAoExcluir extends RepositorioGastosFake {
  @override
  Future<void> removerUma(String id) => Future.error(Exception('offline'));
}

Future<(ProviderContainer, RepositorioGastosFake)> montar(
  WidgetTester tester, {
  List<Gasto> simplesIniciais = const [],
  Gasto? parceladoBase,
  int parcelas = 0,
  Size tamanho = const Size(1400, 1200),
  List<Cartao> cartoes = const [],
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = RepositorioGastosFake();
  for (final g in simplesIniciais) {
    await repo.adicionar(base: g, quantidadeParcelas: 1);
  }
  if (parceladoBase != null) {
    await repo.adicionar(base: parceladoBase, quantidadeParcelas: parcelas);
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake(cartoes)),
    repositorioGastosProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: TelaGastos()),
  ));
  await tester.pumpAndSettle();
  return (container, repo);
}

void main() {
  testWidgets('lista os gastos do mes', (tester) async {
    await montar(tester, simplesIniciais: [
      simples('marcos', 'p1', 1200, 'Aluguel'),
      simples('silvia', 'p2', 300, 'Cinema'),
    ]);

    expect(find.text('Aluguel'), findsOneWidget);
    expect(find.text('Cinema'), findsOneWidget);
  });

  testWidgets('mes vazio mostra a mensagem de lista vazia', (tester) async {
    await montar(tester);

    expect(find.textContaining('Nenhum gasto'), findsOneWidget);
  });

  testWidgets('cada gasto mostra o icone do proprio pote no card (mobile)',
      (tester) async {
    await montar(tester, tamanho: const Size(420, 1400), simplesIniciais: [
      simples('marcos', 'p1', 1200, 'Aluguel'),
      simples('silvia', 'p2', 300, 'Cinema'),
    ]);

    // p1 (Custo fixo, icone 'casa') e p2 (Conforto, icone 'sofa'). A
    // FaixaPotes tambem mostra Icons.home/Icons.weekend (em branco); o
    // icone do card usa a cor do pote, entao filtra por cor pra distinguir
    // os dois em vez de contar ocorrencias.
    final iconesCasa = tester.widgetList<Icon>(find.byIcon(Icons.home));
    expect(iconesCasa.where((i) => i.color == const Color(0xFF2E7D32)),
        hasLength(1));

    final iconesSofa = tester.widgetList<Icon>(find.byIcon(Icons.weekend));
    expect(iconesSofa.where((i) => i.color == const Color(0xFF1565C0)),
        hasLength(1));
  });

  testWidgets(
      'card (mobile) mostra pessoa | pote, sem cartao e sem parcela quando nao ha nenhum dos dois',
      (tester) async {
    await montar(tester, tamanho: const Size(420, 1400), simplesIniciais: [
      simples('marcos', 'p1', 1200, 'Aluguel'),
    ]);

    // "Custo fixo" tambem aparece na FaixaPotes (branco, tamanho 11) --
    // filtra pelo estilo do subtitulo do card (nao-branco) pra achar so a
    // ocorrencia certa.
    expect(find.text('Marcos'), findsOneWidget);
    final custoFixoNoCard = tester
        .widgetList<Text>(find.text('Custo fixo'))
        .where((t) => t.style?.color != Colors.white);
    expect(custoFixoNoCard, hasLength(1));
    // Um "|" so: entre pessoa e pote. Sem cartao e sem parcela, nao ha
    // segmento nem separador extra.
    expect(find.text('|'), findsOneWidget);
    expect(find.textContaining('R\$'), findsWidgets); // valor destacado
  });

  testWidgets(
      'card (mobile) mostra pessoa | pote | cartao · parcela quando o gasto tem cartao e e parcelado',
      (tester) async {
    final base = simples('marcos', 'p1', 490, 'Pos Graduacao');
    await montar(
      tester,
      tamanho: const Size(420, 1400),
      cartoes: const [Cartao(id: 'ct1', nome: 'Inter', ordem: 0)],
      parceladoBase: base.copyWith(cartaoId: 'ct1'),
      parcelas: 8,
    );

    expect(find.text('Marcos'), findsOneWidget);
    final custoFixoNoCard = tester
        .widgetList<Text>(find.text('Custo fixo'))
        .where((t) => t.style?.color != Colors.white);
    expect(custoFixoNoCard, hasLength(1));
    expect(find.textContaining('Inter'), findsWidgets);
    expect(find.textContaining('1/8'), findsOneWidget);
    // Dois separadores "|": pessoa/pote e pote/cartao.
    expect(find.text('|'), findsNWidgets(2));
    expect(find.text(formatarReais(490)), findsOneWidget);
  });

  testWidgets('itens parcelados exibem a parcela', (tester) async {
    await montar(
      tester,
      parceladoBase: simples('marcos', 'p2', 100, 'Geladeira'),
      parcelas: 10,
    );

    expect(find.text('1/10'), findsOneWidget);
  });

  testWidgets('filtrar por pessoa esconde os gastos da outra',
      (tester) async {
    final (container, _) = await montar(tester, simplesIniciais: [
      simples('marcos', 'p1', 1200, 'Aluguel'),
      simples('silvia', 'p2', 300, 'Cinema'),
    ]);

    container.read(visaoProvider.notifier).selecionar('marcos');
    await tester.pumpAndSettle();

    expect(find.text('Aluguel'), findsOneWidget);
    expect(find.text('Cinema'), findsNothing);
  });

  testWidgets('filtrar por pote esconde os outros potes', (tester) async {
    final (container, _) = await montar(tester, simplesIniciais: [
      simples('marcos', 'p1', 1200, 'Aluguel'),
      simples('silvia', 'p2', 300, 'Cinema'),
    ]);

    container.read(filtroPoteProvider.notifier).selecionar('p2');
    await tester.pumpAndSettle();

    expect(find.text('Cinema'), findsOneWidget);
    expect(find.text('Aluguel'), findsNothing);
  });

  testWidgets('os dois filtros se somam', (tester) async {
    final (container, _) = await montar(tester, simplesIniciais: [
      simples('marcos', 'p1', 1200, 'Aluguel'),
      simples('marcos', 'p2', 200, 'Sofa'),
      simples('silvia', 'p2', 300, 'Cinema'),
    ]);

    container.read(visaoProvider.notifier).selecionar('marcos');
    container.read(filtroPoteProvider.notifier).selecionar('p2');
    await tester.pumpAndSettle();

    expect(find.text('Sofa'), findsOneWidget);
    expect(find.text('Aluguel'), findsNothing);
    expect(find.text('Cinema'), findsNothing);
  });

  testWidgets('filtro nulo volta a mostrar o casal inteiro', (tester) async {
    final (container, _) = await montar(tester, simplesIniciais: [
      simples('marcos', 'p1', 1200, 'Aluguel'),
      simples('silvia', 'p2', 300, 'Cinema'),
    ]);

    container.read(visaoProvider.notifier).selecionar('marcos');
    await tester.pumpAndSettle();
    container.read(visaoProvider.notifier).selecionar(null);
    await tester.pumpAndSettle();

    expect(find.text('Aluguel'), findsOneWidget);
    expect(find.text('Cinema'), findsOneWidget);
  });

  testWidgets('excluir gasto simples so apaga depois do "Sim"',
      (tester) async {
    final (_, repo) = await montar(tester,
        simplesIniciais: [simples('marcos', 'p1', 1200, 'Aluguel')]);
    expect(repo.todos, hasLength(1));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Excluir gasto'), findsOneWidget);
    expect(repo.todos, hasLength(1)); // o dialogo por si nao apaga

    await tester.tap(find.byKey(const Key('sim_excluir')));
    await tester.pumpAndSettle();

    expect(repo.todos, isEmpty);
  });

  testWidgets('responder "Nao" mantem o gasto simples', (tester) async {
    final (_, repo) = await montar(tester,
        simplesIniciais: [simples('marcos', 'p1', 1200, 'Aluguel')]);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nao_excluir')));
    await tester.pumpAndSettle();

    expect(repo.todos, hasLength(1));
  });

  testWidgets('excluir parcelado abre o dialogo dos tres modos',
      (tester) async {
    final (_, repo) = await montar(
      tester,
      parceladoBase: simples('marcos', 'p2', 100, 'Geladeira'),
      parcelas: 10,
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Todas as parcelas'), findsOneWidget);

    await tester.tap(find.text('Todas as parcelas'));
    await tester.pumpAndSettle();

    expect(repo.todos, isEmpty);
  });

  testWidgets(
      'filtro apontando para pote ou membro que nao existe mais nao '
      'derruba a tela', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = RepositorioGastosFake();
    final container = ProviderContainer(overrides: [
      repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
      repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
      repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
      repositorioGastosProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container
        .read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));
    // Simula a outra pessoa apagando o pote/membro enquanto esta aba
    // estava aberta com o filtro apontado para eles.
    container.read(filtroPoteProvider.notifier).selecionar('pote-fantasma');
    container
        .read(visaoProvider.notifier)
        .selecionar('membro-fantasma');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TelaGastos()),
    ));

    // Sem a correcao, o pump acima lanca "There should be exactly one item
    // with [DropdownButton]'s value" (o assert do Flutter, em debug).
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TelaGastos), findsOneWidget);
  });

  testWidgets('faixa de potes fica desabilitada sem membros cadastrados',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const casaSemMembros = Casa(id: 'principal', nome: 'Casa', membros: []);
    final repo = RepositorioGastosFake();
    final container = ProviderContainer(overrides: [
      repositorioCasaProvider
          .overrideWithValue(RepositorioCasaFake(casaSemMembros)),
      repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
      repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
      repositorioGastosProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container
        .read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TelaGastos()),
    ));
    await tester.pumpAndSettle();

    // Os potes de teste ('Custo fixo', 'Conforto') continuam visiveis, so
    // nao abrem o formulario.
    await tester.tap(find.text('Custo fixo'));
    await tester.pumpAndSettle();

    expect(find.text('Novo gasto'), findsNothing);
  });

  testWidgets(
      'faixa de potes fica desabilitada quando todo mundo foi removido '
      '(achado 1 da revisao final)', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A lista de membros nao esta vazia (tem uma entrada), mas ninguem
    // nela esta ativo -- prova que o gatilho olha pra gente ATIVA, e nao
    // so "a lista tem alguem".
    final soRemovidos = Casa(
      id: 'principal',
      nome: 'Casa',
      membros: [
        Membro(
          id: 'marcos',
          nome: 'Marcos',
          email: 'm@x.com',
          cor: '#2E7D32',
          ordem: 0,
          removidoEm: DateTime.utc(2026, 8, 1),
        ),
      ],
    );

    final repo = RepositorioGastosFake();
    final container = ProviderContainer(overrides: [
      repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(soRemovidos)),
      repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
      repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
      repositorioGastosProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container
        .read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TelaGastos()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custo fixo'));
    await tester.pumpAndSettle();

    expect(find.text('Novo gasto'), findsNothing);
  });

  testWidgets('tocar num pote da faixa abre Novo gasto com aquele pote',
      (tester) async {
    final (_, repo) = await montar(tester);

    await tester.tap(find.text('Conforto'));
    await tester.pumpAndSettle();

    expect(find.text('Novo gasto'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('gasto_descricao')), 'Sofa');
    await tester.enterText(find.byKey(const Key('gasto_valor')), '50000');
    await tester.tap(find.byKey(const Key('gasto_salvar')));
    await tester.pumpAndSettle();

    expect(repo.todos.single.poteId, 'p2');
  });

  testWidgets(
      'erro ao carregar potes mostra aviso de erro em vez de ids crus',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = RepositorioGastosFake();
    await repo.adicionar(
      base: simples('marcos', 'p1', 1200, 'Aluguel'),
      quantidadeParcelas: 1,
    );
    final container = ProviderContainer(
      // Sem isto, o StreamProvider agenda retries automaticos com Timer
      // apos o erro; o teste falharia com "Timer is still pending" no
      // dispose, por um comportamento (retry/backoff) que nao e o foco
      // deste achado.
      retry: (_, _) => null,
      overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
        repositorioPotesProvider.overrideWithValue(_PotesFakeQueErra()),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGastosProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TelaGastos()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nao foi possivel carregar'), findsOneWidget);
    // Sem a correcao, o gasto aparece com o id cru do pote em vez de sumir
    // atras de um estado de erro.
    expect(find.text('p1'), findsNothing);
  });

  testWidgets('erro ao excluir gasto mostra um aviso em vez de nao fazer nada',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _GastosFakeQueFalhaAoExcluir();
    await repo.adicionar(
      base: simples('marcos', 'p1', 1200, 'Aluguel'),
      quantidadeParcelas: 1,
    );
    final container = ProviderContainer(overrides: [
      repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
      repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
      repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
      repositorioGastosProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container
        .read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TelaGastos()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sim_excluir')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repo.todos, hasLength(1)); // nao apagou
    expect(find.byType(SnackBar), findsOneWidget);
  });

  group('a pessoa escolhida vem do mesmo provider do Resumo', () {
    testWidgets('o dropdown Pessoa mostra a visao escolhida em outra tela',
        (tester) async {
      final (container, _) = await montar(tester, simplesIniciais: [
        simples('marcos', 'p1', 1200, 'Aluguel'),
        simples('silvia', 'p2', 300, 'Cinema'),
      ]);

      // E o que o seletor Marcos / Silvia / Casal do Resumo faz.
      container.read(visaoProvider.notifier).selecionar('silvia');
      await tester.pumpAndSettle();

      final campo = find.byKey(const Key('filtro_membro'));
      expect(find.descendant(of: campo, matching: find.text('Silvia')),
          findsOneWidget);
      expect(find.text('Cinema'), findsOneWidget);
      expect(find.text('Aluguel'), findsNothing);
    });

    testWidgets('escolher no dropdown Pessoa vale para o Resumo',
        (tester) async {
      final (container, _) = await montar(tester, simplesIniciais: [
        simples('marcos', 'p1', 1200, 'Aluguel'),
      ]);

      await tester.tap(find.byKey(const Key('filtro_membro')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcos').last);
      await tester.pumpAndSettle();

      expect(container.read(visaoProvider), 'marcos');
    });
  });
}
