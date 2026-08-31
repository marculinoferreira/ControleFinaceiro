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
    final gastos = ref.watch(gastosFiltradosProvider);
    final membros = ref.watch(membrosProvider);
    final potes = ref.watch(potesProvider).value ?? const <Pote>[];
    final mesRef = ref.watch(mesSelecionadoProvider).valor;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('novo_gasto'),
        onPressed: () => abrirFormularioGasto(context: context, ref: ref),
        icon: const Icon(Icons.add),
        label: const Text('Novo gasto'),
      ),
      body: Column(
        children: [
          _Filtros(membros: membros, potes: potes),
          const Divider(height: 1),
          Expanded(
            child: gastos.when(
              loading: () => const CarregandoLista(),
              error: (e, _) => ErroComRecarregar(
                erro: e,
                aoRecarregar: () =>
                    ref.invalidate(gastosDoMesProvider(mesRef)),
              ),
              data: (lista) => _tabela(context, ref, lista, membros, potes),
            ),
          ),
        ],
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

    if (!gasto.parcelado) {
      await repo.removerUma(gasto.id);
      return;
    }

    final modo = await perguntarModoExclusao(context: context, gasto: gasto);
    if (modo == null) return;
    await aplicarExclusao(repo: repo, gasto: gasto, modo: modo);
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
              initialValue: membroId,
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
              initialValue: poteId,
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
