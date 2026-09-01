import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/cartao.dart';
import '../../dominio/models/membro.dart';
import '../../dominio/models/pote.dart';
import '../../dominio/ordem_gastos.dart';
import '../../dominio/parcelas.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';
import '../widgets/estados_async.dart';
import '../widgets/filtros_lancamentos.dart';
import '../widgets/tabela_responsiva.dart';

/// Apresentacao pura: quem agrupa as parcelas por compra e
/// `agruparParcelasEmAberto`, e quem as ordena e `agruparCompras` — os dois
/// no dominio, testados. Nada e recalculado aqui.
class TelaParcelas extends ConsumerWidget {
  const TelaParcelas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membros = ref.watch(membrosProvider);
    final mesRef = ref.watch(mesSelecionadoProvider).valor;

    // Combina em vez de `.value ?? []`: a regra global e que toda leitura
    // assincrona passa pelos tres ramos de AsyncValue.when, sem excecao.
    final combinado = combinarAsyncValues(
      combinarAsyncValues(
        ref.watch(potesProvider),
        ref.watch(cartoesProvider),
        (potes, cartoes) => (potes, cartoes),
      ),
      ref.watch(comprasAgrupadasProvider),
      (par, grupos) => (par.$1, par.$2, grupos),
    );

    return combinado.when(
      loading: () => const CarregandoLista(),
      error: (e, _) => ErroComRecarregar(
        erro: e,
        aoRecarregar: () {
          ref.invalidate(potesProvider);
          ref.invalidate(cartoesProvider);
          ref.invalidate(parceladosDesdeProvider(mesRef));
        },
      ),
      data: (trio) {
        final (potes, cartoes, grupos) = trio;
        return Column(
          children: [
            FiltrosLancamentos(
              membros: membros,
              potes: potes,
              cartoes: cartoes,
            ),
            const SeletorOrdem(),
            const Divider(height: 1),
            Expanded(
              child: _tabela(grupos, membros, potes, cartoes),
            ),
          ],
        );
      },
    );
  }

  Widget _tabela(
    List<Grupo<CompraParcelada>> grupos,
    List<Membro> membros,
    List<Pote> potes,
    List<Cartao> cartoes,
  ) {
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
      grupos: [
        for (final grupo in grupos)
          GrupoResponsivo(
            titulo: grupo.titulo,
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
    );
  }

  String _restante(CompraParcelada c) {
    if (c.parcelasRestantes == 0) return 'última';
    return '${c.parcelasRestantes} '
        '${c.parcelasRestantes == 1 ? "mês" : "meses"}';
  }
}
