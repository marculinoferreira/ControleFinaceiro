import 'package:flutter/material.dart';

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

/// DataTable acima do breakpoint, cards abaixo. Concentra aqui a decisao de
/// largura para que nenhuma tela precise repeti-la.
class TabelaResponsiva extends StatelessWidget {
  final List<String> colunas;
  final List<LinhaResponsiva> linhas;
  final String vazio;

  TabelaResponsiva({
    super.key,
    required this.colunas,
    required this.linhas,
    this.vazio = 'Nada lançado neste mês.',
  }) : assert(
          // Falha cedo em debug: linha torta e bug de quem chama.
          linhas.isEmpty ||
              linhas.every((l) => l.valores.length == colunas.length),
          'Cada LinhaResponsiva precisa de um valor por coluna',
        );

  bool get _temAcoes => linhas.any((l) => l.aoExcluir != null);

  @override
  Widget build(BuildContext context) {
    if (linhas.isEmpty) {
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
    return desktop ? _tabela() : _cards();
  }

  Widget _tabela() {
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
            for (final l in linhas)
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
          ],
        ),
      ),
    );
  }

  Widget _cards() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: linhas.length,
      itemBuilder: (context, i) {
        final l = linhas[i];
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
