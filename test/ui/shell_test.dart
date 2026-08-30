import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/shell.dart';

Widget montar() => ProviderScope(
      overrides: [
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ],
      child: const MaterialApp(home: Shell()),
    );

Future<void> comLargura(WidgetTester tester, double largura) async {
  tester.view.physicalSize = Size(largura, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('usa NavigationRail no desktop', (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montar());
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('usa NavigationBar no mobile', (tester) async {
    await comLargura(tester, 420);
    await tester.pumpWidget(montar());
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('seletor de mes avanca e volta', (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montar());
    await tester.pump();

    final container = ProviderScope.containerOf(
        tester.element(find.byType(Shell)));
    container.read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));
    await tester.pump();

    expect(find.text('Agosto/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mes_proximo')));
    await tester.pump();
    expect(find.text('Setembro/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mes_anterior')));
    await tester.tap(find.byKey(const Key('mes_anterior')));
    await tester.pump();
    expect(find.text('Julho/2026'), findsOneWidget);
  });

  testWidgets('barra de totais mostra zeros com repositorios vazios',
      (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('total_ganhos')), findsOneWidget);
    expect(find.byKey(const Key('total_gastos')), findsOneWidget);
    expect(find.byKey(const Key('total_saldo')), findsOneWidget);
  });
}
