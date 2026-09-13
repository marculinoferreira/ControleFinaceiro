import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/ui/widgets/faixa_potes.dart';

const potes = [
  Pote(id: 'p1', nome: 'Custo fixo', percentual: 60, ordem: 0,
      cor: '#2E7D32', icone: 'casa'),
  Pote(id: 'p2', nome: 'Conforto', percentual: 40, ordem: 1,
      cor: '#1565C0', icone: 'sofa'),
];

Widget montar({
  List<Pote> lista = potes,
  bool habilitado = true,
  void Function(Pote)? aoTocar,
}) =>
    MaterialApp(
      home: Scaffold(
        body: FaixaPotes(
          potes: lista,
          habilitado: habilitado,
          aoTocar: aoTocar ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('mostra um item por pote, com nome e icone', (tester) async {
    await tester.pumpWidget(montar());

    expect(find.text('Custo fixo'), findsOneWidget);
    expect(find.text('Conforto'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.weekend), findsOneWidget);
  });

  testWidgets('cada item usa a cor do proprio pote como fundo do bloco',
      (tester) async {
    await tester.pumpWidget(montar());

    final container = tester.widget<Container>(find
        .ancestor(
          of: find.byIcon(Icons.home),
          matching: find.byType(Container),
        )
        .first);
    final decoracao = container.decoration as BoxDecoration;

    expect(decoracao.color, const Color(0xFF2E7D32));
  });

  testWidgets('tocar num pote chama aoTocar com aquele pote', (tester) async {
    Pote? tocado;
    await tester.pumpWidget(montar(aoTocar: (p) => tocado = p));

    await tester.tap(find.text('Conforto'));
    await tester.pump();

    expect(tocado?.id, 'p2');
  });

  testWidgets('desabilitado nao chama aoTocar', (tester) async {
    var chamou = 0;
    await tester
        .pumpWidget(montar(habilitado: false, aoTocar: (_) => chamou++));

    await tester.tap(find.text('Custo fixo'));
    await tester.pump();

    expect(chamou, 0);
  });

  testWidgets('lista vazia nao desenha nada', (tester) async {
    await tester.pumpWidget(montar(lista: const []));

    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('icone desconhecido usa o fallback (carteira)', (tester) async {
    await tester.pumpWidget(montar(lista: const [
      Pote(id: 'p9', nome: 'Misterioso', percentual: 10, ordem: 0,
          cor: '#000000', icone: 'chave-nunca-vista'),
    ]));

    expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
  });

  testWidgets(
      'todos os rotulos usam o mesmo tamanho de fonte, mesmo com nomes de tamanhos bem diferentes',
      (tester) async {
    await tester.pumpWidget(montar(lista: const [
      Pote(id: 'p1', nome: 'Ok', percentual: 20, ordem: 0,
          cor: '#2E7D32', icone: 'casa'),
      Pote(id: 'p2', nome: 'Um Nome Bem Comprido Mesmo', percentual: 20,
          ordem: 1, cor: '#1565C0', icone: 'sofa'),
      Pote(id: 'p3', nome: 'Prazer', percentual: 20, ordem: 2,
          cor: '#AD1457', icone: 'presente'),
    ]));
    await tester.pump();

    final tamanhoCurto = tester.widget<Text>(find.text('Ok')).style?.fontSize;
    final tamanhoLongo = tester
        .widget<Text>(find.text('Um Nome Bem Comprido Mesmo'))
        .style
        ?.fontSize;
    final tamanhoPrazer =
        tester.widget<Text>(find.text('Prazer')).style?.fontSize;

    expect(tamanhoCurto, isNotNull);
    expect(tamanhoLongo, tamanhoCurto);
    expect(tamanhoPrazer, tamanhoCurto);

    // Sem FittedBox por item: cada rotulo encolhendo sozinho e exatamente o
    // bug relatado (nome curto, tipo "Prazer", ficava maior que nomes
    // longos porque precisava encolher menos pra caber na mesma largura).
    // Tamanho fixo + reticencias garante o mesmo tamanho pra todo mundo.
    expect(find.byType(FittedBox), findsNothing);
    final textoLongo =
        tester.widget<Text>(find.text('Um Nome Bem Comprido Mesmo'));
    expect(textoLongo.maxLines, 1);
    expect(textoLongo.overflow, TextOverflow.ellipsis);
  });
}
