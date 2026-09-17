import 'package:flutter/material.dart';

import '../tema/formatadores.dart';
import '../shell.dart' show breakpointDesktop;

/// Uma linha da tabela. [valores] tem um item por coluna; no mobile o
/// primeiro vira titulo do card e os demais formam o subtitulo.
class LinhaResponsiva {
  final LocalKey chave;
  final List<String> valores;
  final VoidCallback? aoTocar;

  /// Exclui a linha. Devolve `Future<void>` (nao `VoidCallback`) porque o
  /// card do mobile precisa esperar essa chamada terminar antes de decidir
  /// se a linha volta pro lugar (ver `Dismissible.confirmDismiss` em
  /// `_cards()`) -- a confirmacao e a escrita ja acontecem dentro dela.
  final Future<void> Function()? aoExcluir;

  /// Widget opcional colado ao primeiro valor -- uma barra de progresso, por
  /// exemplo. Aparece nas duas formas: sob o primeiro valor no DataTable e
  /// sob o titulo no card. Existe porque o Resumo dos Potes precisa de uma
  /// barra por linha, e uma tela nao pode repetir a decisao de largura so
  /// para conseguir desenhar isso.
  final Widget? indicador;

  /// Icone opcional antes do nome, no card do mobile (ex.: o icone do pote
  /// do gasto, na cor do proprio pote). `null` (o padrao) nao desenha nada
  /// -- so quem passar os dois campos ganha o icone.
  final IconData? iconePrincipal;
  final Color? corIconePrincipal;

  /// Subtitulo pronto do card (mobile), no lugar do auto-gerado (que so
  /// junta `valores[1..]` com " · "). `null` (o padrao) mantem o
  /// comportamento antigo -- so quem passar isso monta o proprio layout
  /// (ex.: Gastos/Parcelas juntando pessoa | pote | cartao com "|", em vez
  /// do "junta tudo com · " generico).
  final Widget? subtitulo;

  /// Valor em destaque no canto direito do card (mobile) -- ex.: o valor do
  /// gasto, formatado. `null` (o padrao) nao desenha nada; o valor
  /// continua dentro do subtitulo auto-gerado, como sempre foi.
  final String? valorDestacado;

  /// Acao extra no canto direito da linha (ex.: o icone de calendario dos
  /// Cartoes, pra editar o dia de fechamento sem abrir o dialogo inteiro).
  /// Diferente de [aoExcluir] (que vira o gesto de arrastar no mobile),
  /// esta aparece como um botao visivel de verdade, nas duas formas
  /// (DataTable e card).
  final Widget? acaoTrailing;

  /// Destaca o primeiro valor (o "nome" da linha) em negrito -- nas duas
  /// formas (DataTable e card). `false` (o padrao) mantem o peso normal,
  /// como sempre foi em todas as telas que ja usam esta tabela.
  final bool tituloEmNegrito;

  const LinhaResponsiva({
    required this.chave,
    required this.valores,
    this.aoTocar,
    this.aoExcluir,
    this.indicador,
    this.iconePrincipal,
    this.corIconePrincipal,
    this.subtitulo,
    this.valorDestacado,
    this.acaoTrailing,
    this.tituloEmNegrito = false,
  });
}

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

/// DataTable acima do breakpoint, cards abaixo. Concentra aqui a decisao de
/// largura para que nenhuma tela precise repeti-la.
///
/// Aceita grupos com cabecalho. No DataTable o cabecalho e uma linha cujo
/// primeiro campo carrega o titulo — um DataTable exige o mesmo numero de
/// celulas em toda linha, entao as demais ficam vazias.
class TabelaResponsiva extends StatelessWidget {
  final List<String> colunas;
  final List<GrupoResponsivo> grupos;
  final String vazio;

  /// Indice da coluna onde o valor do total de cada grupo deve ser
  /// desenhado no DataTable (desktop). `null` (o padrao) joga o total
  /// inteiro ("Total: R$ X") na coluna 0 -- so existe para nao quebrar quem
  /// ainda nao passa este campo. Irrelevante para a lista simples (sem
  /// agrupamento nunca ha total), por isso nao existe no construtor
  /// principal.
  final int? colunaDoTotal;

  /// Soma de TODAS as linhas de TODOS os grupos, independente do
  /// agrupamento/ordenacao escolhido. `null` (o padrao) nao desenha nada —
  /// caso de quem ainda nao passa este campo, ou da lista simples (sem
  /// agrupamento).
  final double? somatoriaGeral;

  /// Lista simples, sem agrupamento.
  TabelaResponsiva({
    super.key,
    required this.colunas,
    required List<LinhaResponsiva> linhas,
    this.vazio = 'Nada lançado neste mês.',
    this.somatoriaGeral,
  })  : grupos = [GrupoResponsivo(titulo: '', linhas: linhas)],
        colunaDoTotal = null,
        assert(
          // Falha cedo em debug: linha torta e bug de quem chama.
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

  List<LinhaResponsiva> get _todas =>
      [for (final g in grupos) ...g.linhas];

  /// Negrito so no valor 0 (o "nome" da linha) de quem pediu -- as outras
  /// colunas, e quem nao pediu negrito nenhum, ficam com o peso padrao.
  TextStyle? _estiloDoValor(int indice, LinhaResponsiva l) =>
      indice == 0 && l.tituloEmNegrito
          ? const TextStyle(fontWeight: FontWeight.bold)
          : null;

  bool get _temAcoes =>
      _todas.any((l) => l.aoExcluir != null || l.acaoTrailing != null);

  /// Quando a segunda coluna e "Data" (Gastos, Parcelas), o card do mobile
  /// mostra a data ao lado do nome, no titulo, em vez de so no subtitulo --
  /// no desktop a Data ja e a coluna logo depois do nome, e o card passa a
  /// seguir a mesma ordem visual.
  bool get _dataAoLadoDoNome => colunas.length > 1 && colunas[1] == 'Data';

  @override
  Widget build(BuildContext context) {
    if (_todas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            vazio,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final desktop = MediaQuery.sizeOf(context).width >= breakpointDesktop;
    return desktop ? _tabela(context) : _cards();
  }

  Widget _tabela(BuildContext context) {
    // Tabela larga rola na horizontal em vez de estourar o layout.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          showCheckboxColumn: false,
          columns: [
            for (final c in colunas) DataColumn(label: Text(c)),
            if (_temAcoes) const DataColumn(label: Text('')),
          ],
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
                                Text(v, style: _estiloDoValor(i, l)),
                                const SizedBox(height: 4),
                                SizedBox(width: 160, child: l.indicador),
                              ],
                            )
                          : Text(v, style: _estiloDoValor(i, l)),
                    ),
                  if (_temAcoes)
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (l.acaoTrailing != null) l.acaoTrailing!,
                          if (l.aoExcluir != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Excluir',
                              onPressed: () => l.aoExcluir!(),
                            ),
                        ],
                      ),
                    ),
                ],
                ),
              if (grupo.total != null)
                _rodapeDeGrupo(context, grupo.titulo, grupo.total!),
            ],
            if (somatoriaGeral != null)
              _somatoriaGeral(context, somatoriaGeral!),
          ],
        ),
      ),
    );
  }

  /// Linha de cabecalho de grupo. Um DataTable exige o mesmo numero de
  /// celulas em toda linha, entao o titulo vai na primeira e as demais ficam
  /// vazias.
  DataRow _cabecalhoDeGrupo(String titulo) => DataRow(
        key: ValueKey('grupo_$titulo'),
        cells: [
          DataCell(Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold),
          )),
          for (var i = 1; i < colunas.length + (_temAcoes ? 1 : 0); i++)
            const DataCell(SizedBox.shrink()),
        ],
      );

  /// Linha de total ao fim de um grupo. Mesmo truque do cabecalho (texto
  /// fora das celulas normais, resto vazio), mas com fundo cinza claro e
  /// texto em negrito, para se destacar tanto do titulo do grupo (que nao
  /// tem fundo) quanto das linhas normais. Quando [colunaDoTotal] e
  /// informado, o valor vai sob a coluna que esta somando (em vez de inflar
  /// a coluna 0 com uma string longa) -- so a palavra "Total" fica na
  /// celula 0.
  DataRow _rodapeDeGrupo(BuildContext context, String titulo, double total) {
    final estilo = TextStyle(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final totalDeQuantasCelulas = colunas.length + (_temAcoes ? 1 : 0);

    Widget celula(int i) {
      if (i == 0) {
        return Text(
          colunaDoTotal == null ? 'Total: ${formatarReais(total)}' : 'Total',
          style: estilo,
        );
      }
      if (colunaDoTotal != null && i == colunaDoTotal) {
        return Text(formatarReais(total), style: estilo);
      }
      return const SizedBox.shrink();
    }

    return DataRow(
      key: ValueKey('rodape_$titulo'),
      color: WidgetStatePropertyAll(
        Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      cells: [
        for (var i = 0; i < totalDeQuantasCelulas; i++) DataCell(celula(i)),
      ],
    );
  }

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
      if (somatoriaGeral != null) _SomatoriaGeralCard(total: somatoriaGeral!),
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
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ${formatarReais(item.total)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
            ),
          );
        }

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

        final l = item as LinhaResponsiva;
        // Com a data ao lado do nome, o subtitulo pula os dois primeiros
        // valores (nome e data); sem ela, pula so o nome, como antes. So
        // usado quando `l.subtitulo` (widget customizado) nao foi passado.
        final restante =
            l.valores.skip(_dataAoLadoDoNome ? 2 : 1).join(' · ');
        final subtituloWidget = l.subtitulo ??
            (restante.isNotEmpty ? Text(restante) : null);

        final tile = ListTile(
          // Padding menor do lado esquerdo: o icone do pote fica mais perto
          // da borda do card, como pedido.
          contentPadding: const EdgeInsets.only(left: 8, right: 16),
          leading: l.iconePrincipal == null
              ? null
              : Icon(l.iconePrincipal, color: l.corIconePrincipal),
          title: _dataAoLadoDoNome
              ? Row(
                  children: [
                    Flexible(
                      child: Text(
                        l.valores.first,
                        overflow: TextOverflow.ellipsis,
                        style: _estiloDoValor(0, l),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l.valores[1],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                )
              : Text(l.valores.first, style: _estiloDoValor(0, l)),
          subtitle: subtituloWidget != null || l.indicador != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ?subtituloWidget,
                    if (l.indicador != null) ...[
                      const SizedBox(height: 6),
                      l.indicador!,
                    ],
                  ],
                )
              : null,
          trailing: l.valorDestacado == null && l.acaoTrailing == null
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (l.valorDestacado != null)
                      Text(
                        l.valorDestacado!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (l.acaoTrailing != null) l.acaoTrailing!,
                  ],
                ),
          onTap: l.aoTocar,
        );

        const margemCard = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

        if (l.aoExcluir == null) {
          return Card(key: l.chave, margin: margemCard, child: tile);
        }

        // Arrastar pra esquerda revela a faixa vermelha com a lixeira atras
        // do card; so ao final do gesto (confirmDismiss) e que a exclusao de
        // verdade roda -- ela ja pergunta confirmacao por dentro (mesmo
        // fluxo do botao de excluir de sempre). Devolve false sempre: quem
        // tira a linha da tela e o proximo dado que chegar pelo provider
        // (stream), nao o proprio Dismissible -- se a exclusao falhar (ex.:
        // sem rede), a linha so volta pro lugar em vez de sumir e reaparecer.
        return Dismissible(
          key: l.chave,
          direction: DismissDirection.endToStart,
          background: Container(
            margin: margemCard,
            padding: const EdgeInsets.only(right: 24),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            await l.aoExcluir!();
            return false;
          },
          child: Card(margin: margemCard, child: tile),
        );
      },
    );
  }
}

/// Marcador interno de `_cards()`: identifica o item da lista plana que e
/// o rodape de total de um grupo, em vez de titulo ou linha.
class _RodapeDeGrupo {
  final String titulo;
  final double total;

  const _RodapeDeGrupo({required this.titulo, required this.total});
}

/// Marcador interno de `_cards()`: identifica o item da lista plana que e a
/// somatoria geral da tabela inteira, sempre o ultimo item.
class _SomatoriaGeralCard {
  final double total;

  const _SomatoriaGeralCard({required this.total});
}
