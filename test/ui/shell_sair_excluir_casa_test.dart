import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorio_gestao_casa.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dados/servico_auth.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/app.dart';
import 'package:controle_financeiro/ui/shell.dart';
import 'package:controle_financeiro/ui/telas/tela_criar_casa.dart';

/// Cobre a correcao de casaIdProvider ficar preso ao id antigo depois de
/// sair/excluir a casa com sucesso (achado 4 da revisao final): sem o
/// `ref.invalidate(casaIdProvider)` em Shell, o app continuava mostrando o
/// Shell inacessivel em vez de voltar para a tela de criar casa.
void main() {
  Casa casaComDoisMembros() => const Casa(
        id: 'casa-1',
        nome: 'Casa X',
        donoEmail: 'dono@example.com',
        membros: [
          Membro(id: 'm-dono', nome: 'Dono', email: 'dono@example.com', cor: '#000', ordem: 0),
          Membro(id: 'm-bia', nome: 'Bia', email: 'bia@example.com', cor: '#111', ordem: 1),
        ],
      );

  Casa casaDeUmDono() => const Casa(
        id: 'casa-1',
        nome: 'Casa X',
        donoEmail: 'dono@example.com',
        membros: [
          Membro(id: 'm-dono', nome: 'Dono', email: 'dono@example.com', cor: '#000', ordem: 0),
        ],
      );

  Widget montar({
    required Casa casa,
    required String emailLogado,
    required RepositorioGestaoCasaFake gestao,
  }) {
    final auth = AuthFake()..entrar(email: emailLogado, senha: 'x');
    return ProviderScope(
      overrides: [
        servicoAuthProvider.overrideWithValue(auth),
        repositorioGestaoCasaProvider.overrideWithValue(gestao),
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake()),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ],
      child: const App(),
    );
  }

  testWidgets(
    'sair da casa com sucesso invalida casaIdProvider e sai do Shell',
    (tester) async {
      final gestao = RepositorioGestaoCasaFake()..casaIdAtual = 'casa-1';

      await tester.pumpWidget(montar(
        casa: casaComDoisMembros(),
        emailLogado: 'bia@example.com',
        gestao: gestao,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Shell), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu_conta')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('opcao_sair_casa')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sim'));
      await tester.pumpAndSettle();

      expect(gestao.chamadas, ['sairDaCasa']);
      expect(find.byType(Shell), findsNothing);
      expect(find.byType(TelaCriarCasa), findsOneWidget);
    },
  );

  testWidgets(
    'excluir casa com sucesso invalida casaIdProvider e sai do Shell',
    (tester) async {
      final gestao = RepositorioGestaoCasaFake()..casaIdAtual = 'casa-1';

      await tester.pumpWidget(montar(
        casa: casaDeUmDono(),
        emailLogado: 'dono@example.com',
        gestao: gestao,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Shell), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu_conta')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('opcao_excluir_casa')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sim'));
      await tester.pumpAndSettle();

      expect(gestao.chamadas, ['excluirCasa']);
      expect(find.byType(Shell), findsNothing);
      expect(find.byType(TelaCriarCasa), findsOneWidget);
    },
  );
}
