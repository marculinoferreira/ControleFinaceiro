import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../dominio/models/membro.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../../tema/tema.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';

/// Comparativo: gasto por pote, as duas pessoas da casa lado a lado.
class BarrasPoteComparativo extends ConsumerWidget {
  const BarrasPoteComparativo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSelecionadoProvider).valor;
    final dupla = ref.watch(duplaComparativaProvider);

    return MolduraGrafico<List<BarraComparativa>>(
      titulo: 'Gasto por pote',
      vazio: 'Nenhum gasto de nenhuma das duas pessoas neste mês.',
      dados: ref.watch(barrasPoteComparativoProvider),
      estaVazio: (b) =>
          b.isEmpty || serieVazia([for (final x in b) ...[x.valorA, x.valorB]]),
      aoRecarregar: () {
        ref.invalidate(potesProvider);
        ref.invalidate(gastosDoMesProvider(mes));
      },
      legenda: (_) => dupla.length < 2
          ? []
          : [
              ItemLegenda(rotulo: dupla[0].nome, cor: corDeHex(dupla[0].cor)),
              ItemLegenda(rotulo: dupla[1].nome, cor: corDeHex(dupla[1].cor)),
            ],
      construir: (barras) => _Barras(barras: barras, dupla: dupla),
    );
  }
}

class _Barras extends StatelessWidget {
  final List<BarraComparativa> barras;
  final List<Membro> dupla;
  const _Barras({required this.barras, required this.dupla});

  @override
  Widget build(BuildContext context) {
    var maximo = 0.0;
    for (final b in barras) {
      if (b.valorA > maximo) maximo = b.valorA;
      if (b.valorB > maximo) maximo = b.valorB;
    }
    final teto = maximo <= 0 ? 1.0 : maximo * 1.1;

    final corA = corDeHex(dupla[0].cor);
    final corB = corDeHex(dupla[1].cor);
    final nomeA = dupla[0].nome;
    final nomeB = dupla[1].nome;

    return BarChart(
      BarChartData(
        maxY: teto,
        barGroups: [
          for (final (i, b) in barras.indexed)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                BarChartRodData(
                  toY: b.valorA,
                  color: corA,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
                BarChartRodData(
                  toY: b.valorB,
                  color: corB,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (grupo, iGrupo, rod, iRod) {
              if (iGrupo < 0 || iGrupo >= barras.length) return null;
              final barra = barras[iGrupo];
              final quem = iRod == 0 ? nomeA : nomeB;
              return BarTooltipItem(
                '${barra.nome}\n$quem: ${formatarReais(rod.toY)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (valor, meta) {
                final i = valor.toInt();
                if (i < 0 || i >= barras.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _abreviar(barras[i].nome),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _abreviar(String nome) =>
      nome.length <= 8 ? nome : '${nome.substring(0, 7)}…';
}
