import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../dominio/serie_mensal.dart';
import '../../../estado/providers.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';
import 'eixo_mensal.dart';

/// Grafico 3 da spec 10: evolucao de ganhos x gastos ao longo dos meses.
///
/// As duas series nao sao potes, entao a cor vem do ColorScheme — e a unica
/// excecao prevista a regra de "cor sempre do pote".
class LinhaEvolucao extends ConsumerWidget {
  const LinhaEvolucao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esquema = Theme.of(context).colorScheme;
    final fim = ref.watch(mesSelecionadoProvider);

    return MolduraGrafico<List<PontoMensal>>(
      titulo: 'Ganhos × gastos nos últimos $mesesDaSerie meses',
      vazio: 'Nada lançado nos últimos $mesesDaSerie meses.',
      dados: ref.watch(serieMensalProvider),
      estaVazio: (serie) =>
          serie.isEmpty ||
          serieVazia([
            for (final p in serie) ...[p.ganhos, p.gastos],
          ]),
      aoRecarregar: () {
        final janela = (
          inicio: janelaAte(fim, mesesDaSerie).first.valor,
          fim: fim.valor,
        );
        ref.invalidate(ganhosDoIntervaloProvider(janela));
        ref.invalidate(gastosDoIntervaloProvider(janela));
      },
      legenda: (_) => [
        ItemLegenda(rotulo: 'Ganhos', cor: esquema.primary),
        ItemLegenda(rotulo: 'Gastos', cor: esquema.error),
      ],
      construir: (serie) => _Linhas(serie: serie),
    );
  }
}

class _Linhas extends StatelessWidget {
  final List<PontoMensal> serie;
  const _Linhas({required this.serie});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    var maximo = 0.0;
    for (final p in serie) {
      if (p.ganhos > maximo) maximo = p.ganhos;
      if (p.gastos > maximo) maximo = p.gastos;
    }

    return LineChart(
      LineChartData(
        minY: 0,
        // Com tudo zerado o eixo ficaria sem escala; a moldura ja evita
        // chegar aqui, mas o 1 mantem o grafico valido de qualquer forma.
        maxY: maximo <= 0 ? 1 : maximo * 1.15,
        lineBarsData: [
          _serie([for (final (i, p) in serie.indexed) FlSpot(i.toDouble(), p.ganhos)],
              esquema.primary),
          _serie([for (final (i, p) in serie.indexed) FlSpot(i.toDouble(), p.gastos)],
              esquema.error),
        ],
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: eixoMensal(
          context: context,
          meses: [for (final p in serie) p.mes],
        ),
      ),
    );
  }

  LineChartBarData _serie(List<FlSpot> pontos, Color cor) => LineChartBarData(
        spots: pontos,
        color: cor,
        barWidth: 2,
        isCurved: false,
        dotData: const FlDotData(show: false),
      );
}
