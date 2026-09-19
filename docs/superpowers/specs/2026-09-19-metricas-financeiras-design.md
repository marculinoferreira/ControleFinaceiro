# Métricas de análise financeira — Design

**Data:** 2026-09-19
**Status:** aprovado no brainstorming, aguardando revisão do documento

## 1. Contexto e escopo

Depois de lançar as abas Comparativo e Projeção (spec `2026-09-18-graficos-comparativo-projecao-design.md`), o usuário pediu uma visão de analista financeiro sobre o app. Deste brainstorming saíram 4 melhorias aprovadas, sobre dado que já existe no app hoje:

1. **Percentual de comprometimento com dívida** — quanto da renda do mês já está tomado por parcelas, em %, com faixa de alerta.
2. **Alerta de estouro projetado por pote** — no ritmo de gasto de hoje, o pote vai passar do previsto até o fim do mês?
3. **Tendência histórica por pote** — como o gasto de um pote específico variou nos últimos 6 meses.
4. **Reserva de emergência** — um pote marcado como "reserva", com dois campos digitados manualmente (quanto já está guardado, quanto se espera ganhar no mês seguinte), mostrando quantos meses de gasto essa reserva cobre — e o segundo campo passa a alimentar a Projeção para o mês imediatamente seguinte, até que ganhos reais daquele mês sejam lançados.

Nenhuma das 4 introduz um novo tipo de lançamento (gasto/ganho). A única mudança de modelo é em `Pote`, que ganha 3 campos opcionais usados somente quando ele é o pote de reserva.

## 2. Decisões tomadas

| # | Decisão | Escolha | Por quê |
|---|---|---|---|
| 1 | Local do % comprometido | Rodapé do gráfico "Comprometido nos próximos 12 meses" | Reaproveita o slot `rodape` do `MolduraGrafico`, já usado pela Projeção para o aviso de saldo negativo — mesmo padrão visual, zero widget novo de posicionamento. |
| 2 | Faixas do % comprometido | <30% verde, 30–50% amarelo, >50% vermelho | Referência padrão de planejamento financeiro pessoal (regra dos 30-36% de comprometimento de renda com dívida). |
| 3 | Estouro projetado: quando calcular | Só quando o mês selecionado é o mês real de hoje (`MesRef.atual()`) | Projetar "ritmo de gasto até hoje" não faz sentido num mês passado (já fechou) nem futuro (não começou). Em qualquer outro mês, o alerta simplesmente não aparece. |
| 4 | Estouro projetado: onde | Texto de alerta na linha do pote já existente em `tela_resumo.dart` | A tabela já mostra Previsto/Consumido/Ultrapassou/Sobra por pote; o alerta é uma linha extra de texto na mesma linha, não uma tela nova. |
| 5 | Tendência histórica: formato | Um pote por vez, com seletor (dropdown) | Evita gráfico poluído com várias linhas coloridas; o usuário escolhe o que quer analisar. |
| 6 | Tendência histórica: janela | Últimos 6 meses, fixo | Suficiente para enxergar tendência sem virar um segundo gráfico de evolução anual (que já existe, `LinhaEvolucao`, olhando ganhos/gastos totais). |
| 7 | Reserva: onde ficam os campos | Tela de Potes, na linha do pote marcado como reserva | Reaproveita o padrão de edição em lote já existente ali (rascunho local + `salvarTodos`), sem tela nova. |
| 8 | Reserva: cálculo de "guardado" e "vai ganhar" | Dois números digitados manualmente pelo usuário, sem histórico — o app não reconstitui nem contabiliza patrimônio | Decisão explícita do usuário: nenhuma automação de saldo acumulado, e nenhum rastreamento de patrimônio geral — só os dois campos que ele mesmo atualiza quando quiser. |
| 9 | Reserva: base do cálculo de meses de cobertura | `valorGuardado ÷ gasto do mês selecionado` (gasto da casa inteira, sem filtro de pessoa) | Pote é configuração compartilhada da casa, sem seletor de visão — a reserva responde "quantos meses a casa sobrevive", não "quantos meses cobre só uma pessoa". |
| 10 | "Vai ganhar" alimenta a Projeção | Sim, mas só para o mês imediatamente seguinte ao mês selecionado, e só até haver ganho real lançado naquele mês | Pedido explícito do usuário: ele sabe o que vai ganhar mês que vem (é assalariado); assim que o ganho real é lançado, o dado real tem prioridade sobre a estimativa manual. Os outros 11 meses da janela de 12 meses continuam repetindo o ganho do mês selecionado, como já é hoje. |
| 11 | "Vai ganhar" e visão de pessoa | Só entra na Projeção quando a visão é "Casal" | O campo é um número só, não dividido por pessoa; ao ver a Projeção de Marcos ou Silvia isoladamente, a estimativa manual não tem como ser atribuída a uma pessoa específica, então cai no comportamento atual (repete o ganho da pessoa no mês selecionado). |

## 3. Domínio

### 3.1 Percentual de comprometimento (`lib/dominio/totais.dart`)

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

`toleranciaCentavo` já está em `lib/dominio/cascata.dart`; `totais.dart` não o importa hoje — este será o primeiro uso ali, então a função importa `cascata.dart` só por essa constante (mesmo padrão que `graficos.dart` já faz).

### 3.2 Alerta de estouro projetado (`lib/dominio/cascata.dart`)

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

A UI cruza isto com `LinhaCascata.previsto` (o teto do pote) e `gastosPorPoteProvider` (o gasto real classificado nele) — os mesmos dois valores que `tela_resumo.dart` já usa nas colunas Previsto/Ultrapassou/Sobra, então nenhuma leitura nova de dado, só um cálculo a mais sobre o que a tela já tem.

### 3.3 Tendência histórica por pote (`lib/dominio/serie_mensal.dart`)

Reaproveita o tipo `PontoComprometido` (`{mes, valor}`) que já existe no mesmo arquivo — mesma forma, dado diferente:

```dart
/// Gasto classificado num pote especifico, mes a mes, nos [meses] dados.
/// Mesma forma de `serieComprometimento`, mas soma gasto real classificado
/// no pote (nao parcela em aberto), reaproveitando `PontoComprometido` --
/// as duas series sao "um mes, um valor", so a origem do valor muda.
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

### 3.4 Reserva de emergência (`lib/dominio/reserva.dart`, novo arquivo)

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

### 3.5 `Pote` ganha os 3 campos da reserva (`lib/dominio/models/pote.dart`)

```dart
class Pote {
  final String id;
  final String nome;
  final double percentual;
  final int ordem;
  final String cor;
  final String icone;

  /// Marca este como o pote de reserva de emergencia da casa. No maximo um
  /// pote pode ter isto true por vez -- a UI desmarca o anterior ao marcar
  /// um novo.
  final bool ehReserva;

  /// Quanto ja esta guardado, digitado manualmente. So tem sentido quando
  /// [ehReserva] e true; nulo enquanto o usuario nao preencheu.
  final double? valorGuardado;

  /// Quanto se espera ganhar no mes seguinte ao selecionado, digitado
  /// manualmente. So tem sentido quando [ehReserva] e true. Alimenta
  /// `serieProjecaoProvider` — ver secao 4.5.
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

`copyWith` para `valorGuardado`/`proximoGanhoEsperado` segue o mesmo padrão "nulo não distingue de não-passado" que o resto do arquivo já usa (`cor`, `icone` etc.) — não há caso de uso aqui para "limpar" o valor de volta pra nulo via `copyWith` (a tela de Potes reconstrói o `Pote` inteiro a partir dos controllers, não usa `copyWith` parcial nesses dois campos).

### 3.6 Projeção passa a aceitar um "ganho conhecido" por mês (`lib/dominio/serie_mensal.dart`)

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

Mudança compatível com quem já chama `serieProjecao` sem o novo parâmetro (`ganhosConhecidos` tem default `const {}` — comportamento idêntico ao de hoje quando vazio).

## 4. Estado (`lib/estado/providers.dart`)

### 4.1 Percentual de comprometimento

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
      renda: calcularTotais(ganhos: ganhos, gastos: const [], membroId: membroId)
          .ganhos,
    ),
  );
});
```

### 4.2 Estouro projetado por pote

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

`gastosPorPoteProvider` já existe (usado por `resumoCascataProvider`'s tabela via `tela_resumo.dart`) e já respeita a visão selecionada.

### 4.3 Tendência histórica por pote

```dart
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

`gastosDoIntervaloProvider(JanelaMeses)` já existe (usado por `serieMensalProvider`).

### 4.4 Pote de reserva e meses de cobertura

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

### 4.5 `serieProjecaoProvider` passa a considerar `proximoGanhoEsperado`

```dart
final serieProjecaoProvider =
    Provider.autoDispose<AsyncValue<List<PontoProjecao>>>((ref) {
  final inicio = ref.watch(mesSelecionadoProvider);
  final membroId = ref.watch(visaoProvider);
  final meses = janelaDe(inicio, mesesDaSerie);
  final mesSeguinte = inicio.avancar(1).valor;

  return combinarAsyncValues(
    combinarAsyncValues(
      ref.watch(ganhoAssumidoProjecaoProvider),
      ref.watch(parceladosDesdeProvider(inicio.valor)),
      (ganhoAssumido, parcelas) => (ganhoAssumido, parcelas),
    ),
    membroId == null
        ? combinarAsyncValues(
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
                  ? <String, double>{}
                  : {mesSeguinte: estimativa};
            },
          )
        : const AsyncData(<String, double>{}),
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

Quando a visão é uma pessoa (`membroId != null`), o segundo ramo já entra como `AsyncData({})` sem watch nenhum extra — decisão 11: a estimativa manual só se aplica à visão "Casal".

## 5. UI

### 5.1 Percentual de comprometimento — `lib/ui/widgets/graficos/linha_comprometimento.dart`

Adiciona o parâmetro `rodape` no `MolduraGrafico` (mesmo padrão de `linha_projecao.dart`):

```dart
rodape: (_) {
  final percentual = ref.watch(percentualComprometidoProvider).valueOrNull;
  if (percentual == null) return const SizedBox.shrink();
  final esquema = Theme.of(context).colorScheme;
  final cor = percentual < 0.30
      ? Colors.green
      : percentual < 0.50
          ? Colors.orange
          : esquema.error;
  return Text(
    '${formatarPercentual(percentual * 100)} da renda deste mês está '
    'comprometida com parcelas',
    style: TextStyle(color: cor, fontWeight: FontWeight.bold),
  );
},
```

`LinhaComprometimento` precisa virar `ConsumerWidget` com acesso a `ref` dentro do `rodape` (já é `ConsumerWidget` hoje, só o `rodape` é novo).

### 5.2 Estouro projetado — `lib/ui/telas/tela_resumo.dart`

`_linha` hoje é um método puro (`LinhaResponsiva _linha(...)`, sem `WidgetRef`) que passa `_BarraDoPote` como `indicador:`. Em vez de dar `ref` a `_linha` (mudaria a assinatura de um método puro só por causa de um provider), `_BarraDoPote` é substituída por um novo widget composto, `_IndicadorDoPote`, que também é o único lugar que lê `estouroProjetadoProvider`:

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

/// Barra de consumo do pote (o que `_BarraDoPote` ja fazia) mais o alerta
/// de estouro projetado quando existir. `ConsumerWidget` proprio porque
/// `_linha` continua um metodo puro -- so este widget composto precisa de
/// `WidgetRef`.
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
    final excesso = ref.watch(estouroProjetadoProvider).valueOrNull?[poteId];

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

`_BarraDoPote` (a barra de progresso já existente) não muda — só passa a ser um filho de `_IndicadorDoPote` em vez de ser passada direto como `indicador:`.

### 5.3 Tendência histórica — `lib/ui/widgets/graficos/tendencia_pote.dart` (novo arquivo)

8º gráfico da Visão Geral (depois de `RoscaPorCartao`). Um `ConsumerStatefulWidget` (precisa manter qual pote está selecionado):

- Um `DropdownButton<String>` no lugar do `subtitulo` do `MolduraGrafico`, listando os potes cadastrados (`potesProvider`), com o primeiro selecionado por padrão.
- `MolduraGrafico<List<PontoComprometido>>` com `dados: ref.watch(tendenciaPoteProvider(poteSelecionadoId))`.
- Título: "Tendência por pote". `vazio`: "Nenhum gasto neste pote nos últimos 6 meses."
- Linha única (`LineChart`), cor do próprio pote (`corDeHex(pote.cor)`), eixo via `eixoMensal`.
- Sem pote cadastrado: mostra a frase vazia do `MolduraGrafico` sem tentar montar o dropdown.

`lib/ui/telas/tela_graficos.dart`: `TendenciaPote()` entra como 8º item de `_graficosGeral`. Um `ConsumerStatefulWidget` pode ter construtor `const` normalmente (o estado mutável — qual pote está selecionado — vive no `State`, não no widget), o mesmo padrão que `TelaPotes` já usa hoje (`const TelaPotes({super.key})`), então a lista continua `static const` sem nenhuma mudança estrutural em `_duasColunas`/`_colunaUnica`.

### 5.4 Reserva de emergência — `lib/ui/telas/tela_potes.dart`

Na linha de cada pote do rascunho:

- Um `Checkbox` ou `Switch` "Pote de reserva" (`Key('pote_reserva_$i')`). Marcar um desmarca todos os outros no rascunho local (`_rascunho![i] = ...ehReserva: true`, os demais `ehReserva: false`) — mesma mecânica de "no máximo um" que o app já usa para `Cartao`/`Membro` em outras telas.
- Quando `ehReserva` é true nessa linha, dois `TextFormField` adicionais aparecem: "Guardado" e "Vai ganhar (próx. mês)", com `TextEditingController`s próprios (mesmo padrão dos controllers de percentual/nome já existentes), formatados como valor monetário.
- Abaixo da lista, quando existe um pote de reserva: um texto com `ref.watch(mesesCoberturaReservaProvider)` — "Sua reserva cobre X meses de gasto" (ou "cadastre o valor guardado" quando nulo por falta de preenchimento).

## 6. Testes

- `test/dominio/totais_test.dart`: `percentualComprometido` — casos de renda zero (nulo), comprometido zero (0%), comprometido igual à renda (100%).
- `test/dominio/cascata_test.dart`: `projetarGastoPote` — dia 1 do mês, meio do mês, fim do mês, dia 0 (nulo).
- `test/dominio/serie_mensal_test.dart`: `serieGastoPote` (mês sem gasto entra com zero, filtro por membroId, gasto fora da janela é ignorado) e `serieProjecao` com `ganhosConhecidos` (mês presente no mapa usa o valor do mapa, mês ausente cai no `ganhoMensalAssumido`).
- `test/dominio/reserva_test.dart` (novo arquivo): `mesesDeCobertura` — sem valor guardado (nulo), sem gasto no mês (nulo), caso normal.
- `test/dominio/models/pote_test.dart` (se já existir; senão inline nos testes que já constroem `Pote`): `fromMap`/`toMap` round-trip com os 3 campos novos, `fromMap` sem os campos (dado legado) cai nos defaults.
- `test/estado/providers_test.dart`: `percentualComprometidoProvider` (faixas), `estouroProjetadoProvider` (só no mês real de hoje — teste precisa de um jeito de controlar "hoje"; ver nota de implementação abaixo), `poteReservaProvider`/`mesesCoberturaReservaProvider`, `serieProjecaoProvider` com `proximoGanhoEsperado` preenchido e depois com ganho real lançado no mês seguinte (confirma que o real tem prioridade), e com visão de pessoa (confirma que a estimativa é ignorada).
- `test/ui/graficos_linhas_test.dart` ou novo teste dedicado: rodapé do `LinhaComprometimento` nas 3 faixas de cor.
- `test/ui/tela_resumo_test.dart`: alerta de estouro aparece/some conforme `estouroProjetadoProvider`.
- `test/ui/tendencia_pote_test.dart` (novo arquivo): troca de pote no dropdown troca a série exibida; estado vazio.
- `test/ui/tela_potes_test.dart`: marcar reserva desmarca a anterior; campos aparecem só na linha marcada; meses de cobertura exibido corretamente.

**Nota de implementação sobre "mês real de hoje":** `estouroProjetadoProvider` compara `mesSelecionadoProvider` contra `MesRef.atual()`, que lê `DateTime.now()` diretamente — não há injeção de relógio no app hoje (confirmado: nenhum provider de "hoje" existe em `providers.dart`). Os testes que dependem disso precisam rodar assumindo a data real da máquina de teste, ou a tarefa de implementação decide se vale introduzir um `agoraProvider` sobrescrevível — mantendo consistência com o padrão zero-injeção-de-relógio já usado em `formulario_gasto.dart`'s `_hoje()`.

## 7. Fora de escopo

- Rastreamento de patrimônio geral (contas, investimentos, dívidas) — decisão explícita do usuário.
- Metas com valor e data-alvo.
- Gastos sazonais conhecidos.
- Normalização do Comparativo por renda de cada pessoa.
- Histórico/auditoria de mudanças em `valorGuardado`/`proximoGanhoEsperado` — são campos "estado atual", não uma série temporal.
- Mais de um pote de reserva por casa.
- `proximoGanhoEsperado` influenciando qualquer coisa além do mês imediatamente seguinte na Projeção.
