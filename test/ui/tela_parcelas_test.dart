import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';
import 'package:controle_financeiro/ui/telas/tela_parcelas.dart';

/// Fake cujo observar() emite erro -- achado 5 (leitura assincrona sem os
/// tres ramos de AsyncValue.when).
class _PotesFakeQueErra implements RepositorioPotes {
  @override
  Stream<List<Pote>> observar() => Stream.error(Exception('sem permissao'));

  @override
  Future<void> salvarTodos(List<Pote> potes) async {}

  @override
  Future<void> remover(String id) async {}
}

const casa = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
    Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
        cor: '#2E7D32', ordem: 0),
  ],
);

const potes = [
  Pote(id: 'p2', nome: 'Conforto', percentual: 100, ordem: 0,
      cor: '#1565C0', icone: 'sofa'),
];

Gasto base(String descricao) => Gasto(
      id: '',
      mesRef: '2026-08',
      membroId: 'marcos',
      poteId: 'p2',
      descricao: descricao,
      valor: 100,
      criadoEm: DateTime.utc(2026, 8, 1),
      parcelado: false,
    );

Future<void> montar(
  WidgetTester tester,
  Future<void> Function(RepositorioGastosFake) semear, {
  Size tamanho = const Size(1400, 1200),
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = RepositorioGastosFake();
  await semear(repo);

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
    repositorioGastosProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Scaffold(body: TelaParcelas())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sem parcelas mostra a mensagem de vazio', (tester) async {
    await montar(tester, (_) async {});

    expect(find.textContaining('Nenhuma compra parcelada'), findsOneWidget);
  });

  testWidgets('mostra a compra parcelada com parcela atual e restantes',
      (tester) async {
    await montar(tester, (repo) async {
      await repo.adicionar(base: base('Geladeira'), quantidadeParcelas: 10);
    });

    expect(find.text('Geladeira'), findsOneWidget);
    expect(find.text('1/10'), findsOneWidget);
    expect(find.textContaining('9'), findsWidgets); // faltam 9 meses
  });

  testWidgets('gasto simples nao aparece', (tester) async {
    await montar(tester, (repo) async {
      await repo.adicionar(base: base('Mercado'), quantidadeParcelas: 1);
    });

    expect(find.text('Mercado'), findsNothing);
    expect(find.textContaining('Nenhuma compra parcelada'), findsOneWidget);
  });

  testWidgets('a ordem padrao agora e por data de vencimento', (tester) async {
    await montar(tester, (repo) async {
      await repo.adicionar(base: base('Longa'), quantidadeParcelas: 12);
      await repo.adicionar(base: base('Curta'), quantidadeParcelas: 3);
    });

    // Antes a tela vinha ordenada por parcelas restantes ("quita primeiro").
    // Com o seletor de ordem, o padrao passou a ser Data, como em Gastos.
    // As duas compras tem a mesma data aqui, entao caem no mesmo grupo e a
    // ordem interna e alfabetica.
    final textos = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    expect(textos.indexOf('Curta'), lessThan(textos.indexOf('Longa')));
  });

  testWidgets(
      'achado 5 — erro ao carregar potes mostra aviso em vez de ids crus',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = RepositorioGastosFake();
    await repo.adicionar(base: base('Geladeira'), quantidadeParcelas: 10);

    final container = ProviderContainer(
      // Sem isto, o StreamProvider agenda retries automaticos com Timer
      // apos o erro, e o teste falharia com "Timer is still pending" apos
      // o dispose.
      retry: (_, _) => null,
      overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
        repositorioPotesProvider.overrideWithValue(_PotesFakeQueErra()),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGastosProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: TelaParcelas())),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nao foi possivel carregar'), findsOneWidget);
    // Sem a correcao, a compra aparece com o id cru do pote em vez de sumir
    // atras de um estado de erro.
    expect(find.text('p2'), findsNothing);
  });

  testWidgets('mostra o total do grupo somando o valor por mes de cada compra',
      (tester) async {
    await montar(tester, (repo) async {
      await repo.adicionar(base: base('Geladeira'), quantidadeParcelas: 10);
      await repo.adicionar(base: base('Sofa'), quantidadeParcelas: 5);
    });

    // As duas compras usam base(), com a mesma data -> mesmo grupo (ver o
    // teste "a ordem padrao agora e por data de vencimento" acima, que já
    // documenta essa coincidencia). valorParcela de cada uma e 100 (o
    // valor de base()), total do grupo 200. No desktop o valor do total vai
    // sob a coluna Valor/mês (colunaDoTotal), separado da celula "Total".
    // Como so ha um grupo, o total dele coincide com a somatoria geral (200
    // tambem) -> duas celulas com o mesmo valor.
    expect(find.text('Total'), findsOneWidget);
    expect(find.text(formatarReais(200)), findsNWidgets(2));
  });

  testWidgets('mostra a somatoria geral de todas as compras parceladas',
      (tester) async {
    await montar(tester, (repo) async {
      await repo.adicionar(base: base('Geladeira'), quantidadeParcelas: 10);
      await repo.adicionar(base: base('Sofa'), quantidadeParcelas: 5);
    });

    // As duas compras usam base(), com a mesma data -> caem no mesmo grupo
    // (ver o teste "a ordem padrao..." acima). valorParcela de cada uma e
    // 100, soma geral = 200 -- igual ao total desse unico grupo, entao
    // formatarReais(200) aparece duas vezes (total do grupo + somatoria
    // geral), mas so uma tem o rotulo "Somatória total".
    expect(find.text('Somatória total'), findsOneWidget);
    expect(find.text(formatarReais(200)), findsNWidgets(2));
  });

  testWidgets(
      'card (mobile) mostra pessoa | pote | cartao · parcela · faltam, e o valor destacado',
      (tester) async {
    await montar(
      tester,
      (repo) async {
        await repo.adicionar(base: base('Geladeira'), quantidadeParcelas: 10);
      },
      tamanho: const Size(420, 1400),
    );

    expect(find.text('Marcos'), findsOneWidget);
    expect(find.text('Conforto'), findsOneWidget);
    expect(find.textContaining('1/10'), findsOneWidget);
    expect(find.textContaining('9 meses'), findsOneWidget);
    // Sem cartao aqui (base() nao define cartaoId): pessoa | pote | parcela
    // | faltam -- tres separadores.
    expect(find.text('|'), findsNWidgets(3));
    expect(find.text(formatarReais(100)), findsOneWidget);
  });
}
