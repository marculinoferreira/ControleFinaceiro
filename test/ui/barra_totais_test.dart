import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/totais.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/widgets/barra_totais.dart';

Widget montar(TotaisMes totais) => ProviderScope(
      overrides: [
        totaisDoMesProvider.overrideWithValue(AsyncValue.data(totais)),
      ],
      child: const MaterialApp(home: Scaffold(body: BarraTotais())),
    );

void main() {
  testWidgets('mostra um selo com icone por item (ganhos/gastos/saldo)',
      (tester) async {
    await tester.pumpWidget(montar(const TotaisMes(ganhos: 100, gastos: 40)));

    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.savings), findsOneWidget);
  });

  testWidgets('continua mostrando os tres valores formatados', (tester) async {
    await tester.pumpWidget(montar(const TotaisMes(ganhos: 100, gastos: 40)));

    expect(find.text('Ganhos'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text('Saldo do mes'), findsOneWidget);
  });
}
