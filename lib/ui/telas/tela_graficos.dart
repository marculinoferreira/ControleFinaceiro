import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/membro.dart';
import '../../estado/providers.dart';
import '../shell.dart' show breakpointDesktop;
import '../widgets/graficos/barra_cascata.dart';
import '../widgets/graficos/barras_cartao_comparativo.dart';
import '../widgets/graficos/barras_pote_comparativo.dart';
import '../widgets/graficos/barras_previsto_gasto.dart';
import '../widgets/graficos/linha_comprometimento.dart';
import '../widgets/graficos/linha_comprometimento_comparativo.dart';
import '../widgets/graficos/linha_evolucao.dart';
import '../widgets/graficos/linha_projecao.dart';
import '../widgets/graficos/pizza_ganhos.dart';
import '../widgets/graficos/rosca_por_cartao.dart';
import '../widgets/graficos/rosca_por_pote.dart';
import '../widgets/graficos/tendencia_pote.dart';

/// A tela de Graficos tem 3 visoes, escolhidas por `_SeletorTipoVisao`:
/// Visao Geral (os sete graficos de sempre), Comparativo (as duas pessoas
/// da casa lado a lado) e Projecao (saldo dos proximos 12 meses).
///
/// Nao ha AsyncValue.when aqui, de proposito: cada MolduraGrafico resolve o
/// seu. Um `when` no topo derrubaria todos os graficos da visao atual por
/// causa de um provider com problema.
class TelaGraficos extends ConsumerWidget {
  const TelaGraficos({super.key});

  /// Os seis primeiros na ordem da spec 10; o setimo (cartao) vem depois.
  static const _graficosGeral = <Widget>[
    RoscaPorPote(),
    BarrasPrevistoGasto(),
    LinhaEvolucao(),
    PizzaGanhos(),
    BarraCascata(),
    LinhaComprometimento(),
    RoscaPorCartao(),
    TendenciaPote(),
  ];

  static const _graficosComparativo = <Widget>[
    BarrasPoteComparativo(),
    BarrasCartaoComparativo(),
    LinhaComprometimentoComparativo(),
  ];

  static const _graficosProjecao = <Widget>[LinhaProjecao()];

  List<Widget> _graficosDoTipo(TipoVisaoGraficos tipo) => switch (tipo) {
        TipoVisaoGraficos.geral => _graficosGeral,
        TipoVisaoGraficos.comparativo => _graficosComparativo,
        TipoVisaoGraficos.projecao => _graficosProjecao,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = MediaQuery.sizeOf(context).width >= breakpointDesktop;
    final membros = ref.watch(membrosParaVisaoProvider);
    final tipo = ref.watch(tipoVisaoGraficosProvider);
    final graficos = _graficosDoTipo(tipo);

    return Column(
      children: [
        if (tipo != TipoVisaoGraficos.comparativo) _SeletorVisao(membros: membros),
        const _SeletorTipoVisao(),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('graficos_rolagem'),
            child: desktop && graficos.length > 1
                ? _duasColunas(graficos)
                : _colunaUnica(graficos),
          ),
        ),
      ],
    );
  }

  /// No desktop os graficos ficam pequenos demais ocupando a largura toda;
  /// duas colunas aproveitam o espaco e encurtam a rolagem.
  Widget _duasColunas(List<Widget> graficos) {
    final esquerda = <Widget>[];
    final direita = <Widget>[];
    for (final (i, g) in graficos.indexed) {
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

  Widget _colunaUnica(List<Widget> graficos) => Column(
        key: const Key('graficos_coluna_unica'),
        children: graficos,
      );
}

/// Mesmo seletor da tela de Resumo, escrevendo no mesmo `visaoProvider`:
/// trocar a visao num lugar troca no outro, o que e o esperado de duas
/// telas que respondem a mesma pergunta. So aparece na Visao Geral e na
/// Projecao -- o Comparativo sempre mostra as duas pessoas, escolher uma
/// so nao faria sentido ali.
class _SeletorVisao extends ConsumerWidget {
  final List<Membro> membros;
  const _SeletorVisao({required this.membros});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Com um so integrante ativo na casa, "Marcos" e "Casal" seriam a mesma
    // coisa -- o seletor todo some, nao so um dos dois.
    if (membros.where((m) => m.removidoEm == null).length <= 1) {
      return const SizedBox.shrink();
    }

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

/// As 3 abas: Visao Geral / Comparativo / Projecao. "Comparativo" so entra
/// na lista quando a casa tem os dois integrantes ativos -- ver
/// `duplaComparativaProvider`. Se a dupla encolher com a aba Comparativo
/// ja selecionada (alguem saiu da casa com a tela aberta), volta sozinho
/// pra Visao Geral.
class _SeletorTipoVisao extends ConsumerWidget {
  const _SeletorTipoVisao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipo = ref.watch(tipoVisaoGraficosProvider);
    final temDupla = ref.watch(duplaComparativaProvider).length == 2;

    if (tipo == TipoVisaoGraficos.comparativo && !temDupla) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(tipoVisaoGraficosProvider.notifier).selecionar(TipoVisaoGraficos.geral);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SegmentedButton<TipoVisaoGraficos>(
        key: const Key('graficos_tipo_visao'),
        showSelectedIcon: false,
        segments: [
          const ButtonSegment(
            value: TipoVisaoGraficos.geral,
            label: Text('Visão Geral'),
            icon: Icon(Icons.donut_large),
          ),
          if (temDupla)
            const ButtonSegment(
              value: TipoVisaoGraficos.comparativo,
              label: Text('Comparativo'),
              icon: Icon(Icons.bar_chart),
            ),
          const ButtonSegment(
            value: TipoVisaoGraficos.projecao,
            label: Text('Projeção'),
            icon: Icon(Icons.trending_up),
          ),
        ],
        selected: {
          tipo == TipoVisaoGraficos.comparativo && !temDupla
              ? TipoVisaoGraficos.geral
              : tipo,
        },
        onSelectionChanged: (s) =>
            ref.read(tipoVisaoGraficosProvider.notifier).selecionar(s.first),
      ),
    );
  }
}
