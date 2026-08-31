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
import 'package:controle_financeiro/ui/telas/tela_parcelas.dart';

const casa = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
    Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
        cor: '#2E7D32', ordem: 0),
  ],
);

const potes = [
  Pote(id: 'p2', nome: 'Conforto', percentual: 100, ordem: 0,
      cor: '#1565C0', icone: 'sofa'),
];

Gasto base(String descricao) => Gasto(
      id: '',
      mesRef: '2026-08',
      membroId: 'marcos',
      poteId: 'p2',
      descricao: descricao,
      valor: 100,
      criadoEm: DateTime.utc(2026, 8, 1),
      parcelado: false,
    );

Future<void> montar(
  WidgetTester tester,
  Future<void> Function(RepositorioGastosFake) semear,
) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = RepositorioGastosFake();
  await semear(repo);

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioGastosProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: TelaParcelas()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sem parcelas mostra a mensagem de vazio', (tester) async {
    await montar(tester, (_) async {});

    expect(find.textContaining('Nenhuma compra parcelada'), findsOneWidget);
  });

  testWidgets('mostra a compra parcelada com parcela atual e restantes',
      (tester) async {
    await montar(tester, (repo) async {
      await repo.adicionar(base: base('Geladeira'), quantidadeParcelas: 10);
    });

    expect(find.text('Geladeira'), findsOneWidget);
    expect(find.text('1/10'), findsOneWidget);
    expect(find.textContaining('9'), findsWidgets); // faltam 9 meses
  });

  testWidgets('gasto simples nao aparece', (tester) async {
    await montar(tester, (repo) async {
      await repo.adicionar(base: base('Mercado'), quantidadeParcelas: 1);
    });

    expect(find.text('Mercado'), findsNothing);
    expect(find.textContaining('Nenhuma compra parcelada'), findsOneWidget);
  });

  testWidgets('ordena da que quita primeiro para a que quita por ultimo',
      (tester) async {
    await montar(tester, (repo) async {
      await repo.adicionar(base: base('Longa'), quantidadeParcelas: 12);
      await repo.adicionar(base: base('Curta'), quantidadeParcelas: 3);
    });

    final textos = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    expect(textos.indexOf('Curta'), lessThan(textos.indexOf('Longa')));
  });
}
