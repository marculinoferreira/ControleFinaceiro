# Gráfico "Gastos por cartão" — Design

**Data:** 2026-09-12
**Status:** aprovado no brainstorming, aguardando revisão do documento

## 1. Contexto e escopo

A tela de Gráficos (spec 10) tem seis gráficos fixos. Este spec adiciona um
sétimo, fora da numeração original: uma rosca mostrando quanto foi gasto em
cada cartão/conta/carteira (`Cartao`) no mês selecionado.

`Cartao` (`lib/dominio/models/cartao.dart`) já existe e é usado para
filtrar Gastos e Parcelas, mas nenhum gráfico resume por ele ainda.

## 2. Decisões tomadas

| # | Decisão | Escolha | Por quê |
|---|---|---|---|
| 1 | Tipo de gráfico | Rosca, igual ao gráfico de pote | Mesma linguagem visual da tela; total no centro, fatias na legenda. |
| 2 | Cor das fatias | Paleta fixa ciclada por ordem | `Cartao` não tem campo `cor` (ao contrário de `Pote`/`Membro`). Adicionar `cor` mudaria o modelo de dados e a tela de cadastro — fora de escopo para um resumo visual. |
| 3 | Gasto sem cartão / cartão apagado | Fatia agregada "Sem cartão" | Mesmo padrão do gráfico de pote: o dinheiro saiu de qualquer jeito, não pode sumir do total. Reaproveita a convenção já existente em `_passaNoCartao` (string vazia = sem cartão). |
| 4 | Filtro de pessoa (visão) | Respeita `visaoProvider` | Consistente com o gráfico de pote: trocar para Marcos/Silvia filtra também esta rosca. |
| 5 | Posição na tela | 7º item, ao final da lista | Não é um dos seis gráficos da spec 10; anexar ao final evita renumerar o que já existe. |

## 3. Domínio

`lib/dominio/totais.dart` — nova função, mesmo formato de `somarGastosPorPote`:

```dart
Map<String, double> somarGastosPorCartao(List<Gasto> gastos, {String? membroId}) {
  final mapa = <String, double>{};
  for (final g in gastos) {
    if (membroId != null && g.membroId != membroId) continue;
    final chave = g.cartaoId ?? '';
    mapa[chave] = (mapa[chave] ?? 0) + g.valor;
  }
  return mapa;
}
```

`lib/dominio/graficos.dart` — nova função reaproveitando o helper privado
`_fatiar` (o mesmo miolo de `fatiasPorPote`/`fatiasPorMembro`):

```dart
/// Paleta fixa para entidades sem cor propria (Cartao). Mesmos tons de
/// `tela_potes.dart`, para a rosca de cartao nao destoar do resto do app.
const List<String> paletaCartoes = [
  '#2E7D32', '#1565C0', '#00838F', '#EF6C00', '#AD1457', '#4527A0',
];

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

`_fatiar` ganha um parâmetro opcional `nomeOrfaos` (default `'Outros'`, para
não quebrar as duas chamadas existentes) em vez de duplicar a função inteira
só para trocar um rótulo.

Gasto com `cartaoId == null` e gasto cujo `cartaoId` não bate com nenhum
`Cartao` cadastrado (cartão apagado) caem na mesma chave `''` e são somados
juntos na fatia "Sem cartão" — não há como nem por que distingui-los depois
que o cartão foi apagado.

## 4. Estado (`lib/estado/providers.dart`)

Dois providers novos, espelhando `gastosPorPoteProvider` /
`fatiasPorPoteProvider`:

```dart
final gastosPorCartaoProvider =
    Provider.autoDispose<AsyncValue<Map<String, double>>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);

  return ref
      .watch(gastosDoMesProvider(mes))
      .whenData((gastos) => somarGastosPorCartao(gastos, membroId: membroId));
});

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

## 5. UI

Novo arquivo `lib/ui/widgets/graficos/rosca_por_cartao.dart`, cópia
estrutural de `RoscaPorPote` (mesma `MolduraGrafico<List<Fatia>>`, mesmo
`_Rosca` com `PieChart` e total central):

- Título: "Gastos por cartão".
- `vazio`: "Nenhum gasto neste mês."
- `aoRecarregar`: invalida `cartoesProvider` e `gastosDoMesProvider(mes)`.
- `dados`: `fatiasPorCartaoProvider`.

`lib/ui/telas/tela_graficos.dart`: `RoscaPorCartao()` adicionado ao final da
lista `_graficos`, depois de `LinhaComprometimento()`. Como a lista tem 7
itens agora (ímpar), no layout de duas colunas a coluna esquerda fica com
um gráfico a mais — mesmo comportamento que `_duasColunas()` já produziria
com qualquer lista de tamanho ímpar, nenhuma mudança de código necessária.

## 6. Testes

- `test/dominio/totais_test.dart`: casos para `somarGastosPorCartao` —
  soma por cartão, filtro por `membroId`, gasto com `cartaoId` nulo cai em
  `''`.
- `test/dominio/graficos_test.dart` (onde `fatiasPorPote` já é testada):
  casos para `fatiasPorCartao` — cartão sem gasto não aparece, órfão vira
  "Sem cartão", cores cicladas pela paleta.
- `test/ui/tela_graficos_test.dart`: a lista de gráficos passa a ter 7 itens.

## 7. Fora de escopo

- Campo `cor` em `Cartao` e UI para escolhê-la.
- Qualquer outro gráfico novo além deste.
- Mudança na spec 10 (os seis gráficos originais permanecem com a mesma
  numeração e comportamento).
