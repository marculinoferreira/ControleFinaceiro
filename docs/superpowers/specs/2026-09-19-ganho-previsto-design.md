# Ganho previsto — Design

**Data:** 2026-09-19
**Status:** aprovado no brainstorming, aguardando revisão do documento

## 1. Contexto e escopo

A feature de reserva de emergência (spec `2026-09-19-metricas-financeiras-design.md`, já mesclada em `main`) incluiu um campo "Vai ganhar (próx. mês)" no pote de reserva, que alimentava a Projeção só para o mês imediatamente seguinte ao selecionado. Ao testar, o usuário esclareceu que esse desenho estava errado: o conceito que ele quer não é preso a um pote, é uma **renda prevista por pessoa, por mês**, que deve valer pra qualquer mês (não só o seguinte) e alimentar todo cálculo de renda do app — não só a Projeção.

Este spec substitui essa parte da feature anterior (não a reserva inteira: "Guardado" e "meses de cobertura" continuam existindo do jeito que estão).

Exemplo do usuário: em setembro ele já lançou ganho real (R$5.172,76) e gasto real (R$5.112,86) — tudo normal, saldo R$9,90. Ao mudar o mês selecionado pra outubro, sem ganho real lançado ainda, hoje aparece Ganhos R$0,00 / Gastos R$2.759,06 (parcelas já comprometidas) / Saldo -R$2.759,06. Ele quer poder digitar um "ganho previsto" de R$3.800,00 (o salário que ele sabe que vai receber) pra outubro, e esse valor deve entrar nos cálculos de quanto ele pode gastar, quanto já está comprometido por pote, e o comprometido total — não só aparecer num gráfico.

## 2. Decisões tomadas

| # | Decisão | Escolha | Por quê |
|---|---|---|---|
| 1 | Por pessoa ou por casa | Por pessoa, um `Ganho` por membro por mês | Consistente com ganho real, que já é por pessoa. "O meu salário" é uma frase da própria pessoa, não do casal. |
| 2 | Onde editar | Na tela de Ganhos, como um lançamento | O usuário pediu explicitamente "vai pra dentro de ganhos" — reaproveita o formulário, a lista e o fluxo de editar/excluir que já existem. |
| 3 | Modelo de dado | `Ganho` ganha um campo `previsto` (bool, default false) | Um "ganho previsto" é um `Ganho` normal com essa marca — reaproveita toda a persistência, CRUD e listagem já existentes, sem uma coleção nova. |
| 4 | Real vs. previsto no mesmo mês | O real sempre vence; o previsto só conta quando não há nenhum ganho real daquela pessoa naquele mês | Regra simples e previsível: "isto é o que eu realmente ganhei" sempre tem prioridade sobre "isto é o que eu esperava ganhar". |
| 5 | O que acontece com o previsto quando o real chega | Nada automático — o previsto continua na lista (marcado), só para de entrar nos cálculos | Decisão explícita do usuário: ele quer decidir se apaga o previsto depois, o app não decide por ele. |
| 6 | Onde esse "ganho efetivo" entra | Em todo lugar que soma ganho pra calcular renda: cascata (previsto por pote), Resumo (rótulo/sobra), percentual de comprometimento, e a Projeção | O pedido do usuário foi explícito: "previsão de quanto posso gastar, quanto já comprometi de cada pote, quanto está comprometido" — isso é a cascata e os totais do Resumo, não só um gráfico. |
| 7 | Alcance na Projeção | Qualquer mês futuro que tiver previsto preenchido, não só o mês seguinte ao selecionado | Generaliza o mecanismo restrito da spec anterior (que só olhava um mês, preso ao pote de reserva). |
| 8 | Campo antigo no pote de reserva | Removido — `Pote.proximoGanhoEsperado` sai do modelo, "Vai ganhar" some da tela de Potes | Substituído por este novo mecanismo, mais geral e correto. `Guardado`/meses de cobertura continuam intocados. |

## 3. Domínio

### 3.1 `Ganho` ganha o campo `previsto`

`lib/dominio/models/ganho.dart`:

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
  /// ver `ganhosEfetivos`.
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
```

(`_lerData` não muda.) `previsto: false` como default mantém todo `Ganho.fromMap` de documento legado (sem o campo no Firestore) funcionando sem quebrar.

### 3.2 Filtro "ganhos efetivos" de um mês

`lib/dominio/totais.dart`:

```dart
/// Filtra os ganhos de UM MES para "o que efetivamente conta" na renda:
/// os ganhos reais de cada pessoa quando existir pelo menos um; senao, os
/// previstos dela. Nunca mistura real e previsto da mesma pessoa.
///
/// Assume que [ganhosDoMes] ja pertence a um unico mes — "tem ganho real"
/// precisa ser respondido mes a mes, nao ao longo de uma janela inteira
/// (ver `ganhosEfetivosPorMes` para o caso de varios meses).
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

### 3.3 "Ganhos efetivos" ao longo de uma janela de meses

`lib/dominio/serie_mensal.dart` (ao lado de `montarSerie`/`serieComprometimento`, que já fazem agregação por janela):

```dart
/// Ganho efetivo (real-ou-previsto, ver `ganhosEfetivos`) de [membroId] em
/// cada mes de [meses], a partir de uma janela com varios meses
/// misturados (ex.: `gastosDoIntervaloProvider`/`ganhosDoIntervaloProvider`).
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

### 3.4 `Pote` perde `proximoGanhoEsperado`

`lib/dominio/models/pote.dart`: remove o campo `proximoGanhoEsperado` (e as referências em `fromMap`/`toMap`/`copyWith`). `ehReserva` e `valorGuardado` continuam exatamente como estão.

### 3.5 `serieProjecao` não muda de assinatura

A função `serieProjecao` (já existente, com o parâmetro `ganhosConhecidos` adicionado pela spec anterior) **não muda** — o parâmetro `ganhosConhecidos` já é exatamente "mapa de mesRef → ganho conhecido daquele mês, com fallback pro `ganhoMensalAssumido` quando o mês não está no mapa". O que muda é *quem preenche esse mapa*: antes era um único mês (o seguinte ao selecionado, sourced do pote de reserva); agora é a janela de 12 meses inteira, sourced de `ganhosEfetivosPorMes`.

## 4. Estado (`lib/estado/providers.dart`)

### 4.1 Providers existentes passam a usar `ganhosEfetivos`

Três providers já existentes ganham uma chamada a mais (`ganhosEfetivos(ganhos)` antes de `calcularTotais`), sem mudar de assinatura nem de nome:

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

`resumoCascataProvider` não muda — ele já lê `totaisDoMesProvider.ganhos`, então herda o efeito automaticamente. O mesmo vale para `estouroProjetadoProvider` (Task 8 da spec anterior): ele lê `resumoCascataProvider`, então também herda.

### 4.2 `serieProjecaoProvider` — nova fonte do mapa, mesmo formato

Substitui o trecho da spec anterior que buscava `poteReservaProvider`/`ganhosDoMesProvider(mesSeguinte)`:

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

`toleranciaCentavo` deixa de ser necessário neste provider (a versão anterior usava pra comparar `realDoMesSeguinte > toleranciaCentavo`); `poteReservaProvider` deixa de ser lido aqui — continua existindo e sendo usado por `mesesCoberturaReservaProvider`, intocado.

`ganhosDoIntervaloProvider`/`JanelaMeses` já existem (usados por `serieMensalProvider`); `janelaDe`/`mesesDaSerie` já existem (usados no mesmo provider hoje).

## 5. UI

### 5.1 Tela de Ganhos — marcar um lançamento como previsto

`lib/ui/telas/tela_ganhos.dart`, `_FormularioState`:

- Novo estado `bool _previsto = false;`, inicializado de `g?.previsto ?? false` em `initState`.
- Novo `CheckboxListTile` (ou `Row` com `Checkbox` + `Text`) no formulário, entre o campo "Descrição" e o `CampoMoeda`, rotulado "Isto é uma previsão (ainda não recebi)", com `key: const Key('form_previsto')`.
- `_salvar()` passa `previsto: _previsto` ao construir o `Ganho`.

Na lista (`_ColunaMembro`'s `ListTile`), quando `g.previsto` é true, o `subtitle` deixa de ser só `Text(formatarReais(g.valor))` e passa a ser `Text('${formatarReais(g.valor)} · Previsto', style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.outline))` — sem mudar `title`/`trailing`/`onTap`/`onPressed`. Quando `g.previsto` é false, o `subtitle` continua exatamente como está hoje (`Text(formatarReais(g.valor))`, sem itálico nem cor especial).

### 5.2 Tela de Potes — remove "Vai ganhar"

`lib/ui/telas/tela_potes.dart`: remove o `TextFormField` `vai_ganhar_$i`, seu `Expanded`/`SizedBox(width: 12)` companheiro (o layout do `Row` de campos de reserva volta a ter só o campo "Guardado", agora sem precisar do `Row`/`Expanded` — pode virar um único `TextFormField` direto), o controller `_controladoresVaiGanhar` (mapa, factory method, dispose, resincronizar) e a leitura/gravação de `proximoGanhoEsperado` no `onChanged`/na construção do `Pote`. `ehReserva`/`valorGuardado`/o texto de "meses de cobertura" não mudam.

## 6. Testes

- `test/dominio/models/ganho_test.dart` (novo, se não existir; senão adicionar): round-trip `toMap`/`fromMap` com `previsto: true`; `fromMap` sem a chave (legado) cai em `false`.
- `test/dominio/totais_test.dart`: casos de `ganhosEfetivos` — pessoa só com real (usa real), pessoa só com previsto (usa previsto), pessoa com os dois (real vence, previsto ignorado), pessoa sem nenhum dos dois (não aparece).
- `test/dominio/serie_mensal_test.dart`: casos de `ganhosEfetivosPorMes` — mês sem ganho nenhum fica fora do mapa, mês com só previsto entra com o valor do previsto, mês com real de uma pessoa e nada da outra respeita o filtro por `membroId`, mês com ganho de outra pessoa mas não da `membroId` pedida entra com 0.0.
- `test/dominio/models/pote_test.dart`: remove os testes de `proximoGanhoEsperado` (campo não existe mais).
- `test/estado/providers_test.dart`: atualiza os testes de `totaisDoMesProvider`/`percentualComprometidoProvider`/`ganhoAssumidoProjecaoProvider` pra cobrir o caso "só previsto, sem real, ainda soma"; substitui o grupo "serieProjecaoProvider com proximoGanhoEsperado" (spec anterior) por um grupo novo cobrindo: sem nenhum dado no mês seguinte (repete o assumido), só previsto (usa o previsto), real e previsto no mesmo mês (real vence), previsto em MAIS de um mês futuro (cada um usa o seu, não só o seguinte).
- `test/ui/tela_ganhos_test.dart`: marcar "previsto" no formulário grava `Ganho.previsto == true`; a lista mostra o rótulo "Previsto" só nos ganhos marcados.
- `test/ui/tela_potes_test.dart`: remove os testes de `vai_ganhar_$i` (campo não existe mais).

## 7. Fora de escopo

- Qualquer edição em lote de "ganho previsto" (ex.: replicar o mesmo previsto pros próximos N meses de uma vez).
- Notificação/lembrete pra revisar previstos antigos que já deveriam ter virado reais.
- Mudar a regra de "real sempre vence" — não há um modo de "usar o previsto mesmo com real lançado".
- Qualquer coisa da spec anterior além do campo "Vai ganhar": `Guardado`, `ehReserva`, meses de cobertura, percentual de comprometimento, alerta de estouro projetado, tendência por pote continuam exatamente como foram implementados.
