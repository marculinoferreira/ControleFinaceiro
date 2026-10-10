# Fixos (ganhos e gastos recorrentes previstos) — Design

**Data:** 2026-10-09
**Status:** aprovado no brainstorming, segue direto para o plano (autorizado pelo usuário)

## 1. Contexto e escopo

O app já tem o conceito de "ganho previsto" (`Ganho.previsto`): um lançamento manual, marcado na própria tela de Ganhos, que só conta na renda quando não há ganho real da mesma pessoa naquele mês. Não existe equivalente para gastos.

O usuário quer lançar contas recorrentes e previsíveis (salário, aluguel, assinaturas) **uma vez só**, e deixar o app projetar isso automaticamente no mês seguinte ao mês real de hoje, mês após mês, sem precisar relançar manualmente todo mês. Isso é diferente do "ganho previsto" manual de hoje (que é um lançamento avulso, de um mês específico, sem repetição).

Pedido original do usuário (verbatim, resumido): um botão novo "Fixos" entre Potes e Gastos na navegação; nele, cadastra-se um ganho ou um gasto previsto recorrente; o lançamento gerado aparece nas telas de Ganhos/Gastos normalmente, sempre no mês seguinte ao mês real; fica travado (sem editar/excluir) até aquele mês chegar; quando chega, dá pra editar — no gasto, acrescentar um cartão "transforma" em gasto fixo real; no ganho, desmarcar a previsão vira ganho real.

## 2. Decisões tomadas

| # | Decisão | Escolha | Por quê |
|---|---|---|---|
| 1 | O que é um "Fixo" | Um molde separado (nova coleção `Fixo`), não um `Ganho`/`Gasto` em si | Precisa sobreviver além de um único mês e gerar um lançamento novo a cada mês — um `Ganho`/`Gasto` é um documento de um mês só. |
| 2 | Recorrência | O Fixo gera sozinho um lançamento previsto para "o mês seguinte ao mês real de hoje" toda vez que o app abre, enquanto o Fixo existir | É o que dá sentido ao nome "Fixos" — evita relançar manualmente todo mês. Cobre só o próximo mês a cada checagem, sem tentar preencher retroativamente meses pulados (ver §4.2). |
| 3 | Campos do gasto | Descrição, De quem, Pote, Valor — sem cartão | O cartão só é conhecido quando a conta realmente vence (ver decisão 6). |
| 4 | Campos do ganho | De quem, Descrição, Valor | Mesmos campos do ganho previsto manual que já existe. |
| 5 | Onde aparece | O lançamento gerado entra na lista normal de Ganhos ou Gastos do mês, marcado como previsto — não existe uma lista separada "lançamentos de Fixos" | Reaproveita toda a UI de listagem/filtro que já existe; a tela Fixos só gerencia os moldes. |
| 6 | Trava de edição/exclusão | Só lançamentos vindos de um Fixo (`origemFixoId` preenchido) e cujo mês ainda não chegou ficam travados. O checkbox "Previsto" manual (lançamento avulso, sem Fixo) continua livre, do jeito que já funciona hoje. | Decisão explícita do usuário — a trava existe pra impedir editar algo que ainda não devia existir de verdade; o previsto manual nunca teve essa trava e não deve ganhar uma agora. |
| 7 | "Virar real" | Não é um botão especial — é a edição normal do lançamento: no ganho, desmarcar `previsto`; no gasto, desmarcar `previsto` (e tipicamente também preencher o cartão, já que antes não tinha) | O lançamento gerado já É um `Ganho`/`Gasto` de verdade (com `origemFixoId`); "virar real" é só editá-lo depois que a trava cai, usando os formulários que já existem. |
| 8 | Excluir um Fixo | Só impede gerar novos meses a partir dali. Lançamentos já gerados continuam existindo (sujeitos à trava normalmente) | Decisão explícita do usuário — excluir o molde não deve apagar histórico/lançamentos futuros já criados. |
| 9 | Cálculos | Gasto previsto passa a contar nos cálculos (Resumo, cascata, gráfico de evolução) com a mesma regra que ganho previsto já segue: real sempre vence previsto, por pessoa | Gasto precisa da mesma consistência que ganho já tem — sem isso, o Resumo ignoraria um gasto fixo que o usuário já sabe que vai ter. |
| 10 | Posição na navegação | Resumo, Ganhos, Gastos, Parcelas, Fixos, Potes, Cartões | Ordem pedida explicitamente pelo usuário. |

> **Correção pós-revisão final (2026-10-09):** a decisão #9 acima (real
> vence previsto, por pessoa, igual ganho) foi revertida para gasto depois da
> revisão final da implementação. Motivo: gasto previsto e gasto real não
> representam a mesma coisa (diferente de ganho, onde previsto e real do
> salário são a mesma entrada vista de dois jeitos) — uma pessoa tem vários
> gastos reais distintos por mês, e a regra antiga fazia qualquer gasto real
> dela suprimir TODOS os previstos dela no mês, mesmo sem relação entre eles,
> o que descolava o total do Resumo do total da lista de Gastos. A regra
> vigente para gasto: cada gasto (previsto ou real) conta sempre; um previsto
> só para de contar quando ELE MESMO é editado e o campo `previsto` vira
> `false`. `gastosEfetivos`/`gastosEfetivosNaJanela` foram removidas de
> `lib/dominio/totais.dart` — gasto nunca teve essas funções de filtro.
> `ganhosEfetivos`/`ganhosEfetivosNaJanela` continuam valendo para ganho, sem
> mudança.

## 3. Domínio

### 3.1 Novo modelo `Fixo`

`lib/dominio/models/fixo.dart` (novo arquivo):

```dart
enum TipoFixo { ganho, gasto }

/// Molde de um ganho ou gasto recorrente e previsivel (salario, aluguel,
/// assinatura): enquanto existir, gera um lancamento previsto (Ganho ou
/// Gasto, conforme [tipo]) no mes seguinte ao mes real de hoje, toda vez
/// que o app verifica (ver `garantirFixosDoMesProvider`).
///
/// Excluir o Fixo so impede gerar NOVOS meses -- lancamentos que ele ja
/// gerou continuam existindo, independentes dele a partir dai.
class Fixo {
  final String id;
  final TipoFixo tipo;
  final String membroId;
  final String descricao;
  final double valor;

  /// So para `tipo == TipoFixo.gasto`. Nulo (e sem sentido) para ganho.
  final String? poteId;

  final DateTime criadoEm;

  const Fixo({
    required this.id,
    required this.tipo,
    required this.membroId,
    required this.descricao,
    required this.valor,
    required this.criadoEm,
    this.poteId,
  });

  factory Fixo.fromMap(String id, Map<String, dynamic> mapa) => Fixo(
        id: id,
        tipo: (mapa['tipo'] as String) == 'ganho'
            ? TipoFixo.ganho
            : TipoFixo.gasto,
        membroId: mapa['membroId'] as String,
        descricao: mapa['descricao'] as String,
        valor: (mapa['valor'] as num).toDouble(),
        criadoEm: _lerData(mapa['criadoEm']),
        poteId: mapa['poteId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'tipo': tipo == TipoFixo.ganho ? 'ganho' : 'gasto',
        'membroId': membroId,
        'descricao': descricao,
        'valor': valor,
        'criadoEm': criadoEm,
        'poteId': poteId,
      };
}
```

(`_lerData` duck-typed de `Timestamp`, mesmo padrão de `Ganho`/`Gasto`.) Sem `copyWith`/edição de Fixo nesta primeira versão (ver §7 Fora de escopo) — só criar e excluir.

### 3.2 `Ganho` e `Gasto` ganham `origemFixoId`

Ambos ganham um campo `final String? origemFixoId` (nulo para lançamentos que não vieram de um Fixo — a esmagadora maioria). Segue o mesmo padrão de campo opcional já usado em `Gasto.cartaoId`: parâmetro nomeado opcional no construtor, lido/gravado em `fromMap`/`toMap`, incluído em `copyWith`.

`Gasto` **também** ganha `final bool previsto` (default `false`), no mesmo formato que já existe em `Ganho.previsto` — hoje só `Ganho` tem esse campo.

### 3.3 Filtro "gastos efetivos" — espelha `ganhosEfetivos`/`ganhosEfetivosNaJanela`

`lib/dominio/totais.dart`, ao lado de `ganhosEfetivos`. **Duas funções, não uma** — o app já tem essa distinção pronta para ganho (um mês só vs. uma janela de vários meses) e gasto precisa da mesma, pelo mesmo motivo: decidir "esta pessoa tem gasto real" é uma pergunta por mês, nunca pode se misturar entre meses diferentes de uma janela:

```dart
/// Mesma regra de `ganhosEfetivos`, para gastos: o gasto real de uma
/// pessoa vence o previsto dela no mesmo mes; nunca mistura os dois.
/// Assume que [gastosDoMes] ja pertence a um unico mes (mesmo contrato de
/// `ganhosEfetivos`) -- para uma janela com varios meses, ver
/// `gastosEfetivosNaJanela`, logo abaixo.
List<Gasto> gastosEfetivos(List<Gasto> gastosDoMes) {
  final membrosComReal = <String>{
    for (final g in gastosDoMes)
      if (!g.previsto) g.membroId,
  };
  return [
    for (final g in gastosDoMes)
      if (!g.previsto || !membrosComReal.contains(g.membroId)) g,
  ];
}

/// `gastosEfetivos`, mes a mes, para uma janela com varios meses
/// misturados (ex.: `gastosDoIntervaloProvider`) -- mesmo motivo de
/// `ganhosEfetivosNaJanela` existir separado de `ganhosEfetivos`: aplicar
/// a regra sobre a janela inteira de uma vez misturaria "tem gasto real
/// em setembro" com "tem previsto em novembro" da mesma pessoa, quando
/// sao perguntas independentes.
List<Gasto> gastosEfetivosNaJanela(List<Gasto> gastosDoIntervalo) {
  final porMes = <String, List<Gasto>>{};
  for (final g in gastosDoIntervalo) {
    (porMes[g.mesRef] ??= []).add(g);
  }
  return [
    for (final lista in porMes.values) ...gastosEfetivos(lista),
  ];
}
```

### 3.4 Geração: o que falta criar para o mês seguinte

Função pura que decide, a partir dos Fixos ativos e do que já existe, o que falta gerar — sem tocar em repositório (quem grava é o provider, §4.2):

```dart
/// Mes-alvo da geracao: sempre o mes seguinte ao mes REAL de hoje (nao o
/// mes selecionado na tela).
MesRef mesAlvoDosFixos() => MesRef.atual().avancar(1);

/// Os Fixos ativos que AINDA NAO tem um lancamento gerado para [mesAlvo]
/// (comparando pelo id do Fixo contra `origemFixoId` dos lancamentos ja
/// existentes naquele mes). Quem usa decide como gerar cada um (Ganho ou
/// Gasto, conforme `fixo.tipo`).
List<Fixo> fixosParaGerar({
  required List<Fixo> fixos,
  required MesRef mesAlvo,
  required Set<String> origensJaGeradasNoMes,
}) =>
    [
      for (final f in fixos)
        if (!origensJaGeradasNoMes.contains(f.id)) f,
    ];
```

## 4. Estado (`lib/estado/providers.dart`)

### 4.1 `gastosEfetivos`/`gastosEfetivosNaJanela` entram nos mesmos pontos onde `ganhosEfetivos`/`ganhosEfetivosNaJanela` já entram

`totaisDoMesProvider` (lado `gastos`) e `gastosPorPoteProvider` operam sobre um **único mês** (`gastosDoMesProvider`) — usam `gastosEfetivos(gastos)`. `serieMensalProvider` (lado `gastos`) opera sobre uma **janela de vários meses** (`gastosDoIntervaloProvider`) — usa `gastosEfetivosNaJanela(gastos)`, nunca `gastosEfetivos` direto (misturaria meses, ver §3.3). Mesmo padrão já usado para `ganhos` nesses três providers. `resumoCascataProvider` não muda (herda via `totaisDoMesProvider`). O plano confirma os pontos exatos lendo o arquivo atual antes de editar — não há mudança de assinatura em nenhum provider, só a chamada extra de filtro, igual a spec de "ganho previsto" já fez.

`comprometidoNoMes`/`percentualComprometidoProvider`/`estouroProjetadoProvider` **não mudam** — tratam de parcelas em aberto (um conceito ortogonal a "previsto"), fora de escopo aqui.

### 4.2 `RepositorioFixos`, `repositorioFixosProvider` e `garantirFixosDoMesProvider`

`lib/dados/repositorios.dart` ganha a interface, espelhando `RepositorioPotes` (lista simples, sem o conceito de parcelas/mês que `RepositorioGanhos`/`RepositorioGastos` têm):

```dart
abstract class RepositorioFixos {
  Stream<List<Fixo>> observar();
  Future<void> adicionar(Fixo fixo);
  Future<void> remover(String id);
}
```

`lib/dados/repositorio_firestore.dart` ganha `FixosFirestore implements RepositorioFixos`, espelhando `PotesFirestore`/`CartoesFirestore` (coleção `casas/{casaId}/fixos`). As regras do Firestore (`firestore.rules`) **não precisam mudar**: a regra `match /{colecao}/{doc}` dentro de `casas/{casaId}` já libera leitura/escrita para qualquer sub-coleção nova a quem é membro da casa — `fixos` herda isso automaticamente, sem edição no arquivo de regras.

`lib/dados/repositorios.dart` também ganha `RepositorioFixosFake` (lista em memória), espelhando `RepositorioPotesFake`, para os testes.

```dart
final repositorioFixosProvider = Provider<RepositorioFixos>((ref) =>
    FixosFirestore(ref.watch(firestoreProvider), _casaIdResolvido(ref)));

final fixosProvider = StreamProvider<List<Fixo>>(
  (ref) => ref.watch(repositorioFixosProvider).observar(),
);

/// Roda uma vez por sessao do app (nao autoDispose, nao fica relendo a
/// toda hora): confere se cada Fixo ativo ja tem um lancamento previsto
/// gerado para `mesAlvoDosFixos()" e cria o que faltar. Chamado a partir
/// do Shell, assim que a casa resolve.
///
/// Le os repositorios diretamente (`.observar().first`/`.observarMes(...)
/// .first`), nao atraves de `fixosProvider`/`ganhosDoMesProvider`: isto e
/// uma checagem pontual de "o que existe agora", nao algo que precisa
/// recalcular quando o stream emitir de novo.
final garantirFixosDoMesProvider = FutureProvider<void>((ref) async {
  final repoFixos = ref.watch(repositorioFixosProvider);
  final repoGanhos = ref.watch(repositorioGanhosProvider);
  final repoGastos = ref.watch(repositorioGastosProvider);

  final fixos = await repoFixos.observar().first;
  if (fixos.isEmpty) return;

  final mesAlvo = mesAlvoDosFixos();
  final ganhosDoMes = await repoGanhos.observarMes(mesAlvo.valor).first;
  final gastosDoMes = await repoGastos.observarMes(mesAlvo.valor).first;
  final origensJaGeradas = {
    for (final g in ganhosDoMes)
      if (g.origemFixoId != null) g.origemFixoId!,
    for (final g in gastosDoMes)
      if (g.origemFixoId != null) g.origemFixoId!,
  };

  final aGerar = fixosParaGerar(
    fixos: fixos,
    mesAlvo: mesAlvo,
    origensJaGeradasNoMes: origensJaGeradas,
  );

  for (final fixo in aGerar) {
    if (fixo.tipo == TipoFixo.ganho) {
      await repoGanhos.adicionar(Ganho(
        id: '',
        mesRef: mesAlvo.valor,
        membroId: fixo.membroId,
        descricao: fixo.descricao,
        valor: fixo.valor,
        criadoEm: DateTime.now(),
        previsto: true,
        origemFixoId: fixo.id,
      ));
    } else {
      await repoGastos.adicionar(
        base: Gasto(
          id: '',
          mesRef: mesAlvo.valor,
          membroId: fixo.membroId,
          poteId: fixo.poteId!,
          descricao: fixo.descricao,
          valor: fixo.valor,
          criadoEm: DateTime.now(),
          parcelado: false,
          previsto: true,
          origemFixoId: fixo.id,
        ),
        quantidadeParcelas: 1,
      );
    }
  }
});
```

Nota: `origensJaGeradas` junta as origens de Ganhos e Gastos num só conjunto antes de chamar `fixosParaGerar` porque os ids de `Fixo` são únicos entre os dois tipos (uma coleção só) — um Fixo de ganho nunca colide com o id de um Fixo de gasto, então usar o conjunto combinado não gera falso positivo/negativo.

O plano decide o ponto exato de leitura no Shell (ex.: `ref.watch(garantirFixosDoMesProvider)` num local que já roda uma vez por sessão, depois que `casaIdProvider` resolveu) depois de ler o arquivo atual.

### 4.3 Trava de edição/exclusão

Função pura, `lib/dominio/models/fixo.dart` ou `totais.dart`:

```dart
/// Verdadeiro quando o lancamento veio de um Fixo E o mes dele ainda nao
/// chegou (mesRef > mes real de hoje) -- so entao fica travado.
bool travadoPorFixo({required String? origemFixoId, required String mesRef}) =>
    origemFixoId != null && MesRef.parse(mesRef).compareTo(MesRef.atual()) > 0;
```

## 5. UI

### 5.1 Nova tela Fixos

`lib/ui/telas/tela_fixos.dart` (novo arquivo), seguindo o padrão de `TelaPotes`/`TelaCartoes` (lista simples + FAB "Novo fixo" + formulário + exclusão com confirmação):

- Lista os Fixos (`fixosProvider`), um item por `Fixo`: descrição, de quem, valor, e (se gasto) o nome do pote.
- FAB abre um diálogo perguntando "Ganho ou Gasto?" primeiro (`SimpleDialog` com duas opções, ou dois botões), e só então abre o formulário correspondente.
- Formulário de ganho: De quem, Descrição, Valor.
- Formulário de gasto: Descrição, De quem, Pote, Valor.
- Excluir: confirmação (`confirmarExclusao`, já existe), chama `repositorioFixosProvider.remover(id)`. Não apaga lançamentos já gerados (§2 decisão 8 — a exclusão é só do documento `Fixo`; nenhum código extra precisa rodar sobre `Ganho`/`Gasto` existentes).

### 5.2 Navegação

`lib/ui/shell.dart`: `_destinos`/`telas` passam a ser, nesta ordem: Resumo, Ganhos, Gastos, Potes, Cartões, Parcelas → **Resumo, Ganhos, Gastos, Parcelas, Fixos, Potes, Cartões** (reordena Parcelas antes de Potes, insere Fixos entre Parcelas e Potes). Ícone sugerido: `Icons.repeat` (ainda não usado por nenhum destino).

### 5.3 Trava na tela de Ganhos

`lib/ui/telas/tela_ganhos.dart`, `_ColunaMembro`: quando `travadoPorFixo(origemFixoId: g.origemFixoId, mesRef: g.mesRef)` é verdadeiro, o `ListTile` perde `onTap` (vira `null`) e o `trailing` (botão excluir) some — mesmo padrão que `LinhaResponsiva` já usa pra "sem ação" (ver §5.4). Acrescenta um indicador visual curto (ex.: um `Icon(Icons.lock_outline, size: 14)` ao lado do texto "Previsto" no subtítulo, ou um subtítulo "· Previsto · Fixo" quando vem de um Fixo) para o usuário entender por que não consegue tocar.

### 5.4 Trava na tela de Gastos

`lib/ui/telas/tela_gastos.dart`, `_linhaDoGasto`: quando `travadoPorFixo(...)` é verdadeiro, passa `aoTocar: null` e `aoExcluir: null` para `LinhaResponsiva` — o componente já trata esses dois campos como opcionais e esconde a ação quando nulos (não precisa de mudança em `tabela_responsiva.dart`). Mesmo indicador visual do subtítulo que a tela de Ganhos ganha.

## 6. Testes

- `test/dominio/models/fixo_test.dart` (novo): round-trip `toMap`/`fromMap` para os dois tipos; `poteId` nulo em ganho.
- `test/dominio/models/ganho_test.dart` / `gasto_test.dart`: round-trip com `origemFixoId` preenchido e nulo; `Gasto` com `previsto: true`/`false`.
- `test/dominio/totais_test.dart`: casos de `gastosEfetivos` e `gastosEfetivosNaJanela`, espelhando os de `ganhosEfetivos`/`ganhosEfetivosNaJanela` (inclusive o caso que prova que a janela não mistura meses: real num mês não pode apagar previsto da mesma pessoa em outro mês).
- `test/dominio/fixos_test.dart` (novo, ou junto de `fixo_test.dart`): `mesAlvoDosFixos()` (mês real +1, não depende do mês selecionado); `fixosParaGerar` (Fixo sem lançamento ainda entra na lista; Fixo cuja origem já está em `origensJaGeradasNoMes` não entra); `travadoPorFixo` (sem origem nunca trava; com origem e mês futuro trava; com origem e mês igual/passado ao real não trava).
- `test/estado/providers_test.dart`: `garantirFixosDoMesProvider` gera os lançamentos certos (ganho e gasto) na primeira chamada; não duplica numa segunda chamada; `totaisDoMesProvider`/`gastosPorPoteProvider`/`serieMensalProvider` passam a contar gasto previsto do mesmo jeito que já contam ganho previsto.
- `test/ui/tela_fixos_test.dart` (novo): criar um Fixo de cada tipo; excluir um Fixo não pede nada além da confirmação padrão.
- `test/ui/tela_ganhos_test.dart` / `tela_gastos_test.dart`: um lançamento com `origemFixoId` e mês futuro não responde a toque nem mostra exclusão; o mesmo lançamento, com mês igual ao mês real atual (ou passado), volta a responder normalmente.
- `test/ui/shell_test.dart`: Fixos aparece na navegação, na posição certa.

## 7. Fora de escopo

- Editar um Fixo já criado (mudar valor/descrição/pote do molde) — por ora só criar e excluir; para "ajustar o aluguel que subiu", a via é excluir e recriar (os lançamentos já gerados antes não são afetados).
- Qualquer geração retroativa de meses pulados (app fechado por vários meses) — a cada abertura, só garante o mês seguinte a partir de hoje.
- Pausar um Fixo temporariamente sem excluir.
- Qualquer notificação/lembrete sobre Fixos cujo mês chegou e ainda não foi revisado.
- Gasto previsto entrar em `comprometidoNoMes`/`percentualComprometidoProvider`/`estouroProjetadoProvider` — esses continuam só sobre parcelas.
