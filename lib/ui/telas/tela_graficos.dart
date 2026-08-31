import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/membro.dart';
import '../../estado/providers.dart';
import '../shell.dart' show breakpointDesktop;
import '../widgets/graficos/barra_cascata.dart';
import '../widgets/graficos/barras_previsto_gasto.dart';
import '../widgets/graficos/linha_comprometimento.dart';
import '../widgets/graficos/linha_evolucao.dart';
import '../widgets/graficos/pizza_ganhos.dart';
import '../widgets/graficos/rosca_por_pote.dart';

/// Os seis graficos da spec 10.
///
/// Nao ha AsyncValue.when aqui, de proposito: cada MolduraGrafico resolve o
/// seu. Um `when` no topo derrubaria os seis por causa de um provider com
/// problema, e a pessoa perderia cinco graficos que estavam prontos.
class TelaGraficos extends ConsumerWidget {
  const TelaGraficos({super.key});

  /// Na ordem da spec 10.
  static const _graficos = <Widget>[
    RoscaPorPote(),
    BarrasPrevistoGasto(),
    LinhaEvolucao(),
    PizzaGanhos(),
    BarraCascata(),
    LinhaComprometimento(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = MediaQuery.sizeOf(context).width >= breakpointDesktop;
    final membros = ref.watch(membrosProvider);

    return SingleChildScrollView(
      key: const Key('graficos_rolagem'),
      child: Column(
        children: [
          _SeletorVisao(membros: membros),
          if (desktop) _duasColunas() else _colunaUnica(),
        ],
      ),
    );
  }

  /// No desktop os graficos ficam pequenos demais ocupando a largura toda;
  /// duas colunas aproveitam o espaco e encurtam a rolagem.
  Widget _duasColunas() {
    final esquerda = <Widget>[];
    final direita = <Widget>[];
    for (final (i, g) in _graficos.indexed) {
      (i.isEven ? esquerda : direita).add(g);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            key: const Key('graficos_coluna_esquerda'),
            children: esquerda,
          ),
        ),
        Expanded(
          child: Column(
            key: const Key('graficos_coluna_direita'),
            children: direita,
          ),
        ),
      ],
    );
  }

  Widget _colunaUnica() => const Column(
        key: Key('graficos_coluna_unica'),
        children: _graficos,
      );
}

/// Mesmo seletor da tela de Resumo, escrevendo no mesmo `visaoProvider`:
/// trocar a visao num lugar troca no outro, o que e o esperado de duas
/// telas que respondem a mesma pergunta.
class _SeletorVisao extends ConsumerWidget {
  final List<Membro> membros;
  const _SeletorVisao({required this.membros});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (membros.isEmpty) return const SizedBox.shrink();

    final visao = ref.watch(visaoProvider);
    final valida =
        visao == null || membros.any((m) => m.id == visao) ? visao : null;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SegmentedButton<String?>(
        key: const Key('graficos_visao'),
        showSelectedIcon: false,
        segments: [
          for (final m in membros)
            ButtonSegment(value: m.id, label: Text(m.nome)),
          const ButtonSegment(value: null, label: Text('Casal')),
        ],
        selected: {valida},
        onSelectionChanged: (s) =>
            ref.read(visaoProvider.notifier).selecionar(s.first),
      ),
    );
  }
}
