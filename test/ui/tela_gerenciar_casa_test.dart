import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorio_gestao_casa.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/telas/tela_gerenciar_casa.dart';

void main() {
  Casa casaComDono() => const Casa(
        id: 'casa-1',
        nome: 'Casa X',
        donoEmail: 'dono@example.com',
        membros: [
          Membro(id: 'm-dono', nome: 'Dono', email: 'dono@example.com', cor: '#000', ordem: 0),
          Membro(id: 'm-bia', nome: 'Bia', email: 'bia@example.com', cor: '#111', ordem: 1),
        ],
      );

  testWidgets('dono ve o botao de convidar e a lista de membros ativos',
      (tester) async {
    final gestao = RepositorioGestaoCasaFake();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casaComDono())),
          repositorioGestaoCasaProvider.overrideWithValue(gestao),
        ],
        child: MaterialApp(home: TelaGerenciarCasa(casaId: 'casa-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bia'), findsOneWidget);
    expect(find.byKey(const Key('botao_convidar')), findsOneWidget);
  });

  testWidgets('convidar chama o repositorio com o email digitado', (tester) async {
    final gestao = RepositorioGestaoCasaFake();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casaComDono())),
          repositorioGestaoCasaProvider.overrideWithValue(gestao),
        ],
        child: MaterialApp(home: TelaGerenciarCasa(casaId: 'casa-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('botao_convidar')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_email_convite')), 'novo@example.com');
    await tester.enterText(find.byKey(const Key('campo_nome_convite')), 'Novo');
    await tester.tap(find.byKey(const Key('botao_confirmar_convite')));
    await tester.pumpAndSettle();

    expect(gestao.chamadas, ['convidarMembro:novo@example.com']);
  });

  testWidgets('remover chama o repositorio com o membroId', (tester) async {
    final gestao = RepositorioGestaoCasaFake();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casaComDono())),
          repositorioGestaoCasaProvider.overrideWithValue(gestao),
        ],
        child: MaterialApp(home: TelaGerenciarCasa(casaId: 'casa-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('remover_m-bia')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await tester.pumpAndSettle();

    expect(gestao.chamadas, ['removerMembro:m-bia']);
  });
}
