import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';
import 'package:controle_financeiro/ui/widgets/campo_moeda.dart';

void main() {
  group('parsearMoeda', () {
    test('texto vazio devolve null, nao zero', () {
      expect(parsearMoeda(''), isNull);
    });

    test('texto sem digito devolve null', () {
      expect(parsearMoeda('abc'), isNull);
    });

    test('os digitos sao centavos', () {
      expect(parsearMoeda('1234'), 12.34);
      expect(parsearMoeda('5'), 0.05);
    });

    test('zero e um valor, nao ausencia', () {
      expect(parsearMoeda('0'), 0.0);
    });

    test('ignora simbolo, ponto e virgula', () {
      expect(parsearMoeda(r'R$ 1.234,56'), 1234.56);
    });

    test('ida e volta com formatarReais preserva o valor', () {
      for (final v in [0.0, 0.05, 12.34, 1234.56, 999999.99]) {
        expect(parsearMoeda(formatarReais(v)), v, reason: 'falhou para $v');
      }
    });

    test('digitos demais devolvem null em vez de estourar', () {
      expect(parsearMoeda('9' * 40), isNull);
    });
  });

  group('CampoMoeda', () {
    Widget montar(TextEditingController c) => MaterialApp(
          home: Scaffold(body: CampoMoeda(controlador: c)),
        );

    testWidgets('digitar numeros monta o valor da direita para a esquerda',
        (tester) async {
      final c = TextEditingController();
      await tester.pumpWidget(montar(c));

      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.pump();

      expect(c.text, contains('123,45'));
      expect(parsearMoeda(c.text), 123.45);
    });

    testWidgets('apagar tudo deixa o campo vazio', (tester) async {
      final c = TextEditingController();
      await tester.pumpWidget(montar(c));

      await tester.enterText(find.byType(TextFormField), '999');
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();

      expect(c.text, isEmpty);
      expect(parsearMoeda(c.text), isNull);
    });

    testWidgets('o validador padrao recusa zero', (tester) async {
      final c = TextEditingController();
      final chave = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Form(key: chave, child: CampoMoeda(controlador: c)),
        ),
      ));

      await tester.enterText(find.byType(TextFormField), '0');
      expect(chave.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
    });

    testWidgets('o validador padrao aceita valor positivo', (tester) async {
      final c = TextEditingController();
      final chave = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Form(key: chave, child: CampoMoeda(controlador: c)),
        ),
      ));

      await tester.enterText(find.byType(TextFormField), '150');
      expect(chave.currentState!.validate(), isTrue);
    });
  });
}
