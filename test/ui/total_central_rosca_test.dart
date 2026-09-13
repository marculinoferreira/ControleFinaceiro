import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';
import 'package:controle_financeiro/ui/widgets/graficos/total_central_rosca.dart';

Widget montar(double total, double raioInterno) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: TotalCentralRosca(total: total, raioInterno: raioInterno),
        ),
      ),
    );

void main() {
  testWidgets('mostra o rotulo e o valor formatado', (tester) async {
    await tester.pumpWidget(montar(1000, 52));

    expect(find.text('Total'), findsOneWidget);
    expect(find.text(formatarReais(1000)), findsOneWidget);
  });

  testWidgets('fica dentro de uma caixa do tamanho do furo, com FittedBox',
      (tester) async {
    await tester.pumpWidget(montar(1000, 44));

    expect(find.byType(FittedBox), findsOneWidget);
    final caixa =
        tester.widget<SizedBox>(find.byKey(const Key('total_central_caixa')));
    // A caixa precisa caber dentro do furo (raio 44): o lado de um quadrado
    // cuja diagonal cabe no circulo e raio * sqrt(2) ~= 62.2 -- bem acima do
    // que usamos, entao a caixa nunca encosta na borda do furo.
    expect(caixa.width, lessThanOrEqualTo(44 * 1.5));
    expect(caixa.height, caixa.width);
  });

  testWidgets('numero bem maior que o furo encolhe em vez de estourar',
      (tester) async {
    // O bug real: R$ 11.776,19 (bem mais largo que "Total") num furo de
    // raio 44 -- sem o FittedBox, o texto vazava por cima das fatias.
    await tester.pumpWidget(montar(11776.19, 44));

    expect(tester.takeException(), isNull);
    expect(find.text(formatarReais(11776.19)), findsOneWidget);
  });

  testWidgets('numero muito maior ainda nao lanca excecao de overflow',
      (tester) async {
    await tester.pumpWidget(montar(1234567.89, 44));

    expect(tester.takeException(), isNull);
    expect(find.text(formatarReais(1234567.89)), findsOneWidget);
  });
}
