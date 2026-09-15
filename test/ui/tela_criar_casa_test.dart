import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorio_gestao_casa.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dados/servico_auth.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/app.dart';

void main() {
  testWidgets('sem casa mostra a tela de criar casa, com casa mostra o shell',
      (tester) async {
    final auth = AuthFake()..entrar(email: 'nova@example.com', senha: 'x');
    final gestao = RepositorioGestaoCasaFake();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicoAuthProvider.overrideWithValue(auth),
          repositorioGestaoCasaProvider.overrideWithValue(gestao),
          repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
          repositorioPotesProvider.overrideWithValue(RepositorioPotesFake()),
          repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
          repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
          repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criar sua casa'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_nome_membro')), 'Ana');
    await tester.enterText(find.byKey(const Key('campo_nome_casa')), 'Casa da Ana');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('botao_criar_casa')));
    await tester.pumpAndSettle();

    expect(find.text('Criar sua casa'), findsNothing);
    expect(gestao.chamadas, ['criarCasa:Casa da Ana:Ana']);
  });

  testWidgets('botao so habilita com os dois campos preenchidos',
      (tester) async {
    final auth = AuthFake()..entrar(email: 'nova@example.com', senha: 'x');
    final gestao = RepositorioGestaoCasaFake();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicoAuthProvider.overrideWithValue(auth),
          repositorioGestaoCasaProvider.overrideWithValue(gestao),
          repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
          repositorioPotesProvider.overrideWithValue(RepositorioPotesFake()),
          repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
          repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
          repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    FilledButton botao() =>
        tester.widget(find.byKey(const Key('botao_criar_casa')));

    expect(botao().onPressed, isNull);

    await tester.enterText(find.byKey(const Key('campo_nome_casa')), 'Casa da Ana');
    await tester.pumpAndSettle();
    expect(botao().onPressed, isNull);

    await tester.enterText(find.byKey(const Key('campo_nome_membro')), 'Ana');
    await tester.pumpAndSettle();
    expect(botao().onPressed, isNotNull);

    await tester.enterText(find.byKey(const Key('campo_nome_membro')), '');
    await tester.pumpAndSettle();
    expect(botao().onPressed, isNull);
    expect(gestao.chamadas, isEmpty);
  });
}
