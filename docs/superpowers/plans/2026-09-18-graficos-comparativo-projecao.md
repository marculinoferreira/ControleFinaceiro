# Gráficos: abas Comparativo e Projeção — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar duas visões novas à tela de Gráficos — Comparativo (Marcos × Silvia) e Projeção (saldo dos próximos 12 meses) — escolhidas por um segundo seletor, sem alterar os sete gráficos existentes da Visão Geral.

**Architecture:** Reaproveita ao máximo a lógica de domínio já existente (`comprometidoNoMes`, `somarGastosPorPote`, `somarGastosPorCartao`, `janelaDe`, `MolduraGrafico`). O que é novo: duas funções de domínio puras (comparativo por pote/cartão, projeção de saldo), um conjunto de providers Riverpod que as alimentam filtrando por `membroId`, quatro widgets de gráfico seguindo o molde já estabelecido (`BarrasPrevistoGasto`/`LinhaComprometimento`), e a tela de Gráficos reestruturada para trocar a lista de gráficos exibida conforme um novo seletor de 3 opções.

**Tech Stack:** Flutter, Riverpod (`Provider`/`NotifierProvider`/`.autoDispose`), fl_chart (`BarChart`, `LineChart`), Dart puro para o domínio.

**Spec:** `docs/superpowers/specs/2026-09-18-graficos-comparativo-projecao-design.md`

## Global Constraints

- Nenhuma mudança nos sete gráficos da Visão Geral nem no `visaoProvider`/`_SeletorVisao` em si — só quando e como eles aparecem.
- `Comparativo` sempre compara exatamente 2 pessoas (a casa já é limitada a 2 integrantes); com 0 ou 1 membro ativo, a opção "Comparativo" não aparece no seletor de 3.
- Nenhuma escrita nova: as três abas só leem dados que já existem (ganhos, gastos, parcelas).
- Cor das barras "por pessoa" usa `Membro.cor` (via `corDeHex`); cor das barras "por pote"/"por cartão" usa a cor do próprio pote/cartão (mesma paleta de sempre).
- Janela de 12 meses para Comparativo (linha) e Projeção usa a mesma constante `mesesDaSerie` e a mesma função `janelaDe` que o gráfico de Comprometido já usa — sem inventar outra janela.
- Todo provider assíncrono novo passa pelos três ramos de `AsyncValue` (via `combinarAsyncValues`/`.whenData`), nunca `.value ?? []`.

---

## Task 1: Domínio — barras comparativas por pote e por cartão

**Files:**
- Modify: `lib/dominio/graficos.dart`
- Test: `test/dominio/graficos_test.dart`

**Interfaces:**
- Consumes: `toleranciaCentavo` (de `cascata.dart`, já importado no arquivo), `corNeutra`, `paletaCartoes` (já existem em `graficos.dart`), `Pote`, `Cartao` (models já importados).
- Produces:
  - `class BarraComparativa { String id; String nome; String cor; double valorA; double valorB; }`
  - `List<BarraComparativa> barrasComparativasPorPote({required Map<String, double> porPoteA, required Map<String, double> porPoteB, required List<Pote> potes})`
  - `List<BarraComparativa> barrasComparativasPorCartao({required Map<String, double> porCartaoA, required Map<String, double> porCartaoB, required List<Cartao> cartoes})`

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/dominio/graficos_test.dart` (o arquivo já importa `graficos.dart`, `Cartao`, `Pote` e já declara `const potes`/`const cartoes` no topo — reaproveite essas constantes):

```dart
  group('barrasComparativasPorPote', () {
    test('uma barra por pote, na ordem de prioridade, com os dois valores', () {
      final barras = barrasComparativasPorPote(
        porPoteA: const {'p1': 700},
        porPoteB: const {'p1': 300, 'p2': 200},
        potes: potes,
      );

      expect(barras.map((b) => b.id).toList(), ['p1', 'p2']);
      expect(barras[0].valorA, 700);
      expect(barras[0].valorB, 300);
      expect(barras[0].nome, 'Custo fixo');
      expect(barras[0].cor, '#2E7D32');
      expect(barras[1].valorA, 0);
      expect(barras[1].valorB, 200);
    });

    test('pote sem gasto de nenhuma das duas pessoas nao entra', () {
      final barras = barrasComparativasPorPote(
        porPoteA: const {'p1': 700},
        porPoteB: const {},
        potes: potes,
      );

      expect(barras, hasLength(1));
      expect(barras.single.id, 'p1');
    });

    test('pote com gasto de so uma das duas ainda entra', () {
      final barras = barrasComparativasPorPote(
        porPoteA: const {},
        porPoteB: const {'p2': 200},
        potes: potes,
      );

      expect(barras, hasLength(1));
      expect(barras.single.id, 'p2');
      expect(barras.single.valorA, 0);
      expect(barras.single.valorB, 200);
    });

    test('gasto em pote apagado de qualquer uma das duas cai em Outros', () {
      final barras = barrasComparativasPorPote(
        porPoteA: const {'p1': 700, 'fantasma': 50},
        porPoteB: const {'fantasma2': 20},
        potes: potes,
      );

      expect(barras, hasLength(2));
      expect(barras.last.nome, 'Outros');
      expect(barras.last.valorA, 50);
      expect(barras.last.valorB, 20);
    });
  });

  group('barrasComparativasPorCartao', () {
    test('uma barra por cartao, na ordem cadastrada, com cor da paleta', () {
      final barras = barrasComparativasPorCartao(
        porCartaoA: const {'inter': 300, 'nubank': 700},
        porCartaoB: const {'nubank': 100},
        cartoes: cartoes,
      );

      expect(barras.map((b) => b.id).toList(), ['nubank', 'inter']);
      expect(barras[0].valorA, 700);
      expect(barras[0].valorB, 100);
      expect(barras[0].cor, paletaCartoes[0]);
      expect(barras[1].valorA, 300);
      expect(barras[1].valorB, 0);
    });

    test('gasto sem cartao (chave vazia) de qualquer uma cai em Sem cartao', () {
      final barras = barrasComparativasPorCartao(
        porCartaoA: const {'nubank': 700, '': 50},
        porCartaoB: const {},
        cartoes: cartoes,
      );

      expect(barras.last.nome, 'Sem cartão');
      expect(barras.last.valorA, 50);
      expect(barras.last.valorB, 0);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/dominio/graficos_test.dart
```
Esperado: falha em `barrasComparativasPorPote`/`barrasComparativasPorCartao` não definidos (erro de compilação).

- [ ] **Step 3: Implementar**

Em `lib/dominio/graficos.dart`, adicione ao final do arquivo:

```dart
/// Uma barra do Comparativo: o que ela representa e quanto cada uma das
/// duas pessoas da casa gastou nela.
class BarraComparativa {
  final String id;
  final String nome;
  final String cor;
  final double valorA;
  final double valorB;

  const BarraComparativa({
    required this.id,
    required this.nome,
    required this.cor,
    required this.valorA,
    required this.valorB,
  });
}

/// Miolo do Comparativo, no mesmo espirito de `_fatiar`: ordena pela lista
/// dada, ignora quem nao tem gasto de nenhum dos dois lados, agrega
/// desconhecidos numa barra "Outros"/"Sem cartao" no fim.
List<BarraComparativa> _barrar({
  required Map<String, double> valoresA,
  required Map<String, double> valoresB,
  required List<String> ids,
  required Map<String, String> nome,
  required Map<String, String> cor,
  String nomeOrfaos = 'Outros',
}) {
  final conhecidos = ids.toSet();
  final barras = <BarraComparativa>[];

  for (final id in ids) {
    final a = valoresA[id] ?? 0;
    final b = valoresB[id] ?? 0;
    if (a <= toleranciaCentavo && b <= toleranciaCentavo) continue;
    barras.add(BarraComparativa(
      id: id,
      nome: nome[id] ?? id,
      cor: cor[id] ?? corNeutra,
      valorA: a,
      valorB: b,
    ));
  }

  var orfaosA = 0.0, orfaosB = 0.0;
  for (final entrada in valoresA.entries) {
    if (!conhecidos.contains(entrada.key)) orfaosA += entrada.value;
  }
  for (final entrada in valoresB.entries) {
    if (!conhecidos.contains(entrada.key)) orfaosB += entrada.value;
  }
  if (orfaosA > toleranciaCentavo || orfaosB > toleranciaCentavo) {
    barras.add(BarraComparativa(
      id: '',
      nome: nomeOrfaos,
      cor: corNeutra,
      valorA: orfaosA,
      valorB: orfaosB,
    ));
  }

  return barras;
}

/// Gasto por pote, pessoa A x pessoa B (aba Comparativo).
List<BarraComparativa> barrasComparativasPorPote({
  required Map<String, double> porPoteA,
  required Map<String, double> porPoteB,
  required List<Pote> potes,
}) {
  final ordenados = [...potes]..sort((a, b) => a.ordem.compareTo(b.ordem));
  return _barrar(
    valoresA: porPoteA,
    valoresB: porPoteB,
    ids: [for (final p in ordenados) p.id],
    nome: {for (final p in ordenados) p.id: p.nome},
    cor: {for (final p in ordenados) p.id: p.cor},
  );
}

/// Gasto por cartao, pessoa A x pessoa B (aba Comparativo).
List<BarraComparativa> barrasComparativasPorCartao({
  required Map<String, double> porCartaoA,
  required Map<String, double> porCartaoB,
  required List<Cartao> cartoes,
}) {
  final ordenados = [...cartoes]..sort((a, b) => a.ordem.compareTo(b.ordem));
  return _barrar(
    valoresA: porCartaoA,
    valoresB: porCartaoB,
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

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/dominio/graficos_test.dart
```
Esperado: todos os testes passam, incluindo os já existentes (`fatiasPorPote`, `fatiasPorCartao` etc. — não foram tocados).

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/dominio/graficos.dart
git add lib/dominio/graficos.dart test/dominio/graficos_test.dart
git commit -m "feat: barras comparativas por pote e por cartao (dominio)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: Domínio — série de projeção de saldo

**Files:**
- Modify: `lib/dominio/serie_mensal.dart`
- Test: `test/dominio/serie_mensal_test.dart`

**Interfaces:**
- Consumes: `MesRef`, `Gasto` (já importados), `comprometidoNoMes` (de `totais.dart`, já importado em `serie_mensal.dart`), `janelaDe` (já existe no mesmo arquivo).
- Produces:
  - `class PontoProjecao { MesRef mes; double ganhos; double gastos; double get saldo; }`
  - `List<PontoProjecao> serieProjecao({required List<MesRef> meses, required double ganhoMensalAssumido, required List<Gasto> parcelas, String? membroId})`

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/dominio/serie_mensal_test.dart` (o arquivo já importa `serie_mensal.dart`, `Gasto`, `MesRef`, e já tem o helper `parcela(mesRef, valor, {n})` dentro do `group('serieComprometimento', ...)` — repita um helper local equivalente dentro do novo group, já que cada group deste arquivo é independente):

```dart
  group('serieProjecao', () {
    Gasto parcela(String mesRef, double valor, {String membroId = 'marcos'}) =>
        Gasto(
          id: 'p-$mesRef-$membroId',
          mesRef: mesRef,
          membroId: membroId,
          poteId: 'p1',
          descricao: 'geladeira',
          valor: valor,
          criadoEm: DateTime.utc(2026, 1, 1),
          parcelado: true,
          compraId: 'c1',
          parcela: 1,
          totalParcelas: 2,
        );

    test('renda repete o valor assumido em todos os meses', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 3),
        ganhoMensalAssumido: 5000,
        parcelas: const [],
      );

      expect(serie.map((p) => p.ganhos).toList(), [5000, 5000, 5000]);
    });

    test('gasto e o comprometido em parcelas daquele mes', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 3),
        ganhoMensalAssumido: 5000,
        parcelas: [parcela('2026-08', 100), parcela('2026-09', 100)],
      );

      expect(serie.map((p) => p.gastos).toList(), [100, 100, 0]);
    });

    test('saldo e ganhos menos gastos', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 1),
        ganhoMensalAssumido: 5000,
        parcelas: [parcela('2026-08', 6000)],
      );

      expect(serie.single.saldo, -1000);
    });

    test('filtra por membroId quando informado', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 1),
        ganhoMensalAssumido: 3000,
        parcelas: [
          parcela('2026-08', 100, membroId: 'marcos'),
          parcela('2026-08', 200, membroId: 'silvia'),
        ],
        membroId: 'silvia',
      );

      expect(serie.single.gastos, 200);
    });

    test('sem parcela nenhuma, gasto fica zero em todos os meses', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 2),
        ganhoMensalAssumido: 5000,
        parcelas: const [],
      );

      expect(serie.every((p) => p.gastos == 0), isTrue);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/dominio/serie_mensal_test.dart
```
Esperado: falha por `PontoProjecao`/`serieProjecao` não definidos.

- [ ] **Step 3: Implementar**

Em `lib/dominio/serie_mensal.dart`, adicione ao final do arquivo:

```dart
/// Um mes projetado: renda repetida do mes de referencia, gasto = o que ja
/// esta comprometido em parcelas naquele mes.
class PontoProjecao {
  final MesRef mes;
  final double ganhos;
  final double gastos;

  const PontoProjecao({
    required this.mes,
    required this.ganhos,
    required this.gastos,
  });

  double get saldo => ganhos - gastos;
}

/// Projeta [meses] a frente assumindo renda constante (o ganho real do mes
/// de referencia, repetido) contra o gasto ja comprometido em parcelas.
///
/// Nao e previsao nem media: e a mesma renda de hoje, os mesmos
/// compromissos ja lancados -- a pergunta que responde e "se nada mudar,
/// sobra ou falta dinheiro nos proximos meses". Compromisso futuro sai de
/// graca de `comprometidoNoMes`, o mesmo calculo do grafico de
/// Comprometido.
List<PontoProjecao> serieProjecao({
  required List<MesRef> meses,
  required double ganhoMensalAssumido,
  required List<Gasto> parcelas,
  String? membroId,
}) =>
    [
      for (final mes in meses)
        PontoProjecao(
          mes: mes,
          ganhos: ganhoMensalAssumido,
          gastos: comprometidoNoMes(parcelas, mes.valor, membroId: membroId),
        ),
    ];
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/dominio/serie_mensal_test.dart
```

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/dominio/serie_mensal.dart
git add lib/dominio/serie_mensal.dart test/dominio/serie_mensal_test.dart
git commit -m "feat: serie de projecao de saldo (dominio)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: Estado — seletor de aba e a dupla comparativa

**Files:**
- Modify: `lib/estado/providers.dart`
- Test: `test/estado/providers_test.dart`

**Interfaces:**
- Consumes: `membrosAtivosProvider` (já existe em `providers.dart`), `Membro` (já importado).
- Produces:
  - `enum TipoVisaoGraficos { geral, comparativo, projecao }`
  - `class TipoVisaoGraficosNotifier extends Notifier<TipoVisaoGraficos>` com método `selecionar(TipoVisaoGraficos tipo)`
  - `final tipoVisaoGraficosProvider = NotifierProvider<TipoVisaoGraficosNotifier, TipoVisaoGraficos>(...)`
  - `final duplaComparativaProvider = Provider<List<Membro>>(...)` — devolve exatamente 2 membros (ordenados por `Membro.ordem`) ou lista vazia.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/estado/providers_test.dart`, dentro de `void main() { ... }` (antes do `}` final, no mesmo nível dos outros `group`s):

```dart
  group('tipoVisaoGraficosProvider', () {
    test('comeca em geral', () {
      final c = ProviderContainer();
      expect(c.read(tipoVisaoGraficosProvider), TipoVisaoGraficos.geral);
      c.dispose();
    });

    test('selecionar muda o tipo', () {
      final c = ProviderContainer();
      c.read(tipoVisaoGraficosProvider.notifier)
          .selecionar(TipoVisaoGraficos.projecao);
      expect(c.read(tipoVisaoGraficosProvider), TipoVisaoGraficos.projecao);
      c.dispose();
    });
  });

  group('duplaComparativaProvider', () {
    test('casa com 2 membros ativos devolve os dois, na ordem cadastrada', () async {
      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          const Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              Membro(id: 'silvia', nome: 'Silvia', email: 's@x.com',
                  cor: '#6A1B9A', ordem: 1),
              Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                  cor: '#2E7D32', ordem: 0),
            ],
          ),
        )),
      ]);
      c.listen(casaProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final dupla = c.read(duplaComparativaProvider);
      expect(dupla.map((m) => m.id).toList(), ['marcos', 'silvia']);
      c.dispose();
    });

    test('casa com 1 membro ativo devolve lista vazia', () async {
      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          const Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                  cor: '#2E7D32', ordem: 0),
            ],
          ),
        )),
      ]);
      c.listen(casaProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(c.read(duplaComparativaProvider), isEmpty);
      c.dispose();
    });

    test('membro removido nao entra na dupla', () async {
      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              const Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                  cor: '#2E7D32', ordem: 0),
              Membro(id: 'silvia', nome: 'Silvia', email: 's@x.com',
                  cor: '#6A1B9A', ordem: 1, removidoEm: DateTime.utc(2026, 1, 1)),
            ],
          ),
        )),
      ]);
      c.listen(casaProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(c.read(duplaComparativaProvider), isEmpty);
      c.dispose();
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/estado/providers_test.dart
```
Esperado: falha por `tipoVisaoGraficosProvider`/`TipoVisaoGraficos`/`duplaComparativaProvider` não definidos.

- [ ] **Step 3: Implementar**

Em `lib/estado/providers.dart`, adicione (perto de `visaoProvider`/`VisaoNotifier`, já que é um provider da mesma família de "estado de UI da tela de gráficos/resumo"):

```dart
enum TipoVisaoGraficos { geral, comparativo, projecao }

/// Qual das 3 visoes da tela de Graficos esta selecionada. Sempre comeca em
/// `geral` -- trocar de mes ou reabrir a tela nao deve prender a pessoa
/// numa aba que ela nao escolheu conscientemente.
class TipoVisaoGraficosNotifier extends Notifier<TipoVisaoGraficos> {
  @override
  TipoVisaoGraficos build() => TipoVisaoGraficos.geral;

  void selecionar(TipoVisaoGraficos tipo) => state = tipo;
}

final tipoVisaoGraficosProvider =
    NotifierProvider<TipoVisaoGraficosNotifier, TipoVisaoGraficos>(
        TipoVisaoGraficosNotifier.new);

/// Os dois integrantes ativos, na ordem de `Membro.ordem` -- a mesma ordem
/// que a pizza de ganhos ja usa. Lista vazia quando a casa tem 0 ou 1
/// pessoa ativa (a UI esconde a aba Comparativo nesse caso). Nunca mais que
/// 2: a casa ja e limitada a isso, entao nao ha terceiro integrante pra
/// decidir quem entra.
final duplaComparativaProvider = Provider<List<Membro>>((ref) {
  final ativos = [...ref.watch(membrosAtivosProvider)]
    ..sort((a, b) => a.ordem.compareTo(b.ordem));
  return ativos.length == 2 ? ativos : const [];
});
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/estado/providers_test.dart
```

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/estado/providers.dart
git add lib/estado/providers.dart test/estado/providers_test.dart
git commit -m "feat: seletor de tipo de visao e dupla comparativa (estado)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Estado — dados do Comparativo

**Files:**
- Modify: `lib/estado/providers.dart`
- Test: `test/estado/providers_test.dart`

**Interfaces:**
- Consumes: `duplaComparativaProvider` (Task 3), `barrasComparativasPorPote`/`barrasComparativasPorCartao` (Task 1), `serieComprometimento` (já existe), `somarGastosPorPote`/`somarGastosPorCartao` (já existem em `totais.dart`), `mesSelecionadoProvider`, `potesProvider`, `cartoesProvider`, `gastosDoMesProvider`, `parceladosDesdeProvider`, `janelaDe`, `mesesDaSerie`, `combinarAsyncValues` (todos já existem).
- Produces:
  - `final barrasPoteComparativoProvider = Provider.autoDispose<AsyncValue<List<BarraComparativa>>>(...)`
  - `final barrasCartaoComparativoProvider = Provider.autoDispose<AsyncValue<List<BarraComparativa>>>(...)`
  - `final serieComprometimentoComparativoProvider = Provider.autoDispose<AsyncValue<(List<PontoComprometido>, List<PontoComprometido>)>>(...)`

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/estado/providers_test.dart`:

```dart
  group('dados do Comparativo', () {
    Future<ProviderContainer> montarComparativo({
      List<(String membroId, String poteId, double valor)> gastosDoMes = const [],
      List<(String membroId, String mesRef, double valor)> parcelas = const [],
    }) async {
      final gastos = RepositorioGastosFake();

      for (final (membroId, poteId, valor) in gastosDoMes) {
        await gastos.adicionar(
          base: Gasto(
            id: '', mesRef: '2026-08', membroId: membroId, poteId: poteId,
            descricao: 'Compra', valor: valor,
            criadoEm: DateTime.utc(2026, 8, 2), parcelado: false,
          ),
          quantidadeParcelas: 1,
        );
      }
      for (final (membroId, mesRef, valor) in parcelas) {
        await gastos.adicionar(
          base: Gasto(
            id: '', mesRef: mesRef, membroId: membroId, poteId: 'p1',
            descricao: 'Parcelada', valor: valor,
            criadoEm: DateTime.utc(2026, 1, 1), parcelado: true,
            compraId: 'c1', parcela: 1, totalParcelas: 2,
          ),
          quantidadeParcelas: 1,
        );
      }

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          const Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                  cor: '#2E7D32', ordem: 0),
              Membro(id: 'silvia', nome: 'Silvia', email: 's@x.com',
                  cor: '#6A1B9A', ordem: 1),
            ],
          ),
        )),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(gastos),
      ]);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      c.listen(casaProvider, (_, _) {});
      c.listen(potesProvider, (_, _) {});
      c.listen(gastosDoMesProvider('2026-08'), (_, _) {});
      c.listen(parceladosDesdeProvider('2026-08'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('barrasPoteComparativo soma o gasto de cada pessoa por pote', () async {
      final c = await montarComparativo(gastosDoMes: [
        ('marcos', 'p1', 700),
        ('silvia', 'p1', 300),
      ]);
      addTearDown(c.dispose);

      final barras = c.read(barrasPoteComparativoProvider).requireValue;
      expect(barras.single.valorA, 700); // marcos, ordem 0
      expect(barras.single.valorB, 300); // silvia, ordem 1
    });

    test('barrasCartaoComparativo soma o gasto de cada pessoa por cartao', () async {
      final c = await montarComparativo();
      addTearDown(c.dispose);
      // Sem cartoes cadastrados e sem gasto, a lista vem vazia -- so
      // confirma que o provider resolve sem erro.
      expect(c.read(barrasCartaoComparativoProvider).hasValue, isTrue);
    });

    test('serieComprometimentoComparativo devolve uma serie por pessoa', () async {
      final c = await montarComparativo(parcelas: [
        ('marcos', '2026-08', 100),
        ('silvia', '2026-08', 250),
      ]);
      addTearDown(c.dispose);

      final (serieA, serieB) =
          c.read(serieComprometimentoComparativoProvider).requireValue;
      expect(serieA.first.valor, 100);
      expect(serieB.first.valor, 250);
    });

    test('com casa de 1 pessoa, os tres providers devolvem vazio', () async {
      final gastos = RepositorioGastosFake();
      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          const Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                  cor: '#2E7D32', ordem: 0),
            ],
          ),
        )),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(gastos),
      ]);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      c.listen(casaProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(c.read(barrasPoteComparativoProvider).requireValue, isEmpty);
      expect(c.read(barrasCartaoComparativoProvider).requireValue, isEmpty);
      final (serieA, serieB) =
          c.read(serieComprometimentoComparativoProvider).requireValue;
      expect(serieA, isEmpty);
      expect(serieB, isEmpty);
      c.dispose();
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/estado/providers_test.dart
```
Esperado: falha por `barrasPoteComparativoProvider`/`barrasCartaoComparativoProvider`/`serieComprometimentoComparativoProvider` não definidos.

- [ ] **Step 3: Implementar**

Em `lib/estado/providers.dart`, logo depois de `duplaComparativaProvider` (Task 3):

```dart
final barrasPoteComparativoProvider =
    Provider.autoDispose<AsyncValue<List<BarraComparativa>>>((ref) {
  final dupla = ref.watch(duplaComparativaProvider);
  if (dupla.length < 2) return const AsyncData([]);
  final mes = ref.watch(mesSelecionadoProvider).valor;

  return combinarAsyncValues(
    ref.watch(potesProvider),
    ref.watch(gastosDoMesProvider(mes)),
    (potes, gastos) => barrasComparativasPorPote(
      porPoteA: somarGastosPorPote(gastos, membroId: dupla[0].id),
      porPoteB: somarGastosPorPote(gastos, membroId: dupla[1].id),
      potes: potes,
    ),
  );
});

final barrasCartaoComparativoProvider =
    Provider.autoDispose<AsyncValue<List<BarraComparativa>>>((ref) {
  final dupla = ref.watch(duplaComparativaProvider);
  if (dupla.length < 2) return const AsyncData([]);
  final mes = ref.watch(mesSelecionadoProvider).valor;

  return combinarAsyncValues(
    ref.watch(cartoesProvider),
    ref.watch(gastosDoMesProvider(mes)),
    (cartoes, gastos) => barrasComparativasPorCartao(
      porCartaoA: somarGastosPorCartao(gastos, membroId: dupla[0].id),
      porCartaoB: somarGastosPorCartao(gastos, membroId: dupla[1].id),
      cartoes: cartoes,
    ),
  );
});

/// (serie de A, serie de B), mesma janela de `serieComprometimentoProvider`.
final serieComprometimentoComparativoProvider = Provider.autoDispose<
    AsyncValue<(List<PontoComprometido>, List<PontoComprometido>)>>((ref) {
  final dupla = ref.watch(duplaComparativaProvider);
  if (dupla.length < 2) return const AsyncData(([], []));
  final inicio = ref.watch(mesSelecionadoProvider);
  final meses = janelaDe(inicio, mesesDaSerie);

  return ref.watch(parceladosDesdeProvider(inicio.valor)).whenData(
        (parcelas) => (
          serieComprometimento(meses: meses, parcelas: parcelas, membroId: dupla[0].id),
          serieComprometimento(meses: meses, parcelas: parcelas, membroId: dupla[1].id),
        ),
      );
});
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/estado/providers_test.dart
```

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/estado/providers.dart
git add lib/estado/providers.dart test/estado/providers_test.dart
git commit -m "feat: providers de dados do Comparativo (estado)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Estado — dados da Projeção

**Files:**
- Modify: `lib/estado/providers.dart`
- Test: `test/estado/providers_test.dart`

**Interfaces:**
- Consumes: `serieProjecao`/`PontoProjecao` (Task 2), `calcularTotais` (já existe em `totais.dart`), `visaoProvider`, `mesSelecionadoProvider`, `ganhosDoMesProvider`, `parceladosDesdeProvider`, `janelaDe`, `mesesDaSerie`, `combinarAsyncValues` (já existem).
- Produces:
  - `final ganhoAssumidoProjecaoProvider = Provider.autoDispose<AsyncValue<double>>(...)`
  - `final serieProjecaoProvider = Provider.autoDispose<AsyncValue<List<PontoProjecao>>>(...)`

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/estado/providers_test.dart`:

```dart
  group('dados da Projecao', () {
    Future<ProviderContainer> montarProjecao({
      double ganhoMarcos = 5000,
      List<(String mesRef, double valor)> parcelas = const [],
    }) async {
      final ganhos = RepositorioGanhosFake();
      final gastos = RepositorioGastosFake();

      if (ganhoMarcos > 0) {
        await ganhos.adicionar(Ganho(
          id: '', mesRef: '2026-08', membroId: 'marcos',
          descricao: 'Salario', valor: ganhoMarcos,
          criadoEm: DateTime.utc(2026, 8, 1),
        ));
      }
      for (final (mesRef, valor) in parcelas) {
        await gastos.adicionar(
          base: Gasto(
            id: '', mesRef: mesRef, membroId: 'marcos', poteId: 'p1',
            descricao: 'Parcelada', valor: valor,
            criadoEm: DateTime.utc(2026, 1, 1), parcelado: true,
            compraId: 'c1', parcela: 1, totalParcelas: 2,
          ),
          quantidadeParcelas: 1,
        );
      }

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(ganhos),
        repositorioGastosProvider.overrideWithValue(gastos),
      ]);
      addTearDown(c.dispose);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      c.listen(ganhosDoMesProvider('2026-08'), (_, _) {});
      c.listen(parceladosDesdeProvider('2026-08'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('ganhoAssumidoProjecao e o total de ganhos do mes selecionado', () async {
      final c = await montarProjecao(ganhoMarcos: 5000);
      expect(c.read(ganhoAssumidoProjecaoProvider).requireValue, 5000);
    });

    test('ganhoAssumidoProjecao respeita a visao selecionada', () async {
      final c = await montarProjecao(ganhoMarcos: 5000);
      c.read(visaoProvider.notifier).selecionar('silvia');
      expect(c.read(ganhoAssumidoProjecaoProvider).requireValue, 0);
    });

    test('serieProjecao repete a renda e usa o comprometido por mes', () async {
      final c = await montarProjecao(
        ganhoMarcos: 5000,
        parcelas: [('2026-08', 100), ('2026-09', 100)],
      );

      final serie = c.read(serieProjecaoProvider).requireValue;
      expect(serie, hasLength(mesesDaSerie));
      expect(serie.every((p) => p.ganhos == 5000), isTrue);
      expect(serie[0].gastos, 100);
      expect(serie[1].gastos, 100);
      expect(serie[2].gastos, 0);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/estado/providers_test.dart
```
Esperado: falha por `ganhoAssumidoProjecaoProvider`/`serieProjecaoProvider` não definidos.

- [ ] **Step 3: Implementar**

Em `lib/estado/providers.dart`, logo depois dos providers do Comparativo (Task 4):

```dart
/// Ganho real do mes selecionado, respeitando a visao -- a renda que a
/// projecao assume constante dali pra frente.
final ganhoAssumidoProjecaoProvider =
    Provider.autoDispose<AsyncValue<double>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);

  return ref.watch(ganhosDoMesProvider(mes)).whenData(
        (ganhos) => calcularTotais(
          ganhos: ganhos,
          gastos: const [],
          membroId: membroId,
        ).ganhos,
      );
});

final serieProjecaoProvider =
    Provider.autoDispose<AsyncValue<List<PontoProjecao>>>((ref) {
  final inicio = ref.watch(mesSelecionadoProvider);
  final membroId = ref.watch(visaoProvider);
  final meses = janelaDe(inicio, mesesDaSerie);

  return combinarAsyncValues(
    ref.watch(ganhoAssumidoProjecaoProvider),
    ref.watch(parceladosDesdeProvider(inicio.valor)),
    (ganhoAssumido, parcelas) => serieProjecao(
      meses: meses,
      ganhoMensalAssumido: ganhoAssumido,
      parcelas: parcelas,
      membroId: membroId,
    ),
  );
});
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/estado/providers_test.dart
```

- [ ] **Step 5: Analisar, rodar a suíte completa e commitar**

```bash
flutter analyze
flutter test
git add lib/estado/providers.dart test/estado/providers_test.dart
git commit -m "feat: providers de dados da Projecao (estado)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: UI — barras comparativas (por pote e por cartão)

**Files:**
- Create: `lib/ui/widgets/graficos/barras_pote_comparativo.dart`
- Create: `lib/ui/widgets/graficos/barras_cartao_comparativo.dart`
- Test: `test/ui/graficos_comparativo_test.dart` (novo arquivo)

**Interfaces:**
- Consumes: `barrasPoteComparativoProvider`/`barrasCartaoComparativoProvider`/`duplaComparativaProvider` (Tasks 3-4), `BarraComparativa` (Task 1), `MolduraGrafico`, `ItemLegenda`, `corDeHex`, `serieVazia` (já existem).
- Produces: `class BarrasPoteComparativo extends ConsumerWidget` e `class BarrasCartaoComparativo extends ConsumerWidget`, cada um sem parâmetros (`const BarrasPoteComparativo({super.key})`).

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/ui/graficos_comparativo_test.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/cartao.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/widgets/graficos/barras_cartao_comparativo.dart';
import 'package:controle_financeiro/ui/widgets/graficos/barras_pote_comparativo.dart';

const casaComDupla = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
    Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
        cor: '#2E7D32', ordem: 0),
    Membro(id: 'silvia', nome: 'Silvia', email: 's@x.com',
        cor: '#6A1B9A', ordem: 1),
  ],
);

const potes = [
  Pote(id: 'p1', nome: 'Custo fixo', percentual: 60, ordem: 0,
      cor: '#2E7D32', icone: 'casa'),
];

const cartoes = [
  Cartao(id: 'nubank', nome: 'Nubank', ordem: 0),
];

/// (membroId, poteId, cartaoId, valor)
typedef Lancamento = (String, String, String?, double);

Future<void> montar(
  WidgetTester tester,
  Widget grafico, {
  List<Lancamento> gastosDoMes = const [],
  Casa casa = casaComDupla,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final gastos = RepositorioGastosFake();
  for (final (membroId, poteId, cartaoId, valor) in gastosDoMes) {
    await gastos.adicionar(
      base: Gasto(
        id: '', mesRef: '2026-08', membroId: membroId, poteId: poteId,
        cartaoId: cartaoId, descricao: 'Compra', valor: valor,
        criadoEm: DateTime.utc(2026, 8, 2), parcelado: false,
      ),
      quantidadeParcelas: 1,
    );
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake(cartoes)),
    repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
    repositorioGastosProvider.overrideWithValue(gastos),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(casaProvider, (_, _) {});
  container.listen(potesProvider, (_, _) {});
  container.listen(cartoesProvider, (_, _) {});
  container.listen(gastosDoMesProvider('2026-08'), (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: grafico)),
    ),
  ));
  await tester.pumpAndSettle();
}

List<BarChartGroupData> grupos(WidgetTester tester) =>
    tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;

void main() {
  group('BarrasPoteComparativo', () {
    testWidgets('dois rods por pote, um pra cada pessoa', (tester) async {
      await montar(tester, const BarrasPoteComparativo(), gastosDoMes: [
        ('marcos', 'p1', null, 700),
        ('silvia', 'p1', null, 300),
      ]);

      expect(grupos(tester), hasLength(1));
      expect(grupos(tester).single.barRods, hasLength(2));
      expect(grupos(tester).single.barRods[0].toY, 700);
      expect(grupos(tester).single.barRods[1].toY, 300);
    });

    testWidgets('a legenda tem os nomes das duas pessoas', (tester) async {
      await montar(tester, const BarrasPoteComparativo(), gastosDoMes: [
        ('marcos', 'p1', null, 700),
      ]);

      expect(find.text('Marcos'), findsOneWidget);
      expect(find.text('Silvia'), findsOneWidget);
    });

    testWidgets('sem gasto de nenhuma das duas mostra a frase', (tester) async {
      await montar(tester, const BarrasPoteComparativo());

      expect(find.byType(BarChart), findsNothing);
      expect(find.textContaining('Nenhum gasto'), findsOneWidget);
    });

    testWidgets('casa com 1 pessoa so mostra a frase, sem desenhar',
        (tester) async {
      await montar(
        tester,
        const BarrasPoteComparativo(),
        casa: const Casa(
          id: 'principal',
          nome: 'Casa',
          membros: [
            Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                cor: '#2E7D32', ordem: 0),
          ],
        ),
        gastosDoMes: [('marcos', 'p1', null, 700)],
      );

      expect(find.byType(BarChart), findsNothing);
    });
  });

  group('BarrasCartaoComparativo', () {
    testWidgets('dois rods por cartao, um pra cada pessoa', (tester) async {
      await montar(tester, const BarrasCartaoComparativo(), gastosDoMes: [
        ('marcos', 'p1', 'nubank', 700),
        ('silvia', 'p1', 'nubank', 300),
      ]);

      expect(grupos(tester), hasLength(1));
      expect(grupos(tester).single.barRods[0].toY, 700);
      expect(grupos(tester).single.barRods[1].toY, 300);
    });

    testWidgets('sem gasto de nenhuma das duas mostra a frase', (tester) async {
      await montar(tester, const BarrasCartaoComparativo());

      expect(find.byType(BarChart), findsNothing);
      expect(find.textContaining('Nenhum gasto'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/ui/graficos_comparativo_test.dart
```
Esperado: falha de compilação — os dois arquivos de widget ainda não existem.

- [ ] **Step 3: Implementar**

Crie `lib/ui/widgets/graficos/barras_pote_comparativo.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../dominio/models/membro.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../../tema/tema.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';

/// Comparativo: gasto por pote, as duas pessoas da casa lado a lado.
class BarrasPoteComparativo extends ConsumerWidget {
  const BarrasPoteComparativo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSelecionadoProvider).valor;
    final dupla = ref.watch(duplaComparativaProvider);

    return MolduraGrafico<List<BarraComparativa>>(
      titulo: 'Gasto por pote',
      vazio: 'Nenhum gasto de nenhuma das duas pessoas neste mês.',
      dados: ref.watch(barrasPoteComparativoProvider),
      estaVazio: (b) =>
          b.isEmpty || serieVazia([for (final x in b) ...[x.valorA, x.valorB]]),
      aoRecarregar: () {
        ref.invalidate(potesProvider);
        ref.invalidate(gastosDoMesProvider(mes));
      },
      legenda: (_) => dupla.length < 2
          ? []
          : [
              ItemLegenda(rotulo: dupla[0].nome, cor: corDeHex(dupla[0].cor)),
              ItemLegenda(rotulo: dupla[1].nome, cor: corDeHex(dupla[1].cor)),
            ],
      construir: (barras) => _Barras(barras: barras, dupla: dupla),
    );
  }
}

class _Barras extends StatelessWidget {
  final List<BarraComparativa> barras;
  final List<Membro> dupla;
  const _Barras({required this.barras, required this.dupla});

  @override
  Widget build(BuildContext context) {
    var maximo = 0.0;
    for (final b in barras) {
      if (b.valorA > maximo) maximo = b.valorA;
      if (b.valorB > maximo) maximo = b.valorB;
    }
    final teto = maximo <= 0 ? 1.0 : maximo * 1.1;

    final corA = corDeHex(dupla[0].cor);
    final corB = corDeHex(dupla[1].cor);
    final nomeA = dupla[0].nome;
    final nomeB = dupla[1].nome;

    return BarChart(
      BarChartData(
        maxY: teto,
        barGroups: [
          for (final (i, b) in barras.indexed)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                BarChartRodData(
                  toY: b.valorA,
                  color: corA,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
                BarChartRodData(
                  toY: b.valorB,
                  color: corB,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (grupo, iGrupo, rod, iRod) {
              if (iGrupo < 0 || iGrupo >= barras.length) return null;
              final barra = barras[iGrupo];
              final quem = iRod == 0 ? nomeA : nomeB;
              return BarTooltipItem(
                '${barra.nome}\n$quem: ${formatarReais(rod.toY)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (valor, meta) {
                final i = valor.toInt();
                if (i < 0 || i >= barras.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _abreviar(barras[i].nome),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _abreviar(String nome) =>
      nome.length <= 8 ? nome : '${nome.substring(0, 7)}…';
}
```

Crie `lib/ui/widgets/graficos/barras_cartao_comparativo.dart`, idêntico ao de cima trocando: título `'Gasto por cartão'`, frase vazia `'Nenhum gasto de nenhuma das duas pessoas neste mês.'` (igual), `dados: ref.watch(barrasCartaoComparativoProvider)`, `aoRecarregar` invalidando `cartoesProvider` (em vez de `potesProvider`) e `gastosDoMesProvider(mes)`, e o nome da classe pública `BarrasCartaoComparativo`. O `_Barras` interno pode ser reaproveitado copiando a mesma classe (arquivos de gráfico deste app não compartilham widgets privados entre si — ver `barras_previsto_gasto.dart` vs `barras_pote_comparativo.dart`, cada um com seu próprio `_Barras`).

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/ui/graficos_comparativo_test.dart
```

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/ui/widgets/graficos/barras_pote_comparativo.dart lib/ui/widgets/graficos/barras_cartao_comparativo.dart
git add lib/ui/widgets/graficos/barras_pote_comparativo.dart lib/ui/widgets/graficos/barras_cartao_comparativo.dart test/ui/graficos_comparativo_test.dart
git commit -m "feat: graficos de barras comparativas (por pote e por cartao)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: UI — linha de comprometimento comparativo

**Files:**
- Create: `lib/ui/widgets/graficos/linha_comprometimento_comparativo.dart`
- Modify: `test/ui/graficos_comparativo_test.dart`

**Interfaces:**
- Consumes: `serieComprometimentoComparativoProvider`/`duplaComparativaProvider` (Tasks 3-4), `PontoComprometido` (já existe), `eixoMensal` (já existe), `MolduraGrafico`, `ItemLegenda`, `corDeHex`, `serieVazia`.
- Produces: `class LinhaComprometimentoComparativo extends ConsumerWidget`, sem parâmetros.

- [ ] **Step 1: Escrever o teste que falha**

Adicione ao final de `test/ui/graficos_comparativo_test.dart`, dentro de `void main() { ... }`, um novo `import` no topo do arquivo:

```dart
import 'package:controle_financeiro/ui/widgets/graficos/linha_comprometimento_comparativo.dart';
```

E o novo `group`, com um helper de parcela local (o arquivo já tem `montar`/`Lancamento` para gasto simples; parcela precisa de `compraId`/`parcela`/`totalParcelas`, então helper próprio):

```dart
  group('LinhaComprometimentoComparativo', () {
    Future<void> montarComParcelas(
      WidgetTester tester, {
      List<(String membroId, String mesRef, double valor)> parcelas = const [],
    }) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final gastos = RepositorioGastosFake();
      for (final (membroId, mesRef, valor) in parcelas) {
        await gastos.adicionar(
          base: Gasto(
            id: '', mesRef: mesRef, membroId: membroId, poteId: 'p1',
            descricao: 'Parcelada', valor: valor,
            criadoEm: DateTime.utc(2026, 1, 1), parcelado: true,
            compraId: 'c1', parcela: 1, totalParcelas: 2,
          ),
          quantidadeParcelas: 1,
        );
      }

      final container = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casaComDupla)),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake(cartoes)),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(gastos),
      ]);
      addTearDown(container.dispose);
      container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      container.listen(casaProvider, (_, _) {});
      container.listen(parceladosDesdeProvider('2026-08'), (_, _) {});

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: LinhaComprometimentoComparativo()),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('duas series, uma por pessoa', (tester) async {
      await montarComParcelas(tester, parcelas: [
        ('marcos', '2026-08', 100),
        ('silvia', '2026-08', 250),
      ]);

      final dados = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(dados.lineBarsData, hasLength(2));
      expect(dados.lineBarsData[0].spots.first.y, 100);
      expect(dados.lineBarsData[1].spots.first.y, 250);
    });

    testWidgets('sem parcela nenhuma mostra a frase', (tester) async {
      await montarComParcelas(tester);

      expect(find.byType(LineChart), findsNothing);
      expect(find.textContaining('Nenhuma parcela'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/ui/graficos_comparativo_test.dart
```
Esperado: falha de compilação — `linha_comprometimento_comparativo.dart` ainda não existe.

- [ ] **Step 3: Implementar**

Crie `lib/ui/widgets/graficos/linha_comprometimento_comparativo.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../dominio/serie_mensal.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../../tema/tema.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';
import 'eixo_mensal.dart';

/// Comparativo: parcelas comprometidas nos proximos 12 meses, as duas
/// pessoas da casa lado a lado (duas linhas, mesmo eixo do grafico de
/// Comprometido da Visao Geral).
class LinhaComprometimentoComparativo extends ConsumerWidget {
  const LinhaComprometimentoComparativo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inicio = ref.watch(mesSelecionadoProvider);
    final dupla = ref.watch(duplaComparativaProvider);

    return MolduraGrafico<(List<PontoComprometido>, List<PontoComprometido>)>(
      titulo: 'Comprometido nos próximos $mesesDaSerie meses',
      vazio: 'Nenhuma parcela em aberto daqui para a frente.',
      dados: ref.watch(serieComprometimentoComparativoProvider),
      estaVazio: (par) {
        final (serieA, serieB) = par;
        return serieA.isEmpty ||
            serieVazia([
              for (final p in serieA) p.valor,
              for (final p in serieB) p.valor,
            ]);
      },
      aoRecarregar: () => ref.invalidate(parceladosDesdeProvider(inicio.valor)),
      legenda: (_) => dupla.length < 2
          ? []
          : [
              ItemLegenda(rotulo: dupla[0].nome, cor: corDeHex(dupla[0].cor)),
              ItemLegenda(rotulo: dupla[1].nome, cor: corDeHex(dupla[1].cor)),
            ],
      construir: (par) => _Linha(
        serieA: par.$1,
        serieB: par.$2,
        corA: dupla.length < 2 ? Colors.grey : corDeHex(dupla[0].cor),
        corB: dupla.length < 2 ? Colors.grey : corDeHex(dupla[1].cor),
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final List<PontoComprometido> serieA;
  final List<PontoComprometido> serieB;
  final Color corA;
  final Color corB;

  const _Linha({
    required this.serieA,
    required this.serieB,
    required this.corA,
    required this.corB,
  });

  @override
  Widget build(BuildContext context) {
    var maximo = 0.0;
    for (final p in [...serieA, ...serieB]) {
      if (p.valor > maximo) maximo = p.valor;
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maximo <= 0 ? 1 : maximo * 1.15,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (i, p) in serieA.indexed) FlSpot(i.toDouble(), p.valor),
            ],
            color: corA,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: [
              for (final (i, p) in serieB.indexed) FlSpot(i.toDouble(), p.valor),
            ],
            color: corB,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: true),
          ),
        ],
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: eixoMensal(
          context: context,
          meses: [for (final p in serieA) p.mes],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (pontos) => [
              for (final p in pontos)
                LineTooltipItem(
                  formatarReais(p.y),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/ui/graficos_comparativo_test.dart
```

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/ui/widgets/graficos/linha_comprometimento_comparativo.dart
git add lib/ui/widgets/graficos/linha_comprometimento_comparativo.dart test/ui/graficos_comparativo_test.dart
git commit -m "feat: linha de comprometimento comparativo entre as duas pessoas

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 8: UI — linha de projeção de saldo

**Files:**
- Create: `lib/ui/widgets/graficos/linha_projecao.dart`
- Test: `test/ui/graficos_projecao_test.dart` (novo arquivo)

**Interfaces:**
- Consumes: `serieProjecaoProvider` (Task 5), `PontoProjecao` (Task 2), `visaoProvider`, `membrosProvider`, `eixoMensal`, `MolduraGrafico`, `serieVazia`.
- Produces: `class LinhaProjecao extends ConsumerWidget`, sem parâmetros.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/ui/graficos_projecao_test.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/widgets/graficos/linha_projecao.dart';

const casa = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
    Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
        cor: '#2E7D32', ordem: 0),
    Membro(id: 'silvia', nome: 'Silvia', email: 's@x.com',
        cor: '#6A1B9A', ordem: 1),
  ],
);

Future<void> montar(
  WidgetTester tester, {
  double ganhoMarcos = 5000,
  List<(String mesRef, double valor)> parcelas = const [],
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final ganhos = RepositorioGanhosFake();
  final gastos = RepositorioGastosFake();

  if (ganhoMarcos > 0) {
    await ganhos.adicionar(Ganho(
      id: '', mesRef: '2026-08', membroId: 'marcos',
      descricao: 'Salario', valor: ganhoMarcos,
      criadoEm: DateTime.utc(2026, 8, 1),
    ));
  }
  for (final (mesRef, valor) in parcelas) {
    await gastos.adicionar(
      base: Gasto(
        id: '', mesRef: mesRef, membroId: 'marcos', poteId: 'p1',
        descricao: 'Parcelada', valor: valor,
        criadoEm: DateTime.utc(2026, 1, 1), parcelado: true,
        compraId: 'c1', parcela: 1, totalParcelas: 2,
      ),
      quantidadeParcelas: 1,
    );
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake()),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
    repositorioGanhosProvider.overrideWithValue(ganhos),
    repositorioGastosProvider.overrideWithValue(gastos),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(casaProvider, (_, _) {});
  container.listen(ganhosDoMesProvider('2026-08'), (_, _) {});
  container.listen(parceladosDesdeProvider('2026-08'), (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Scaffold(body: LinhaProjecao())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('LinhaProjecao', () {
    testWidgets('duas series: renda constante e gasto comprometido',
        (tester) async {
      await montar(tester, ganhoMarcos: 5000, parcelas: [
        ('2026-08', 100),
        ('2026-09', 100),
      ]);

      final dados = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(dados.lineBarsData, hasLength(2));
      // Renda: reta em 5000 em todos os meses.
      expect(
        dados.lineBarsData[0].spots.every((s) => s.y == 5000),
        isTrue,
      );
      // Gasto comprometido: 100 nos dois primeiros meses, 0 depois.
      expect(dados.lineBarsData[1].spots[0].y, 100);
      expect(dados.lineBarsData[1].spots[1].y, 100);
      expect(dados.lineBarsData[1].spots[2].y, 0);
    });

    testWidgets('sem renda e sem parcela mostra a frase', (tester) async {
      await montar(tester, ganhoMarcos: 0);

      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('rodape avisa quantos meses ficam com saldo negativo',
        (tester) async {
      await montar(tester, ganhoMarcos: 1000, parcelas: [
        ('2026-08', 1500),
        ('2026-09', 1500),
      ]);

      expect(find.textContaining('saldo negativo'), findsOneWidget);
    });

    testWidgets('sem mes negativo nao mostra aviso', (tester) async {
      await montar(tester, ganhoMarcos: 5000, parcelas: [('2026-08', 100)]);

      expect(find.textContaining('saldo negativo'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/ui/graficos_projecao_test.dart
```
Esperado: falha de compilação — `linha_projecao.dart` ainda não existe.

- [ ] **Step 3: Implementar**

Crie `lib/ui/widgets/graficos/linha_projecao.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../dominio/serie_mensal.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';
import 'eixo_mensal.dart';

/// Projecao de saldo nos proximos 12 meses: renda projetada (repete o
/// ganho do mes selecionado) x gasto ja comprometido em parcelas.
/// Respeita o seletor de pessoa (Marcos/Silvia/Casal).
class LinhaProjecao extends ConsumerWidget {
  const LinhaProjecao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inicio = ref.watch(mesSelecionadoProvider);
    final esquema = Theme.of(context).colorScheme;

    return MolduraGrafico<List<PontoProjecao>>(
      titulo: 'Projeção de saldo',
      vazio: 'Cadastre um ganho ou uma parcela para ver a projeção.',
      dados: ref.watch(serieProjecaoProvider),
      estaVazio: (serie) =>
          serie.isEmpty ||
          serieVazia([for (final p in serie) ...[p.ganhos, p.gastos]]),
      aoRecarregar: () {
        ref.invalidate(ganhosDoMesProvider(inicio.valor));
        ref.invalidate(parceladosDesdeProvider(inicio.valor));
      },
      legenda: (_) => [
        ItemLegenda(rotulo: 'Renda projetada', cor: esquema.primary),
        ItemLegenda(rotulo: 'Gasto comprometido', cor: esquema.tertiary),
      ],
      rodape: (serie) {
        final negativos = serie.where((p) => p.saldo < 0).length;
        if (negativos == 0) return const SizedBox.shrink();
        return Text(
          '$negativos ${negativos == 1 ? 'mês fica' : 'meses ficam'} com saldo negativo',
          style: TextStyle(color: esquema.error, fontWeight: FontWeight.bold),
        );
      },
      construir: (serie) => _Linha(serie: serie),
    );
  }
}

class _Linha extends StatelessWidget {
  final List<PontoProjecao> serie;
  const _Linha({required this.serie});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    var maximo = 0.0;
    for (final p in serie) {
      if (p.ganhos > maximo) maximo = p.ganhos;
      if (p.gastos > maximo) maximo = p.gastos;
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maximo <= 0 ? 1 : maximo * 1.15,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (i, p) in serie.indexed) FlSpot(i.toDouble(), p.ganhos),
            ],
            color: esquema.primary,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: [
              for (final (i, p) in serie.indexed) FlSpot(i.toDouble(), p.gastos),
            ],
            color: esquema.tertiary,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: true),
          ),
        ],
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: eixoMensal(
          context: context,
          meses: [for (final p in serie) p.mes],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (pontos) => [
              for (final p in pontos)
                LineTooltipItem(
                  formatarReais(p.y),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/ui/graficos_projecao_test.dart
```

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/ui/widgets/graficos/linha_projecao.dart
git add lib/ui/widgets/graficos/linha_projecao.dart test/ui/graficos_projecao_test.dart
git commit -m "feat: grafico de linha de projecao de saldo

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 9: UI — seletor de 3 abas e restruturação de `tela_graficos.dart`

**Files:**
- Modify: `lib/ui/telas/tela_graficos.dart`
- Modify: `test/ui/tela_graficos_test.dart`

**Interfaces:**
- Consumes: `tipoVisaoGraficos`/`TipoVisaoGraficos`/`duplaComparativaProvider` (Task 3), `BarrasPoteComparativo`/`BarrasCartaoComparativo` (Task 6), `LinhaComprometimentoComparativo` (Task 7), `LinhaProjecao` (Task 8) — todos os widgets novos.
- Produces: `TelaGraficos` reestruturada (mesma API pública, `const TelaGraficos({super.key})`); novo widget privado `_SeletorTipoVisao`.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/ui/tela_graficos_test.dart`, dentro de `void main() { ... }` (o arquivo já importa tudo que os testes abaixo precisam — `casa` já tem os 2 membros marcos/silvia):

```dart
  group('seletor de tipo de visao', () {
    testWidgets('comeca em Visao Geral, mostrando os 7 graficos de sempre',
        (tester) async {
      await montar(tester);

      expect(find.byKey(const Key('graficos_coluna_unica')), findsOneWidget);
      expect(find.text('Comparativo'), findsOneWidget);
      expect(find.text('Projeção'), findsOneWidget);
    });

    testWidgets('trocar para Comparativo esconde o seletor de pessoa',
        (tester) async {
      await montar(tester);

      expect(find.byKey(const Key('graficos_visao')), findsOneWidget);

      await tester.tap(find.text('Comparativo'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('graficos_visao')), findsNothing);
    });

    testWidgets('Comparativo mostra os 3 graficos novos, nao os 7 de sempre',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('Comparativo'));
      await tester.pumpAndSettle();

      expect(find.text('Gasto por pote'), findsOneWidget);
      expect(find.text('Gasto por cartão'), findsOneWidget);
      expect(find.textContaining('Comprometido nos próximos'), findsOneWidget);
      expect(find.text('Ganhos por pessoa'), findsNothing); // grafico da Visao Geral
    });

    testWidgets('trocar para Projecao mantem o seletor de pessoa',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('Projeção'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('graficos_visao')), findsOneWidget);
      expect(find.text('Projeção de saldo'), findsOneWidget);
    });

    testWidgets('casa com 1 pessoa ativa nao oferece Comparativo',
        (tester) async {
      final container = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          const Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                  cor: '#2E7D32', ordem: 0),
            ],
          ),
        )),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ]);
      addTearDown(container.dispose);
      container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      container.listen(casaProvider, (_, _) {});

      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TelaGraficos())),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Visão Geral'), findsOneWidget);
      expect(find.text('Projeção'), findsOneWidget);
      expect(find.text('Comparativo'), findsNothing);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/ui/tela_graficos_test.dart
```
Esperado: falhas — o seletor de 3 abas ainda não existe, "Comparativo"/"Projeção" não aparecem em lugar nenhum.

- [ ] **Step 3: Implementar**

Substitua o conteúdo de `lib/ui/telas/tela_graficos.dart` por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/membro.dart';
import '../../estado/providers.dart';
import '../shell.dart' show breakpointDesktop;
import '../widgets/graficos/barra_cascata.dart';
import '../widgets/graficos/barras_cartao_comparativo.dart';
import '../widgets/graficos/barras_pote_comparativo.dart';
import '../widgets/graficos/barras_previsto_gasto.dart';
import '../widgets/graficos/linha_comprometimento.dart';
import '../widgets/graficos/linha_comprometimento_comparativo.dart';
import '../widgets/graficos/linha_evolucao.dart';
import '../widgets/graficos/linha_projecao.dart';
import '../widgets/graficos/pizza_ganhos.dart';
import '../widgets/graficos/rosca_por_cartao.dart';
import '../widgets/graficos/rosca_por_pote.dart';

/// A tela de Graficos tem 3 visoes, escolhidas por `_SeletorTipoVisao`:
/// Visao Geral (os sete graficos de sempre), Comparativo (as duas pessoas
/// da casa lado a lado) e Projecao (saldo dos proximos 12 meses).
///
/// Nao ha AsyncValue.when aqui, de proposito: cada MolduraGrafico resolve o
/// seu. Um `when` no topo derrubaria todos os graficos da visao atual por
/// causa de um provider com problema.
class TelaGraficos extends ConsumerWidget {
  const TelaGraficos({super.key});

  /// Os seis primeiros na ordem da spec 10; o setimo (cartao) vem depois.
  static const _graficosGeral = <Widget>[
    RoscaPorPote(),
    BarrasPrevistoGasto(),
    LinhaEvolucao(),
    PizzaGanhos(),
    BarraCascata(),
    LinhaComprometimento(),
    RoscaPorCartao(),
  ];

  static const _graficosComparativo = <Widget>[
    BarrasPoteComparativo(),
    BarrasCartaoComparativo(),
    LinhaComprometimentoComparativo(),
  ];

  static const _graficosProjecao = <Widget>[LinhaProjecao()];

  List<Widget> _graficosDoTipo(TipoVisaoGraficos tipo) => switch (tipo) {
        TipoVisaoGraficos.geral => _graficosGeral,
        TipoVisaoGraficos.comparativo => _graficosComparativo,
        TipoVisaoGraficos.projecao => _graficosProjecao,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = MediaQuery.sizeOf(context).width >= breakpointDesktop;
    final membros = ref.watch(membrosParaVisaoProvider);
    final tipo = ref.watch(tipoVisaoGraficosProvider);
    final graficos = _graficosDoTipo(tipo);

    return Column(
      children: [
        if (tipo != TipoVisaoGraficos.comparativo) _SeletorVisao(membros: membros),
        const _SeletorTipoVisao(),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('graficos_rolagem'),
            child: desktop ? _duasColunas(graficos) : _colunaUnica(graficos),
          ),
        ),
      ],
    );
  }

  /// No desktop os graficos ficam pequenos demais ocupando a largura toda;
  /// duas colunas aproveitam o espaco e encurtam a rolagem.
  Widget _duasColunas(List<Widget> graficos) {
    final esquerda = <Widget>[];
    final direita = <Widget>[];
    for (final (i, g) in graficos.indexed) {
      (i.isEven ? esquerda : direita).add(g);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            key: const Key('graficos_coluna_esquerda'),
            children: esquerda,
          ),
        ),
        Expanded(
          child: Column(
            key: const Key('graficos_coluna_direita'),
            children: direita,
          ),
        ),
      ],
    );
  }

  Widget _colunaUnica(List<Widget> graficos) => Column(
        key: const Key('graficos_coluna_unica'),
        children: graficos,
      );
}

/// Mesmo seletor da tela de Resumo, escrevendo no mesmo `visaoProvider`:
/// trocar a visao num lugar troca no outro, o que e o esperado de duas
/// telas que respondem a mesma pergunta. So aparece na Visao Geral e na
/// Projecao -- o Comparativo sempre mostra as duas pessoas, escolher uma
/// so nao faria sentido ali.
class _SeletorVisao extends ConsumerWidget {
  final List<Membro> membros;
  const _SeletorVisao({required this.membros});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Com um so integrante ativo na casa, "Marcos" e "Casal" seriam a mesma
    // coisa -- o seletor todo some, nao so um dos dois.
    if (membros.where((m) => m.removidoEm == null).length <= 1) {
      return const SizedBox.shrink();
    }

    final visao = ref.watch(visaoProvider);
    final valida =
        visao == null || membros.any((m) => m.id == visao) ? visao : null;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SegmentedButton<String?>(
        key: const Key('graficos_visao'),
        showSelectedIcon: false,
        segments: [
          for (final m in membros)
            ButtonSegment(value: m.id, label: Text(m.nome)),
          const ButtonSegment(value: null, label: Text('Casal')),
        ],
        selected: {valida},
        onSelectionChanged: (s) =>
            ref.read(visaoProvider.notifier).selecionar(s.first),
      ),
    );
  }
}

/// As 3 abas: Visao Geral / Comparativo / Projecao. "Comparativo" so entra
/// na lista quando a casa tem os dois integrantes ativos -- ver
/// `duplaComparativaProvider`. Se a dupla encolher com a aba Comparativo
/// ja selecionada (alguem saiu da casa com a tela aberta), volta sozinho
/// pra Visao Geral.
class _SeletorTipoVisao extends ConsumerWidget {
  const _SeletorTipoVisao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipo = ref.watch(tipoVisaoGraficosProvider);
    final temDupla = ref.watch(duplaComparativaProvider).length == 2;

    if (tipo == TipoVisaoGraficos.comparativo && !temDupla) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(tipoVisaoGraficosProvider.notifier).selecionar(TipoVisaoGraficos.geral);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SegmentedButton<TipoVisaoGraficos>(
        key: const Key('graficos_tipo_visao'),
        showSelectedIcon: false,
        segments: [
          const ButtonSegment(
            value: TipoVisaoGraficos.geral,
            label: Text('Visão Geral'),
            icon: Icon(Icons.donut_large),
          ),
          if (temDupla)
            const ButtonSegment(
              value: TipoVisaoGraficos.comparativo,
              label: Text('Comparativo'),
              icon: Icon(Icons.bar_chart),
            ),
          const ButtonSegment(
            value: TipoVisaoGraficos.projecao,
            label: Text('Projeção'),
            icon: Icon(Icons.trending_up),
          ),
        ],
        selected: {
          tipo == TipoVisaoGraficos.comparativo && !temDupla
              ? TipoVisaoGraficos.geral
              : tipo,
        },
        onSelectionChanged: (s) =>
            ref.read(tipoVisaoGraficosProvider.notifier).selecionar(s.first),
      ),
    );
  }
}
```

> Nota sobre o reset automático: `WidgetsBinding.instance.addPostFrameCallback` dentro de um `build` é o mesmo tipo de efeito colateral que `ref.listen` resolveria de forma mais idiomática num `Notifier.build()` (como `VisaoNotifier` já faz). Se preferir seguir esse padrão em vez do `addPostFrameCallback`, mova a lógica para dentro de `TipoVisaoGraficosNotifier.build()`:
> ```dart
> @override
> TipoVisaoGraficos build() {
>   ref.listen<List<Membro>>(duplaComparativaProvider, (_, dupla) {
>     if (state == TipoVisaoGraficos.comparativo && dupla.length < 2) {
>       state = TipoVisaoGraficos.geral;
>     }
>   });
>   return TipoVisaoGraficos.geral;
> }
> ```
> Isso exigiria voltar ao Task 3 e trocar `TipoVisaoGraficosNotifier.build()`. Qualquer uma das duas formas satisfaz o teste "casa com 1 pessoa ativa nao oferece Comparativo" (que testa o caso em que a casa JÁ tem 1 pessoa ao abrir a tela, coberto pelo `if (temDupla)` no `segments`, sem depender do reset automático). Implemente com `addPostFrameCallback` primeiro (mais simples, não exige tocar Task 3 de novo); só troque para `ref.listen` se algum teste do Task 9 revelar que o reset automático não está dando (nenhum teste deste plano cobre esse caminho específico — é reforço de robustez, não requisito testado).

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/ui/tela_graficos_test.dart
```

- [ ] **Step 5: Rodar a suíte inteira, analisar e commitar**

```bash
flutter analyze
flutter test
git add lib/ui/telas/tela_graficos.dart test/ui/tela_graficos_test.dart
git commit -m "feat: seletor de 3 abas (Visao Geral/Comparativo/Projecao) em Graficos

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Final Checklist

- [ ] `flutter analyze` limpo no projeto inteiro.
- [ ] `flutter test` verde no projeto inteiro (suíte completa, não só os arquivos tocados).
- [ ] Nenhuma Cloud Function nem regra do Firestore precisa de deploy — este plano é 100% client-side (domínio + estado + UI), só leitura de dados que já existem.
- [ ] Gerar um APK de release (`flutter build apk --release --split-per-abi`) e instalar no emulador/dispositivo pra conferir visualmente as 3 abas, especialmente: Comparativo sumindo com 1 pessoa só, e o seletor de pessoa sumindo só no Comparativo.
