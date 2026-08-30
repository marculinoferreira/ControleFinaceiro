import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/ui/widgets/formulario_responsivo.dart';

Future<void> comLargura(WidgetTester tester, double largura) async {
  tester.view.physicalSize = Size(largura, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Botao que abre o formulario e guarda o valor devolvido, para o teste
/// conseguir observar o retorno.
Widget montar(List<String?> capturado) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final r = await mostrarFormulario<String>(
                context: context,
                titulo: 'Novo ganho',
                construir: (c) => ElevatedButton(
                  onPressed: () => Navigator.of(c).pop('salvou'),
                  child: const Text('Salvar'),
                ),
              );
              capturado.add(r);
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('desktop abre um AlertDialog', (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montar([]));

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Novo ganho'), findsOneWidget);
  });

  testWidgets('mobile abre um bottom sheet', (tester) async {
    await comLargura(tester, 420);
    await tester.pumpWidget(montar([]));

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Novo ganho'), findsOneWidget);
  });

  testWidgets('devolve o valor passado ao pop, no desktop', (tester) async {
    final capturado = <String?>[];
    await comLargura(tester, 1400);
    await tester.pumpWidget(montar(capturado));

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(capturado, ['salvou']);
  });

  testWidgets('devolve o valor passado ao pop, no mobile', (tester) async {
    final capturado = <String?>[];
    await comLargura(tester, 420);
    await tester.pumpWidget(montar(capturado));

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(capturado, ['salvou']);
  });

  testWidgets('dispensar sem salvar devolve null', (tester) async {
    final capturado = <String?>[];
    await comLargura(tester, 1400);
    await tester.pumpWidget(montar(capturado));

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    // Toca fora do dialogo para dispensar.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(capturado, [null]);
  });
}
