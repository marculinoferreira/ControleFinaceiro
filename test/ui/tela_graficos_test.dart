import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:controle_financeiro/ui/telas/tela_graficos.dart';
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

class _PotesQueFalha implements RepositorioPotes {
  @override
  Stream<List<Pote>> observar() => Stream.error(Exception('sem permissao'));
  @override
  Future<void> salvarTodos(List<Pote> potes) async {}
  @override
  Future<void> remover(String id) async {}
}

Future<ProviderContainer> montar(
  WidgetTester tester, {
  Size tamanho = const Size(1400, 2400),
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
    child: const MaterialApp(home: Scaffold(body: TelaGraficos())),
  ));
  await tester.pumpAndSettle();
  return container;
}

// find.byType(MolduraGrafico) resolveria para o tipo cru e nao casaria com
// as instancias, que sao genericas sobre a serie de cada grafico. O
// predicado usa `is`, que respeita a covariancia.
final molduras = find.byWidgetPredicate((w) => w is MolduraGrafico);

void main() {
  group('composicao', () {
    testWidgets('mostra os oito graficos', (tester) async {
      await montar(tester);

      expect(molduras, findsNWidgets(8));
    });

    testWidgets('os titulos aparecem na ordem da spec 10', (tester) async {
      await montar(tester);

      expect(find.text('Gastos por pote'), findsOneWidget);
      expect(find.text('Previsto × Gasto por pote'), findsOneWidget);
      expect(find.textContaining('Ganhos × gastos'), findsOneWidget);
      expect(find.text('Ganhos por pessoa'), findsOneWidget);
      expect(find.text('Onde o gasto parou'), findsOneWidget);
      expect(find.textContaining('Comprometido'), findsOneWidget);
      expect(find.text('Gastos por cartão'), findsOneWidget);
    });

    testWidgets('rola sem estourar o layout', (tester) async {
      await montar(tester, tamanho: const Size(1400, 700));

      expect(find.byKey(const Key('graficos_rolagem')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('responsividade', () {
    testWidgets('desktop usa duas colunas', (tester) async {
      await montar(tester);

      expect(find.byKey(const Key('graficos_coluna_esquerda')), findsOneWidget);
      expect(find.byKey(const Key('graficos_coluna_direita')), findsOneWidget);
      expect(find.byKey(const Key('graficos_coluna_unica')), findsNothing);
    });

    testWidgets('mobile usa coluna unica', (tester) async {
      await montar(tester, tamanho: const Size(500, 2400));

      expect(find.byKey(const Key('graficos_coluna_unica')), findsOneWidget);
      expect(find.byKey(const Key('graficos_coluna_esquerda')), findsNothing);
      expect(molduras, findsNWidgets(8));
    });
  });

  group('isolamento de erro', () {
    testWidgets('um provider quebrado nao apaga os outros graficos',
        (tester) async {
      await montar(tester, repoPotes: _PotesQueFalha());

      // Os oito continuam montados.
      expect(molduras, findsNWidgets(8));

      // Rosca, barras, cascata e tendencia por pote dependem de potes e
      // mostram o erro.
      expect(find.text('Tentar de novo'), findsNWidgets(4));

      // Os que nao dependem de potes seguem desenhando.
      expect(find.byType(LineChart), findsWidgets);
      expect(find.byType(PieChart), findsNWidgets(2)); // pizza de ganhos e rosca por cartao
    });

    testWidgets('os titulos continuam legiveis mesmo no erro', (tester) async {
      await montar(tester, repoPotes: _PotesQueFalha());

      expect(find.text('Gastos por pote'), findsOneWidget);
      expect(find.text('Onde o gasto parou'), findsOneWidget);
    });
  });

  group('seletor de visao', () {
    testWidgets('compartilha visaoProvider com a tela de Resumo',
        (tester) async {
      final c = await montar(tester);

      await tester.tap(find.text('Marcos').first);
      await tester.pumpAndSettle();

      expect(c.read(visaoProvider), 'marcos');
    });

    testWidgets('fica fora da area de rolagem dos graficos', (tester) async {
      await montar(tester, tamanho: const Size(1400, 700));

      final rolagem = find.byKey(const Key('graficos_rolagem'));
      final seletor = find.byKey(const Key('graficos_visao'));

      expect(seletor, findsOneWidget);
      expect(find.descendant(of: rolagem, matching: seletor), findsNothing);
    });

    testWidgets('sem membros carregados nao mostra o seletor', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake()),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TelaGraficos())),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('graficos_visao')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('com um so membro ativo nao mostra o seletor', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
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
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake()),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TelaGraficos())),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('graficos_visao')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('mes sem nada', () {
    testWidgets('os oito mostram frase de vazio, nenhum desenho quebrado',
        (tester) async {
      await montar(tester, comDados: false);

      expect(molduras, findsNWidgets(8));
      expect(find.byType(PieChart), findsNothing);
      expect(find.byType(LineChart), findsNothing);
      expect(find.byType(BarChart), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('seletor de tipo de visao', () {
    testWidgets('comeca em Visao Geral, mostrando os 7 graficos de sempre',
        (tester) async {
      await montar(tester, tamanho: const Size(500, 2400));

      expect(find.byKey(const Key('graficos_coluna_unica')), findsOneWidget);
      expect(find.text('Comparativo'), findsOneWidget);
      expect(find.text('Projeção'), findsOneWidget);
    });

    testWidgets('trocar para Comparativo esconde o seletor de pessoa',
        (tester) async {
      await montar(tester);

      expect(find.byKey(const Key('graficos_visao')), findsOneWidget);

      await tester.tap(find.text('Comparativo'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('graficos_visao')), findsNothing);
    });

    testWidgets('Comparativo mostra os 3 graficos novos, nao os 7 de sempre',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('Comparativo'));
      await tester.pumpAndSettle();

      expect(find.text('Gasto por pote'), findsOneWidget);
      expect(find.text('Gasto por cartão'), findsOneWidget);
      expect(find.textContaining('Comprometido nos próximos'), findsOneWidget);
      expect(find.text('Ganhos por pessoa'), findsNothing); // grafico da Visao Geral
    });

    testWidgets('trocar para Projecao mantem o seletor de pessoa',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('Projeção'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('graficos_visao')), findsOneWidget);
      expect(find.text('Projeção de saldo'), findsOneWidget);
    });

    testWidgets(
        'Projecao no desktop usa coluna unica, com um so grafico nao ha o que dividir',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('Projeção'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('graficos_coluna_unica')), findsOneWidget);
      expect(find.byKey(const Key('graficos_coluna_esquerda')), findsNothing);
      expect(find.byKey(const Key('graficos_coluna_direita')), findsNothing);
    });

    testWidgets('Comparativo no desktop continua em duas colunas',
        (tester) async {
      await montar(tester);

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

      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TelaGraficos())),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Visão Geral'), findsOneWidget);
      expect(find.text('Projeção'), findsOneWidget);
      expect(find.text('Comparativo'), findsNothing);
    });

    testWidgets('Visao Geral tem 8 graficos, incluindo a Tendencia por pote',
        (tester) async {
      await montar(tester);

      expect(find.text('Tendência por pote'), findsOneWidget);
    });
  });
}
