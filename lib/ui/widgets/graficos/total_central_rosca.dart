import 'package:flutter/material.dart';

import '../../tema/formatadores.dart';

/// Total no furo central de uma rosca (RoscaPorPote, RoscaPorCartao).
///
/// O furo tem raio fixo ([raioInterno]), mas o valor formatado pode ter
/// qualquer numero de digitos -- um total de R$ 11.776,19 e bem mais largo
/// que R$ 100,00. Sem limite, o texto vaza por cima das fatias da rosca.
/// `FittedBox` com `scaleDown` encolhe o rotulo e o valor juntos (mantendo a
/// proporcao entre os dois) o quanto precisar para caber numa caixa que
/// sempre cabe dentro do furo, em vez de deixar o texto crescer livre.
class TotalCentralRosca extends StatelessWidget {
  final double total;
  final double raioInterno;

  const TotalCentralRosca({
    super.key,
    required this.total,
    required this.raioInterno,
  });

  @override
  Widget build(BuildContext context) {
    // Lado da caixa quadrada inscrita no furo, com folga: a metade da
    // diagonal do quadrado (lado * sqrt(2) / 2 ~= lado * 0.707) fica bem
    // abaixo de raioInterno, entao a caixa nunca encosta na borda do furo
    // mesmo sem precisar encolher (0.707 * 1.3 ~= 0.92, ainda < 1).
    final lado = raioInterno * 1.3;

    return SizedBox(
      key: const Key('total_central_caixa'),
      width: lado,
      height: lado,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
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
      ),
    );
  }
}
