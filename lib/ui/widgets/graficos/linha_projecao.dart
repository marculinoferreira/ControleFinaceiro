import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../dominio/serie_mensal.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';
import 'eixo_mensal.dart';

/// Projecao de saldo nos proximos 12 meses: renda projetada (repete o
/// ganho do mes selecionado) x gasto ja comprometido em parcelas.
/// Respeita o seletor de pessoa (Marcos/Silvia/Casal).
class LinhaProjecao extends ConsumerWidget {
  const LinhaProjecao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inicio = ref.watch(mesSelecionadoProvider);
    final esquema = Theme.of(context).colorScheme;

    return MolduraGrafico<List<PontoProjecao>>(
      titulo: 'Projeção de saldo',
      vazio: 'Cadastre um ganho ou uma parcela para ver a projeção.',
      dados: ref.watch(serieProjecaoProvider),
      estaVazio: (serie) =>
          serie.isEmpty ||
          serieVazia([for (final p in serie) ...[p.ganhos, p.gastos]]),
      aoRecarregar: () {
        ref.invalidate(ganhosDoMesProvider(inicio.valor));
        ref.invalidate(parceladosDesdeProvider(inicio.valor));
      },
      legenda: (_) => [
        ItemLegenda(rotulo: 'Renda projetada', cor: esquema.primary),
        ItemLegenda(rotulo: 'Gasto comprometido', cor: esquema.tertiary),
      ],
      rodape: (serie) {
        final negativos = serie.where((p) => p.saldo < 0).length;
        if (negativos == 0) return const SizedBox.shrink();
        return Text(
          '$negativos ${negativos == 1 ? 'mês fica' : 'meses ficam'} com saldo negativo',
          style: TextStyle(color: esquema.error, fontWeight: FontWeight.bold),
        );
      },
      construir: (serie) => _Linha(serie: serie),
    );
  }
}

class _Linha extends StatelessWidget {
  final List<PontoProjecao> serie;
  const _Linha({required this.serie});

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
        maxY: maximo <= 0 ? 1 : maximo * 1.15,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (i, p) in serie.indexed) FlSpot(i.toDouble(), p.ganhos),
            ],
            color: esquema.primary,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: [
              for (final (i, p) in serie.indexed) FlSpot(i.toDouble(), p.gastos),
            ],
            color: esquema.tertiary,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: true),
          ),
        ],
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: eixoMensal(
          context: context,
          meses: [for (final p in serie) p.mes],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (pontos) => [
              for (final p in pontos)
                LineTooltipItem(
                  formatarReais(p.y),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
