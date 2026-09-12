# Linhas no gráfico de cartão + totalizadores por grupo — Design

**Data:** 2026-09-12
**Status:** aprovado no brainstorming, aguardando revisão do documento

## 1. Contexto e escopo

Dois ajustes de UI independentes, pedidos juntos pelo usuário:

1. O gráfico "Gastos por cartão" (`RoscaPorCartao`, ver
   `docs/superpowers/specs/2026-09-12-grafico-gastos-por-cartao-design.md`)
   mostra a porcentagem de cada fatia, mas não o valor em reais por cartão.
2. As telas de Gastos e Parcelas, quando agrupadas por Data, Pote ou Cartão
   (`OrdemGastos`), não mostram quanto cada grupo soma — só dá pra ver
   somando os itens de cabeça.

Os dois já têm toda a infraestrutura de domínio pronta (`Fatia`/`totalDasFatias`
para o gráfico; `Grupo<T>`/`agruparPor` para as tabelas). Este spec cobre só a
apresentação.

## 2. Decisões tomadas

| # | Decisão | Escolha | Por quê |
|---|---|---|---|
| 1 | Rótulo do gráfico de cartão | Mantém a porcentagem dentro da fatia e adiciona uma linha externa com o valor em R$ | Confirmado com o usuário: as duas informações convivem, a porcentagem já funciona bem para fatias grandes, o valor externo cobre o que faltava. |
| 2 | Onde desenhar a linha | `CustomPainter` próprio, sobre o `PieChart`, dentro do mesmo `Stack` | fl_chart não desenha "leader lines" para fora do anel; calculando o ângulo de cada fatia com a mesma fórmula que a biblioteca usa (proporção do valor sobre o total, começando em `startDegreeOffset = 0`), a linha e o rótulo sempre alinham com a fatia certa, sem tocar em código de terceiros. |
| 3 | Cor da linha | Cor da própria fatia (mesma paleta fixa de cartões) | Liga visualmente a linha à fatia sem precisar de nova legenda. |
| 4 | Texto do rótulo externo | Só o valor formatado (`formatarReais`), sem o nome do cartão | O nome já está na legenda abaixo do gráfico; repetir no rótulo externo poluiria um gráfico que já tem raio pequeno. |
| 5 | Espaço para a linha/rótulo | Anel um pouco menor (`centerSpaceRadius` e `radius` reduzidos) e altura do card um pouco maior, só neste gráfico | O card tem altura fixa (`MolduraGrafico.altura`, 240 por padrão); sem folga o rótulo cortaria nas bordas do card nas fatias que apontam para cima/baixo. Mudar só `RoscaPorCartao` não afeta os outros seis gráficos, que reaproveitam o mesmo `MolduraGrafico`. |
| 6 | Fatia sem linha | Nenhuma — toda fatia com valor > 0 ganha linha e rótulo, mesmo as menores que 5% (que hoje não mostram porcentagem) | É exatamente nas fatias pequenas que o valor externo mais ajuda, já que a porcentagem interna não cabe nelas. |
| 7 | Quais agrupamentos ganham total | Data, Pote e Cartão; não a ordem A–Z | A–Z é lista corrida sem cabeçalho de grupo (`Grupo.titulo == ''`); sem cabeçalho não há "grupo" visual para totalizar. Usar `grupo.titulo.isNotEmpty` como gatilho reaproveita a mesma condição que já decide se desenha o cabeçalho — nenhum estado novo. |
| 8 | Valor somado em Parcelas | Coluna "Valor/mês" (`CompraParcelada.valorParcela`) | É o único valor monetário somável do grupo; "Faltam" é uma contagem de meses, não dá para somar. |
| 9 | Onde implementar o total | Uma vez em `TabelaResponsiva`/`GrupoResponsivo`, não duplicado nas duas telas | Gastos e Parcelas já compartilham `TabelaResponsiva.agrupada`; a soma em si (um `fold` sobre os itens do grupo) fica em cada tela (que sabe qual campo somar), mas a apresentação da linha de total é uma coisa só. |

## 3. Gráfico "Gastos por cartão"

Arquivo: `lib/ui/widgets/graficos/rosca_por_cartao.dart` (único arquivo tocado
nesta parte).

### 3.1 Ajuste de raio e altura

- `centerSpaceRadius`: 52 → 44.
- `radius` de cada seção: 46 → 38 (anel externo passa de raio 98 para 82).
- `MolduraGrafico.altura`: passa a ser passado explicitamente como 260 (era o
  padrão 240) só nesta chamada, em `RoscaPorCartao.build`.

### 3.2 Cálculo do ângulo de cada fatia

Nova função privada em `_Rosca`, replicando a mesma lógica que
`PieChartPainter` usa (soma cumulativa de graus, `startDegreeOffset = 0`,
sentido horário a partir do eixo 3 horas):

```dart
List<double> _anguloMedioPorFatia(List<Fatia> fatias, double total) {
  var acumulado = 0.0;
  final medios = <double>[];
  for (final f in fatias) {
    final grausDaFatia = total <= 0 ? 0.0 : f.valor / total * 360;
    medios.add(acumulado + grausDaFatia / 2);
    acumulado += grausDaFatia;
  }
  return medios;
}
```

`fatias` é a mesma lista, na mesma ordem, usada para montar `sections` do
`PieChart` — não há reordenação entre as duas, então o ângulo calculado bate
com o que a biblioteca desenha.

### 3.3 `CustomPainter` das linhas

Novo widget privado `_LinhasDeChamada` (um `CustomPaint` inserido no `Stack`,
entre o `PieChart` e o texto central do total, ocupando o mesmo tamanho):

- Recebe `fatias`, `total` e as cores já resolvidas (`corDeHex`).
- Para cada fatia com `valor > 0`:
  - Ponto inicial: borda externa do anel (raio 82) no ângulo médio da fatia.
  - Ponto final da linha: raio 96 (82 + 14), mesmo ângulo.
  - Desenha o segmento com `Paint()` na cor da fatia, `strokeWidth: 1.5`.
  - Desenha o rótulo (`formatarReais(f.valor)`) centrado a partir do raio 96,
    usando `TextPainter`, com a cor de texto padrão do tema (não a cor da
    fatia, por contraste em modo claro/escuro).
- Fatias com fração de círculo desprezível (< 1°, ou seja, `total <= 0`) não
  desenham nada — evita linha "apontando pra lugar nenhum" quando não há
  dado (esse caso já cai no ramo "vazio" do `MolduraGrafico` antes de chegar
  aqui, mas o painter fica defensivo mesmo assim).

### 3.4 Teste manual esperado

Com os dados do teste existente (Nubank 700, Inter 300 → total 1000, 70%/30%),
a fatia do Nubank (maior) deve mostrar linha + "R$ 700,00" e a do Inter
"R$ 300,00", cada uma na cor correspondente.

## 4. Totalizador por grupo (Gastos e Parcelas)

### 4.1 `lib/ui/widgets/tabela_responsiva.dart`

`GrupoResponsivo` ganha um campo novo, opcional:

```dart
class GrupoResponsivo {
  final String titulo;
  final List<LinhaResponsiva> linhas;
  final double? total;

  const GrupoResponsivo({required this.titulo, required this.linhas, this.total});
}
```

- **DataTable** (`_tabela()`): depois das linhas de um grupo, se
  `grupo.total != null`, insere uma `DataRow` extra (`_rodapeDeGrupo`),
  mesmo formato de `_cabecalhoDeGrupo` (texto na primeira célula, resto
  vazio), mas com estilo diferente do cabeçalho — itálico, sem negrito total,
  cor `Theme.of(context).colorScheme.outline` — para não ser confundido com o
  título do grupo. Texto: `'Total: ${formatarReais(grupo.total!)}'`.
- **Cards** (`_cards()`): depois do último card de um grupo (antes do título
  do próximo, se houver), insere um `Padding` com o mesmo texto, estilo
  `bodySmall` + `outline`, alinhado à direita.
- Import novo: `../tema/formatadores.dart` (para `formatarReais`), hoje não
  importado neste arquivo.
- Sem total (`total == null`, o caso de hoje): nenhuma linha nova aparece —
  comportamento não muda para quem não passar o campo.

### 4.2 `lib/ui/telas/tela_gastos.dart`

Em `_tabela()`, cada `GrupoResponsivo` passa a levar:

```dart
total: grupo.titulo.isEmpty
    ? null
    : grupo.itens.fold(0.0, (soma, g) => soma + g.valor),
```

### 4.3 `lib/ui/telas/tela_parcelas.dart`

Mesma ideia, somando `c.valorParcela`:

```dart
total: grupo.titulo.isEmpty
    ? null
    : grupo.itens.fold(0.0, (soma, c) => soma + c.valorParcela),
```

## 5. Testes

- `test/ui/graficos_por_cartao_test.dart`: novos casos —
  - cada fatia mostra seu valor formatado fora do anel (`find.text(formatarReais(700))` etc.);
  - o `CustomPaint` das linhas existe e não lança exceção com 1 fatia (100%) e
    com fatia "Sem cartão" (órfã).
- `test/ui/tabela_responsiva_test.dart`: novos casos com
  `TabelaResponsiva.agrupada` —
  - grupo com `total` não nulo mostra a linha "Total: R$ X" no desktop e no
    mobile;
  - grupo com `total` nulo não mostra linha nenhuma extra (comportamento
    atual preservado).
- `test/ui/tela_gastos_test.dart` / `test/ui/ordem_gastos_ui_test.dart`: um
  caso novo confirmando o total por dia/pote/cartão soma certo (ex.: dois
  gastos de R$ 100 no mesmo dia → "Total: R$ 200,00" aparece uma vez sob o
  grupo).
- `test/ui/tela_parcelas_test.dart`: caso equivalente somando `valorParcela`.
- Nenhum teste existente deveria quebrar: os dois recursos são aditivos
  (campo novo opcional, gráfico com widget extra) e os testes atuais não
  buscam por texto em formato de moeda nas telas agrupadas.

## 6. Fora de escopo

- Mudar `RoscaPorPote`, `PizzaGanhos` ou qualquer outro gráfico da tela.
- Total geral da tela inteira (soma de todos os grupos) — só o total por
  grupo foi pedido.
- Total na ordem alfabética (lista corrida, sem cabeçalho).
- Qualquer mudança na regra de agrupamento (`agruparPor`) em si.
