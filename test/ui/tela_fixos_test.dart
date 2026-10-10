import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/fixo.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/telas/tela_fixos.dart';

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
];

Future<ProviderContainer> montar(
  WidgetTester tester, {
  RepositorioFixos? repoFixos,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
    repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
    repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
    repositorioFixosProvider.overrideWithValue(repoFixos ?? RepositorioFixosFake()),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(MesRef.atual());
  container.listen(potesProvider, (_, _) {});
  container.listen(fixosProvider, (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: TelaFixos()),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('sem fixos cadastrados mostra a mensagem de vazio',
      (tester) async {
    await montar(tester);

    expect(find.text('Nenhum fixo cadastrado.'), findsOneWidget);
  });

  testWidgets('criar um fixo de ganho grava e mostra na lista',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('novo_fixo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tipo_fixo_ganho')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('fixo_form_descricao')), 'Salário');
    // CampoMoeda nao tem key propria no TextFormField interno (mesmo
    // padrao ja usado em tela_ganhos_test.dart): e o ultimo TextFormField
    // do formulario, ja que o dropdown "De quem" nao e um TextFormField.
    await tester.enterText(find.byType(TextFormField).last, '500000');
    await tester.tap(find.byKey(const Key('fixo_form_salvar')));
    await tester.pumpAndSettle();

    expect(find.text('Salário'), findsOneWidget);
  });

  testWidgets('criar um fixo de gasto pede o pote e grava', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('novo_fixo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tipo_fixo_gasto')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fixo_form_pote')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('fixo_form_descricao')), 'Aluguel');
    // Mesmo motivo do teste anterior: ultimo TextFormField do formulario.
    await tester.enterText(find.byType(TextFormField).last, '120000');
    await tester.tap(find.byKey(const Key('fixo_form_salvar')));
    await tester.pumpAndSettle();

    expect(find.text('Aluguel'), findsOneWidget);
  });

  testWidgets('excluir um fixo so pede a confirmacao padrao', (tester) async {
    final repo = RepositorioFixosFake();
    await repo.adicionar(Fixo(
      id: '', tipo: TipoFixo.ganho, membroId: 'marcos',
      descricao: 'Salário', valor: 5000,
      criadoEm: DateTime.utc(2026, 10, 1),
    ));
    await montar(tester, repoFixos: repo);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Excluir fixo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sim_excluir')));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum fixo cadastrado.'), findsOneWidget);
  });
}
