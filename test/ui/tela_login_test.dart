import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/servico_auth.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/telas/tela_login.dart';

Widget montar(ServicoAuth auth) => ProviderScope(
      overrides: [servicoAuthProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: TelaLogin()),
    );

void main() {
  testWidgets('mostra erro quando a senha esta errada', (tester) async {
    final auth = AuthFake(erroAoEntrar: 'Senha incorreta.');
    await tester.pumpWidget(montar(auth));

    await tester.enterText(
        find.byKey(const Key('campo_email')), 'marcos.centrone@gmail.com');
    await tester.enterText(find.byKey(const Key('campo_senha')), 'errada');
    await tester.tap(find.byKey(const Key('botao_entrar')));
    await tester.pumpAndSettle();

    expect(find.text('Senha incorreta.'), findsOneWidget);
  });

  testWidgets('nao chama o servico com campos vazios', (tester) async {
    final auth = AuthFake();
    await tester.pumpWidget(montar(auth));

    await tester.tap(find.byKey(const Key('botao_entrar')));
    await tester.pumpAndSettle();

    expect(auth.tentativas, 0);
    expect(find.text('Informe o e-mail.'), findsOneWidget);
  });

  testWidgets('chama o servico com os dados digitados', (tester) async {
    final auth = AuthFake();
    await tester.pumpWidget(montar(auth));

    await tester.enterText(
        find.byKey(const Key('campo_email')), 'marcos.centrone@gmail.com');
    await tester.enterText(find.byKey(const Key('campo_senha')), 'segredo123');
    await tester.tap(find.byKey(const Key('botao_entrar')));
    await tester.pumpAndSettle();

    expect(auth.tentativas, 1);
    expect(auth.ultimoEmail, 'marcos.centrone@gmail.com');
  });

  testWidgets('desabilita o botao enquanto autentica', (tester) async {
    final auth = AuthFake(demora: const Duration(milliseconds: 200));
    await tester.pumpWidget(montar(auth));

    await tester.enterText(
        find.byKey(const Key('campo_email')), 'marcos.centrone@gmail.com');
    await tester.enterText(find.byKey(const Key('campo_senha')), 'segredo123');
    await tester.tap(find.byKey(const Key('botao_entrar')));
    await tester.pump(); // inicia, ainda nao terminou

    final botao = tester.widget<FilledButton>(
        find.byKey(const Key('botao_entrar')));
    expect(botao.onPressed, isNull);

    await tester.pumpAndSettle();
  });
}
