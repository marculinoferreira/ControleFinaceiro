# Métricas de análise financeira Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar 4 métricas de análise financeira ao app — percentual de comprometimento com dívida, alerta de estouro projetado por pote, tendência histórica por pote, e reserva de emergência (com integração na Projeção) — sobre dado que já existe hoje.

**Architecture:** Cada métrica é uma função de domínio pura + um provider Riverpod que a alimenta com dado real + um ponto de UI existente que ganha um elemento novo (rodapé, texto de alerta, campo, ou um 8º gráfico). Nenhuma escrita nova de lançamento; a única mudança de modelo é `Pote` ganhar 3 campos opcionais usados só quando ele é o pote de reserva.

**Tech Stack:** Flutter, Riverpod (`Provider`/`NotifierProvider`/`.autoDispose`), fl_chart (`LineChart`), Dart puro para o domínio.

**Spec:** `docs/superpowers/specs/2026-09-19-metricas-financeiras-design.md`

## Global Constraints

- Nenhuma escrita nova de lançamento (gasto/ganho); as 4 métricas só leem e combinam dado que já existe.
- `Pote` ganha `ehReserva` (bool, default false), `valorGuardado` (double?), `proximoGanhoEsperado` (double?) — nulos/false não quebram dado legado sem esses campos no Firestore.
- No máximo um pote pode ter `ehReserva == true` por vez.
- O alerta de estouro projetado (item 2) só calcula quando o mês selecionado é `MesRef.atual()` — em qualquer outro mês, nenhum alerta aparece.
- `proximoGanhoEsperado` só alimenta a Projeção (a) para o mês imediatamente seguinte ao mês selecionado, (b) só enquanto esse mês não tiver ganho real lançado (o real tem prioridade), e (c) só quando a visão é "Casal" (`visaoProvider == null`).
- Faixas do percentual de comprometimento: <30% verde, 30–50% amarelo, >50% vermelho.
- Toda leitura assíncrona nova passa pelos três ramos de `AsyncValue` (via `combinarAsyncValues`/`.whenData`), nunca `.value ?? []`.
- Testes de provider que dependem de "hoje" usam `MesRef.atual()`/`DateTime.now()` computados no próprio teste, nunca uma data hardcoded — os testes precisam passar em qualquer dia em que rodem. Testes de widget que dependem desses providers isolam o cálculo via `overrideWith` direto no provider, sem depender da cadeia de datas.

---

## Task 1: Domínio — percentual de comprometimento

**Files:**
- Modify: `lib/dominio/totais.dart`
- Test: `test/dominio/totais_test.dart`

**Interfaces:**
- Consumes: `toleranciaCentavo` (de `cascata.dart`).
- Produces: `double? percentualComprometido({required double comprometido, required double renda})`.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/dominio/totais_test.dart` (o arquivo já importa `totais.dart`; adicione também `import 'package:controle_financeiro/dominio/cascata.dart' show toleranciaCentavo;` no topo, só para o teste de tolerância):

```dart
  group('percentualComprometido', () {
    test('sem renda devolve nulo', () {
      expect(
        percentualComprometido(comprometido: 300, renda: 0),
        isNull,
      );
    });

    test('comprometido zero da 0%', () {
      expect(
        percentualComprometido(comprometido: 0, renda: 1000),
        0,
      );
    });

    test('comprometido igual a renda da 100%', () {
      expect(
        percentualComprometido(comprometido: 1000, renda: 1000),
        1,
      );
    });

    test('fracao normal', () {
      expect(
        percentualComprometido(comprometido: 300, renda: 1000),
        closeTo(0.3, 0.0001),
      );
    });

    test('renda dentro da tolerancia de centavo tambem conta como sem renda',
        () {
      expect(
        percentualComprometido(
          comprometido: 100,
          renda: toleranciaCentavo / 2,
        ),
        isNull,
      );
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/dominio/totais_test.dart
```
Esperado: falha de compilação — `percentualComprometido` não existe.

- [ ] **Step 3: Implementar**

Em `lib/dominio/totais.dart`, adicione o import e a função ao final do arquivo:

```dart
import 'models/ganho.dart';
import 'models/gasto.dart';
import 'cascata.dart' show toleranciaCentavo;
```

```dart
/// Fracao da renda do mes ja comprometida em parcelas. Nula sem renda, para
/// nao dividir por zero — a UI mostra "sem renda" nesse caso, nao 0% nem
/// infinito.
double? percentualComprometido({
  required double comprometido,
  required double renda,
}) {
  if (renda <= toleranciaCentavo) return null;
  return comprometido / renda;
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
git commit -m "feat: percentual de comprometimento com divida (dominio)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: Domínio — projeção linear de estouro por pote

**Files:**
- Modify: `lib/dominio/cascata.dart`
- Test: `test/dominio/cascata_test.dart`

**Interfaces:**
- Consumes: nada de outras tarefas.
- Produces: `double? projetarGastoPote({required double gastoAteHoje, required int diaAtual, required int diasDoMes})`.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/dominio/cascata_test.dart` (dentro de `void main() { ... }`, o arquivo já importa `cascata.dart`):

```dart
  group('projetarGastoPote', () {
    test('dia zero devolve nulo (evita divisao por zero)', () {
      expect(
        projetarGastoPote(gastoAteHoje: 100, diaAtual: 0, diasDoMes: 30),
        isNull,
      );
    });

    test('dia 1: o gasto do dia vale por todo o mes', () {
      expect(
        projetarGastoPote(gastoAteHoje: 100, diaAtual: 1, diasDoMes: 30),
        3000,
      );
    });

    test('meio do mes: extrapola o ritmo ate o fim do mes', () {
      expect(
        projetarGastoPote(gastoAteHoje: 450, diaAtual: 15, diasDoMes: 30),
        900,
      );
    });

    test('ultimo dia do mes: a projecao e o proprio gasto acumulado', () {
      expect(
        projetarGastoPote(gastoAteHoje: 900, diaAtual: 30, diasDoMes: 30),
        900,
      );
    });

    test('sem gasto nenhum, a projecao e zero', () {
      expect(
        projetarGastoPote(gastoAteHoje: 0, diaAtual: 10, diasDoMes: 30),
        0,
      );
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/dominio/cascata_test.dart
```
Esperado: falha de compilação — `projetarGastoPote` não existe.

- [ ] **Step 3: Implementar**

Em `lib/dominio/cascata.dart`, adicione ao final do arquivo:

```dart
/// Projecao linear de gasto de um pote ate o fim do mes, dado o ritmo de
/// gasto ate [diaAtual]. Nula quando [diaAtual] e zero (nao deveria
/// acontecer — todo mes tem pelo menos o dia 1 — mas evita divisao por
/// zero em vez de lancar).
double? projetarGastoPote({
  required double gastoAteHoje,
  required int diaAtual,
  required int diasDoMes,
}) {
  if (diaAtual <= 0) return null;
  return gastoAteHoje / diaAtual * diasDoMes;
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/dominio/cascata_test.dart
```

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/dominio/cascata.dart
git add lib/dominio/cascata.dart test/dominio/cascata_test.dart
git commit -m "feat: projecao linear de estouro por pote (dominio)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: Domínio — tendência histórica por pote

**Files:**
- Modify: `lib/dominio/serie_mensal.dart`
- Test: `test/dominio/serie_mensal_test.dart`

**Interfaces:**
- Consumes: `PontoComprometido` (já existe no mesmo arquivo), `MesRef`, `Gasto`.
- Produces: `List<PontoComprometido> serieGastoPote({required List<MesRef> meses, required List<Gasto> gastos, required String poteId, String? membroId})`.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/dominio/serie_mensal_test.dart` (dentro de `void main() { ... }`; o arquivo já importa `serie_mensal.dart`, `Gasto`, `MesRef`):

```dart
  group('serieGastoPote', () {
    Gasto gastoDoPote(String mesRef, String poteId, double valor,
            {String membroId = 'marcos'}) =>
        Gasto(
          id: 'g-$mesRef-$poteId-$membroId',
          mesRef: mesRef,
          membroId: membroId,
          poteId: poteId,
          descricao: 'Compra',
          valor: valor,
          criadoEm: DateTime.utc(2026, 1, 1),
          parcelado: false,
        );

    test('mes sem gasto no pote entra com zero', () {
      final serie = serieGastoPote(
        meses: janelaAte(const MesRef(2026, 8), 3),
        gastos: [gastoDoPote('2026-08', 'p1', 500)],
        poteId: 'p1',
      );

      expect(serie.map((p) => p.valor).toList(), [0, 0, 500]);
    });

    test('soma gastos do mesmo pote e mes', () {
      final serie = serieGastoPote(
        meses: janelaAte(const MesRef(2026, 8), 1),
        gastos: [
          gastoDoPote('2026-08', 'p1', 200),
          gastoDoPote('2026-08', 'p1', 150),
        ],
        poteId: 'p1',
      );

      expect(serie.single.valor, 350);
    });

    test('ignora gasto de outro pote', () {
      final serie = serieGastoPote(
        meses: janelaAte(const MesRef(2026, 8), 1),
        gastos: [gastoDoPote('2026-08', 'p2', 999)],
        poteId: 'p1',
      );

      expect(serie.single.valor, 0);
    });

    test('filtra por membroId quando informado', () {
      final serie = serieGastoPote(
        meses: janelaAte(const MesRef(2026, 8), 1),
        gastos: [
          gastoDoPote('2026-08', 'p1', 200, membroId: 'marcos'),
          gastoDoPote('2026-08', 'p1', 300, membroId: 'silvia'),
        ],
        poteId: 'p1',
        membroId: 'silvia',
      );

      expect(serie.single.valor, 300);
    });

    test('ignora gasto fora da janela', () {
      final serie = serieGastoPote(
        meses: janelaAte(const MesRef(2026, 8), 1),
        gastos: [gastoDoPote('2020-01', 'p1', 999)],
        poteId: 'p1',
      );

      expect(serie.single.valor, 0);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/dominio/serie_mensal_test.dart
```
Esperado: falha de compilação — `serieGastoPote` não existe.

- [ ] **Step 3: Implementar**

Em `lib/dominio/serie_mensal.dart`, adicione ao final do arquivo:

```dart
/// Gasto classificado num pote especifico, mes a mes, nos [meses] dados.
/// Mesma forma de `serieComprometimento`, mas soma gasto real classificado
/// no pote (nao parcela em aberto) — as duas series sao "um mes, um valor",
/// so a origem do valor muda, entao reaproveitam `PontoComprometido`.
List<PontoComprometido> serieGastoPote({
  required List<MesRef> meses,
  required List<Gasto> gastos,
  required String poteId,
  String? membroId,
}) {
  final somaPorMes = <String, double>{};
  for (final g in gastos) {
    if (g.poteId != poteId) continue;
    if (membroId != null && g.membroId != membroId) continue;
    somaPorMes[g.mesRef] = (somaPorMes[g.mesRef] ?? 0) + g.valor;
  }
  return [
    for (final mes in meses)
      PontoComprometido(mes: mes, valor: somaPorMes[mes.valor] ?? 0),
  ];
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
git commit -m "feat: serie de tendencia historica por pote (dominio)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Domínio — meses de cobertura da reserva

**Files:**
- Create: `lib/dominio/reserva.dart`
- Test: `test/dominio/reserva_test.dart`

**Interfaces:**
- Consumes: `toleranciaCentavo` (de `cascata.dart`).
- Produces: `double? mesesDeCobertura({required double? valorGuardado, required double gastoDoMes})`.

- [ ] **Step 1: Escrever os testes que falham**

Crie `test/dominio/reserva_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/reserva.dart';

void main() {
  group('mesesDeCobertura', () {
    test('sem valor guardado devolve nulo', () {
      expect(
        mesesDeCobertura(valorGuardado: null, gastoDoMes: 1500),
        isNull,
      );
    });

    test('sem gasto no mes devolve nulo (nao ha o que dividir)', () {
      expect(
        mesesDeCobertura(valorGuardado: 6000, gastoDoMes: 0),
        isNull,
      );
    });

    test('caso normal', () {
      expect(
        mesesDeCobertura(valorGuardado: 6000, gastoDoMes: 1500),
        4,
      );
    });

    test('valor guardado zero mas presente da zero meses, nao nulo', () {
      expect(
        mesesDeCobertura(valorGuardado: 0, gastoDoMes: 1500),
        0,
      );
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/dominio/reserva_test.dart
```
Esperado: falha de compilação — o arquivo `lib/dominio/reserva.dart` ainda não existe.

- [ ] **Step 3: Implementar**

Crie `lib/dominio/reserva.dart`:

```dart
import 'cascata.dart' show toleranciaCentavo;

/// Quantos meses o valor guardado no pote de reserva cobre, dado o gasto
/// de um mes de referencia. Nula sem valor guardado (pote marcado como
/// reserva mas ainda sem o campo preenchido) ou sem gasto no mes (divisao
/// por zero nao faz sentido: "cobre infinitos meses" nao e uma resposta
/// util).
double? mesesDeCobertura({
  required double? valorGuardado,
  required double gastoDoMes,
}) {
  if (valorGuardado == null) return null;
  if (gastoDoMes <= toleranciaCentavo) return null;
  return valorGuardado / gastoDoMes;
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/dominio/reserva_test.dart
```

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/dominio/reserva.dart
git add lib/dominio/reserva.dart test/dominio/reserva_test.dart
git commit -m "feat: meses de cobertura da reserva de emergencia (dominio)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Domínio — `Pote` ganha os campos da reserva

**Files:**
- Modify: `lib/dominio/models/pote.dart`
- Test: `test/dominio/models/pote_test.dart` (novo arquivo)

**Interfaces:**
- Consumes: nada de outras tarefas.
- Produces: `Pote` com `bool ehReserva` (default `false`), `double? valorGuardado`, `double? proximoGanhoEsperado`; `Pote.fromMap`/`toMap`/`copyWith` atualizados para incluir os 3 campos.

- [ ] **Step 1: Escrever os testes que falham**

Crie `test/dominio/models/pote_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';

Pote poteBase({
  bool ehReserva = false,
  double? valorGuardado,
  double? proximoGanhoEsperado,
}) =>
    Pote(
      id: 'p1',
      nome: 'Reserva',
      percentual: 10,
      ordem: 0,
      cor: '#2E7D32',
      icone: 'cofre',
      ehReserva: ehReserva,
      valorGuardado: valorGuardado,
      proximoGanhoEsperado: proximoGanhoEsperado,
    );

void main() {
  group('Pote com campos de reserva', () {
    test('default: ehReserva falso, guardado e vaiGanhar nulos', () {
      const pote = Pote(
        id: 'p1',
        nome: 'Custo fixo',
        percentual: 60,
        ordem: 0,
        cor: '#2E7D32',
        icone: 'casa',
      );

      expect(pote.ehReserva, isFalse);
      expect(pote.valorGuardado, isNull);
      expect(pote.proximoGanhoEsperado, isNull);
    });

    test('toMap/fromMap fazem round-trip com os 3 campos preenchidos', () {
      final pote = poteBase(
        ehReserva: true,
        valorGuardado: 6000,
        proximoGanhoEsperado: 5000,
      );

      final reconstruido = Pote.fromMap('p1', pote.toMap());

      expect(reconstruido.ehReserva, isTrue);
      expect(reconstruido.valorGuardado, 6000);
      expect(reconstruido.proximoGanhoEsperado, 5000);
    });

    test('fromMap sem os campos novos (dado legado) cai nos defaults', () {
      final pote = Pote.fromMap('p1', const {
        'nome': 'Custo fixo',
        'percentual': 60,
        'ordem': 0,
        'cor': '#2E7D32',
        'icone': 'casa',
      });

      expect(pote.ehReserva, isFalse);
      expect(pote.valorGuardado, isNull);
      expect(pote.proximoGanhoEsperado, isNull);
    });

    test('toMap de pote sem reserva nao inclui guardado/vaiGanhar', () {
      final mapa = poteBase().toMap();

      expect(mapa.containsKey('valorGuardado'), isFalse);
      expect(mapa.containsKey('proximoGanhoEsperado'), isFalse);
      expect(mapa['ehReserva'], isFalse);
    });

    test('copyWith preserva os campos de reserva quando nao especificados',
        () {
      final pote = poteBase(ehReserva: true, valorGuardado: 6000);
      final renomeado = pote.copyWith(nome: 'Reserva de emergencia');

      expect(renomeado.ehReserva, isTrue);
      expect(renomeado.valorGuardado, 6000);
    });

    test('copyWith troca ehReserva para false explicitamente', () {
      final pote = poteBase(ehReserva: true);
      final desmarcado = pote.copyWith(ehReserva: false);

      expect(desmarcado.ehReserva, isFalse);
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/dominio/models/pote_test.dart
```
Esperado: falha de compilação — `Pote` ainda não tem `ehReserva`/`valorGuardado`/`proximoGanhoEsperado`.

- [ ] **Step 3: Implementar**

Substitua o conteúdo de `lib/dominio/models/pote.dart` por:

```dart
/// Categoria de orcamento. A [ordem] define a prioridade na cascata.
class Pote {
  final String id;
  final String nome;
  final double percentual;
  final int ordem;
  final String cor;   // hex "#RRGGBB"
  final String icone; // chave textual mapeada para IconData na UI

  /// Marca este como o pote de reserva de emergencia da casa. No maximo um
  /// pote pode ter isto true por vez -- a UI desmarca o anterior ao marcar
  /// um novo.
  final bool ehReserva;

  /// Quanto ja esta guardado, digitado manualmente. So tem sentido quando
  /// [ehReserva] e true; nulo enquanto o usuario nao preencheu.
  final double? valorGuardado;

  /// Quanto se espera ganhar no mes seguinte ao selecionado, digitado
  /// manualmente. So tem sentido quando [ehReserva] e true. Alimenta
  /// `serieProjecaoProvider` para o mes imediatamente seguinte, so enquanto
  /// esse mes nao tiver ganho real lancado.
  final double? proximoGanhoEsperado;

  const Pote({
    required this.id,
    required this.nome,
    required this.percentual,
    required this.ordem,
    required this.cor,
    required this.icone,
    this.ehReserva = false,
    this.valorGuardado,
    this.proximoGanhoEsperado,
  });

  factory Pote.fromMap(String id, Map<String, dynamic> mapa) => Pote(
        id: id,
        nome: mapa['nome'] as String,
        // Firestore devolve int quando o valor gravado nao tem decimal.
        percentual: (mapa['percentual'] as num).toDouble(),
        ordem: (mapa['ordem'] as num).toInt(),
        cor: mapa['cor'] as String? ?? '#607D8B',
        icone: mapa['icone'] as String? ?? 'carteira',
        ehReserva: mapa['ehReserva'] as bool? ?? false,
        valorGuardado: (mapa['valorGuardado'] as num?)?.toDouble(),
        proximoGanhoEsperado:
            (mapa['proximoGanhoEsperado'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'percentual': percentual,
        'ordem': ordem,
        'cor': cor,
        'icone': icone,
        'ehReserva': ehReserva,
        if (valorGuardado != null) 'valorGuardado': valorGuardado,
        if (proximoGanhoEsperado != null)
          'proximoGanhoEsperado': proximoGanhoEsperado,
      };

  Pote copyWith({
    String? id,
    String? nome,
    double? percentual,
    int? ordem,
    String? cor,
    String? icone,
    bool? ehReserva,
    double? valorGuardado,
    double? proximoGanhoEsperado,
  }) =>
      Pote(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        percentual: percentual ?? this.percentual,
        ordem: ordem ?? this.ordem,
        cor: cor ?? this.cor,
        icone: icone ?? this.icone,
        ehReserva: ehReserva ?? this.ehReserva,
        valorGuardado: valorGuardado ?? this.valorGuardado,
        proximoGanhoEsperado:
            proximoGanhoEsperado ?? this.proximoGanhoEsperado,
      );
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/dominio/models/pote_test.dart
```

- [ ] **Step 5: Rodar a suíte inteira, analisar e commitar**

`Pote` é usado em muitos arquivos existentes (`cascata.dart`, `graficos.dart`, `tela_potes.dart` etc.) — como todos os campos novos têm default, nenhum construtor existente deveria quebrar, mas confirme com a suíte inteira antes de seguir.

```bash
flutter test
flutter analyze lib/dominio/models/pote.dart
git add lib/dominio/models/pote.dart test/dominio/models/pote_test.dart
git commit -m "feat: Pote ganha campos de reserva de emergencia (dominio)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: Domínio — `serieProjecao` aceita ganhos conhecidos por mês

**Files:**
- Modify: `lib/dominio/serie_mensal.dart`
- Test: `test/dominio/serie_mensal_test.dart`

**Interfaces:**
- Consumes: `PontoProjecao`, `comprometidoNoMes` (já existem/importados no arquivo).
- Produces: `serieProjecao` ganha o parâmetro opcional `Map<String, double> ganhosConhecidos = const {}`.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final do `group('serieProjecao', ...)` já existente em `test/dominio/serie_mensal_test.dart` (o grupo já tem um helper `parcela(...)` local — reaproveite):

```dart
    test('mes presente em ganhosConhecidos usa o valor do mapa', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 3),
        ganhoMensalAssumido: 5000,
        parcelas: const [],
        ganhosConhecidos: const {'2026-09': 5500},
      );

      expect(serie[0].ganhos, 5000); // 2026-08: nao esta no mapa
      expect(serie[1].ganhos, 5500); // 2026-09: esta no mapa
      expect(serie[2].ganhos, 5000); // 2026-10: nao esta no mapa
    });

    test('mapa vazio (default) se comporta como antes', () {
      final serie = serieProjecao(
        meses: janelaDe(const MesRef(2026, 8), 2),
        ganhoMensalAssumido: 5000,
        parcelas: const [],
      );

      expect(serie.every((p) => p.ganhos == 5000), isTrue);
    });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/dominio/serie_mensal_test.dart
```
Esperado: falha de compilação — `serieProjecao` ainda não aceita `ganhosConhecidos`.

- [ ] **Step 3: Implementar**

Em `lib/dominio/serie_mensal.dart`, localize a função `serieProjecao` (adicionada por um plano anterior) e substitua por:

```dart
List<PontoProjecao> serieProjecao({
  required List<MesRef> meses,
  required double ganhoMensalAssumido,
  required List<Gasto> parcelas,
  String? membroId,
  Map<String, double> ganhosConhecidos = const {},
}) =>
    [
      for (final mes in meses)
        PontoProjecao(
          mes: mes,
          ganhos: ganhosConhecidos[mes.valor] ?? ganhoMensalAssumido,
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
git commit -m "feat: serieProjecao aceita ganhos conhecidos por mes (dominio)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: Estado — percentual de comprometimento

**Files:**
- Modify: `lib/estado/providers.dart`
- Test: `test/estado/providers_test.dart`

**Interfaces:**
- Consumes: `percentualComprometido` (Task 1), `comprometidoNoMes`, `calcularTotais`, `mesSelecionadoProvider`, `visaoProvider`, `parceladosDesdeProvider`, `ganhosDoMesProvider`, `combinarAsyncValues` (já existem).
- Produces: `final percentualComprometidoProvider = Provider.autoDispose<AsyncValue<double?>>(...)`.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/estado/providers_test.dart`, dentro de `void main() { ... }` (o arquivo já tem o padrão `ProviderContainer` + overrides de repositório usado em grupos anteriores — reaproveite a mesma casa/potes/cartões mínimos):

```dart
  group('percentualComprometidoProvider', () {
    Future<ProviderContainer> montarComprometimento({
      double ganhoMarcos = 0,
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
          quantidadeParcelas: 2,
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

    test('sem renda devolve nulo', () async {
      final c = await montarComprometimento(
        ganhoMarcos: 0,
        parcelas: [('2026-08', 100)],
      );

      expect(c.read(percentualComprometidoProvider).requireValue, isNull);
    });

    test('calcula a fracao do comprometido de 2026-08 sobre a renda', () async {
      // Uma compra de 2 parcelas de 100 gera uma em 2026-08 e outra em
      // 2026-09; comprometidoNoMes('2026-08') pega so a primeira.
      final c = await montarComprometimento(
        ganhoMarcos: 1000,
        parcelas: [('2026-08', 100)],
      );

      expect(
        c.read(percentualComprometidoProvider).requireValue,
        closeTo(0.1, 0.0001),
      );
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/estado/providers_test.dart
```
Esperado: falha por `percentualComprometidoProvider` não definido.

- [ ] **Step 3: Implementar**

Em `lib/estado/providers.dart`, adicione ao final do arquivo:

```dart
/// Percentual da renda do mes selecionado ja comprometido em parcelas,
/// respeitando a visao. Nulo sem renda no mes.
final percentualComprometidoProvider =
    Provider.autoDispose<AsyncValue<double?>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);

  return combinarAsyncValues(
    ref.watch(parceladosDesdeProvider(mes)),
    ref.watch(ganhosDoMesProvider(mes)),
    (parcelas, ganhos) => percentualComprometido(
      comprometido: comprometidoNoMes(parcelas, mes, membroId: membroId),
      renda:
          calcularTotais(ganhos: ganhos, gastos: const [], membroId: membroId)
              .ganhos,
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
git commit -m "feat: provider do percentual de comprometimento com divida (estado)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 8: Estado — alerta de estouro projetado

**Files:**
- Modify: `lib/estado/providers.dart`
- Test: `test/estado/providers_test.dart`

**Interfaces:**
- Consumes: `projetarGastoPote` (Task 2), `resumoCascataProvider`, `gastosPorPoteProvider`, `mesSelecionadoProvider`, `MesRef.atual()`, `toleranciaCentavo` (já existem/importados).
- Produces: `final estouroProjetadoProvider = Provider.autoDispose<AsyncValue<Map<String, double>>>(...)`.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/estado/providers_test.dart`. Este teste depende do dia real em que roda — monta o container com `mesSelecionadoProvider` apontando pro `MesRef.atual()` de verdade, e calcula o valor esperado com a mesma fórmula que o provider usa, em vez de um número fixo (assim o teste passa em qualquer dia):

```dart
  group('estouroProjetadoProvider', () {
    Future<ProviderContainer> montarEstouro({
      required MesRef mesSelecionado,
      double ganhoMarcos = 1000,
      double gastoNoPote = 0,
    }) async {
      final ganhos = RepositorioGanhosFake();
      final gastos = RepositorioGastosFake();
      final mesRef = mesSelecionado.valor;

      if (ganhoMarcos > 0) {
        await ganhos.adicionar(Ganho(
          id: '', mesRef: mesRef, membroId: 'marcos',
          descricao: 'Salario', valor: ganhoMarcos,
          criadoEm: DateTime.utc(2026, 1, 1),
        ));
      }
      if (gastoNoPote > 0) {
        await gastos.adicionar(
          base: Gasto(
            id: '', mesRef: mesRef, membroId: 'marcos', poteId: 'p1',
            descricao: 'Compra', valor: gastoNoPote,
            criadoEm: DateTime.utc(2026, 1, 2), parcelado: false,
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
      c.read(mesSelecionadoProvider.notifier).irPara(mesSelecionado);
      c.listen(ganhosDoMesProvider(mesRef), (_, _) {});
      c.listen(gastosDoMesProvider(mesRef), (_, _) {});
      c.listen(potesProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('mes selecionado diferente de hoje: mapa vazio', () async {
      // Janeiro de 2020 nunca vai ser "hoje" de novo.
      final c = await montarEstouro(mesSelecionado: const MesRef(2020, 1));

      expect(c.read(estouroProjetadoProvider).requireValue, isEmpty);
    });

    test('mes selecionado e hoje, gasto no ritmo do previsto: sem excesso',
        () async {
      // potes = [p1 60%, p2 40%] sobre 1000 de renda -> previsto p1 = 600.
      // Gasta so uma fracao pequena, sempre abaixo do previsto projetado.
      final c = await montarEstouro(
        mesSelecionado: MesRef.atual(),
        ganhoMarcos: 1000,
        gastoNoPote: 1,
      );

      expect(c.read(estouroProjetadoProvider).requireValue, isEmpty);
    });

    test('mes selecionado e hoje, ritmo de gasto estoura o previsto',
        () async {
      final hoje = DateTime.now();
      final diasDoMes = DateTime(hoje.year, hoje.month + 1, 0).day;
      // previsto p1 = 600 (60% de 1000). Gasta o suficiente no dia de hoje
      // para que a extrapolacao linear passe de 600.
      final gastoNoPote = 600.0 / diasDoMes * hoje.day + 50;

      final c = await montarEstouro(
        mesSelecionado: MesRef.atual(),
        ganhoMarcos: 1000,
        gastoNoPote: gastoNoPote,
      );

      final excessos = c.read(estouroProjetadoProvider).requireValue;
      expect(excessos.containsKey('p1'), isTrue);
      expect(excessos['p1'], greaterThan(0));
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/estado/providers_test.dart
```
Esperado: falha por `estouroProjetadoProvider` não definido.

- [ ] **Step 3: Implementar**

Em `lib/estado/providers.dart`, adicione ao final do arquivo:

```dart
/// Pote -> quanto ele deve passar do previsto ate o fim do mes, no ritmo
/// atual. So calcula no mes real de hoje; em qualquer outro mes selecionado
/// devolve um mapa vazio (nenhum alerta).
final estouroProjetadoProvider =
    Provider.autoDispose<AsyncValue<Map<String, double>>>((ref) {
  final mesSelecionado = ref.watch(mesSelecionadoProvider);
  if (mesSelecionado != MesRef.atual()) {
    return const AsyncData({});
  }

  final hoje = DateTime.now();
  final diasDoMes = DateTime(hoje.year, hoje.month + 1, 0).day;

  return combinarAsyncValues(
    ref.watch(resumoCascataProvider),
    ref.watch(gastosPorPoteProvider),
    (resumo, porPote) {
      final excessos = <String, double>{};
      for (final linha in resumo.linhas) {
        final gastoAteHoje = porPote[linha.pote.id] ?? 0;
        final projetado = projetarGastoPote(
          gastoAteHoje: gastoAteHoje,
          diaAtual: hoje.day,
          diasDoMes: diasDoMes,
        );
        if (projetado == null) continue;
        final excesso = projetado - linha.previsto;
        if (excesso > toleranciaCentavo) excessos[linha.pote.id] = excesso;
      }
      return excessos;
    },
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
git commit -m "feat: provider do alerta de estouro projetado por pote (estado)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 9: Estado — tendência histórica por pote

**Files:**
- Modify: `lib/estado/providers.dart`
- Test: `test/estado/providers_test.dart`

**Interfaces:**
- Consumes: `serieGastoPote` (Task 3), `janelaAte`, `gastosDoIntervaloProvider`, `JanelaMeses`, `mesSelecionadoProvider`, `visaoProvider` (já existem).
- Produces: `const int mesesDaTendencia = 6;` e `final tendenciaPoteProvider = Provider.autoDispose.family<AsyncValue<List<PontoComprometido>>, String>(...)`.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/estado/providers_test.dart`:

```dart
  group('tendenciaPoteProvider', () {
    Future<ProviderContainer> montarTendencia({
      List<(String mesRef, String poteId, double valor)> gastos = const [],
    }) async {
      final repoGastos = RepositorioGastosFake();
      for (final (mesRef, poteId, valor) in gastos) {
        await repoGastos.adicionar(
          base: Gasto(
            id: '', mesRef: mesRef, membroId: 'marcos', poteId: poteId,
            descricao: 'Compra', valor: valor,
            criadoEm: DateTime.utc(2026, 1, 1), parcelado: false,
          ),
          quantidadeParcelas: 1,
        );
      }

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(repoGastos),
      ]);
      addTearDown(c.dispose);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      final janela = (
        inicio: janelaAte(const MesRef(2026, 8), mesesDaTendencia).first.valor,
        fim: '2026-08',
      );
      c.listen(gastosDoIntervaloProvider(janela), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('serie de 6 meses terminando no mes selecionado', () async {
      final c = await montarTendencia(gastos: [('2026-08', 'p1', 400)]);

      final serie = c.read(tendenciaPoteProvider('p1')).requireValue;
      expect(serie, hasLength(mesesDaTendencia));
      expect(serie.last.valor, 400);
    });

    test('filtra pelo poteId pedido', () async {
      final c = await montarTendencia(gastos: [
        ('2026-08', 'p1', 400),
        ('2026-08', 'p2', 999),
      ]);

      final serie = c.read(tendenciaPoteProvider('p1')).requireValue;
      expect(serie.last.valor, 400);
    });

    test('mes sem gasto no pote entra com zero', () async {
      final c = await montarTendencia();

      final serie = c.read(tendenciaPoteProvider('p1')).requireValue;
      expect(serie.every((p) => p.valor == 0), isTrue);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/estado/providers_test.dart
```
Esperado: falha por `tendenciaPoteProvider`/`mesesDaTendencia` não definidos.

- [ ] **Step 3: Implementar**

Em `lib/estado/providers.dart`, adicione ao final do arquivo:

```dart
/// Quantos meses a tendencia por pote cobre, terminando no mes selecionado.
/// Janela mais curta que `mesesDaSerie` (12): o objetivo aqui e enxergar
/// tendencia recente, nao repetir o grafico de evolucao anual.
const int mesesDaTendencia = 6;

/// Serie de gasto de um pote nos ultimos [mesesDaTendencia] meses,
/// terminando no mes selecionado.
final tendenciaPoteProvider =
    Provider.autoDispose.family<AsyncValue<List<PontoComprometido>>, String>(
        (ref, poteId) {
  final fim = ref.watch(mesSelecionadoProvider);
  final membroId = ref.watch(visaoProvider);
  final meses = janelaAte(fim, mesesDaTendencia);
  final janela = (inicio: meses.first.valor, fim: fim.valor);

  return ref.watch(gastosDoIntervaloProvider(janela)).whenData(
        (gastos) => serieGastoPote(
          meses: meses,
          gastos: gastos,
          poteId: poteId,
          membroId: membroId,
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
git commit -m "feat: provider da tendencia historica por pote (estado)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 10: Estado — pote de reserva e meses de cobertura

**Files:**
- Modify: `lib/estado/providers.dart`
- Test: `test/estado/providers_test.dart`

**Interfaces:**
- Consumes: `mesesDeCobertura` (Task 4), `Pote` com campos de reserva (Task 5), `potesProvider`, `gastosDoMesProvider`, `mesSelecionadoProvider` (já existem).
- Produces: `final poteReservaProvider = Provider.autoDispose<AsyncValue<Pote?>>(...)` e `final mesesCoberturaReservaProvider = Provider.autoDispose<AsyncValue<double?>>(...)`.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/estado/providers_test.dart`:

```dart
  group('poteReservaProvider e mesesCoberturaReservaProvider', () {
    const potesSemReserva = [
      Pote(id: 'p1', nome: 'Custo fixo', percentual: 60, ordem: 0,
          cor: '#2E7D32', icone: 'casa'),
      Pote(id: 'p2', nome: 'Reserva', percentual: 40, ordem: 1,
          cor: '#1565C0', icone: 'cofre'),
    ];

    Future<ProviderContainer> montarReserva({
      List<Pote> potesDaCasa = potesSemReserva,
      double gastoDoMes = 0,
    }) async {
      final repoGastos = RepositorioGastosFake();
      if (gastoDoMes > 0) {
        await repoGastos.adicionar(
          base: Gasto(
            id: '', mesRef: '2026-08', membroId: 'marcos', poteId: 'p1',
            descricao: 'Compra', valor: gastoDoMes,
            criadoEm: DateTime.utc(2026, 8, 2), parcelado: false,
          ),
          quantidadeParcelas: 1,
        );
      }

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
        repositorioPotesProvider
            .overrideWithValue(RepositorioPotesFake(potesDaCasa)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(repoGastos),
      ]);
      addTearDown(c.dispose);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      c.listen(potesProvider, (_, _) {});
      c.listen(gastosDoMesProvider('2026-08'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('sem pote marcado como reserva, os dois providers sao nulos',
        () async {
      final c = await montarReserva(gastoDoMes: 1000);

      expect(c.read(poteReservaProvider).requireValue, isNull);
      expect(c.read(mesesCoberturaReservaProvider).requireValue, isNull);
    });

    test('com pote marcado e valor guardado, calcula meses de cobertura',
        () async {
      final potesComReserva = [
        potesSemReserva[0],
        potesSemReserva[1].copyWith(ehReserva: true, valorGuardado: 6000),
      ];
      final c = await montarReserva(
        potesDaCasa: potesComReserva,
        gastoDoMes: 1500,
      );

      expect(c.read(poteReservaProvider).requireValue?.id, 'p2');
      expect(c.read(mesesCoberturaReservaProvider).requireValue, 4);
    });

    test('pote marcado mas sem valor guardado preenchido: cobertura nula',
        () async {
      final potesComReserva = [
        potesSemReserva[0],
        potesSemReserva[1].copyWith(ehReserva: true),
      ];
      final c = await montarReserva(
        potesDaCasa: potesComReserva,
        gastoDoMes: 1500,
      );

      expect(c.read(poteReservaProvider).requireValue, isNotNull);
      expect(c.read(mesesCoberturaReservaProvider).requireValue, isNull);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/estado/providers_test.dart
```
Esperado: falha por `poteReservaProvider`/`mesesCoberturaReservaProvider` não definidos.

- [ ] **Step 3: Implementar**

Em `lib/estado/providers.dart`:

1. Adicione o novo import perto dos outros imports de `dominio/`:

```dart
import '../dominio/reserva.dart';
```

2. Adicione ao final do arquivo:

```dart
/// O pote marcado como reserva, se houver algum. No maximo um por casa.
final poteReservaProvider = Provider.autoDispose<AsyncValue<Pote?>>((ref) {
  return ref.watch(potesProvider).whenData((potes) {
    for (final p in potes) {
      if (p.ehReserva) return p;
    }
    return null;
  });
});

/// Meses que a reserva cobre, dado o gasto da casa inteira no mes
/// selecionado. Nulo sem pote de reserva, sem valor guardado preenchido, ou
/// sem gasto no mes.
final mesesCoberturaReservaProvider =
    Provider.autoDispose<AsyncValue<double?>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;

  return combinarAsyncValues(
    ref.watch(poteReservaProvider),
    ref.watch(gastosDoMesProvider(mes)),
    (reserva, gastos) {
      if (reserva == null) return null;
      final gastoDaCasa = gastos.fold(0.0, (s, g) => s + g.valor);
      return mesesDeCobertura(
        valorGuardado: reserva.valorGuardado,
        gastoDoMes: gastoDaCasa,
      );
    },
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
git commit -m "feat: providers do pote de reserva e meses de cobertura (estado)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 11: Estado — `serieProjecaoProvider` usa `proximoGanhoEsperado`

**Files:**
- Modify: `lib/estado/providers.dart`
- Test: `test/estado/providers_test.dart`

**Interfaces:**
- Consumes: `serieProjecao` com `ganhosConhecidos` (Task 6), `poteReservaProvider` (Task 10), `ganhoAssumidoProjecaoProvider`, `parceladosDesdeProvider`, `mesSelecionadoProvider`, `visaoProvider`, `janelaDe`, `mesesDaSerie`, `combinarAsyncValues` (já existem).
- Produces: `serieProjecaoProvider` reescrito para considerar ganho real ou `proximoGanhoEsperado` no mês seguinte ao selecionado, só na visão "Casal".

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/estado/providers_test.dart`:

```dart
  group('serieProjecaoProvider com proximoGanhoEsperado', () {
    const potesSimples = [
      Pote(id: 'p1', nome: 'Custo fixo', percentual: 100, ordem: 0,
          cor: '#2E7D32', icone: 'casa'),
    ];

    Future<ProviderContainer> montarProjecaoComReserva({
      double ganhoMarcosAgosto = 5000,
      double? proximoGanhoEsperado,
      double ganhoMarcosSetembro = 0,
    }) async {
      final ganhos = RepositorioGanhosFake();
      if (ganhoMarcosAgosto > 0) {
        await ganhos.adicionar(Ganho(
          id: '', mesRef: '2026-08', membroId: 'marcos',
          descricao: 'Salario', valor: ganhoMarcosAgosto,
          criadoEm: DateTime.utc(2026, 8, 1),
        ));
      }
      if (ganhoMarcosSetembro > 0) {
        await ganhos.adicionar(Ganho(
          id: '', mesRef: '2026-09', membroId: 'marcos',
          descricao: 'Salario', valor: ganhoMarcosSetembro,
          criadoEm: DateTime.utc(2026, 9, 1),
        ));
      }

      final potes = [
        if (proximoGanhoEsperado != null)
          potesSimples[0].copyWith(
            ehReserva: true,
            proximoGanhoEsperado: proximoGanhoEsperado,
          )
        else
          potesSimples[0],
      ];

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(ganhos),
        repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ]);
      addTearDown(c.dispose);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      c.listen(potesProvider, (_, _) {});
      c.listen(ganhosDoMesProvider('2026-08'), (_, _) {});
      c.listen(ganhosDoMesProvider('2026-09'), (_, _) {});
      c.listen(parceladosDesdeProvider('2026-08'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('sem pote de reserva, repete o ganho do mes selecionado (antigo)',
        () async {
      final c = await montarProjecaoComReserva(ganhoMarcosAgosto: 5000);

      final serie = c.read(serieProjecaoProvider).requireValue;
      expect(serie.every((p) => p.ganhos == 5000), isTrue);
    });

    test('com proximoGanhoEsperado e sem ganho real em setembro, usa a estimativa so em setembro',
        () async {
      final c = await montarProjecaoComReserva(
        ganhoMarcosAgosto: 5000,
        proximoGanhoEsperado: 5800,
      );

      final serie = c.read(serieProjecaoProvider).requireValue;
      expect(serie[0].ganhos, 5000); // agosto: mes selecionado, valor real
      expect(serie[1].ganhos, 5800); // setembro: estimativa
      expect(serie[2].ganhos, 5000); // outubro: volta a repetir o assumido
    });

    test('com ganho real em setembro, o real tem prioridade sobre a estimativa',
        () async {
      final c = await montarProjecaoComReserva(
        ganhoMarcosAgosto: 5000,
        proximoGanhoEsperado: 5800,
        ganhoMarcosSetembro: 6200,
      );

      final serie = c.read(serieProjecaoProvider).requireValue;
      expect(serie[1].ganhos, 6200);
    });

    test('na visao de uma pessoa, a estimativa nunca e usada', () async {
      final c = await montarProjecaoComReserva(
        ganhoMarcosAgosto: 5000,
        proximoGanhoEsperado: 5800,
      );
      c.read(visaoProvider.notifier).selecionar('marcos');

      final serie = c.read(serieProjecaoProvider).requireValue;
      expect(serie[1].ganhos, 5000); // repete o assumido, ignora a estimativa
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/estado/providers_test.dart
```
Esperado: os 3 primeiros testes deste grupo passam com a implementação atual (comportamento antigo já cobre o caso "sem reserva"); os testes com `proximoGanhoEsperado` falham, porque o provider ainda não olha pro mês seguinte.

- [ ] **Step 3: Implementar**

Em `lib/estado/providers.dart`, localize `serieProjecaoProvider` (adicionado por um plano anterior, logo depois de `ganhoAssumidoProjecaoProvider`) e substitua por:

```dart
final serieProjecaoProvider =
    Provider.autoDispose<AsyncValue<List<PontoProjecao>>>((ref) {
  final inicio = ref.watch(mesSelecionadoProvider);
  final membroId = ref.watch(visaoProvider);
  final meses = janelaDe(inicio, mesesDaSerie);
  final mesSeguinte = inicio.avancar(1).valor;

  final baseAsync = combinarAsyncValues(
    ref.watch(ganhoAssumidoProjecaoProvider),
    ref.watch(parceladosDesdeProvider(inicio.valor)),
    (ganhoAssumido, parcelas) => (ganhoAssumido, parcelas),
  );

  final ganhosConhecidosAsync = membroId != null
      ? const AsyncData<Map<String, double>>({})
      : combinarAsyncValues(
          ref.watch(ganhosDoMesProvider(mesSeguinte)),
          ref.watch(poteReservaProvider),
          (ganhosDoMesSeguinte, reserva) {
            final realDoMesSeguinte =
                ganhosDoMesSeguinte.fold(0.0, (s, g) => s + g.valor);
            if (realDoMesSeguinte > toleranciaCentavo) {
              return <String, double>{mesSeguinte: realDoMesSeguinte};
            }
            final estimativa = reserva?.proximoGanhoEsperado;
            return estimativa == null
                ? const <String, double>{}
                : {mesSeguinte: estimativa};
          },
        );

  return combinarAsyncValues(
    baseAsync,
    ganhosConhecidosAsync,
    (par, ganhosConhecidos) => serieProjecao(
      meses: meses,
      ganhoMensalAssumido: par.$1,
      parcelas: par.$2,
      membroId: membroId,
      ganhosConhecidos: ganhosConhecidos,
    ),
  );
});
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/estado/providers_test.dart
```

- [ ] **Step 5: Rodar a suíte inteira, analisar e commitar**

```bash
flutter test
flutter analyze lib/estado/providers.dart
git add lib/estado/providers.dart test/estado/providers_test.dart
git commit -m "feat: serieProjecaoProvider usa proximoGanhoEsperado no mes seguinte (estado)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 12: UI — rodapé de percentual no gráfico de Comprometido

**Files:**
- Modify: `lib/ui/widgets/graficos/linha_comprometimento.dart`
- Test: `test/ui/graficos_linhas_test.dart`

**Interfaces:**
- Consumes: `percentualComprometidoProvider` (Task 7), `formatarPercentual` (já existe em `formatadores.dart`).
- Produces: `LinhaComprometimento` (mesma API pública, sem parâmetros) com o `rodape` do `MolduraGrafico` estendido.

**IMPORTANTE:** `LinhaComprometimento` já usa o slot `rodape` do `MolduraGrafico` para mostrar "Total: R$X" (linha 36-42 do arquivo atual). Este `rodape` é um único slot — a tarefa é **estender** esse rodapé existente para incluir o percentual embaixo do total, não substituí-lo. Há um teste já passando (`test/ui/graficos_linhas_test.dart`, grupo "linha de comprometimento", teste "mostra o total comprometido abaixo do grafico" e "o total fica a direita, na mesma linha da legenda") que precisa continuar passando sem alteração.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final do `group('linha de comprometimento', ...)` já existente em `test/ui/graficos_linhas_test.dart` (o arquivo já importa `formatarReais`; adicione também `formatarPercentual` na mesma linha de import `package:controle_financeiro/ui/tema/formatadores.dart`, e o `montar()` já aceita `ganhosPorMes`):

```dart
    testWidgets('percentual comprometido aparece em verde abaixo de 30%',
        (tester) async {
      await montar(
        tester,
        const LinhaComprometimento(),
        ganhosPorMes: const [('2026-08', 1000)],
        parcelasDe: 3,
        valorParcela: 100, // comprometido de agosto = 100 -> 10%
      );

      final texto = tester.widget<Text>(
        find.byKey(const Key('percentual_comprometido')),
      );
      expect(texto.data, contains(formatarPercentual(10)));
      expect(texto.style?.color, Colors.green);
    });

    testWidgets('percentual comprometido aparece em vermelho acima de 50%',
        (tester) async {
      await montar(
        tester,
        const LinhaComprometimento(),
        ganhosPorMes: const [('2026-08', 200)],
        parcelasDe: 3,
        valorParcela: 150, // comprometido de agosto = 150 -> 75%
      );

      final texto = tester.widget<Text>(
        find.byKey(const Key('percentual_comprometido')),
      );
      expect(texto.style?.color, Theme.of(tester.element(find.byType(LinhaComprometimento))).colorScheme.error);
    });

    testWidgets('sem renda, o percentual nao aparece mas o total continua',
        (tester) async {
      await montar(
        tester,
        const LinhaComprometimento(),
        parcelasDe: 3,
        valorParcela: 100,
      );

      expect(find.byKey(const Key('percentual_comprometido')), findsNothing);
      expect(find.text('Total: ${formatarReais(300)}'), findsOneWidget);
    });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/ui/graficos_linhas_test.dart
```
Esperado: falha — a `Key('percentual_comprometido')` ainda não existe.

- [ ] **Step 3: Implementar**

Em `lib/ui/widgets/graficos/linha_comprometimento.dart`, substitua o parâmetro `rodape` (e adicione o import de `percentualComprometidoProvider`, que já está no mesmo arquivo `../../../estado/providers.dart` já importado):

```dart
      rodape: (serie) {
        final total = serie.fold(0.0, (soma, p) => soma + p.valor);
        final percentual = ref.watch(percentualComprometidoProvider).valueOrNull;
        final corPercentual = percentual == null
            ? null
            : percentual < 0.30
                ? Colors.green
                : percentual < 0.50
                    ? Colors.orange
                    : esquema.error;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total: ${formatarReais(total)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (percentual != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${formatarPercentual(percentual * 100)} da renda deste '
                  'mês está comprometida com parcelas',
                  key: const Key('percentual_comprometido'),
                  style: TextStyle(
                    color: corPercentual,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );
      },
```

Isto substitui o `rodape: (serie) => Text(...)` atual (linhas 36-42 do arquivo antes desta tarefa) — o resto do arquivo (`titulo`, `vazio`, `dados`, `estaVazio`, `aoRecarregar`, `legenda`, `construir`, e toda a classe `_Linha`) não muda.

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/ui/graficos_linhas_test.dart
```

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/ui/widgets/graficos/linha_comprometimento.dart
git add lib/ui/widgets/graficos/linha_comprometimento.dart test/ui/graficos_linhas_test.dart
git commit -m "feat: rodape do grafico Comprometido mostra percentual da renda (UI)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 13: UI — alerta de estouro projetado no Resumo

**Files:**
- Modify: `lib/ui/telas/tela_resumo.dart`
- Test: `test/ui/tela_resumo_test.dart`

**Interfaces:**
- Consumes: `estouroProjetadoProvider` (Task 8).
- Produces: `_IndicadorDoPote` (novo `ConsumerWidget` privado), substitui `_BarraDoPote` como o `indicador:` de cada `LinhaResponsiva`.

- [ ] **Step 1: Escrever os testes que falham**

Adicione ao final de `test/ui/tela_resumo_test.dart`. Primeiro, dê ao `montar()` já existente um parâmetro extra `overridesExtras` (não muda o comportamento de nenhuma chamada existente, que não passa esse parâmetro):

```dart
Future<void> montar(
  WidgetTester tester, {
  double ganhoMarcos = 0,
  double ganhoSilvia = 0,
  double gastoMarcos = 0,
  double gastoSilvia = 0,
  List<Pote> comPotes = potes,
  RepositorioPotes? repoPotes,
  Size tamanho = const Size(1400, 1400),
  bool semRetry = false,
  List<Override> overridesExtras = const [],
}) async {
```

E dentro do `ProviderContainer(...)`, acrescente `...overridesExtras,` ao final da lista `overrides: [...]` já existente.

Depois, ao final do arquivo, dentro de `void main() { ... }`:

```dart
  group('alerta de estouro projetado', () {
    testWidgets('aparece quando o provider tem excesso para o pote',
        (tester) async {
      await montar(
        tester,
        ganhoMarcos: 10000,
        gastoMarcos: 3000,
        overridesExtras: [
          estouroProjetadoProvider.overrideWith(
            (ref) => const AsyncData({'p1': 120.0}),
          ),
        ],
      );

      expect(find.byKey(const Key('estouro_p1')), findsOneWidget);
      expect(find.textContaining(formatarReais(120)), findsOneWidget);
    });

    testWidgets('nao aparece quando o provider nao tem excesso',
        (tester) async {
      await montar(
        tester,
        ganhoMarcos: 10000,
        gastoMarcos: 3000,
        overridesExtras: [
          estouroProjetadoProvider.overrideWith((ref) => const AsyncData({})),
        ],
      );

      expect(find.byKey(const Key('estouro_p1')), findsNothing);
      expect(find.byKey(const Key('estouro_p2')), findsNothing);
    });

    testWidgets('a barra de progresso do pote continua funcionando',
        (tester) async {
      await montar(
        tester,
        ganhoMarcos: 10000,
        gastoMarcos: 3000,
        overridesExtras: [
          estouroProjetadoProvider.overrideWith((ref) => const AsyncData({})),
        ],
      );

      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/ui/tela_resumo_test.dart
```
Esperado: falha por `Key('estouro_p1')` nunca aparecer (o widget ainda não existe) e por `overridesExtras` não ser um parâmetro de `montar`.

- [ ] **Step 3: Implementar**

Em `lib/ui/telas/tela_resumo.dart`, substitua o método `_linha` (e só ele — a classe `_BarraDoPote` que vem logo depois dele no arquivo atual permanece exatamente como está, sem nenhuma edição) por:

```dart
  LinhaResponsiva _linha(LinhaCascata linha, Map<String, double> porPote) {
    final consumido = porPote[linha.pote.id] ?? 0;
    final ultrapassou = math.max(0.0, consumido - linha.previsto);
    final sobra = math.max(0.0, linha.previsto - consumido);

    return LinhaResponsiva(
      chave: ValueKey('resumo_${linha.pote.id}'),
      valores: [
        linha.pote.nome,
        formatarPercentual(linha.pote.percentual),
        formatarReais(linha.previsto),
        formatarReais(consumido),
        formatarReais(ultrapassou),
        formatarReais(sobra),
      ],
      indicador: _IndicadorDoPote(
        previsto: linha.previsto,
        consumido: consumido,
        cor: linha.pote.cor,
        poteId: linha.pote.id,
      ),
    );
  }
}

/// Barra de consumo do pote mais o alerta de estouro projetado quando
/// existir. `ConsumerWidget` proprio porque `_linha` continua um metodo
/// puro (sem `WidgetRef`) -- so este widget composto precisa ler o
/// provider.
class _IndicadorDoPote extends ConsumerWidget {
  final double previsto;
  final double consumido;
  final String cor;
  final String poteId;

  const _IndicadorDoPote({
    required this.previsto,
    required this.consumido,
    required this.cor,
    required this.poteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excesso = ref.watch(estouroProjetadoProvider).value?[poteId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BarraDoPote(previsto: previsto, consumido: consumido, cor: cor),
        if (excesso != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'No ritmo atual, vai passar ${formatarReais(excesso)} do previsto',
              key: Key('estouro_$poteId'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
```

Repare que a chave de fechamento `}` que antes fechava a classe `TelaResumo` (depois de `_linha`) foi movida: `_linha` agora é o último método de `TelaResumo`, e `_IndicadorDoPote` é uma classe nova logo depois, antes de `_BarraDoPote` (que continua exatamente igual — só passa a ser filha de `_IndicadorDoPote` em vez de ser passada direto como `indicador:`).

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/ui/tela_resumo_test.dart
```

- [ ] **Step 5: Analisar e commitar**

```bash
flutter analyze lib/ui/telas/tela_resumo.dart
git add lib/ui/telas/tela_resumo.dart test/ui/tela_resumo_test.dart
git commit -m "feat: alerta de estouro projetado por pote no Resumo (UI)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 14: UI — gráfico de tendência histórica por pote

**Files:**
- Create: `lib/ui/widgets/graficos/tendencia_pote.dart`
- Modify: `lib/ui/telas/tela_graficos.dart`
- Test: `test/ui/tendencia_pote_test.dart` (novo arquivo)
- Test: `test/ui/tela_graficos_test.dart`

**Interfaces:**
- Consumes: `tendenciaPoteProvider` (Task 9), `potesProvider`, `mesesDaTendencia`, `PontoComprometido`, `eixoMensal`, `MolduraGrafico`, `corDeHex`, `serieVazia` (já existem).
- Produces: `class TendenciaPote extends ConsumerStatefulWidget`, `const TendenciaPote({super.key})`.

- [ ] **Step 1: Escrever os testes que falham**

Crie `test/ui/tendencia_pote_test.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
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
import 'package:controle_financeiro/ui/widgets/graficos/tendencia_pote.dart';

const casa = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
    Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
        cor: '#2E7D32', ordem: 0),
  ],
);

const potes = [
  Pote(id: 'p1', nome: 'Custo fixo', percentual: 60, ordem: 0,
      cor: '#2E7D32', icone: 'casa'),
  Pote(id: 'p2', nome: 'Lazer', percentual: 40, ordem: 1,
      cor: '#AD1457', icone: 'presente'),
];

Future<void> montar(
  WidgetTester tester, {
  List<Pote> comPotes = potes,
  List<(String poteId, double valor)> gastos = const [],
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repoGastos = RepositorioGastosFake();
  for (final (poteId, valor) in gastos) {
    await repoGastos.adicionar(
      base: Gasto(
        id: '', mesRef: '2026-08', membroId: 'marcos', poteId: poteId,
        descricao: 'Compra', valor: valor,
        criadoEm: DateTime.utc(2026, 8, 2), parcelado: false,
      ),
      quantidadeParcelas: 1,
    );
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(comPotes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
    repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
    repositorioGastosProvider.overrideWithValue(repoGastos),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(potesProvider, (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: TendenciaPote())),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('TendenciaPote', () {
    testWidgets('mostra o dropdown com os potes cadastrados', (tester) async {
      await montar(tester);

      expect(find.text('Custo fixo'), findsOneWidget);
    });

    testWidgets('comeca mostrando o primeiro pote', (tester) async {
      await montar(tester, gastos: const [('p1', 400)]);

      final dados =
          tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(dados.lineBarsData.single.spots.last.y, 400);
    });

    testWidgets('trocar o pote no dropdown troca a serie exibida',
        (tester) async {
      await montar(tester, gastos: const [('p1', 400), ('p2', 700)]);

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lazer').last);
      await tester.pumpAndSettle();

      final dados =
          tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(dados.lineBarsData.single.spots.last.y, 700);
    });

    testWidgets('pote sem gasto nos ultimos 6 meses mostra a frase vazia',
        (tester) async {
      await montar(tester);

      expect(find.byType(LineChart), findsNothing);
      expect(find.textContaining('Nenhum gasto'), findsOneWidget);
    });

    testWidgets('sem pote cadastrado, mostra a frase vazia sem montar o dropdown',
        (tester) async {
      await montar(tester, comPotes: const []);

      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.byType(LineChart), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/ui/tendencia_pote_test.dart
```
Esperado: falha de compilação — `lib/ui/widgets/graficos/tendencia_pote.dart` ainda não existe.

- [ ] **Step 3: Implementar**

Crie `lib/ui/widgets/graficos/tendencia_pote.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart' show serieVazia;
import '../../../dominio/serie_mensal.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../../tema/tema.dart';
import '../moldura_grafico.dart';
import 'eixo_mensal.dart';

/// Tendencia de gasto de um pote especifico nos ultimos [mesesDaTendencia]
/// meses. Diferente dos outros graficos da Visao Geral, este tem um
/// seletor interno (o pote a analisar) -- por isso e um
/// `ConsumerStatefulWidget`, nao um `ConsumerWidget`: o pote escolhido e
/// estado local da tela, nao um provider global.
class TendenciaPote extends ConsumerStatefulWidget {
  const TendenciaPote({super.key});

  @override
  ConsumerState<TendenciaPote> createState() => _TendenciaPoteState();
}

class _TendenciaPoteState extends ConsumerState<TendenciaPote> {
  String? _poteSelecionadoId;

  @override
  Widget build(BuildContext context) {
    final potesAsync = ref.watch(potesProvider);

    return potesAsync.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 240,
        child: Center(child: Text('Erro: $e')),
      ),
      data: (potes) {
        if (potes.isEmpty) {
          return MolduraGrafico<List<PontoComprometido>>(
            titulo: 'Tendência por pote',
            vazio: 'Cadastre um pote para ver a tendência de gasto.',
            dados: const AsyncData(<PontoComprometido>[]),
            estaVazio: (_) => true,
            legenda: (_) => [],
            aoRecarregar: () => ref.invalidate(potesProvider),
            construir: (_) => const SizedBox.shrink(),
          );
        }

        final selecionado = potes.any((p) => p.id == _poteSelecionadoId)
            ? _poteSelecionadoId!
            : potes.first.id;
        final poteAtual = potes.firstWhere((p) => p.id == selecionado);

        // `MolduraGrafico.subtitulo` e String, nao Widget -- nao ha slot ali
        // para um dropdown. O seletor de pote fica FORA da moldura, num
        // Card proprio acima dela, mantendo a moldura em si intocada.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DropdownButton<String>(
                  value: selecionado,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final p in potes)
                      DropdownMenuItem(value: p.id, child: Text(p.nome)),
                  ],
                  onChanged: (novoId) =>
                      setState(() => _poteSelecionadoId = novoId),
                ),
              ),
            ),
            MolduraGrafico<List<PontoComprometido>>(
              titulo: 'Tendência por pote',
              vazio:
                  'Nenhum gasto neste pote nos últimos $mesesDaTendencia meses.',
              dados: ref.watch(tendenciaPoteProvider(selecionado)),
              estaVazio: (serie) =>
                  serie.isEmpty || serieVazia([for (final p in serie) p.valor]),
              aoRecarregar: () {
                ref.invalidate(potesProvider);
                ref.invalidate(tendenciaPoteProvider(selecionado));
              },
              legenda: (_) => [],
              construir: (serie) =>
                  _Linha(serie: serie, cor: corDeHex(poteAtual.cor)),
            ),
          ],
        );
      },
    );
  }
}

class _Linha extends StatelessWidget {
  final List<PontoComprometido> serie;
  final Color cor;
  const _Linha({required this.serie, required this.cor});

  @override
  Widget build(BuildContext context) {
    var maximo = 0.0;
    for (final p in serie) {
      if (p.valor > maximo) maximo = p.valor;
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maximo <= 0 ? 1 : maximo * 1.15,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (i, p) in serie.indexed) FlSpot(i.toDouble(), p.valor),
            ],
            color: cor,
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

Antes de implementar, leia `lib/ui/widgets/moldura_grafico.dart` para confirmar a API pública exata de `MolduraGrafico` (os parâmetros usados acima — `titulo`, `vazio`, `dados`, `estaVazio`, `legenda`, `aoRecarregar`, `subtitulo`, `construir` — precisam bater com o que o widget realmente aceita).

Em `lib/ui/telas/tela_graficos.dart`:
1. Adicione o import `import '../widgets/graficos/tendencia_pote.dart';` (ordem alfabética, entre `rosca_por_pote.dart` e nenhum outro — na verdade depois de `rosca_por_pote.dart`).
2. Em `_graficosGeral`, adicione `TendenciaPote()` como 8º item, depois de `RoscaPorCartao()`.

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/ui/tendencia_pote_test.dart
```

- [ ] **Step 5: Adicionar teste de integração em `tela_graficos_test.dart`, rodar tudo e commitar**

Adicione ao `group('seletor de tipo de visao', ...)` já existente em `test/ui/tela_graficos_test.dart`:

```dart
    testWidgets('Visao Geral tem 8 graficos, incluindo a Tendencia por pote',
        (tester) async {
      await montar(tester);

      expect(find.text('Tendência por pote'), findsOneWidget);
    });
```

```bash
flutter test test/ui/tela_graficos_test.dart
flutter test
flutter analyze
git add lib/ui/widgets/graficos/tendencia_pote.dart lib/ui/telas/tela_graficos.dart test/ui/tendencia_pote_test.dart test/ui/tela_graficos_test.dart
git commit -m "feat: grafico de tendencia historica por pote (UI)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 15: UI — reserva de emergência na tela de Potes

**Files:**
- Modify: `lib/ui/telas/tela_potes.dart`
- Test: `test/ui/tela_potes_test.dart`

**Interfaces:**
- Consumes: `mesesCoberturaReservaProvider`, `poteReservaProvider` (Task 10), `Pote` com campos de reserva (Task 5).
- Produces: `_TelaPotesState` ganha um checkbox "Pote de reserva" e dois campos condicionais por linha, mais um texto de meses de cobertura abaixo da lista.

**IMPORTANTE — risco de regressão:** ao ler `mesesCoberturaReservaProvider`, `TelaPotes` passa a depender de `repositorioGastosProvider` (via `gastosDoMesProvider`), que **nenhum teste existente em `test/ui/tela_potes_test.dart` overrida hoje** — sem essa mudança no `montar()` de teste, TODOS os testes já existentes nesse arquivo quebram com `UnimplementedError` assim que `TelaPotes` tentar montar. O Step 1 abaixo cobre essa mudança antes de qualquer coisa.

- [ ] **Step 1: Ajustar o helper de teste, depois escrever os testes que falham**

O tipo `Override` (usado no novo parâmetro abaixo) não é exportado pelo barrel principal `package:flutter_riverpod/flutter_riverpod.dart` nesta versão do Riverpod (3.3.2) — confirmado lendo o `show` explícito do pacote. Adicione este import no topo de `test/ui/tela_potes_test.dart`, junto dos outros imports:

```dart
import 'package:flutter_riverpod/misc.dart' show Override;
```

Em `test/ui/tela_potes_test.dart`, localize o `montar()` existente (perto da linha 127) e substitua por:

```dart
Future<RepositorioPotesFake> montar(
  WidgetTester tester, {
  List<Pote> iniciais = tresPotes,
  List<Override> overridesExtras = const [],
}) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = RepositorioPotesFake(iniciais);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositorioPotesProvider.overrideWithValue(repo),
      repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
      repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ...overridesExtras,
    ],
    child: const MaterialApp(home: TelaPotes()),
  ));
  await tester.pumpAndSettle();
  return repo;
}
```

(A única mudança real é a linha `repositorioGastosProvider.overrideWithValue(RepositorioGastosFake())` e o novo parâmetro `overridesExtras` — nada mais muda, e toda chamada existente a `montar(tester)` continua funcionando igual, agora com um repositório de gastos vazio por padrão.)

Depois, rode a suíte deste arquivo ANTES de escrever qualquer teste novo, só para confirmar que a adição do override não quebrou nada:

```bash
flutter test test/ui/tela_potes_test.dart
```
Esperado: todos os testes já existentes continuam passando.

Agora adicione, ao final de `test/ui/tela_potes_test.dart`, dentro de `void main() { ... }`:

```dart
  group('reserva de emergencia', () {
    testWidgets('checkbox e campos nao aparecem por padrao', (tester) async {
      await montar(tester);

      expect(find.byKey(const Key('reserva_0')), findsOneWidget);
      expect(find.byKey(const Key('guardado_0')), findsNothing);
      expect(find.byKey(const Key('vai_ganhar_0')), findsNothing);
    });

    testWidgets('marcar reserva mostra os campos Guardado e Vai ganhar',
        (tester) async {
      await montar(tester);

      await tester.tap(find.byKey(const Key('reserva_0')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guardado_0')), findsOneWidget);
      expect(find.byKey(const Key('vai_ganhar_0')), findsOneWidget);
    });

    testWidgets('marcar um pote como reserva desmarca o anterior',
        (tester) async {
      await montar(tester);

      await tester.tap(find.byKey(const Key('reserva_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guardado_0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reserva_1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guardado_0')), findsNothing);
      expect(find.byKey(const Key('guardado_1')), findsOneWidget);
    });

    testWidgets('editar Guardado atualiza o rascunho e persiste ao salvar',
        (tester) async {
      final repo = await montar(tester);

      await tester.tap(find.byKey(const Key('reserva_0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('guardado_0')), '6000');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('salvar_potes')));
      await tester.pumpAndSettle();

      expect(repo.todos.firstWhere((p) => p.ehReserva).valorGuardado, 6000);
    });

    testWidgets('mostra os meses de cobertura quando o provider tem valor',
        (tester) async {
      await montar(tester, overridesExtras: [
        mesesCoberturaReservaProvider.overrideWith((ref) => const AsyncData(4.0)),
        poteReservaProvider.overrideWith(
          (ref) => AsyncData(tresPotes.first.copyWith(ehReserva: true)),
        ),
      ]);

      expect(find.byKey(const Key('meses_cobertura')), findsOneWidget);
      expect(find.textContaining('4'), findsWidgets);
    });

    testWidgets('sem pote de reserva, o texto de cobertura nao aparece',
        (tester) async {
      await montar(tester, overridesExtras: [
        poteReservaProvider.overrideWith((ref) => const AsyncData(null)),
        mesesCoberturaReservaProvider.overrideWith((ref) => const AsyncData(null)),
      ]);

      expect(find.byKey(const Key('meses_cobertura')), findsNothing);
    });
  });
```

- [ ] **Step 2: Rodar e confirmar que falha**

```bash
flutter test test/ui/tela_potes_test.dart
```
Esperado: falha — as chaves `reserva_0`, `guardado_0`, `vai_ganhar_0`, `meses_cobertura` ainda não existem.

- [ ] **Step 3: Implementar**

Em `lib/ui/telas/tela_potes.dart`:

1. Adicione dois novos mapas de controllers, ao lado de `_controladores`/`_controladoresNome`:

```dart
  final _controladoresGuardado = <int, TextEditingController>{};
  final _controladoresVaiGanhar = <int, TextEditingController>{};
```

2. No `dispose()`, adicione a limpeza dos dois novos mapas, no mesmo padrão dos existentes:

```dart
  @override
  void dispose() {
    for (final c in _controladores.values) {
      c.dispose();
    }
    for (final c in _controladoresNome.values) {
      c.dispose();
    }
    for (final c in _controladoresGuardado.values) {
      c.dispose();
    }
    for (final c in _controladoresVaiGanhar.values) {
      c.dispose();
    }
    super.dispose();
  }
```

3. Adicione os dois novos métodos de controller, perto de `_controladorNome`:

```dart
  TextEditingController _controladorGuardado(int indice, double? valor) {
    return _controladoresGuardado.putIfAbsent(
      indice,
      () => TextEditingController(
        text: valor == null ? '' : valor.toStringAsFixed(2),
      ),
    );
  }

  TextEditingController _controladorVaiGanhar(int indice, double? valor) {
    return _controladoresVaiGanhar.putIfAbsent(
      indice,
      () => TextEditingController(
        text: valor == null ? '' : valor.toStringAsFixed(2),
      ),
    );
  }
```

4. Em `_resincronizarControladores()`, adicione a limpeza dos dois novos mapas:

```dart
  void _resincronizarControladores() {
    for (final c in _controladores.values) {
      c.dispose();
    }
    _controladores.clear();
    for (final c in _controladoresNome.values) {
      c.dispose();
    }
    _controladoresNome.clear();
    for (final c in _controladoresGuardado.values) {
      c.dispose();
    }
    _controladoresGuardado.clear();
    for (final c in _controladoresVaiGanhar.values) {
      c.dispose();
    }
    _controladoresVaiGanhar.clear();
  }
```

5. Em `_conteudo`, adicione a leitura de `mesesCoberturaReservaProvider`/`poteReservaProvider` e o texto de cobertura entre a lista e o `Divider`:

```dart
  Widget _conteudo(BuildContext context) {
    final rascunho = _rascunho!;
    final fecha = somaFechada(_soma);
    final reservaAsync = ref.watch(poteReservaProvider);
    final coberturaAsync = ref.watch(mesesCoberturaReservaProvider);

    return Column(
      children: [
        Expanded(
          child: ReorderableListView(
            key: const Key('lista_potes'),
            padding: const EdgeInsets.all(8),
            onReorder: (de, para) => setState(() {
              final destino = para > de ? para - 1 : para;
              final movido = rascunho.removeAt(de);
              rascunho.insert(destino, movido);
              _resincronizarControladores();
            }),
            children: [
              for (var i = 0; i < rascunho.length; i++)
                _linha(context, i, rascunho[i]),
            ],
          ),
        ),
        if (reservaAsync.value != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              coberturaAsync.value != null
                  ? 'Sua reserva cobre ${coberturaAsync.requireValue!.toStringAsFixed(1)} meses de gasto.'
                  : 'Preencha o valor guardado para ver quantos meses sua reserva cobre.',
              key: const Key('meses_cobertura'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        const Divider(height: 1),
        // ... resto do metodo (Padding com Adicionar pote / soma / Salvar) sem mudanca
```

(O resto do corpo de `_conteudo`, a partir do `Padding` com o `Row` de "Adicionar pote"/soma/"Salvar", não muda.)

6. Substitua `_linha` por:

```dart
  Widget _linha(BuildContext context, int i, Pote pote) {
    return Card(
      key: Key('pote_$i'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
                CircleAvatar(radius: 10, backgroundColor: corDeHex(pote.cor)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: Key('nome_$i'),
                    controller: _controladorNome(i, pote.nome),
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: const [PrimeiraMaiuscula()],
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(
                      () => _rascunho![i] = _rascunho![i].copyWith(nome: v),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    key: Key('percentual_$i'),
                    controller: _controlador(i, pote.percentual),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(
                      () => _rascunho![i] = _rascunho![i].copyWith(
                        percentual: double.tryParse(v) ?? 0,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: Key('remover_$i'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remover pote',
                  onPressed: () async {
                    final confirmou = await confirmarExclusao(
                      context: context,
                      titulo: 'Remover pote',
                      mensagem: 'Deseja remover "${pote.nome}" da lista?',
                    );
                    if (!confirmou || !mounted) return;
                    setState(() {
                      _rascunho!.removeAt(i);
                      _resincronizarControladores();
                    });
                  },
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 40),
                Checkbox(
                  key: Key('reserva_$i'),
                  value: pote.ehReserva,
                  onChanged: (v) => setState(() {
                    for (var j = 0; j < _rascunho!.length; j++) {
                      _rascunho![j] = _rascunho![j].copyWith(
                        ehReserva: j == i ? (v ?? false) : false,
                      );
                    }
                  }),
                ),
                const Text('Pote de reserva'),
              ],
            ),
            if (pote.ehReserva)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: Key('guardado_$i'),
                        controller: _controladorGuardado(i, pote.valorGuardado),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
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
                            valorGuardado:
                                double.tryParse(v.replaceAll(',', '.')),
                            proximoGanhoEsperado: atual.proximoGanhoEsperado,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: Key('vai_ganhar_$i'),
                        controller:
                            _controladorVaiGanhar(i, pote.proximoGanhoEsperado),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Vai ganhar (próx. mês)',
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
                            valorGuardado: atual.valorGuardado,
                            proximoGanhoEsperado:
                                double.tryParse(v.replaceAll(',', '.')),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: Rodar e confirmar que passa**

```bash
flutter test test/ui/tela_potes_test.dart
```

- [ ] **Step 5: Rodar a suíte inteira, analisar e commitar**

```bash
flutter test
flutter analyze lib/ui/telas/tela_potes.dart
git add lib/ui/telas/tela_potes.dart test/ui/tela_potes_test.dart
git commit -m "feat: campos de reserva de emergencia na tela de Potes (UI)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Final Checklist

- [ ] `flutter analyze` limpo no projeto inteiro.
- [ ] `flutter test` verde no projeto inteiro.
- [ ] Nenhuma Cloud Function nem regra do Firestore precisa de deploy — este plano é 100% client-side, só leitura/combinação de dado que já existe, mais 3 campos novos opcionais em `Pote` (compatíveis com documentos existentes no Firestore, que não têm esses campos).
- [ ] Gerar um APK de release (`flutter build apk --release --split-per-abi`) e instalar no emulador/dispositivo pra conferir visualmente: percentual de comprometimento no gráfico de Comprometido, alerta de estouro no Resumo (só aparece se algum pote estiver estourando no ritmo atual do mês real), Tendência por pote na Visão Geral, e marcar um pote como reserva na tela de Potes.
