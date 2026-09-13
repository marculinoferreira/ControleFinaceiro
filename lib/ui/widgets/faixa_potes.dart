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

    return LayoutBuilder(
      builder: (context, restricoes) {
        // Mesmo raciocinio de Shell._barraInferior: um tamanho de fonte so
        // pra todo mundo, calculado a partir da largura media disponivel,
        // em vez de cada rotulo encolher sozinho com FittedBox -- isso
        // fazia nomes curtos (ex.: "Prazer") precisarem encolher bem menos
        // que nomes longos (ex.: "Conhecimento") pra caber na mesma
        // largura, e o rotulo curto acabava visualmente maior que os
        // outros. Com reticencias em vez de encolher, o tamanho fica igual
        // pra todos, e so o nome muito comprido corta.
        final larguraItem = restricoes.maxWidth / potes.length;
        final tamanhoRotulo = ((larguraItem - 8) / 6.0).clamp(9.0, 11.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              for (final pote in potes)
                Expanded(
                  child: _ItemPote(
                    pote: pote,
                    habilitado: habilitado,
                    tamanhoRotulo: tamanhoRotulo,
                    aoTocar: () => aoTocar(pote),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ItemPote extends StatelessWidget {
  final Pote pote;
  final bool habilitado;
  final double tamanhoRotulo;
  final VoidCallback aoTocar;

  const _ItemPote({
    required this.pote,
    required this.habilitado,
    required this.tamanhoRotulo,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Opacity(
        opacity: habilitado ? 1 : 0.4,
        child: InkWell(
          onTap: habilitado ? aoTocar : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: corDeHex(pote.cor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconeDoPote(pote.icone), color: Colors.white, size: 22),
                const SizedBox(height: 4),
                Text(
                  pote.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: tamanhoRotulo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
