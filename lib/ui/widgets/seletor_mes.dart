import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/providers.dart';

class SeletorMes extends ConsumerWidget {
  const SeletorMes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSelecionadoProvider);
    final notifier = ref.read(mesSelecionadoProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('mes_anterior'),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Mes anterior',
          onPressed: () => notifier.avancar(-1),
        ),
        SizedBox(
          width: 150,
          child: Text(
            mes.formatarExtenso(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const Key('mes_proximo'),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Proximo mes',
          onPressed: () => notifier.avancar(1),
        ),
      ],
    );
  }
}
