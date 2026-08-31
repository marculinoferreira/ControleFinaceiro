# Controle Financeiro Familiar — Fase 4 (Análise)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir os dois últimos placeholders do shell — Resumo dos Potes e Gráficos — pelas telas reais, e gerar os binários `.exe` e `.apk`. Ao fim disto o app está completo em relação à spec.

**Architecture:** A Fase 2 já entregou o motor inteiro que esta fase consome: `calcularCascata`, `somarGastosPorPote`, `somarGanhosPorMembro`, `comprometidoNoMes`. Nada de regra de negócio nova em `lib/dominio/`, com **uma exceção nomeada** (a série multi-mês da Tarefa 1, que hoje não existe em lugar nenhum). O trabalho é de apresentação: seis gráficos que compartilham uma moldura só, e uma tabela que já tem os números prontos.

**Tech Stack:** Flutter 3.41.5, Dart 3.11.3, Riverpod 3.3.2, **fl_chart 1.2.0** (já resolvida em `pubspec.lock`), intl 0.20.3, cloud_firestore 6.9.0.

**Spec:** `docs/superpowers/specs/2026-08-30-controle-financeiro-familiar-design.md` (§8 linha "Resumo dos Potes", §10, §13)

**Plano anterior:** `docs/superpowers/plans/2026-08-30-fase-3-crud.md` — Fase 3, concluída, verificada no app real e mesclada em `main` (commit `5fbd6b6`).

---

## Global Constraints

Valem para **todas** as tarefas.

- **`lib/dominio/` não pode importar `package:flutter`, `package:firebase_*` nem `package:cloud_firestore`.** Isso inclui `fl_chart`: nenhum arquivo de domínio conhece o tipo `Color`, `FlSpot` ou `PieChartSectionData`. Domínio devolve números; a UI os pinta.
- **Nenhuma tela lê `FirebaseFirestore` direto.** Sempre pelos providers.
- **Breakpoint único: `breakpointDesktop = 900`**, exportado por `lib/ui/shell.dart`.
- **Toda leitura assíncrona usa `AsyncValue.when` com os três ramos** — `CarregandoLista` no loading, `ErroComRecarregar` no erro.
- **Dinheiro nunca é comparado com `==` nem `> 0` puro.** Use `toleranciaCentavo` (0.005) de `lib/dominio/cascata.dart`.
- **`mesRef` é sempre `String` `"YYYY-MM"`** com zero à esquerda, obtida de `ref.watch(mesSelecionadoProvider).valor`.
- **Textos visíveis em português com acento; identificadores e comentários sem acento.**
- **`flutter analyze` limpo ao fim de cada tarefa.** O projeto está em zero issues.
- **Riverpod 3 não tem `valueOrNull`.** Use `AsyncValue.value`.
- **A cor de um pote vem sempre de `Pote.cor` via `corDeHex`** (`lib/ui/tema/tema.dart`). Nenhum gráfico escolhe cor por conta própria: a spec §10 exige que a mesma categoria tenha a mesma cor em todos os gráficos. Paleta fixa de fallback só para séries que não são potes (ganhos × gastos), e vinda do `ColorScheme` do tema.

---

## API existente que este plano consome

Já mesclada em `main`. **Não reimplemente nada disto.**

**`lib/dominio/cascata.dart`**

```dart
const double toleranciaCentavo = 0.005;

class LinhaCascata {
  final Pote pote;
  final double previsto, consumido, sobra;
}

class ResultadoCascata {
  final List<LinhaCascata> linhas;
  final Pote? poteAtivo;      // null = passou de todos
  final double excedente;     // sobra de gasto depois do ultimo pote
  final double totalGanhos;
  bool get estourouTudo;      // poteAtivo == null
  bool get semRenda;          // totalGanhos <= toleranciaCentavo
  String get rotulo;          // 'CADASTRE SEUS GANHOS' | NOME DO POTE | 'PARE DE GASTAR'
}

ResultadoCascata calcularCascata({
  required List<Pote> potes,
  required double totalGanhos,
  required double totalGastos,
});
```

**`lib/dominio/totais.dart`**

```dart
class TotaisMes { final double ganhos, gastos; double get saldo; }

TotaisMes calcularTotais({required List<Ganho> ganhos, required List<Gasto> gastos, String? membroId});
Map<String, double> somarGanhosPorMembro(List<Ganho> ganhos);
Map<String, double> somarGastosPorMembro(List<Gasto> gastos);
Map<String, double> somarGastosPorPote(List<Gasto> gastos, {String? membroId});
double comprometidoNoMes(List<Gasto> gastos, String mesRef);
```

**`lib/dominio/models/mes_ref.dart`**

```dart
class MesRef implements Comparable<MesRef> {
  MesRef avancar(int meses);          // aceita negativo
  int diferencaEm(MesRef outro);
  String get valor;                   // "2026-08"
  String formatarCurto();             // "Ago/26"
  String formatarExtenso();           // "Agosto/2026"
}
```

**`lib/estado/providers.dart`** — já existem e serão reusados:

```dart
final visaoProvider;              // NotifierProvider<VisaoNotifier, String?> — null = Casal
final potesProvider;              // StreamProvider<List<Pote>>
final ganhosDoMesProvider;        // family<List<Ganho>, String mesRef>
final gastosDoMesProvider;        // family<List<Gasto>, String mesRef>
final parceladosDesdeProvider;    // family<List<Gasto>, String mesRef>
final totaisDoMesProvider;        // AsyncValue<TotaisMes>, ja respeita visaoProvider
final resumoCascataProvider;      // AsyncValue<ResultadoCascata>, ja respeita visaoProvider
final membrosProvider;            // List<Membro>
AsyncValue<R> combinarAsyncValues<A, B, R>(a, b, juntar);
```

> **`visaoProvider` e `resumoCascataProvider` já existem e já estão ligados.** Foram criados na Fase 2 antecipando esta fase. A Tarefa 2 consome `resumoCascataProvider` direto — não crie outro.

**`lib/ui/tema/tema.dart`**

```dart
Color corDeHex(String hex);   // "#RRGGBB" -> Color
```

**`lib/ui/widgets/estados_async.dart`** — `CarregandoLista`, `ErroComRecarregar`, `avisarErroDeEscrita`.

**`lib/ui/shell.dart`** — os seis destinos **já existem**, com `_ProximaFase('Resumo dos Potes')` no índice 0 e `_ProximaFase('Gráficos')` no índice 5. A Fase 4 troca esses dois widgets e apaga `_ProximaFase`.

**fl_chart 1.2.0** — API verificada no pacote resolvido:

```dart
PieChartData({List<PieChartSectionData>? sections, double? centerSpaceRadius, ...})
PieChartSectionData({double? value, Color? color, double? radius, String? title, TextStyle? titleStyle, ...})
BarChartGroupData({required int x, List<BarChartRodData>? barRods, double? barsSpace, ...})
BarChartRodData({required double toY, Color? color, double? width, BorderRadius? borderRadius, ...})
LineChartBarData({List<FlSpot> spots, Color? color, double barWidth, bool isCurved, FlDotData dotData, ...})
// Eixos: FlTitlesData -> AxisTitles -> SideTitles(getTitlesWidget: ...)
```

Rosca = `PieChart` com `centerSpaceRadius` > 0. Pizza = o mesmo com `centerSpaceRadius: 0`.

---

## Estrutura de arquivos

```
lib/
  dominio/
    serie_mensal.dart          NOVO  (Tarefa 1) — unica logica nova de dominio
  dados/
    repositorios.dart          EDITA (Tarefa 1) — observarIntervalo nas duas interfaces + fakes
    repositorio_firestore.dart EDITA (Tarefa 1)
  estado/
    providers.dart             EDITA (Tarefas 1, 3) — serieMensalProvider, dados de cada grafico
  ui/
    telas/
      tela_resumo.dart         NOVO  (Tarefa 2)
      tela_graficos.dart       NOVO  (Tarefa 7)
    widgets/
      moldura_grafico.dart     NOVO  (Tarefa 3)
      legenda_grafico.dart     NOVO  (Tarefa 3)
      graficos/
        rosca_por_pote.dart          NOVO (Tarefa 4)
        barras_previsto_gasto.dart   NOVO (Tarefa 4)
        pizza_ganhos.dart            NOVO (Tarefa 5)
        barra_cascata.dart           NOVO (Tarefa 5)
        linha_evolucao.dart          NOVO (Tarefa 6)
        linha_comprometimento.dart   NOVO (Tarefa 6)
    shell.dart                 EDITA (Tarefas 2 e 7) — troca os dois _ProximaFase
test/
  dominio/serie_mensal_test.dart
  dados/intervalo_test.dart
  ui/tela_resumo_test.dart
  ui/moldura_grafico_test.dart
  ui/graficos_test.dart
  ui/tela_graficos_test.dart
```

---

## Ordem e dependências

```
Tarefa 1 (serie multi-mes)  ─┐
Tarefa 2 (Resumo dos Potes) ─┤ independentes entre si
Tarefa 3 (moldura + legenda)─┘
                             │
        ┌────────────────────┼────────────────────┐
   Tarefa 4              Tarefa 5             Tarefa 6
  (roscas/barras)      (pizza/cascata)    (linhas, precisa da 1)
        └────────────────────┼────────────────────┘
                        Tarefa 7 (tela Graficos)
                             │
                        Tarefa 8 (builds)
```

Tarefas 1, 2 e 3 podem ir em paralelo. As 4, 5 e 6 dependem só da 3 (a 6 também da 1).

---

## Decisões que este plano toma (e que valem revisão antes de começar)

1. **A série multi-mês usa uma query de intervalo, não N assinaturas mensais.** `mesRef` é `"YYYY-MM"`, cujo ordenamento lexicográfico **é** o cronológico, então `where('mesRef', isGreaterThanOrEqualTo: a).where('mesRef', isLessThanOrEqualTo: b)` funciona com índice de campo único — sem índice composto novo em `firestore.indexes.json`. Doze assinaturas separadas custariam doze streams e doze rebuilds.

2. **Janela do gráfico 3 (evolução): 12 meses terminando no mês selecionado.** A spec só diz "ao longo dos meses". Doze dá o ciclo anual inteiro e cabe no eixo sem virar sopa de rótulos. Trocar para 6 é mudar uma constante.

3. **Janela do gráfico 6 (comprometimento futuro): 12 meses a partir do mês selecionado, inclusive.** Simétrico ao 3.

4. **Todo gráfico sem dado mostra uma frase, não um desenho vazio.** Um `PieChart` com zero seções renderiza um círculo em branco que parece bug. A moldura da Tarefa 3 centraliza isso: recebe `vazio: 'Nenhum gasto neste mês.'` e decide.

5. **Os gráficos 1, 2 e 5 respeitam `visaoProvider`; o 4 não.** "Proporção de ganhos entre Marcos e Silvia" é intrinsecamente do casal — filtrar por pessoa deixaria uma fatia só. O gráfico 4 fica visualmente marcado como "do casal" na moldura.

6. **A tela de Gráficos empilha em coluna única no mobile e vai a duas colunas no desktop**, reusando o `breakpointDesktop` de 900. Cada gráfico tem altura fixa; a página rola.

---

## Tarefa 1 — Série mensal (o dado que hoje não existe)

**Problema:** o gráfico 3 precisa de ganhos e gastos de vários meses. Todo o app até aqui só sabe ler **um** mês (`observarMes`). Esta é a única lacuna de dados da Fase 4.

- [x] **Step 1: Escrever os testes que falham**

`test/dominio/serie_mensal_test.dart`:

| Caso | Espera |
|---|---|
| 12 meses terminando em 2026-08 | lista de 12 `MesRef`, de 2025-09 a 2026-08, em ordem |
| janela cruzando o ano | 2026-01 com 3 meses → 2025-11, 2025-12, 2026-01 |
| mês sem nenhum lançamento | ponto com ganhos 0 e gastos 0, **presente na série** (buraco no gráfico é pior que zero) |
| gastos de outro membro com `membroId` | não entram |
| `membroId` nulo | soma o casal |
| ordem da saída | sempre cronológica, independente da ordem de entrada |

`test/dados/intervalo_test.dart`: os fakes devolvem só o que está na janela, e emitem de novo quando algo é gravado dentro dela.

- [x] **Step 2: Rodar e confirmar que falham**

- [x] **Step 3: Implementar**

`lib/dominio/serie_mensal.dart`:

```dart
/// Um ponto da serie: um mes e os dois totais daquele mes.
class PontoMensal {
  final MesRef mes;
  final double ganhos;
  final double gastos;
}

/// Os [quantidade] meses terminando em [fim], do mais antigo para o mais novo.
List<MesRef> janelaAte(MesRef fim, int quantidade);

/// Os [quantidade] meses comecando em [inicio], inclusive.
List<MesRef> janelaDe(MesRef inicio, int quantidade);

/// Agrupa lancamentos soltos na serie de [meses]. Meses sem lancamento
/// entram com zero — a serie nunca tem buraco.
List<PontoMensal> montarSerie({
  required List<MesRef> meses,
  required List<Ganho> ganhos,
  required List<Gasto> gastos,
  String? membroId,
});
```

`lib/dados/repositorios.dart` — nas duas interfaces:

```dart
/// Lancamentos com mesRef entre [inicio] e [fim], ambos inclusive.
Stream<List<Ganho>> observarIntervalo(String inicio, String fim);
Stream<List<Gasto>> observarIntervalo(String inicio, String fim);
```

Fakes: filtram por comparação de `MesRef` e emitem no mesmo controlador já existente.

`lib/dados/repositorio_firestore.dart`:

```dart
@override
Stream<List<Gasto>> observarIntervalo(String inicio, String fim) => _col
    .where('mesRef', isGreaterThanOrEqualTo: inicio)
    .where('mesRef', isLessThanOrEqualTo: fim)
    .orderBy('mesRef')
    .snapshots()
    .map((s) => s.docs.map((d) => Gasto.fromMap(d.id, d.data())).toList());
```

`lib/estado/providers.dart`:

```dart
const int mesesDaSerie = 12;

final serieMensalProvider = Provider.autoDispose<AsyncValue<List<PontoMensal>>>((ref) {
  final fim = ref.watch(mesSelecionadoProvider);
  final membroId = ref.watch(visaoProvider);
  final meses = janelaAte(fim, mesesDaSerie);
  final inicio = meses.first.valor;

  return combinarAsyncValues(
    ref.watch(ganhosDoIntervaloProvider((inicio, fim.valor))),
    ref.watch(gastosDoIntervaloProvider((inicio, fim.valor))),
    (g, d) => montarSerie(meses: meses, ganhos: g, gastos: d, membroId: membroId),
  );
});
```

- [x] **Step 4: Rodar os testes e confirmar que passam**
- [x] **Step 5: Commit** — `feat: serie mensal de ganhos e gastos para os graficos de evolucao`

---

## Tarefa 2 — Tela Resumo dos Potes

A tela que a spec descreve com mais detalhe, e a que dá sentido a toda a Fase 2.

- [x] **Step 1: Escrever os testes que falham**

`test/ui/tela_resumo_test.dart`:

| Caso | Espera |
|---|---|
| 6 potes, ganhos 10000, gastos 3000 | 6 linhas com Previsto/Consumido/Sobra corretos |
| pote ativo | rótulo grande com o nome do pote **em maiúscula** |
| gasto passa de todos os potes | rótulo `PARE DE GASTAR` **em vermelho**, com o valor do excedente visível |
| sem ganhos cadastrados | rótulo `CADASTRE SEUS GANHOS`, sem PARE DE GASTAR |
| trocar a visão para um membro | os números mudam (usa `visaoProvider`) |
| barra de progresso por linha | `value` = consumido/previsto, travado em 1.0 quando estoura |
| previsto zero (pote 0%) | não divide por zero; barra em 0 |
| loading | `CarregandoLista`, não spinner |
| erro | `ErroComRecarregar` |
| mobile (<900) | cards, não `DataTable` |

- [x] **Step 2: Rodar e confirmar que falham**

- [x] **Step 3: Implementar** `lib/ui/telas/tela_resumo.dart`

Estrutura: `ConsumerWidget` lendo `resumoCascataProvider` (já existe, já respeita a visão).

1. **Seletor de visão** no topo — `SegmentedButton` com Marcos / Silvia / Casal, escrevendo em `visaoProvider`. Mesmo tratamento de id órfão dos filtros de `tela_gastos.dart`: se o membro sumiu, coage para null.
2. **Rótulo semafórico** grande, de `ResultadoCascata.rotulo`. Cor: `corDeHex(poteAtivo.cor)` quando há pote ativo; `colorScheme.error` no `PARE DE GASTAR`; `colorScheme.outline` no `CADASTRE SEUS GANHOS`. No estouro, subtítulo com `formatarReais(excedente)`.
3. **Tabela** via `TabelaResponsiva` (já existe): colunas Pote · % · Previsto · Consumido · Sobra, com a barra de progresso na célula do nome, pintada com a cor do pote.

> **Cuidado com o `previsto == 0`:** um pote de 0% ou um mês sem ganhos dá divisão por zero na barra. Trate antes de dividir, não com `??` depois.

- [x] **Step 4: Ligar no shell** — trocar `_ProximaFase('Resumo dos Potes')` por `TelaResumo()`. O teste do shell (`test/ui/shell_test.dart`) precisa acompanhar.
- [x] **Step 5: Rodar os testes e confirmar que passam**
- [x] **Step 6: Commit** — `feat: tela de resumo dos potes com rotulo semaforico e PARE DE GASTAR`

---

## Tarefa 3 — Moldura e legenda compartilhadas

Absorve, uma vez só, o que os seis gráficos repetiriam: título, `AsyncValue.when`, estado vazio, altura e legenda.

- [x] **Step 1: Escrever os testes que falham**

`test/ui/moldura_grafico_test.dart`:

| Caso | Espera |
|---|---|
| dados presentes | renderiza o filho |
| lista vazia | mostra a frase de `vazio`, **não** o filho |
| loading | `CarregandoLista` |
| erro | `ErroComRecarregar` com botão que reinvalida |
| legenda | um marcador por série, com a cor certa e o rótulo certo |
| legenda com muitos itens | quebra em várias linhas (`Wrap`), não estoura |

- [x] **Step 2: Rodar e confirmar que falham**

- [x] **Step 3: Implementar**

```dart
// lib/ui/widgets/moldura_grafico.dart
class MolduraGrafico extends StatelessWidget {
  final String titulo;
  final String? subtitulo;     // ex.: "do casal" no grafico 4
  final String vazio;
  final bool semDados;
  final double altura;
  final Widget child;
  final List<ItemLegenda> legenda;
}

// lib/ui/widgets/legenda_grafico.dart
class ItemLegenda { final String rotulo; final Color cor; }
class LegendaGrafico extends StatelessWidget { final List<ItemLegenda> itens; }
```

- [x] **Step 4: Rodar os testes e confirmar que passam**
- [x] **Step 5: Commit** — `feat: moldura e legenda compartilhadas dos graficos`

---

## Tarefa 4 — Gráficos 1 e 2 (por pote)

- [x] **Step 1: Escrever os testes que falham**

`test/ui/graficos_test.dart`, grupo "por pote":

| Caso | Espera |
|---|---|
| rosca: 3 potes com gasto | 3 `PieChartSectionData`, valores proporcionais |
| rosca: cor de cada seção | igual a `corDeHex(pote.cor)` |
| rosca: gasto em pote apagado | agrupa em "Outros", não quebra |
| rosca: sem gastos | moldura mostra o vazio, sem `PieChart` |
| barras: previsto × gasto | 2 `BarChartRodData` por grupo, um por pote |
| barras: pote estourado | a barra de gasto ultrapassa a de previsto (não trava no teto) |
| ambos respeitam `visaoProvider` | trocar a visão muda os valores |

- [x] **Step 2: Rodar e confirmar que falham**
- [x] **Step 3: Implementar** `rosca_por_pote.dart` e `barras_previsto_gasto.dart`

Dados: `somarGastosPorPote(gastos, membroId: visao)` cruzado com `potesProvider`. O previsto de cada pote vem de `resumoCascataProvider` (`LinhaCascata.previsto`) — **não recalcule** `ganhos * percentual / 100` na UI.

- [x] **Step 4: Rodar os testes e confirmar que passam**
- [x] **Step 5: Commit** — `feat: rosca de gastos por pote e barras previsto x gasto`

---

## Tarefa 5 — Gráficos 4 e 5 (pizza de ganhos e barra da cascata)

- [x] **Step 1: Escrever os testes que falham**

| Caso | Espera |
|---|---|
| pizza: dois membros com ganho | 2 seções, proporcionais |
| pizza: um membro sem ganho | não vira seção de valor 0 invisível — some da legenda |
| pizza: ignora `visaoProvider` | trocar a visão **não** muda o gráfico |
| pizza: sem ganhos | moldura mostra o vazio |
| cascata: potes na ordem de prioridade | segmentos na ordem de `ordem`, largura = previsto |
| cascata: marcador do gasto | posicionado na fronteira do pote ativo |
| cascata: estouro | marcador no fim, com destaque de excedente |
| cascata: sem renda | mostra o vazio, sem barra de larguras NaN |

- [x] **Step 2: Rodar e confirmar que falham**
- [x] **Step 3: Implementar** `pizza_ganhos.dart` e `barra_cascata.dart`

A barra da cascata **não usa `fl_chart`**: é um `Row` de `Expanded` com `flex` proporcional ao previsto de cada pote, mais um marcador posicionado. É mais simples, mais fiel ao desenho da spec e não força um gráfico empilhado a fingir ser uma régua.

> **Divisão por zero de novo:** sem renda, todo `previsto` é 0 e o `flex` vira 0 para todos. Trate com `semRenda` antes de montar o `Row`.

- [x] **Step 4: Rodar os testes e confirmar que passam**
- [x] **Step 5: Commit** — `feat: pizza de ganhos por pessoa e barra da cascata`

---

## Tarefa 6 — Gráficos 3 e 6 (linhas)

Depende da Tarefa 1.

- [x] **Step 1: Escrever os testes que falham**

| Caso | Espera |
|---|---|
| evolução: 12 pontos | 2 `LineChartBarData` (ganhos e gastos), 12 `FlSpot` cada |
| evolução: mês sem lançamento | ponto em zero, **sem buraco** na linha |
| evolução: rótulos do eixo X | `MesRef.formatarCurto()`, e não todos os 12 (a cada 2 ou 3, senão colidem) |
| comprometimento: parcelas futuras | um ponto por mês, somando `comprometidoNoMes` |
| comprometimento: sem parcelas | moldura mostra o vazio |
| comprometimento: parcela que acaba no meio | a linha cai a zero depois da última |

- [x] **Step 2: Rodar e confirmar que falham**
- [x] **Step 3: Implementar** `linha_evolucao.dart` e `linha_comprometimento.dart`

Evolução lê `serieMensalProvider`. Comprometimento lê `parceladosDesdeProvider` (já existe) e aplica `comprometidoNoMes` sobre `janelaDe(mesSelecionado, 12)`.

Cores: as duas séries da evolução vêm do `ColorScheme` (`primary` e `error`), não de potes — é a exceção prevista na constraint de cor.

- [x] **Step 4: Rodar os testes e confirmar que passam**
- [x] **Step 5: Commit** — `feat: linha de evolucao mensal e de comprometimento futuro`

---

## Tarefa 7 — Tela de Gráficos

- [x] **Step 1: Escrever os testes que falham**

| Caso | Espera |
|---|---|
| desktop (>=900) | duas colunas |
| mobile (<900) | coluna única |
| os seis gráficos presentes | seis molduras, na ordem da spec §10 |
| um provider em erro | só aquele gráfico mostra erro; os outros cinco renderizam |
| rola | `SingleChildScrollView`, sem overflow |

> O quarto caso é o que mais importa: um `AsyncValue.when` no topo da tela derrubaria os seis juntos. Cada moldura resolve o seu.

- [x] **Step 2: Rodar e confirmar que falham**
- [x] **Step 3: Implementar** `lib/ui/telas/tela_graficos.dart`
- [x] **Step 4: Ligar no shell** — trocar `_ProximaFase('Gráficos')` por `TelaGraficos()` e **apagar a classe `_ProximaFase`**, que fica sem uso.
- [x] **Step 5: Rodar a suíte inteira**

Esperado: tudo verde, `analyze` limpo, contagem subindo dos 267 da Fase 3 para algo em torno de 340.

- [x] **Step 6: Commit** — `feat: tela de graficos e fecha os placeholders do shell`

---

## Tarefa 8 — Builds e verificação final

- [x] **Step 1: Verificar no app real, no Windows**

```powershell
flutter run -d windows
```

1. **Resumo** abre com os 6 potes e o rótulo do pote ativo na cor dele.
2. Lançar gasto até passar de todos os potes: o rótulo vira **PARE DE GASTAR** em vermelho, com o excedente.
3. Trocar a visão para Marcos e para Silvia: números e rótulo acompanham.
4. **Gráficos**: os seis renderizam, e as cores dos potes batem entre a rosca, as barras e a cascata.
5. Um mês sem lançamento nenhum: os seis mostram a frase de vazio, nenhum círculo em branco.
6. Voltar 3 meses no seletor: a linha de evolução acompanha a janela.

- [x] **Step 2: Verificar no Android**

```powershell
flutter run -d emulator-5554
```

Layout de coluna única, sem overflow, e os rótulos do eixo X legíveis na largura do telefone.

> O emulador `Medium_Phone_API_36.1` foi recriado com `-wipe-data` no fim da Fase 3 e agora tem os 16 GB que o `config.ini` sempre pediu. Se voltar a faltar espaço, a causa é outra.

- [x] **Step 3: Gerar os binários** (spec §13)

```powershell
flutter build windows --release
flutter build apk --release
```

Saídas: `build/windows/x64/runner/Release/` e `build/app/outputs/flutter-apk/app-release.apk`.

O `applicationId` é `controle.finaceiro` (grafia do console, deliberada); o pacote Dart é `controle_financeiro`. **São independentes e ambos estão certos** — não "conserte" um para casar com o outro.

- [x] **Step 4: Commit** — `chore: builds de release da Fase 4`

---

## Estado ao fim deste plano

- Resumo dos Potes com a cascata visível e o "PARE DE GASTAR" funcionando
- Os seis gráficos da §10, com cor consistente por pote
- Shell sem nenhum placeholder
- `.exe` e `.apk` gerados

Com isso o app cobre a spec inteira. O que sobra é o que a §15 declarou fora de escopo: recuperação de senha, terceiro usuário, anexos, notificações e exportação.
