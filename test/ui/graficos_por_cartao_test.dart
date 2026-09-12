import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/cartao.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';
import 'package:controle_financeiro/ui/widgets/graficos/rosca_por_cartao.dart';
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

const cartoes = [
  Cartao(id: 'nubank', nome: 'Nubank', ordem: 0),
  Cartao(id: 'inter', nome: 'Inter', ordem: 1),
];

/// (membroId, cartaoId ou null, valor)
typedef Lancamento = (String, String?, double);

Future<ProviderContainer> montar(
  WidgetTester tester, {
  List<Lancamento> gastosDoMes = const [],
  List<Cartao> comCartoes = cartoes,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final gastos = RepositorioGastosFake();

  for (final (membroId, cartaoId, valor) in gastosDoMes) {
    await gastos.adicionar(
      base: Gasto(
        id: '',
        mesRef: '2026-08',
        membroId: membroId,
        poteId: 'p1',
        descricao: 'Compra',
        valor: valor,
        criadoEm: DateTime.utc(2026, 8, 2),
        parcelado: false,
        cartaoId: cartaoId,
      ),
      quantidadeParcelas: 1,
    );
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake()),
    repositorioCartoesProvider
        .overrideWithValue(RepositorioCartoesFake(comCartoes)),
    repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
    repositorioGastosProvider.overrideWithValue(gastos),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(cartoesProvider, (_, _) {});
  container.listen(casaProvider, (_, _) {});
  container.listen(gastosDoMesProvider('2026-08'), (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: RoscaPorCartao())),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

List<PieChartSectionData> secoes(WidgetTester tester) =>
    tester.widget<PieChart>(find.byType(PieChart)).data.sections;

void main() {
  group('rosca de gastos por cartao', () {
    testWidgets('uma secao por cartao com gasto', (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', 'inter', 300),
      ]);

      expect(secoes(tester), hasLength(2));
      expect(secoes(tester).map((s) => s.value).toList(), [700, 300]);
    });

    testWidgets('cada secao usa a cor da paleta fixa', (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', 'inter', 300),
      ]);

      expect(secoes(tester)[0].color, const Color(0xFF2E7D32));
      expect(secoes(tester)[1].color, const Color(0xFF1565C0));
    });

    testWidgets('mostra o total no centro', (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', 'inter', 300),
      ]);

      expect(find.text(formatarReais(1000)), findsOneWidget);
    });

    testWidgets('gasto sem cartao vira Sem cartao, sem quebrar',
        (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', null, 50),
      ]);

      expect(secoes(tester), hasLength(2));
      expect(find.text('Sem cartão'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sem gastos mostra a frase e nao desenha a rosca',
        (tester) async {
      await montar(tester);

      expect(find.byType(PieChart), findsNothing);
      expect(find.text('Nenhum gasto neste mês.'), findsOneWidget);
    });

    testWidgets('a legenda tem um item por cartao', (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', 'inter', 300),
      ]);

      expect(find.byType(MarcadorLegenda), findsNWidgets(2));
      expect(find.text('Nubank'), findsOneWidget);
    });

    testWidgets('respeita a visao selecionada', (tester) async {
      final container = await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('silvia', 'inter', 300),
      ]);

      expect(secoes(tester), hasLength(2));

      container.read(visaoProvider.notifier).selecionar('marcos');
      await tester.pumpAndSettle();

      // So o gasto do Marcos sobra.
      expect(secoes(tester), hasLength(1));
      expect(secoes(tester).single.value, 700);
    });

    testWidgets('cada fatia mostra o valor em reais fora do anel',
        (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', 'inter', 300),
      ]);

      expect(find.text(formatarReais(700)), findsOneWidget);
      expect(find.text(formatarReais(300)), findsOneWidget);
    });

    testWidgets('fatia orfa "Sem cartao" tambem ganha o rotulo de valor',
        (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', null, 50),
      ]);

      expect(find.text(formatarReais(50)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uma unica fatia (100%) nao lanca excecao', (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 500),
      ]);

      // O rotulo da fatia e o total central mostram o mesmo valor porque so
      // ha um cartao: as duas ocorrencias de "R$ 500,00" sao esperadas.
      expect(find.text(formatarReais(500)), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('rotulo de valor fica no angulo e raio corretos, nao so longe do centro',
        (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', 'inter', 300),
      ]);

      final centerTotalFinder = find.text('Total');
      expect(centerTotalFinder, findsOneWidget);
      final centerTotalPos = tester.getCenter(centerTotalFinder);

      final valueLabelFinder = find.text(formatarReais(700));
      expect(valueLabelFinder, findsOneWidget);
      final valueLabelPos = tester.getCenter(valueLabelFinder);

      // Mesma formula de _anguloMedioPorFatia para a primeira fatia (nubank,
      // 700 de 1000 -> 252 graus de arco, comecando em 0 graus): angulo medio
      // 126 graus. Raio do rotulo: raioInterno(44) + raioFatia(38) + 12 + 10
      // = 104, os mesmos numeros de _Rosca/_LinhasDeChamada.
      const anguloMedioGraus = 126.0;
      const raioRotulo = 104.0;
      final radianos = anguloMedioGraus * math.pi / 180;
      final esperado = Offset(
        raioRotulo * math.cos(radianos),
        raioRotulo * math.sin(radianos),
      );

      final real = valueLabelPos - centerTotalPos;

      // Tolerancia pequena (15px): o bug do round 1 deslocava o rotulo por
      // ~metade da largura/altura do proprio texto (tipicamente 20-30px em
      // cada eixo), bem acima de qualquer folga de arredondamento de layout
      // (que e de uns 10-15px).
      expect((real - esperado).distance, lessThan(15.0));
    });
  });
}
