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
import 'package:controle_financeiro/ui/telas/formulario_gasto.dart';

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

/// Semeia uma compra parcelada em [quantidade] vezes a partir de Ago/26.
Future<RepositorioGastosFake> comCompraParcelada({
  int quantidade = 5,
  double valor = 126,
}) async {
  final repo = RepositorioGastosFake();
  await repo.adicionar(
    base: Gasto(
      id: '',
      mesRef: '2026-08',
      membroId: 'marcos',
      poteId: 'p1',
      descricao: 'pneus dakar',
      valor: valor,
      criadoEm: DateTime.utc(2026, 8, 2),
      parcelado: false,
    ),
    quantidadeParcelas: quantidade,
  );
  return repo;
}

Future<void> montar(
  WidgetTester tester, {
  required Gasto existente,
  required RepositorioGastosFake repo,
}) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
    repositorioGastosProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(potesProvider, (_, _) {});
  container.listen(casaProvider, (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('abrir_formulario'),
              onPressed: () => abrirFormularioGasto(
                context: context,
                ref: ref,
                existente: existente,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  ));

  await tester.tap(find.byKey(const Key('abrir_formulario')));
  await tester.pumpAndSettle();
}

/// As parcelas de uma compra, da primeira para a ultima.
List<Gasto> parcelasDe(RepositorioGastosFake repo) =>
    repo.todos.where((g) => g.parcela != null).toList()
      ..sort((a, b) => a.parcela!.compareTo(b.parcela!));

void main() {
  group('mudar a quantidade de parcelas', () {
    testWidgets('de 5 para 6 cria a 6a no mes seguinte ao fim',
        (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      final primeira = parcelasDe(repo).first;

      await montar(tester, existente: primeira, repo: repo);

      await tester.enterText(find.byKey(const Key('gasto_quantidade')), '6');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      final parcelas = parcelasDe(repo);
      expect(parcelas, hasLength(6));
      expect(parcelas.last.parcela, 6);
      expect(parcelas.last.mesRef, '2027-01');
      expect(parcelas.last.valor, 126);
      expect(parcelas.every((g) => g.totalParcelas == 6), isTrue);
      expect(parcelas.map((g) => g.compraId).toSet(), hasLength(1));
    });

    testWidgets('de 5 para 4 apaga a ultima', (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      final primeira = parcelasDe(repo).first;

      await montar(tester, existente: primeira, repo: repo);

      await tester.enterText(find.byKey(const Key('gasto_quantidade')), '4');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      final parcelas = parcelasDe(repo);
      expect(parcelas, hasLength(4));
      expect(parcelas.last.mesRef, '2026-11');
      expect(parcelas.every((g) => g.totalParcelas == 4), isTrue);
    });

    testWidgets('mexer so na quantidade nao pergunta o alcance',
        (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      await montar(tester, existente: parcelasDe(repo).first, repo: repo);

      await tester.enterText(find.byKey(const Key('gasto_quantidade')), '6');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      // Nenhum dialogo: as tres opcoes fariam a mesma coisa.
      expect(find.text('Alterar o valor'), findsNothing);
      expect(parcelasDe(repo), hasLength(6));
    });

    testWidgets('nao deixa encolher abaixo da parcela aberta', (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      final terceira = parcelasDe(repo)[2];

      await montar(tester, existente: terceira, repo: repo);

      await tester.enterText(find.byKey(const Key('gasto_quantidade')), '2');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      expect(find.textContaining('editando a parcela 3'), findsOneWidget);
      expect(parcelasDe(repo), hasLength(5)); // nada foi apagado
    });

    testWidgets('uma parcela so continua sendo recusada', (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      await montar(tester, existente: parcelasDe(repo).first, repo: repo);

      await tester.enterText(find.byKey(const Key('gasto_quantidade')), '1');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      expect(find.textContaining('pelo menos 2 parcelas'), findsOneWidget);
      expect(parcelasDe(repo), hasLength(5));
    });
  });

  group('identidade da compra vai para todas as parcelas', () {
    testWidgets('mudar a descricao nao pergunta e vale para todas',
        (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      await montar(tester, existente: parcelasDe(repo)[2], repo: repo);

      await tester.enterText(
          find.byKey(const Key('gasto_descricao')), 'pneus novos');
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      expect(find.text('Alterar o valor'), findsNothing);
      // Digitado em minuscula; PrimeiraMaiuscula sobe a inicial.
      expect(
          parcelasDe(repo).every((g) => g.descricao == 'Pneus novos'), isTrue);
    });

    testWidgets('mudar o pote nao pergunta e vale para todas', (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      await montar(tester, existente: parcelasDe(repo)[2], repo: repo);

      await tester.tap(find.byKey(const Key('gasto_pote')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conforto').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      expect(find.text('Alterar o valor'), findsNothing);
      expect(parcelasDe(repo).every((g) => g.poteId == 'p2'), isTrue);
    });

    testWidgets('mudar a pessoa nao pergunta e vale para todas',
        (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      await montar(tester, existente: parcelasDe(repo)[2], repo: repo);

      await tester.tap(find.byKey(const Key('gasto_membro')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Silvia').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      expect(find.text('Alterar o valor'), findsNothing);
      expect(parcelasDe(repo).every((g) => g.membroId == 'silvia'), isTrue);
    });
  });

  group('alcance do valor', () {
    testWidgets('so esta parcela muda o valor de um documento so',
        (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      await montar(tester, existente: parcelasDe(repo)[2], repo: repo);

      await tester.enterText(find.byKey(const Key('gasto_valor')), '20000');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edicao_somente_esta')));
      await tester.pumpAndSettle();

      final parcelas = parcelasDe(repo);
      expect(parcelas.where((g) => g.valor == 200), hasLength(1));
      expect(parcelas[2].valor, 200);
    });

    testWidgets('esta e as futuras muda o valor da parcela aberta em diante',
        (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      await montar(tester, existente: parcelasDe(repo)[2], repo: repo);

      await tester.enterText(find.byKey(const Key('gasto_valor')), '20000');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edicao_esta_e_futuras')));
      await tester.pumpAndSettle();

      expect(parcelasDe(repo).map((g) => g.valor).toList(),
          [126, 126, 200, 200, 200]);
    });

    testWidgets('todas as parcelas muda o valor da compra inteira',
        (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      await montar(tester, existente: parcelasDe(repo)[2], repo: repo);

      await tester.enterText(find.byKey(const Key('gasto_valor')), '20000');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edicao_todas')));
      await tester.pumpAndSettle();

      expect(parcelasDe(repo).every((g) => g.valor == 200), isTrue);
    });

    testWidgets('cancelar aborta a edicao inteira', (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      await montar(tester, existente: parcelasDe(repo).first, repo: repo);

      await tester.enterText(
          find.byKey(const Key('gasto_descricao')), 'pneus novos');
      await tester.enterText(find.byKey(const Key('gasto_valor')), '20000');
      await tester.enterText(find.byKey(const Key('gasto_quantidade')), '6');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Cancelar desiste do Salvar inteiro, nao so do alcance: nem a
      // descricao nem a 6a parcela entram.
      final parcelas = parcelasDe(repo);
      expect(parcelas, hasLength(5));
      expect(parcelas.every((g) => g.descricao == 'pneus dakar'), isTrue);
      expect(parcelas.every((g) => g.valor == 126), isTrue);
    });

    testWidgets('descricao, valor e quantidade juntos respeitam cada regra',
        (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      await montar(tester, existente: parcelasDe(repo).first, repo: repo);

      await tester.enterText(
          find.byKey(const Key('gasto_descricao')), 'pneus novos');
      await tester.enterText(find.byKey(const Key('gasto_valor')), '20000');
      await tester.enterText(find.byKey(const Key('gasto_quantidade')), '6');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edicao_somente_esta')));
      await tester.pumpAndSettle();

      final parcelas = parcelasDe(repo);
      expect(parcelas, hasLength(6)); // quantidade: compra inteira
      expect(parcelas.every((g) => g.descricao == 'Pneus novos'), isTrue);
      // Valor so na 1a, que e a editada; a 6a nasce com o valor novo.
      expect(parcelas.map((g) => g.valor).toList(),
          [200, 126, 126, 126, 126, 200]);
    });
  });

  group('preview', () {
    testWidgets('ancora no mes da parcela 1, nao no da parcela aberta',
        (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      // Parcela 3 cai em Out/26; a compra comecou em Ago/26.
      await montar(tester, existente: parcelasDe(repo)[2], repo: repo);

      expect(find.textContaining('Ago/26'), findsOneWidget);
      expect(find.textContaining('Dez/26'), findsOneWidget);
      expect(find.textContaining('Out/26'), findsNothing);
    });

    testWidgets('acompanha a nova quantidade digitada', (tester) async {
      final repo = await comCompraParcelada(quantidade: 5);
      await montar(tester, existente: parcelasDe(repo).first, repo: repo);

      await tester.enterText(find.byKey(const Key('gasto_quantidade')), '6');
      await tester.pumpAndSettle();

      expect(find.textContaining('Jan/27'), findsOneWidget);
    });
  });

  group('data da compra', () {
    testWidgets('mudar a data nao pergunta nada e vale para todas',
        (tester) async {
      final repo = await comCompraParcelada(quantidade: 3);
      await montar(tester, existente: parcelasDe(repo).first, repo: repo);

      // Abre o calendario e escolhe o dia 17 do mes exibido.
      await tester.tap(find.byKey(const Key('gasto_data')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('17'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      expect(find.text('Alterar o valor'), findsNothing);

      final parcelas = parcelasDe(repo);
      expect(parcelas.every((g) => g.data.day == 17), isTrue);
      // Cada uma continua no proprio mes.
      expect(parcelas.map((g) => g.data.month).toList(), [8, 9, 10]);
    });

    testWidgets('editar a parcela do meio alinha as irmas a ela',
        (tester) async {
      final repo = await comCompraParcelada(quantidade: 3);
      await montar(tester, existente: parcelasDe(repo)[1], repo: repo);

      await tester.tap(find.byKey(const Key('gasto_data')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('17'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      final parcelas = parcelasDe(repo);
      expect(parcelas.every((g) => g.data.day == 17), isTrue);
      expect(parcelas.map((g) => g.data.month).toList(), [8, 9, 10]);
    });
  });
}
