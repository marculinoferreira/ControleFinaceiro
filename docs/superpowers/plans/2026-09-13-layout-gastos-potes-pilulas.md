# Layout de Gastos: faixa de potes + pílulas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar o spec `docs/superpowers/specs/2026-09-13-layout-gastos-potes-pilulas-design.md` — faixa de potes (ícone+nome) no topo de Gastos para criar um gasto já com o pote escolhido, e filtros/ordenação em pílulas compactas (compartilhados por Gastos e Parcelas).

**Architecture:** Um widget novo (`FaixaPotes`) e um redesign local de um widget já existente (`filtros_lancamentos.dart`, que ganha uma pílula compartilhada `_Pilula` usada tanto pelos filtros — com `PopupMenuButton` — quanto pelo `SeletorOrdem` — seleção direta). `TelaGastos` é o único ponto que amarra os três: remove o FAB, mostra a faixa, e passa o pote escolhido para o formulário via um novo parâmetro opcional.

**Tech Stack:** Flutter/Dart, flutter_riverpod, flutter_test.

## Global Constraints

- Todo texto de UI em português, vocabulário já usado no app ("Casal", "Todos", "Sem cartão").
- `formatarReais`/`nomeDoMembro`/`nomeDoPote`/`nomeDoCartao` (`lib/ui/tema/formatadores.dart`) continuam sendo a única forma de formatar/resolver nomes — não duplicar essa lógica.
- Rodar os testes do arquivo tocado depois de cada mudança: `flutter test <arquivo>`.
- **Desvio combinado com o usuário para esta rodada: NENHUM commit ao final de uma task.** Implementar, testar, deixar tudo no working tree sem `git add`/`git commit`. O usuário vai rodar o app (emulador Android + Windows) e só then aprovar o commit. Por isso os passos "Commit" do formato padrão de tasks foram removidos deste plano — não executar `git commit` em nenhum momento até receber sinal verde explícito.
- As `Key`s de hoje (`filtro_membro`, `filtro_cartao`, `filtro_pote`, `ordem_gastos`) são preservadas nos mesmos lugares da árvore de widgets (não dentro de um menu/overlay) para não quebrar os testes de integração existentes (`ordem_gastos_ui_test.dart`, `parcelas_filtros_test.dart`, `visao_entre_telas_test.dart`).

---

## Task 1: `FaixaPotes` (novo widget)

**Files:**
- Create: `lib/ui/widgets/faixa_potes.dart`
- Test: `test/ui/faixa_potes_test.dart`

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces: `IconData iconeDoPote(String chave)` e
  `FaixaPotes({required List<Pote> potes, required void Function(Pote) aoTocar, bool habilitado = true})`
  — Task 4 (`TelaGastos`) consome os dois.

- [ ] **Step 1: Escrever os testes que falham**

Crie `test/ui/faixa_potes_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/ui/widgets/faixa_potes.dart';

const potes = [
  Pote(id: 'p1', nome: 'Custo fixo', percentual: 60, ordem: 0,
      cor: '#2E7D32', icone: 'casa'),
  Pote(id: 'p2', nome: 'Conforto', percentual: 40, ordem: 1,
      cor: '#1565C0', icone: 'sofa'),
];

Widget montar({
  List<Pote> lista = potes,
  bool habilitado = true,
  void Function(Pote)? aoTocar,
}) =>
    MaterialApp(
      home: Scaffold(
        body: FaixaPotes(
          potes: lista,
          habilitado: habilitado,
          aoTocar: aoTocar ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('mostra um item por pote, com nome e icone', (tester) async {
    await tester.pumpWidget(montar());

    expect(find.text('Custo fixo'), findsOneWidget);
    expect(find.text('Conforto'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.weekend), findsOneWidget);
  });

  testWidgets('tocar num pote chama aoTocar com aquele pote', (tester) async {
    Pote? tocado;
    await tester.pumpWidget(montar(aoTocar: (p) => tocado = p));

    await tester.tap(find.text('Conforto'));
    await tester.pump();

    expect(tocado?.id, 'p2');
  });

  testWidgets('desabilitado nao chama aoTocar', (tester) async {
    var chamou = 0;
    await tester
        .pumpWidget(montar(habilitado: false, aoTocar: (_) => chamou++));

    await tester.tap(find.text('Custo fixo'));
    await tester.pump();

    expect(chamou, 0);
  });

  testWidgets('lista vazia nao desenha nada', (tester) async {
    await tester.pumpWidget(montar(lista: const []));

    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('icone desconhecido usa o fallback (carteira)', (tester) async {
    await tester.pumpWidget(montar(lista: const [
      Pote(id: 'p9', nome: 'Misterioso', percentual: 10, ordem: 0,
          cor: '#000000', icone: 'chave-nunca-vista'),
    ]));

    expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/ui/faixa_potes_test.dart`
Expected: FAIL — `package:controle_financeiro/ui/widgets/faixa_potes.dart` não existe (erro de importação).

- [ ] **Step 3: Implementar `FaixaPotes`**

Crie `lib/ui/widgets/faixa_potes.dart`:

```dart
import 'package:flutter/material.dart';

import '../../dominio/models/pote.dart';
import '../tema/tema.dart';

/// Mapa fixo chave->icone (spec 2026-09-13). `Pote.icone` e uma chave
/// textual que existe no modelo desde sempre mas nunca foi usada em nenhum
/// lugar da UI ate aqui -- qualquer chave fora da lista (inclusive o
/// fallback do proprio modelo, `'carteira'`) cai na carteira generica.
IconData iconeDoPote(String chave) => switch (chave) {
      'casa' => Icons.home,
      'sofa' => Icons.weekend,
      'grafico' => Icons.show_chart,
      'alvo' => Icons.track_changes,
      'presente' => Icons.card_giftcard,
      'livro' => Icons.menu_book,
      _ => Icons.account_balance_wallet,
    };

/// Faixa de atalhos pra "Novo gasto", um item por pote. Potes tem um teto
/// de 6 (ver `tela_potes_test.dart`, "nao passa de 6 potes"), entao cabem
/// numa linha so, sem precisar rolar.
///
/// Quando [habilitado] e false (a tela nao tem membro cadastrado pra
/// atribuir o gasto -- mesma condicao que desabilitava o FAB "Novo gasto"
/// antes dele ser substituido por esta faixa), os itens ficam visiveis,
/// so nao reagem ao toque.
class FaixaPotes extends StatelessWidget {
  final List<Pote> potes;
  final bool habilitado;
  final void Function(Pote pote) aoTocar;

  const FaixaPotes({
    super.key,
    required this.potes,
    required this.aoTocar,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    if (potes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          for (final pote in potes)
            Expanded(
              child: _ItemPote(
                pote: pote,
                habilitado: habilitado,
                aoTocar: () => aoTocar(pote),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemPote extends StatelessWidget {
  final Pote pote;
  final bool habilitado;
  final VoidCallback aoTocar;

  const _ItemPote({
    required this.pote,
    required this.habilitado,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: habilitado ? 1 : 0.4,
      child: InkWell(
        onTap: habilitado ? aoTocar : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconeDoPote(pote.icone), color: corDeHex(pote.cor)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(pote.nome, maxLines: 1, softWrap: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/ui/faixa_potes_test.dart`
Expected: PASS (5 testes).

---

## Task 2: Pílula compartilhada + `FiltrosLancamentos`/`SeletorOrdem` redesenhados

**Files:**
- Modify: `lib/ui/widgets/filtros_lancamentos.dart` (reescrita completa)
- Test: `test/ui/filtros_lancamentos_test.dart` (novo — hoje só existe
  cobertura indireta, através de `ordem_gastos_ui_test.dart` e
  `parcelas_filtros_test.dart`)

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces: `SeletorOrdem` e `FiltrosLancamentos({required membros, required potes, required cartoes})`
  sem mudança de assinatura pública — Task 4 continua chamando os dois exatamente como `tela_gastos.dart` já faz hoje.

- [ ] **Step 1: Escrever os testes que falham**

Crie `test/ui/filtros_lancamentos_test.dart`. Os três providers usados
(`visaoProvider`, `filtroPoteProvider`, `filtroCartaoProvider`,
`ordemGastosProvider`) não dependem de repositório algum — um
`ProviderScope` comum basta, sem `RepositorioXFake`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/cartao.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/dominio/ordem_gastos.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/widgets/filtros_lancamentos.dart';

const membros = [
  Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
      cor: '#2E7D32', ordem: 0),
  Membro(id: 'silvia', nome: 'Silvia', email: 's@x.com',
      cor: '#6A1B9A', ordem: 1),
];

const potes = [
  Pote(id: 'p1', nome: 'Custo fixo', percentual: 60, ordem: 0,
      cor: '#2E7D32', icone: 'casa'),
  Pote(id: 'p2', nome: 'Conforto', percentual: 40, ordem: 1,
      cor: '#1565C0', icone: 'sofa'),
];

const cartoes = [
  Cartao(id: 'ct1', nome: 'Nubank', ordem: 0),
];

Widget montarFiltros() => const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: FiltrosLancamentos(
            membros: membros,
            potes: potes,
            cartoes: cartoes,
          ),
        ),
      ),
    );

void main() {
  group('FiltrosLancamentos', () {
    testWidgets('as tres pilulas aparecem numa linha so', (tester) async {
      await tester.pumpWidget(montarFiltros());

      expect(find.byKey(const Key('filtro_membro')), findsOneWidget);
      expect(find.byKey(const Key('filtro_cartao')), findsOneWidget);
      expect(find.byKey(const Key('filtro_pote')), findsOneWidget);
      // Sem o breakpoint de empilhar em duas linhas que existia antes.
      expect(find.byType(LayoutBuilder), findsNothing);
    });

    testWidgets('comeca em Casal/Todos/Todos', (tester) async {
      await tester.pumpWidget(montarFiltros());

      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_membro')),
              matching: find.text('Casal')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_cartao')),
              matching: find.text('Todos')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_pote')),
              matching: find.text('Todos')),
          findsOneWidget);
    });

    testWidgets(
        'cada pilula tem um icone proprio, pra distinguir Cartao de Pote quando os dois dizem "Todos"',
        (tester) async {
      await tester.pumpWidget(montarFiltros());

      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_membro')),
              matching: find.byIcon(Icons.person_outline)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_cartao')),
              matching: find.byIcon(Icons.credit_card)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_pote')),
              matching: find.byIcon(Icons.pie_chart_outline)),
          findsOneWidget);
    });

    testWidgets('tocar na pilula Pessoa abre um menu com as opcoes',
        (tester) async {
      await tester.pumpWidget(montarFiltros());

      await tester.tap(find.byKey(const Key('filtro_membro')));
      await tester.pumpAndSettle();

      expect(find.text('Marcos'), findsWidgets);
      expect(find.text('Silvia'), findsWidgets);
    });

    testWidgets('escolher no menu da pilula Pessoa muda o provider e o rotulo',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FiltrosLancamentos(
              membros: membros,
              potes: potes,
              cartoes: cartoes,
            ),
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('filtro_membro')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcos').last);
      await tester.pumpAndSettle();

      expect(container.read(visaoProvider), 'marcos');
      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_membro')),
              matching: find.text('Marcos')),
          findsOneWidget);
    });

    testWidgets('pilula Cartao mostra "Sem cartão" quando selecionado',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(filtroCartaoProvider.notifier).selecionar('');
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FiltrosLancamentos(
              membros: membros,
              potes: potes,
              cartoes: cartoes,
            ),
          ),
        ),
      ));

      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_cartao')),
              matching: find.text('Sem cartão')),
          findsOneWidget);
    });
  });

  group('SeletorOrdem', () {
    Widget montarOrdem() => const ProviderScope(
          child: MaterialApp(home: Scaffold(body: SeletorOrdem())),
        );

    testWidgets('mostra as quatro pilulas de ordenacao', (tester) async {
      await tester.pumpWidget(montarOrdem());

      final seletor = find.byKey(const Key('ordem_gastos'));
      for (final rotulo in ['Data', 'A–Z', 'Pote', 'Cartão']) {
        expect(find.descendant(of: seletor, matching: find.text(rotulo)),
            findsOneWidget,
            reason: 'faltou $rotulo');
      }
      expect(find.byType(SegmentedButton<OrdemGastos>), findsNothing);
      expect(find.text('Ordenar por'), findsOneWidget);
    });

    testWidgets('tocar numa pilula troca o provider direto, sem menu',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SeletorOrdem())),
      ));

      await tester.tap(find.descendant(
        of: find.byKey(const Key('ordem_gastos')),
        matching: find.text('A–Z'),
      ));
      await tester.pump();

      expect(container.read(ordemGastosProvider), OrdemGastos.alfabetica);
    });
  });
}
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/ui/filtros_lancamentos_test.dart`
Expected: FAIL — hoje `FiltrosLancamentos` usa `DropdownButtonFormField`
(sem `PopupMenuButton`/menu) e `SeletorOrdem` usa `SegmentedButton` (o
teste `expect(find.byType(SegmentedButton<OrdemGastos>), findsNothing)`
falha, entre outros).

- [ ] **Step 3: Reescrever `lib/ui/widgets/filtros_lancamentos.dart`**

Substitua o arquivo inteiro por:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/cartao.dart';
import '../../dominio/models/membro.dart';
import '../../dominio/models/pote.dart';
import '../../dominio/ordem_gastos.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';

/// Capsula compartilhada por SeletorOrdem e FiltrosLancamentos: borda
/// arredondada, texto que encolhe com FittedBox pra caber em qualquer
/// largura. [destacada] pinta o fundo -- usada só pela opção de ordenação
/// ativa; os filtros nunca ficam destacados, só mostram o valor atual.
/// [aoTocar] fica nulo quando a pílula é o `child` de um `PopupMenuButton`
/// (os filtros): quem abre o menu é o botão por fora, não a pílula.
///
/// [iconeInicial] identifica QUAL filtro é a pílula (Pessoa/Cartão/Pote) --
/// sem rótulo flutuante (como o dropdown antigo tinha), duas pílulas de
/// filtro sem seleção mostram o mesmo texto ("Todos"); o ícone inicial é o
/// único jeito de diferenciar Cartão de Pote nesse estado. O `SeletorOrdem`
/// não usa esse campo (cada pílula já É a própria opção, não precisa dizer
/// "isto é um filtro de X").
class _Pilula extends StatelessWidget {
  final String rotulo;
  final IconData? iconeInicial;
  final IconData? iconeFinal;
  final bool destacada;
  final VoidCallback? aoTocar;

  const _Pilula({
    required this.rotulo,
    this.iconeInicial,
    this.iconeFinal,
    this.destacada = false,
    this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final corTexto =
        destacada ? esquema.onPrimaryContainer : esquema.onSurfaceVariant;

    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: destacada ? esquema.primaryContainer : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: esquema.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconeInicial != null) ...[
              Icon(iconeInicial, size: 16, color: corTexto),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(rotulo, style: TextStyle(color: corTexto)),
              ),
            ),
            if (iconeFinal != null) ...[
              const SizedBox(width: 2),
              Icon(iconeFinal, size: 18, color: corTexto),
            ],
          ],
        ),
      ),
    );
  }
}

/// As quatro ordenacoes da lista. Fica separado dos filtros de proposito: um
/// filtro tira linhas da tela, uma ordenacao so as reorganiza.
///
/// Compartilhado por Gastos e Parcelas, e ligado no mesmo provider: quem
/// escolheu "por cartao" numa tela quer o mesmo criterio na outra.
class SeletorOrdem extends ConsumerWidget {
  const SeletorOrdem({super.key});

  static const _rotulos = {
    OrdemGastos.data: 'Data',
    OrdemGastos.alfabetica: 'A–Z',
    OrdemGastos.pote: 'Pote',
    OrdemGastos.cartao: 'Cartão',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordem = ref.watch(ordemGastosProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              'Ordenar por',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              key: const Key('ordem_gastos'),
              children: [
                for (final entrada in _rotulos.entries) ...[
                  if (entrada.key != _rotulos.keys.first)
                    const SizedBox(width: 6),
                  Expanded(
                    child: _Pilula(
                      rotulo: entrada.value,
                      destacada: ordem == entrada.key,
                      aoTocar: () => ref
                          .read(ordemGastosProvider.notifier)
                          .selecionar(entrada.key),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FiltrosLancamentos extends ConsumerWidget {
  final List<Membro> membros;
  final List<Pote> potes;
  final List<Cartao> cartoes;

  const FiltrosLancamentos({
    super.key,
    required this.membros,
    required this.potes,
    required this.cartoes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membroId = ref.watch(visaoProvider);
    final poteId = ref.watch(filtroPoteProvider);
    final cartaoId = ref.watch(filtroCartaoProvider);

    // Coage para null quando o filtro aponta para um id que sumiu da lista
    // (a outra pessoa apagou o membro/pote/cartao enquanto esta aba estava
    // aberta): sem isso a pilula mostraria o id cru em vez de um rotulo.
    final membroValido =
        membroId == null || membros.any((m) => m.id == membroId)
            ? membroId
            : null;
    final poteValido = poteId == null || potes.any((p) => p.id == poteId)
        ? poteId
        : null;
    final cartaoValido = cartaoId == null ||
            cartaoId.isEmpty ||
            cartoes.any((c) => c.id == cartaoId)
        ? cartaoId
        : null;

    final pessoa = _pilulaFiltro<String?>(
      chave: const Key('filtro_membro'),
      icone: Icons.person_outline,
      rotulo:
          membroValido == null ? 'Casal' : nomeDoMembro(membros, membroValido),
      itens: [
        (null, 'Casal'),
        for (final m in membros) (m.id, m.nome),
      ],
      aoSelecionar: (v) => ref.read(visaoProvider.notifier).selecionar(v),
    );

    final cartao = _pilulaFiltro<String?>(
      chave: const Key('filtro_cartao'),
      icone: Icons.credit_card,
      rotulo: cartaoValido == null
          ? 'Todos'
          : (cartaoValido.isEmpty
              ? 'Sem cartão'
              : nomeDoCartao(cartoes, cartaoValido)),
      itens: [
        (null, 'Todos'),
        ('', 'Sem cartão'),
        for (final c in cartoes) (c.id, c.nome),
      ],
      aoSelecionar: (v) =>
          ref.read(filtroCartaoProvider.notifier).selecionar(v),
    );

    final pote = _pilulaFiltro<String?>(
      chave: const Key('filtro_pote'),
      icone: Icons.pie_chart_outline,
      rotulo: poteValido == null ? 'Todos' : nomeDoPote(potes, poteValido),
      itens: [
        (null, 'Todos'),
        for (final p in potes) (p.id, p.nome),
      ],
      aoSelecionar: (v) => ref.read(filtroPoteProvider.notifier).selecionar(v),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(child: pessoa),
          const SizedBox(width: 8),
          Expanded(child: cartao),
          const SizedBox(width: 8),
          Expanded(child: pote),
        ],
      ),
    );
  }

  /// Pilula que abre um menu suspenso ancorado nela mesma. [itens] e uma
  /// lista de (valor, rotulo) -- generico em T porque os tres filtros
  /// (Pessoa, Cartao, Pote) usam o mesmo tipo (`String?`, inclusive a
  /// string vazia sentinela de "Sem cartao"). [icone] identifica qual
  /// filtro e (ver o comentario de `_Pilula.iconeInicial`).
  Widget _pilulaFiltro<T>({
    required Key chave,
    required IconData icone,
    required String rotulo,
    required List<(T, String)> itens,
    required ValueChanged<T> aoSelecionar,
  }) {
    return PopupMenuButton<T>(
      key: chave,
      tooltip: '',
      itemBuilder: (context) => [
        for (final (valor, texto) in itens)
          PopupMenuItem(value: valor, child: Text(texto)),
      ],
      onSelected: aoSelecionar,
      child: _Pilula(
        rotulo: rotulo,
        iconeInicial: icone,
        iconeFinal: Icons.arrow_drop_down,
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/ui/filtros_lancamentos_test.dart`
Expected: PASS (9 testes).

- [ ] **Step 5: Rodar a suíte de integração que já existia, confirmando que nada quebrou**

Run: `flutter test test/ui/ordem_gastos_ui_test.dart test/ui/parcelas_filtros_test.dart test/ui/visao_entre_telas_test.dart`
Expected: PASS em tudo — as `Key`s e o padrão `tap(key) → tap(text)` não
mudaram, só a aparência por trás delas. Se algum teste falhar por depender
de `DropdownButtonFormField`/`SegmentedButton` especificamente, ajuste esse
teste para checar por `Key`+texto em vez do widget interno (sem mudar o
comportamento que ele verifica).

---

## Task 3: `poteIdInicial` em `abrirFormularioGasto`/`FormularioGasto`

**Files:**
- Modify: `lib/ui/telas/formulario_gasto.dart:38-47` (assinatura de
  `abrirFormularioGasto`) e a região de `_formulario` que resolve `_poteId`
  (hoje `_poteId ??= potes.isEmpty ? null : potes.first.id;`)
- Modify: `test/ui/formulario_gasto_test.dart` (helper `montar`)

**Interfaces:**
- Consumes: nada de tasks anteriores.
- Produces: `abrirFormularioGasto({..., String? poteIdInicial})` — Task 4
  (`TelaGastos`) passa esse parâmetro quando abre a partir de um toque na
  `FaixaPotes`.

- [ ] **Step 1: Escrever o teste que falha**

Em `test/ui/formulario_gasto_test.dart`, troque a assinatura do helper
`montar` para aceitar o novo parâmetro e repassá-lo:

```dart
Future<RepositorioGastosFake> montar(
  WidgetTester tester, {
  Gasto? existente,
  RepositorioGastosFake? comRepo,
  MesRef mes = const MesRef(2026, 8),
  String? poteIdInicial,
}) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = comRepo ?? RepositorioGastosFake();
  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake(cartoes)),
    repositorioGastosProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(mes);
  container.listen(potesProvider, (_, _) {});
  container.listen(casaProvider, (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('abrir_formulario'),
              onPressed: () => abrirFormularioGasto(
                context: context,
                ref: ref,
                existente: existente,
                poteIdInicial: poteIdInicial,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('abrir_formulario')));
  await tester.pumpAndSettle();

  return repo;
}
```

Adicione este grupo novo no `main()`:

```dart
  group('pote pre-selecionado', () {
    testWidgets('poteIdInicial preenche o pote do formulario novo',
        (tester) async {
      final repo = RepositorioGastosFake();
      await montar(tester, comRepo: repo, poteIdInicial: 'p2');

      // Mesmo padrao de "editar mostra o cartao gravado": confere o valor
      // exibido no dropdown fechado, sem precisar salvar.
      expect(find.text('Conforto'), findsWidgets);

      await tester.enterText(
          find.byKey(const Key('gasto_descricao')), 'Sofa novo');
      await tester.enterText(find.byKey(const Key('gasto_valor')), '50000');
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.single.poteId, 'p2');
    });

    testWidgets('poteIdInicial apontando pra pote que nao existe mais cai no primeiro',
        (tester) async {
      final repo = RepositorioGastosFake();
      await montar(tester, comRepo: repo, poteIdInicial: 'fantasma');

      await tester.enterText(
          find.byKey(const Key('gasto_descricao')), 'Aluguel');
      await tester.enterText(find.byKey(const Key('gasto_valor')), '100000');
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      // potes[0] no helper de teste e 'p1' (Custo fixo).
      expect(repo.todos.single.poteId, 'p1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('sem poteIdInicial continua caindo no primeiro pote, como hoje',
        (tester) async {
      final repo = RepositorioGastosFake();
      await montar(tester, comRepo: repo);

      await tester.enterText(
          find.byKey(const Key('gasto_descricao')), 'Feira');
      await tester.enterText(find.byKey(const Key('gasto_valor')), '10000');
      await tester.tap(find.byKey(const Key('gasto_salvar')));
      await tester.pumpAndSettle();

      expect(repo.todos.single.poteId, 'p1');
    });
  });
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `flutter test test/ui/formulario_gasto_test.dart`
Expected: FAIL — `poteIdInicial` não existe em `abrirFormularioGasto`
(erro de compilação).

- [ ] **Step 3: Implementar `poteIdInicial`**

Em `lib/ui/telas/formulario_gasto.dart`:

```dart
Future<void> abrirFormularioGasto({
  required BuildContext context,
  required WidgetRef ref,
  Gasto? existente,
  String? poteIdInicial,
}) async {
  final resultado = await mostrarFormulario<_ResultadoFormularioGasto>(
    context: context,
    titulo: existente == null ? 'Novo gasto' : 'Editar gasto',
    construir: (c) => FormularioGasto(
      existente: existente,
      poteIdInicial: poteIdInicial,
    ),
  );
  if (resultado == null) return;
  // ... resto do corpo sem mudanca
```

```dart
class FormularioGasto extends ConsumerStatefulWidget {
  final Gasto? existente;
  final String? poteIdInicial;
  const FormularioGasto({super.key, this.existente, this.poteIdInicial});
  // ... resto sem mudanca
```

E na região de `_formulario` que resolve o pote (troque só essa linha):

```dart
    // Se o pote apontado nao existe mais (foi apagado enquanto o formulario
    // estava aberto, ou o lancamento editado aponta para um pote ja
    // removido), reseta em vez de manter um id orfao...
    if (_poteId != null && !potes.any((p) => p.id == _poteId)) {
      _poteId = null;
    }
    // poteIdInicial (a faixa de potes de Gastos) so vale se ainda existir
    // na lista -- mesma cautela do pote de um lancamento existente, acima.
    _poteId ??= (widget.poteIdInicial != null &&
            potes.any((p) => p.id == widget.poteIdInicial))
        ? widget.poteIdInicial
        : (potes.isEmpty ? null : potes.first.id);
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `flutter test test/ui/formulario_gasto_test.dart`
Expected: PASS (todos, incluindo os três novos do grupo `pote
pre-selecionado`).

---

## Task 4: `TelaGastos` — remove o FAB, integra `FaixaPotes`

**Files:**
- Modify: `lib/ui/telas/tela_gastos.dart`
- Test: `test/ui/tela_gastos_test.dart`

**Interfaces:**
- Consumes: `FaixaPotes({required potes, required aoTocar, bool habilitado})`
  (Task 1); `abrirFormularioGasto({..., String? poteIdInicial})` (Task 3).
- Produces: nada consumido por outra task.

- [ ] **Step 1: Escrever o teste que falha**

Em `test/ui/tela_gastos_test.dart`, **substitua** o teste
`'FAB de novo gasto fica desabilitado sem membros cadastrados'` (ele testa
um widget que deixa de existir) por:

```dart
  testWidgets('faixa de potes fica desabilitada sem membros cadastrados',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const casaSemMembros = Casa(id: 'principal', nome: 'Casa', membros: []);
    final repo = RepositorioGastosFake();
    final container = ProviderContainer(overrides: [
      repositorioCasaProvider
          .overrideWithValue(RepositorioCasaFake(casaSemMembros)),
      repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
      repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
      repositorioGastosProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container
        .read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TelaGastos()),
    ));
    await tester.pumpAndSettle();

    // Os potes de teste ('Custo fixo', 'Conforto') continuam visiveis, so
    // nao abrem o formulario.
    await tester.tap(find.text('Custo fixo'));
    await tester.pumpAndSettle();

    expect(find.text('Novo gasto'), findsNothing);
  });

  testWidgets('tocar num pote da faixa abre Novo gasto com aquele pote',
      (tester) async {
    final (_, repo) = await montar(tester);

    await tester.tap(find.text('Conforto'));
    await tester.pumpAndSettle();

    expect(find.text('Novo gasto'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('gasto_descricao')), 'Sofa');
    await tester.enterText(find.byKey(const Key('gasto_valor')), '50000');
    await tester.tap(find.byKey(const Key('gasto_salvar')));
    await tester.pumpAndSettle();

    expect(repo.todos.single.poteId, 'p2');
  });
```

(O helper `montar` de `tela_gastos_test.dart` já registra `potes` com `p1`
"Custo fixo" e `p2` "Conforto" — ver o topo do arquivo.)

- [ ] **Step 2: Rodar os testes e confirmar que falham**

Run: `flutter test test/ui/tela_gastos_test.dart`
Expected: FAIL — `find.byKey(const Key('novo_gasto'))` não existe mais
(teste antigo removido, mas os dois novos falham porque a `FaixaPotes`
ainda não está na tela: `find.text('Custo fixo')` retorna vazio).

- [ ] **Step 3: Integrar `FaixaPotes` em `TelaGastos`**

Em `lib/ui/telas/tela_gastos.dart`, adicione o import e remova o FAB:

```dart
import '../widgets/dialogo_exclusao.dart';
import '../widgets/faixa_potes.dart';
import '../widgets/filtros_lancamentos.dart';
```

```dart
    return Scaffold(
      body: combinado.when(
        loading: () => const CarregandoLista(),
        error: (e, _) => ErroComRecarregar(
          erro: e,
          aoRecarregar: () {
            ref.invalidate(potesProvider);
            ref.invalidate(cartoesProvider);
            ref.invalidate(gastosDoMesProvider(mesRef));
          },
        ),
        data: (trio) {
          final (potes, cartoes, grupos) = trio;
          return Column(
            children: [
              FaixaPotes(
                potes: potes,
                habilitado: membros.isNotEmpty,
                aoTocar: (pote) => abrirFormularioGasto(
                  context: context,
                  ref: ref,
                  poteIdInicial: pote.id,
                ),
              ),
              FiltrosLancamentos(
                  membros: membros, potes: potes, cartoes: cartoes),
              const SeletorOrdem(),
              const Divider(height: 1),
              Expanded(
                child:
                    _tabela(context, ref, grupos, membros, potes, cartoes),
              ),
            ],
          );
        },
      ),
    );
```

(Removido: `floatingActionButton: FloatingActionButton.extended(key:
const Key('novo_gasto'), ...)` inteiro.)

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `flutter test test/ui/tela_gastos_test.dart`
Expected: PASS (todos, incluindo os dois novos e sem o teste antigo do
FAB).

- [ ] **Step 5: Rodar `flutter analyze` e a suíte inteira**

Run: `flutter analyze`
Expected: nenhum aviso (em particular, nada de import não usado —
confirme que `Icons.add`/`FloatingActionButton` não ficaram órfãos em
`tela_gastos.dart`).

Run: `flutter test`
Expected: PASS em tudo — nenhuma outra tela usa `FiltrosLancamentos`/
`SeletorOrdem`/`abrirFormularioGasto` de um jeito que dependa do que foi
removido aqui.

---

## Verificação final (sem commit)

- [ ] `flutter test` — suíte inteira verde.
- [ ] `flutter analyze` — zero problemas.
- [ ] `flutter build apk --release` e `flutter build windows --release`.
- [ ] Instalar o APK no emulador Android (`flutter install -d <id>` ou
  `adb install -r`) e abrir o app.
- [ ] Abrir `build\windows\x64\runner\Release\controle_financeiro.exe`.
- [ ] Aguardar o usuário revisar visualmente as duas plataformas antes de
  qualquer `git add`/`git commit`.
