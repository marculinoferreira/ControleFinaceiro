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
          children: [
            Expanded(
              child: _Item(
                chave: 'total_ganhos',
                rotulo: 'Ganhos',
                valor: t.ganhos,
                cor: esquema.primary,
                icone: Icons.arrow_upward,
                corSelo: Colors.green.shade600,
              ),
            ),
            Expanded(
              child: _Item(
                chave: 'total_gastos',
                rotulo: 'Gastos',
                valor: t.gastos,
                cor: esquema.error,
                icone: Icons.arrow_downward,
                corSelo: Colors.red.shade600,
              ),
            ),
            Expanded(
              child: _Item(
                chave: 'total_saldo',
                rotulo: 'Saldo do mes',
                valor: t.saldo,
                cor: t.saldo < 0 ? esquema.error : esquema.primary,
                icone: Icons.savings,
                corSelo: Colors.blue.shade600,
              ),
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
  final IconData icone;
  final Color corSelo;

  const _Item({
    required this.chave,
    required this.rotulo,
    required this.valor,
    required this.cor,
    required this.icone,
    required this.corSelo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key(chave),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: corSelo,
          child: Icon(icone, size: 13, color: Colors.white),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatarReais(valor),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: cor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
