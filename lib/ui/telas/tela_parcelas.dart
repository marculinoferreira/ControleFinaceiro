import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/pote.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';
import '../widgets/estados_async.dart';
import '../widgets/tabela_responsiva.dart';

/// Apresentacao pura: o agrupamento e a ordenacao vem prontos de
/// agruparParcelasEmAberto, testado na Fase 2. Nao recalcule nada aqui.
class TelaParcelas extends ConsumerWidget {
  const TelaParcelas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abertas = ref.watch(parcelasEmAbertoProvider);
    final membros = ref.watch(membrosProvider);
    final potes = ref.watch(potesProvider).value ?? const <Pote>[];
    final mesRef = ref.watch(mesSelecionadoProvider).valor;

    return abertas.when(
      loading: () => const CarregandoLista(),
      error: (e, _) => ErroComRecarregar(
        erro: e,
        aoRecarregar: () => ref.invalidate(parceladosDesdeProvider(mesRef)),
      ),
      data: (compras) {
        return TabelaResponsiva(
          colunas: const [
            'Compra',
            'Pessoa',
            'Pote',
            'Parcela',
            'Valor/mês',
            'Faltam',
          ],
          vazio: 'Nenhuma compra parcelada em aberto.',
          linhas: [
            for (final c in compras)
              LinhaResponsiva(
                chave: ValueKey('compra_${c.compraId}'),
                valores: [
                  c.descricao,
                  nomeDoMembro(membros, c.membroId),
                  nomeDoPote(potes, c.poteId),
                  '${c.parcelaAtual}/${c.totalParcelas}',
                  formatarReais(c.valorParcela),
                  c.parcelasRestantes == 0
                      ? 'última'
                      : '${c.parcelasRestantes} ${c.parcelasRestantes == 1 ? "mês" : "meses"}',
                ],
              ),
          ],
        );
      },
    );
  }
}
