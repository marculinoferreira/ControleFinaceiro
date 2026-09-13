import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/cartao.dart';
import '../../dominio/models/membro.dart';
import '../../dominio/models/pote.dart';
import '../../dominio/ordem_gastos.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';
import '../tema/tema.dart';

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
    final esquema = Theme.of(context).colorScheme;
    final entradas = _rotulos.entries.toList();

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
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: esquema.outlineVariant),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                key: const Key('ordem_gastos'),
                children: [
                  for (final (i, entrada) in entradas.indexed) ...[
                    // Linha fina entre as opcoes -- so entre elas, nunca
                    // antes da primeira nem depois da ultima.
                    if (i > 0)
                      Container(
                        width: 1,
                        height: 18,
                        color: esquema.outlineVariant,
                      ),
                    Expanded(
                      child: _OpcaoOrdem(
                        rotulo: entrada.value,
                        selecionada: ordem == entrada.key,
                        aoTocar: () => ref
                            .read(ordemGastosProvider.notifier)
                            .selecionar(entrada.key),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uma opcao do `SeletorOrdem`. Selecionada: pilula com fundo destacado.
/// Nao selecionada: so o texto, sem caixa nem borda -- as linhas finas do
/// `Row` externo (entre as opcoes) e que separam uma da outra.
class _OpcaoOrdem extends StatelessWidget {
  final String rotulo;
  final bool selecionada;
  final VoidCallback aoTocar;

  const _OpcaoOrdem({
    required this.rotulo,
    required this.selecionada,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selecionada ? corDestaque : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            rotulo,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: selecionada ? Colors.white : esquema.onSurfaceVariant,
              fontWeight: selecionada ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// Caixa de filtro compartilhada: mesmo padrao do campo de data em
/// `formulario_gasto.dart` (`InputDecorator` + `OutlineInputBorder`) -- a
/// legenda (icone + "Rotulo:") "quebra" a linha de cima da borda, em vez de
/// ficar dentro da caixa acima do valor. Sem a legenda, duas caixas sem
/// selecao mostrariam so "Todos" cada uma, sem dizer qual e Cartao e qual e
/// Pote.
class _CaixaFiltro extends StatelessWidget {
  final IconData icone;
  final String rotuloCampo;
  final String valor;

  const _CaixaFiltro({
    required this.icone,
    required this.rotuloCampo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 14),
            const SizedBox(width: 4),
            Text('$rotuloCampo:'),
          ],
        ),
        suffixIcon: const Icon(Icons.arrow_drop_down),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      child: Text(
        valor,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Sentinela interna de `_caixaFiltro`: `PopupMenuButton<T>` nao consegue
/// distinguir "o menu fechou sem escolha" de "a pessoa escolheu o item cujo
/// valor e null" -- as duas resolvem a Future interna do `showMenu` como
/// null, e so a primeira chama `onCanceled` em vez de `onSelected`. Por
/// isso os itens nulos ("Casal"/"Todos") viajam com esta chave e so viram
/// null de volta no `onSelected`. String claramente artificial, nunca
/// cadastrada como id real de pessoa/pote/cartao em nenhuma tela.
const _semFiltro = '__sem_filtro__';

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
    // aberta): sem isso a caixa mostraria o id cru em vez de um rotulo.
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

    final pessoa = _caixaFiltro(
      chave: const Key('filtro_membro'),
      icone: Icons.person_outline,
      rotuloCampo: 'Pessoa',
      valor:
          membroValido == null ? 'Casal' : nomeDoMembro(membros, membroValido),
      itens: [
        (null, 'Casal'),
        for (final m in membros) (m.id, m.nome),
      ],
      aoSelecionar: (v) => ref.read(visaoProvider.notifier).selecionar(v),
    );

    final cartao = _caixaFiltro(
      chave: const Key('filtro_cartao'),
      icone: Icons.credit_card,
      rotuloCampo: 'Cartão',
      valor: cartaoValido == null
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

    final pote = _caixaFiltro(
      chave: const Key('filtro_pote'),
      icone: Icons.pie_chart_outline,
      rotuloCampo: 'Pote',
      valor: poteValido == null ? 'Todos' : nomeDoPote(potes, poteValido),
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

  /// Caixa de filtro que abre um menu suspenso ancorado nela mesma. [itens]
  /// e uma lista de (valor, rotulo); [icone] e [rotuloCampo] identificam
  /// qual filtro e (ver o comentario de `_CaixaFiltro`). Ver `_semFiltro`
  /// sobre o motivo de mapear valores nulos pra uma chave nao-nula antes de
  /// entregar ao `PopupMenuButton`.
  Widget _caixaFiltro({
    required Key chave,
    required IconData icone,
    required String rotuloCampo,
    required String valor,
    required List<(String?, String)> itens,
    required ValueChanged<String?> aoSelecionar,
  }) {
    return PopupMenuButton<String>(
      key: chave,
      tooltip: '',
      itemBuilder: (context) => [
        for (final (v, texto) in itens)
          PopupMenuItem(value: v ?? _semFiltro, child: Text(texto)),
      ],
      onSelected: (v) => aoSelecionar(v == _semFiltro ? null : v),
      child: _CaixaFiltro(icone: icone, rotuloCampo: rotuloCampo, valor: valor),
    );
  }
}
