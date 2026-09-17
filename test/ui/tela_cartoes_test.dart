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
  Future<int?> meuFechamento(String cartaoId, String membroId) async => null;
  @override
  Future<void> definirMeuFechamento(
          String cartaoId, String membroId, int dia) async =>
      {};
  @override
  Future<void> removerMeuFechamento(String cartaoId, String membroId) async =>
      {};
}

/// Quem esta logada nos testes: seu membroId e usado como dono de qualquer
/// fechamento gravado, e e o unico que RepositorioCartoesFake.fechamentoDe
/// e meuFechamento devem enxergar.
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

    testWidgets('cadastrar tambem com um dia de fechamento', (tester) async {
      final (repo, _) = await montar(tester);

      await tester.tap(find.byKey(const Key('novo_cartao')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cartao_nome')), 'Inter');
      await tester.tap(find.byKey(const Key('cartao_fechamento')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dia_fechamento_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      final cartaoId = repo.todos.single.id;
      expect(repo.fechamentoDe(cartaoId, _meuMembroId), 5);
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

    testWidgets('abre com o fechamento que eu mesma cadastrei', (tester) async {
      final fake = RepositorioCartoesFake(const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);
      await fake.definirMeuFechamento('c1', _meuMembroId, 15);
      await montar(tester, repo: fake);

      await tester.tap(find.text('Inter'));
      await tester.pumpAndSettle();

      expect(find.text('Dia 15'), findsOneWidget);
    });

    testWidgets('no dialogo, o dia ja cadastrado aparece destacado com cor',
        (tester) async {
      final fake = RepositorioCartoesFake(const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);
      await fake.definirMeuFechamento('c1', _meuMembroId, 15);
      await montar(tester, repo: fake);

      await tester.tap(find.text('Inter'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cartao_fechamento')));
      await tester.pumpAndSettle();

      final container15 = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('dia_fechamento_15')),
          matching: find.byType(Container),
        ),
      );
      final container16 = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('dia_fechamento_16')),
          matching: find.byType(Container),
        ),
      );

      expect((container15.decoration as BoxDecoration?)?.color, isNotNull);
      expect(container16.decoration, isNull);
    });

    testWidgets('trocar o fechamento grava o novo dia', (tester) async {
      final fake = RepositorioCartoesFake(const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);
      await fake.definirMeuFechamento('c1', _meuMembroId, 15);
      await montar(tester, repo: fake);

      await tester.tap(find.text('Inter'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cartao_fechamento')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dia_fechamento_20')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(fake.fechamentoDe('c1', _meuMembroId), 20);
    });

    testWidgets('remover o dia cadastrado no dialogo apaga o fechamento',
        (tester) async {
      final fake = RepositorioCartoesFake(const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);
      await fake.definirMeuFechamento('c1', _meuMembroId, 15);
      await montar(tester, repo: fake);

      await tester.tap(find.text('Inter'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cartao_fechamento')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('remover_fechamento')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cartao_salvar')));
      await tester.pumpAndSettle();

      expect(fake.fechamentoDe('c1', _meuMembroId), isNull);
    });
  });

  group('atalho de calendario na lista', () {
    testWidgets('define o fechamento direto, sem abrir o dialogo de editar',
        (tester) async {
      final fake = RepositorioCartoesFake(const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);
      await montar(tester, repo: fake);

      await tester.tap(find.byKey(const Key('fechamento_rapido_c1')));
      await tester.pumpAndSettle();

      // O dialogo de editar (nome + botao Salvar) nao chegou a abrir.
      expect(find.byKey(const Key('cartao_nome')), findsNothing);
      expect(find.byKey(const Key('dia_fechamento_10')), findsOneWidget);

      await tester.tap(find.byKey(const Key('dia_fechamento_10')));
      await tester.pumpAndSettle();

      expect(fake.fechamentoDe('c1', _meuMembroId), 10);
    });

    testWidgets('remover pelo atalho apaga o fechamento cadastrado',
        (tester) async {
      final fake = RepositorioCartoesFake(const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);
      await fake.definirMeuFechamento('c1', _meuMembroId, 15);
      await montar(tester, repo: fake);

      await tester.tap(find.byKey(const Key('fechamento_rapido_c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('remover_fechamento')));
      await tester.pumpAndSettle();

      expect(fake.fechamentoDe('c1', _meuMembroId), isNull);
    });

    testWidgets('define pelo atalho atualiza o texto na propria lista',
        (tester) async {
      final fake = RepositorioCartoesFake(const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);
      await montar(tester, repo: fake);

      expect(find.textContaining('Fechamento dia'), findsNothing);

      await tester.tap(find.byKey(const Key('fechamento_rapido_c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dia_fechamento_10')));
      await tester.pumpAndSettle();

      expect(find.text('Fechamento dia 10'), findsOneWidget);
    });

    testWidgets('sem fechamento cadastrado nao mostra o texto na lista',
        (tester) async {
      final fake = RepositorioCartoesFake(const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);
      await montar(tester, repo: fake);

      expect(find.textContaining('Fechamento dia'), findsNothing);
    });

    testWidgets('ja cadastrado, a lista mostra o texto ao abrir a tela',
        (tester) async {
      final fake = RepositorioCartoesFake(const [
        Cartao(id: 'c1', nome: 'Inter', ordem: 0),
      ]);
      await fake.definirMeuFechamento('c1', _meuMembroId, 20);
      await montar(tester, repo: fake);

      expect(find.text('Fechamento dia 20'), findsOneWidget);
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
        'quando outro integrante tem fechamento, o servidor recusa e '
        'a tela mostra a mensagem', (tester) async {
      final gestao = RepositorioGestaoCasaFake()
        ..erro = 'Não é possível remover: outro integrante da casa ainda '
            'tem um dia de fechamento cadastrado para este cartão.';
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
