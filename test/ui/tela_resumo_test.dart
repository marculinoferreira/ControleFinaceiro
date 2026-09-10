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
import 'package:controle_financeiro/ui/telas/tela_resumo.dart';

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

Future<void> montar(
  WidgetTester tester, {
  double ganhoMarcos = 0,
  double ganhoSilvia = 0,
  double gastoMarcos = 0,
  double gastoSilvia = 0,
  List<Pote> comPotes = potes,
  RepositorioPotes? repoPotes,
  Size tamanho = const Size(1400, 1400),
  bool semRetry = false,
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
      repositorioGanhosProvider.overrideWithValue(ganhos),
      repositorioGastosProvider.overrideWithValue(gastos),
    ],
  );
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(potesProvider, (_, _) {});
  container.listen(casaProvider, (_, _) {});
  container.listen(ganhosDoMesProvider('2026-08'), (_, _) {});
  container.listen(gastosDoMesProvider('2026-08'), (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: TelaResumo()),
  ));
  await tester.pumpAndSettle();
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

      expect(find.text('Custo fixo'), findsOneWidget);
      expect(find.text('Conforto'), findsOneWidget);

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

      await tester.tap(find.text('Marcos'));
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

      await tester.tap(find.text('Silvia'));
      await tester.pumpAndSettle();

      final barras = tester
          .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator))
          .toList();
      expect(barras.every((b) => b.value == 0), isTrue);
    });
  });

  group('estados assincronos', () {
    testWidgets('erro nos potes mostra ErroComRecarregar', (tester) async {
      await montar(tester, repoPotes: _PotesFakeQueFalha(), semRetry: true);

      expect(find.text('Tentar de novo'), findsOneWidget);
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
}
