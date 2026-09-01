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
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/widgets/graficos/barra_cascata.dart';
import 'package:controle_financeiro/ui/widgets/graficos/pizza_ganhos.dart';
import 'package:controle_financeiro/ui/widgets/legenda_grafico.dart';

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

Future<ProviderContainer> montar(
  WidgetTester tester,
  Widget grafico, {
  double ganhoMarcos = 0,
  double ganhoSilvia = 0,
  double gasto = 0,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
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

  if (gasto > 0) {
    await gastos.adicionar(
      base: Gasto(
        id: '',
        mesRef: '2026-08',
        membroId: 'marcos',
        poteId: 'p1',
        descricao: 'Compra',
        valor: gasto,
        criadoEm: DateTime.utc(2026, 8, 2),
        parcelado: false,
      ),
      quantidadeParcelas: 1,
    );
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
    repositorioGanhosProvider.overrideWithValue(ganhos),
    repositorioGastosProvider.overrideWithValue(gastos),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(potesProvider, (_, _) {});
  container.listen(casaProvider, (_, _) {});
  container.listen(ganhosDoMesProvider('2026-08'), (_, _) {});
  container.listen(gastosDoMesProvider('2026-08'), (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: grafico)),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

List<PieChartSectionData> secoes(WidgetTester tester) =>
    tester.widget<PieChart>(find.byType(PieChart)).data.sections;

void main() {
  group('pizza de ganhos', () {
    testWidgets('uma fatia por pessoa que ganhou', (tester) async {
      await montar(tester, const PizzaGanhos(),
          ganhoMarcos: 6000, ganhoSilvia: 4000);

      expect(secoes(tester), hasLength(2));
      expect(secoes(tester).map((s) => s.value).toList(), [6000, 4000]);
    });

    testWidgets('usa a cor de cada pessoa', (tester) async {
      await montar(tester, const PizzaGanhos(),
          ganhoMarcos: 6000, ganhoSilvia: 4000);

      expect(secoes(tester)[0].color, const Color(0xFF2E7D32));
      expect(secoes(tester)[1].color, const Color(0xFF6A1B9A));
    });

    testWidgets('quem nao ganhou no mes nao vira fatia invisivel',
        (tester) async {
      await montar(tester, const PizzaGanhos(), ganhoMarcos: 6000);

      expect(secoes(tester), hasLength(1));
      expect(find.byType(MarcadorLegenda), findsOneWidget);
    });

    testWidgets('ignora a visao selecionada', (tester) async {
      final c = await montar(tester, const PizzaGanhos(),
          ganhoMarcos: 6000, ganhoSilvia: 4000);

      expect(secoes(tester), hasLength(2));

      c.read(visaoProvider.notifier).selecionar('marcos');
      await tester.pumpAndSettle();

      // Continua mostrando os dois: a pergunta e sobre a proporcao do casal.
      expect(secoes(tester), hasLength(2));
    });

    testWidgets('diz no subtitulo que e do casal', (tester) async {
      await montar(tester, const PizzaGanhos(), ganhoMarcos: 6000);

      expect(find.textContaining('do casal'), findsOneWidget);
    });

    testWidgets('sem ganhos mostra a frase, sem desenhar', (tester) async {
      await montar(tester, const PizzaGanhos());

      expect(find.byType(PieChart), findsNothing);
      expect(find.textContaining('Nenhum ganho'), findsOneWidget);
    });
  });

  group('barra da cascata', () {
    testWidgets('desenha um segmento por pote', (tester) async {
      await montar(tester, const BarraCascata(),
          ganhoMarcos: 10000, gasto: 3000);

      expect(find.byType(MarcadorLegenda), findsNWidgets(2));
      expect(find.byKey(const Key('cascata_marcador')), findsOneWidget);
    });

    testWidgets('diz em que pote o gasto parou', (tester) async {
      await montar(tester, const BarraCascata(),
          ganhoMarcos: 10000, gasto: 3000);

      expect(find.textContaining('Parou em Custo fixo'), findsOneWidget);
    });

    testWidgets('gasto que passa de tudo mostra o excedente', (tester) async {
      await montar(tester, const BarraCascata(),
          ganhoMarcos: 10000, gasto: 12000);

      expect(find.textContaining('Passou'), findsOneWidget);
      expect(find.textContaining('Parou em'), findsNothing);
    });

    testWidgets('o marcador vira vermelho no estouro', (tester) async {
      await montar(tester, const BarraCascata(),
          ganhoMarcos: 10000, gasto: 12000);

      final marcador = tester
          .widget<Container>(find.byKey(const Key('cascata_marcador')));
      final esquema = ThemeData.light().colorScheme;
      expect((marcador.color), esquema.error);
    });

    testWidgets('sem renda mostra a frase e nao desenha a regua',
        (tester) async {
      await montar(tester, const BarraCascata(), gasto: 500);

      expect(find.byKey(const Key('cascata_marcador')), findsNothing);
      expect(find.textContaining('Lance seus ganhos'), findsOneWidget);
    });

    testWidgets('nao estoura o layout com renda alta e gasto zero',
        (tester) async {
      await montar(tester, const BarraCascata(), ganhoMarcos: 999999);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('cascata_marcador')), findsOneWidget);
    });

    testWidgets('respeita a visao selecionada', (tester) async {
      final c = await montar(tester, const BarraCascata(),
          ganhoMarcos: 6000, ganhoSilvia: 4000, gasto: 3000);

      expect(find.textContaining('Parou em'), findsOneWidget);

      c.read(visaoProvider.notifier).selecionar('silvia');
      await tester.pumpAndSettle();

      // Silvia ganhou 4000 e nao gastou nada: para no primeiro pote.
      expect(find.textContaining('Parou em Custo fixo'), findsOneWidget);
    });
  });
}
