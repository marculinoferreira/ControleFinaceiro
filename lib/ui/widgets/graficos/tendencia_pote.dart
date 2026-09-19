import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart' show serieVazia;
import '../../../dominio/serie_mensal.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../../tema/tema.dart';
import '../moldura_grafico.dart';
import 'eixo_mensal.dart';

/// Tendencia de gasto de um pote especifico nos ultimos [mesesDaTendencia]
/// meses. Diferente dos outros graficos da Visao Geral, este tem um
/// seletor interno (o pote a analisar) -- por isso e um
/// `ConsumerStatefulWidget`, nao um `ConsumerWidget`: o pote escolhido e
/// estado local da tela, nao um provider global.
class TendenciaPote extends ConsumerStatefulWidget {
  const TendenciaPote({super.key});

  @override
  ConsumerState<TendenciaPote> createState() => _TendenciaPoteState();
}

class _TendenciaPoteState extends ConsumerState<TendenciaPote> {
  String? _poteSelecionadoId;

  @override
  Widget build(BuildContext context) {
    final potesAsync = ref.watch(potesProvider);
    final potes = potesAsync.value;

    // potesProvider ainda carregando ou com erro: sem a lista nao ha como
    // montar o seletor (o dropdown precisa de potes de verdade), mas o
    // proprio estado de loading/erro precisa passar pela MolduraGrafico --
    // assim como os outros graficos da Visao Geral que dependem de potes,
    // em vez de um `.when` proprio que derrubaria o widget inteiro (incluido
    // o card do seletor) e escondido do isolamento de erro da tela.
    if (potes == null) {
      return MolduraGrafico<List<PontoComprometido>>(
        titulo: 'Tendência por pote',
        vazio: 'Cadastre um pote para ver a tendência de gasto.',
        dados: potesAsync.whenData((_) => const <PontoComprometido>[]),
        estaVazio: (_) => true,
        legenda: (_) => [],
        aoRecarregar: () => ref.invalidate(potesProvider),
        construir: (_) => const SizedBox.shrink(),
      );
    }

    if (potes.isEmpty) {
      // Zero potes cadastrados e um AsyncData([]) normal, nao um erro --
      // caso diferente do ramo acima, que mantem o mesmo texto de "vazio".
      return MolduraGrafico<List<PontoComprometido>>(
        titulo: 'Tendência por pote',
        vazio: 'Cadastre um pote para ver a tendência de gasto.',
        dados: const AsyncData(<PontoComprometido>[]),
        estaVazio: (_) => true,
        legenda: (_) => [],
        aoRecarregar: () => ref.invalidate(potesProvider),
        construir: (_) => const SizedBox.shrink(),
      );
    }

    final selecionado = potes.any((p) => p.id == _poteSelecionadoId)
        ? _poteSelecionadoId!
        : potes.first.id;
    final poteAtual = potes.firstWhere((p) => p.id == selecionado);

    // `MolduraGrafico.subtitulo` e String, nao Widget -- nao ha slot ali
    // para um dropdown. O seletor de pote fica FORA da moldura, num
    // Card proprio acima dela, mantendo a moldura em si intocada.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButton<String>(
              value: selecionado,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final p in potes)
                  DropdownMenuItem(value: p.id, child: Text(p.nome)),
              ],
              onChanged: (novoId) =>
                  setState(() => _poteSelecionadoId = novoId),
            ),
          ),
        ),
        MolduraGrafico<List<PontoComprometido>>(
          titulo: 'Tendência por pote',
          vazio:
              'Nenhum gasto neste pote nos últimos $mesesDaTendencia meses.',
          dados: ref.watch(tendenciaPoteProvider(selecionado)),
          estaVazio: (serie) =>
              serie.isEmpty || serieVazia([for (final p in serie) p.valor]),
          aoRecarregar: () {
            ref.invalidate(potesProvider);
            ref.invalidate(tendenciaPoteProvider(selecionado));
          },
          legenda: (_) => [],
          construir: (serie) =>
              _Linha(serie: serie, cor: corDeHex(poteAtual.cor)),
        ),
      ],
    );
  }
}

class _Linha extends StatelessWidget {
  final List<PontoComprometido> serie;
  final Color cor;
  const _Linha({required this.serie, required this.cor});

  @override
  Widget build(BuildContext context) {
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
              for (final (i, p) in serie.indexed) FlSpot(i.toDouble(), p.valor),
            ],
            color: cor,
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
