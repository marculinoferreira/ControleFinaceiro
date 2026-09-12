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
import 'package:controle_financeiro/dominio/ordem_gastos.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';
import 'package:controle_financeiro/ui/telas/tela_gastos.dart';

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

Gasto gasto(String descricao, int dia,
        {String poteId = 'p1', String? cartaoId}) =>
    Gasto(
      id: '',
      mesRef: '2026-08',
      membroId: 'marcos',
      poteId: poteId,
      descricao: descricao,
      valor: 100,
      criadoEm: DateTime.utc(2026, 8, 1),
      data: DateTime(2026, 8, dia),
      cartaoId: cartaoId,
      parcelado: false,
    );

Future<ProviderContainer> montar(
  WidgetTester tester, {
  required List<Gasto> gastos,
  Size tamanho = const Size(1400, 1400),
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = RepositorioGastosFake();
  for (final g in gastos) {
    await repo.adicionar(base: g, quantidadeParcelas: 1);
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider.overrideWithValue(
        RepositorioCartoesFake(const [
      Cartao(id: 'ct1', nome: 'Nubank', ordem: 0),
      Cartao(id: 'ct2', nome: 'Inter', ordem: 1),
    ])),
    repositorioGastosProvider.overrideWithValue(repo),
    repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(potesProvider, (_, _) {});
  container.listen(casaProvider, (_, _) {});
  container.listen(gastosDoMesProvider('2026-08'), (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: TelaGastos()),
  ));
  await tester.pumpAndSettle();
  return container;
}

/// A posicao vertical de um texto na tela, para provar quem vem antes.
double alturaDe(WidgetTester tester, String texto) =>
    tester.getTopLeft(find.text(texto).first).dy;

/// Toca um segmento do seletor de ordem.
///
/// find.text('Pote') sozinho e ambiguo: casa com o cabecalho da coluna, com
/// o rotulo do filtro e com o botao de ordem. A busca precisa ser dentro do
/// seletor.
Future<void> ordenarPor(WidgetTester tester, String rotulo) async {
  await tester.tap(find.descendant(
    of: find.byKey(const Key('ordem_gastos')),
    matching: find.text(rotulo),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('agrupamento por data', () {
    testWidgets('e a ordem inicial da tela', (tester) async {
      final c = await montar(tester, gastos: [gasto('Feira', 12)]);
      expect(c.read(ordemGastosProvider), OrdemGastos.data);
    });

    testWidgets('mostra um cabecalho por dia, mais recente no topo',
        (tester) async {
      await montar(tester, gastos: [
        gasto('Meli', 10),
        gasto('Feira', 12),
        gasto('Padaria', 10),
        gasto('Freezer', 12),
      ]);

      // Cada data aparece no cabecalho do grupo e tambem na coluna Data de
      // cada linha daquele dia: 1 + 2 = 3.
      expect(find.text('12/08/2026'), findsNWidgets(3));
      expect(find.text('10/08/2026'), findsNWidgets(3));

      // O dia mais recente aparece acima do mais antigo.
      expect(alturaDe(tester, '12/08/2026'),
          lessThan(alturaDe(tester, '10/08/2026')));
    });

    testWidgets('os gastos ficam sob o cabecalho do proprio dia',
        (tester) async {
      await montar(tester, gastos: [
        gasto('Meli', 10),
        gasto('Feira', 12),
      ]);

      final cab12 = alturaDe(tester, '12/08/2026');
      final cab10 = alturaDe(tester, '10/08/2026');

      expect(alturaDe(tester, 'Feira'), greaterThan(cab12));
      expect(alturaDe(tester, 'Feira'), lessThan(cab10));
      expect(alturaDe(tester, 'Meli'), greaterThan(cab10));
    });

    testWidgets('a data de cada gasto aparece na linha', (tester) async {
      await montar(tester, gastos: [gasto('Feira', 12)]);

      // Uma no cabecalho do grupo, outra na coluna Data da linha.
      expect(find.text('12/08/2026'), findsNWidgets(2));
    });
  });

  group('ordem alfabetica', () {
    testWidgets('lista corrida, sem cabecalho de dia', (tester) async {
      await montar(tester, gastos: [
        gasto('Zebra', 12),
        gasto('Abacaxi', 10),
      ]);

      await ordenarPor(tester, 'A–Z');

      // Sem cabecalho de grupo: sobra so a data da propria linha.
      expect(find.text('12/08/2026'), findsOneWidget);
      expect(find.text('10/08/2026'), findsOneWidget);
      expect(alturaDe(tester, 'Abacaxi'), lessThan(alturaDe(tester, 'Zebra')));
    });

    testWidgets('a data nao influencia a ordem', (tester) async {
      await montar(tester, gastos: [
        gasto('Zebra', 28), // mais recente
        gasto('Abacaxi', 1),
      ]);

      await ordenarPor(tester, 'A–Z');

      expect(alturaDe(tester, 'Abacaxi'), lessThan(alturaDe(tester, 'Zebra')));
    });
  });

  group('ordem por pote', () {
    testWidgets('agrupa por pote, na ordem de prioridade', (tester) async {
      await montar(tester, gastos: [
        gasto('Freezer', 10, poteId: 'p2'),
        gasto('Aluguel', 12, poteId: 'p1'),
      ]);

      await ordenarPor(tester, 'Pote');

      // Custo fixo (ordem 0) antes de Conforto (ordem 1), apesar de o gasto
      // do Conforto ser mais antigo.
      expect(alturaDe(tester, 'Custo fixo'),
          lessThan(alturaDe(tester, 'Conforto')));
      expect(alturaDe(tester, 'Aluguel'),
          lessThan(alturaDe(tester, 'Freezer')));
    });

    testWidgets('sem cabecalho de dia nesta ordem', (tester) async {
      await montar(tester, gastos: [gasto('Aluguel', 12)]);

      await ordenarPor(tester, 'Pote');

      // A data continua na coluna, mas nao ha cabecalho de dia.
      expect(find.text('12/08/2026'), findsOneWidget);
    });
  });

  group('o seletor', () {
    testWidgets('troca a ordem no provider', (tester) async {
      final c = await montar(tester, gastos: [gasto('Feira', 12)]);

      await ordenarPor(tester, 'A–Z');
      expect(c.read(ordemGastosProvider), OrdemGastos.alfabetica);

      await ordenarPor(tester, 'Pote');
      expect(c.read(ordemGastosProvider), OrdemGastos.pote);

      await ordenarPor(tester, 'Data');
      expect(c.read(ordemGastosProvider), OrdemGastos.data);
    });

    testWidgets('aparece mesmo sem gasto nenhum', (tester) async {
      await montar(tester, gastos: const []);

      expect(find.byKey(const Key('ordem_gastos')), findsOneWidget);
      expect(find.text('Nenhum gasto neste mês.'), findsOneWidget);
    });
  });

  group('mobile', () {
    testWidgets('os cabecalhos de grupo sobrevivem ao layout de cards',
        (tester) async {
      await montar(
        tester,
        gastos: [gasto('Meli', 10), gasto('Feira', 12)],
        tamanho: const Size(500, 1400),
      );

      expect(find.byType(DataTable), findsNothing);
      expect(find.text('12/08/2026'), findsWidgets);
      expect(find.text('10/08/2026'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('ordem por cartao', () {
    testWidgets('agrupa por cartao, na ordem cadastrada', (tester) async {
      await montar(tester, gastos: [
        gasto('Freezer', 10, cartaoId: 'ct2'),
        gasto('Feira', 12, cartaoId: 'ct1'),
      ]);

      await ordenarPor(tester, 'Cartão');

      expect(alturaDe(tester, 'Nubank'), lessThan(alturaDe(tester, 'Inter')));
      expect(alturaDe(tester, 'Feira'), lessThan(alturaDe(tester, 'Freezer')));
    });

    testWidgets('o que saiu em dinheiro cai em "Sem cartão"', (tester) async {
      await montar(tester, gastos: [
        gasto('Feira', 12, cartaoId: 'ct1'),
        gasto('Padaria', 11),
      ]);

      await ordenarPor(tester, 'Cartão');

      expect(find.text('Sem cartão'), findsOneWidget);
      expect(alturaDe(tester, 'Padaria'),
          greaterThan(alturaDe(tester, 'Sem cartão')));
    });

    testWidgets('troca a ordem no provider', (tester) async {
      final c = await montar(tester, gastos: [gasto('Feira', 12)]);

      await ordenarPor(tester, 'Cartão');
      expect(c.read(ordemGastosProvider), OrdemGastos.cartao);
    });

    testWidgets('as quatro opcoes aparecem no seletor', (tester) async {
      await montar(tester, gastos: [gasto('Feira', 12)]);

      final seletor = find.byKey(const Key('ordem_gastos'));
      for (final rotulo in ['Data', 'A–Z', 'Pote', 'Cartão']) {
        expect(
          find.descendant(of: seletor, matching: find.text(rotulo)),
          findsOneWidget,
          reason: 'faltou $rotulo',
        );
      }
    });
  });

  group('coluna de cartao', () {
    testWidgets('mostra o nome do cartao do gasto', (tester) async {
      await montar(tester, gastos: [gasto('Feira', 12, cartaoId: 'ct1')]);

      expect(find.text('Nubank'), findsOneWidget);
    });

    testWidgets('gasto sem cartao nao mostra nada na coluna', (tester) async {
      await montar(tester, gastos: [gasto('Padaria', 12)]);

      // Dinheiro ou pix: a celula fica vazia em vez de inventar um rotulo.
      expect(find.text('Nubank'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cartao removido nao faz o gasto sumir da lista',
        (tester) async {
      await montar(tester, gastos: [gasto('Feira', 12, cartaoId: 'sumiu')]);

      expect(find.text('Feira'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('filtro por cartao', () {
    /// Escolhe uma opcao no dropdown de cartao.
    Future<void> filtrarPorCartao(WidgetTester tester, String rotulo) async {
      await tester.tap(find.byKey(const Key('filtro_cartao')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(rotulo).last);
      await tester.pumpAndSettle();
    }

    testWidgets('comeca em Todos, mostrando tudo', (tester) async {
      final c = await montar(tester, gastos: [
        gasto('Feira', 12, cartaoId: 'ct1'),
        gasto('Padaria', 11),
      ]);

      expect(c.read(filtroCartaoProvider), isNull);
      expect(find.text('Feira'), findsOneWidget);
      expect(find.text('Padaria'), findsOneWidget);
    });

    testWidgets('filtrar por um cartao esconde os demais', (tester) async {
      await montar(tester, gastos: [
        gasto('Feira', 12, cartaoId: 'ct1'),
        gasto('Freezer', 11, cartaoId: 'ct2'),
      ]);

      await filtrarPorCartao(tester, 'Nubank');

      expect(find.text('Feira'), findsOneWidget);
      expect(find.text('Freezer'), findsNothing);
    });

    testWidgets('"Sem cartão" mostra so o que saiu em dinheiro',
        (tester) async {
      await montar(tester, gastos: [
        gasto('Feira', 12, cartaoId: 'ct1'),
        gasto('Padaria', 11),
      ]);

      await filtrarPorCartao(tester, 'Sem cartão');

      expect(find.text('Padaria'), findsOneWidget);
      expect(find.text('Feira'), findsNothing);
    });

    testWidgets('voltar para Todos traz tudo de volta', (tester) async {
      await montar(tester, gastos: [
        gasto('Feira', 12, cartaoId: 'ct1'),
        gasto('Padaria', 11),
      ]);

      await filtrarPorCartao(tester, 'Nubank');
      expect(find.text('Padaria'), findsNothing);

      await filtrarPorCartao(tester, 'Todos');
      expect(find.text('Padaria'), findsOneWidget);
      expect(find.text('Feira'), findsOneWidget);
    });

    testWidgets('combina com o filtro de pessoa e de pote', (tester) async {
      await montar(tester, gastos: [
        gasto('Feira', 12, cartaoId: 'ct1', poteId: 'p1'),
        gasto('Freezer', 12, cartaoId: 'ct1', poteId: 'p2'),
      ]);

      await filtrarPorCartao(tester, 'Nubank');
      expect(find.text('Feira'), findsOneWidget);
      expect(find.text('Freezer'), findsOneWidget);

      await tester.tap(find.byKey(const Key('filtro_pote')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conforto').last);
      await tester.pumpAndSettle();

      // Os dois filtros somam, nao competem.
      expect(find.text('Freezer'), findsOneWidget);
      expect(find.text('Feira'), findsNothing);
    });

    testWidgets('filtro apontando para cartao removido nao derruba a tela',
        (tester) async {
      final c = await montar(tester, gastos: [gasto('Feira', 12)]);

      c.read(filtroCartaoProvider.notifier).selecionar('fantasma');
      await tester.pumpAndSettle();

      // O dropdown coage o valor exibido para "Todos" em vez de derrubar o
      // assert de "exactly one item with DropdownButton's value".
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('filtro_cartao')), findsOneWidget);

      // A LISTA, porem, continua filtrando pelo id que sumiu, e fica vazia.
      // Mesmo comportamento dos filtros de pessoa e de pote, que ja eram
      // assim: a coacao e so visual. Documentado aqui para a inconsistencia
      // nao passar por acidente.
      expect(find.text('Feira'), findsNothing);
    });
  });

  group('totalizador por grupo', () {
    testWidgets('mostra o total do dia', (tester) async {
      await montar(tester, gastos: [
        gasto('Feira', 12),
        gasto('Padaria', 12),
      ]);

      // Os dois gastos (100 + 100, valor fixo do helper gasto()) caem no
      // mesmo dia -> total 200. No desktop o valor vai sob a coluna Valor
      // (colunaDoTotal), separado da celula "Total" -- ver Finding 1 do
      // review final.
      expect(find.text('Total'), findsOneWidget);
      expect(find.text(formatarReais(200)), findsOneWidget);
    });

    testWidgets('mostra o total por pote', (tester) async {
      await montar(tester, gastos: [
        gasto('Aluguel', 12, poteId: 'p1'),
        gasto('Freezer', 10, poteId: 'p2'),
      ]);

      await ordenarPor(tester, 'Pote');

      // Um gasto de 100 em cada pote -> total 100 em cada um dos dois
      // grupos. No desktop o valor do total vai sob a coluna Valor
      // (colunaDoTotal), na mesma celula onde o unico gasto do grupo ja
      // mostra "R$ 100,00" -- entao find.text(formatarReais(100)) sozinho
      // bateria em 4 celulas (2 linhas + 2 rodapes), nao so nos rodapes. A
      // key do DataRow do rodape nao vira key de nenhum widget na arvore
      // (Table/DataTable nao expoe isso), entao a linha de total e
      // distinguida pelo estilo (italico + cor esmaecida, ver o achado da
      // Finding 5) em vez de key ou posicao.
      expect(find.text('Total'), findsNWidgets(2));
      final valoresEmItalico = tester
          .widgetList<Text>(find.text(formatarReais(100)))
          .where((t) => t.style?.fontStyle == FontStyle.italic);
      expect(valoresEmItalico.length, 2);
    });

    testWidgets('nao mostra total na ordem alfabetica', (tester) async {
      await montar(tester, gastos: [gasto('Feira', 12)]);

      await ordenarPor(tester, 'A–Z');

      expect(find.textContaining('Total:'), findsNothing);
    });
  });
}
