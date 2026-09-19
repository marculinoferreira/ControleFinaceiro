# Ganho previsto Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir o campo "Vai ganhar (próx. mês)" do pote de reserva por um conceito geral de "ganho previsto" — um `Ganho` marcado, por pessoa, por mês — que alimenta todo cálculo de renda do app (cascata, Resumo, percentual de comprometimento, Projeção), não só a Projeção do mês seguinte.

**Architecture:** `Ganho` ganha um campo `previsto` (bool). Um filtro de domínio novo (`ganhosEfetivos`) decide, por pessoa e por mês, se usa o real ou cai no previsto. Esse filtro entra em cada provider que hoje soma ganho puro; a Projeção passa a construir um mapa de "ganho efetivo por mês" para a janela inteira de 12 meses, em vez de um único valor fixo com uma exceção pro mês seguinte. `Pote.proximoGanhoEsperado` e a UI correspondente saem do código.

**Tech Stack:** Flutter, Riverpod (`Provider`/`Provider.autoDispose`), Dart puro para o domínio.

**Spec:** `docs/superpowers/specs/2026-09-19-ganho-previsto-design.md`

## Global Constraints

- `Ganho.previsto` tem default `false` — documentos legados no Firestore sem esse campo continuam funcionando.
- Real sempre vence sobre previsto: uma pessoa com pelo menos um `Ganho` real (`previsto == false`) num mês usa só os reais dela naquele mês, ignorando qualquer previsto que exista.
- Nenhuma remoção automática: quando o ganho real chega, o previsto continua na lista (marcado), só para de contar nos cálculos — o usuário decide se apaga.
- A Projeção usa o previsto de QUALQUER mês futuro preenchido, não só o mês imediatamente seguinte ao selecionado.
- `Pote.proximoGanhoEsperado` e o campo "Vai ganhar" na tela de Potes são removidos — `ehReserva`, `valorGuardado` e "meses de cobertura" continuam intocados.
- Toda leitura assíncrona passa pelos três ramos de `AsyncValue` via `combinarAsyncValues`/`.whenData`, nunca `.value ?? []`.

---

## Task 1: Domínio — `Ganho` ganha o campo `previsto`

**Files:**
- Modify: `lib/dominio/models/ganho.dart`
- Test: `test/dominio/models/ganho_test.dart` (novo arquivo)

**Interfaces:**
- Consumes: nada de outras tarefas.
- Produces: `Ganho` com `bool previsto` (default `false`); `fromMap`/`toMap`/`copyWith` atualizados para incluir o campo.

- [ ] **Step 1: Escrever os testes que falham**

Crie `test/dominio/models/ganho_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';

void main() {
  group('Ganho com o campo previsto', () {
    test('default: previsto falso', () {
      final ganho = Ganho(
        id: 'g1',
        mesRef: '2026-10',
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 3800,
        criadoEm: DateTime.utc(2026, 9, 1),
      );

      expect(ganho.previsto, isFalse);
    });

    test('toMap/fromMap fazem round-trip com previsto true', () {
      final ganho = Ganho(
        id: 'g1',
        mesRef: '2026-10',
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 3800,
        criadoEm: DateTime.utc(2026, 9, 1),
        previsto: true,
      );

      final reconstruido = Ganho.fromMap('g1', ganho.toMap());

      expect(reconstruido.previsto, isTrue);
    });

    test('fromMap sem a chave previsto (dado legado) cai em falso', () {
      final ganho = Ganho.fromMap('g1', {
        'mesRef': '2026-08',
        'membroId': 'marcos',
        'descricao': 'Salario',
        'valor': 5000,
        'criadoEm': DateTime.utc(2026, 8, 1),
      });

      expect(ganho.previsto, isFalse);
    });

    test('copyWith preserva previsto quando nao especificado', () {
      final ganho = Ganho(
        id: 'g1',
        mesRef: '2026-10',
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 3800,
        criadoEm: DateTime.utc(2026, 9, 1),
        previsto: true,
      );

      final renomeado = ganho.copyWith(descricao: 'Salario CLT');

      expect(renomeado.previsto, isTrue);
      expect(renomeado.descricao, 'Salario CLT');
    });

    test('copyWith troca previsto para false explicitamente', () {
      final ganho = Ganho(
        id: 'g1',
        mesRef: '2026-10',
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 3800,
        criadoEm: DateTime.utc(2026, 9, 1),
        previsto: true,
      );

      final atualizado = ganho.copyWith(previsto: false);

      expect(atualizado.previsto, isFalse);
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/dominio/models/ganho_test.dart
```
Esperado: falha de compilação — `Ganho` ainda não tem `previsto`.

- [ ] **Step 3: Implementar**

Substitua o conteúdo de `lib/dominio/models/ganho.dart` por:

```dart
/// Entrada de renda de uma pessoa em um mes.
class Ganho {
  final String id;
  final String mesRef;
  final String membroId;
  final String descricao;
  final double valor;
  final DateTime criadoEm;

  /// Marca que este ganho e uma previsao ("eu sei que vou ganhar X"), nao
  /// um ganho ja recebido. So conta nos calculos de renda quando a mesma
  /// pessoa nao tiver nenhum ganho real (previsto == false) no mesmo mes —
  /// ver `ganhosEfetivos` em totais.dart.
  final bool previsto;

  const Ganho({
    required this.id,
    required this.mesRef,
    required this.membroId,
    required this.descricao,
    required this.valor,
    required this.criadoEm,
    this.previsto = false,
  });

  factory Ganho.fromMap(String id, Map<String, dynamic> mapa) => Ganho(
        id: id,
        mesRef: mapa['mesRef'] as String,
        membroId: mapa['membroId'] as String,
        descricao: mapa['descricao'] as String,
        valor: (mapa['valor'] as num).toDouble(),
        criadoEm: _lerData(mapa['criadoEm']),
        previsto: mapa['previsto'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'mesRef': mesRef,
        'membroId': membroId,
        'descricao': descricao,
        'valor': valor,
        'criadoEm': criadoEm,
        'previsto': previsto,
      };

  Ganho copyWith({
    String? id,
    String? mesRef,
    String? membroId,
    String? descricao,
    double? valor,
    DateTime? criadoEm,
    bool? previsto,
  }) =>
      Ganho(
        id: id ?? this.id,
        mesRef: mesRef ?? this.mesRef,
        membroId: membroId ?? this.membroId,
        descricao: descricao ?? this.descricao,
        valor: valor ?? this.valor,
        criadoEm: criadoEm ?? this.criadoEm,
        previsto: previsto ?? this.previsto,
      );
}

/// O Firestore devolve Timestamp; os testes de dominio passam DateTime.
/// Converter aqui mantem o dominio livre de import do cloud_firestore:
/// Timestamp expoe toDate() e e aceito via duck typing dinamico.
DateTime _lerData(dynamic bruto) {
  if (bruto is DateTime) return bruto;
  if (bruto == null) return DateTime.now();
  return (bruto as dynamic).toDate() as DateTime;
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/dominio/models/ganho_test.dart
```

- [ ] **Step 5: Rodar a suíte inteira, analisar e commitar**

`Ganho` é usado em muitos arquivos existentes — como o campo novo tem default, nenhum construtor existente deveria quebrar, mas confirme com a suíte inteira antes de seguir.

```bash
flutter test
flutter analyze lib/dominio/models/ganho.dart
git add lib/dominio/models/ganho.dart test/dominio/models/ganho_test.dart
git commit -m "feat: Ganho ganha o campo previsto (dominio)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: Domínio — filtro "ganhos efetivos" de um mês

**Files:**
- Modify: `lib/dominio/totais.dart`
- Test: `test/dominio/totais_test.dart`

**Interfaces:**
- Consumes: `Ganho.previsto` (Task 1).
- Produces: `List<Ganho> ganhosEfetivos(List<Ganho> ganhosDoMes)`.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/dominio/totais_test.dart` (o arquivo já tem o helper `ganho(membroId, valor, {mesRef, ...})` no topo — reaproveite, passando `previsto` via um segundo helper local dentro do grupo, já que o helper existente não tem esse parâmetro):

```dart
  group('ganhosEfetivos', () {
    Ganho ganhoMarcado(String membroId, double valor, {required bool previsto}) =>
        Ganho(
          id: 'g-$membroId-$previsto',
          mesRef: '2026-10',
          membroId: membroId,
          descricao: previsto ? 'Salario previsto' : 'Salario',
          valor: valor,
          criadoEm: DateTime.utc(2026, 9, 1),
          previsto: previsto,
        );

    test('pessoa so com real: usa o real', () {
      final efetivos = ganhosEfetivos([
        ganhoMarcado('marcos', 5000, previsto: false),
      ]);

      expect(efetivos, hasLength(1));
      expect(efetivos.single.valor, 5000);
      expect(efetivos.single.previsto, isFalse);
    });

    test('pessoa so com previsto: usa o previsto', () {
      final efetivos = ganhosEfetivos([
        ganhoMarcado('marcos', 3800, previsto: true),
      ]);

      expect(efetivos, hasLength(1));
      expect(efetivos.single.valor, 3800);
      expect(efetivos.single.previsto, isTrue);
    });

    test('pessoa com real e previsto no mesmo mes: real vence, previsto some',
        () {
      final efetivos = ganhosEfetivos([
        ganhoMarcado('marcos', 5000, previsto: false),
        ganhoMarcado('marcos', 3800, previsto: true),
      ]);

      expect(efetivos, hasLength(1));
      expect(efetivos.single.valor, 5000);
      expect(efetivos.single.previsto, isFalse);
    });

    test('duas pessoas, cada uma com sua propria regra', () {
      final efetivos = ganhosEfetivos([
        ganhoMarcado('marcos', 5000, previsto: false),
        ganhoMarcado('silvia', 3200, previsto: true),
      ]);

      expect(efetivos, hasLength(2));
      expect(efetivos.firstWhere((g) => g.membroId == 'marcos').valor, 5000);
      expect(efetivos.firstWhere((g) => g.membroId == 'silvia').valor, 3200);
    });

    test('lista vazia devolve lista vazia', () {
      expect(ganhosEfetivos(const []), isEmpty);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/dominio/totais_test.dart
```
Esperado: falha de compilação — `ganhosEfetivos` não existe.

- [ ] **Step 3: Implementar**

Em `lib/dominio/totais.dart`, adicione ao final do arquivo:

```dart
/// Filtra os ganhos de UM MES para "o que efetivamente conta" na renda:
/// os ganhos reais de cada pessoa quando existir pelo menos um; senao, os
/// previstos dela. Nunca mistura real e previsto da mesma pessoa.
///
/// Assume que [ganhosDoMes] ja pertence a um unico mes — "tem ganho real"
/// precisa ser respondido mes a mes, nao ao longo de uma janela inteira
/// (ver `ganhosEfetivosPorMes` em serie_mensal.dart para o caso de varios
/// meses).
List<Ganho> ganhosEfetivos(List<Ganho> ganhosDoMes) {
  final membrosComReal = <String>{
    for (final g in ganhosDoMes)
      if (!g.previsto) g.membroId,
  };
  return [
    for (final g in ganhosDoMes)
      if (!g.previsto || !membrosComReal.contains(g.membroId)) g,
  ];
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/dominio/totais_test.dart
```

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/dominio/totais.dart
git add lib/dominio/totais.dart test/dominio/totais_test.dart
git commit -m "feat: filtro de ganhos efetivos (real ou previsto) de um mes (dominio)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: Domínio — "ganhos efetivos" ao longo de uma janela de meses

**Files:**
- Modify: `lib/dominio/serie_mensal.dart`
- Test: `test/dominio/serie_mensal_test.dart`

**Interfaces:**
- Consumes: `ganhosEfetivos` (Task 2), `calcularTotais` (já existe/importado no arquivo), `MesRef`, `Ganho`.
- Produces: `Map<String, double> ganhosEfetivosPorMes({required List<Ganho> ganhosDoIntervalo, required List<MesRef> meses, String? membroId})`.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/dominio/serie_mensal_test.dart` (dentro de `void main() { ... }`; o arquivo já importa `serie_mensal.dart`, `Ganho`, `MesRef`):

```dart
  group('ganhosEfetivosPorMes', () {
    Ganho ganhoDoMes(String mesRef, String membroId, double valor,
            {bool previsto = false}) =>
        Ganho(
          id: 'g-$mesRef-$membroId-$previsto',
          mesRef: mesRef,
          membroId: membroId,
          descricao: previsto ? 'Previsto' : 'Real',
          valor: valor,
          criadoEm: DateTime.utc(2026, 1, 1),
          previsto: previsto,
        );

    test('mes sem ganho nenhum fica fora do mapa', () {
      final mapa = ganhosEfetivosPorMes(
        ganhosDoIntervalo: const [],
        meses: janelaDe(const MesRef(2026, 9), 2),
      );

      expect(mapa, isEmpty);
    });

    test('mes com so previsto entra com o valor do previsto', () {
      final mapa = ganhosEfetivosPorMes(
        ganhosDoIntervalo: [ganhoDoMes('2026-10', 'marcos', 3800, previsto: true)],
        meses: janelaDe(const MesRef(2026, 9), 2),
      );

      expect(mapa['2026-09'], isNull);
      expect(mapa['2026-10'], 3800);
    });

    test('filtra por membroId quando informado', () {
      final mapa = ganhosEfetivosPorMes(
        ganhosDoIntervalo: [
          ganhoDoMes('2026-10', 'marcos', 3800, previsto: true),
          ganhoDoMes('2026-10', 'silvia', 3200, previsto: true),
        ],
        meses: janelaDe(const MesRef(2026, 9), 2),
        membroId: 'silvia',
      );

      expect(mapa['2026-10'], 3200);
    });

    test('mes com real de uma pessoa e nada da pessoa pedida entra com zero',
        () {
      final mapa = ganhosEfetivosPorMes(
        ganhosDoIntervalo: [ganhoDoMes('2026-10', 'marcos', 5000)],
        meses: janelaDe(const MesRef(2026, 9), 2),
        membroId: 'silvia',
      );

      expect(mapa.containsKey('2026-10'), isTrue);
      expect(mapa['2026-10'], 0);
    });

    test('real vence previsto no mesmo mes e pessoa', () {
      final mapa = ganhosEfetivosPorMes(
        ganhosDoIntervalo: [
          ganhoDoMes('2026-10', 'marcos', 3800, previsto: true),
          ganhoDoMes('2026-10', 'marcos', 4200),
        ],
        meses: janelaDe(const MesRef(2026, 9), 2),
        membroId: 'marcos',
      );

      expect(mapa['2026-10'], 4200);
    });

    test('sem membroId (visao casal), soma todo mundo', () {
      final mapa = ganhosEfetivosPorMes(
        ganhosDoIntervalo: [
          ganhoDoMes('2026-10', 'marcos', 5000),
          ganhoDoMes('2026-10', 'silvia', 3200, previsto: true),
        ],
        meses: janelaDe(const MesRef(2026, 9), 2),
      );

      expect(mapa['2026-10'], 8200);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/dominio/serie_mensal_test.dart
```
Esperado: falha de compilação — `ganhosEfetivosPorMes` não existe.

- [ ] **Step 3: Implementar**

Em `lib/dominio/serie_mensal.dart`, adicione ao final do arquivo:

```dart
/// Ganho efetivo (real-ou-previsto, ver `ganhosEfetivos` em totais.dart) de
/// [membroId] em cada mes de [meses], a partir de uma janela com varios
/// meses misturados (ex.: `gastosDoIntervaloProvider`/
/// `ganhosDoIntervaloProvider`).
///
/// Um mes sem NENHUM ganho (nem real, nem previsto, de ninguem) fica de
/// fora do mapa — quem consome decide o que fazer (`serieProjecao` cai no
/// `ganhoMensalAssumido` nesse caso). Um mes com ganho de outra pessoa mas
/// nao de [membroId] entra no mapa com o valor 0.0, igual `calcularTotais`
/// ja faz hoje pra um mes so — nao ha tratamento especial novo aqui.
Map<String, double> ganhosEfetivosPorMes({
  required List<Ganho> ganhosDoIntervalo,
  required List<MesRef> meses,
  String? membroId,
}) {
  final porMes = <String, List<Ganho>>{};
  for (final g in ganhosDoIntervalo) {
    (porMes[g.mesRef] ??= []).add(g);
  }

  return {
    for (final mes in meses)
      if (porMes[mes.valor] != null)
        mes.valor: calcularTotais(
          ganhos: ganhosEfetivos(porMes[mes.valor]!),
          gastos: const [],
          membroId: membroId,
        ).ganhos,
  };
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/dominio/serie_mensal_test.dart
```

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/dominio/serie_mensal.dart
git add lib/dominio/serie_mensal.dart test/dominio/serie_mensal_test.dart
git commit -m "feat: ganhos efetivos por mes ao longo de uma janela (dominio)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Estado — providers existentes passam a usar `ganhosEfetivos`

**Files:**
- Modify: `lib/estado/providers.dart`
- Test: `test/estado/providers_test.dart`

**Interfaces:**
- Consumes: `ganhosEfetivos` (Task 2).
- Produces: `totaisDoMesProvider`, `percentualComprometidoProvider`, `ganhoAssumidoProjecaoProvider` — mesmos nomes e assinaturas de hoje, só a lógica interna muda.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/estado/providers_test.dart`:

```dart
  group('ganhos efetivos nos providers existentes', () {
    Future<ProviderContainer> montarComGanhos({
      List<(String membroId, double valor, bool previsto)> ganhosDoMes = const [],
      List<(String mesRef, double valor)> parcelas = const [],
    }) async {
      final repoGanhos = RepositorioGanhosFake();
      for (final (membroId, valor, previsto) in ganhosDoMes) {
        await repoGanhos.adicionar(Ganho(
          id: '', mesRef: '2026-10', membroId: membroId,
          descricao: previsto ? 'Previsto' : 'Real', valor: valor,
          criadoEm: DateTime.utc(2026, 9, 1), previsto: previsto,
        ));
      }
      final repoGastos = RepositorioGastosFake();
      for (final (mesRef, valor) in parcelas) {
        await repoGastos.adicionar(
          base: Gasto(
            id: '', mesRef: mesRef, membroId: 'marcos', poteId: 'p1',
            descricao: 'Parcelada', valor: valor,
            criadoEm: DateTime.utc(2026, 1, 1), parcelado: true,
            compraId: 'c1', parcela: 1, totalParcelas: 2,
          ),
          quantidadeParcelas: 2,
        );
      }

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(repoGanhos),
        repositorioGastosProvider.overrideWithValue(repoGastos),
      ]);
      addTearDown(c.dispose);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 10));
      c.listen(ganhosDoMesProvider('2026-10'), (_, _) {});
      c.listen(gastosDoMesProvider('2026-10'), (_, _) {});
      c.listen(potesProvider, (_, _) {});
      c.listen(parceladosDesdeProvider('2026-10'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('totaisDoMesProvider usa previsto quando nao ha ganho real', () async {
      final c = await montarComGanhos(
        ganhosDoMes: [('marcos', 3800, true)],
      );

      expect(c.read(totaisDoMesProvider).requireValue.ganhos, 3800);
    });

    test('totaisDoMesProvider ignora previsto quando ha ganho real', () async {
      final c = await montarComGanhos(
        ganhosDoMes: [('marcos', 3800, true), ('marcos', 4200, false)],
      );

      expect(c.read(totaisDoMesProvider).requireValue.ganhos, 4200);
    });

    test('percentualComprometidoProvider usa previsto como renda', () async {
      final c = await montarComGanhos(
        ganhosDoMes: [('marcos', 1000, true)],
        parcelas: [('2026-10', 100)],
      );

      expect(
        c.read(percentualComprometidoProvider).requireValue,
        closeTo(0.1, 0.0001),
      );
    });

    test('ganhoAssumidoProjecaoProvider usa previsto quando so ha previsto',
        () async {
      final c = await montarComGanhos(
        ganhosDoMes: [('marcos', 3800, true)],
      );

      expect(c.read(ganhoAssumidoProjecaoProvider).requireValue, 3800);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/estado/providers_test.dart
```
Esperado: os testes que dependem só de previsto (sem nenhum ganho real) falham — `totaisDoMesProvider`/`percentualComprometidoProvider`/`ganhoAssumidoProjecaoProvider` ainda somam só ganho real, então "renda" fica 0 nesses casos.

- [ ] **Step 3: Implementar**

Em `lib/estado/providers.dart`, localize `totaisDoMesProvider`, `percentualComprometidoProvider` e `ganhoAssumidoProjecaoProvider` (todos já existentes) e substitua cada `calcularTotais(ganhos: ganhos, ...)` por `calcularTotais(ganhos: ganhosEfetivos(ganhos), ...)`:

```dart
final totaisDoMesProvider = Provider.autoDispose<AsyncValue<TotaisMes>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);

  return combinarAsyncValues(
    ref.watch(ganhosDoMesProvider(mes)),
    ref.watch(gastosDoMesProvider(mes)),
    (ganhos, gastos) => calcularTotais(
      ganhos: ganhosEfetivos(ganhos),
      gastos: gastos,
      membroId: membroId,
    ),
  );
});
```

```dart
final percentualComprometidoProvider =
    Provider.autoDispose<AsyncValue<double?>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);

  return combinarAsyncValues(
    ref.watch(parceladosDesdeProvider(mes)),
    ref.watch(ganhosDoMesProvider(mes)),
    (parcelas, ganhos) => percentualComprometido(
      comprometido: comprometidoNoMes(parcelas, mes, membroId: membroId),
      renda: calcularTotais(
        ganhos: ganhosEfetivos(ganhos),
        gastos: const [],
        membroId: membroId,
      ).ganhos,
    ),
  );
});
```

```dart
final ganhoAssumidoProjecaoProvider =
    Provider.autoDispose<AsyncValue<double>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);

  return ref.watch(ganhosDoMesProvider(mes)).whenData(
        (ganhos) => calcularTotais(
          ganhos: ganhosEfetivos(ganhos),
          gastos: const [],
          membroId: membroId,
        ).ganhos,
      );
});
```

Nenhum import novo é necessário — `ganhosEfetivos` está em `totais.dart`, já importado neste arquivo.

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/estado/providers_test.dart
```

- [ ] **Step 5: Rodar a suíte inteira, analisar e commitar**

`totaisDoMesProvider` alimenta `resumoCascataProvider` e `estouroProjetadoProvider`; confirme que nada quebrou na tela de Resumo.

```bash
flutter test
flutter analyze lib/estado/providers.dart
git add lib/estado/providers.dart test/estado/providers_test.dart
git commit -m "feat: totais/comprometimento/projecao usam ganhos efetivos (estado)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Estado — `serieProjecaoProvider` usa `ganhosEfetivosPorMes`

**Files:**
- Modify: `lib/estado/providers.dart`
- Test: `test/estado/providers_test.dart`

**Interfaces:**
- Consumes: `ganhosEfetivosPorMes` (Task 3), `ganhoAssumidoProjecaoProvider` (Task 4), `ganhosDoIntervaloProvider`/`JanelaMeses`/`janelaDe`/`mesesDaSerie`/`parceladosDesdeProvider`/`combinarAsyncValues` (já existem).
- Produces: `serieProjecaoProvider` reescrito — mesma assinatura pública (`Provider.autoDispose<AsyncValue<List<PontoProjecao>>>`), fonte do "ganho conhecido por mês" muda de `poteReservaProvider`+um único mês para `ganhosEfetivosPorMes` sobre a janela inteira.

**IMPORTANTE:** este é o ÚLTIMO lugar em `lib/estado/providers.dart` que lê `poteReservaProvider`/`Pote.proximoGanhoEsperado`. Depois desta tarefa, `poteReservaProvider` continua existindo (ainda é usado por `mesesCoberturaReservaProvider`, que NÃO muda), mas nada mais em `providers.dart` lê `proximoGanhoEsperado`. Isso deixa o código pronto para a Task 6 remover o campo do modelo sem quebrar nada no meio do caminho.

- [ ] **Step 1: Escrever os testes que falham**

Localize e REMOVA o grupo de testes `group('serieProjecaoProvider com proximoGanhoEsperado', ...)` inteiro em `test/estado/providers_test.dart` (ele testava o mecanismo antigo, que este passo substitui) e adicione, no lugar, ao final do arquivo:

```dart
  group('serieProjecaoProvider com ganhos efetivos', () {
    Future<ProviderContainer> montarProjecaoComGanhos({
      double ganhoMarcosOutubro = 5000,
      List<(String mesRef, double valor, bool previsto)> ganhosFuturos = const [],
    }) async {
      final ganhos = RepositorioGanhosFake();
      if (ganhoMarcosOutubro > 0) {
        await ganhos.adicionar(Ganho(
          id: '', mesRef: '2026-10', membroId: 'marcos',
          descricao: 'Salario', valor: ganhoMarcosOutubro,
          criadoEm: DateTime.utc(2026, 10, 1),
        ));
      }
      for (final (mesRef, valor, previsto) in ganhosFuturos) {
        await ganhos.adicionar(Ganho(
          id: '', mesRef: mesRef, membroId: 'marcos',
          descricao: previsto ? 'Previsto' : 'Real', valor: valor,
          criadoEm: DateTime.utc(2026, 10, 1), previsto: previsto,
        ));
      }

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(ganhos),
        repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ]);
      addTearDown(c.dispose);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 10));
      c.listen(ganhosDoMesProvider('2026-10'), (_, _) {});
      c.listen(
        ganhosDoIntervaloProvider(
          (inicio: '2026-10', fim: janelaDe(const MesRef(2026, 10), mesesDaSerie).last.valor),
        ),
        (_, _) {},
      );
      c.listen(parceladosDesdeProvider('2026-10'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('sem nenhum dado no mes seguinte, repete o ganho assumido', () async {
      final c = await montarProjecaoComGanhos(ganhoMarcosOutubro: 5000);

      final serie = c.read(serieProjecaoProvider).requireValue;
      expect(serie.every((p) => p.ganhos == 5000), isTrue);
    });

    test('mes seguinte so com previsto usa o previsto', () async {
      final c = await montarProjecaoComGanhos(
        ganhoMarcosOutubro: 5000,
        ganhosFuturos: [('2026-11', 3800, true)],
      );

      final serie = c.read(serieProjecaoProvider).requireValue;
      expect(serie[0].ganhos, 5000); // outubro: mes selecionado
      expect(serie[1].ganhos, 3800); // novembro: previsto
      expect(serie[2].ganhos, 5000); // dezembro: volta a repetir o assumido
    });

    test('mes com real e previsto: real vence', () async {
      final c = await montarProjecaoComGanhos(
        ganhoMarcosOutubro: 5000,
        ganhosFuturos: [
          ('2026-11', 3800, true),
          ('2026-11', 4200, false),
        ],
      );

      final serie = c.read(serieProjecaoProvider).requireValue;
      expect(serie[1].ganhos, 4200);
    });

    test('previsto em mais de um mes futuro: cada mes usa o seu', () async {
      final c = await montarProjecaoComGanhos(
        ganhoMarcosOutubro: 5000,
        ganhosFuturos: [
          ('2026-11', 3800, true),
          ('2026-12', 4100, true),
        ],
      );

      final serie = c.read(serieProjecaoProvider).requireValue;
      expect(serie[0].ganhos, 5000); // outubro
      expect(serie[1].ganhos, 3800); // novembro
      expect(serie[2].ganhos, 4100); // dezembro
      expect(serie[3].ganhos, 5000); // janeiro: sem dado, volta ao assumido
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/estado/providers_test.dart
```
Esperado: os testes com `ganhosFuturos` preenchido falham — o provider atual só olha o mês seguinte via `poteReservaProvider`, nunca `ganhosDoIntervaloProvider`, e não tem noção de "previsto".

- [ ] **Step 3: Implementar**

Em `lib/estado/providers.dart`, localize `serieProjecaoProvider` (o provider inteiro, do `final serieProjecaoProvider =` até o `});` que o fecha) e substitua por:

```dart
final serieProjecaoProvider =
    Provider.autoDispose<AsyncValue<List<PontoProjecao>>>((ref) {
  final inicio = ref.watch(mesSelecionadoProvider);
  final membroId = ref.watch(visaoProvider);
  final meses = janelaDe(inicio, mesesDaSerie);
  final janela = (inicio: meses.first.valor, fim: meses.last.valor);

  return combinarAsyncValues(
    combinarAsyncValues(
      ref.watch(ganhoAssumidoProjecaoProvider),
      ref.watch(parceladosDesdeProvider(inicio.valor)),
      (ganhoAssumido, parcelas) => (ganhoAssumido, parcelas),
    ),
    ref.watch(ganhosDoIntervaloProvider(janela)).whenData(
          (ganhosDoIntervalo) => ganhosEfetivosPorMes(
            ganhosDoIntervalo: ganhosDoIntervalo,
            meses: meses,
            membroId: membroId,
          ),
        ),
    (par, ganhosPorMes) => serieProjecao(
      meses: meses,
      ganhoMensalAssumido: par.$1,
      parcelas: par.$2,
      membroId: membroId,
      ganhosConhecidos: ganhosPorMes,
    ),
  );
});
```

Este bloco substitui inteiramente a versão anterior (que lia `poteReservaProvider` e `ganhosDoMesProvider(mesSeguinte)`). `toleranciaCentavo` deixa de ser necessário AQUI especificamente (continua usado por `estouroProjetadoProvider`, então o import não muda). `ganhosDoIntervaloProvider`/`JanelaMeses`/`janelaDe`/`mesesDaSerie` já existem e já são usados por `serieMensalProvider` no mesmo arquivo.

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/estado/providers_test.dart
```

- [ ] **Step 5: Rodar a suíte inteira, analisar e commitar**

```bash
flutter test
flutter analyze lib/estado/providers.dart
git add lib/estado/providers.dart test/estado/providers_test.dart
git commit -m "feat: serieProjecaoProvider usa ganhos efetivos na janela inteira (estado)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: Remover `Pote.proximoGanhoEsperado` e o campo "Vai ganhar" da UI

**Files:**
- Modify: `lib/dominio/models/pote.dart`
- Modify: `lib/ui/telas/tela_potes.dart`
- Test: `test/dominio/models/pote_test.dart`
- Test: `test/ui/tela_potes_test.dart`

**Interfaces:**
- Consumes: nada de outras tarefas (depende que a Task 5 já tenha removido a última leitura de `proximoGanhoEsperado` em `providers.dart`).
- Produces: `Pote` sem o campo `proximoGanhoEsperado`; `_TelaPotesState` sem o campo "Vai ganhar (próx. mês)", os controllers e a lógica associados.

**IMPORTANTE:** o campo `proximoGanhoEsperado` e o campo "Vai ganhar" na UI são as DUAS ÚLTIMAS coisas no código que ainda se referem a esse conceito (a Task 5 já removeu a leitura em `providers.dart`). Removê-los precisa ser feito NA MESMA tarefa/commit — remover só um dos dois deixaria o código sem compilar no meio do caminho (a UI constrói `Pote(..., proximoGanhoEsperado: ...)`; se o campo sumir do modelo antes da UI parar de referenciá-lo, o projeto não compila).

- [ ] **Step 1: Ajustar os testes que hoje cobrem o campo removido**

Em `test/dominio/models/pote_test.dart`, remova todo o texto `ehReserva: true, valorGuardado: 6000, proximoGanhoEsperado: 5000,` (e ocorrências parecidas) trocando por `ehReserva: true, valorGuardado: 6000,` — ou seja, tire toda menção a `proximoGanhoEsperado` dos testes existentes, incluindo do helper `poteBase(...)` (que tinha um parâmetro `proximoGanhoEsperado`, remova esse parâmetro) e da asserção `expect(reconstruido.proximoGanhoEsperado, 5000);` no teste de round-trip.

Em `test/ui/tela_potes_test.dart`, remova o `group('reserva de emergencia', ...)`'s teste `testWidgets('marcar reserva mostra os campos Guardado e Vai ganhar', ...)` — troque por uma versão que só verifica o campo Guardado:

```dart
    testWidgets('marcar reserva mostra o campo Guardado', (tester) async {
      await montar(tester);

      await tester.tap(find.byKey(const Key('reserva_0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guardado_0')), findsOneWidget);
      expect(find.byKey(const Key('vai_ganhar_0')), findsNothing);
    });
```

No teste `testWidgets('checkbox e campos nao aparecem por padrao', ...)`, remova a linha `expect(find.byKey(const Key('vai_ganhar_0')), findsNothing);` — o teste fica só com a asserção de `guardado_0`. Os testes `'marcar um pote como reserva desmarca o anterior'`, `'editar Guardado atualiza o rascunho e persiste ao salvar'` e os dois testes de "meses de cobertura" não mencionam `vai_ganhar` em nenhum lugar — não precisam de nenhuma mudança.

- [ ] **Step 2: Rodar e confirmar que os testes ajustados falham do jeito esperado**

```bash
flutter test test/dominio/models/pote_test.dart test/ui/tela_potes_test.dart
```
Esperado: os testes que ainda mencionam `vai_ganhar_0` continuam passando por enquanto (o campo ainda existe no código) — a mudança de verdade acontece no Step 3. Confirme só que os testes editados no Step 1 compilam.

- [ ] **Step 3: Implementar — remover do modelo e da UI juntos**

Em `lib/dominio/models/pote.dart`, remova o campo `proximoGanhoEsperado`: a linha `final double? proximoGanhoEsperado;` e seu comentário, o parâmetro `this.proximoGanhoEsperado,` do construtor, a linha `proximoGanhoEsperado: (mapa['proximoGanhoEsperado'] as num?)?.toDouble(),` de `fromMap`, o bloco `if (proximoGanhoEsperado != null) 'proximoGanhoEsperado': proximoGanhoEsperado,` de `toMap`, e o parâmetro `double? proximoGanhoEsperado,` + a linha `proximoGanhoEsperado: proximoGanhoEsperado ?? this.proximoGanhoEsperado,` de `copyWith`.

Em `lib/ui/telas/tela_potes.dart`:

1. Remova o mapa `_controladoresVaiGanhar` (declaração), o método `_controladorVaiGanhar(...)`, a limpeza em `dispose()` (o bloco `for (final c in _controladoresVaiGanhar.values) { c.dispose(); }`) e em `_resincronizarControladores()` (o bloco equivalente).
2. Em `_linha`, dentro do bloco `if (pote.ehReserva) Padding(... child: Row(children: [...]))`, remova inteiramente o segundo `Expanded` (o campo `vai_ganhar_$i` e o `SizedBox(width: 12)` que vem antes dele) — o `Row` fica só com o primeiro `Expanded` (o campo `guardado_$i`). Como agora só sobra um filho, simplifique trocando o `Row` por um `TextFormField` direto (sem `Row`/`Expanded` nenhum) com o mesmo conteúdo que o campo `guardado_$i` já tinha:

```dart
            if (pote.ehReserva)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextFormField(
                  key: Key('guardado_$i'),
                  controller: _controladorGuardado(i, pote.valorGuardado),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FormatadorMoeda()],
                  decoration: const InputDecoration(
                    labelText: 'Guardado',
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() {
                    final atual = _rascunho![i];
                    _rascunho![i] = Pote(
                      id: atual.id,
                      nome: atual.nome,
                      percentual: atual.percentual,
                      ordem: atual.ordem,
                      cor: atual.cor,
                      icone: atual.icone,
                      ehReserva: atual.ehReserva,
                      valorGuardado: parsearMoeda(v),
                    );
                  }),
                ),
              ),
```

(O `inputFormatters: [FormatadorMoeda()]` e `onChanged: (v) => ... parsearMoeda(v)` já eram assim depois da correção da revisão final da spec anterior — mantenha exatamente esse comportamento, só removendo o `Row`/`Expanded` em volta e o segundo campo.)

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/dominio/models/pote_test.dart test/ui/tela_potes_test.dart
```

- [ ] **Step 5: Rodar a suíte inteira, analisar e commitar**

```bash
flutter test
flutter analyze lib/dominio/models/pote.dart lib/ui/telas/tela_potes.dart
git add lib/dominio/models/pote.dart lib/ui/telas/tela_potes.dart test/dominio/models/pote_test.dart test/ui/tela_potes_test.dart
git commit -m "refactor: remove proximoGanhoEsperado do Pote e o campo Vai ganhar da UI

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: UI — marcar um lançamento de Ganho como previsto

**Files:**
- Modify: `lib/ui/telas/tela_ganhos.dart`
- Test: `test/ui/tela_ganhos_test.dart`

**Interfaces:**
- Consumes: `Ganho.previsto` (Task 1).
- Produces: `_FormularioState` ganha um checkbox "previsto"; `_ColunaMembro`'s `ListTile` mostra um rótulo "Previsto" quando `g.previsto` é true.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/ui/tela_ganhos_test.dart`, dentro de `void main() { ... }` (o arquivo já tem o helper `ganho(id, membroId, valor)` no topo, sem parâmetro `previsto` — para os novos testes, construa o `Ganho` diretamente em vez de usar o helper quando precisar de `previsto: true`):

```dart
  group('ganho previsto', () {
    testWidgets('marcar previsto no formulario grava Ganho.previsto true',
        (tester) async {
      await comLargura(tester, 1400);
      final repo = await montar(tester);

      await tester.tap(find.byKey(const Key('novo_ganho')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('form_descricao')), 'Salario previsto');
      await tester.enterText(find.byType(TextFormField).last, '380000');
      await tester.tap(find.byKey(const Key('form_previsto')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('form_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos, hasLength(1));
      expect(repo.todos.single.previsto, isTrue);
      expect(repo.todos.single.valor, 3800.0);
    });

    testWidgets('sem marcar previsto, grava Ganho.previsto false (padrao)',
        (tester) async {
      await comLargura(tester, 1400);
      final repo = await montar(tester);

      await tester.tap(find.byKey(const Key('novo_ganho')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('form_descricao')), 'Salario');
      await tester.enterText(find.byType(TextFormField).last, '500000');
      await tester.tap(find.byKey(const Key('form_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.single.previsto, isFalse);
    });

    testWidgets('lista mostra o rotulo Previsto so nos ganhos marcados',
        (tester) async {
      await comLargura(tester, 1400);
      await montar(tester, iniciais: [
        Ganho(
          id: '', mesRef: '2026-08', membroId: 'marcos',
          descricao: 'Salario previsto', valor: 3800,
          criadoEm: DateTime.utc(2026, 8, 1), previsto: true,
        ),
        ganho('', 'marcos', 4000),
      ]);

      expect(find.textContaining('Previsto'), findsOneWidget);
    });

    testWidgets('editar um ganho existente preserva o estado de previsto',
        (tester) async {
      await comLargura(tester, 1400);
      await montar(tester, iniciais: [
        Ganho(
          id: 'g1', mesRef: '2026-08', membroId: 'marcos',
          descricao: 'Salario previsto', valor: 3800,
          criadoEm: DateTime.utc(2026, 8, 1), previsto: true,
        ),
      ]);

      await tester.tap(find.byKey(const Key('ganho_g1')));
      await tester.pumpAndSettle();

      final checkbox =
          tester.widget<CheckboxListTile>(find.byKey(const Key('form_previsto')));
      expect(checkbox.value, isTrue);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/ui/tela_ganhos_test.dart
```
Esperado: falha — a `Key('form_previsto')` ainda não existe, e o rótulo "Previsto" ainda não aparece na lista.

- [ ] **Step 3: Implementar**

Em `lib/ui/telas/tela_ganhos.dart`, na classe `_FormularioState`:

1. Adicione o campo de estado, perto de `_membroId`:

```dart
  bool _previsto = false;
```

2. Em `initState()`, inicialize a partir do existente:

```dart
    _previsto = g?.previsto ?? false;
```

3. Em `_salvar()`, passe `previsto: _previsto` ao construir o `Ganho`:

```dart
    final ganho = Ganho(
      id: base?.id ?? '',
      mesRef: widget.mesRef,
      membroId: _membroId,
      descricao: _descricao.text.trim(),
      valor: parsearMoeda(_valor.text) ?? 0,
      criadoEm: base?.criadoEm ?? DateTime.now(),
      previsto: _previsto,
    );
```

4. No `build()`, adicione o `CheckboxListTile` entre o campo "Descrição" e o `CampoMoeda`:

```dart
          const SizedBox(height: 12),
          CheckboxListTile(
            key: const Key('form_previsto'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Isto é uma previsão (ainda não recebi)'),
            value: _previsto,
            onChanged: (v) => setState(() => _previsto = v ?? false),
          ),
          const SizedBox(height: 12),
          CampoMoeda(controlador: _valor),
```

(Isto substitui o único `const SizedBox(height: 12)` que hoje fica entre o campo Descrição e o `CampoMoeda` — o novo bloco acima já inclui os dois `SizedBox` ao redor do checkbox.)

Na classe `_ColunaMembro`, dentro do `ListTile.builder`'s `itemBuilder`, troque o `subtitle: Text(formatarReais(g.valor)),` por:

```dart
                              subtitle: g.previsto
                                  ? Text(
                                      '${formatarReais(g.valor)} · Previsto',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                    )
                                  : Text(formatarReais(g.valor)),
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/ui/tela_ganhos_test.dart
```

- [ ] **Step 5: Rodar a suíte inteira, analisar e commitar**

```bash
flutter test
flutter analyze lib/ui/telas/tela_ganhos.dart
git add lib/ui/telas/tela_ganhos.dart test/ui/tela_ganhos_test.dart
git commit -m "feat: marcar lancamento de Ganho como previsto (UI)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Final Checklist

- [ ] `flutter analyze` limpo no projeto inteiro.
- [ ] `flutter test` verde no projeto inteiro.
- [ ] Nenhuma Cloud Function nem regra do Firestore precisa de deploy — este plano é 100% client-side. `Ganho.previsto` é um campo novo opcional (compatível com documentos existentes); `Pote.proximoGanhoEsperado` sai do modelo, mas como nenhum documento gravado até agora dependia dele pra nada além do que a spec anterior fazia (só lido, nunca obrigatório), remover o campo não quebra leitura de documentos antigos — `fromMap` simplesmente ignora a chave se ainda existir no Firestore.
- [ ] Gerar um APK de release (`flutter build apk --release --split-per-abi`) e instalar no emulador/dispositivo pra conferir visualmente: marcar um Ganho como previsto na tela de Ganhos (aparece "Previsto" na lista), ver a Projeção usar esse valor no mês certo, ver a tela de Potes sem o campo "Vai ganhar" (só "Guardado").
