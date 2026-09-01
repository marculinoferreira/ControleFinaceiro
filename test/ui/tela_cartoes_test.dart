import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dados/semeadura.dart';
import 'package:controle_financeiro/dominio/models/cartao.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/telas/tela_cartoes.dart';

class _CartoesQueFalha implements RepositorioCartoes {
  @override
  Stream<List<Cartao>> observar() => Stream.error(Exception('sem rede'));
  @override
  Future<void> salvar(Cartao cartao) async {}
  @override
  Future<void> remover(String id) async {}
}

Future<RepositorioCartoesFake> montar(
  WidgetTester tester, {
  List<Cartao> iniciais = const [],
  RepositorioCartoes? repo,
  Size tamanho = const Size(1400, 1200),
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fake = RepositorioCartoesFake(iniciais);
  final container = ProviderContainer(
    retry: repo != null ? (_, _) => null : null,
    overrides: [
      repositorioCartoesProvider.overrideWithValue(repo ?? fake),
    ],
  );
  addTearDown(container.dispose);
  container.listen(cartoesProvider, (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: TelaCartoes()),
  ));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  group('semeadura', () {
    test('traz os cinco cartoes da casa, na ordem', () {
      final padrao = cartoesPadrao();

      expect(padrao.map((c) => c.nome).toList(), [
        'Inter',
        'Mercado Pago',
        'Nubank',
        'Magazine Luiza',
        'Sicoob',
      ]);
      expect(padrao.map((c) => c.ordem).toList(), [0, 1, 2, 3, 4]);
    });

    test('semear cria os cartoes quando nao ha nenhum', () async {
      final cartoes = RepositorioCartoesFake();
      await semear(
        casa: RepositorioCasaFake(),
        potes: RepositorioPotesFake(),
        cartoes: cartoes,
      );

      expect(cartoes.todos, hasLength(5));
      expect(cartoes.todos.first.nome, 'Inter');
      // Recebeu id de verdade, nao o vazio do template.
      expect(cartoes.todos.first.id, isNotEmpty);
    });

    test('semear nao duplica quando ja existe cartao', () async {
      final cartoes =
          RepositorioCartoesFake([const Cartao(id: 'c1', nome: 'Meu', ordem: 0)]);
      await semear(
        casa: RepositorioCasaFake(),
        potes: RepositorioPotesFake(),
        cartoes: cartoes,
      );

      expect(cartoes.todos, hasLength(1));
      expect(cartoes.todos.single.nome, 'Meu');
    });
  });

  group('listagem', () {
    testWidgets('mostra os cartoes cadastrados', (tester) async {
      await montar(tester, iniciais: const [
        Cartao(id: 'c1', nome: 'Nubank', ordem: 1),
        Cartao(id: 'c2', nome: 'Inter', ordem: 0),
      ]);

      expect(find.text('Nubank'), findsOneWidget);
      expect(find.text('Inter'), findsOneWidget);
    });

    testWidgets('respeita a ordem cadastrada', (tester) async {
      await montar(tester, iniciais: const [
        Cartao(id: 'c1', nome: 'Nubank', ordem: 1),
        Cartao(id: 'c2', nome: 'Inter', ordem: 0),
      ]);

      final inter = tester.getTopLeft(find.text('Inter')).dy;
      final nubank = tester.getTopLeft(find.text('Nubank')).dy;
      expect(inter, lessThan(nubank));
    });

    testWidgets('sem cartao mostra a frase', (tester) async {
      await montar(tester);
      expect(find.text('Nenhum cartão cadastrado.'), findsOneWidget);
    });

    testWidgets('erro de leitura mostra ErroComRecarregar', (tester) async {
      await montar(tester, repo: _CartoesQueFalha());
      expect(find.text('Tentar de novo'), findsOneWidget);
    });
  });

  group('cadastro', () {
    testWidgets('criar um cartao novo', (tester) async {
      final repo = await montar(tester);

      await tester.tap(find.byKey(const Key('novo_cartao')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_nome')), 'C6 Bank');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.single.nome, 'C6 Bank');
      expect(repo.todos.single.id, isNotEmpty);
    });

    testWidgets('a inicial sobe sozinha', (tester) async {
      final repo = await montar(tester);

      await tester.tap(find.byKey(const Key('novo_cartao')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_nome')), 'nubank');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.single.nome, 'Nubank');
    });

    testWidgets('nome vazio e recusado', (tester) async {
      final repo = await montar(tester);

      await tester.tap(find.byKey(const Key('novo_cartao')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(find.text('Informe o nome.'), findsOneWidget);
      expect(repo.todos, isEmpty);
    });

    testWidgets('o novo entra no fim da ordem', (tester) async {
      final repo = await montar(tester, iniciais: const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);

      await tester.tap(find.byKey(const Key('novo_cartao')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_nome')), 'Sicoob');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.last.ordem, 1);
    });
  });

  group('edicao', () {
    testWidgets('tocar abre com o nome atual e renomeia', (tester) async {
      final repo = await montar(tester, iniciais: const [
        Cartao(id: 'c1', nome: 'Nubank', ordem: 0),
      ]);

      await tester.tap(find.text('Nubank'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Nubank'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('cartao_nome')), 'Nubank Ultravioleta');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.single.id, 'c1'); // editou, nao criou outro
      expect(repo.todos.single.nome, 'Nubank Ultravioleta');
      expect(repo.todos, hasLength(1));
    });

    testWidgets('a ordem sobrevive a uma renomeacao', (tester) async {
      final repo = await montar(tester, iniciais: const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 3),
      ]);

      await tester.tap(find.text('Inter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_nome')), 'Inter PJ');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.single.ordem, 3);
    });
  });

  group('exclusao', () {
    testWidgets('pede confirmacao e avisa sobre os gastos', (tester) async {
      final repo = await montar(tester, iniciais: const [
        Cartao(id: 'c1', nome: 'Nubank', ordem: 0),
      ]);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.textContaining('continuam existindo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmar_exclusao_cartao')));
      await tester.pumpAndSettle();

      expect(repo.todos, isEmpty);
    });

    testWidgets('cancelar nao apaga', (tester) async {
      final repo = await montar(tester, iniciais: const [
        Cartao(id: 'c1', nome: 'Nubank', ordem: 0),
      ]);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.todos, hasLength(1));
    });
  });
}
