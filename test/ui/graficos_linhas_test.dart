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
import 'package:controle_financeiro/dominio/serie_mensal.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';
import 'package:controle_financeiro/ui/widgets/graficos/linha_comprometimento.dart';
import 'package:controle_financeiro/ui/widgets/graficos/linha_evolucao.dart';

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

/// (mesRef, valor)
typedef Entrada = (String, double);

Future<ProviderContainer> montar(
  WidgetTester tester,
  Widget grafico, {
  List<Entrada> ganhosPorMes = const [],
  List<Entrada> gastosPorMes = const [],
  int parcelasDe = 0,
  double valorParcela = 100,
  String inicioParcelas = '2026-08',
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final ganhos = RepositorioGanhosFake();
  final gastos = RepositorioGastosFake();

  for (final (mes, valor) in ganhosPorMes) {
    await ganhos.adicionar(Ganho(
      id: '',
      mesRef: mes,
      membroId: 'marcos',
      descricao: 'Salario',
      valor: valor,
      criadoEm: DateTime.utc(2026, 1, 1),
    ));
  }

  for (final (mes, valor) in gastosPorMes) {
    await gastos.adicionar(
      base: Gasto(
        id: '',
        mesRef: mes,
        membroId: 'marcos',
        poteId: 'p1',
        descricao: 'Compra',
        valor: valor,
        criadoEm: DateTime.utc(2026, 1, 1),
        parcelado: false,
      ),
      quantidadeParcelas: 1,
    );
  }

  if (parcelasDe > 0) {
    await gastos.adicionar(
      base: Gasto(
        id: '',
        mesRef: inicioParcelas,
        membroId: 'marcos',
        poteId: 'p1',
        descricao: 'Geladeira',
        valor: valorParcela,
        criadoEm: DateTime.utc(2026, 8, 1),
        parcelado: false,
      ),
      quantidadeParcelas: parcelasDe,
    );
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake()),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
    repositorioGanhosProvider.overrideWithValue(ganhos),
    repositorioGastosProvider.overrideWithValue(gastos),
  ]);
  addTearDown(container.dispose);

  const mes = MesRef(2026, 8);
  container.read(mesSelecionadoProvider.notifier).irPara(mes);
  container.listen(casaProvider, (_, _) {});

  final janela =
      (inicio: janelaAte(mes, mesesDaSerie).first.valor, fim: mes.valor);
  container.listen(ganhosDoIntervaloProvider(janela), (_, _) {});
  container.listen(gastosDoIntervaloProvider(janela), (_, _) {});
  container.listen(parceladosDesdeProvider(mes.valor), (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: grafico)),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

LineChartData dadosDaLinha(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

void main() {
  group('linha de evolucao', () {
    testWidgets('duas series, com um ponto por mes da janela', (tester) async {
      await montar(
        tester,
        const LinhaEvolucao(),
        ganhosPorMes: const [('2026-08', 5000), ('2026-06', 4000)],
        gastosPorMes: const [('2026-08', 3000)],
      );

      final dados = dadosDaLinha(tester);
      expect(dados.lineBarsData, hasLength(2));
      expect(dados.lineBarsData[0].spots, hasLength(mesesDaSerie));
      expect(dados.lineBarsData[1].spots, hasLength(mesesDaSerie));
    });

    testWidgets('mes sem lancamento e um ponto em zero, nao um buraco',
        (tester) async {
      await montar(
        tester,
        const LinhaEvolucao(),
        ganhosPorMes: const [('2026-08', 5000)],
      );

      final ganhos = dadosDaLinha(tester).lineBarsData[0].spots;
      // Julho (penultimo) nao teve nada.
      expect(ganhos[mesesDaSerie - 2].y, 0);
      expect(ganhos.last.y, 5000);
    });

    testWidgets('o ultimo ponto e o mes selecionado', (tester) async {
      await montar(
        tester,
        const LinhaEvolucao(),
        ganhosPorMes: const [('2026-08', 5000)],
      );

      expect(dadosDaLinha(tester).lineBarsData[0].spots.last.y, 5000);
    });

    testWidgets('as duas series usam cores do tema, nao de pote',
        (tester) async {
      await montar(
        tester,
        const LinhaEvolucao(),
        ganhosPorMes: const [('2026-08', 5000)],
      );

      final esquema = ThemeData.light().colorScheme;
      expect(dadosDaLinha(tester).lineBarsData[0].color, esquema.primary);
      expect(dadosDaLinha(tester).lineBarsData[1].color, esquema.error);
    });

    testWidgets('janela inteira zerada mostra a frase, sem desenhar',
        (tester) async {
      await montar(tester, const LinhaEvolucao());

      expect(find.byType(LineChart), findsNothing);
      expect(find.textContaining('Nada lançado'), findsOneWidget);
    });

    testWidgets('o eixo nao rotula os doze meses', (tester) async {
      await montar(
        tester,
        const LinhaEvolucao(),
        ganhosPorMes: const [('2026-08', 5000)],
      );

      // Doze "Ago/26" lado a lado viram mancha; o eixo rala os rotulos.
      final rotulos = find.textContaining('/2');
      expect(tester.widgetList(rotulos).length, lessThan(mesesDaSerie));
    });

    testWidgets('respeita a visao selecionada', (tester) async {
      final c = await montar(
        tester,
        const LinhaEvolucao(),
        ganhosPorMes: const [('2026-08', 5000)],
      );

      expect(dadosDaLinha(tester).lineBarsData[0].spots.last.y, 5000);

      c.read(visaoProvider.notifier).selecionar('silvia');
      await tester.pumpAndSettle();

      // Silvia nao lancou nada: a serie zera e a moldura passa a frase.
      expect(find.textContaining('Nada lançado'), findsOneWidget);
    });

    testWidgets('o tooltip da evolucao usa texto branco e nomeia a serie',
        (tester) async {
      await montar(
        tester,
        const LinhaEvolucao(),
        ganhosPorMes: const [('2026-08', 5000)],
        gastosPorMes: const [('2026-08', 3000)],
      );

      final dados = dadosDaLinha(tester);
      final itens = dados.lineTouchData.touchTooltipData.getTooltipItems([
        LineBarSpot(dados.lineBarsData[0], 0, dados.lineBarsData[0].spots.last),
        LineBarSpot(dados.lineBarsData[1], 1, dados.lineBarsData[1].spots.last),
      ]);

      // O padrao do fl_chart pinta o texto com a cor da serie; o vermelho de
      // "Gastos" some na caixa escura.
      expect(itens[0]!.textStyle.color, Colors.white);
      expect(itens[1]!.textStyle.color, Colors.white);
      expect(itens[0]!.text, contains('Ganhos'));
      expect(itens[1]!.text, contains('Gastos'));
    });
  });

  group('linha de comprometimento', () {
    testWidgets('um ponto por mes da janela futura', (tester) async {
      await montar(tester, const LinhaComprometimento(), parcelasDe: 5);

      expect(dadosDaLinha(tester).lineBarsData.single.spots,
          hasLength(mesesDaSerie));
    });

    testWidgets('soma o valor das parcelas de cada mes', (tester) async {
      await montar(
        tester,
        const LinhaComprometimento(),
        parcelasDe: 3,
        valorParcela: 100,
      );

      final pontos = dadosDaLinha(tester).lineBarsData.single.spots;
      expect(pontos[0].y, 100); // Ago
      expect(pontos[1].y, 100); // Set
      expect(pontos[2].y, 100); // Out
    });

    testWidgets('mostra o total comprometido abaixo do grafico',
        (tester) async {
      await montar(
        tester,
        const LinhaComprometimento(),
        parcelasDe: 3,
        valorParcela: 100,
      );

      // 3 parcelas de 100 (Ago/Set/Out) e os outros 9 meses da janela de 12
      // meses ficam em zero -> soma da serie inteira = 300.
      expect(find.text('Total: ${formatarReais(300)}'), findsOneWidget);
    });

    testWidgets('o total fica a direita, na mesma linha da legenda',
        (tester) async {
      await montar(
        tester,
        const LinhaComprometimento(),
        parcelasDe: 3,
        valorParcela: 100,
      );

      final legendaPos = tester.getCenter(find.text('Parcelas a pagar'));
      final totalPos =
          tester.getCenter(find.text('Total: ${formatarReais(300)}'));

      expect(totalPos.dy, closeTo(legendaPos.dy, 1));
      expect(totalPos.dx, greaterThan(legendaPos.dx));
    });

    testWidgets('a linha cai a zero depois da ultima parcela',
        (tester) async {
      await montar(tester, const LinhaComprometimento(), parcelasDe: 3);

      final pontos = dadosDaLinha(tester).lineBarsData.single.spots;
      expect(pontos[3].y, 0);
      expect(pontos.last.y, 0);
    });

    testWidgets('sem parcela nenhuma mostra a frase, sem desenhar',
        (tester) async {
      await montar(tester, const LinhaComprometimento());

      expect(find.byType(LineChart), findsNothing);
      expect(find.textContaining('Nenhuma parcela em aberto'), findsOneWidget);
    });

    testWidgets('gasto simples nao conta como comprometimento',
        (tester) async {
      await montar(
        tester,
        const LinhaComprometimento(),
        gastosPorMes: const [('2026-08', 900)],
      );

      expect(find.textContaining('Nenhuma parcela em aberto'), findsOneWidget);
    });

    testWidgets('parcelamento longo nao estoura a janela', (tester) async {
      // 24 parcelas: a janela mostra as 12 primeiras, sem quebrar.
      await montar(tester, const LinhaComprometimento(), parcelasDe: 24);

      final pontos = dadosDaLinha(tester).lineBarsData.single.spots;
      expect(pontos, hasLength(mesesDaSerie));
      expect(pontos.every((p) => p.y == 100), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('respeita a visao selecionada', (tester) async {
      final c =
          await montar(tester, const LinhaComprometimento(), parcelasDe: 3);

      expect(dadosDaLinha(tester).lineBarsData.single.spots[0].y, 100);

      c.read(visaoProvider.notifier).selecionar('silvia');
      await tester.pumpAndSettle();

      // Silvia nao tem parcela nenhuma: a serie zera e a moldura passa a
      // frase.
      expect(find.textContaining('Nenhuma parcela em aberto'), findsOneWidget);
    });

    testWidgets('o tooltip do comprometimento usa texto branco', (tester) async {
      await montar(tester, const LinhaComprometimento(), parcelasDe: 3);

      final dados = dadosDaLinha(tester);
      final itens = dados.lineTouchData.touchTooltipData.getTooltipItems([
        LineBarSpot(dados.lineBarsData[0], 0, dados.lineBarsData[0].spots.first),
      ]);

      expect(itens.single!.textStyle.color, Colors.white);
      expect(itens.single!.text, contains(formatarReais(100)));
    });

    testWidgets('percentual comprometido aparece em verde abaixo de 30%',
        (tester) async {
      await montar(
        tester,
        const LinhaComprometimento(),
        ganhosPorMes: const [('2026-08', 1000)],
        parcelasDe: 3,
        valorParcela: 100, // comprometido de agosto = 100 -> 10%
      );

      final texto = tester.widget<Text>(
        find.byKey(const Key('percentual_comprometido')),
      );
      expect(texto.data, contains(formatarPercentual(10)));
      expect(texto.style?.color, Colors.green);
    });

    testWidgets('percentual comprometido aparece em vermelho acima de 50%',
        (tester) async {
      await montar(
        tester,
        const LinhaComprometimento(),
        ganhosPorMes: const [('2026-08', 200)],
        parcelasDe: 3,
        valorParcela: 150, // comprometido de agosto = 150 -> 75%
      );

      final texto = tester.widget<Text>(
        find.byKey(const Key('percentual_comprometido')),
      );
      expect(texto.style?.color, Theme.of(tester.element(find.byType(LinhaComprometimento))).colorScheme.error);
    });

    testWidgets('sem renda, o percentual nao aparece mas o total continua',
        (tester) async {
      await montar(
        tester,
        const LinhaComprometimento(),
        parcelasDe: 3,
        valorParcela: 100,
      );

      expect(find.byKey(const Key('percentual_comprometido')), findsNothing);
      expect(find.text('Total: ${formatarReais(300)}'), findsOneWidget);
    });
  });
}
