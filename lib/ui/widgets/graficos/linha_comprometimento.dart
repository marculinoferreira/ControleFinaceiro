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

/// Grafico 6 da spec 10: quanto dos proximos meses ja esta comprometido em
/// parcelas.
///
/// O dado sai de graca da decisao de tratar cada parcela como documento
/// real: nao ha projecao nem estimativa aqui, sao lancamentos que existem.
class LinhaComprometimento extends ConsumerWidget {
  const LinhaComprometimento({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esquema = Theme.of(context).colorScheme;
    final inicio = ref.watch(mesSelecionadoProvider);

    return MolduraGrafico<List<PontoComprometido>>(
      titulo: 'Comprometido nos próximos $mesesDaSerie meses',
      vazio: 'Nenhuma parcela em aberto daqui para a frente.',
      dados: ref.watch(serieComprometimentoProvider),
      estaVazio: (serie) =>
          serie.isEmpty || serieVazia([for (final p in serie) p.valor]),
      aoRecarregar: () => ref.invalidate(parceladosDesdeProvider(inicio.valor)),
      legenda: (_) => [
        ItemLegenda(rotulo: 'Parcelas a pagar', cor: esquema.tertiary),
      ],
      construir: (serie) => _Linha(serie: serie),
    );
  }
}

class _Linha extends StatelessWidget {
  final List<PontoComprometido> serie;
  const _Linha({required this.serie});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    var maximo = 0.0;
    for (final p in serie) {
      if (p.valor > maximo) maximo = p.valor;
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maximo <= 0 ? 1 : maximo * 1.15,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (i, p) in serie.indexed)
                FlSpot(i.toDouble(), p.valor),
            ],
            color: esquema.tertiary,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: true),
            // A area preenchida ajuda a ler "isto ja esta tomado", que e
            // diferente de "isto foi gasto".
            belowBarData: BarAreaData(
              show: true,
              color: esquema.tertiary.withValues(alpha: 0.15),
            ),
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
                  Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
