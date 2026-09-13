# Quatro ajustes de UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar os quatro ajustes de UI aprovados no spec `docs/superpowers/specs/2026-09-13-quatro-ajustes-ui-design.md`: total no gráfico de comprometimento, remoção do checkbox de seleção nas tabelas, linha de "Somatória total" em Gastos e Parcelas, e o seletor Marcos/Silvia/Casal fixo na tela de Gráficos.

**Architecture:** Cada ajuste é aditivo sobre widgets já compartilhados (`MolduraGrafico`, `TabelaResponsiva`) ou uma reestruturação local de layout (`TelaGraficos`) — nenhuma mudança de modelo de domínio ou de provider é necessária. Os quatro são independentes entre si e podem ser implementados e commitados em qualquer ordem.

**Tech Stack:** Flutter/Dart, flutter_riverpod, fl_chart, flutter_test.

## Global Constraints

- Todo texto de UI em português, seguindo o vocabulário já usado no arquivo tocado (ex.: "Somatória total", "Total").
- `formatarReais` (de `lib/ui/tema/formatadores.dart`) é a única forma de formatar valores monetários — nunca formatar na mão.
- Rodar os testes do arquivo tocado depois de cada mudança: `flutter test <arquivo>`.
- Commits pequenos, um por task, seguindo o estilo `tipo: descrição` já usado no histórico do projeto (`feat:`, `fix:`, `style:`, `test:`).
- Nenhuma mudança nesta plan deve alterar o comportamento de telas/gráficos não mencionados no spec (Resumo, Ganhos, Potes, os outros 6 gráficos).

---

## Task 1: `MolduraGrafico` ganha o parâmetro opcional `rodape`

**Files:**
- Modify: `lib/ui/widgets/moldura_grafico.dart:20-116`
- Test: `test/ui/moldura_grafico_test.dart`

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces: `MolduraGrafico<T>({..., Widget Function(T)? rodape})` — Task 2 usa este parâmetro. `null` (padrão) não muda o comportamento atual.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/moldura_grafico_test.dart`, adicione o parâmetro `rodape` ao helper `montar` e um novo grupo de testes. O arquivo completo do helper (só a assinatura e o corpo do `MolduraGrafico` mudam; o resto do arquivo continua igual):

```dart
Future<int> montar(
  WidgetTester tester, {
  required AsyncValue<List<int>> dados,
  List<ItemLegenda> Function(List<int>)? legenda,
  String vazio = 'Nada neste mês.',
  String? subtitulo,
  Widget Function(List<int>)? rodape,
}) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  var recarregou = 0;

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MolduraGrafico<List<int>>(
        titulo: 'Gastos por pote',
        subtitulo: subtitulo,
        vazio: vazio,
        dados: dados,
        estaVazio: (l) => l.isEmpty,
        legenda: legenda ?? (_) => const [],
        rodape: rodape,
        aoRecarregar: () => recarregou++,
        construir: (l) => Text('serie com ${l.length}'),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return recarregou;
}
```

Adicione este grupo novo no `main()`, depois do grupo `'legenda'`:

```dart
  group('rodape', () {
    testWidgets('aparece quando informado e ha dado', (tester) async {
      await montar(
        tester,
        dados: const AsyncValue.data([1, 2]),
        rodape: (l) => Text('total ${l.length}'),
      );

      expect(find.text('total 2'), findsOneWidget);
    });

    testWidgets('nao aparece quando nao informado', (tester) async {
      await montar(tester, dados: const AsyncValue.data([1, 2]));

      expect(find.textContaining('total'), findsNothing);
    });

    testWidgets('nao aparece quando os dados estao vazios', (tester) async {
      await montar(
        tester,
        dados: const AsyncValue.data(<int>[]),
        rodape: (l) => const Text('nunca aparece'),
      );

      expect(find.text('nunca aparece'), findsNothing);
    });
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/ui/moldura_grafico_test.dart`
Expected: FAIL — `rodape` não existe em `MolduraGrafico` (erro de compilação: "no named parameter 'rodape'").

- [ ] **Step 3: Implementar o parâmetro em `MolduraGrafico`**

Em `lib/ui/widgets/moldura_grafico.dart`, adicione o campo e o parâmetro do construtor:

```dart
  final List<ItemLegenda> Function(T) legenda;
  final Widget Function(T)? rodape;
  final Widget Function(T) construir;
```

```dart
  const MolduraGrafico({
    super.key,
    required this.titulo,
    required this.vazio,
    required this.dados,
    required this.estaVazio,
    required this.legenda,
    required this.construir,
    required this.aoRecarregar,
    this.subtitulo,
    this.rodape,
    this.altura = 240,
  });
```

E no `build`, chame o novo helper depois de `..._legenda()`:

```dart
            const SizedBox(height: 12),
            if (dados.hasError)
              ErroComRecarregar(erro: dados.error!, aoRecarregar: aoRecarregar)
            else
              SizedBox(height: altura, child: _corpo(context)),
            ..._legenda(),
            ..._rodape(),
          ],
        ),
      ),
    );
  }
```

Adicione o método `_rodape()`, logo depois de `_legenda()`:

```dart
  /// Mesma condicao do `_legenda()`: sem dado (ou vazio), nao ha o que
  /// resumir no rodape.
  List<Widget> _rodape() {
    final valor = dados.value;
    if (valor == null || estaVazio(valor) || rodape == null) return const [];

    return [const SizedBox(height: 8), rodape!(valor)];
  }
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/ui/moldura_grafico_test.dart`
Expected: PASS (todos os testes, incluindo os três novos do grupo `rodape`).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/moldura_grafico.dart test/ui/moldura_grafico_test.dart
git commit -m "feat: MolduraGrafico ganha rodape opcional abaixo da legenda"
```

---

## Task 2: Total comprometido no gráfico "Comprometido nos próximos 12 meses"

**Files:**
- Modify: `lib/ui/widgets/graficos/linha_comprometimento.dart:18-39`
- Test: `test/ui/graficos_linhas_test.dart`

**Interfaces:**
- Consumes: `MolduraGrafico<T>({..., Widget Function(T)? rodape})` da Task 1.
- Produces: nada consumido por outra task.

- [ ] **Step 1: Escrever o teste que falha**

Em `test/ui/graficos_linhas_test.dart`, dentro do `group('linha de comprometimento', ...)`, adicione (depois do teste `'soma o valor das parcelas de cada mes'`):

```dart
    testWidgets('mostra o total comprometido abaixo do grafico',
        (tester) async {
      await montar(
        tester,
        const LinhaComprometimento(),
        parcelasDe: 3,
        valorParcela: 100,
      );

      // 3 parcelas de 100 (Ago/Set/Out) e os outros 9 meses da janela de 12
      // meses ficam em zero -> soma da serie inteira = 300.
      expect(find.text('Total: ${formatarReais(300)}'), findsOneWidget);
    });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/ui/graficos_linhas_test.dart`
Expected: FAIL — o texto `'Total: R$ 300,00'` não existe na árvore.

- [ ] **Step 3: Implementar o rodapé em `LinhaComprometimento`**

Em `lib/ui/widgets/graficos/linha_comprometimento.dart`, no `build` de `LinhaComprometimento`, adicione `rodape` à chamada de `MolduraGrafico`:

```dart
    return MolduraGrafico<List<PontoComprometido>>(
      titulo: 'Comprometido nos próximos $mesesDaSerie meses',
      vazio: 'Nenhuma parcela em aberto daqui para a frente.',
      dados: ref.watch(serieComprometimentoProvider),
      estaVazio: (serie) =>
          serie.isEmpty || serieVazia([for (final p in serie) p.valor]),
      aoRecarregar: () => ref.invalidate(parceladosDesdeProvider(inicio.valor)),
      legenda: (_) => [
        ItemLegenda(rotulo: 'Parcelas a pagar', cor: esquema.tertiary),
      ],
      rodape: (serie) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Total: ${formatarReais(serie.fold(0.0, (soma, p) => soma + p.valor))}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      construir: (serie) => _Linha(serie: serie),
    );
```

`context` aqui é o parâmetro `context` do `build(BuildContext context, WidgetRef ref)` de `LinhaComprometimento` — já está em escopo no método inteiro (é o mesmo `context` usado, por exemplo, se algo acima chamasse `Theme.of(context)`), não precisa de `Builder` nem de capturar de novo.

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `flutter test test/ui/graficos_linhas_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo o novo).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/graficos/linha_comprometimento.dart test/ui/graficos_linhas_test.dart
git commit -m "feat: mostra o total comprometido abaixo do grafico de comprometimento"
```

---

## Task 3: Remover a coluna de checkbox de `TabelaResponsiva`

**Files:**
- Modify: `lib/ui/widgets/tabela_responsiva.dart:114-166`
- Test: `test/ui/tabela_responsiva_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: nada consumido por outra task (independente das demais).

- [ ] **Step 1: Escrever o teste que falha**

Em `test/ui/tabela_responsiva_test.dart`, adicione (depois do teste `'o botao de excluir dispara aoExcluir no desktop'`):

```dart
  testWidgets('nao mostra checkbox de selecao mesmo com aoTocar',
      (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montar(duasLinhas(aoTocar: () {})));
    await tester.pump();

    expect(find.byType(Checkbox), findsNothing);
  });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/ui/tabela_responsiva_test.dart`
Expected: FAIL — `find.byType(Checkbox)` encontra pelo menos um `Checkbox` (o `DataTable` desenha a coluna de seleção por padrão quando alguma `DataRow` tem `onSelectChanged`).

- [ ] **Step 3: Implementar `showCheckboxColumn: false`**

Em `lib/ui/widgets/tabela_responsiva.dart`, método `_tabela()`, adicione o parâmetro no `DataTable`:

```dart
        child: DataTable(
          showCheckboxColumn: false,
          columns: [
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `flutter test test/ui/tabela_responsiva_test.dart`
Expected: PASS (todos os testes do arquivo, incluindo o novo — em particular `'tocar na linha dispara aoTocar no mobile'` e os testes de exclusão continuam passando, provando que `onSelectChanged`/toque na linha não dependem do checkbox).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/tabela_responsiva.dart test/ui/tabela_responsiva_test.dart
git commit -m "fix: remove checkbox de selecao das tabelas, sem funcao alguma"
```

---

## Task 4: Linha "Somatória total" em `TabelaResponsiva`

**Files:**
- Modify: `lib/ui/widgets/tabela_responsiva.dart` (classe inteira — novo campo, novo método no `DataTable`, novo item nos `cards`)
- Test: `test/ui/tabela_responsiva_test.dart`

**Interfaces:**
- Consumes: nada de tasks anteriores (independente).
- Produces: `TabelaResponsiva.agrupada({..., double? somatoriaGeral})` — Tasks 5 e 6 passam esse parâmetro a partir das telas de Gastos e Parcelas.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/tabela_responsiva_test.dart`, troque a assinatura de `montarAgrupada` para aceitar o novo parâmetro:

```dart
Widget montarAgrupada(
  List<GrupoResponsivo> grupos, {
  double? somatoriaGeral,
}) =>
    MaterialApp(
      home: Scaffold(
        body: TabelaResponsiva.agrupada(
          colunas: const ['Descricao', 'Valor'],
          grupos: grupos,
          somatoriaGeral: somatoriaGeral,
        ),
      ),
    );
```

Adicione este grupo novo no `main()`, depois do teste `'grupo com total mostra a linha de total no mobile'`:

```dart
  group('somatoria geral', () {
    testWidgets('mostra a linha ao final no desktop', (tester) async {
      await comLargura(tester, 1400);
      await tester.pumpWidget(montarAgrupada(
        [
          const GrupoResponsivo(
            titulo: 'Hoje',
            linhas: [
              LinhaResponsiva(
                  chave: ValueKey('l1'), valores: ['Aluguel', r'R$ 100,00']),
            ],
            total: 100,
          ),
        ],
        somatoriaGeral: 100,
      ));
      await tester.pump();

      // A linha de total do grupo ("Total: R$ 100,00") e a somatoria geral
      // ("Somatória total: R$ 100,00") coexistem, com textos diferentes.
      expect(find.text('Total: ${formatarReais(100)}'), findsOneWidget);
      expect(find.text('Somatória total: ${formatarReais(100)}'),
          findsOneWidget);
    });

    testWidgets('mostra a linha ao final no mobile', (tester) async {
      await comLargura(tester, 420);
      await tester.pumpWidget(montarAgrupada(
        [
          const GrupoResponsivo(
            titulo: 'Hoje',
            linhas: [
              LinhaResponsiva(
                  chave: ValueKey('l1'), valores: ['Aluguel', r'R$ 100,00']),
            ],
          ),
        ],
        somatoriaGeral: 100,
      ));
      await tester.pump();

      expect(find.text('Somatória total: ${formatarReais(100)}'),
          findsOneWidget);
    });

    testWidgets('nao aparece quando somatoriaGeral e nula', (tester) async {
      await comLargura(tester, 1400);
      await tester.pumpWidget(montarAgrupada([
        const GrupoResponsivo(
          titulo: 'Hoje',
          linhas: [
            LinhaResponsiva(
                chave: ValueKey('l1'), valores: ['Aluguel', r'R$ 100,00']),
          ],
        ),
      ]));
      await tester.pump();

      expect(find.textContaining('Somatória total'), findsNothing);
    });
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/ui/tabela_responsiva_test.dart`
Expected: FAIL — `somatoriaGeral` não existe em `TabelaResponsiva.agrupada` (erro de compilação).

- [ ] **Step 3: Implementar `somatoriaGeral` em `TabelaResponsiva`**

Em `lib/ui/widgets/tabela_responsiva.dart`:

1. Novo campo na classe, junto de `colunaDoTotal`:

```dart
  final int? colunaDoTotal;

  /// Soma de TODAS as linhas de TODOS os grupos, independente do
  /// agrupamento/ordenacao escolhido. `null` (o padrao) nao desenha nada —
  /// caso de quem ainda nao passa este campo, ou da lista simples (sem
  /// agrupamento).
  final double? somatoriaGeral;
```

2. Os dois construtores ganham o parâmetro nomeado opcional:

```dart
  TabelaResponsiva({
    super.key,
    required this.colunas,
    required List<LinhaResponsiva> linhas,
    this.vazio = 'Nada lançado neste mês.',
    this.somatoriaGeral,
  })  : grupos = [GrupoResponsivo(titulo: '', linhas: linhas)],
        colunaDoTotal = null,
        assert(
          linhas.isEmpty ||
              linhas.every((l) => l.valores.length == colunas.length),
          'Cada LinhaResponsiva precisa de um valor por coluna',
        );

  const TabelaResponsiva.agrupada({
    super.key,
    required this.colunas,
    required this.grupos,
    this.vazio = 'Nada lançado neste mês.',
    this.colunaDoTotal,
    this.somatoriaGeral,
  });
```

3. No `_tabela()`, adicione a linha final depois do loop dos grupos:

```dart
          rows: [
            for (final grupo in grupos) ...[
              if (grupo.titulo.isNotEmpty) _cabecalhoDeGrupo(grupo.titulo),
              for (final l in grupo.linhas)
                DataRow(
                key: l.chave,
                onSelectChanged:
                    l.aoTocar == null ? null : (_) => l.aoTocar!(),
                cells: [
                  for (final (i, v) in l.valores.indexed)
                    DataCell(
                      i == 0 && l.indicador != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v),
                                const SizedBox(height: 4),
                                SizedBox(width: 160, child: l.indicador),
                              ],
                            )
                          : Text(v),
                    ),
                  if (_temAcoes)
                    DataCell(
                      l.aoExcluir == null
                          ? const SizedBox.shrink()
                          : IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Excluir',
                              onPressed: l.aoExcluir,
                            ),
                    ),
                ],
                ),
              if (grupo.total != null)
                _rodapeDeGrupo(context, grupo.titulo, grupo.total!),
            ],
            if (somatoriaGeral != null) _somatoriaGeral(context, somatoriaGeral!),
          ],
```

(só a última linha, `if (somatoriaGeral != null) ...`, é nova — o resto do método `_tabela()` não muda.)

4. Novo método privado, logo depois de `_rodapeDeGrupo`:

```dart
  /// Linha de soma de TODA a tabela (todos os grupos), sempre a ultima.
  /// Mesmo truque de `_rodapeDeGrupo`, mas com fundo cinza bem escuro e
  /// texto branco -- precisa se destacar da linha de total por grupo (cinza
  /// claro), que ja existe acima dela quando ha agrupamento.
  DataRow _somatoriaGeral(BuildContext context, double total) {
    const estilo = TextStyle(fontWeight: FontWeight.bold, color: Colors.white);
    final totalDeQuantasCelulas = colunas.length + (_temAcoes ? 1 : 0);

    Widget celula(int i) {
      if (i == 0) {
        return Text(
          colunaDoTotal == null
              ? 'Somatória total: ${formatarReais(total)}'
              : 'Somatória total',
          style: estilo,
        );
      }
      if (colunaDoTotal != null && i == colunaDoTotal) {
        return Text(formatarReais(total), style: estilo);
      }
      return const SizedBox.shrink();
    }

    return DataRow(
      key: const ValueKey('somatoria_geral'),
      color: WidgetStatePropertyAll(Colors.grey.shade800),
      cells: [
        for (var i = 0; i < totalDeQuantasCelulas; i++) DataCell(celula(i)),
      ],
    );
  }
```

5. No `_cards()`, adicione o item final na lista `itens`:

```dart
  Widget _cards() {
    final itens = <Object>[
      for (final grupo in grupos) ...[
        if (grupo.titulo.isNotEmpty) grupo.titulo,
        ...grupo.linhas,
        if (grupo.total != null)
          _RodapeDeGrupo(titulo: grupo.titulo, total: grupo.total!),
      ],
      if (somatoriaGeral != null) _SomatoriaGeralCard(total: somatoriaGeral!),
    ];
```

E, dentro do `itemBuilder`, adicione o `if` de renderização (antes do `final l = item as LinhaResponsiva;` final):

```dart
        if (item is _SomatoriaGeralCard) {
          return Padding(
            key: const ValueKey('somatoria_geral'),
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Somatória total: ${formatarReais(item.total)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
              ),
            ),
          );
        }
```

6. Nova classe marcadora, ao lado de `_RodapeDeGrupo` no fim do arquivo:

```dart
/// Marcador interno de `_cards()`: identifica o item da lista plana que e a
/// somatoria geral da tabela inteira, sempre o ultimo item.
class _SomatoriaGeralCard {
  final double total;

  const _SomatoriaGeralCard({required this.total});
}
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/ui/tabela_responsiva_test.dart`
Expected: PASS (todos, incluindo os três novos do grupo `somatoria geral`).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/widgets/tabela_responsiva.dart test/ui/tabela_responsiva_test.dart
git commit -m "feat: TabelaResponsiva ganha linha de somatoria geral, cinza escuro e texto branco"
```

---

## Task 5: "Somatória total" na tela de Gastos

**Files:**
- Modify: `lib/ui/telas/tela_gastos.dart:77-125`
- Test: `test/ui/ordem_gastos_ui_test.dart`

**Interfaces:**
- Consumes: `TabelaResponsiva.agrupada({..., double? somatoriaGeral})` da Task 4.
- Produces: nada consumido por outra task.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/ui/ordem_gastos_ui_test.dart`, adicione este grupo novo no `main()`, depois do grupo `'totalizador por grupo'`:

```dart
  group('somatoria geral', () {
    testWidgets('soma todos os gastos, independente da ordenacao',
        (tester) async {
      await montar(tester, gastos: [
        gasto('Feira', 12),
        gasto('Padaria', 10),
      ]);

      // Os dois gastos (100 + 100, valor fixo do helper gasto()) somam 200.
      // colunaDoTotal (6) separa o rotulo do valor, como no total por
      // grupo.
      expect(find.text('Somatória total'), findsOneWidget);
      expect(find.text(formatarReais(200)), findsOneWidget);
    });

    testWidgets('continua aparecendo na ordem alfabetica, que nao tem total por grupo',
        (tester) async {
      await montar(tester, gastos: [
        gasto('Feira', 12),
        gasto('Padaria', 10),
      ]);

      await ordenarPor(tester, 'A–Z');

      expect(find.text('Somatória total'), findsOneWidget);
      expect(find.text(formatarReais(200)), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/ui/ordem_gastos_ui_test.dart`
Expected: FAIL — `find.text('Somatória total')` não encontra nada (`TelaGastos` ainda não passa `somatoriaGeral`).

- [ ] **Step 3: Passar `somatoriaGeral` em `TelaGastos`**

Em `lib/ui/telas/tela_gastos.dart`, método `_tabela()`, adicione o parâmetro à chamada de `TabelaResponsiva.agrupada`:

```dart
    return TabelaResponsiva.agrupada(
      colunas: const [
        'Descrição',
        'Data',
        'Pessoa',
        'Pote',
        'Cartão',
        'Parcela',
        'Valor',
      ],
      vazio: 'Nenhum gasto neste mês.',
      colunaDoTotal: 6,
      somatoriaGeral:
          grupos.expand((g) => g.itens).fold<double>(0.0, (soma, g) => soma + g.valor),
      grupos: [
```

(o resto do método — o `for (final grupo in grupos) ...` que monta `GrupoResponsivo` — não muda.)

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/ui/ordem_gastos_ui_test.dart`
Expected: PASS (todos, incluindo os dois novos do grupo `somatoria geral`).

Rode também a suíte completa da tela para garantir que nada quebrou:

Run: `flutter test test/ui/tela_gastos_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/telas/tela_gastos.dart test/ui/ordem_gastos_ui_test.dart
git commit -m "feat: soma geral de todos os gastos na tela de Gastos"
```

---

## Task 6: "Somatória total" na tela de Parcelas

**Files:**
- Modify: `lib/ui/telas/tela_parcelas.dart:68-113`
- Test: `test/ui/tela_parcelas_test.dart`

**Interfaces:**
- Consumes: `TabelaResponsiva.agrupada({..., double? somatoriaGeral})` da Task 4.
- Produces: nada consumido por outra task.

- [ ] **Step 1: Escrever o teste que falha**

Em `test/ui/tela_parcelas_test.dart`, adicione (depois do teste `'mostra o total do grupo somando o valor por mes de cada compra'`):

```dart
  testWidgets('mostra a somatoria geral de todas as compras parceladas',
      (tester) async {
    await montar(tester, (repo) async {
      await repo.adicionar(base: base('Geladeira'), quantidadeParcelas: 10);
      await repo.adicionar(base: base('Sofa'), quantidadeParcelas: 5);
    });

    // As duas compras usam base(), com a mesma data -> caem no mesmo grupo
    // (ver o teste "a ordem padrao..." acima). valorParcela de cada uma e
    // 100, soma geral = 200 -- igual ao total desse unico grupo, entao
    // formatarReais(200) aparece duas vezes (total do grupo + somatoria
    // geral), mas so uma tem o rotulo "Somatória total".
    expect(find.text('Somatória total'), findsOneWidget);
    expect(find.text(formatarReais(200)), findsNWidgets(2));
  });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/ui/tela_parcelas_test.dart`
Expected: FAIL — `find.text('Somatória total')` não encontra nada.

- [ ] **Step 3: Passar `somatoriaGeral` em `TelaParcelas`**

Em `lib/ui/telas/tela_parcelas.dart`, método `_tabela()`, adicione o parâmetro:

```dart
    return TabelaResponsiva.agrupada(
      colunas: const [
        'Compra',
        'Data',
        'Pessoa',
        'Pote',
        'Cartão',
        'Parcela',
        'Valor/mês',
        'Faltam',
      ],
      vazio: 'Nenhuma compra parcelada em aberto.',
      colunaDoTotal: 6,
      somatoriaGeral: grupos
          .expand((g) => g.itens)
          .fold<double>(0.0, (soma, c) => soma + c.valorParcela),
      grupos: [
```

(o resto do método não muda.)

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `flutter test test/ui/tela_parcelas_test.dart`
Expected: PASS (todos, incluindo o novo).

- [ ] **Step 5: Commit**

```bash
git add lib/ui/telas/tela_parcelas.dart test/ui/tela_parcelas_test.dart
git commit -m "feat: soma geral de todas as compras parceladas na tela de Parcelas"
```

---

## Task 7: Fixar o seletor Marcos/Silvia/Casal na tela de Gráficos

**Files:**
- Modify: `lib/ui/telas/tela_graficos.dart:21-49`
- Test: `test/ui/tela_graficos_test.dart`

**Interfaces:**
- Consumes: nada (independente das demais tasks).
- Produces: nada.

- [ ] **Step 1: Escrever o teste que falha**

Em `test/ui/tela_graficos_test.dart`, dentro do `group('seletor de visao', ...)`, adicione (depois do teste `'compartilha visaoProvider com a tela de Resumo'`):

```dart
    testWidgets('fica fora da area de rolagem dos graficos', (tester) async {
      await montar(tester, tamanho: const Size(1400, 700));

      final rolagem = find.byKey(const Key('graficos_rolagem'));
      final seletor = find.byKey(const Key('graficos_visao'));

      expect(seletor, findsOneWidget);
      expect(find.descendant(of: rolagem, matching: seletor), findsNothing);
    });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/ui/tela_graficos_test.dart`
Expected: FAIL — hoje `_SeletorVisao` é filho do `SingleChildScrollView` de key `graficos_rolagem`, então `find.descendant(...)` encontra o seletor.

- [ ] **Step 3: Reestruturar `TelaGraficos.build`**

Em `lib/ui/telas/tela_graficos.dart`, troque o `build`:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = MediaQuery.sizeOf(context).width >= breakpointDesktop;
    final membros = ref.watch(membrosProvider);

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
  }
```

(`_duasColunas()` e `_colunaUnica()` continuam exatamente iguais — só o que os envolve muda: antes era `SingleChildScrollView > Column [seletor, grade]`, agora é `Column [seletor, Expanded > SingleChildScrollView > grade]`, igual à estrutura de `TelaResumo.build`.)

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/ui/tela_graficos_test.dart`
Expected: PASS — incluindo o teste novo e os já existentes (`'rola sem estourar o layout'`, `'mostra os sete graficos'`, os de responsividade e os de erro), já que a key `graficos_rolagem` continua existindo, só mudou o que está dentro dela.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/telas/tela_graficos.dart test/ui/tela_graficos_test.dart
git commit -m "fix: fixa o seletor Marcos/Silvia/Casal no topo da tela de Graficos"
```

---

## Verificação final

- [ ] **Rodar a suíte inteira**

Run: `flutter test`
Expected: PASS em todos os arquivos, sem regressão em Resumo, Ganhos, Potes ou nos outros 6 gráficos.
