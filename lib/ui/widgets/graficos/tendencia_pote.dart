import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart' show serieVazia;
import '../../../dominio/models/mes_ref.dart';
import '../../../dominio/models/pote.dart';
import '../../../dominio/serie_mensal.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../../tema/tema.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';
import 'eixo_mensal.dart';

/// Tendencia de gasto de TODOS os potes nos ultimos [mesesDaTendencia]
/// meses: uma linha por pote, cada uma com a cor ja cadastrada daquele
/// pote, e uma legenda embaixo com nome + cor de cada um.
class TendenciaPote extends ConsumerWidget {
  const TendenciaPote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final potesAsync = ref.watch(potesProvider);
    final potes = potesAsync.value;

    // potesProvider ainda carregando ou com erro: sem a lista nao ha como
    // montar a legenda (precisa do nome/cor de cada pote), mas o proprio
    // estado de loading/erro precisa passar pela MolduraGrafico -- assim
    // como os outros graficos da Visao Geral que dependem de potes, em vez
    // de um `.when` proprio que derrubaria o widget inteiro e escaparia do
    // isolamento de erro da tela.
    if (potes == null) {
      return MolduraGrafico<Map<String, List<PontoComprometido>>>(
        titulo: 'Tendência por pote',
        vazio: 'Cadastre um pote para ver a tendência de gasto.',
        dados: potesAsync.whenData((_) => const <String, List<PontoComprometido>>{}),
        estaVazio: (_) => true,
        legenda: (_) => [],
        aoRecarregar: () => ref.invalidate(potesProvider),
        construir: (_) => const SizedBox.shrink(),
      );
    }

    if (potes.isEmpty) {
      // Zero potes cadastrados e um AsyncData({}) normal, nao um erro --
      // caso diferente do ramo acima, que mantem o mesmo texto de "vazio".
      return MolduraGrafico<Map<String, List<PontoComprometido>>>(
        titulo: 'Tendência por pote',
        vazio: 'Cadastre um pote para ver a tendência de gasto.',
        dados: const AsyncData(<String, List<PontoComprometido>>{}),
        estaVazio: (_) => true,
        legenda: (_) => [],
        aoRecarregar: () => ref.invalidate(potesProvider),
        construir: (_) => const SizedBox.shrink(),
      );
    }

    final fim = ref.watch(mesSelecionadoProvider);
    final meses = janelaAte(fim, mesesDaTendencia);
    final janela = (inicio: meses.first.valor, fim: fim.valor);

    return MolduraGrafico<Map<String, List<PontoComprometido>>>(
      titulo: 'Tendência por pote',
      vazio: 'Nenhum gasto nos últimos $mesesDaTendencia meses.',
      // Uma faixa por pote (cada uma com o proprio zero, escala propria):
      // cresce com a quantidade de potes, senao as faixas ficam
      // espremidas demais pra distinguir uma da outra.
      altura: 64.0 * potes.length,
      dados: ref.watch(tendenciaTodosPotesProvider),
      estaVazio: (porPote) => serieVazia([
        for (final serie in porPote.values)
          for (final p in serie) p.valor,
      ]),
      aoRecarregar: () {
        ref.invalidate(potesProvider);
        ref.invalidate(tendenciaTodosPotesProvider);
        ref.invalidate(gastosDoIntervaloProvider(janela));
      },
      legenda: (_) => [
        for (final p in potes) ItemLegenda(rotulo: p.nome, cor: corDeHex(p.cor)),
      ],
      construir: (porPote) => _Linhas(meses: meses, potes: potes, porPote: porPote),
    );
  }
}

/// Fracao da faixa (0 a 1) que a linha pode ocupar acima da propria base --
/// o resto fica de folga ate a base da faixa de cima, pra elas nunca se
/// encostarem mesmo no pico.
const double _amplitudeDaFaixa = 0.8;

/// Uma faixa por pote, cada uma com o proprio zero (uma linha horizontal
/// cinza) e a propria escala -- assim um pote de R$200 fica tao legivel
/// quanto um de R$5.000 na mesma tela, em vez de todos disputarem o mesmo
/// eixo e os menores colarem uns nos outros perto do zero comum.
class _Linhas extends StatelessWidget {
  final List<MesRef> meses;
  final List<Pote> potes;
  final Map<String, List<PontoComprometido>> porPote;

  const _Linhas({required this.meses, required this.potes, required this.porPote});

  /// A base da faixa do pote de indice [i] (0 = primeiro pote, no topo).
  /// O primeiro pote fica na faixa mais alta, o ultimo na faixa 0 -- por
  /// isso a conta e invertida.
  double _baseDaFaixa(int i) => (potes.length - 1 - i).toDouble();

  @override
  Widget build(BuildContext context) {
    final maximoPorPote = {
      for (final pote in potes)
        pote.id: (porPote[pote.id] ?? const <PontoComprometido>[])
            .fold(0.0, (m, p) => p.valor > m ? p.valor : m),
    };

    double normalizar(Pote pote, double valor) {
      final maximo = maximoPorPote[pote.id] ?? 0;
      if (maximo <= 0) return 0;
      return (valor / maximo) * _amplitudeDaFaixa;
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: potes.length.toDouble(),
        lineBarsData: [
          for (final (i, pote) in potes.indexed)
            LineChartBarData(
              spots: [
                for (final (j, p) in (porPote[pote.id] ?? const <PontoComprometido>[]).indexed)
                  FlSpot(j.toDouble(), _baseDaFaixa(i) + normalizar(pote, p.valor)),
              ],
              color: corDeHex(pote.cor),
              barWidth: 2,
              isCurved: false,
              dotData: const FlDotData(show: true),
            ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            for (var i = 0; i < potes.length; i++)
              HorizontalLine(y: _baseDaFaixa(i), color: Colors.grey.shade400),
          ],
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: eixoMensal(context: context, meses: meses),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (pontos) => [
              for (final p in pontos) _itemTooltip(p),
            ],
          ),
        ),
      ),
    );
  }

  /// O `y` de um `LineBarSpot` e a posicao normalizada dentro da faixa, nao
  /// o valor real -- pra mostrar o valor certo no toque, busca de volta em
  /// [porPote] pelo pote (`barIndex`, mesma ordem de [potes]) e pelo mes
  /// (`x`, o mesmo indice usado pra montar os spots).
  LineTooltipItem _itemTooltip(LineBarSpot p) {
    final pote = potes[p.barIndex];
    final serie = porPote[pote.id] ?? const <PontoComprometido>[];
    final indice = p.x.round();
    final valor = indice >= 0 && indice < serie.length ? serie[indice].valor : 0.0;
    return LineTooltipItem(
      '${pote.nome}: ${formatarReais(valor)}',
      const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }
}
