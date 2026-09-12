import 'package:flutter/material.dart';

import '../tema/formatadores.dart';
import '../shell.dart' show breakpointDesktop;

/// Uma linha da tabela. [valores] tem um item por coluna; no mobile o
/// primeiro vira titulo do card e os demais formam o subtitulo.
class LinhaResponsiva {
  final LocalKey chave;
  final List<String> valores;
  final VoidCallback? aoTocar;
  final VoidCallback? aoExcluir;

  /// Widget opcional colado ao primeiro valor -- uma barra de progresso, por
  /// exemplo. Aparece nas duas formas: sob o primeiro valor no DataTable e
  /// sob o titulo no card. Existe porque o Resumo dos Potes precisa de uma
  /// barra por linha, e uma tela nao pode repetir a decisao de largura so
  /// para conseguir desenhar isso.
  final Widget? indicador;

  const LinhaResponsiva({
    required this.chave,
    required this.valores,
    this.aoTocar,
    this.aoExcluir,
    this.indicador,
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

  /// Lista simples, sem agrupamento.
  TabelaResponsiva({
    super.key,
    required this.colunas,
    required List<LinhaResponsiva> linhas,
    this.vazio = 'Nada lançado neste mês.',
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
  });

  List<LinhaResponsiva> get _todas =>
      [for (final g in grupos) ...g.linhas];

  bool get _temAcoes => _todas.any((l) => l.aoExcluir != null);

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
  /// fora das celulas normais, resto vazio), mas em italico e em cor
  /// esmaecida em vez de negrito, para nao ser confundida com o titulo do
  /// grupo. Quando [colunaDoTotal] e informado, o valor vai sob a coluna que
  /// esta somando (em vez de inflar a coluna 0 com uma string longa) -- so
  /// a palavra "Total" fica na celula 0.
  DataRow _rodapeDeGrupo(BuildContext context, String titulo, double total) {
    final estilo = TextStyle(
      fontStyle: FontStyle.italic,
      color: Theme.of(context).colorScheme.outline,
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.outline,
                    ),
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
}

/// Marcador interno de `_cards()`: identifica o item da lista plana que e
/// o rodape de total de um grupo, em vez de titulo ou linha.
class _RodapeDeGrupo {
  final String titulo;
  final double total;

  const _RodapeDeGrupo({required this.titulo, required this.total});
}
