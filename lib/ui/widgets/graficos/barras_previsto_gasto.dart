import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../../tema/tema.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';

/// Grafico 2 da spec 10: Previsto x Gasto por pote.
///
/// Duas barras por pote. A de previsto usa a cor do pote esmaecida e a de
/// gasto a cor cheia, para as duas se lerem como o mesmo assunto — e para
/// a barra de gasto passando da de previsto ser obvia.
class BarrasPrevistoGasto extends ConsumerWidget {
  const BarrasPrevistoGasto({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSelecionadoProvider).valor;
    final esquema = Theme.of(context).colorScheme;

    return MolduraGrafico<List<BarraPote>>(
      titulo: 'Previsto × Gasto por pote',
      vazio: 'Cadastre seus potes e lance ganhos para ver o previsto.',
      dados: ref.watch(barrasPorPoteProvider),
      // Mes sem renda e sem gasto daria um grafico de barras de altura
      // zero, que parece defeito. A frase diz mais.
      estaVazio: (b) =>
          b.isEmpty ||
          serieVazia([
            for (final x in b) ...[x.previsto, x.gasto],
          ]),
      aoRecarregar: () {
        ref.invalidate(potesProvider);
        ref.invalidate(gastosDoMesProvider(mes));
      },
      legenda: (_) => [
        ItemLegenda(rotulo: 'Previsto', cor: esquema.outlineVariant),
        ItemLegenda(rotulo: 'Gasto', cor: esquema.primary),
      ],
      construir: (barras) => _Barras(barras: barras),
    );
  }
}

class _Barras extends StatelessWidget {
  final List<BarraPote> barras;
  const _Barras({required this.barras});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    // Uma folga de 10% no topo evita a barra mais alta encostar na borda.
    // Com tudo zerado (mes sem renda e sem gasto) o teto seria 0 e o
    // fl_chart nao teria escala nenhuma; 1 mantem o eixo valido.
    final teto = tetoDasBarras(barras);
    final maximo = teto <= 0 ? 1.0 : teto * 1.1;

    return BarChart(
      BarChartData(
        maxY: maximo,
        barGroups: [
          for (final (i, b) in barras.indexed)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                BarChartRodData(
                  toY: b.previsto,
                  color: corDeHex(b.cor).withValues(alpha: 0.35),
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3)),
                ),
                BarChartRodData(
                  toY: b.gasto,
                  // Estourou o pote: vermelho, para nao depender de o olho
                  // comparar duas alturas parecidas.
                  color: b.estourou ? esquema.error : corDeHex(b.cor),
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3)),
                ),
              ],
            ),
        ],
        // Sem isto o fl_chart usa o tooltip padrao: caixa escura com texto
        // escuro (ilegivel) e o valor cru, tipo "1387.4". O rotulo do eixo e
        // abreviado por falta de espaco, entao o tooltip e o unico lugar que
        // mostra o nome do pote inteiro.
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (grupo, iGrupo, rod, iRod) {
              if (iGrupo < 0 || iGrupo >= barras.length) return null;
              final barra = barras[iGrupo];
              final qual = iRod == 0 ? 'Previsto' : 'Gasto';
              return BarTooltipItem(
                '${barra.nome}\n$qual: ${formatarReais(rod.toY)}',
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

  /// "Conhecimento" nao cabe sob uma barra de 22px no telefone. A legenda
  /// nao ajuda aqui (ela distingue previsto de gasto, nao os potes), entao
  /// o corte precisa manter o comeco reconhecivel.
  String _abreviar(String nome) =>
      nome.length <= 8 ? nome : '${nome.substring(0, 7)}…';
}
