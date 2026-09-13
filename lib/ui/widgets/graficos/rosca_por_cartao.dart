import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/graficos.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../../tema/tema.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';
import 'total_central_rosca.dart';

/// Gastos por cartao — grafico extra, fora da numeracao da spec 10.
///
/// Mesma linguagem visual da rosca de pote: furo central com o total, para
/// a pessoa nao precisar somar as fatias de cabeca. Cada fatia tambem ganha
/// uma linha externa com o valor em reais daquele cartao — a porcentagem
/// sozinha nao diz quanto foi gasto.
class RoscaPorCartao extends ConsumerWidget {
  const RoscaPorCartao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSelecionadoProvider).valor;

    return MolduraGrafico<List<Fatia>>(
      titulo: 'Gastos por cartão',
      vazio: 'Nenhum gasto neste mês.',
      // Anel menor que os outros graficos da tela (que usam o padrao de 240)
      // deixa espaco para a linha + valor de cada fatia sem cortar no card.
      // Um pouco mais alto que o minimo (280 em vez de 260) porque o rotulo
      // ganhou mais distancia do anel (raioRotulo maior, ver _Rosca).
      altura: 280,
      dados: ref.watch(fatiasPorCartaoProvider),
      estaVazio: (f) => f.isEmpty,
      aoRecarregar: () {
        ref.invalidate(cartoesProvider);
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

  /// Anel menor que o da rosca de pote (52/46): sobra espaco no mesmo card
  /// para a linha + rotulo de valor de cada fatia.
  static const double raioInterno = 44;
  static const double raioFatia = 38;

  /// Cadeia de raios compartilhada entre o rotulo (`_constroiRotulos`) e a
  /// linha de chamada (`_LinhasDeChamada`) -- uma unica fonte, para que os
  /// dois nunca desalinhem se algum dia o comprimento da linha mudar.
  ///
  /// A folga entre `raioLinha` e `raioRotulo` (16, nao so um respiro minimo)
  /// e de proposito: com pouca distancia o rotulo de uma fatia fina (poucos
  /// graus de arco) acaba visualmente colado no anel, parecendo que esta
  /// "em cima" da rosca em vez de apontado para fora dela.
  static const double raioAnel = raioInterno + raioFatia;
  static const double raioLinha = raioAnel + 16;
  static const double raioRotulo = raioLinha + 16;

  @override
  Widget build(BuildContext context) {
    final total = totalDasFatias(fatias);
    final corTexto = Theme.of(context).colorScheme.onSurface;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _LinhasDeChamada(
              fatias: fatias,
              total: total,
            ),
          ),
        ),
        PieChart(
          PieChartData(
            centerSpaceRadius: raioInterno,
            sectionsSpace: 2,
            sections: [
              for (final f in fatias)
                PieChartSectionData(
                  value: f.valor,
                  color: corDeHex(f.cor),
                  radius: raioFatia,
                  // O nome vai na legenda; repeti-lo na fatia embola o
                  // desenho quando ha varios cartoes.
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
        ..._constroiRotulos(total, corTexto),
        TotalCentralRosca(total: total, raioInterno: raioInterno),
      ],
    );
  }

  List<Widget> _constroiRotulos(double total, Color corTexto) {
    if (total <= 0) return [];

    final angulosPorFatia = _anguloMedioPorFatia(fatias, total);
    final rotulos = <Widget>[];

    for (int i = 0; i < fatias.length; i++) {
      final f = fatias[i];
      if (f.valor <= 0) continue;

      final anguloMedio = angulosPorFatia[i];
      final radianos = anguloMedio * math.pi / 180;

      final posicao = Offset(raioRotulo * math.cos(radianos),
          raioRotulo * math.sin(radianos));

      rotulos.add(
        Transform.translate(
          offset: posicao,
          child: Text(
            formatarReais(f.valor),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: corTexto,
            ),
          ),
        ),
      );
    }

    return rotulos;
  }

  /// Calcula o angulo medio (em graus) para cada fatia, em ordem.
  /// Implementa a acumulacao de graus comecando em 0 (eixo das 3 horas),
  /// sentido horario — a mesma formula usada pelo PieChartPainter do
  /// fl_chart por baixo dos panos. `fatias` precisa ser a mesma lista, na
  /// mesma ordem, usada para montar as `sections` do PieChart, para o
  /// angulo calculado aqui sempre bater com o que a biblioteca desenha. Usada
  /// tanto para posicionar os rotulos de valor (`_constroiRotulos`) quanto
  /// as linhas de chamada (`_LinhasDeChamada`).
  static List<double> _anguloMedioPorFatia(List<Fatia> fatias, double total) {
    if (total <= 0) return [];

    var acumulado = 0.0;
    final angulos = <double>[];

    for (final f in fatias) {
      final grausDaFatia = f.valor / total * 360;
      final anguloMedio = acumulado + grausDaFatia / 2;
      acumulado += grausDaFatia;
      angulos.add(anguloMedio);
    }

    return angulos;
  }

  /// Fatia menor que 5% nao recebe rotulo: o texto sairia maior que ela.
  String _percentual(double valor, double total) {
    if (total <= 0) return '';
    final pct = valor / total * 100;
    return pct < 5 ? '' : '${pct.toStringAsFixed(0)}%';
  }
}

/// Desenha, para cada fatia, apenas o TRACO da linha de chamada (da borda
/// do anel ate o raio onde o rotulo comeca) — o rotulo com o valor em reais
/// em si NAO e desenhado aqui: e um `Text` widget separado, construido por
/// `_Rosca._constroiRotulos`, para poder herdar tema/estilo de texto e ser
/// testado como qualquer outro widget. Esta classe cuida so do traco.
class _LinhasDeChamada extends CustomPainter {
  final List<Fatia> fatias;
  final double total;

  const _LinhasDeChamada({
    required this.fatias,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final centro = size.center(Offset.zero);
    final angulosPorFatia = _Rosca._anguloMedioPorFatia(fatias, total);

    for (int i = 0; i < fatias.length; i++) {
      final f = fatias[i];
      if (f.valor <= 0) continue;

      final anguloMedio = angulosPorFatia[i];
      final radianos = anguloMedio * math.pi / 180;
      final direcao = Offset(math.cos(radianos), math.sin(radianos));

      canvas.drawLine(
        centro + direcao * _Rosca.raioAnel,
        centro + direcao * _Rosca.raioLinha,
        Paint()
          ..color = corDeHex(f.cor)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinhasDeChamada oldDelegate) =>
      oldDelegate.fatias != fatias || oldDelegate.total != total;
}
