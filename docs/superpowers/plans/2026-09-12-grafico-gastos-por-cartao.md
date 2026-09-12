# Gráfico "Gastos por cartão" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar um sétimo gráfico à tela de Gráficos — uma rosca mostrando o total de gastos do mês por cartão/conta (`Cartao`), respeitando o filtro de pessoa (`visaoProvider`).

**Architecture:** Segue exatamente o padrão já usado pelo gráfico "Gastos por pote": uma função de domínio pura que agrupa `Gasto` por `cartaoId` (`somarGastosPorCartao`), uma função que transforma esse mapa em `Fatia` (`fatiasPorCartao`, reaproveitando o helper `_fatiar` já existente), dois providers Riverpod que encadeiam essas funções aos dados ao vivo, e um widget `MolduraGrafico` que desenha a rosca. Como `Cartao` não tem cor própria, as fatias usam uma paleta fixa ciclada pela ordem de cadastro.

**Tech Stack:** Flutter 3.41.5 / Dart 3.11.3, Riverpod (`Provider.autoDispose`, `StreamProvider`), `fl_chart` (`PieChart`), `flutter_test`.

## Global Constraints

- Gasto com `cartaoId` nulo ou apontando para um cartão apagado cai na chave `''`, mesma convenção já usada em `_passaNoCartao` (`lib/estado/providers.dart:450`).
- O rótulo da fatia órfã deste gráfico é "Sem cartão" (não "Outros" — reaproveita `_fatiar` com um parâmetro novo, não duplica a função).
- Cores das fatias vêm da paleta fixa `paletaCartoes` (mesmos tons de `_paleta` em `lib/ui/telas/tela_potes.dart:18`), ciclada por índice — nenhum campo novo em `Cartao`.
- O gráfico respeita `visaoProvider` (filtro de pessoa), igual ao gráfico de pote.
- Novo gráfico é o 7º item de `_graficos` em `TelaGraficos`, ao final da lista — os seis originais da spec 10 não mudam de posição nem de comportamento.
- Spec de referência: `docs/superpowers/specs/2026-09-12-grafico-gastos-por-cartao-design.md`.

---

### Task 1: Domínio — somar e fatiar gastos por cartão

**Files:**
- Modify: `lib/dominio/totais.dart`
- Modify: `lib/dominio/graficos.dart`
- Test: `test/dominio/totais_test.dart`
- Test: `test/dominio/graficos_test.dart`

**Interfaces:**
- Produces: `Map<String, double> somarGastosPorCartao(List<Gasto> gastos, {String? membroId})` em `lib/dominio/totais.dart`.
- Produces: `const List<String> paletaCartoes` em `lib/dominio/graficos.dart`.
- Produces: `List<Fatia> fatiasPorCartao({required Map<String, double> porCartao, required List<Cartao> cartoes})` em `lib/dominio/graficos.dart`.
- Consumes: `Fatia` (já existe em `lib/dominio/graficos.dart`), `Cartao` (já existe em `lib/dominio/models/cartao.dart`, campos `id`, `nome`, `ordem`), `toleranciaCentavo` (já importado em `graficos.dart` via `cascata.dart`).

- [ ] **Step 1: Escrever os testes que falham para `somarGastosPorCartao`**

Em `test/dominio/totais_test.dart`, primeiro adicione `cartaoId` ao helper `gasto` (ele não tem esse parâmetro hoje):

```dart
Gasto gasto(
  String membroId,
  String poteId,
  double valor, {
  String mesRef = '2026-08',
  bool parcelado = false,
  String? cartaoId,
}) =>
    Gasto(
      id: 'x${valor.toInt()}',
      mesRef: mesRef,
      membroId: membroId,
      poteId: poteId,
      descricao: 'Compra',
      valor: valor,
      criadoEm: DateTime.utc(2026, 8, 1),
      parcelado: parcelado,
      cartaoId: cartaoId,
      compraId: parcelado ? 'c1' : null,
      parcela: parcelado ? 1 : null,
      totalParcelas: parcelado ? 5 : null,
    );
```

Depois, adicione um novo `group` no fim do `main()`, antes do `group('comprometidoNoMes', ...)` ou depois — a ordem entre groups não importa:

```dart
  group('somarGastosPorCartao', () {
    test('agrupa por cartao somando o casal', () {
      final gastosComCartao = [
        gasto('marcos', 'p1', 1200, cartaoId: 'nubank'),
        gasto('marcos', 'p2', 300, cartaoId: 'nubank'),
        gasto('silvia', 'p1', 800, cartaoId: 'inter'),
      ];
      expect(somarGastosPorCartao(gastosComCartao),
          {'nubank': 1500.0, 'inter': 800.0});
    });

    test('gasto sem cartao cai na chave vazia', () {
      final gastosComCartao = [
        gasto('marcos', 'p1', 1200, cartaoId: 'nubank'),
        gasto('marcos', 'p2', 300),
      ];
      expect(somarGastosPorCartao(gastosComCartao),
          {'nubank': 1200.0, '': 300.0});
    });

    test('filtra por membro quando pedido', () {
      final gastosComCartao = [
        gasto('marcos', 'p1', 1200, cartaoId: 'nubank'),
        gasto('silvia', 'p1', 800, cartaoId: 'nubank'),
      ];
      expect(somarGastosPorCartao(gastosComCartao, membroId: 'marcos'),
          {'nubank': 1200.0});
    });

    test('lista vazia devolve mapa vazio', () {
      expect(somarGastosPorCartao(const []), isEmpty);
    });
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/dominio/totais_test.dart`
Expected: FAIL — `somarGastosPorCartao` não existe (erro de compilação).

- [ ] **Step 3: Implementar `somarGastosPorCartao`**

Em `lib/dominio/totais.dart`, adicione logo depois de `somarGastosPorPote`:

```dart
/// Soma por cartao, com a mesma convencao de `_passaNoCartao`: gasto sem
/// cartao (ou com um cartao que foi apagado) cai na chave ''.
Map<String, double> somarGastosPorCartao(List<Gasto> gastos,
    {String? membroId}) {
  final mapa = <String, double>{};
  for (final g in gastos) {
    if (membroId != null && g.membroId != membroId) continue;
    final chave = g.cartaoId ?? '';
    mapa[chave] = (mapa[chave] ?? 0) + g.valor;
  }
  return mapa;
}
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/dominio/totais_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/dominio/totais.dart test/dominio/totais_test.dart
git commit -m "feat: soma gastos por cartao"
```

- [ ] **Step 6: Escrever os testes que falham para `fatiasPorCartao`**

Em `test/dominio/graficos_test.dart`, adicione o import e a lista de cartões no topo (depois dos imports existentes):

```dart
import 'package:controle_financeiro/dominio/models/cartao.dart';
```

```dart
const cartoes = [
  Cartao(id: 'nubank', nome: 'Nubank', ordem: 0),
  Cartao(id: 'inter', nome: 'Inter', ordem: 1),
];
```

Adicione um novo `group` dentro de `main()`, junto dos outros (por exemplo, depois de `group('fatiasPorMembro', ...)`):

```dart
  group('fatiasPorCartao', () {
    test('uma fatia por cartao, na ordem cadastrada, com cor da paleta', () {
      final fatias = fatiasPorCartao(
        porCartao: const {'inter': 300, 'nubank': 700},
        cartoes: cartoes,
      );

      expect(fatias.map((f) => f.id).toList(), ['nubank', 'inter']);
      expect(fatias.map((f) => f.valor).toList(), [700, 300]);
      expect(fatias[0].cor, paletaCartoes[0]);
      expect(fatias[1].cor, paletaCartoes[1]);
    });

    test('cartao sem gasto nao vira fatia', () {
      final fatias = fatiasPorCartao(
        porCartao: const {'nubank': 700},
        cartoes: cartoes,
      );

      expect(fatias, hasLength(1));
    });

    test('gasto sem cartao (chave vazia) cai em Sem cartao, no fim', () {
      final fatias = fatiasPorCartao(
        porCartao: const {'nubank': 700, '': 50},
        cartoes: cartoes,
      );

      expect(fatias, hasLength(2));
      expect(fatias.last.nome, 'Sem cartão');
      expect(fatias.last.valor, 50);
    });

    test('gasto de cartao apagado tambem cai em Sem cartao', () {
      final fatias = fatiasPorCartao(
        porCartao: const {'nubank': 700, 'fantasma': 30},
        cartoes: cartoes,
      );

      expect(fatias.last.nome, 'Sem cartão');
      expect(fatias.last.valor, 30);
    });

    test('sem gasto nenhum devolve lista vazia', () {
      expect(fatiasPorCartao(porCartao: const {}, cartoes: cartoes), isEmpty);
    });

    test('mais cartoes que cores na paleta cicla de volta ao inicio', () {
      final muitosCartoes = [
        for (var i = 0; i < paletaCartoes.length + 1; i++)
          Cartao(id: 'c$i', nome: 'Cartao $i', ordem: i),
      ];
      final porCartao = {for (final c in muitosCartoes) c.id: 10.0};

      final fatias =
          fatiasPorCartao(porCartao: porCartao, cartoes: muitosCartoes);

      expect(fatias.first.cor, fatias.last.cor);
    });
  });
```

- [ ] **Step 7: Rodar os testes e confirmar que falham**

Run: `flutter test test/dominio/graficos_test.dart`
Expected: FAIL — `fatiasPorCartao` e `paletaCartoes` não existem (erro de compilação).

- [ ] **Step 8: Implementar `paletaCartoes` e `fatiasPorCartao`, e generalizar `_fatiar`**

Em `lib/dominio/graficos.dart`, adicione o import do modelo `Cartao` junto dos demais (ordem alfabética):

```dart
import 'cascata.dart';
import 'models/cartao.dart';
import 'models/membro.dart';
import 'models/pote.dart';
```

Dê a `_fatiar` um parâmetro opcional `nomeOrfaos`, para o bucket desconhecido poder se chamar "Sem cartão" aqui sem duplicar a função. Ela hoje é (por volta da linha 91):

```dart
List<Fatia> _fatiar({
  required Map<String, double> valores,
  required List<String> ids,
  required Map<String, String> nome,
  required Map<String, String> cor,
}) {
```

Troque por:

```dart
List<Fatia> _fatiar({
  required Map<String, double> valores,
  required List<String> ids,
  required Map<String, String> nome,
  required Map<String, String> cor,
  String nomeOrfaos = 'Outros',
}) {
```

E troque a linha que cria a fatia órfã (por volta da linha 118):

```dart
    fatias.add(Fatia(id: '', nome: 'Outros', cor: corNeutra, valor: orfaos));
```

por:

```dart
    fatias.add(Fatia(id: '', nome: nomeOrfaos, cor: corNeutra, valor: orfaos));
```

`fatiasPorPote` e `fatiasPorMembro` não mudam: como não passam `nomeOrfaos`, continuam usando o default `'Outros'`.

Por fim, adicione ao final do arquivo (depois de `serieVazia`):

```dart
/// Paleta fixa para entidades sem cor propria (Cartao). Mesmos tons de
/// `tela_potes.dart`, para a rosca de cartao nao destoar do resto do app.
const List<String> paletaCartoes = [
  '#2E7D32', '#1565C0', '#00838F', '#EF6C00', '#AD1457', '#4527A0',
];

/// Fatias da rosca de gastos por cartao (fora da numeracao da spec 10).
///
/// Cartao nao tem cor propria como Pote/Membro; a cor de cada fatia vem da
/// paleta fixa, ciclada pela ordem de cadastro.
List<Fatia> fatiasPorCartao({
  required Map<String, double> porCartao,
  required List<Cartao> cartoes,
}) {
  final ordenados = [...cartoes]..sort((a, b) => a.ordem.compareTo(b.ordem));
  return _fatiar(
    valores: porCartao,
    ids: [for (final c in ordenados) c.id],
    nome: {for (final c in ordenados) c.id: c.nome},
    cor: {
      for (final (i, c) in ordenados.indexed)
        c.id: paletaCartoes[i % paletaCartoes.length]
    },
    nomeOrfaos: 'Sem cartão',
  );
}
```

- [ ] **Step 9: Rodar os testes e confirmar que passam**

Run: `flutter test test/dominio/graficos_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo os já existentes de `fatiasPorPote`/`fatiasPorMembro` — confirma que `nomeOrfaos` não quebrou o comportamento default).

- [ ] **Step 10: Commit**

```bash
git add lib/dominio/graficos.dart test/dominio/graficos_test.dart
git commit -m "feat: fatias de gastos por cartao, com paleta fixa e bucket Sem cartao"
```

---

### Task 2: Estado e widget — rosca de gastos por cartão

**Files:**
- Modify: `lib/estado/providers.dart`
- Create: `lib/ui/widgets/graficos/rosca_por_cartao.dart`
- Test: `test/ui/graficos_por_cartao_test.dart` (novo arquivo)

**Interfaces:**
- Consumes: `somarGastosPorCartao` e `fatiasPorCartao` (Task 1), `cartoesProvider`, `gastosDoMesProvider`, `mesSelecionadoProvider`, `visaoProvider`, `combinarAsyncValues` (já existem em `lib/estado/providers.dart`).
- Produces: `gastosPorCartaoProvider` (`Provider.autoDispose<AsyncValue<Map<String, double>>>`) e `fatiasPorCartaoProvider` (`Provider.autoDispose<AsyncValue<List<Fatia>>>`) em `lib/estado/providers.dart`.
- Produces: widget `RoscaPorCartao` (`ConsumerWidget`, sem parâmetros) em `lib/ui/widgets/graficos/rosca_por_cartao.dart`, consumido pela Task 3.

- [ ] **Step 1: Escrever o teste de widget que falha**

Crie `test/ui/graficos_por_cartao_test.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/cartao.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';
import 'package:controle_financeiro/ui/widgets/graficos/rosca_por_cartao.dart';
import 'package:controle_financeiro/ui/widgets/legenda_grafico.dart';

const casa = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
    Membro(
        id: 'marcos',
        nome: 'Marcos',
        email: 'm@x.com',
        cor: '#2E7D32',
        ordem: 0),
    Membro(
        id: 'silvia',
        nome: 'Silvia',
        email: 's@x.com',
        cor: '#6A1B9A',
        ordem: 1),
  ],
);

const cartoes = [
  Cartao(id: 'nubank', nome: 'Nubank', ordem: 0),
  Cartao(id: 'inter', nome: 'Inter', ordem: 1),
];

/// (membroId, cartaoId ou null, valor)
typedef Lancamento = (String, String?, double);

Future<ProviderContainer> montar(
  WidgetTester tester, {
  List<Lancamento> gastosDoMes = const [],
  List<Cartao> comCartoes = cartoes,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final gastos = RepositorioGastosFake();

  for (final (membroId, cartaoId, valor) in gastosDoMes) {
    await gastos.adicionar(
      base: Gasto(
        id: '',
        mesRef: '2026-08',
        membroId: membroId,
        poteId: 'p1',
        descricao: 'Compra',
        valor: valor,
        criadoEm: DateTime.utc(2026, 8, 2),
        parcelado: false,
        cartaoId: cartaoId,
      ),
      quantidadeParcelas: 1,
    );
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake()),
    repositorioCartoesProvider
        .overrideWithValue(RepositorioCartoesFake(comCartoes)),
    repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
    repositorioGastosProvider.overrideWithValue(gastos),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(cartoesProvider, (_, _) {});
  container.listen(casaProvider, (_, _) {});
  container.listen(gastosDoMesProvider('2026-08'), (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: RoscaPorCartao())),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

List<PieChartSectionData> secoes(WidgetTester tester) =>
    tester.widget<PieChart>(find.byType(PieChart)).data.sections;

void main() {
  group('rosca de gastos por cartao', () {
    testWidgets('uma secao por cartao com gasto', (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', 'inter', 300),
      ]);

      expect(secoes(tester), hasLength(2));
      expect(secoes(tester).map((s) => s.value).toList(), [700, 300]);
    });

    testWidgets('cada secao usa a cor da paleta fixa', (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', 'inter', 300),
      ]);

      expect(secoes(tester)[0].color, const Color(0xFF2E7D32));
      expect(secoes(tester)[1].color, const Color(0xFF1565C0));
    });

    testWidgets('mostra o total no centro', (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', 'inter', 300),
      ]);

      expect(find.text(formatarReais(1000)), findsOneWidget);
    });

    testWidgets('gasto sem cartao vira Sem cartao, sem quebrar',
        (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', null, 50),
      ]);

      expect(secoes(tester), hasLength(2));
      expect(find.text('Sem cartão'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sem gastos mostra a frase e nao desenha a rosca',
        (tester) async {
      await montar(tester);

      expect(find.byType(PieChart), findsNothing);
      expect(find.text('Nenhum gasto neste mês.'), findsOneWidget);
    });

    testWidgets('a legenda tem um item por cartao', (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', 'inter', 300),
      ]);

      expect(find.byType(MarcadorLegenda), findsNWidgets(2));
      expect(find.text('Nubank'), findsOneWidget);
    });

    testWidgets('respeita a visao selecionada', (tester) async {
      final container = await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('silvia', 'inter', 300),
      ]);

      expect(secoes(tester), hasLength(2));

      container.read(visaoProvider.notifier).selecionar('marcos');
      await tester.pumpAndSettle();

      // So o gasto do Marcos sobra.
      expect(secoes(tester), hasLength(1));
      expect(secoes(tester).single.value, 700);
    });
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/ui/graficos_por_cartao_test.dart`
Expected: FAIL — `gastosPorCartaoProvider`, `fatiasPorCartaoProvider` e `RoscaPorCartao` não existem (erro de compilação).

- [ ] **Step 3: Adicionar os dois providers**

Em `lib/estado/providers.dart`, insira depois de `serieComprometimentoProvider` (que termina com `});` logo antes de `final parcelasEmAbertoProvider = ...`):

```dart
/// Gastos do mes somados por cartao, ja respeitando a visao selecionada.
///
/// Fora da numeracao da spec 10 (grafico extra).
final gastosPorCartaoProvider =
    Provider.autoDispose<AsyncValue<Map<String, double>>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);

  return ref
      .watch(gastosDoMesProvider(mes))
      .whenData((gastos) => somarGastosPorCartao(gastos, membroId: membroId));
});

/// Fatias da rosca de gastos por cartao (grafico extra, fora da spec 10).
final fatiasPorCartaoProvider =
    Provider.autoDispose<AsyncValue<List<Fatia>>>((ref) {
  return combinarAsyncValues(
    ref.watch(cartoesProvider),
    ref.watch(gastosPorCartaoProvider),
    (cartoes, porCartao) =>
        fatiasPorCartao(porCartao: porCartao, cartoes: cartoes),
  );
});
```

- [ ] **Step 4: Criar o widget `RoscaPorCartao`**

Crie `lib/ui/widgets/graficos/rosca_por_cartao.dart`, cópia estrutural de `rosca_por_pote.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../../tema/tema.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';

/// Gastos por cartao — grafico extra, fora da numeracao da spec 10.
///
/// Mesma linguagem visual da rosca de pote: furo central com o total, para
/// a pessoa nao precisar somar as fatias de cabeca.
class RoscaPorCartao extends ConsumerWidget {
  const RoscaPorCartao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSelecionadoProvider).valor;

    return MolduraGrafico<List<Fatia>>(
      titulo: 'Gastos por cartão',
      vazio: 'Nenhum gasto neste mês.',
      dados: ref.watch(fatiasPorCartaoProvider),
      estaVazio: (f) => f.isEmpty,
      aoRecarregar: () {
        ref.invalidate(cartoesProvider);
        ref.invalidate(gastosDoMesProvider(mes));
      },
      legenda: (fatias) => [
        for (final f in fatias)
          ItemLegenda(rotulo: f.nome, cor: corDeHex(f.cor)),
      ],
      construir: (fatias) => _Rosca(fatias: fatias),
    );
  }
}

class _Rosca extends StatelessWidget {
  final List<Fatia> fatias;
  const _Rosca({required this.fatias});

  @override
  Widget build(BuildContext context) {
    final total = totalDasFatias(fatias);

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            centerSpaceRadius: 52,
            sectionsSpace: 2,
            sections: [
              for (final f in fatias)
                PieChartSectionData(
                  value: f.valor,
                  color: corDeHex(f.cor),
                  radius: 46,
                  title: _percentual(f.valor, total),
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total', style: Theme.of(context).textTheme.bodySmall),
            Text(
              formatarReais(total),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  /// Fatia menor que 5% nao recebe rotulo: o texto sairia maior que ela.
  String _percentual(double valor, double total) {
    if (total <= 0) return '';
    final pct = valor / total * 100;
    return pct < 5 ? '' : '${pct.toStringAsFixed(0)}%';
  }
}
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `flutter test test/ui/graficos_por_cartao_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/estado/providers.dart lib/ui/widgets/graficos/rosca_por_cartao.dart test/ui/graficos_por_cartao_test.dart
git commit -m "feat: grafico de gastos por cartao (rosca)"
```

---

### Task 3: Ligar o gráfico na tela de Gráficos

**Files:**
- Modify: `lib/ui/telas/tela_graficos.dart`
- Modify: `test/ui/tela_graficos_test.dart`

**Interfaces:**
- Consumes: `RoscaPorCartao` (Task 2).

- [ ] **Step 1: Atualizar as expectativas do teste de composição para 7 gráficos**

Em `test/ui/tela_graficos_test.dart`, some o import:

```dart
import 'package:controle_financeiro/ui/widgets/graficos/rosca_por_cartao.dart';
```

(A lista alfabética de imports já tem `rosca_por_pote.dart`; não é necessário, mas mantenha a ordem se preferir — não é obrigatório pois o arquivo não usa o tipo diretamente, só via `TelaGraficos`.)

Troque cada `findsNWidgets(6)` por `findsNWidgets(7)` nos seguintes testes (são 4 ocorrências):

```dart
    testWidgets('mostra os seis graficos da spec', (tester) async {
      await montar(tester);

      expect(molduras, findsNWidgets(7));
    });
```

```dart
      // Os seis continuam montados.
      expect(molduras, findsNWidgets(7));
```
(dentro de `'um provider quebrado nao apaga os outros graficos'`)

```dart
      expect(find.byKey(const Key('graficos_coluna_unica')), findsOneWidget);
      expect(find.byKey(const Key('graficos_coluna_esquerda')), findsNothing);
      expect(molduras, findsNWidgets(7));
```
(dentro de `'mobile usa coluna unica'`)

```dart
    testWidgets('os seis mostram frase de vazio, nenhum desenho quebrado',
        (tester) async {
      await montar(tester, comDados: false);

      expect(molduras, findsNWidgets(7));
```
(dentro do `group('mes sem nada', ...)`)

E adicione o título do novo gráfico no teste de ordem dos títulos:

```dart
    testWidgets('os titulos aparecem na ordem da spec 10', (tester) async {
      await montar(tester);

      expect(find.text('Gastos por pote'), findsOneWidget);
      expect(find.text('Previsto × Gasto por pote'), findsOneWidget);
      expect(find.textContaining('Ganhos × gastos'), findsOneWidget);
      expect(find.text('Ganhos por pessoa'), findsOneWidget);
      expect(find.text('Onde o gasto parou'), findsOneWidget);
      expect(find.textContaining('Comprometido'), findsOneWidget);
      expect(find.text('Gastos por cartão'), findsOneWidget);
    });
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/ui/tela_graficos_test.dart`
Expected: FAIL — os testes esperam 7 molduras/o título "Gastos por cartão", mas `TelaGraficos` ainda só monta 6.

- [ ] **Step 3: Adicionar `RoscaPorCartao` à lista de gráficos**

Em `lib/ui/telas/tela_graficos.dart`, adicione o import:

```dart
import '../widgets/graficos/rosca_por_cartao.dart';
```

E adicione o widget ao final de `_graficos`:

```dart
  static const _graficos = <Widget>[
    RoscaPorPote(),
    BarrasPrevistoGasto(),
    LinhaEvolucao(),
    PizzaGanhos(),
    BarraCascata(),
    LinhaComprometimento(),
    RoscaPorCartao(),
  ];
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/ui/tela_graficos_test.dart`
Expected: PASS

- [ ] **Step 5: Rodar a suíte inteira**

Run: `flutter test`
Expected: PASS — nenhuma regressão nos outros gráficos ou telas.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/telas/tela_graficos.dart test/ui/tela_graficos_test.dart
git commit -m "feat: adiciona Gastos por cartao a tela de graficos"
```

- [ ] **Step 7: Compilar para Windows e verificar visualmente**

Run: `flutter build windows`
Expected: build sem erros (se o executável anterior estiver rodando, encerre o processo `controle_financeiro.exe` antes — `taskkill /F /IM controle_financeiro.exe`).

Abra `build\windows\x64\runner\Release\controle_financeiro.exe`, vá em Gráficos e confirme que a nova rosca "Gastos por cartão" aparece ao final da lista, some corretamente e responde ao seletor de pessoa.
