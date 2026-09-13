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
  VoidCallback? aoExcluir,
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

Widget montarAgrupada(List<GrupoResponsivo> grupos) => MaterialApp(
      home: Scaffold(
        body: TabelaResponsiva.agrupada(
          colunas: const ['Descricao', 'Valor'],
          grupos: grupos,
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

  testWidgets('o botao de excluir dispara aoExcluir no mobile', (tester) async {
    await comLargura(tester, 420);
    var excluiu = 0;
    await tester.pumpWidget(montar(duasLinhas(aoExcluir: () => excluiu++)));
    await tester.pump();

    // So a primeira linha recebe aoExcluir, entao existe um unico botao.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(excluiu, 1);
  });

  testWidgets('o botao de excluir dispara aoExcluir no desktop',
      (tester) async {
    await comLargura(tester, 1400);
    var excluiu = 0;
    await tester.pumpWidget(montar(duasLinhas(aoExcluir: () => excluiu++)));
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
}
