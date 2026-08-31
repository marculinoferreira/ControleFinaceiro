import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../estado/providers.dart';
import '../../tema/tema.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';

/// Grafico 4 da spec 10: proporcao de ganhos entre as pessoas da casa.
///
/// Pizza cheia, sem furo — ao contrario da rosca de gastos. A diferenca de
/// forma ajuda a nao confundir os dois circulos na mesma tela.
///
/// Ignora o seletor de visao, e diz isso no subtitulo: filtrado por pessoa
/// o grafico viraria uma fatia unica de 100%.
class PizzaGanhos extends ConsumerWidget {
  const PizzaGanhos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSelecionadoProvider).valor;

    return MolduraGrafico<List<Fatia>>(
      titulo: 'Ganhos por pessoa',
      subtitulo: 'do casal, independente da visão',
      vazio: 'Nenhum ganho lançado neste mês.',
      dados: ref.watch(fatiasPorMembroProvider),
      estaVazio: (f) => f.isEmpty,
      aoRecarregar: () {
        ref.invalidate(casaProvider);
        ref.invalidate(ganhosDoMesProvider(mes));
      },
      legenda: (fatias) => [
        for (final f in fatias)
          ItemLegenda(rotulo: f.nome, cor: corDeHex(f.cor)),
      ],
      construir: (fatias) => _Pizza(fatias: fatias),
    );
  }
}

class _Pizza extends StatelessWidget {
  final List<Fatia> fatias;
  const _Pizza({required this.fatias});

  @override
  Widget build(BuildContext context) {
    final total = totalDasFatias(fatias);

    return PieChart(
      PieChartData(
        centerSpaceRadius: 0,
        sectionsSpace: 2,
        sections: [
          for (final f in fatias)
            PieChartSectionData(
              value: f.valor,
              color: corDeHex(f.cor),
              radius: 90,
              title: total <= 0
                  ? ''
                  : '${(f.valor / total * 100).toStringAsFixed(0)}%',
              titleStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
