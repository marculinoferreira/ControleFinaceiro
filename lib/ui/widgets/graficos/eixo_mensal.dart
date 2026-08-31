import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../dominio/models/mes_ref.dart';

/// Quantos rotulos de mes cabem no eixo sem colidir na largura de um
/// telefone. Doze "Ago/26" lado a lado viram uma mancha.
const int _rotulosVisiveis = 5;

/// Eixo X de mes, compartilhado pelos dois graficos de linha.
///
/// Rotula um mes a cada [_rotulosVisiveis], e sempre o ultimo — que e o mes
/// que ancora a leitura: "hoje" na evolucao, e o mes selecionado no
/// comprometimento.
FlTitlesData eixoMensal({
  required BuildContext context,
  required List<MesRef> meses,
}) {
  final passo = (meses.length / _rotulosVisiveis).ceil().clamp(1, 12);

  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: const AxisTitles(),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        interval: 1,
        getTitlesWidget: (valor, meta) {
          final i = valor.toInt();
          if (i < 0 || i >= meses.length) return const SizedBox.shrink();

          final ultimo = i == meses.length - 1;
          if (!ultimo && i % passo != 0) return const SizedBox.shrink();

          // O penultimo rotulo encostaria no ultimo; deixa o ultimo ganhar.
          if (!ultimo && i > meses.length - 1 - passo) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              meses[i].formatarCurto(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        },
      ),
    ),
  );
}
