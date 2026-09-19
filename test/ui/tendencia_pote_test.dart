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
import 'package:controle_financeiro/ui/widgets/legenda_grafico.dart';
import 'package:controle_financeiro/ui/widgets/moldura_grafico.dart';

/// Simula potesProvider falhando (permissao negada, offline etc.) -- o
/// mesmo fake usado em tela_graficos_test.dart para o achado 2 (isolamento
/// de erro).
class _PotesQueFalha implements RepositorioPotes {
  @override
  Stream<List<Pote>> observar() => Stream.error(Exception('sem permissao'));
  @override
  Future<void> salvarTodos(List<Pote> potes) async {}
  @override
  Future<void> remover(String id) async {}
}

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
    testWidgets('mostra uma linha por pote cadastrado, sem seletor',
        (tester) async {
      await montar(tester, gastos: const [('p1', 400), ('p2', 700)]);

      expect(find.byType(DropdownButton<String>), findsNothing);
      final dados = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(dados.lineBarsData, hasLength(2));
    });

    testWidgets('cada linha usa a cor cadastrada do proprio pote',
        (tester) async {
      await montar(tester, gastos: const [('p1', 400), ('p2', 700)]);

      final dados = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(dados.lineBarsData[0].color, const Color(0xFF2E7D32));
      expect(dados.lineBarsData[1].color, const Color(0xFFAD1457));
    });

    testWidgets('a legenda mostra o nome de cada pote', (tester) async {
      await montar(tester, gastos: const [('p1', 400)]);

      expect(find.byType(MarcadorLegenda), findsNWidgets(2));
      expect(find.text('Custo fixo'), findsOneWidget);
      expect(find.text('Lazer'), findsOneWidget);
    });

    testWidgets(
        'cada pote tem a propria escala: um pico no p1 nao move a linha do p2',
        (tester) async {
      await montar(tester, gastos: const [('p1', 400)]);

      final dados = tester.widget<LineChart>(find.byType(LineChart)).data;
      // p1 e o primeiro pote (faixa de cima, base em y=1): o unico ponto com
      // gasto e tambem o maximo do proprio pote, entao ele sobe ate o topo
      // da propria faixa (base + amplitude maxima).
      expect(dados.lineBarsData[0].spots.last.y, closeTo(1.8, 0.0001));
      // p2 nao tem gasto nenhum: fica parado na propria base (y=0), sem
      // qualquer influencia do p1.
      expect(dados.lineBarsData[1].spots.last.y, 0);
    });

    testWidgets('cada pote tem sua propria linha de base (zero)',
        (tester) async {
      await montar(tester, gastos: const [('p1', 400)]);

      final dados = tester.widget<LineChart>(find.byType(LineChart)).data;
      final bases = dados.extraLinesData.horizontalLines.map((l) => l.y).toSet();
      expect(bases, {0, 1});
    });

    testWidgets(
        'nenhum pote com gasto nos ultimos 6 meses mostra a frase vazia',
        (tester) async {
      await montar(tester);

      expect(find.byType(LineChart), findsNothing);
      expect(find.textContaining('Nenhum gasto'), findsOneWidget);
    });

    testWidgets('sem pote cadastrado, mostra a frase vazia sem grafico',
        (tester) async {
      await montar(tester, comPotes: const []);

      expect(find.byType(LineChart), findsNothing);
      expect(find.textContaining('Cadastre um pote'), findsOneWidget);
    });

    testWidgets(
        'potesProvider com erro mostra o cartao de erro padrao, respeitando '
        'o isolamento de erro da tela', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
          repositorioPotesProvider.overrideWithValue(_PotesQueFalha()),
          repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
          repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
          repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
        ],
      );
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

      // O erro passa pela MolduraGrafico, igual aos outros graficos que
      // dependem de potes -- inclui o botao "Tentar de novo", nao um texto
      // de erro solto.
      expect(find.byWidgetPredicate((w) => w is MolduraGrafico),
          findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });
  });
}
