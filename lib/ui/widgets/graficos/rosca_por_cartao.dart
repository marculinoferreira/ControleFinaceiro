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
      altura: 260,
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

  @override
  Widget build(BuildContext context) {
    final total = totalDasFatias(fatias);
    final corTexto =
        Theme.of(context).textTheme.bodySmall?.color ?? Colors.black87;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _LinhasDeChamada(
              fatias: fatias,
              total: total,
              corTexto: corTexto,
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
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total', style: Theme.of(context).textTheme.bodySmall),
            Text(
              formatarReais(total),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
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

      const raioAnel = raioInterno + raioFatia;
      const raioRotulo = raioAnel + 12 + 10;

      final posicao = Offset(raioRotulo * math.cos(radianos),
          raioRotulo * math.sin(radianos));

      rotulos.add(
        Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: posicao,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: Text(
                formatarReais(f.valor),
                style: TextStyle(fontSize: 10, color: corTexto),
              ),
            ),
          ),
        ),
      );
    }

    return rotulos;
  }

  /// Calcula o angulo medio (em graus) para cada fatia, em ordem.
  /// Implementa a acumulacao de graus comecando em 0 (eixo das 3 horas),
  /// sentido horario — a mesma formula usada pelo PieChartPainter do fl_chart.
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

/// Desenha, para cada fatia, uma linha saindo da borda do anel ate um
/// rotulo com o valor em reais — a porcentagem dentro da fatia nao diz
/// quanto foi gasto em cada cartao.
///
/// O angulo de cada fatia e recalculado aqui com a MESMA formula que o
/// PieChartPainter do fl_chart usa por baixo dos panos (soma cumulativa de
/// graus, comecando em 0 = eixo das 3 horas, sentido horario). `fatias` e a
/// mesma lista, na mesma ordem, usada para montar as `sections` do
/// PieChart logo acima — o angulo calculado aqui sempre bate com o que a
/// biblioteca desenha.
class _LinhasDeChamada extends CustomPainter {
  final List<Fatia> fatias;
  final double total;
  final Color corTexto;

  const _LinhasDeChamada({
    required this.fatias,
    required this.total,
    required this.corTexto,
  });

  static const double _raioAnel = _Rosca.raioInterno + _Rosca.raioFatia;
  static const double _raioLinha = _raioAnel + 12;

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
        centro + direcao * _raioAnel,
        centro + direcao * _raioLinha,
        Paint()
          ..color = corDeHex(f.cor)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinhasDeChamada oldDelegate) =>
      oldDelegate.fatias != fatias ||
      oldDelegate.total != total ||
      oldDelegate.corTexto != corTexto;
}
