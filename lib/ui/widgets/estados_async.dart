import 'package:flutter/material.dart';

/// Skeleton com a forma do conteudo, em vez de um spinner centralizado:
/// o layout nao pula quando os dados chegam.
class CarregandoLista extends StatelessWidget {
  final int linhas;
  const CarregandoLista({super.key, this.linhas = 5});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: linhas,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 56,
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class ErroComRecarregar extends StatelessWidget {
  final Object erro;
  final VoidCallback aoRecarregar;

  const ErroComRecarregar({
    super.key,
    required this.erro,
    required this.aoRecarregar,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 40, color: esquema.error),
            const SizedBox(height: 12),
            Text(
              'Nao foi possivel carregar os dados.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '$erro',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: aoRecarregar,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
