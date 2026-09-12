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
  });
}
