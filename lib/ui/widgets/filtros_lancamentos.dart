import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/cartao.dart';
import '../../dominio/models/membro.dart';
import '../../dominio/models/pote.dart';
import '../../dominio/ordem_gastos.dart';
import '../../estado/providers.dart';

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
          SegmentedButton<OrdemGastos>(
            key: const Key('ordem_gastos'),
            showSelectedIcon: false,
            // expandedInsets zerado faz os quatro segmentos dividirem a
            // largura disponivel em partes iguais, de uma borda a outra da
            // tela, em vez de encolherem ate o texto e rolarem na horizontal.
            expandedInsets: EdgeInsets.zero,
            style: const ButtonStyle(
              // Retangulo reto: sem o raio de pilula do Material 3.
              shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              ),
            ),
            segments: [
              for (final entrada in _rotulos.entries)
                ButtonSegment(
                  value: entrada.key,
                  // Um quarto da tela e pouco para "Cartão" com a fonte do
                  // sistema aumentada: o scaleDown encolhe o rotulo o tanto
                  // que precisar em vez de quebrar em duas linhas.
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(entrada.value, maxLines: 1, softWrap: false),
                  ),
                ),
            ],
            selected: {ordem},
            onSelectionChanged: (s) =>
                ref.read(ordemGastosProvider.notifier).selecionar(s.first),
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

  /// Acima disto os tres filtros cabem lado a lado; abaixo, Pessoa e Cartao
  /// dividem a primeira linha e Pote fica sozinho na segunda.
  static const double _larguraTresColunas = 700;

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
    // (a outra pessoa apagou o membro ou o pote enquanto esta aba estava
    // aberta): sem isso o DropdownButtonFormField derruba o assert de
    // "exactly one item with [DropdownButton]'s value". Null e sempre valido
    // aqui — e o item "Casal"/"Todos".
    final membroValido =
        membroId == null || membros.any((m) => m.id == membroId)
            ? membroId
            : null;
    final poteValido = poteId == null || potes.any((p) => p.id == poteId)
        ? poteId
        : null;
    // A string vazia ("Sem cartão") e sempre valida: ela nao aponta para
    // nenhum documento que possa ter sido removido.
    final cartaoValido = cartaoId == null ||
            cartaoId.isEmpty ||
            cartoes.any((c) => c.id == cartaoId)
        ? cartaoId
        : null;

    final pessoa = _seletor(
      context,
      chave: const Key('filtro_membro'),
      rotulo: 'Pessoa',
      valor: membroValido,
      itens: [
        _item(null, 'Casal'),
        for (final m in membros) _item(m.id, m.nome),
      ],
      // Mesmo provider do seletor Marcos / Silvia / Casal do Resumo e dos
      // Graficos: trocar a pessoa aqui troca la, e vice-versa.
      aoMudar: (v) => ref.read(visaoProvider.notifier).selecionar(v),
    );

    final cartao = _seletor(
      context,
      chave: const Key('filtro_cartao'),
      rotulo: 'Cartão',
      valor: cartaoValido,
      itens: [
        _item(null, 'Todos'),
        _item('', 'Sem cartão'),
        for (final c in cartoes) _item(c.id, c.nome),
      ],
      aoMudar: (v) => ref.read(filtroCartaoProvider.notifier).selecionar(v),
    );

    final pote = _seletor(
      context,
      chave: const Key('filtro_pote'),
      rotulo: 'Pote',
      valor: poteValido,
      itens: [
        _item(null, 'Todos'),
        for (final p in potes) _item(p.id, p.nome),
      ],
      aoMudar: (v) => ref.read(filtroPoteProvider.notifier).selecionar(v),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: LayoutBuilder(
        builder: (context, restricoes) {
          if (restricoes.maxWidth >= _larguraTresColunas) {
            return Row(
              children: [
                Expanded(child: pessoa),
                const SizedBox(width: 12),
                Expanded(child: cartao),
                const SizedBox(width: 12),
                Expanded(child: pote),
              ],
            );
          }
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: pessoa),
                  const SizedBox(width: 12),
                  Expanded(child: cartao),
                ],
              ),
              const SizedBox(height: 8),
              pote,
            ],
          );
        },
      ),
    );
  }

  DropdownMenuItem<String?> _item(String? valor, String texto) =>
      DropdownMenuItem(
        value: valor,
        child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis),
      );

  Widget _seletor(
    BuildContext context, {
    required Key chave,
    required String rotulo,
    required String? valor,
    required List<DropdownMenuItem<String?>> itens,
    required ValueChanged<String?> aoMudar,
  }) {
    return DropdownButtonFormField<String?>(
      key: chave,
      initialValue: valor,
      // A caixa acompanha a coluna (Expanded) e isExpanded faz o texto
      // escolhido ocupar essa largura, cortando com reticencias em vez de
      // estourar quando o nome do cartao ou do pote e comprido.
      isExpanded: true,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: rotulo,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: itens,
      onChanged: aoMudar,
    );
  }
}
