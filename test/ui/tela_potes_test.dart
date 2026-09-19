import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/telas/tela_potes.dart';

/// Fake que cunha ids como o Firestore faz em PotesFirestore.salvarTodos:
/// um pote com id vazio ganha um id novo a cada chamada, e qualquer
/// documento existente cujo id nao esteja entre os enviados e apagado. O
/// RepositorioPotesFake normal (lib/dados/repositorios.dart) so faz
/// `_potes = [...potes]` -- preserva `id: ''` tal e qual, entao nao consegue
/// reproduzir o bug de troca de id descrito no achado 1.
class _PotesFakeComCunhagemDeId implements RepositorioPotes {
  List<Pote> _potes;
  final _controlador = StreamController<void>.broadcast();
  var _seq = 0;

  _PotesFakeComCunhagemDeId([List<Pote> iniciais = const []])
      : _potes = [...iniciais];

  List<Pote> get todos => List.unmodifiable(_potes);

  @override
  Stream<List<Pote>> observar() => Stream.multi((assinante) {
        assinante.add(List<Pote>.unmodifiable(_potes));
        final assinatura = _controlador.stream
            .listen((_) => assinante.add(List<Pote>.unmodifiable(_potes)));
        assinante.onCancel = assinatura.cancel;
      });

  @override
  Future<void> salvarTodos(List<Pote> potes) async {
    // Mesma logica de PotesFirestore.salvarTodos: apaga os documentos
    // atuais cujo id nao esta entre os enviados, e cunha um id novo para
    // cada pote que chega com id vazio.
    final mantidos = potes.map((p) => p.id).toSet();
    _potes.removeWhere((p) => !mantidos.contains(p.id));
    _potes = [
      for (final p in potes)
        p.id.isEmpty ? p.copyWith(id: 'pote-${_seq++}') : p,
    ];
    _controlador.add(null);
  }

  @override
  Future<void> remover(String id) async {
    _potes.removeWhere((p) => p.id == id);
    _controlador.add(null);
  }
}

/// Fake cujo salvarTodos sempre falha -- simula permissao negada ou um
/// commit que nunca chega ao servidor.
class _PotesFakeQueFalha implements RepositorioPotes {
  final List<Pote> _potes;
  _PotesFakeQueFalha(this._potes);

  @override
  Stream<List<Pote>> observar() => Stream.value(List<Pote>.unmodifiable(_potes));

  @override
  Future<void> salvarTodos(List<Pote> potes) =>
      Future.error(Exception('permissao negada'));

  @override
  Future<void> remover(String id) async {}
}

/// Fake que so conta quantas vezes salvarTodos foi chamado e deixa o
/// chamador controlar quando cada chamada completa via Completer -- sem
/// nenhum Future.delayed, entao nao depende do relogio falso dos testes.
class _PotesFakeContandoChamadas implements RepositorioPotes {
  List<Pote> _potes;
  final _controlador = StreamController<void>.broadcast();
  int chamadas = 0;
  final _pendentes = <Completer<void>>[];

  _PotesFakeContandoChamadas([List<Pote> iniciais = const []])
      : _potes = [...iniciais];

  @override
  Stream<List<Pote>> observar() => Stream.multi((assinante) {
        assinante.add(List<Pote>.unmodifiable(_potes));
        final assinatura = _controlador.stream
            .listen((_) => assinante.add(List<Pote>.unmodifiable(_potes)));
        assinante.onCancel = assinatura.cancel;
      });

  @override
  Future<void> salvarTodos(List<Pote> potes) async {
    chamadas++;
    final completer = Completer<void>();
    _pendentes.add(completer);
    await completer.future;
    _potes = [...potes];
    _controlador.add(null);
  }

  /// Libera todas as chamadas pendentes ate agora.
  void completarPendentes() {
    for (final c in _pendentes) {
      if (!c.isCompleted) c.complete();
    }
    _pendentes.clear();
  }

  @override
  Future<void> remover(String id) async {
    _potes.removeWhere((p) => p.id == id);
    _controlador.add(null);
  }
}

const tresPotes = [
  Pote(id: 'p1', nome: 'Custo fixo', percentual: 55, ordem: 0,
      cor: '#2E7D32', icone: 'casa'),
  Pote(id: 'p2', nome: 'Conforto', percentual: 30, ordem: 1,
      cor: '#1565C0', icone: 'sofa'),
  Pote(id: 'p3', nome: 'Prazer', percentual: 15, ordem: 2,
      cor: '#AD1457', icone: 'presente'),
];

Future<RepositorioPotesFake> montar(
  WidgetTester tester, {
  List<Pote> iniciais = tresPotes,
  List<Override> overridesExtras = const [],
}) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = RepositorioPotesFake(iniciais);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositorioPotesProvider.overrideWithValue(repo),
      repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
      repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ...overridesExtras,
    ],
    child: const MaterialApp(home: TelaPotes()),
  ));
  await tester.pumpAndSettle();
  return repo;
}

ReorderableListView lista(WidgetTester tester) =>
    tester.widget<ReorderableListView>(find.byType(ReorderableListView));

void main() {
  group('rotuloSoma', () {
    test('exatamente 100 fecha', () {
      expect(rotuloSoma(100), '100%');
      expect(somaFechada(100), isTrue);
    });

    test('dentro da tolerancia de centavo ainda fecha', () {
      expect(somaFechada(100.004), isTrue);
      expect(somaFechada(99.996), isTrue);
    });

    test('abaixo de 100 diz quanto falta', () {
      expect(rotuloSoma(97), contains('faltam'));
      expect(rotuloSoma(97), contains('3%'));
      expect(somaFechada(97), isFalse);
    });

    test('acima de 100 diz quanto sobra', () {
      expect(rotuloSoma(103), contains('a mais'));
      expect(rotuloSoma(103), contains('3%'));
      expect(somaFechada(103), isFalse);
    });
  });

  testWidgets('lista os potes na ordem gravada', (tester) async {
    await montar(tester);

    expect(find.text('Custo fixo'), findsOneWidget);
    expect(find.text('Conforto'), findsOneWidget);
    expect(find.text('Prazer'), findsOneWidget);
    expect(lista(tester).itemCount, 3);
  });

  testWidgets('a soma inicial aparece no indicador', (tester) async {
    await montar(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('soma_potes')),
        matching: find.text('100%'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('salvar esta habilitado quando a soma fecha', (tester) async {
    await montar(tester);

    final botao =
        tester.widget<FilledButton>(find.byKey(const Key('salvar_potes')));
    expect(botao.onPressed, isNotNull);
  });

  testWidgets('mudar um percentual quebra os 100% e desabilita o salvar',
      (tester) async {
    await montar(tester);

    await tester.enterText(find.byKey(const Key('percentual_0')), '40');
    await tester.pump();

    final botao =
        tester.widget<FilledButton>(find.byKey(const Key('salvar_potes')));
    expect(botao.onPressed, isNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('soma_potes')),
        matching: find.textContaining('faltam'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reordenar e salvar grava a nova ordem', (tester) async {
    final repo = await montar(tester);

    // Move o terceiro pote (Prazer) para o topo.
    lista(tester).onReorder(2, 0);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('salvar_potes')));
    await tester.pumpAndSettle();

    expect(repo.todos.map((p) => p.nome).toList(),
        ['Prazer', 'Custo fixo', 'Conforto']);
    expect(repo.todos.map((p) => p.ordem).toList(), [0, 1, 2]);
  });

  testWidgets('salvar mantem a soma em 100 e nao altera percentuais',
      (tester) async {
    final repo = await montar(tester);

    await tester.tap(find.byKey(const Key('salvar_potes')));
    await tester.pumpAndSettle();

    expect(repo.todos.fold<double>(0, (a, p) => a + p.percentual), 100);
  });

  testWidgets(
      'reordenar atualiza o nome renderizado na linha, sem ficar obsoleto',
      (tester) async {
    await montar(tester);

    // Move o terceiro pote (Prazer) para o topo.
    lista(tester).onReorder(2, 0);
    await tester.pump();

    // O campo de nome na posicao 0 deve mostrar o pote que agora ocupa essa
    // posicao ("Prazer"), nao o que ocupava antes ("Custo fixo"). Ler pelo
    // texto renderizado no campo, nao pelo _rascunho, porque o bug e de
    // exibicao: o dado interno ja estava correto.
    expect(
      find.descendant(
        of: find.byKey(const Key('nome_0')),
        matching: find.text('Prazer'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('nome_0')),
        matching: find.text('Custo fixo'),
      ),
      findsNothing,
    );
  });

  testWidgets('remover atualiza o nome renderizado na linha que sobe',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('remover_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sim_excluir')));
    await tester.pumpAndSettle();

    // Depois de remover "Custo fixo" (indice 0), "Conforto" passa a ocupar
    // a posicao 0. O campo de nome nessa posicao deve refletir isso.
    expect(
      find.descendant(
        of: find.byKey(const Key('nome_0')),
        matching: find.text('Conforto'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('nome_0')),
        matching: find.text('Custo fixo'),
      ),
      findsNothing,
    );
  });

  testWidgets('nao passa de 6 potes', (tester) async {
    await montar(tester, iniciais: const [
      Pote(id: 'a', nome: 'A', percentual: 50, ordem: 0,
          cor: '#2E7D32', icone: 'casa'),
      Pote(id: 'b', nome: 'B', percentual: 10, ordem: 1,
          cor: '#1565C0', icone: 'casa'),
      Pote(id: 'c', nome: 'C', percentual: 10, ordem: 2,
          cor: '#00838F', icone: 'casa'),
      Pote(id: 'd', nome: 'D', percentual: 10, ordem: 3,
          cor: '#EF6C00', icone: 'casa'),
      Pote(id: 'e', nome: 'E', percentual: 10, ordem: 4,
          cor: '#AD1457', icone: 'casa'),
      Pote(id: 'f', nome: 'F', percentual: 10, ordem: 5,
          cor: '#4527A0', icone: 'casa'),
    ]);

    final botao = tester
        .widget<OutlinedButton>(find.byKey(const Key('adicionar_pote')));
    expect(botao.onPressed, isNull);
    expect(lista(tester).itemCount, maximoPotes);
  });

  testWidgets('adicionar cria um pote a mais com 0%', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('adicionar_pote')));
    await tester.pumpAndSettle();

    expect(lista(tester).itemCount, 4);
    // Soma continua 100 porque o novo entra com zero.
    expect(
      find.descendant(
        of: find.byKey(const Key('soma_potes')),
        matching: find.text('100%'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('remover tira o pote da lista e muda a soma', (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('remover_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sim_excluir')));
    await tester.pumpAndSettle();

    expect(lista(tester).itemCount, 2);
    final botao =
        tester.widget<FilledButton>(find.byKey(const Key('salvar_potes')));
    expect(botao.onPressed, isNull); // 85%, nao fecha
  });

  group('achado 1 (critico) — rascunho nao re-semeado apos salvar', () {
    Future<_PotesFakeComCunhagemDeId> montarComCunhagem(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fake = _PotesFakeComCunhagemDeId(tresPotes);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          repositorioPotesProvider.overrideWithValue(fake),
          repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        ],
        child: const MaterialApp(home: TelaPotes()),
      ));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('salvar duas vezes seguidas mantem os mesmos ids',
        (tester) async {
      final fake = await montarComCunhagem(tester);

      // Adiciona um pote novo: entra com id vazio, exatamente como a UI faz
      // (tela_potes.dart:_adicionarPote). A soma continua 100% (entra com
      // 0%), entao o Salvar permanece habilitado.
      await tester.tap(find.byKey(const Key('adicionar_pote')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('salvar_potes')));
      await tester.pumpAndSettle();
      final idsAposPrimeiro = fake.todos.map((p) => p.id).toSet();
      expect(idsAposPrimeiro, hasLength(4)); // 3 originais + 1 novo cunhado

      // O SnackBar de sucesso cobre a linha do Salvar (achado 8); avanca o
      // relogio falso (nao e Future.delayed real) ate o timer dele disparar
      // e depois assenta a animacao de saida, para o segundo toque nao ser
      // engolido por um SnackBar ainda em transicao de saida.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('salvar_potes')));
      await tester.pumpAndSettle();
      final idsAposSegundo = fake.todos.map((p) => p.id).toSet();

      // Sem a correcao, o pote novo troca de id a cada Salvar (o antigo e
      // apagado e um outro e cunhado), entao os dois conjuntos diferem.
      expect(idsAposSegundo, idsAposPrimeiro);
      expect(fake.todos, hasLength(4)); // ninguem ficou orfao
    });

    testWidgets(
        'uma emissao nova do stream depois de salvar aparece na tela',
        (tester) async {
      final fake = await montarComCunhagem(tester);

      // Toca Salvar mas NAO assenta a tela ainda: o objetivo e capturar a
      // janela entre o `setState(() => _rascunho = null)` (agendado pelo
      // Salvar) e o proximo rebuild de verdade. Se assentarmos aqui, o
      // rebuild pendente ja re-semeia o rascunho com os dados atuais (ainda
      // sem a renomeacao) antes da escrita externa acontecer.
      await tester.tap(find.byKey(const Key('salvar_potes')));

      // Simula a outra pessoa renomeando um pote enquanto esta aba
      // continua aberta: uma escrita direta no repositorio, sem passar
      // pela UI local, ANTES do primeiro rebuild pos-Salvar acontecer.
      final renomeados = [
        for (final p in fake.todos)
          p.id == 'p1' ? p.copyWith(nome: 'Custo fixo (renomeado)') : p,
      ];
      await fake.salvarTodos(renomeados);
      await tester.pumpAndSettle();

      // Sem a correcao, _rascunho continua com o valor semeado antes do
      // primeiro Salvar e a renomeacao externa nunca aparece.
      expect(
        find.descendant(
          of: find.byKey(const Key('nome_0')),
          matching: find.text('Custo fixo (renomeado)'),
        ),
        findsOneWidget,
      );
    });
  });

  group('achado 3b — guarda de reentrancia no Salvar', () {
    testWidgets('dois toques rapidos no salvar gravam uma vez so',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fake = _PotesFakeContandoChamadas(tresPotes);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          repositorioPotesProvider.overrideWithValue(fake),
          repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        ],
        child: const MaterialApp(home: TelaPotes()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('salvar_potes')));
      // Um pump (nao pumpAndSettle): a escrita esta presa no Completer, so
      // o suficiente para o setState do inicio de _salvar reconstruir a
      // tela e desabilitar o botao.
      await tester.pump();

      await tester.tap(find.byKey(const Key('salvar_potes')));
      await tester.pump();

      fake.completarPendentes();
      await tester.pumpAndSettle();

      expect(fake.chamadas, 1);
    });
  });

  testWidgets('o SnackBar de sucesso usa comportamento floating',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byKey(const Key('salvar_potes')));
    await tester.pumpAndSettle();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
  });

  group('achado 6 — tratamento de erro na escrita', () {
    testWidgets(
        'salvarTodos falhando mostra um aviso em vez de nao fazer nada',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fake = _PotesFakeQueFalha([...tresPotes]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          repositorioPotesProvider.overrideWithValue(fake),
          repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        ],
        child: const MaterialApp(home: TelaPotes()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('salvar_potes')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Potes salvos.'), findsNothing);

      // O botao volta a ficar habilitado depois do erro: a guarda de
      // reentrancia nao pode travar o usuario para sempre so porque a
      // ultima tentativa falhou.
      final botao =
          tester.widget<FilledButton>(find.byKey(const Key('salvar_potes')));
      expect(botao.onPressed, isNotNull);
    });
  });

  group('reserva de emergencia', () {
    testWidgets('checkbox e campos nao aparecem por padrao', (tester) async {
      await montar(tester);

      expect(find.byKey(const Key('reserva_0')), findsOneWidget);
      expect(find.byKey(const Key('guardado_0')), findsNothing);
    });

    testWidgets('marcar reserva mostra o campo Guardado', (tester) async {
      await montar(tester);

      await tester.tap(find.byKey(const Key('reserva_0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guardado_0')), findsOneWidget);
      expect(find.byKey(const Key('vai_ganhar_0')), findsNothing);
    });

    testWidgets('marcar um pote como reserva desmarca o anterior',
        (tester) async {
      await montar(tester);

      await tester.tap(find.byKey(const Key('reserva_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guardado_0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reserva_1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guardado_0')), findsNothing);
      expect(find.byKey(const Key('guardado_1')), findsOneWidget);
    });

    testWidgets('editar Guardado atualiza o rascunho e persiste ao salvar',
        (tester) async {
      final repo = await montar(tester);

      await tester.tap(find.byKey(const Key('reserva_0')));
      await tester.pumpAndSettle();
      // Digitos lidos como centavos (mesma convencao de CampoMoeda): '600000'
      // -> R$ 6000,00.
      await tester.enterText(find.byKey(const Key('guardado_0')), '600000');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('salvar_potes')));
      await tester.pumpAndSettle();

      expect(repo.todos.firstWhere((p) => p.ehReserva).valorGuardado, 6000);
    });

    testWidgets('mostra os meses de cobertura quando o provider tem valor',
        (tester) async {
      await montar(tester, overridesExtras: [
        mesesCoberturaReservaProvider.overrideWith((ref) => const AsyncData(4.0)),
        poteReservaProvider.overrideWith(
          (ref) => AsyncData(tresPotes.first.copyWith(ehReserva: true)),
        ),
      ]);

      expect(find.byKey(const Key('meses_cobertura')), findsOneWidget);
      expect(find.textContaining('4'), findsWidgets);
    });

    testWidgets('sem pote de reserva, o texto de cobertura nao aparece',
        (tester) async {
      await montar(tester, overridesExtras: [
        poteReservaProvider.overrideWith((ref) => const AsyncData(null)),
        mesesCoberturaReservaProvider.overrideWith((ref) => const AsyncData(null)),
      ]);

      expect(find.byKey(const Key('meses_cobertura')), findsNothing);
    });
  });
}
