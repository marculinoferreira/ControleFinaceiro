import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/providers.dart';
import '../tema/formatadores.dart';

/// Faixa fixa abaixo da AppBar: Ganhos, Gastos e Saldo no mes, respeitando a
/// visao selecionada (Casal, Marcos ou Silvia).
/// Fica visivel em todas as telas autenticadas.
class BarraTotais extends ConsumerWidget {
  const BarraTotais({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totais = ref.watch(totaisDoMesProvider);
    final esquema = Theme.of(context).colorScheme;

    return Container(
      color: esquema.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: totais.when(
        loading: () => const SizedBox(
          height: 34,
          child: Center(
            child: SizedBox(
              height: 16, width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, _) => SizedBox(
          height: 34,
          child: Center(
            child: Text('Totais indisponiveis',
                style: TextStyle(color: esquema.error)),
          ),
        ),
        data: (t) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Item(
              chave: 'total_ganhos',
              rotulo: 'Ganhos',
              valor: t.ganhos,
              cor: esquema.primary,
            ),
            _Item(
              chave: 'total_gastos',
              rotulo: 'Gastos',
              valor: t.gastos,
              cor: esquema.error,
            ),
            _Item(
              chave: 'total_saldo',
              rotulo: 'Saldo do mes',
              valor: t.saldo,
              cor: t.saldo < 0 ? esquema.error : esquema.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String chave;
  final String rotulo;
  final double valor;
  final Color cor;

  const _Item({
    required this.chave,
    required this.rotulo,
    required this.valor,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key(chave),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rotulo, style: Theme.of(context).textTheme.labelSmall),
        Text(
          formatarReais(valor),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: cor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
