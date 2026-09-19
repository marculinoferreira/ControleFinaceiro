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
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/widgets/graficos/barras_cartao_comparativo.dart';
import 'package:controle_financeiro/ui/widgets/graficos/barras_pote_comparativo.dart';

const casaComDupla = Casa(
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
];

const cartoes = [
  Cartao(id: 'nubank', nome: 'Nubank', ordem: 0),
];

/// (membroId, poteId, cartaoId, valor)
typedef Lancamento = (String, String, String?, double);

Future<void> montar(
  WidgetTester tester,
  Widget grafico, {
  List<Lancamento> gastosDoMes = const [],
  Casa casa = casaComDupla,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final gastos = RepositorioGastosFake();
  for (final (membroId, poteId, cartaoId, valor) in gastosDoMes) {
    await gastos.adicionar(
      base: Gasto(
        id: '', mesRef: '2026-08', membroId: membroId, poteId: poteId,
        cartaoId: cartaoId, descricao: 'Compra', valor: valor,
        criadoEm: DateTime.utc(2026, 8, 2), parcelado: false,
      ),
      quantidadeParcelas: 1,
    );
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake(cartoes)),
    repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
    repositorioGastosProvider.overrideWithValue(gastos),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(casaProvider, (_, _) {});
  container.listen(potesProvider, (_, _) {});
  container.listen(cartoesProvider, (_, _) {});
  container.listen(gastosDoMesProvider('2026-08'), (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: grafico)),
    ),
  ));
  await tester.pumpAndSettle();
}

List<BarChartGroupData> grupos(WidgetTester tester) =>
    tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;

void main() {
  group('BarrasPoteComparativo', () {
    testWidgets('dois rods por pote, um pra cada pessoa', (tester) async {
      await montar(tester, const BarrasPoteComparativo(), gastosDoMes: [
        ('marcos', 'p1', null, 700),
        ('silvia', 'p1', null, 300),
      ]);

      expect(grupos(tester), hasLength(1));
      expect(grupos(tester).single.barRods, hasLength(2));
      expect(grupos(tester).single.barRods[0].toY, 700);
      expect(grupos(tester).single.barRods[1].toY, 300);
    });

    testWidgets('a legenda tem os nomes das duas pessoas', (tester) async {
      await montar(tester, const BarrasPoteComparativo(), gastosDoMes: [
        ('marcos', 'p1', null, 700),
      ]);

      expect(find.text('Marcos'), findsOneWidget);
      expect(find.text('Silvia'), findsOneWidget);
    });

    testWidgets('sem gasto de nenhuma das duas mostra a frase', (tester) async {
      await montar(tester, const BarrasPoteComparativo());

      expect(find.byType(BarChart), findsNothing);
      expect(find.textContaining('Nenhum gasto'), findsOneWidget);
    });

    testWidgets('casa com 1 pessoa so mostra a frase, sem desenhar',
        (tester) async {
      await montar(
        tester,
        const BarrasPoteComparativo(),
        casa: const Casa(
          id: 'principal',
          nome: 'Casa',
          membros: [
            Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                cor: '#2E7D32', ordem: 0),
          ],
        ),
        gastosDoMes: [('marcos', 'p1', null, 700)],
      );

      expect(find.byType(BarChart), findsNothing);
    });
  });

  group('BarrasCartaoComparativo', () {
    testWidgets('dois rods por cartao, um pra cada pessoa', (tester) async {
      await montar(tester, const BarrasCartaoComparativo(), gastosDoMes: [
        ('marcos', 'p1', 'nubank', 700),
        ('silvia', 'p1', 'nubank', 300),
      ]);

      expect(grupos(tester), hasLength(1));
      expect(grupos(tester).single.barRods[0].toY, 700);
      expect(grupos(tester).single.barRods[1].toY, 300);
    });

    testWidgets('sem gasto de nenhuma das duas mostra a frase', (tester) async {
      await montar(tester, const BarrasCartaoComparativo());

      expect(find.byType(BarChart), findsNothing);
      expect(find.textContaining('Nenhum gasto'), findsOneWidget);
    });
  });
}
