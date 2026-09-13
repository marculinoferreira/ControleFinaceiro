# Quatro ajustes de UI — Design

**Data:** 2026-09-13
**Status:** aprovado no brainstorming, aguardando revisão do documento

## 1. Contexto e escopo

Quatro ajustes de UI independentes, pedidos juntos pelo usuário:

1. O gráfico "Comprometido nos próximos 12 meses" (`LinhaComprometimento`) não
   mostra o total comprometido, só a linha mês a mês.
2. As telas "Gastos" e "Cartões" mostram um checkbox de seleção (coluna
   inteira + "selecionar tudo" no cabeçalho) que não tem nenhuma
   funcionalidade — clicar na linha já abre a edição, o checkbox é só ruído
   visual.
3. Em "Gastos" e "Parcelas", já existe uma linha de total por grupo (Data,
   Pote ou Cartão), mas não uma soma geral da tabela inteira.
4. Na tela "Gráficos", o seletor Marcos/Silvia/Casal rola junto com os sete
   gráficos e desaparece; na tela "Resumo" o mesmo seletor fica fixo no topo.

## 2. Decisões tomadas

| # | Decisão | Escolha | Por quê |
|---|---|---|---|
| 1 | Período somado no gráfico de comprometimento | Soma dos 12 pontos da série já exibida | `serieComprometimentoProvider` já monta a série com `janelaDe(mesSelecionado, mesesDaSerie)` — ela **começa** no mês visualizado e vai 12 meses à frente. Não há "resto do ano" nem data dinâmica pra calcular: a soma pedida é a soma da série que já está na tela. |
| 2 | Onde desenhar o total do gráfico | Novo parâmetro opcional `rodape` em `MolduraGrafico`, abaixo da legenda | Mesmo padrão do `total` opcional em `GrupoResponsivo` (spec 2026-09-12): campo novo, opcional, só usado por quem passar — os outros seis gráficos continuam idênticos. Fica dentro do mesmo `Card`, alinhado à esquerda (mesmo `crossAxisAlignment.start` da legenda). |
| 3 | Como remover o checkbox | `showCheckboxColumn: false` no único `DataTable` de `TabelaResponsiva` | O checkbox aparece porque o Flutter desenha essa coluna por padrão quando alguma `DataRow` tem `onSelectChanged` (aqui, sempre que `aoTocar != null`). `showCheckboxColumn: false` remove a coluna e o "selecionar tudo" do cabeçalho sem remover `onSelectChanged` — o toque na linha continua chamando `aoTocar` normalmente, porque no Flutter isso não depende do checkbox estar visível. Como é o único `DataTable` do widget, a mudança é uma linha e vale para todas as telas que usam `TabelaResponsiva` (Gastos, Cartões, Parcelas, Potes, Resumo, Ganhos) — nas que não têm `aoTocar` (Parcelas, Resumo) não havia checkbox visível de qualquer forma. |
| 4 | Cor da linha "Somatória total" | Fundo `Colors.grey.shade800`, texto branco em negrito | Já existe uma linha de total **por grupo** (fundo cinza claro `surfaceContainerHighest`, texto em negrito `onSurface` — spec 2026-09-12). A nova linha é a soma de tudo, não de um grupo, e precisa se distinguir claramente das linhas de total por grupo. Cinza escuro fixo (não dependente do tema) com texto branco garante contraste alto nos dois temas e uma hierarquia visual clara: total de grupo (cinza claro) < soma geral (cinza escuro). |
| 5 | Onde entra a "Somatória total" | Depois de todos os grupos, somando todas as linhas da tabela inteira, independente da ordenação | Pedido explícito do usuário em Parcelas; estendido a Gastos porque as duas telas compartilham `TabelaResponsiva.agrupada` e já têm total por grupo. A soma usa todas as linhas de todos os grupos (inclusive a ordenação A–Z, que não tem total por grupo porque não tem título) — trocar de "Data" pra "A–Z" não pode fazer a soma geral sumir. |
| 6 | Onde calcular a "Somatória total" | Cada tela soma seus próprios itens (mesmo campo já usado no total por grupo: `valor` em Gastos, `valorParcela` em Parcelas) e passa pronto pra `TabelaResponsiva` | Mesma divisão de responsabilidade do total por grupo: a tela sabe qual campo somar, o widget só sabe desenhar a linha. |
| 7 | Como fixar o seletor de visão nos Gráficos | Tirar `_SeletorVisao` de dentro do `SingleChildScrollView`, replicando a estrutura do Resumo | Resumo já faz exatamente isso: `Column` com o seletor fixo no topo e só o conteúdo de baixo (lá, a tabela; aqui, a grade de sete gráficos) dentro de `Expanded(child: SingleChildScrollView(...))`. Não é preciso inventar mecanismo novo (`Sliver`, `pinned`, etc.) — o padrão já está no app. |

## 3. Total no gráfico de comprometimento

Arquivos: `lib/ui/widgets/moldura_grafico.dart`,
`lib/ui/widgets/graficos/linha_comprometimento.dart`.

### 3.1 `MolduraGrafico<T>`

Novo campo opcional:

```dart
final Widget Function(T)? rodape;
```

Renderizado depois do bloco da legenda (`..._legenda()`), só quando os dados
não estão vazios (mesma condição hoje usada por `_legenda()`):

```dart
List<Widget> _rodape() {
  final valor = dados.value;
  if (valor == null || estaVazio(valor) || rodape == null) return const [];
  return [const SizedBox(height: 8), rodape!(valor)];
}
```

`null` (padrão) não desenha nada — os outros seis gráficos não mudam.

### 3.2 `LinhaComprometimento`

Passa `rodape` somando a série:

```dart
rodape: (serie) => Align(
  alignment: Alignment.centerLeft,
  child: Text(
    'Total: ${formatarReais(serie.fold(0.0, (soma, p) => soma + p.valor))}',
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.bold),
  ),
),
```

(`Theme.of(context)` disponível porque `construir`/`rodape` já rodam dentro do
`build` do `MolduraGrafico`, que tem `context`.)

## 4. Remover checkbox de seleção

Arquivo: `lib/ui/widgets/tabela_responsiva.dart`, método `_tabela()`.

Uma linha no `DataTable`:

```dart
DataTable(
  showCheckboxColumn: false,
  columns: [...],
  rows: [...],
)
```

Nada mais muda: `onSelectChanged` continua ligado a `aoTocar` em cada
`DataRow`, então o toque na linha continua abrindo a edição.

## 5. Linha "Somatória total"

Arquivo: `lib/ui/widgets/tabela_responsiva.dart`.

### 5.1 Novo campo em `TabelaResponsiva`

```dart
final double? somatoriaGeral;
```

- Construtor `.agrupada` ganha o parâmetro opcional `this.somatoriaGeral`.
- Construtor simples (lista sem agrupamento) não expõe o parâmetro — não é
  usado por nenhuma tela sem grupo.
- `null` (padrão): nenhuma linha nova aparece, comportamento atual
  preservado.

### 5.2 DataTable (`_tabela()`)

Depois do loop dos grupos (`for (final grupo in grupos) ...`), se
`somatoriaGeral != null`, adiciona uma última `DataRow` via novo método
`_somatoriaGeral(context, somatoriaGeral!)` — mesma estrutura de
`_rodapeDeGrupo` (texto na coluna 0, valor sob `colunaDoTotal` quando
informado, resto vazio), mas com:

```dart
color: const WidgetStatePropertyAll(Color(0xFF424242)), // Colors.grey.shade800
```

e texto:

```dart
const estilo = TextStyle(fontWeight: FontWeight.bold, color: Colors.white);
```

Rótulo da célula 0: `colunaDoTotal == null ? 'Somatória total: ${formatarReais(total)}' : 'Somatória total'`
(mesma lógica condicional de `_rodapeDeGrupo`).

### 5.3 Cards (`_cards()`)

Depois do loop dos grupos na lista `itens`, se `somatoriaGeral != null`,
adiciona um último item marcador `_SomatoriaGeral(total: somatoriaGeral!)`,
renderizado como um `Container` igual ao de `_RodapeDeGrupo` mas com
`color: const Color(0xFF424242)` e texto branco em negrito:
`'Somatória total: ${formatarReais(total)}'`.

### 5.4 Telas

`tela_gastos.dart` e `tela_parcelas.dart` passam:

```dart
somatoriaGeral: grupos
    .expand((g) => g.itens)
    .fold(0.0, (soma, item) => soma + item.valor), // .valorParcela em Parcelas
```

(soma sobre `grupos` — a lista de domínio antes de virar `GrupoResponsivo` —
não sobre os `GrupoResponsivo.total`, que é `null` na ordenação A–Z.)

## 6. Fixar o seletor de visão em Gráficos

Arquivo: `lib/ui/telas/tela_graficos.dart`.

`TelaGraficos.build` passa a montar:

```dart
return Column(
  children: [
    _SeletorVisao(membros: membros),
    Expanded(
      child: SingleChildScrollView(
        key: const Key('graficos_rolagem'),
        child: desktop ? _duasColunas() : _colunaUnica(),
      ),
    ),
  ],
);
```

Em vez do `SingleChildScrollView` único de hoje envolvendo tudo. A key
`graficos_rolagem` se mantém, só muda o que fica dentro dela (a grade de
gráficos, não mais o seletor).

## 7. Testes

- `test/ui/tela_graficos_test.dart`: caso novo confirmando o total do
  gráfico de comprometimento (`find.textContaining('Total: R\$')` com dados
  conhecidos); caso novo de regressão confirmando que `_SeletorVisao` fica
  fora do widget de rolagem (ex.: localizar o `SingleChildScrollView` por
  key e verificar que o seletor não é descendente dele, ou verificar via
  `tester.getTopLeft` que a posição do seletor não muda ao rolar).
- `test/ui/tabela_responsiva_test.dart`: casos novos —
  - `DataTable` não mostra mais checkbox (`find.byType(Checkbox)` vazio)
    mesmo com linhas que têm `aoTocar`;
  - `somatoriaGeral` não nulo mostra a linha "Somatória total: R$ X" no
    desktop e no mobile, depois de todas as linhas/grupos;
  - `somatoriaGeral` nulo (padrão) não muda comportamento atual.
- `test/ui/tela_gastos_test.dart` / `test/ui/ordem_gastos_ui_test.dart`:
  caso novo confirmando que a soma geral aparece e está correta nas quatro
  ordenações (Data, A–Z, Pote, Cartão) — inclusive A–Z, que não tem total
  por grupo.
- `test/ui/tela_parcelas_test.dart`: caso equivalente somando
  `valorParcela`.
- Nenhum teste existente deveria quebrar: os quatro ajustes são aditivos
  (parâmetros novos opcionais, restruturação de layout que preserva keys) —
  exceto testes que hoje afirmem a presença de `Checkbox` em
  `tabela_responsiva_test.dart`/telas, que precisam ser ajustados para
  refletir a remoção intencional.

## 8. Fora de escopo

- Checkbox em outras telas que não usam `TabelaResponsiva` (não existem
  hoje).
- Soma geral em Resumo ou Ganhos — não pedido, e Resumo já tem seu próprio
  total por pote via cascata.
- Qualquer mudança na regra de agrupamento ou ordenação (`agruparPor`,
  `OrdemGastos`) em si.
- Mudar o cálculo de `serieComprometimento` ou o período de 12 meses —
  a soma reaproveita a série existente tal como está.
