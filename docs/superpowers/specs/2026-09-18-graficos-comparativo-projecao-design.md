# Gráficos: abas Comparativo e Projeção — Design

**Data:** 2026-09-18
**Status:** aprovado no brainstorming, aguardando revisão do documento

## 1. Contexto e escopo

A tela de Gráficos (`lib/ui/telas/tela_graficos.dart`) hoje mostra sempre os
mesmos sete gráficos (spec 10 + o de cartão), filtrados pelo seletor
Marcos/Silvia/Casal (`_SeletorVisao`, escrevendo em `visaoProvider`).

Este spec adiciona duas visões novas à mesma tela, escolhidas por um
segundo seletor (3 opções: Visão Geral / Comparativo / Projeção), sem
tocar nos sete gráficos existentes nem no seletor de pessoa em si:

- **Visão Geral**: os sete gráficos de hoje, sem mudança.
- **Comparativo**: três gráficos novos comparando os dois integrantes
  ativos da casa lado a lado — por pote, por cartão, e parcelas
  comprometidas nos próximos 12 meses.
- **Projeção**: um gráfico novo de linha, próximos 12 meses, cruzando
  renda projetada (repete o ganho do mês selecionado) com o gasto já
  comprometido em parcelas — respeita o seletor de pessoa.

A maior parte da lógica de domínio já existe e é só reaproveitada com
outro filtro (`comprometidoNoMes`, `somarGastosPorPote`,
`somarGastosPorCartao`, `janelaDe`) — ver seção 3 para o que é
genuinamente novo.

## 2. Decisões tomadas

| # | Decisão | Escolha | Por quê |
|---|---|---|---|
| 1 | Onde fica o seletor novo | Uma segunda fileira, abaixo do seletor de pessoa (`_SeletorVisao`) | Mesma ordem do print de referência: pessoa em cima, modo de visão embaixo. |
| 2 | Seletor de pessoa no Comparativo | Some inteiramente (não fica desabilitado, não aparece) | Pedido explícito: Comparativo sempre mostra os dois, escolher "Marcos" ali não faria sentido. |
| 3 | Comparativo com casa de 1 pessoa só | A opção "Comparativo" some do seletor de 3 (fica só Visão Geral / Projeção) | Mesmo raciocínio já aplicado ao seletor de pessoa (`membrosAtivosProvider.length <= 1` esconde comparação): comparar alguém com ninguém não tem o que mostrar. |
| 4 | Comparativo por pote / por cartão | Barras agrupadas (2 barras por pote/cartão), mês selecionado | Mesma linguagem visual de `BarrasPrevistoGasto`, só trocando "previsto × gasto" por "pessoa A × pessoa B". |
| 5 | Comparativo "próximos 12 meses" | Parcelas comprometidas por pessoa (não histórico) | Confirmado no brainstorming: é sobre compromisso futuro, não gasto passado. |
| 6 | Renda futura na Projeção | Repete o ganho real do mês selecionado em todos os meses seguintes | Confirmado no brainstorming: opção simples, adequada a quem tem renda fixa; não tenta prever nem fazer média. |
| 7 | Gasto futuro na Projeção | `comprometidoNoMes` (parcelas já lançadas), igual ao gráfico "Comprometido" existente | Não há por que inventar uma segunda forma de calcular compromisso futuro — a spec 10 já resolveu isso. |
| 8 | Cor das barras "por pessoa" | Cor de cada membro (`Membro.cor`), igual à pizza de ganhos | `Membro` já tem cor própria (ao contrário de `Cartao`); reaproveita em vez de inventar paleta nova. |
| 9 | Pote/cartão sem gasto de ninguém | Não entra na lista de barras | Mesma regra de `fatiasPorPote`/`fatiasPorCartao`: barra de altura zero dos dois lados não informa nada. |
| 10 | Gasto de cartão apagado / sem cartão no Comparativo | Barra agregada "Sem cartão", com o valor de cada pessoa separado | Mesma convenção de `fatiasPorCartao`, estendida para carregar dois valores em vez de um. |

## 3. Domínio

### 3.1 `lib/dominio/graficos.dart` — comparativo por pote/cartão

Novo tipo, paralelo a `Fatia` mas com dois valores em vez de um:

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
```

Miolo compartilhado, no mesmo espírito de `_fatiar` (ordena pela lista
dada, ignora quem não tem gasto de nenhum lado, agrega desconhecidos):

```dart
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
      id: '', nome: nomeOrfaos, cor: corNeutra,
      valorA: orfaosA, valorB: orfaosB,
    ));
  }

  return barras;
}

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

`somarGastosPorPote`/`somarGastosPorCartao` (já existem em
`totais.dart`) alimentam `porPoteA`/`porPoteB` chamados uma vez por
`membroId`, no provider (seção 4) — nenhuma mudança nesses dois.

### 3.2 `lib/dominio/serie_mensal.dart` — projeção

Novo tipo e nova função, no mesmo molde de `PontoComprometido` /
`serieComprometimento`:

```dart
/// Um mes projetado: renda repetida do mes selecionado, gasto = o que ja
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

/// Projeta [meses] à frente assumindo renda constante (o ganho real do mes
/// de referencia, repetido) contra o gasto ja comprometido em parcelas.
///
/// Nao e previsão nem media: e a mesma renda de hoje, os mesmos
/// compromissos ja lançados — a pergunta que responde e "se nada mudar,
/// sobra ou falta dinheiro nos proximos meses". Compromisso futuro sai de
/// graca de `comprometidoNoMes`, o mesmo calculo do grafico 6 da spec 10.
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

## 4. Estado (`lib/estado/providers.dart`)

### 4.1 Seletor de aba (estado de UI, não persiste)

```dart
enum TipoVisaoGraficos { geral, comparativo, projecao }

class TipoVisaoGraficosNotifier extends Notifier<TipoVisaoGraficos> {
  @override
  TipoVisaoGraficos build() => TipoVisaoGraficos.geral;

  void selecionar(TipoVisaoGraficos tipo) => state = tipo;
}

final tipoVisaoGraficosProvider =
    NotifierProvider<TipoVisaoGraficosNotifier, TipoVisaoGraficos>(
        TipoVisaoGraficosNotifier.new);
```

Sempre começa em `geral` — trocar de mês/tela não deve prender a
pessoa numa aba que ela não escolheu conscientemente (mesmo raciocínio
de `ordemGastosProvider`).

### 4.2 Dados do Comparativo

```dart
/// Os dois integrantes ativos, na ordem de `Membro.ordem` -- a mesma ordem
/// que a pizza de ganhos ja usa. Vazio quando a casa tem 0 ou 1 pessoa
/// ativa (a UI esconde a aba Comparativo nesse caso, ver 5.1). Nunca mais
/// que 2: a casa ja e limitada a isso (achado "casa pode ter no maximo 2
/// pessoas"), entao nao ha terceiro integrante pra decidir quem entra.
final duplaComparativaProvider = Provider<List<Membro>>((ref) {
  final ativos = [...ref.watch(membrosAtivosProvider)]
    ..sort((a, b) => a.ordem.compareTo(b.ordem));
  return ativos.length == 2 ? ativos : const [];
});

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

### 4.3 Dados da Projeção

```dart
/// Ganho real do mes selecionado, respeitando a visao -- a renda que a
/// projecao assume constante dali pra frente.
final ganhoAssumidoProjecaoProvider =
    Provider.autoDispose<AsyncValue<double>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);

  return ref.watch(ganhosDoMesProvider(mes)).whenData(
        (ganhos) => calcularTotais(ganhos: ganhos, gastos: const [], membroId: membroId).ganhos,
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

## 5. UI

### 5.1 `lib/ui/telas/tela_graficos.dart`

- Novo widget privado `_SeletorTipoVisao`: três `ChoiceChip`/pílulas
  (Visão Geral · Comparativo · Projeção — ícones `donut_large`,
  `bar_chart`, `trending_up`, ecoando o print de referência), escrevendo
  em `tipoVisaoGraficosProvider`. A opção "Comparativo" só entra na
  lista quando `ref.watch(duplaComparativaProvider).length == 2` — com
  casa de 1 pessoa, o seletor tem só as outras duas opções.
- Se a aba comparativo estiver selecionada e a dupla ficar com menos de
  2 pessoas enquanto a tela está aberta (alguém saiu da casa), o
  provider volta pra `geral` automaticamente (`ref.listen` no
  `TipoVisaoGraficosNotifier.build`, mesmo padrão de `VisaoNotifier`).
- `_SeletorVisao` (pessoa) só aparece quando o tipo é `geral` ou
  `projecao`.
- A lista de gráficos que `_duasColunas()`/`_colunaUnica()` recebem
  deixa de ser o `const _graficos` fixo e passa a vir de uma função
  `_graficosDoTipo(TipoVisaoGraficos tipo)`:
  - `geral` → a lista atual de 7 (sem mudança).
  - `comparativo` → `[BarrasPoteComparativo(), BarrasCartaoComparativo(), LinhaComprometimentoComparativo()]`.
  - `projecao` → `[LinhaProjecao()]`.
- Nada muda em `_duasColunas()`/`_colunaUnica()` em si — já lidam com
  qualquer tamanho de lista.

### 5.2 Gráficos novos (`lib/ui/widgets/graficos/`)

Todos seguem o molde de `BarrasPrevistoGasto`/`LinhaComprometimento`
(`MolduraGrafico` + `legenda`/`rodape`/`aoRecarregar`), então só os
pontos que mudam:

- **`barras_pote_comparativo.dart`** (`BarrasPoteComparativo`): barras
  agrupadas por pote, 2 barras cada (cor do membro A cheia, cor do
  membro B cheia — sem "esmaecida" como no previsto×gasto, aqui os
  dois são gastos reais). Legenda com o nome de cada pessoa. Título:
  "Gasto por pote". `vazio`: "Nenhum gasto de nenhum dos dois neste
  mês."
- **`barras_cartao_comparativo.dart`** (`BarrasCartaoComparativo`):
  igual, trocando pote por cartão. Título: "Gasto por cartão".
- **`linha_comprometimento_comparativo.dart`**
  (`LinhaComprometimentoComparativo`): duas linhas (cor de cada
  membro), mesmo eixo/tooltip de `LinhaComprometimento`. Título:
  "Comprometido nos próximos 12 meses". Legenda com os dois nomes.
- **`linha_projecao.dart`** (`LinhaProjecao`): duas linhas — renda
  projetada (reta, cor `primary`) e gasto comprometido (cor
  `tertiary`, igual ao gráfico de comprometimento). Sem sombreamento
  condicional no gráfico (complicaria o fl_chart sem necessidade): o
  `rodape` do `MolduraGrafico` (mesmo slot que os outros gráficos já
  usam para "Total: ...") mostra, em vermelho, "N mês(es) com saldo
  negativo" quando `serie.any((p) => p.saldo < 0)` — senão, o rodapé
  fica em branco (nenhum aviso). Título: "Projeção de saldo — [nome da
  visão ou 'Casal']".

## 6. Testes

- `test/dominio/graficos_test.dart`: `barrasComparativasPorPote` e
  `barrasComparativasPorCartao` — ordena pela lista dada, ignora
  quando os dois valores são zero, agrega desconhecidos em "Outros"/
  "Sem cartão" mantendo os dois valores separados.
- `test/dominio/serie_mensal_test.dart` (ou onde `serieComprometimento`
  já é testada): `serieProjecao` — renda constante em todos os meses,
  gasto igual a `comprometidoNoMes`, filtro por `membroId`.
- `test/ui/tela_graficos_test.dart`: trocar para Comparativo esconde o
  seletor de pessoa e mostra as 3 barras/linhas novas; trocar para
  Projeção mantém o seletor de pessoa; casa com 1 pessoa ativa não
  oferece "Comparativo" no seletor de 3.

## 7. Fora de escopo

- Mudar os sete gráficos da Visão Geral.
- Qualquer edição/gravação nova — as três abas só leem dados que já
  existem.
- Projeção com renda variável, sazonal ou baseada em média — decisão
  explícita de manter simples (seção 2, item 6).
- Comparativo com mais de duas pessoas (o app já limita casa a 2
  integrantes).
- Persistir qual aba estava selecionada entre sessões do app.
