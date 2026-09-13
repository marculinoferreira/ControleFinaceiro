import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/ui/widgets/tabela_responsiva.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';

Future<void> comLargura(WidgetTester tester, double largura) async {
  tester.view.physicalSize = Size(largura, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget montar(List<LinhaResponsiva> linhas) => MaterialApp(
      home: Scaffold(
        body: TabelaResponsiva(
          colunas: const ['Descricao', 'Valor'],
          linhas: linhas,
        ),
      ),
    );

List<LinhaResponsiva> duasLinhas({
  VoidCallback? aoTocar,
  Future<void> Function()? aoExcluir,
}) =>
    [
      LinhaResponsiva(
        chave: const ValueKey('l1'),
        valores: const ['Aluguel', r'R$ 1.200,00'],
        aoTocar: aoTocar,
        aoExcluir: aoExcluir,
      ),
      const LinhaResponsiva(
        chave: ValueKey('l2'),
        valores: ['Mercado', r'R$ 800,00'],
      ),
    ];

Widget montarAgrupada(
  List<GrupoResponsivo> grupos, {
  double? somatoriaGeral,
}) =>
    MaterialApp(
      home: Scaffold(
        body: TabelaResponsiva.agrupada(
          colunas: const ['Descricao', 'Valor'],
          grupos: grupos,
          somatoriaGeral: somatoriaGeral,
        ),
      ),
    );

void main() {
  testWidgets('desktop usa DataTable', (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montar(duasLinhas()));
    await tester.pump();

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.text('Aluguel'), findsOneWidget);
  });

  testWidgets('mobile usa cards', (tester) async {
    await comLargura(tester, 420);
    await tester.pumpWidget(montar(duasLinhas()));
    await tester.pump();

    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('Aluguel'), findsOneWidget);
  });

  testWidgets('lista vazia mostra a mensagem no desktop', (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabelaResponsiva(
          colunas: const ['Descricao', 'Valor'],
          linhas: const [],
          vazio: 'Nada por aqui.',
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Nada por aqui.'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('lista vazia mostra a mensagem no mobile', (tester) async {
    await comLargura(tester, 420);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabelaResponsiva(
          colunas: const ['Descricao', 'Valor'],
          linhas: const [],
          vazio: 'Nada por aqui.',
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Nada por aqui.'), findsOneWidget);
  });

  testWidgets('tocar na linha dispara aoTocar no mobile', (tester) async {
    await comLargura(tester, 420);
    var tocou = 0;
    await tester.pumpWidget(montar(duasLinhas(aoTocar: () => tocou++)));
    await tester.pump();

    await tester.tap(find.text('Aluguel'));
    await tester.pump();

    expect(tocou, 1);
  });

  testWidgets('arrastar a linha pra esquerda ate o fim chama aoExcluir no mobile',
      (tester) async {
    await comLargura(tester, 420);
    var excluiu = 0;
    await tester
        .pumpWidget(montar(duasLinhas(aoExcluir: () async => excluiu++)));
    await tester.pump();

    await tester.drag(find.text('Aluguel'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(excluiu, 1);
  });

  testWidgets(
      'nao mostra mais um botao de lixeira fixo no card (so o gesto de arrastar)',
      (tester) async {
    await comLargura(tester, 420);
    await tester.pumpWidget(montar(duasLinhas(aoExcluir: () async {})));
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets(
      'a faixa vermelha com a lixeira aparece atras da linha durante o arrasto',
      (tester) async {
    await comLargura(tester, 420);
    await tester.pumpWidget(montar(duasLinhas(aoExcluir: () async {})));
    await tester.pump();

    // So a primeira linha (Aluguel) recebe aoExcluir -- so ela vira um
    // Dismissible.
    expect(find.byType(Dismissible), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsNothing); // parado, sem arrastar

    // Passos pequenos (nao um unico salto grande): dentro de um
    // ListView.builder, a arena de gestos so resolve a favor do
    // Dismissible (em vez do scroll vertical da lista) com movimento
    // incremental, do jeito que um arrasto de verdade acontece.
    final gesto =
        await tester.startGesture(tester.getCenter(find.text('Aluguel')));
    for (var i = 0; i < 10; i++) {
      await gesto.moveBy(const Offset(-15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // No meio do gesto, a faixa vermelha com o icone cheio (Icons.delete)
    // ja aparece atras da linha.
    expect(find.byIcon(Icons.delete), findsOneWidget);

    await gesto.up();
    await tester.pumpAndSettle();
  });

  testWidgets('so aceita arrastar da direita pra esquerda', (tester) async {
    await comLargura(tester, 420);
    var excluiu = 0;
    await tester
        .pumpWidget(montar(duasLinhas(aoExcluir: () async => excluiu++)));
    await tester.pump();

    // Arrastar pra DIREITA nao deve dar em nada (Dismissible so aceita
    // endToStart aqui).
    await tester.drag(find.text('Aluguel'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(excluiu, 0);
    expect(find.text('Aluguel'), findsOneWidget);
  });

  testWidgets('o botao de excluir dispara aoExcluir no desktop',
      (tester) async {
    await comLargura(tester, 1400);
    var excluiu = 0;
    await tester
        .pumpWidget(montar(duasLinhas(aoExcluir: () async => excluiu++)));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(excluiu, 1);
  });

  testWidgets('nao mostra checkbox de selecao mesmo com aoTocar',
      (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montar(duasLinhas(aoTocar: () {})));
    await tester.pump();

    expect(find.byType(Checkbox), findsNothing);
  });

  test('linha com numero de celulas diferente das colunas e rejeitada', () {
    expect(
      () => TabelaResponsiva(
        colunas: const ['A', 'B'],
        linhas: const [
          LinhaResponsiva(chave: ValueKey('x'), valores: ['so uma']),
        ],
      ),
      throwsAssertionError,
    );
  });

  testWidgets('grupo com total mostra a linha de total no desktop',
      (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montarAgrupada([
      const GrupoResponsivo(
        titulo: 'Hoje',
        linhas: [
          LinhaResponsiva(
              chave: ValueKey('l1'), valores: ['Aluguel', r'R$ 100,00']),
        ],
        total: 100,
      ),
    ]));
    await tester.pump();

    expect(find.text('Total: ${formatarReais(100)}'), findsOneWidget);
  });

  testWidgets('grupo sem total nao mostra linha extra', (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montarAgrupada([
      const GrupoResponsivo(
        titulo: 'Hoje',
        linhas: [
          LinhaResponsiva(
              chave: ValueKey('l1'), valores: ['Aluguel', r'R$ 100,00']),
        ],
      ),
    ]));
    await tester.pump();

    expect(find.textContaining('Total:'), findsNothing);
  });

  testWidgets('grupo com total mostra a linha de total no mobile',
      (tester) async {
    await comLargura(tester, 420);
    await tester.pumpWidget(montarAgrupada([
      const GrupoResponsivo(
        titulo: 'Hoje',
        linhas: [
          LinhaResponsiva(
              chave: ValueKey('l1'), valores: ['Aluguel', r'R$ 100,00']),
        ],
        total: 100,
      ),
    ]));
    await tester.pump();

    expect(find.text('Total: ${formatarReais(100)}'), findsOneWidget);
  });

  group('somatoria geral', () {
    testWidgets('mostra a linha ao final no desktop', (tester) async {
      await comLargura(tester, 1400);
      await tester.pumpWidget(montarAgrupada(
        [
          const GrupoResponsivo(
            titulo: 'Hoje',
            linhas: [
              LinhaResponsiva(
                  chave: ValueKey('l1'), valores: ['Aluguel', r'R$ 100,00']),
            ],
            total: 100,
          ),
        ],
        somatoriaGeral: 100,
      ));
      await tester.pump();

      // A linha de total do grupo ("Total: R$ 100,00") e a somatoria geral
      // ("Somatória total: R$ 100,00") coexistem, com textos diferentes.
      expect(find.text('Total: ${formatarReais(100)}'), findsOneWidget);
      expect(find.text('Somatória total: ${formatarReais(100)}'),
          findsOneWidget);
    });

    testWidgets('mostra a linha ao final no mobile', (tester) async {
      await comLargura(tester, 420);
      await tester.pumpWidget(montarAgrupada(
        [
          const GrupoResponsivo(
            titulo: 'Hoje',
            linhas: [
              LinhaResponsiva(
                  chave: ValueKey('l1'), valores: ['Aluguel', r'R$ 100,00']),
            ],
          ),
        ],
        somatoriaGeral: 100,
      ));
      await tester.pump();

      expect(find.text('Somatória total: ${formatarReais(100)}'),
          findsOneWidget);
    });

    testWidgets('nao aparece quando somatoriaGeral e nula', (tester) async {
      await comLargura(tester, 1400);
      await tester.pumpWidget(montarAgrupada([
        const GrupoResponsivo(
          titulo: 'Hoje',
          linhas: [
            LinhaResponsiva(
                chave: ValueKey('l1'), valores: ['Aluguel', r'R$ 100,00']),
          ],
        ),
      ]));
      await tester.pump();

      expect(find.textContaining('Somatória total'), findsNothing);
    });
  });

  group('data ao lado do nome no mobile', () {
    Widget montarComData(List<LinhaResponsiva> linhas) => MaterialApp(
          home: Scaffold(
            body: TabelaResponsiva(
              colunas: const ['Descricao', 'Data', 'Valor'],
              linhas: linhas,
            ),
          ),
        );

    testWidgets(
        'quando a segunda coluna e Data, ela aparece ao lado do nome no card',
        (tester) async {
      await comLargura(tester, 420);
      await tester.pumpWidget(montarComData(const [
        LinhaResponsiva(
          chave: ValueKey('l1'),
          valores: ['Aluguel', '12/08/2026', r'R$ 1.200,00'],
        ),
      ]));
      await tester.pump();

      final nomePos = tester.getCenter(find.text('Aluguel'));
      final dataPos = tester.getCenter(find.text('12/08/2026'));

      // Mesma linha (titulo do card) e a data vem depois do nome.
      expect(dataPos.dy, closeTo(nomePos.dy, 1));
      expect(dataPos.dx, greaterThan(nomePos.dx));

      // A data nao se repete na linha de baixo (subtitulo) — so o resto.
      expect(find.text(r'R$ 1.200,00'), findsOneWidget);
      expect(find.text('12/08/2026'), findsOneWidget);
    });

    testWidgets(
        'quando a segunda coluna nao e Data, o comportamento antigo continua',
        (tester) async {
      await comLargura(tester, 420);
      await tester.pumpWidget(montar(duasLinhas()));
      await tester.pump();

      // 'Valor' (nao 'Data') e a segunda coluna aqui: continua so no
      // subtitulo, nao ao lado do nome.
      final nomePos = tester.getCenter(find.text('Aluguel'));
      final valorPos = tester.getCenter(find.text(r'R$ 1.200,00'));
      expect(valorPos.dy, greaterThan(nomePos.dy));
    });
  });

  group('icone principal no card', () {
    testWidgets('aparece ao lado do nome quando informado', (tester) async {
      await comLargura(tester, 420);
      await tester.pumpWidget(montar([
        const LinhaResponsiva(
          chave: ValueKey('l1'),
          valores: ['Aluguel', r'R$ 1.200,00'],
          iconePrincipal: Icons.home,
          corIconePrincipal: Color(0xFF2E7D32),
        ),
      ]));
      await tester.pump();

      expect(find.byIcon(Icons.home), findsOneWidget);
      final icone = tester.widget<Icon>(find.byIcon(Icons.home));
      expect(icone.color, const Color(0xFF2E7D32));
    });

    testWidgets('nao aparece quando nao informado', (tester) async {
      await comLargura(tester, 420);
      await tester.pumpWidget(montar(duasLinhas()));
      await tester.pump();

      expect(find.byType(ListTile).evaluate().every((e) {
        final tile = e.widget as ListTile;
        return tile.leading == null;
      }), isTrue);
    });
  });

  group('subtitulo e valor destacado customizados no card', () {
    testWidgets('usa o subtitulo widget customizado em vez do auto-gerado',
        (tester) async {
      await comLargura(tester, 420);
      await tester.pumpWidget(montar([
        const LinhaResponsiva(
          chave: ValueKey('l1'),
          valores: ['Aluguel', r'R$ 1.200,00'],
          subtitulo: Text('subtitulo customizado'),
        ),
      ]));
      await tester.pump();

      expect(find.text('subtitulo customizado'), findsOneWidget);
      // O auto-gerado (so o resto dos valores juntando com " · ") nao
      // aparece quando ha subtitulo customizado.
      expect(find.text(r'R$ 1.200,00'), findsNothing);
    });

    testWidgets('mostra o valor destacado no trailing do ListTile',
        (tester) async {
      await comLargura(tester, 420);
      await tester.pumpWidget(montar([
        const LinhaResponsiva(
          chave: ValueKey('l1'),
          valores: ['Aluguel', 'algo qualquer'],
          valorDestacado: r'R$ 1.200,00',
        ),
      ]));
      await tester.pump();

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.trailing, isNotNull);
      expect(find.text(r'R$ 1.200,00'), findsOneWidget);
    });

    testWidgets('sem subtitulo nem valorDestacado, o comportamento antigo continua',
        (tester) async {
      await comLargura(tester, 420);
      await tester.pumpWidget(montar(duasLinhas()));
      await tester.pump();

      expect(find.text(r'R$ 1.200,00'), findsOneWidget);
      final tile = tester.widget<ListTile>(find.byType(ListTile).first);
      expect(tile.trailing, isNull);
    });
  });
}
