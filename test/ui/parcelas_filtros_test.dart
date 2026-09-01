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
import 'package:controle_financeiro/ui/telas/tela_parcelas.dart';

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

const cartoes = [
  Cartao(id: 'ct1', nome: 'Nubank', ordem: 0),
  Cartao(id: 'ct2', nome: 'Inter', ordem: 1),
];

Gasto compra(
  String descricao, {
  String membroId = 'marcos',
  String poteId = 'p1',
  String? cartaoId,
  int dia = 12,
}) =>
    Gasto(
      id: '',
      mesRef: '2026-08',
      membroId: membroId,
      poteId: poteId,
      descricao: descricao,
      valor: 100,
      criadoEm: DateTime.utc(2026, 8, 1),
      data: DateTime(2026, 8, dia),
      cartaoId: cartaoId,
      parcelado: false,
    );

Future<ProviderContainer> montar(
  WidgetTester tester,
  List<(Gasto, int)> compras,
) async {
  tester.view.physicalSize = const Size(1400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = RepositorioGastosFake();
  for (final (g, n) in compras) {
    await repo.adicionar(base: g, quantidadeParcelas: n);
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider
        .overrideWithValue(RepositorioCartoesFake(cartoes)),
    repositorioGastosProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(potesProvider, (_, _) {});
  container.listen(cartoesProvider, (_, _) {});
  container.listen(casaProvider, (_, _) {});
  container.listen(parceladosDesdeProvider('2026-08'), (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Scaffold(body: TelaParcelas())),
  ));
  await tester.pumpAndSettle();
  return container;
}

double alturaDe(WidgetTester tester, String texto) =>
    tester.getTopLeft(find.text(texto).first).dy;

Future<void> ordenarPor(WidgetTester tester, String rotulo) async {
  await tester.tap(find.descendant(
    of: find.byKey(const Key('ordem_gastos')),
    matching: find.text(rotulo),
  ));
  await tester.pumpAndSettle();
}

Future<void> escolherFiltro(
    WidgetTester tester, Key filtro, String rotulo) async {
  await tester.tap(find.byKey(filtro));
  await tester.pumpAndSettle();
  await tester.tap(find.text(rotulo).last);
  await tester.pumpAndSettle();
}

void main() {
  group('a tela ganha filtros e ordenacao', () {
    testWidgets('os tres filtros e o seletor aparecem', (tester) async {
      await montar(tester, [(compra('Geladeira'), 5)]);

      expect(find.byKey(const Key('filtro_membro')), findsOneWidget);
      expect(find.byKey(const Key('filtro_cartao')), findsOneWidget);
      expect(find.byKey(const Key('filtro_pote')), findsOneWidget);
      expect(find.byKey(const Key('ordem_gastos')), findsOneWidget);
    });

    testWidgets('as quatro ordenacoes estao no seletor', (tester) async {
      await montar(tester, [(compra('Geladeira'), 5)]);

      final seletor = find.byKey(const Key('ordem_gastos'));
      for (final rotulo in ['Data', 'A–Z', 'Pote', 'Cartão']) {
        expect(
          find.descendant(of: seletor, matching: find.text(rotulo)),
          findsOneWidget,
          reason: 'faltou $rotulo',
        );
      }
    });

    testWidgets('a coluna de data e a de cartao aparecem', (tester) async {
      await montar(tester, [(compra('Geladeira', cartaoId: 'ct1'), 5)]);

      expect(find.text('12/08/2026'), findsWidgets);
      expect(find.text('Nubank'), findsWidgets);
    });
  });

  group('filtros', () {
    testWidgets('por pessoa', (tester) async {
      await montar(tester, [
        (compra('Geladeira', membroId: 'marcos'), 5),
        (compra('Sofa', membroId: 'silvia'), 5),
      ]);

      await escolherFiltro(tester, const Key('filtro_membro'), 'Marcos');

      expect(find.text('Geladeira'), findsOneWidget);
      expect(find.text('Sofa'), findsNothing);
    });

    testWidgets('por cartao', (tester) async {
      await montar(tester, [
        (compra('Geladeira', cartaoId: 'ct1'), 5),
        (compra('Sofa', cartaoId: 'ct2'), 5),
      ]);

      await escolherFiltro(tester, const Key('filtro_cartao'), 'Nubank');

      expect(find.text('Geladeira'), findsOneWidget);
      expect(find.text('Sofa'), findsNothing);
    });

    testWidgets('por pote', (tester) async {
      await montar(tester, [
        (compra('Geladeira', poteId: 'p1'), 5),
        (compra('Sofa', poteId: 'p2'), 5),
      ]);

      await escolherFiltro(tester, const Key('filtro_pote'), 'Conforto');

      expect(find.text('Sofa'), findsOneWidget);
      expect(find.text('Geladeira'), findsNothing);
    });

    testWidgets('"Sem cartão" isola o que nao passou por cartao',
        (tester) async {
      await montar(tester, [
        (compra('Geladeira', cartaoId: 'ct1'), 5),
        (compra('Pedreiro'), 5),
      ]);

      await escolherFiltro(tester, const Key('filtro_cartao'), 'Sem cartão');

      expect(find.text('Pedreiro'), findsOneWidget);
      expect(find.text('Geladeira'), findsNothing);
    });
  });

  group('ordenacao', () {
    testWidgets('por data vem a vencer primeiro, ao contrario de Gastos',
        (tester) async {
      await montar(tester, [
        (compra('Depois', dia: 20), 5),
        (compra('Antes', dia: 5), 5),
      ]);

      // Sao contas a vencer: a proxima interessa mais que a mais recente.
      expect(alturaDe(tester, '05/08/2026'),
          lessThan(alturaDe(tester, '20/08/2026')));
      expect(alturaDe(tester, 'Antes'), lessThan(alturaDe(tester, 'Depois')));
    });

    testWidgets('alfabetica ignora a data', (tester) async {
      await montar(tester, [
        (compra('Zebra', dia: 5), 5),
        (compra('Abacaxi', dia: 20), 5),
      ]);

      await ordenarPor(tester, 'A–Z');

      expect(alturaDe(tester, 'Abacaxi'), lessThan(alturaDe(tester, 'Zebra')));
    });

    testWidgets('por pote agrupa na ordem de prioridade', (tester) async {
      await montar(tester, [
        (compra('Sofa', poteId: 'p2'), 5),
        (compra('Aluguel', poteId: 'p1'), 5),
      ]);

      await ordenarPor(tester, 'Pote');

      expect(alturaDe(tester, 'Custo fixo'),
          lessThan(alturaDe(tester, 'Conforto')));
    });

    testWidgets('por cartao agrupa, com "Sem cartão" no fim', (tester) async {
      await montar(tester, [
        (compra('Geladeira', cartaoId: 'ct1'), 5),
        (compra('Pedreiro'), 5),
      ]);

      await ordenarPor(tester, 'Cartão');

      expect(alturaDe(tester, 'Nubank'),
          lessThan(alturaDe(tester, 'Sem cartão')));
    });
  });

  group('estado compartilhado com Gastos', () {
    testWidgets('a ordem escolhida aqui vale para a outra tela',
        (tester) async {
      final c = await montar(tester, [(compra('Geladeira'), 5)]);

      await ordenarPor(tester, 'Cartão');

      // Mesmo provider das duas telas: o criterio acompanha a pessoa.
      expect(c.read(ordemGastosProvider), OrdemGastos.cartao);
    });

    testWidgets('o filtro escolhido aqui vale para a outra tela',
        (tester) async {
      final c = await montar(tester, [(compra('Geladeira'), 5)]);

      await escolherFiltro(tester, const Key('filtro_membro'), 'Marcos');

      expect(c.read(filtroMembroProvider), 'marcos');
    });
  });
}
