# Layout de Gastos: faixa de potes + filtros/ordenação em pílulas — Design

**Data:** 2026-09-13
**Status:** aprovado no brainstorming, aguardando revisão do documento

## 1. Contexto e escopo

Redesign do topo da tela "Gastos" (e, por tabela — os widgets são
compartilhados —, de "Parcelas"), pedido pelo usuário com esta ordem visual:

1. Resumo (Ganhos/Gastos/Saldo) compacto no topo — **já existe**
   (`BarraTotais`, global, acima de toda tela autenticada) e não muda.
2. Faixa de potes, estilo do menu (ícone + nome), logo abaixo do resumo —
   **novo componente**. Tocar num pote abre "Novo gasto" com aquele pote
   já selecionado.
3. Filtros (Pessoa, Cartão, Pote) em pílulas compactas numa linha só —
   **redesign** de `FiltrosLancamentos`.
4. "Ordenar por" em pílulas finas — **redesign** de `SeletorOrdem`.
5. Lista de gastos por baixo — **sem mudança** (`TabelaResponsiva.agrupada`).

`FiltrosLancamentos` e `SeletorOrdem` vivem hoje no mesmo arquivo
(`lib/ui/widgets/filtros_lancamentos.dart`) e são usados tanto por
`TelaGastos` quanto por `TelaParcelas`; o usuário confirmou que o redesign
vale para as duas telas, para manter a cara do app consistente.

## 2. Decisões tomadas

| # | Decisão | Escolha | Por quê |
|---|---|---|---|
| 1 | Resumo do topo | Mantém `BarraTotais` como está, sem resumo novo | Confirmado com o usuário: já é a barra global (Ganhos/Gastos/Saldo, respeitando a visão Pessoa/Casal); um segundo resumo, filtrado por Pote/Cartão, foi cogitado e descartado — fora de escopo. |
| 2 | Faixa de potes: onde vive | Widget novo `FaixaPotes`, só em `TelaGastos` | Parcelas nunca teve um jeito de criar lançamento (compras parceladas nascem em Gastos) — a faixa não faz sentido lá. |
| 3 | Faixa de potes: layout | `Row` com um item por pote, ícone em cima (na cor do pote) e nome embaixo (`FittedBox` para encolher nomes longos) — mesma linguagem visual dos destinos do menu (`Shell._barraInferior`) | Potes têm um teto de 6 (`tela_potes_test.dart`: "não passa de 6 potes"), então cabem numa linha só sem precisar rolar — o "estilo do menu" pedido é sobre a aparência (ícone + rótulo), não sobre rolagem. |
| 4 | Ícone de cada pote | Mapa fixo string→`IconData` (tabela abaixo), com fallback para chaves desconhecidas | `Pote.icone` é uma chave textual que existe no modelo desde sempre mas nunca foi mapeada para um ícone em lugar nenhum da UI — este é o primeiro uso dela. A semeadura padrão (`semeadura.dart`) já usa 6 chaves distintas; potes criados depois (sem seletor de ícone na tela Potes) caem sempre em `'casa'`, o que é aceitável e fora de escopo corrigir aqui. |
| 5 | Toque num pote | Abre `abrirFormularioGasto` com um novo parâmetro opcional `poteIdInicial` | Reaproveita o formulário e o fluxo de gravação já existentes; só muda qual pote vem pré-selecionado. |
| 6 | Botão flutuante "Novo gasto" | **Removido** | Decisão do usuário: a faixa de potes vira o único caminho para criar um gasto nesta tela — sempre com um pote escolhido de saída, o que também é mais correto (todo gasto tem pote). |
| 7 | Faixa de potes sem membros cadastrados | Itens da faixa ficam desabilitados (mesmo tratamento que o FAB tinha) | O formulário depende de uma pessoa pra atribuir o gasto; sem membro, abrir o formulário hoje já é bloqueado (FAB desabilitado). A faixa assume esse mesmo bloqueio, item a item. |
| 8 | Filtros: aparência | Pílula (cápsula com borda, ícone de seta) mostrando o valor atual (ex.: "Casal", "Todos", nome escolhido) | Troca o `DropdownButtonFormField` (caixa com rótulo flutuante, mais alto) por algo mais compacto, cabendo os três numa linha só mesmo no celular. |
| 9 | Filtros: interação | `PopupMenuButton` ancorado na própria pílula, com as mesmas opções de hoje | Menu suspenso é mais leve que uma folha inferior pra trocar um filtro rápido, e não precisa de estado próprio (o `PopupMenuButton` já cuida de abrir/fechar). |
| 10 | Filtros: responsividade | Sempre uma `Row` com três `Expanded`, sem o breakpoint de empilhar (`_larguraTresColunas` de hoje é removido) | Pedido explícito ("numa linha só"); o texto de cada pílula usa `FittedBox`/reticências pra caber em qualquer largura, em vez de quebrar pra duas linhas. |
| 11 | Ordenar por: aparência e interação | Mesma pílula visual dos filtros, mas cada uma já É uma opção (Data/A–Z/Pote/Cartão) — tocar seleciona direto, sem menu | Mantém o comportamento de hoje (`SegmentedButton`, escolha direta), só troca o visual pra ficar consistente com a linha de filtros logo acima. |
| 12 | Compatibilidade com testes existentes | As pílulas mantêm as mesmas `Key`s de hoje (`filtro_membro`, `filtro_cartao`, `filtro_pote`, `ordem_gastos`) e os rótulos continuam aparecendo como `Text` descendente da pílula fechada | `PopupMenuButton` com `child` sendo a pílula preserva `find.descendant(of: find.byKey(...), matching: find.text(rotulo))` e o padrão `tap(key) → tap(text)` que os testes de filtro/ordenação já usam — a grande maioria continua passando sem alteração. |

## 3. `FaixaPotes` (novo widget)

Arquivo novo: `lib/ui/widgets/faixa_potes.dart`.

```dart
IconData iconeDoPote(String chave) => switch (chave) {
  'casa' => Icons.home,
  'sofa' => Icons.weekend,
  'grafico' => Icons.show_chart,
  'alvo' => Icons.track_changes,
  'presente' => Icons.card_giftcard,
  'livro' => Icons.menu_book,
  _ => Icons.account_balance_wallet,
};

class FaixaPotes extends StatelessWidget {
  final List<Pote> potes;
  final bool habilitado; // false quando nao ha membros cadastrados
  final void Function(Pote) aoTocar;
  ...
}
```

- `Row` com um item por pote (`Expanded` em cada, dividindo a largura
  igualmente — mesmo truque do `SeletorOrdem` atual).
- Cada item: `Icon(iconeDoPote(pote.icone), color: corDoPote)` em cima,
  `Text(pote.nome)` embaixo dentro de `FittedBox(fit: BoxFit.scaleDown)`.
- `onTap: habilitado ? () => aoTocar(pote) : null` — item continua visível,
  mas com opacidade reduzida e sem reação ao toque quando desabilitado.
- Lista de potes vazia (`potes.isEmpty`): a faixa não desenha nada
  (`SizedBox.shrink()`) — sem potes cadastrados não há como classificar um
  gasto; a tela de "Lei dos Potes" é quem resolve isso, fora de escopo aqui.

## 4. `FiltrosLancamentos` e `SeletorOrdem` (redesign)

Arquivo: `lib/ui/widgets/filtros_lancamentos.dart` (os dois widgets já
vivem aqui).

### 4.1 Pílula compartilhada

Widget privado `_Pilula` usado pelos dois:

```dart
class _Pilula extends StatelessWidget {
  final IconData? iconeFinal; // seta pra baixo nos filtros; nenhum no ordenar
  final String rotulo;
  final bool destacada; // preenchida quando e a opcao ativa (so Ordenar por)
  final VoidCallback? aoTocar;
  ...
}
```

Visual: `Container` com `borderRadius` alto (formato de cápsula), borda
`colorScheme.outlineVariant`; quando `destacada`, fundo
`colorScheme.primaryContainer` e texto/ícone `onPrimaryContainer`. Texto
dentro de `FittedBox(fit: BoxFit.scaleDown)` para não estourar em telas
estreitas ou fonte grande.

### 4.2 `FiltrosLancamentos`

Cada um dos três filtros vira:

```dart
PopupMenuButton<String?>(
  key: const Key('filtro_membro'), // idem filtro_cartao, filtro_pote
  child: _Pilula(rotulo: rotuloAtual, iconeFinal: Icons.arrow_drop_down),
  itemBuilder: (context) => [
    for (final item in itens) PopupMenuItem(value: item.valor, child: Text(item.rotulo)),
  ],
  onSelected: aoMudar,
)
```

`Row` com os três `Expanded(child: ...)`, sem `LayoutBuilder`/breakpoint —
substitui o método `_seletor` atual e remove `_larguraTresColunas`.

### 4.3 `SeletorOrdem`

`Row` com quatro `Expanded(child: _Pilula(...))`, uma por `OrdemGastos`,
`destacada: ordem == entrada.key`, `aoTocar: () => notifier.selecionar(...)`.
Sem `SegmentedButton`. Mantém a `Key('ordem_gastos')` no `Row` externo (não
em cada pílula) — mesma posição de hoje, pra `find.descendant` continuar
funcionando.

## 5. `abrirFormularioGasto` e `FormularioGasto`

Arquivo: `lib/ui/telas/formulario_gasto.dart`.

- `abrirFormularioGasto` ganha `String? poteIdInicial` (opcional, `null`
  por padrão — comportamento de hoje preservado para quem não passar).
- `FormularioGasto` ganha o mesmo campo opcional.
- Em `_formulario`, a linha que hoje é

  ```dart
  _poteId ??= potes.isEmpty ? null : potes.first.id;
  ```

  passa a ser

  ```dart
  _poteId ??= (widget.poteIdInicial != null &&
          potes.any((p) => p.id == widget.poteIdInicial))
      ? widget.poteIdInicial
      : (potes.isEmpty ? null : potes.first.id);
  ```

  — só usa `poteIdInicial` se ele ainda existir na lista (mesma cautela já
  aplicada ao pote de um lançamento existente, algumas linhas abaixo).

## 6. `TelaGastos`

- Remove `floatingActionButton`.
- Novo corpo (`BarraTotais` já fica acima de tudo, via `Shell`, sem
  mudança): `FaixaPotes` → `FiltrosLancamentos` → `SeletorOrdem` →
  `Divider` → lista, na mesma estrutura de `Column`/`Expanded` de hoje.
- `FaixaPotes.aoTocar` chama
  `abrirFormularioGasto(context: context, ref: ref, poteIdInicial: pote.id)`.
- `FaixaPotes.habilitado` recebe `membros.isNotEmpty` (mesma condição que
  hoje desabilita o FAB).

## 7. `TelaParcelas`

Nenhuma mudança estrutural — continua chamando os mesmos
`FiltrosLancamentos`/`SeletorOrdem`, que agora renderizam como pílulas. Sem
`FaixaPotes` (nunca teve criação de lançamento nesta tela).

## 8. Testes

- `test/ui/faixa_potes_test.dart` (novo): um item por pote com ícone e
  nome; toca num pote e `aoTocar` é chamado com aquele `Pote`; lista vazia
  não desenha nada; `habilitado: false` faz o toque não disparar nada.
- `test/ui/filtros_lancamentos_test.dart` (se não existir, criar) ou os
  testes de integração já existentes (`ordem_gastos_ui_test.dart`,
  `parcelas_filtros_test.dart`, `visao_entre_telas_test.dart`): continuam
  passando sem alteração, porque a `Key` e o padrão de interação
  (`tap(key)` → `tap(text)`) não mudam — só a aparência do widget por trás
  da `Key`.
- `test/ui/tela_gastos_test.dart`: o teste
  `'FAB de novo gasto fica desabilitado sem membros cadastrados'` é
  **reescrito** para `'faixa de potes fica desabilitada sem membros
  cadastrados'` — monta `TelaGastos` sem membros e confirma que tocar num
  item da `FaixaPotes` não abre o formulário (`find.text('Novo gasto')`
  continua ausente depois do toque).
- `test/ui/formulario_gasto_test.dart`: novo caso — `FormularioGasto`
  aberto com `poteIdInicial: 'p2'` mostra "Conforto" pré-selecionado no
  campo de pote; `poteIdInicial` apontando pra um pote que não existe mais
  cai no `potes.first.id` de sempre, sem quebrar.
- Nenhum teste de `Ordenar por`/filtros deveria precisar mudar; se algum
  quebrar por depender de `SegmentedButton`/`DropdownButtonFormField`
  especificamente (em vez de `Key`+texto), é ajustado nesse momento.

## 9. Fora de escopo

- Seletor de ícone na tela "Lei dos Potes" (potes novos continuam nascendo
  com `icone: 'casa'`, sem UI para trocar).
- Resumo filtrado por Pote/Cartão (a `BarraTotais` global continua sendo o
  único resumo).
- Qualquer mudança em `TabelaResponsiva`/lista de gastos em si.
- Rolagem horizontal na faixa de potes (não é necessária com o teto de 6
  potes já existente).
