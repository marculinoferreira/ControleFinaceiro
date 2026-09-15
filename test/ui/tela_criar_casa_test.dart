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
    await tester.tap(find.byKey(const Key('botao_criar_casa')));
    await tester.pumpAndSettle();

    expect(find.text('Criar sua casa'), findsNothing);
    expect(gestao.chamadas, ['criarCasa:Casa da Ana:Ana']);
  });

  testWidgets('nao envia sem informar o proprio nome', (tester) async {
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

    await tester.enterText(find.byKey(const Key('campo_nome_casa')), 'Casa da Ana');
    await tester.tap(find.byKey(const Key('botao_criar_casa')));
    await tester.pumpAndSettle();

    expect(find.text('Informe seu nome ou apelido.'), findsOneWidget);
    expect(gestao.chamadas, isEmpty);
  });
}
