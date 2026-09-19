import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../dominio/serie_mensal.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../../tema/tema.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';
import 'eixo_mensal.dart';

/// Comparativo: parcelas comprometidas nos proximos 12 meses, as duas
/// pessoas da casa lado a lado (duas linhas, mesmo eixo do grafico de
/// Comprometido da Visao Geral).
class LinhaComprometimentoComparativo extends ConsumerWidget {
  const LinhaComprometimentoComparativo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inicio = ref.watch(mesSelecionadoProvider);
    final dupla = ref.watch(duplaComparativaProvider);

    return MolduraGrafico<(List<PontoComprometido>, List<PontoComprometido>)>(
      titulo: 'Comprometido nos próximos $mesesDaSerie meses',
      vazio: 'Nenhuma parcela em aberto daqui para a frente.',
      dados: ref.watch(serieComprometimentoComparativoProvider),
      estaVazio: (par) {
        final (serieA, serieB) = par;
        return serieA.isEmpty ||
            serieVazia([
              for (final p in serieA) p.valor,
              for (final p in serieB) p.valor,
            ]);
      },
      aoRecarregar: () => ref.invalidate(parceladosDesdeProvider(inicio.valor)),
      legenda: (_) => dupla.length < 2
          ? []
          : [
              ItemLegenda(rotulo: dupla[0].nome, cor: corDeHex(dupla[0].cor)),
              ItemLegenda(rotulo: dupla[1].nome, cor: corDeHex(dupla[1].cor)),
            ],
      construir: (par) => _Linha(
        serieA: par.$1,
        serieB: par.$2,
        corA: dupla.length < 2 ? Colors.grey : corDeHex(dupla[0].cor),
        corB: dupla.length < 2 ? Colors.grey : corDeHex(dupla[1].cor),
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final List<PontoComprometido> serieA;
  final List<PontoComprometido> serieB;
  final Color corA;
  final Color corB;

  const _Linha({
    required this.serieA,
    required this.serieB,
    required this.corA,
    required this.corB,
  });

  @override
  Widget build(BuildContext context) {
    var maximo = 0.0;
    for (final p in [...serieA, ...serieB]) {
      if (p.valor > maximo) maximo = p.valor;
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maximo <= 0 ? 1 : maximo * 1.15,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (i, p) in serieA.indexed) FlSpot(i.toDouble(), p.valor),
            ],
            color: corA,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: [
              for (final (i, p) in serieB.indexed) FlSpot(i.toDouble(), p.valor),
            ],
            color: corB,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: true),
          ),
        ],
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: eixoMensal(
          context: context,
          meses: [for (final p in serieA) p.mes],
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
