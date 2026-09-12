# Linhas no gráfico de cartão + totalizadores por grupo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adiciona linhas externas com o valor por cartão no gráfico "Gastos por cartão", e uma linha de total ao fim de cada grupo nas telas de Gastos e Parcelas quando agrupadas por Data, Pote ou Cartão.

**Architecture:** Duas mudanças independentes que reaproveitam infraestrutura existente. (1) `RoscaPorCartao` ganha um `CustomPainter` desenhado sobre o `PieChart`, que recalcula o ângulo de cada fatia com a mesma fórmula do fl_chart para desenhar uma linha + rótulo de valor por fora do anel. (2) `GrupoResponsivo` (usado por `TabelaResponsiva.agrupada`, consumido por `TelaGastos` e `TelaParcelas`) ganha um campo `total` opcional; quando presente, uma linha "Total: R$ X" aparece ao fim do grupo, tanto no `DataTable` (desktop) quanto nos cards (mobile).

**Tech Stack:** Flutter, fl_chart 1.2.0, flutter_riverpod, flutter_test.

## Global Constraints

- Manter a porcentagem já existente dentro de cada fatia do gráfico de cartão — só adiciona, não substitui.
- O ângulo de cada fatia deve ser calculado com `startDegreeOffset = 0`, sentido horário, soma cumulativa de `valor/total*360` — a mesma fórmula que `PieChartPainter` usa internamente, para a linha sempre apontar para a fatia certa.
- `RoscaPorPote`, `PizzaGanhos` e os demais gráficos da tela de Gráficos não são tocados.
- Total por grupo só aparece quando o grupo tem cabeçalho (`grupo.titulo.isNotEmpty`) — a ordem alfabética (lista corrida) não ganha total.
- Em Parcelas, o total soma `CompraParcelada.valorParcela` (não soma "Faltam", que não é monetário).
- Nenhum teste existente pode quebrar: os dois recursos são aditivos (widget novo no gráfico; campo novo opcional em `GrupoResponsivo`).

---

### Task 1: Linhas de valor por fatia em `RoscaPorCartao`

**Files:**
- Modify: `lib/ui/widgets/graficos/rosca_por_cartao.dart` (reescreve o arquivo inteiro)
- Test: `test/ui/graficos_por_cartao_test.dart` (adiciona um novo `group` no fim de `main()`)

**Interfaces:**
- Consumes: `Fatia` (`id`, `nome`, `cor`, `valor`) e `totalDasFatias(List<Fatia>)` de `lib/dominio/graficos.dart` (já existentes, não mudam). `corDeHex(String)` de `lib/ui/tema/tema.dart`. `formatarReais(double)` de `lib/ui/tema/formatadores.dart`.
- Produces: nenhuma API nova consumida por outro arquivo — `_Rosca` e `_LinhasDeChamada` continuam privados deste arquivo.

- [ ] **Step 1: Escrever os testes que ainda falham**

Adicione ao final de `test/ui/graficos_por_cartao_test.dart`, dentro do `group('rosca de gastos por cartao', ...)`, antes do `});` que fecha o grupo (depois do teste `'respeita a visao selecionada'`):

```dart
    testWidgets('cada fatia mostra o valor em reais fora do anel',
        (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', 'inter', 300),
      ]);

      expect(find.text(formatarReais(700)), findsOneWidget);
      expect(find.text(formatarReais(300)), findsOneWidget);
    });

    testWidgets('fatia orfa "Sem cartao" tambem ganha o rotulo de valor',
        (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 700),
        ('marcos', null, 50),
      ]);

      expect(find.text(formatarReais(50)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uma unica fatia (100%) nao lanca excecao', (tester) async {
      await montar(tester, gastosDoMes: [
        ('marcos', 'nubank', 500),
      ]);

      // O rotulo da fatia e o total central mostram o mesmo valor porque so
      // ha um cartao: as duas ocorrencias de "R$ 500,00" sao esperadas.
      expect(find.text(formatarReais(500)), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/ui/graficos_por_cartao_test.dart`
Expected: FAIL nos três testes novos — hoje nenhum valor em reais aparece fora do anel (só a porcentagem dentro da fatia e o total central), então `find.text(formatarReais(700))` etc. não encontram nada.

- [ ] **Step 3: Reescrever `lib/ui/widgets/graficos/rosca_por_cartao.dart`**

```dart
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../../tema/tema.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';

/// Gastos por cartao — grafico extra, fora da numeracao da spec 10.
///
/// Mesma linguagem visual da rosca de pote: furo central com o total, para
/// a pessoa nao precisar somar as fatias de cabeca. Cada fatia tambem ganha
/// uma linha externa com o valor em reais daquele cartao — a porcentagem
/// sozinha nao diz quanto foi gasto.
class RoscaPorCartao extends ConsumerWidget {
  const RoscaPorCartao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSelecionadoProvider).valor;

    return MolduraGrafico<List<Fatia>>(
      titulo: 'Gastos por cartão',
      vazio: 'Nenhum gasto neste mês.',
      // Anel menor que os outros graficos da tela (que usam o padrao de 240)
      // deixa espaco para a linha + valor de cada fatia sem cortar no card.
      altura: 260,
      dados: ref.watch(fatiasPorCartaoProvider),
      estaVazio: (f) => f.isEmpty,
      aoRecarregar: () {
        ref.invalidate(cartoesProvider);
        ref.invalidate(gastosDoMesProvider(mes));
      },
      legenda: (fatias) => [
        for (final f in fatias)
          ItemLegenda(rotulo: f.nome, cor: corDeHex(f.cor)),
      ],
      construir: (fatias) => _Rosca(fatias: fatias),
    );
  }
}

class _Rosca extends StatelessWidget {
  final List<Fatia> fatias;
  const _Rosca({required this.fatias});

  /// Anel menor que o da rosca de pote (52/46): sobra espaco no mesmo card
  /// para a linha + rotulo de valor de cada fatia.
  static const double raioInterno = 44;
  static const double raioFatia = 38;

  @override
  Widget build(BuildContext context) {
    final total = totalDasFatias(fatias);
    final corTexto =
        Theme.of(context).textTheme.bodySmall?.color ?? Colors.black87;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _LinhasDeChamada(
              fatias: fatias,
              total: total,
              corTexto: corTexto,
            ),
          ),
        ),
        PieChart(
          PieChartData(
            centerSpaceRadius: raioInterno,
            sectionsSpace: 2,
            sections: [
              for (final f in fatias)
                PieChartSectionData(
                  value: f.valor,
                  color: corDeHex(f.cor),
                  radius: raioFatia,
                  // O nome vai na legenda; repeti-lo na fatia embola o
                  // desenho quando ha varios cartoes.
                  title: _percentual(f.valor, total),
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total', style: Theme.of(context).textTheme.bodySmall),
            Text(
              formatarReais(total),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  /// Fatia menor que 5% nao recebe rotulo: o texto sairia maior que ela.
  String _percentual(double valor, double total) {
    if (total <= 0) return '';
    final pct = valor / total * 100;
    return pct < 5 ? '' : '${pct.toStringAsFixed(0)}%';
  }
}

/// Desenha, para cada fatia, uma linha saindo da borda do anel ate um
/// rotulo com o valor em reais — a porcentagem dentro da fatia nao diz
/// quanto foi gasto em cada cartao.
///
/// O angulo de cada fatia e recalculado aqui com a MESMA formula que o
/// PieChartPainter do fl_chart usa por baixo dos panos (soma cumulativa de
/// graus, comecando em 0 = eixo das 3 horas, sentido horario). `fatias` e a
/// mesma lista, na mesma ordem, usada para montar as `sections` do
/// PieChart logo acima — o angulo calculado aqui sempre bate com o que a
/// biblioteca desenha.
class _LinhasDeChamada extends CustomPainter {
  final List<Fatia> fatias;
  final double total;
  final Color corTexto;

  const _LinhasDeChamada({
    required this.fatias,
    required this.total,
    required this.corTexto,
  });

  static const double _raioAnel = _Rosca.raioInterno + _Rosca.raioFatia;
  static const double _raioLinha = _raioAnel + 12;
  static const double _raioRotulo = _raioLinha + 10;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final centro = size.center(Offset.zero);
    var acumulado = 0.0;

    for (final f in fatias) {
      final grausDaFatia = f.valor / total * 360;
      final anguloMedio = acumulado + grausDaFatia / 2;
      acumulado += grausDaFatia;
      if (f.valor <= 0) continue;

      final radianos = anguloMedio * math.pi / 180;
      final direcao = Offset(math.cos(radianos), math.sin(radianos));

      canvas.drawLine(
        centro + direcao * _raioAnel,
        centro + direcao * _raioLinha,
        Paint()
          ..color = corDeHex(f.cor)
          ..strokeWidth = 1.5,
      );

      final rotulo = TextPainter(
        text: TextSpan(
          text: formatarReais(f.valor),
          style: TextStyle(fontSize: 10, color: corTexto),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final centroDoRotulo = centro + direcao * _raioRotulo;
      rotulo.paint(
        canvas,
        centroDoRotulo - Offset(rotulo.width / 2, rotulo.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinhasDeChamada oldDelegate) =>
      oldDelegate.fatias != fatias ||
      oldDelegate.total != total ||
      oldDelegate.corTexto != corTexto;
}
```

Nota: `_raioAnel` referencia `_Rosca.raioInterno`/`_Rosca.raioFatia` — os dois `static const` ficaram públicos dentro da biblioteca (sem `_` no nome do campo, só a classe `_Rosca` é privada) justamente para o painter reaproveitar os mesmos números sem duplicar literais.

Nota: implementação final desviou disto — ver commits de correção. O rótulo com o valor em reais deixou de ser desenhado no `Canvas` via `TextPainter` (bloco acima) e passou a ser um `Text` widget separado, construído por `_Rosca._constroiRotulos` e posicionado com `Transform.translate` sobre a `Stack` — assim ele herda tema/estilo de texto normalmente e pode ser encontrado e testado como qualquer outro widget (`find.text(...)`), em vez de exigir asserções pixel a pixel sobre o canvas. `_LinhasDeChamada` ficou responsável só pelo traço da linha; `corTexto` foi removido de lá porque deixou de ter uso ali. Os raios (`raioAnel`/`raioLinha`/`raioRotulo`) também foram hoisted para `_Rosca` como fonte única, em vez de recalculados separadamente em cada lugar como no bloco acima.

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/ui/graficos_por_cartao_test.dart`
Expected: PASS — todos os testes do arquivo, incluindo os três novos e os que já existiam (total no centro, cores da paleta, legenda, "Sem cartão", visão selecionada).

- [ ] **Step 5: Rodar a suíte inteira, garantindo que nada mais quebrou**

Run: `flutter test test/ui/tela_graficos_test.dart`
Expected: PASS — esse arquivo só verifica que a lista de gráficos tem 7 itens; não deveria ser afetado, mas confirma que `RoscaPorCartao` ainda constrói sem erro dentro da tela inteira.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/widgets/graficos/rosca_por_cartao.dart test/ui/graficos_por_cartao_test.dart
git commit -m "feat: linhas com valor por cartao no grafico de gastos por cartao"
```

---

### Task 2: Campo `total` em `GrupoResponsivo` / `TabelaResponsiva`

**Files:**
- Modify: `lib/ui/widgets/tabela_responsiva.dart`
- Test: `test/ui/tabela_responsiva_test.dart`

**Interfaces:**
- Consumes: `formatarReais(double)` de `../tema/formatadores.dart` (novo import neste arquivo).
- Produces: `GrupoResponsivo({required titulo, required linhas, double? total})` — o campo `total` é opcional e por padrão `null` (comportamento atual preservado). Tasks 3 e 4 vão passar esse campo a partir de `tela_gastos.dart` e `tela_parcelas.dart`.

- [ ] **Step 1: Escrever os testes que ainda falham**

O arquivo `test/ui/tabela_responsiva_test.dart` termina assim:

```dart
  test('linha com numero de celulas diferente das colunas e rejeitada', () {
    expect(
      () => TabelaResponsiva(
        colunas: const ['A', 'B'],
        linhas: const [
          LinhaResponsiva(chave: ValueKey('x'), valores: ['so uma']),
        ],
      ),
      throwsAssertionError,
    );
  });
}
```

Primeiro, adicione uma nova função de nível superior, no mesmo estilo de
`montar` e `duasLinhas` já existentes no arquivo — logo depois de
`duasLinhas` e antes de `void main() {`:

```dart
Widget montarAgrupada(List<GrupoResponsivo> grupos) => MaterialApp(
      home: Scaffold(
        body: TabelaResponsiva.agrupada(
          colunas: const ['Descricao', 'Valor'],
          grupos: grupos,
        ),
      ),
    );
```

Depois, dentro de `main()`, insira os três testes novos depois do último
`test(...)` (o de "linha com numero de celulas diferente das colunas e
rejeitada") e antes do `}` que fecha `main()`:

```dart
  testWidgets('grupo com total mostra a linha de total no desktop',
      (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montarAgrupada([
      const GrupoResponsivo(
        titulo: 'Hoje',
        linhas: [
          LinhaResponsiva(
              chave: ValueKey('l1'), valores: ['Aluguel', r'R$ 100,00']),
        ],
        total: 100,
      ),
    ]));
    await tester.pump();

    expect(find.text('Total: R\$ 100,00'), findsOneWidget);
  });

  testWidgets('grupo sem total nao mostra linha extra', (tester) async {
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

    expect(find.textContaining('Total:'), findsNothing);
  });

  testWidgets('grupo com total mostra a linha de total no mobile',
      (tester) async {
    await comLargura(tester, 420);
    await tester.pumpWidget(montarAgrupada([
      const GrupoResponsivo(
        titulo: 'Hoje',
        linhas: [
          LinhaResponsiva(
              chave: ValueKey('l1'), valores: ['Aluguel', r'R$ 100,00']),
        ],
        total: 100,
      ),
    ]));
    await tester.pump();

    expect(find.text('Total: R\$ 100,00'), findsOneWidget);
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/ui/tabela_responsiva_test.dart`
Expected: FAIL nos três testes novos — o construtor `GrupoResponsivo` ainda não tem o parâmetro nomeado `total`, então o arquivo nem compila (erro do analisador, não falha de asserção).

- [ ] **Step 3: Adicionar o campo `total` e o novo import**

Em `lib/ui/widgets/tabela_responsiva.dart`, adicione o import logo depois do `import 'package:flutter/material.dart';` (linha 1):

```dart
import '../tema/formatadores.dart';
```

Substitua a classe `GrupoResponsivo` (linhas 31-36):

```dart
/// Um bloco de linhas sob um cabecalho. [titulo] vazio significa sem
/// cabecalho — o caso de uma lista simples, sem agrupamento.
class GrupoResponsivo {
  final String titulo;
  final List<LinhaResponsiva> linhas;

  /// Soma dos itens do grupo, para a linha de total ao final dele. `null`
  /// (o padrao) nao desenha linha nenhuma — e o caso de quem ainda nao
  /// passa este campo.
  final double? total;

  const GrupoResponsivo({
    required this.titulo,
    required this.linhas,
    this.total,
  });
}
```

- [ ] **Step 4: Desenhar a linha de total no `DataTable`**

Substitua o corpo de `rows:` dentro de `_tabela()` (linhas 104-140):

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
                _rodapeDeGrupo(grupo.titulo, grupo.total!),
            ],
          ],
```

Adicione um novo método logo depois de `_cabecalhoDeGrupo` (depois da linha 159 original):

```dart
  /// Linha de total ao fim de um grupo. Mesmo truque do cabecalho (texto na
  /// primeira celula, resto vazio), mas em italico em vez de negrito, para
  /// nao ser confundida com o titulo do grupo.
  DataRow _rodapeDeGrupo(String titulo, double total) => DataRow(
        key: ValueKey('rodape_$titulo'),
        cells: [
          DataCell(Text(
            'Total: ${formatarReais(total)}',
            style: const TextStyle(fontStyle: FontStyle.italic),
          )),
          for (var i = 1; i < colunas.length + (_temAcoes ? 1 : 0); i++)
            const DataCell(SizedBox.shrink()),
        ],
      );
```

- [ ] **Step 5: Desenhar a linha de total nos cards**

Substitua o método `_cards()` inteiro (linhas 161-221):

```dart
  Widget _cards() {
    // Uma lista plana onde cada item e um titulo (String), uma linha, ou o
    // rodape de total de um grupo.
    final itens = <Object>[
      for (final grupo in grupos) ...[
        if (grupo.titulo.isNotEmpty) grupo.titulo,
        ...grupo.linhas,
        if (grupo.total != null)
          _RodapeDeGrupo(titulo: grupo.titulo, total: grupo.total!),
      ],
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: itens.length,
      itemBuilder: (context, i) {
        final item = itens[i];
        if (item is String) {
          return Padding(
            key: ValueKey('grupo_$item'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              item,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          );
        }

        if (item is _RodapeDeGrupo) {
          return Padding(
            key: ValueKey('rodape_${item.titulo}'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ${formatarReais(item.total)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          );
        }

        final l = item as LinhaResponsiva;
        return Card(
          key: l.chave,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(l.valores.first),
            subtitle: l.valores.length > 1 || l.indicador != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (l.valores.length > 1)
                        Text(l.valores.skip(1).join(' · ')),
                      if (l.indicador != null) ...[
                        const SizedBox(height: 6),
                        l.indicador!,
                      ],
                    ],
                  )
                : null,
            onTap: l.aoTocar,
            trailing: l.aoExcluir == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Excluir',
                    onPressed: l.aoExcluir,
                  ),
          ),
        );
      },
    );
  }
```

E adicione, no fim do arquivo (depois do fechamento da classe `TabelaResponsiva`), a classe marcadora usada só pelo `_cards()`:

```dart
/// Marcador interno de `_cards()`: identifica o item da lista plana que e
/// o rodape de total de um grupo, em vez de titulo ou linha.
class _RodapeDeGrupo {
  final String titulo;
  final double total;

  const _RodapeDeGrupo({required this.titulo, required this.total});
}
```

- [ ] **Step 6: Rodar os testes e confirmar que passam**

Run: `flutter test test/ui/tabela_responsiva_test.dart`
Expected: PASS — os três testes novos e todos os que já existiam no arquivo (desktop/mobile, lista vazia, toques, exclusão, assert de linha torta).

- [ ] **Step 7: Commit**

```bash
git add lib/ui/widgets/tabela_responsiva.dart test/ui/tabela_responsiva_test.dart
git commit -m "feat: campo total em GrupoResponsivo, com linha de total no desktop e no mobile"
```

---

### Task 3: Total por grupo em Gastos (Data / Pote / Cartão)

**Files:**
- Modify: `lib/ui/telas/tela_gastos.dart`
- Test: `test/ui/ordem_gastos_ui_test.dart`

**Interfaces:**
- Consumes: `GrupoResponsivo({required titulo, required linhas, double? total})` da Task 2. `Gasto.valor` (`lib/dominio/models/gasto.dart`, já existe).
- Produces: nada consumido por outro arquivo.

- [ ] **Step 1: Escrever os testes que ainda falham**

Adicione o import de `formatarReais` no topo do arquivo (ainda não importado
neste arquivo), junto dos demais imports de `package:controle_financeiro/...`:

```dart
import 'package:controle_financeiro/ui/tema/formatadores.dart';
```

Nota: `formatarReais` usa `NumberFormat.currency` com locale `pt_BR`, que
insere um espaço **não quebrável** (NBSP, U+00A0) entre "R$" e o valor — não
um espaço comum. Um literal escrito à mão como `'Total: R$ 200,00'` (com
espaço comum) NÃO bate com o texto renderizado; use sempre
`'Total: ${formatarReais(valor)}'` para montar o texto esperado, nunca um
literal com o cifrão escrito à mão.

Adicione um novo `group` ao final de `test/ui/ordem_gastos_ui_test.dart`, antes do último `}` que fecha `main()`:

```dart
  group('totalizador por grupo', () {
    testWidgets('mostra o total do dia', (tester) async {
      await montar(tester, gastos: [
        gasto('Feira', 12),
        gasto('Padaria', 12),
      ]);

      // Os dois gastos (100 + 100, valor fixo do helper gasto()) caem no
      // mesmo dia -> total 200.
      expect(find.text('Total: ${formatarReais(200)}'), findsOneWidget);
    });

    testWidgets('mostra o total por pote', (tester) async {
      await montar(tester, gastos: [
        gasto('Aluguel', 12, poteId: 'p1'),
        gasto('Freezer', 10, poteId: 'p2'),
      ]);

      await ordenarPor(tester, 'Pote');

      // Um gasto de 100 em cada pote -> total 100 em cada um dos dois
      // grupos.
      expect(find.text('Total: ${formatarReais(100)}'), findsNWidgets(2));
    });

    testWidgets('nao mostra total na ordem alfabetica', (tester) async {
      await montar(tester, gastos: [gasto('Feira', 12)]);

      await ordenarPor(tester, 'A–Z');

      expect(find.textContaining('Total:'), findsNothing);
    });
  });
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/ui/ordem_gastos_ui_test.dart`
Expected: FAIL nos dois primeiros testes novos (nenhuma linha de total aparece ainda); o terceiro ("nao mostra total na ordem alfabetica") já passa hoje, mas sem sentido até os outros dois existirem — rode o arquivo inteiro mesmo assim para confirmar a régua antes da mudança.

- [ ] **Step 3: Passar o total em `_tabela()` de `tela_gastos.dart`**

Substitua o corpo de `grupos:` dentro de `_tabela()` (linhas 96-119 do arquivo atual):

```dart
      grupos: [
        for (final grupo in grupos)
          GrupoResponsivo(
            titulo: grupo.titulo,
            total: grupo.titulo.isEmpty
                ? null
                : grupo.itens.fold(0.0, (soma, g) => soma + g.valor),
            linhas: [
              for (final g in grupo.itens)
                LinhaResponsiva(
                  chave: ValueKey('gasto_${g.id}'),
                  valores: [
                    g.descricao,
                    formatarData(g.data),
                    nomeDoMembro(membros, g.membroId),
                    nomeDoPote(potes, g.poteId),
                    nomeDoCartao(cartoes, g.cartaoId),
                    g.rotuloParcela,
                    formatarReais(g.valor),
                  ],
                  aoTocar: () => abrirFormularioGasto(
                      context: context, ref: ref, existente: g),
                  aoExcluir: () => _excluir(context, ref, g),
                ),
            ],
          ),
      ],
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/ui/ordem_gastos_ui_test.dart`
Expected: PASS — os três testes do novo grupo, e todos os grupos que já existiam no arquivo (agrupamento por data, alfabetica, pote, cartao, seletor, mobile, filtro por cartao).

- [ ] **Step 5: Rodar a suíte inteira de Gastos, garantindo que nada mais quebrou**

Run: `flutter test test/ui/tela_gastos_test.dart test/ui/parcelas_filtros_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/telas/tela_gastos.dart test/ui/ordem_gastos_ui_test.dart
git commit -m "feat: total por grupo na tela de Gastos (Data, Pote e Cartao)"
```

---

### Task 4: Total por grupo em Parcelas (Data / Pote / Cartão)

**Files:**
- Modify: `lib/ui/telas/tela_parcelas.dart`
- Test: `test/ui/tela_parcelas_test.dart`

**Interfaces:**
- Consumes: `GrupoResponsivo({required titulo, required linhas, double? total})` da Task 2. `CompraParcelada.valorParcela` (`lib/dominio/parcelas.dart`, já existe).
- Produces: nada consumido por outro arquivo.

- [ ] **Step 1: Escrever o teste que ainda falha**

Adicione o import de `formatarReais` no topo do arquivo (ainda não importado
neste arquivo), junto dos demais imports de `package:controle_financeiro/...`:

```dart
import 'package:controle_financeiro/ui/tema/formatadores.dart';
```

Nota: `formatarReais` usa `NumberFormat.currency` com locale `pt_BR`, que
insere um espaço **não quebrável** (NBSP, U+00A0) entre "R$" e o valor — não
um espaço comum. Um literal escrito à mão como `'Total: R$ 200,00'` (com
espaço comum) NÃO bate com o texto renderizado; use sempre
`'Total: ${formatarReais(valor)}'` para montar o texto esperado, nunca um
literal com o cifrão escrito à mão.

Adicione ao final de `test/ui/tela_parcelas_test.dart`, depois do último `testWidgets(...)` e antes do `}` que fecha `main()`:

```dart
  testWidgets('mostra o total do grupo somando o valor por mes de cada compra',
      (tester) async {
    await montar(tester, (repo) async {
      await repo.adicionar(base: base('Geladeira'), quantidadeParcelas: 10);
      await repo.adicionar(base: base('Sofa'), quantidadeParcelas: 5);
    });

    // As duas compras usam base(), com a mesma data -> mesmo grupo (ver o
    // teste "a ordem padrao agora e por data de vencimento" acima, que já
    // documenta essa coincidencia). valorParcela de cada uma e 100 (o
    // valor de base()), total do grupo 200.
    expect(find.text('Total: ${formatarReais(200)}'), findsOneWidget);
  });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/ui/tela_parcelas_test.dart`
Expected: FAIL — nenhuma linha de total aparece ainda na tela de Parcelas.

- [ ] **Step 3: Passar o total em `_tabela()` de `tela_parcelas.dart`**

Substitua o corpo de `grupos:` dentro de `_tabela()` (linhas 86-108 do arquivo atual):

```dart
      grupos: [
        for (final grupo in grupos)
          GrupoResponsivo(
            titulo: grupo.titulo,
            total: grupo.titulo.isEmpty
                ? null
                : grupo.itens.fold(0.0, (soma, c) => soma + c.valorParcela),
            linhas: [
              for (final c in grupo.itens)
                LinhaResponsiva(
                  chave: ValueKey('compra_${c.compraId}'),
                  valores: [
                    c.descricao,
                    formatarData(c.data),
                    nomeDoMembro(membros, c.membroId),
                    nomeDoPote(potes, c.poteId),
                    nomeDoCartao(cartoes, c.cartaoId),
                    '${c.parcelaAtual}/${c.totalParcelas}',
                    formatarReais(c.valorParcela),
                    _restante(c),
                  ],
                ),
            ],
          ),
      ],
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `flutter test test/ui/tela_parcelas_test.dart`
Expected: PASS — o teste novo e todos os que já existiam (vazio, parcela atual/restantes, gasto simples não aparece, ordem por data, achado 5).

- [ ] **Step 5: Rodar a suíte inteira do projeto, garantindo que nada mais quebrou em lugar nenhum**

Run: `flutter test`
Expected: PASS em todos os arquivos de teste do projeto.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/telas/tela_parcelas.dart test/ui/tela_parcelas_test.dart
git commit -m "feat: total por grupo na tela de Parcelas (Data, Pote e Cartao)"
```
