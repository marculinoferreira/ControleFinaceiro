import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/ui/widgets/primeira_maiuscula.dart';

/// Aplica o formatador como o campo de texto aplicaria.
TextEditingValue formatar(String antes, String depois, {int? cursor}) {
  const f = PrimeiraMaiuscula();
  return f.formatEditUpdate(
    TextEditingValue(text: antes),
    TextEditingValue(
      text: depois,
      selection: TextSelection.collapsed(offset: cursor ?? depois.length),
    ),
  );
}

void main() {
  group('PrimeiraMaiuscula', () {
    test('deixa a primeira letra maiuscula', () {
      expect(formatar('', 'feira').text, 'Feira');
    });

    test('so a primeira: as demais palavras ficam como digitadas', () {
      // "Pneus Dakar" estragaria "Conta de luz".
      expect(formatar('', 'pneus dakar').text, 'Pneus dakar');
    });

    test('nao mexe no que ja esta maiusculo', () {
      expect(formatar('', 'Feira').text, 'Feira');
    });

    test('preserva o resto da caixa, inclusive siglas', () {
      expect(formatar('', 'conta de IPTU').text, 'Conta de IPTU');
    });

    test('texto vazio passa sem erro', () {
      expect(formatar('', '').text, '');
    });

    test('numero ou simbolo no inicio nao quebra', () {
      expect(formatar('', '123 pila').text, '123 pila');
      expect(formatar('', '#feira').text, '#feira');
    });

    test('acentuada tambem sobe', () {
      expect(formatar('', 'agua').text, 'Agua');
      expect(formatar('', 'ótica').text, 'Ótica');
    });

    test('o cursor nao pula para o fim ao digitar no meio', () {
      // Digitando no meio de "feira", o cursor estava na posicao 3.
      final r = formatar('feira', 'feiXra', cursor: 4);
      expect(r.text, 'FeiXra');
      expect(r.selection.baseOffset, 4);
    });

    test('apagar tudo volta a string vazia sem erro', () {
      expect(formatar('Feira', '').text, '');
    });
  });

  group('no campo de texto', () {
    testWidgets('digitar minusculo mostra maiusculo', (tester) async {
      final controlador = TextEditingController();
      addTearDown(controlador.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TextField(
            key: const Key('campo'),
            controller: controlador,
            inputFormatters: const [PrimeiraMaiuscula()],
          ),
        ),
      ));

      await tester.enterText(find.byKey(const Key('campo')), 'padaria');
      await tester.pumpAndSettle();

      expect(controlador.text, 'Padaria');
      expect(find.text('Padaria'), findsOneWidget);
    });
  });

  group('localizacao', () {
    testWidgets('o MaterialApp declara pt-BR', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('pt', 'BR'),
        supportedLocales: [Locale('pt', 'BR')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: SizedBox()),
      ));
      await tester.pumpAndSettle();

      final contexto = tester.element(find.byType(Scaffold));
      final loc = MaterialLocalizations.of(contexto);

      // Se o delegate global nao estivesse ativo, viria "Cancel".
      expect(loc.cancelButtonLabel, 'Cancelar');
      expect(loc.okButtonLabel, 'OK');
    });
  });
}
