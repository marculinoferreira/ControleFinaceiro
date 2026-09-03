import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dados/servico_auth.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/telas/formulario_gasto.dart';

const casa = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
    // Marcos e o primeiro da lista de proposito: assim o teste da Silvia
    // falha se o padrao voltar a ser "o primeiro membro".
    Membro(
        id: 'marcos',
        nome: 'Marcos',
        email: 'marcos@x.com',
        cor: '#2E7D32',
        ordem: 0),
    Membro(
        id: 'silvia',
        nome: 'Silvia',
        email: 'silvia@x.com',
        cor: '#6A1B9A',
        ordem: 1),
  ],
);

const potes = [
  Pote(
      id: 'p1',
      nome: 'Custo fixo',
      percentual: 100,
      ordem: 0,
      cor: '#2E7D32',
      icone: 'casa'),
];

/// Abre o formulario de gasto novo com [emailLogado] autenticado.
Future<void> abrirNovoGasto(WidgetTester tester, String? emailLogado) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final auth = AuthFake();
  if (emailLogado != null) {
    await auth.entrar(email: emailLogado, senha: 'segredo123');
  }

  final container = ProviderContainer(overrides: [
    servicoAuthProvider.overrideWithValue(auth),
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
    repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(potesProvider, (_, _) {});
  container.listen(cartoesProvider, (_, _) {});
  container.listen(casaProvider, (_, _) {});
  container.listen(emailLogadoProvider, (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('abrir_formulario'),
              onPressed: () => abrirFormularioGasto(context: context, ref: ref),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('abrir_formulario')));
  await tester.pumpAndSettle();
}

/// O nome mostrado no seletor "De quem".
String deQuem(WidgetTester tester) {
  final campo = find.byKey(const Key('gasto_membro'));
  final texto = find.descendant(of: campo, matching: find.byType(Text));
  // O primeiro Text do campo e o rotulo flutuante; o nome vem depois.
  return tester
      .widgetList<Text>(texto)
      .map((t) => t.data)
      .firstWhere((d) => d != null && d != 'De quem', orElse: () => null)!;
}

void main() {
  group('"De quem" num gasto novo comeca em quem esta logado', () {
    testWidgets('Marcos logado abre com Marcos', (tester) async {
      await abrirNovoGasto(tester, 'marcos@x.com');
      expect(deQuem(tester), 'Marcos');
    });

    testWidgets('Silvia logada abre com Silvia, nao com o primeiro da lista',
        (tester) async {
      await abrirNovoGasto(tester, 'silvia@x.com');
      expect(deQuem(tester), 'Silvia');
    });

    testWidgets('e-mail de fora da casa cai no primeiro membro',
        (tester) async {
      await abrirNovoGasto(tester, 'visita@x.com');
      expect(deQuem(tester), 'Marcos');
      expect(tester.takeException(), isNull);
    });

    testWidgets('sem ninguem logado cai no primeiro membro', (tester) async {
      await abrirNovoGasto(tester, null);
      expect(deQuem(tester), 'Marcos');
      expect(tester.takeException(), isNull);
    });
  });
}
