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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Text('Ordenar por', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 12),
          // Expanded limita a largura e o scroll horizontal absorve o resto:
          // quatro segmentos nao cabem na largura de um telefone, e um Row
          // solto estoura em vez de rolar.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<OrdemGastos>(
                key: const Key('ordem_gastos'),
                showSelectedIcon: false,
                segments: [
                  for (final entrada in _rotulos.entries)
                    ButtonSegment(
                        value: entrada.key, label: Text(entrada.value)),
                ],
                selected: {ordem},
                onSelectionChanged: (s) =>
                    ref.read(ordemGastosProvider.notifier).selecionar(s.first),
              ),
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
    final membroId = ref.watch(filtroMembroProvider);
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

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              key: const Key('filtro_membro'),
              initialValue: membroValido,
              decoration: const InputDecoration(
                labelText: 'Pessoa',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Casal')),
                for (final m in membros)
                  DropdownMenuItem(value: m.id, child: Text(m.nome)),
              ],
              onChanged: (v) =>
                  ref.read(filtroMembroProvider.notifier).selecionar(v),
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              key: const Key('filtro_cartao'),
              initialValue: cartaoValido,
              decoration: const InputDecoration(
                labelText: 'Cartão',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                const DropdownMenuItem(value: '', child: Text('Sem cartão')),
                for (final c in cartoes)
                  DropdownMenuItem(value: c.id, child: Text(c.nome)),
              ],
              onChanged: (v) =>
                  ref.read(filtroCartaoProvider.notifier).selecionar(v),
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              key: const Key('filtro_pote'),
              initialValue: poteValido,
              decoration: const InputDecoration(
                labelText: 'Pote',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final p in potes)
                  DropdownMenuItem(value: p.id, child: Text(p.nome)),
              ],
              onChanged: (v) =>
                  ref.read(filtroPoteProvider.notifier).selecionar(v),
            ),
          ),
        ],
      ),
    );
  }
}
