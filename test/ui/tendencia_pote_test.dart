import 'package:fl_chart/fl_chart.dart';
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
import 'package:controle_financeiro/ui/widgets/graficos/tendencia_pote.dart';

const casa = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
    Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
        cor: '#2E7D32', ordem: 0),
  ],
);

const potes = [
  Pote(id: 'p1', nome: 'Custo fixo', percentual: 60, ordem: 0,
      cor: '#2E7D32', icone: 'casa'),
  Pote(id: 'p2', nome: 'Lazer', percentual: 40, ordem: 1,
      cor: '#AD1457', icone: 'presente'),
];

Future<void> montar(
  WidgetTester tester, {
  List<Pote> comPotes = potes,
  List<(String poteId, double valor)> gastos = const [],
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repoGastos = RepositorioGastosFake();
  for (final (poteId, valor) in gastos) {
    await repoGastos.adicionar(
      base: Gasto(
        id: '', mesRef: '2026-08', membroId: 'marcos', poteId: poteId,
        descricao: 'Compra', valor: valor,
        criadoEm: DateTime.utc(2026, 8, 2), parcelado: false,
      ),
      quantidadeParcelas: 1,
    );
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(comPotes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
    repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
    repositorioGastosProvider.overrideWithValue(repoGastos),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(potesProvider, (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: TendenciaPote())),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('TendenciaPote', () {
    testWidgets('mostra o dropdown com os potes cadastrados', (tester) async {
      await montar(tester);

      expect(find.text('Custo fixo'), findsOneWidget);
    });

    testWidgets('comeca mostrando o primeiro pote', (tester) async {
      await montar(tester, gastos: const [('p1', 400)]);

      final dados =
          tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(dados.lineBarsData.single.spots.last.y, 400);
    });

    testWidgets('trocar o pote no dropdown troca a serie exibida',
        (tester) async {
      await montar(tester, gastos: const [('p1', 400), ('p2', 700)]);

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lazer').last);
      await tester.pumpAndSettle();

      final dados =
          tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(dados.lineBarsData.single.spots.last.y, 700);
    });

    testWidgets('pote sem gasto nos ultimos 6 meses mostra a frase vazia',
        (tester) async {
      await montar(tester);

      expect(find.byType(LineChart), findsNothing);
      expect(find.textContaining('Nenhum gasto'), findsOneWidget);
    });

    testWidgets('sem pote cadastrado, mostra a frase vazia sem montar o dropdown',
        (tester) async {
      await montar(tester, comPotes: const []);

      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.byType(LineChart), findsNothing);
    });
  });
}
