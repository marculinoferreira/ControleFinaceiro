import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/fixo.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
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
  RepositorioGanhos? repoGanhos,
  RepositorioGastos? repoGastos,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
    repositorioGanhosProvider.overrideWithValue(repoGanhos ?? RepositorioGanhosFake()),
    repositorioGastosProvider.overrideWithValue(repoGastos ?? RepositorioGastosFake()),
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

  testWidgets(
      'criar um fixo de gasto ja gera o lancamento previsto do mes '
      'seguinte, sem esperar a proxima sessao', (tester) async {
    final repoGastos = RepositorioGastosFake();
    await montar(tester, repoGastos: repoGastos);

    await tester.tap(find.byKey(const Key('novo_fixo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tipo_fixo_gasto')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('fixo_form_descricao')), 'Internet');
    await tester.enterText(find.byType(TextFormField).last, '9990');
    await tester.tap(find.byKey(const Key('fixo_form_salvar')));
    // runAsync, e nao so pumpAndSettle: a geracao encadeia varios awaits
    // sobre streams dos repositorios, fora do ciclo de frame do widget --
    // sem isto o teste segue adiante antes da escrita realmente terminar.
    await tester.runAsync(() => tester.pumpAndSettle());

    final mesAlvo = mesAlvoDosFixos();
    final gastosDoMesAlvo =
        repoGastos.todos.where((g) => g.mesRef == mesAlvo.valor).toList();
    expect(gastosDoMesAlvo, hasLength(1));
    expect(gastosDoMesAlvo.single.descricao, 'Internet');
    expect(gastosDoMesAlvo.single.previsto, isTrue);
    expect(gastosDoMesAlvo.single.origemFixoId, isNotNull);
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

  testWidgets(
      'tocar num fixo abre o formulario preenchido, e salvar atualiza o '
      'fixo e sincroniza o lancamento do mes seguinte', (tester) async {
    final repoFixos = RepositorioFixosFake();
    await repoFixos.adicionar(Fixo(
      id: '', tipo: TipoFixo.gasto, membroId: 'marcos',
      descricao: 'Aluguel', valor: 1200,
      criadoEm: DateTime.utc(2026, 10, 1), poteId: 'p1',
    ));
    final fixoId = repoFixos.todos.single.id;
    final mesAlvo = mesAlvoDosFixos();

    final repoGastos = RepositorioGastosFake();
    await repoGastos.definir(
      idLancamentoDoFixo(repoFixos.todos.single, mesAlvo),
      Gasto(
        id: '', mesRef: mesAlvo.valor, membroId: 'marcos', poteId: 'p1',
        descricao: 'Aluguel', valor: 1200,
        criadoEm: DateTime.utc(2026, 10, 1), parcelado: false,
        previsto: true, origemFixoId: fixoId,
      ),
    );

    await montar(tester, repoFixos: repoFixos, repoGastos: repoGastos);

    await tester.tap(find.text('Aluguel'));
    await tester.pumpAndSettle();

    expect(find.text('Editar gasto fixo'), findsOneWidget);
    final campoDescricao = tester
        .widget<TextFormField>(find.byKey(const Key('fixo_form_descricao')));
    expect(campoDescricao.controller!.text, 'Aluguel');

    await tester.enterText(
        find.byKey(const Key('fixo_form_descricao')), 'Aluguel reajustado');
    await tester.enterText(find.byType(TextFormField).last, '135000');
    await tester.tap(find.byKey(const Key('fixo_form_salvar')));
    await tester.runAsync(() => tester.pumpAndSettle());

    expect(repoFixos.todos.single.descricao, 'Aluguel reajustado');
    expect(repoFixos.todos.single.valor, 1350);

    final gastosDoMesAlvo =
        repoGastos.todos.where((g) => g.mesRef == mesAlvo.valor).toList();
    expect(gastosDoMesAlvo, hasLength(1));
    expect(gastosDoMesAlvo.single.id, idLancamentoDoFixo(repoFixos.todos.single, mesAlvo));
    expect(gastosDoMesAlvo.single.descricao, 'Aluguel reajustado');
    expect(gastosDoMesAlvo.single.valor, 1350);
  });

  testWidgets(
      'excluir um fixo tambem apaga o lancamento previsto do mes seguinte',
      (tester) async {
    final repoFixos = RepositorioFixosFake();
    await repoFixos.adicionar(Fixo(
      id: '', tipo: TipoFixo.ganho, membroId: 'marcos',
      descricao: 'Salário', valor: 5000,
      criadoEm: DateTime.utc(2026, 10, 1),
    ));
    final fixo = repoFixos.todos.single;
    final mesAlvo = mesAlvoDosFixos();

    final repoGanhos = RepositorioGanhosFake();
    await repoGanhos.definir(
      idLancamentoDoFixo(fixo, mesAlvo),
      Ganho(
        id: '', mesRef: mesAlvo.valor, membroId: 'marcos',
        descricao: 'Salário', valor: 5000,
        criadoEm: DateTime.utc(2026, 10, 1),
        previsto: true, origemFixoId: fixo.id,
      ),
    );

    await montar(tester, repoFixos: repoFixos, repoGanhos: repoGanhos);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sim_excluir')));
    await tester.runAsync(() => tester.pumpAndSettle());

    expect(
        repoGanhos.todos.where((g) => g.mesRef == mesAlvo.valor), isEmpty);
  });

  testWidgets(
      'excluir um fixo nao apaga lancamentos de meses ja destravados',
      (tester) async {
    final repoFixos = RepositorioFixosFake();
    await repoFixos.adicionar(Fixo(
      id: '', tipo: TipoFixo.ganho, membroId: 'marcos',
      descricao: 'Salário', valor: 5000,
      criadoEm: DateTime.utc(2026, 1, 1),
    ));
    final fixo = repoFixos.todos.single;
    final mesCorrente = MesRef.atual();

    final repoGanhos = RepositorioGanhosFake();
    await repoGanhos.definir(
      idLancamentoDoFixo(fixo, mesCorrente),
      Ganho(
        id: '', mesRef: mesCorrente.valor, membroId: 'marcos',
        descricao: 'Salário', valor: 5000,
        criadoEm: DateTime.utc(2026, 1, 1),
        // Ja destravado (mes corrente, nao futuro) e convertido em real.
        previsto: false, origemFixoId: fixo.id,
      ),
    );

    await montar(tester, repoFixos: repoFixos, repoGanhos: repoGanhos);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sim_excluir')));
    await tester.runAsync(() => tester.pumpAndSettle());

    expect(
        repoGanhos.todos.where((g) => g.mesRef == mesCorrente.valor),
        hasLength(1));
  });
}
