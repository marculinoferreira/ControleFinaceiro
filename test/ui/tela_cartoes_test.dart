import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorio_gestao_casa.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dados/servico_auth.dart';
import 'package:controle_financeiro/dominio/models/cartao.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/telas/tela_cartoes.dart';

class _CartoesQueFalha implements RepositorioCartoes {
  @override
  Stream<List<Cartao>> observar() => Stream.error(Exception('sem rede'));
  @override
  Future<String> salvar(Cartao cartao) async => 'c1';
  @override
  Future<int?> meuVencimento(String cartaoId, String membroId) async => null;
  @override
  Future<void> definirMeuVencimento(
          String cartaoId, String membroId, int dia) async =>
      {};
  @override
  Future<void> removerMeuVencimento(String cartaoId, String membroId) async =>
      {};
}

/// Quem esta logada nos testes: seu membroId e usado como dono de qualquer
/// vencimento gravado, e e o unico que RepositorioCartoesFake.vencimentoDe
/// e observarMeuVencimento devem enxergar.
const _emailLogado = 'marcos@example.com';
const _meuMembroId = 'membro-marcos';

Future<(RepositorioCartoesFake, RepositorioGestaoCasaFake)> montar(
  WidgetTester tester, {
  List<Cartao> iniciais = const [],
  RepositorioCartoes? repo,
  RepositorioGestaoCasaFake? gestao,
  Size tamanho = const Size(1400, 1200),
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fake = RepositorioCartoesFake(iniciais);
  final gestaoFake = gestao ?? RepositorioGestaoCasaFake();
  final auth = AuthFake()..entrar(email: _emailLogado, senha: 'x');
  const casa = Casa(
    id: 'casa-1',
    nome: 'Casa',
    donoEmail: _emailLogado,
    membros: [
      Membro(
        id: _meuMembroId,
        nome: 'Marcos',
        email: _emailLogado,
        cor: '#000',
        ordem: 0,
      ),
    ],
  );

  final container = ProviderContainer(
    retry: repo != null ? (_, _) => null : null,
    overrides: [
      repositorioCartoesProvider.overrideWithValue(repo ?? fake),
      repositorioGestaoCasaProvider.overrideWithValue(gestaoFake),
      servicoAuthProvider.overrideWithValue(auth),
      repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    ],
  );
  addTearDown(container.dispose);
  container.listen(cartoesProvider, (_, _) {});
  container.listen(emailLogadoProvider, (_, _) {});
  container.listen(casaProvider, (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: TelaCartoes()),
  ));
  await tester.pumpAndSettle();
  return (fake, gestaoFake);
}

void main() {
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
      final (repo, _) = await montar(tester);

      await tester.tap(find.byKey(const Key('novo_cartao')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_nome')), 'C6 Bank');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.single.nome, 'C6 Bank');
      expect(repo.todos.single.id, isNotEmpty);
    });

    testWidgets('a inicial sobe sozinha', (tester) async {
      final (repo, _) = await montar(tester);

      await tester.tap(find.byKey(const Key('novo_cartao')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_nome')), 'nubank');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.single.nome, 'Nubank');
    });

    testWidgets('nome vazio e recusado', (tester) async {
      final (repo, _) = await montar(tester);

      await tester.tap(find.byKey(const Key('novo_cartao')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(find.text('Informe o nome.'), findsOneWidget);
      expect(repo.todos, isEmpty);
    });

    testWidgets('o novo entra no fim da ordem', (tester) async {
      final (repo, _) = await montar(tester, iniciais: const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);

      await tester.tap(find.byKey(const Key('novo_cartao')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_nome')), 'Sicoob');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.last.ordem, 1);
    });

    testWidgets('cadastrar tambem com um dia de vencimento', (tester) async {
      final (repo, _) = await montar(tester);

      await tester.tap(find.byKey(const Key('novo_cartao')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_nome')), 'Inter');
      await tester.enterText(find.byKey(const Key('cartao_vencimento')), '5');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      final cartaoId = repo.todos.single.id;
      expect(repo.vencimentoDe(cartaoId, _meuMembroId), 5);
    });

    testWidgets('dia de vencimento fora de 1-31 e recusado', (tester) async {
      final (repo, _) = await montar(tester);

      await tester.tap(find.byKey(const Key('novo_cartao')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_nome')), 'Inter');
      await tester.enterText(find.byKey(const Key('cartao_vencimento')), '32');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(find.text('Informe um dia entre 1 e 31.'), findsOneWidget);
      expect(repo.todos, isEmpty);
    });
  });

  group('edicao', () {
    testWidgets('tocar abre com o nome atual e renomeia', (tester) async {
      final (repo, _) = await montar(tester, iniciais: const [
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
      final (repo, _) = await montar(tester, iniciais: const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 3),
      ]);

      await tester.tap(find.text('Inter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_nome')), 'Inter PJ');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.single.ordem, 3);
    });

    testWidgets('abre com o vencimento que eu mesma cadastrei', (tester) async {
      final fake = RepositorioCartoesFake(const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);
      await fake.definirMeuVencimento('c1', _meuMembroId, 15);
      await montar(tester, repo: fake);

      await tester.tap(find.text('Inter'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, '15'), findsOneWidget);
    });

    testWidgets('trocar o vencimento grava o novo dia', (tester) async {
      final fake = RepositorioCartoesFake(const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);
      await fake.definirMeuVencimento('c1', _meuMembroId, 15);
      await montar(tester, repo: fake);

      await tester.tap(find.text('Inter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_vencimento')), '20');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(fake.vencimentoDe('c1', _meuMembroId), 20);
    });

    testWidgets('apagar o campo remove o vencimento cadastrado', (tester) async {
      final fake = RepositorioCartoesFake(const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);
      await fake.definirMeuVencimento('c1', _meuMembroId, 15);
      await montar(tester, repo: fake);

      await tester.tap(find.text('Inter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_vencimento')), '');
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(fake.vencimentoDe('c1', _meuMembroId), isNull);
    });
  });

  group('exclusao', () {
    testWidgets('pede confirmacao e chama removerCartao no servidor',
        (tester) async {
      final (_, gestao) = await montar(tester, iniciais: const [
        Cartao(id: 'c1', nome: 'Nubank', ordem: 0),
      ]);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.textContaining('continuam existindo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sim_excluir')));
      await tester.pumpAndSettle();

      expect(gestao.chamadas, ['removerCartao:c1']);
    });

    testWidgets('responder "Nao" nao chama removerCartao', (tester) async {
      final (_, gestao) = await montar(tester, iniciais: const [
        Cartao(id: 'c1', nome: 'Nubank', ordem: 0),
      ]);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nao_excluir')));
      await tester.pumpAndSettle();

      expect(gestao.chamadas, isEmpty);
    });

    testWidgets(
        'quando outro integrante tem vencimento, o servidor recusa e '
        'a tela mostra a mensagem', (tester) async {
      final gestao = RepositorioGestaoCasaFake()
        ..erro = 'Não é possível remover: outro integrante da casa ainda '
            'tem um dia de vencimento cadastrado para este cartão.';
      await montar(
        tester,
        iniciais: const [Cartao(id: 'c1', nome: 'Nubank', ordem: 0)],
        gestao: gestao,
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sim_excluir')));
      await tester.pumpAndSettle();

      expect(find.textContaining('outro integrante'), findsOneWidget);
    });
  });
}
