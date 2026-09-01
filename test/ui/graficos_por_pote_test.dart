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
import 'package:controle_financeiro/ui/tema/formatadores.dart';
import 'package:controle_financeiro/ui/widgets/graficos/barras_previsto_gasto.dart';
import 'package:controle_financeiro/ui/widgets/graficos/rosca_por_pote.dart';
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

/// (membroId, poteId, valor)
typedef Lancamento = (String, String, double);

Future<void> montar(
  WidgetTester tester,
  Widget grafico, {
  List<Lancamento> gastosDoMes = const [],
  double ganho = 10000,
  List<Pote> comPotes = potes,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final ganhos = RepositorioGanhosFake();
  final gastos = RepositorioGastosFake();

  if (ganho > 0) {
    await ganhos.adicionar(Ganho(
      id: '',
      mesRef: '2026-08',
      membroId: 'marcos',
      descricao: 'Salario',
      valor: ganho,
      criadoEm: DateTime.utc(2026, 8, 1),
    ));
  }

  for (final (membroId, poteId, valor) in gastosDoMes) {
    await gastos.adicionar(
      base: Gasto(
        id: '',
        mesRef: '2026-08',
        membroId: membroId,
        poteId: poteId,
        descricao: 'Compra',
        valor: valor,
        criadoEm: DateTime.utc(2026, 8, 2),
        parcelado: false,
      ),
      quantidadeParcelas: 1,
    );
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(comPotes)),
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
}

List<PieChartSectionData> secoes(WidgetTester tester) =>
    tester.widget<PieChart>(find.byType(PieChart)).data.sections;

List<BarChartGroupData> grupos(WidgetTester tester) =>
    tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;

void main() {
  group('rosca de gastos por pote', () {
    testWidgets('uma secao por pote com gasto', (tester) async {
      await montar(tester, const RoscaPorPote(), gastosDoMes: [
        ('marcos', 'p1', 700),
        ('marcos', 'p2', 300),
      ]);

      expect(secoes(tester), hasLength(2));
      expect(secoes(tester).map((s) => s.value).toList(), [700, 300]);
    });

    testWidgets('cada secao usa a cor do pote', (tester) async {
      await montar(tester, const RoscaPorPote(), gastosDoMes: [
        ('marcos', 'p1', 700),
        ('marcos', 'p2', 300),
      ]);

      expect(secoes(tester)[0].color, const Color(0xFF2E7D32));
      expect(secoes(tester)[1].color, const Color(0xFF1565C0));
    });

    testWidgets('mostra o total no centro', (tester) async {
      await montar(tester, const RoscaPorPote(), gastosDoMes: [
        ('marcos', 'p1', 700),
        ('marcos', 'p2', 300),
      ]);

      expect(find.text(formatarReais(1000)), findsOneWidget);
    });

    testWidgets('gasto em pote apagado vira Outros, sem quebrar',
        (tester) async {
      await montar(tester, const RoscaPorPote(), gastosDoMes: [
        ('marcos', 'p1', 700),
        ('marcos', 'fantasma', 50),
      ]);

      expect(secoes(tester), hasLength(2));
      expect(find.text('Outros'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sem gastos mostra a frase e nao desenha a rosca',
        (tester) async {
      await montar(tester, const RoscaPorPote());

      expect(find.byType(PieChart), findsNothing);
      expect(find.text('Nenhum gasto neste mês.'), findsOneWidget);
    });

    testWidgets('a legenda tem um item por pote', (tester) async {
      await montar(tester, const RoscaPorPote(), gastosDoMes: [
        ('marcos', 'p1', 700),
        ('marcos', 'p2', 300),
      ]);

      expect(find.byType(MarcadorLegenda), findsNWidgets(2));
      expect(find.text('Custo fixo'), findsOneWidget);
    });

    testWidgets('respeita a visao selecionada', (tester) async {
      await montar(tester, const RoscaPorPote(), gastosDoMes: [
        ('marcos', 'p1', 700),
        ('silvia', 'p2', 300),
      ]);

      expect(secoes(tester), hasLength(2));

      final container = ProviderScope.containerOf(
          tester.element(find.byType(RoscaPorPote)));
      container.read(visaoProvider.notifier).selecionar('marcos');
      await tester.pumpAndSettle();

      // So o gasto do Marcos sobra.
      expect(secoes(tester), hasLength(1));
      expect(secoes(tester).single.value, 700);
    });
  });

  group('barras previsto x gasto', () {
    testWidgets('dois rods por pote: previsto e gasto', (tester) async {
      await montar(tester, const BarrasPrevistoGasto(), gastosDoMes: [
        ('marcos', 'p1', 5500),
      ]);

      expect(grupos(tester), hasLength(2)); // um grupo por pote
      expect(grupos(tester)[0].barRods, hasLength(2));
      expect(grupos(tester)[0].barRods[0].toY, 6000); // previsto p1
      expect(grupos(tester)[0].barRods[1].toY, 5500); // gasto p1
    });

    testWidgets('pote sem gasto continua na lista, com gasto zero',
        (tester) async {
      await montar(tester, const BarrasPrevistoGasto(), gastosDoMes: [
        ('marcos', 'p1', 100),
      ]);

      expect(grupos(tester)[1].barRods[0].toY, 4000); // previsto p2
      expect(grupos(tester)[1].barRods[1].toY, 0); // gasto p2
    });

    testWidgets('gasto que estoura o pote nao e cortado no teto',
        (tester) async {
      await montar(tester, const BarrasPrevistoGasto(), gastosDoMes: [
        ('marcos', 'p1', 9000), // previsto e 6000
      ]);

      expect(grupos(tester)[0].barRods[1].toY, 9000);
    });

    testWidgets('pote estourado pinta a barra de gasto com a cor de erro',
        (tester) async {
      await montar(tester, const BarrasPrevistoGasto(), gastosDoMes: [
        ('marcos', 'p1', 9000),
      ]);

      final esquema = ThemeData.light().colorScheme;
      expect(grupos(tester)[0].barRods[1].color, esquema.error);
      // O pote intocado nao vira vermelho.
      expect(grupos(tester)[1].barRods[1].color, isNot(esquema.error));
    });

    testWidgets('sem potes mostra a frase, sem desenhar', (tester) async {
      await montar(tester, const BarrasPrevistoGasto(), comPotes: const []);

      expect(find.byType(BarChart), findsNothing);
      expect(find.textContaining('Cadastre seus potes'), findsOneWidget);
    });

    testWidgets('mes sem renda nem gasto mostra a frase, sem barras zeradas',
        (tester) async {
      await montar(tester, const BarrasPrevistoGasto(), ganho: 0);

      // Um grafico de barras de altura zero parece defeito.
      expect(find.byType(BarChart), findsNothing);
      expect(find.textContaining('Cadastre seus potes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('previsto sem gasto nenhum ainda desenha, com escala valida',
        (tester) async {
      await montar(tester, const BarrasPrevistoGasto());

      final dados = tester.widget<BarChart>(find.byType(BarChart)).data;
      expect(dados.maxY, greaterThan(0));
      expect(grupos(tester)[0].barRods[1].toY, 0); // gasto zero
      expect(tester.takeException(), isNull);
    });

    testWidgets('respeita a visao selecionada', (tester) async {
      await montar(tester, const BarrasPrevistoGasto(), gastosDoMes: [
        ('silvia', 'p1', 5500),
      ]);

      expect(grupos(tester)[0].barRods[1].toY, 5500);

      final container = ProviderScope.containerOf(
          tester.element(find.byType(BarrasPrevistoGasto)));
      container.read(visaoProvider.notifier).selecionar('marcos');
      await tester.pumpAndSettle();

      expect(grupos(tester)[0].barRods[1].toY, 0);
    });

    testWidgets('o tooltip usa texto branco, legivel na caixa escura',
        (tester) async {
      await montar(tester, const BarrasPrevistoGasto(), gastosDoMes: [
        ('marcos', 'p1', 5500),
      ]);

      final dados = tester.widget<BarChart>(find.byType(BarChart)).data;
      final item = dados.barTouchData.touchTooltipData.getTooltipItem(
        dados.barGroups[0],
        0,
        dados.barGroups[0].barRods[1],
        1,
      );

      expect(item, isNotNull);
      expect(item!.textStyle.color, Colors.white);
    });

    testWidgets('o tooltip mostra o nome inteiro do pote e o valor em moeda',
        (tester) async {
      await montar(tester, const BarrasPrevistoGasto(), gastosDoMes: [
        ('marcos', 'p1', 5500),
      ]);

      final dados = tester.widget<BarChart>(find.byType(BarChart)).data;
      final item = dados.barTouchData.touchTooltipData.getTooltipItem(
        dados.barGroups[0],
        0,
        dados.barGroups[0].barRods[1],
        1,
      );

      // O eixo abrevia ("Custo f..."); o tooltip e o unico lugar com o nome
      // completo, e o valor precisa vir formatado, nao como 5500.0.
      expect(item!.text, contains('Custo fixo'));
      expect(item.text, contains('Gasto'));
      expect(item.text, contains(formatarReais(5500)));
    });

    testWidgets('o tooltip distingue a barra de previsto da de gasto',
        (tester) async {
      await montar(tester, const BarrasPrevistoGasto(), gastosDoMes: [
        ('marcos', 'p1', 5500),
      ]);

      final dados = tester.widget<BarChart>(find.byType(BarChart)).data;
      final previsto = dados.barTouchData.touchTooltipData.getTooltipItem(
          dados.barGroups[0], 0, dados.barGroups[0].barRods[0], 0);

      expect(previsto!.text, contains('Previsto'));
      expect(previsto.text, contains(formatarReais(6000)));
    });
  });
}
