import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../estado/providers.dart';
import '../../tema/tema.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';
import 'total_central_rosca.dart';

/// Grafico 1 da spec 10: distribuicao de gastos por pote.
///
/// Rosca, e nao pizza: o furo central deixa espaco para o total, que e o
/// numero que a pessoa procura primeiro.
class RoscaPorPote extends ConsumerWidget {
  const RoscaPorPote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSelecionadoProvider).valor;

    return MolduraGrafico<List<Fatia>>(
      titulo: 'Gastos por pote',
      vazio: 'Nenhum gasto neste mês.',
      dados: ref.watch(fatiasPorPoteProvider),
      estaVazio: (f) => f.isEmpty,
      aoRecarregar: () {
        ref.invalidate(potesProvider);
        ref.invalidate(gastosDoMesProvider(mes));
      },
      legenda: (fatias) => [
        for (final f in fatias)
          ItemLegenda(rotulo: f.nome, cor: corDeHex(f.cor)),
      ],
      construir: (fatias) => _Rosca(fatias: fatias),
    );
  }
}

class _Rosca extends StatelessWidget {
  final List<Fatia> fatias;
  const _Rosca({required this.fatias});

  static const double raioInterno = 52;

  @override
  Widget build(BuildContext context) {
    final total = totalDasFatias(fatias);

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            centerSpaceRadius: raioInterno,
            sectionsSpace: 2,
            sections: [
              for (final f in fatias)
                PieChartSectionData(
                  value: f.valor,
                  color: corDeHex(f.cor),
                  radius: 46,
                  // O nome vai na legenda; repeti-lo na fatia embola o
                  // desenho quando ha seis potes.
                  title: _percentual(f.valor, total),
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        TotalCentralRosca(total: total, raioInterno: raioInterno),
      ],
    );
  }

  /// Fatia menor que 5% nao recebe rotulo: o texto sairia maior que ela.
  String _percentual(double valor, double total) {
    if (total <= 0) return '';
    final pct = valor / total * 100;
    return pct < 5 ? '' : '${pct.toStringAsFixed(0)}%';
  }
}
