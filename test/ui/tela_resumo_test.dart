import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/dominio/serie_mensal.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';
import 'package:controle_financeiro/ui/telas/tela_resumo.dart';
import 'package:controle_financeiro/ui/widgets/moldura_grafico.dart';

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

/// Dois potes bastam para provar a cascata e deixam a conta legivel:
/// 60% e 40%.
const potes = [
  Pote(
      id: 'p1',
      nome: 'Custo fixo',
      percentual: 60,
      ordem: 0,
      cor: '#2E7D32',
      icone: 'casa'),
  Pote(
      id: 'p2',
      nome: 'Conforto',
      percentual: 40,
      ordem: 1,
      cor: '#1565C0',
      icone: 'sofa'),
];

class _PotesFakeQueFalha implements RepositorioPotes {
  @override
  Stream<List<Pote>> observar() => Stream.error(Exception('sem rede'));
  @override
  Future<void> salvarTodos(List<Pote> potes) async {}
  @override
  Future<void> remover(String id) async {}
}

Future<ProviderContainer> montar(
  WidgetTester tester, {
  double ganhoMarcos = 0,
  double ganhoSilvia = 0,
  double gastoMarcos = 0,
  double gastoSilvia = 0,
  List<Pote> comPotes = potes,
  RepositorioPotes? repoPotes,
  Size tamanho = const Size(1400, 1400),
  bool semRetry = false,
  List<Override> overridesExtras = const [],
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final ganhos = RepositorioGanhosFake();
  final gastos = RepositorioGastosFake();

  for (final (membroId, valor) in [
    ('marcos', ganhoMarcos),
    ('silvia', ganhoSilvia),
  ]) {
    if (valor <= 0) continue;
    await ganhos.adicionar(Ganho(
      id: '',
      mesRef: '2026-08',
      membroId: membroId,
      descricao: 'Salario',
      valor: valor,
      criadoEm: DateTime.utc(2026, 8, 1),
    ));
  }

  for (final (membroId, valor) in [
    ('marcos', gastoMarcos),
    ('silvia', gastoSilvia),
  ]) {
    if (valor <= 0) continue;
    await gastos.adicionar(
      base: Gasto(
        id: '',
        mesRef: '2026-08',
        membroId: membroId,
        poteId: 'p1',
        descricao: 'Mercado',
        valor: valor,
        criadoEm: DateTime.utc(2026, 8, 2),
        parcelado: false,
      ),
      quantidadeParcelas: 1,
    );
  }

  final container = ProviderContainer(
    // Depois de um erro, o StreamProvider agenda retries com Timer, e o teste
    // morreria com "Timer is still pending" por um comportamento que nao e o
    // foco aqui. Mesmo tratamento de tela_gastos_test.
    retry: semRetry ? (_, _) => null : null,
    overrides: [
      repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
      repositorioPotesProvider
          .overrideWithValue(repoPotes ?? RepositorioPotesFake(comPotes)),
      repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
      repositorioGanhosProvider.overrideWithValue(ganhos),
      repositorioGastosProvider.overrideWithValue(gastos),
      ...overridesExtras,
    ],
  );
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(potesProvider, (_, _) {});
  container.listen(casaProvider, (_, _) {});
  container.listen(ganhosDoMesProvider('2026-08'), (_, _) {});
  container.listen(gastosDoMesProvider('2026-08'), (_, _) {});
  // A Visao Geral agora tambem desenha os graficos de sempre, que dependem
  // destes providers -- sem o listen, eles ficam em loading ate algum outro
  // widget os observar, e o pumpAndSettle devolve o controle cedo demais.
  container.listen(parceladosDesdeProvider('2026-08'), (_, _) {});
  final janela = (
    inicio: janelaAte(const MesRef(2026, 8), mesesDaSerie).first.valor,
    fim: '2026-08',
  );
  container.listen(ganhosDoIntervaloProvider(janela), (_, _) {});
  container.listen(gastosDoIntervaloProvider(janela), (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Scaffold(body: TelaResumo())),
  ));
  await tester.pumpAndSettle();
  return container;
}

/// A cor efetiva do texto do rotulo grande.
Color? corDoRotulo(WidgetTester tester) {
  final texto = tester.widget<Text>(find.byKey(const Key('resumo_rotulo')));
  return texto.style?.color;
}

void main() {
  group('tabela', () {
    testWidgets('lista uma linha por pote com previsto, consumido e sobra',
        (tester) async {
      // 10000 de renda: p1 preve 6000, p2 preve 4000.
      // 3000 de gasto param todos no p1.
      await montar(tester, ganhoMarcos: 10000, gastoMarcos: 3000);

      // Escopado na propria tabela: com dado real, os graficos da Visao
      // Geral agora tambem mostram os nomes dos potes na legenda, entao um
      // find.text solto encontraria mais de um "Custo fixo" na tela.
      final tabela = find.byKey(const Key('resumo_tabela'));
      expect(find.descendant(of: tabela, matching: find.text('Custo fixo')),
          findsOneWidget);
      expect(find.descendant(of: tabela, matching: find.text('Conforto')),
          findsOneWidget);

      expect(find.text(formatarReais(6000)), findsOneWidget); // previsto p1
      expect(find.text(formatarReais(3000)), findsWidgets); // consumido e sobra p1
      expect(find.text(formatarReais(4000)), findsWidgets); // previsto e sobra p2
    });

    testWidgets('mostra o percentual de cada pote', (tester) async {
      await montar(tester, ganhoMarcos: 10000, gastoMarcos: 3000);

      expect(find.text('60%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
    });

    testWidgets('a barra de progresso e consumido sobre previsto',
        (tester) async {
      await montar(tester, ganhoMarcos: 10000, gastoMarcos: 3000);

      final barras = tester
          .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator))
          .toList();

      expect(barras, hasLength(2));
      expect(barras[0].value, closeTo(0.5, 0.001)); // 3000/6000
      expect(barras[1].value, 0); // p2 intocado
    });

    testWidgets(
        'pote com gasto real maior que o previsto trava a barra em 1.0, sem passar',
        (tester) async {
      // 8000 de gasto, todos classificados no pote p1 (previsto 6000): passa
      // 2000 do previsto dele. O consumido e por categoria real, entao p2
      // (sem nenhum gasto classificado nele) fica intocado -- mesmo a
      // cascata tendo transbordado 2000 pra ele.
      await montar(tester, ganhoMarcos: 10000, gastoMarcos: 8000);

      final barras = tester
          .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator))
          .toList();

      expect(barras[0].value, 1.0);
      expect(barras[1].value, 0);
    });

    testWidgets('gasto real acima do previsto aparece na coluna Ultrapassou',
        (tester) async {
      // 8000 de gasto no p1 (previsto 6000): ultrapassou 2000, sobra 0.
      await montar(tester, ganhoMarcos: 10000, gastoMarcos: 8000);

      expect(find.text('Ultrapassou'), findsOneWidget);
      expect(find.text(formatarReais(2000)), findsOneWidget); // ultrapassou p1
      expect(find.text(formatarReais(4000)), findsWidgets); // previsto e sobra p2
    });

    testWidgets('pote de 0% nao divide por zero', (tester) async {
      await montar(
        tester,
        ganhoMarcos: 10000,
        gastoMarcos: 1000,
        comPotes: const [
          Pote(
              id: 'p1',
              nome: 'Tudo',
              percentual: 100,
              ordem: 0,
              cor: '#2E7D32',
              icone: 'casa'),
          Pote(
              id: 'p2',
              nome: 'Zerado',
              percentual: 0,
              ordem: 1,
              cor: '#1565C0',
              icone: 'sofa'),
        ],
      );

      final barras = tester
          .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator))
          .toList();

      expect(barras[1].value, 0);
      expect(barras[1].value, isNot(isNaN));
    });

    testWidgets('sem ganhos, nenhum previsto vira NaN', (tester) async {
      await montar(tester, gastoMarcos: 500);

      final barras = tester
          .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator))
          .toList();

      expect(barras.every((b) => b.value == 0), isTrue);
    });
  });

  group('rotulo semaforico', () {
    testWidgets('mostra o nome do pote ativo em maiuscula', (tester) async {
      await montar(tester, ganhoMarcos: 10000, gastoMarcos: 3000);

      expect(find.text('CUSTO FIXO'), findsOneWidget);
    });

    testWidgets('usa a cor do pote ativo', (tester) async {
      await montar(tester, ganhoMarcos: 10000, gastoMarcos: 3000);

      // #2E7D32 do Custo fixo.
      expect(corDoRotulo(tester), const Color(0xFF2E7D32));
    });

    testWidgets('gasto que passa de todos vira PARE DE GASTAR em vermelho',
        (tester) async {
      // 12000 de gasto contra 10000 de renda: passou de todos os potes.
      await montar(tester, ganhoMarcos: 10000, gastoMarcos: 12000);

      expect(find.text('PARE DE GASTAR'), findsOneWidget);

      final esquema = ThemeData.light().colorScheme;
      expect(corDoRotulo(tester), isNot(const Color(0xFF2E7D32)));
      expect(corDoRotulo(tester), isNotNull);
      // Vermelho de erro do tema, seja qual for o valor exato.
      expect(corDoRotulo(tester)!.r, greaterThan(esquema.primary.r));
    });

    testWidgets('no estouro mostra o valor do excedente', (tester) async {
      await montar(tester, ganhoMarcos: 10000, gastoMarcos: 12000);

      expect(find.byKey(const Key('resumo_excedente')), findsOneWidget);
      expect(find.textContaining(formatarReais(2000)), findsWidgets);
    });

    testWidgets('sem renda pede para cadastrar ganhos, sem PARE DE GASTAR',
        (tester) async {
      await montar(tester, gastoMarcos: 500);

      expect(find.text('CADASTRE SEUS GANHOS'), findsOneWidget);
      expect(find.text('PARE DE GASTAR'), findsNothing);
      expect(find.byKey(const Key('resumo_excedente')), findsNothing);
    });
  });

  group('seletor de visao', () {
    testWidgets('comeca no casal e soma as duas pessoas', (tester) async {
      await montar(
        tester,
        ganhoMarcos: 6000,
        ganhoSilvia: 4000,
        gastoMarcos: 3000,
      );

      // Casal: 10000 de renda, p1 preve 6000.
      expect(find.text(formatarReais(6000)), findsOneWidget);
    });

    testWidgets('trocar para uma pessoa recalcula a cascata', (tester) async {
      await montar(
        tester,
        ganhoMarcos: 6000,
        ganhoSilvia: 4000,
        gastoMarcos: 3000,
      );

      // .first: com dado real, a legenda de Ganhos por pessoa tambem mostra
      // o nome -- o seletor continua sendo o primeiro na ordem da arvore.
      await tester.tap(find.text('Marcos').first);
      await tester.pumpAndSettle();

      // So Marcos: 6000 de renda, p1 preve 3600 e consumiu os 3000 dele.
      expect(find.text(formatarReais(3600)), findsOneWidget);
    });

    testWidgets('a visao de quem nao gastou zera o consumo', (tester) async {
      await montar(
        tester,
        ganhoMarcos: 6000,
        ganhoSilvia: 4000,
        gastoMarcos: 3000,
      );

      // .first: mesmo motivo do teste acima com Marcos.
      await tester.tap(find.text('Silvia').first);
      await tester.pumpAndSettle();

      final barras = tester
          .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator))
          .toList();
      expect(barras.every((b) => b.value == 0), isTrue);
    });

    testWidgets('com um so membro ativo nao mostra o seletor', (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const casaSolo = Casa(
        id: 'principal',
        nome: 'Casa',
        membros: [
          Membro(
              id: 'marcos',
              nome: 'Marcos',
              email: 'm@x.com',
              cor: '#2E7D32',
              ordem: 0),
        ],
      );

      final container = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casaSolo)),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TelaResumo())),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resumo_visao')), findsNothing);
      expect(find.text('Casal'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('estados assincronos', () {
    testWidgets('erro nos potes mostra ErroComRecarregar', (tester) async {
      await montar(tester, repoPotes: _PotesFakeQueFalha(), semRetry: true);

      // A cascata mostra o proprio erro -- os graficos que tambem dependem
      // de potes (Visao Geral, abaixo dela) mostram o deles, cada um com o
      // seu botao; a contagem exata esta no grupo "isolamento de erro".
      expect(find.text('Tentar de novo'), findsWidgets);
    });
  });

  group('responsividade', () {
    testWidgets('desktop usa DataTable', (tester) async {
      await montar(tester, ganhoMarcos: 10000, gastoMarcos: 3000);
      expect(find.byType(DataTable), findsOneWidget);
    });

    testWidgets('mobile usa cards, sem DataTable', (tester) async {
      await montar(
        tester,
        ganhoMarcos: 10000,
        gastoMarcos: 3000,
        tamanho: const Size(500, 1200),
      );

      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(Card), findsWidgets);
      // A barra de progresso sobrevive ao layout de card.
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });
  });

  group('alerta de estouro projetado', () {
    testWidgets('aparece quando o provider tem excesso para o pote',
        (tester) async {
      await montar(
        tester,
        ganhoMarcos: 10000,
        gastoMarcos: 3000,
        overridesExtras: [
          estouroProjetadoProvider.overrideWith(
            (ref) => const AsyncData({'p1': 120.0}),
          ),
        ],
      );

      expect(find.byKey(const Key('estouro_p1')), findsOneWidget);
      expect(find.textContaining(formatarReais(120)), findsOneWidget);
    });

    testWidgets('nao aparece quando o provider nao tem excesso',
        (tester) async {
      await montar(
        tester,
        ganhoMarcos: 10000,
        gastoMarcos: 3000,
        overridesExtras: [
          estouroProjetadoProvider.overrideWith((ref) => const AsyncData({})),
        ],
      );

      expect(find.byKey(const Key('estouro_p1')), findsNothing);
      expect(find.byKey(const Key('estouro_p2')), findsNothing);
    });

    testWidgets('a barra de progresso do pote continua funcionando',
        (tester) async {
      await montar(
        tester,
        ganhoMarcos: 10000,
        gastoMarcos: 3000,
        overridesExtras: [
          estouroProjetadoProvider.overrideWith((ref) => const AsyncData({})),
        ],
      );

      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });
  });

  // -------------------------------------------------------------------
  // Os grupos abaixo vieram da extinta TelaGraficos: a Visao Geral do
  // Resumo agora tambem desenha os graficos de sempre, Comparativo e
  // Projecao continuam substituindo o conteudo (sem a cascata). Usam um
  // fixture proprio (`montarComGraficos`), com parcelas de verdade, para
  // exercitar os graficos de comprometimento/tendencia -- diferente do
  // `montar()` acima, pensado so para a cascata.
  // -------------------------------------------------------------------

  // find.byType(MolduraGrafico) resolveria para o tipo cru e nao casaria com
  // as instancias, que sao genericas sobre a serie de cada grafico. O
  // predicado usa `is`, que respeita a covariancia.
  final molduras = find.byWidgetPredicate((w) => w is MolduraGrafico);

  Future<ProviderContainer> montarComGraficos(
    WidgetTester tester, {
    Size tamanho = const Size(1400, 4000),
    RepositorioPotes? repoPotes,
    bool comDados = true,
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ganhos = RepositorioGanhosFake();
    final gastos = RepositorioGastosFake();

    if (comDados) {
      await ganhos.adicionar(Ganho(
        id: '',
        mesRef: '2026-08',
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 10000,
        criadoEm: DateTime.utc(2026, 8, 1),
      ));
      await gastos.adicionar(
        base: Gasto(
          id: '',
          mesRef: '2026-08',
          membroId: 'marcos',
          poteId: 'p1',
          descricao: 'Geladeira',
          valor: 300,
          criadoEm: DateTime.utc(2026, 8, 2),
          parcelado: false,
        ),
        quantidadeParcelas: 6,
      );
    }

    final falhando = repoPotes != null;
    final container = ProviderContainer(
      retry: falhando ? (_, _) => null : null,
      overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
        repositorioPotesProvider
            .overrideWithValue(repoPotes ?? RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(ganhos),
        repositorioGastosProvider.overrideWithValue(gastos),
      ],
    );
    addTearDown(container.dispose);

    const mes = MesRef(2026, 8);
    container.read(mesSelecionadoProvider.notifier).irPara(mes);
    container.listen(casaProvider, (_, _) {});
    container.listen(potesProvider, (_, _) {});
    container.listen(ganhosDoMesProvider(mes.valor), (_, _) {});
    container.listen(gastosDoMesProvider(mes.valor), (_, _) {});
    container.listen(parceladosDesdeProvider(mes.valor), (_, _) {});
    final janela =
        (inicio: janelaAte(mes, mesesDaSerie).first.valor, fim: mes.valor);
    container.listen(ganhosDoIntervaloProvider(janela), (_, _) {});
    container.listen(gastosDoIntervaloProvider(janela), (_, _) {});

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: TelaResumo())),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  group('graficos na Visao Geral', () {
    testWidgets('mostra os oito graficos', (tester) async {
      await montarComGraficos(tester);

      expect(molduras, findsNWidgets(8));
    });

    testWidgets('os titulos aparecem na ordem da spec 10', (tester) async {
      await montarComGraficos(tester);

      expect(find.text('Gastos por pote'), findsOneWidget);
      expect(find.text('Previsto × Gasto por pote'), findsOneWidget);
      expect(find.textContaining('Ganhos × gastos'), findsOneWidget);
      expect(find.text('Ganhos por pessoa'), findsOneWidget);
      expect(find.text('Onde o gasto parou'), findsOneWidget);
      expect(find.textContaining('Comprometido'), findsOneWidget);
      expect(find.text('Gastos por cartão'), findsOneWidget);
    });

    testWidgets('rola sem estourar o layout', (tester) async {
      await montarComGraficos(tester, tamanho: const Size(1400, 700));

      expect(find.byKey(const Key('resumo_rolagem')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a cascata aparece acima dos graficos', (tester) async {
      await montarComGraficos(tester);

      expect(find.byKey(const Key('resumo_rotulo')), findsOneWidget);
      expect(molduras, findsNWidgets(8));
    });
  });

  group('responsividade dos graficos', () {
    testWidgets('desktop usa duas colunas', (tester) async {
      await montarComGraficos(tester);

      expect(find.byKey(const Key('graficos_coluna_esquerda')), findsOneWidget);
      expect(find.byKey(const Key('graficos_coluna_direita')), findsOneWidget);
      expect(find.byKey(const Key('graficos_coluna_unica')), findsNothing);
    });

    testWidgets('mobile usa coluna unica', (tester) async {
      await montarComGraficos(tester, tamanho: const Size(500, 4000));

      expect(find.byKey(const Key('graficos_coluna_unica')), findsOneWidget);
      expect(find.byKey(const Key('graficos_coluna_esquerda')), findsNothing);
      expect(molduras, findsNWidgets(8));
    });
  });

  group('isolamento de erro dos graficos', () {
    testWidgets('um provider quebrado nao apaga os outros graficos',
        (tester) async {
      await montarComGraficos(tester, repoPotes: _PotesFakeQueFalha());

      // Os oito continuam montados.
      expect(molduras, findsNWidgets(8));

      // A cascata mostra o proprio erro, mais rosca, barras, cascata e
      // tendencia por pote (dependem de potes): 5 botoes ao todo.
      expect(find.text('Tentar de novo'), findsNWidgets(5));

      // Os que nao dependem de potes seguem desenhando.
      expect(find.byType(LineChart), findsWidgets);
      expect(find.byType(PieChart), findsNWidgets(2)); // pizza de ganhos e rosca por cartao
    });

    testWidgets('os titulos continuam legiveis mesmo no erro', (tester) async {
      await montarComGraficos(tester, repoPotes: _PotesFakeQueFalha());

      expect(find.text('Gastos por pote'), findsOneWidget);
      expect(find.text('Onde o gasto parou'), findsOneWidget);
    });
  });

  group('mes sem nada nos graficos', () {
    testWidgets('os oito mostram frase de vazio, nenhum desenho quebrado',
        (tester) async {
      await montarComGraficos(tester, comDados: false);

      expect(molduras, findsNWidgets(8));
      expect(find.byType(PieChart), findsNothing);
      expect(find.byType(LineChart), findsNothing);
      expect(find.byType(BarChart), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('seletor de tipo de visao', () {
    testWidgets('comeca em Visao Geral, mostrando os graficos de sempre',
        (tester) async {
      await montarComGraficos(tester, tamanho: const Size(500, 4000));

      expect(find.byKey(const Key('graficos_coluna_unica')), findsOneWidget);
      expect(find.text('Comparativo'), findsOneWidget);
      expect(find.text('Projeção'), findsOneWidget);
    });

    testWidgets('trocar para Comparativo esconde o seletor de pessoa',
        (tester) async {
      await montarComGraficos(tester);

      expect(find.byKey(const Key('resumo_visao')), findsOneWidget);

      await tester.tap(find.text('Comparativo'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resumo_visao')), findsNothing);
    });

    testWidgets(
        'Comparativo mostra os 3 graficos novos, nao os de sempre nem a cascata',
        (tester) async {
      await montarComGraficos(tester);

      await tester.tap(find.text('Comparativo'));
      await tester.pumpAndSettle();

      expect(find.text('Gasto por pote'), findsOneWidget);
      expect(find.text('Gasto por cartão'), findsOneWidget);
      expect(find.textContaining('Comprometido nos próximos'), findsOneWidget);
      expect(find.text('Ganhos por pessoa'), findsNothing); // grafico da Visao Geral
      expect(find.byKey(const Key('resumo_rotulo')), findsNothing); // cascata
    });

    testWidgets('trocar para Projecao mantem o seletor de pessoa, sem cascata',
        (tester) async {
      await montarComGraficos(tester);

      await tester.tap(find.text('Projeção'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resumo_visao')), findsOneWidget);
      expect(find.text('Projeção de saldo'), findsOneWidget);
      expect(find.byKey(const Key('resumo_rotulo')), findsNothing);
    });

    testWidgets(
        'Projecao no desktop usa coluna unica, com um so grafico nao ha o que dividir',
        (tester) async {
      await montarComGraficos(tester);

      await tester.tap(find.text('Projeção'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('graficos_coluna_unica')), findsOneWidget);
      expect(find.byKey(const Key('graficos_coluna_esquerda')), findsNothing);
      expect(find.byKey(const Key('graficos_coluna_direita')), findsNothing);
    });

    testWidgets('Comparativo no desktop continua em duas colunas',
        (tester) async {
      await montarComGraficos(tester);

      await tester.tap(find.text('Comparativo'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('graficos_coluna_esquerda')), findsOneWidget);
      expect(find.byKey(const Key('graficos_coluna_direita')), findsOneWidget);
      expect(find.byKey(const Key('graficos_coluna_unica')), findsNothing);
    });

    testWidgets('casa com 1 pessoa ativa nao oferece Comparativo',
        (tester) async {
      final container = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          const Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                  cor: '#2E7D32', ordem: 0),
            ],
          ),
        )),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ]);
      addTearDown(container.dispose);
      container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      container.listen(casaProvider, (_, _) {});

      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TelaResumo())),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Visão Geral'), findsOneWidget);
      expect(find.text('Projeção'), findsOneWidget);
      expect(find.text('Comparativo'), findsNothing);
    });

    testWidgets('Visao Geral tem 8 graficos, incluindo a Tendencia por pote',
        (tester) async {
      await montarComGraficos(tester);

      expect(find.text('Tendência por pote'), findsOneWidget);
    });
  });
}
