import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/gasto.dart';
import '../../dominio/models/membro.dart';
import '../../dominio/models/pote.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';
import '../widgets/dialogo_exclusao.dart';
import '../widgets/estados_async.dart';
import '../widgets/tabela_responsiva.dart';
import 'formulario_gasto.dart';

class TelaGastos extends ConsumerWidget {
  const TelaGastos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membros = ref.watch(membrosProvider);
    final mesRef = ref.watch(mesSelecionadoProvider).valor;

    // Potes entra na combinacao (em vez de `.value ?? []`) porque a regra
    // global e "toda leitura assincrona passa pelo AsyncValue.when com os
    // tres ramos, sem excecao": um erro em potesProvider nao pode renderizar
    // ids crus silenciosamente, e o loading dele nao pode ser mascarado de
    // "zero potes cadastrados".
    final combinado = combinarAsyncValues(
      ref.watch(potesProvider),
      ref.watch(gastosFiltradosProvider),
      (potes, gastos) => (potes, gastos),
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('novo_gasto'),
        onPressed: membros.isEmpty
            ? null
            : () => abrirFormularioGasto(context: context, ref: ref),
        icon: const Icon(Icons.add),
        label: const Text('Novo gasto'),
      ),
      body: combinado.when(
        loading: () => const CarregandoLista(),
        error: (e, _) => ErroComRecarregar(
          erro: e,
          aoRecarregar: () {
            ref.invalidate(potesProvider);
            ref.invalidate(gastosDoMesProvider(mesRef));
          },
        ),
        data: (par) {
          final (potes, gastos) = par;
          return Column(
            children: [
              _Filtros(membros: membros, potes: potes),
              const Divider(height: 1),
              Expanded(
                child: _tabela(context, ref, gastos, membros, potes),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabela(
    BuildContext context,
    WidgetRef ref,
    List<Gasto> gastos,
    List<Membro> membros,
    List<Pote> potes,
  ) {
    return TabelaResponsiva(
      colunas: const ['Descrição', 'Pessoa', 'Pote', 'Parcela', 'Valor'],
      vazio: 'Nenhum gasto neste mês.',
      linhas: [
        for (final g in gastos)
          LinhaResponsiva(
            chave: ValueKey('gasto_${g.id}'),
            valores: [
              g.descricao,
              nomeDoMembro(membros, g.membroId),
              nomeDoPote(potes, g.poteId),
              g.rotuloParcela,
              formatarReais(g.valor),
            ],
            aoTocar: () =>
                abrirFormularioGasto(context: context, ref: ref, existente: g),
            aoExcluir: () => _excluir(context, ref, g),
          ),
      ],
    );
  }

  /// Gasto simples apaga direto; parcelado precisa da escolha do modo.
  Future<void> _excluir(
      BuildContext context, WidgetRef ref, Gasto gasto) async {
    final repo = ref.read(repositorioGastosProvider);

    try {
      if (!gasto.parcelado) {
        await repo.removerUma(gasto.id);
        return;
      }

      final modo =
          await perguntarModoExclusao(context: context, gasto: gasto);
      if (modo == null) return;
      await aplicarExclusao(repo: repo, gasto: gasto, modo: modo);
    } catch (e) {
      if (!context.mounted) return;
      avisarErroDeEscrita(context, e);
    }
  }
}

class _Filtros extends ConsumerWidget {
  final List<Membro> membros;
  final List<Pote> potes;

  const _Filtros({required this.membros, required this.potes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membroId = ref.watch(filtroMembroProvider);
    final poteId = ref.watch(filtroPoteProvider);

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
