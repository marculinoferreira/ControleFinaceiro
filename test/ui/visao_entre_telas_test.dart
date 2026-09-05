import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dados/servico_auth.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/shell.dart';

const casa = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
    Membro(id: 'marcos', nome: 'Marcos', email: 'marcos@x.com',
        cor: '#2E7D32', ordem: 0),
    Membro(id: 'silvia', nome: 'Silvia', email: 'silvia@x.com',
        cor: '#6A1B9A', ordem: 1),
  ],
);

const potes = [
  Pote(id: 'p1', nome: 'Custo fixo', percentual: 100, ordem: 0,
      cor: '#2E7D32', icone: 'casa'),
];

Gasto gasto(String membroId, String desc) => Gasto(
      id: '',
      mesRef: '2026-08',
      membroId: membroId,
      poteId: 'p1',
      descricao: desc,
      valor: 100,
      criadoEm: DateTime.utc(2026, 8, 2),
      parcelado: false,
    );

/// O app inteiro, logado como marcos@x.com, aberto no Resumo.
Future<ProviderContainer> montar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final auth = AuthFake();
  await auth.entrar(email: 'marcos@x.com', senha: 'segredo123');

  final gastos = RepositorioGastosFake();
  await gastos.adicionar(base: gasto('marcos', 'Aluguel'), quantidadeParcelas: 1);
  await gastos.adicionar(base: gasto('silvia', 'Cinema'), quantidadeParcelas: 1);

  final container = ProviderContainer(overrides: [
    servicoAuthProvider.overrideWithValue(auth),
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
    repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
    repositorioGastosProvider.overrideWithValue(gastos),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Shell()),
  ));
  await tester.pumpAndSettle();
  return container;
}

Future<void> irPara(WidgetTester tester, String aba) async {
  await tester.tap(find.text(aba).first);
  await tester.pumpAndSettle();
}

/// O que o dropdown "Pessoa" esta mostrando.
String pessoaNoDropdown(WidgetTester tester) {
  final campo = find.byKey(const Key('filtro_membro'));
  final textos = tester
      .widgetList<Text>(find.descendant(of: campo, matching: find.byType(Text)))
      .map((t) => t.data)
      .where((d) => d != null && d != 'Pessoa');
  return textos.first!;
}

void main() {
  testWidgets('Gastos abre na pessoa que o Resumo esta mostrando',
      (tester) async {
    final c = await montar(tester);
    expect(c.read(visaoProvider), 'marcos', reason: 'semeado no arranque');

    await irPara(tester, 'Gastos');

    expect(pessoaNoDropdown(tester), 'Marcos');
    expect(find.text('Cinema'), findsNothing);
  });

  testWidgets('trocar no Resumo vale ao entrar em Gastos depois',
      (tester) async {
    await montar(tester);

    await tester.tap(find.text('Silvia').first);
    await tester.pumpAndSettle();
    await irPara(tester, 'Gastos');

    expect(pessoaNoDropdown(tester), 'Silvia');
    expect(find.text('Aluguel'), findsNothing);
  });

  testWidgets('Parcelas tambem abre na pessoa do Resumo', (tester) async {
    await montar(tester);

    await irPara(tester, 'Parcelas');

    expect(pessoaNoDropdown(tester), 'Marcos');
  });
}
