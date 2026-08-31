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

/// Mostra um SnackBar de erro para uma escrita que falhou -- permissao
/// negada, commit que nunca chega ao servidor offline etc. A spec so
/// especifica o tratamento de falha de LEITURA (o par loading/error do
/// AsyncValue.when); escrita nao tem uma contrapartida estruturada, entao
/// isto e o minimo: avisar em portugues em vez de deixar a tela parada sem
/// explicacao nenhuma.
void avisarErroDeEscrita(BuildContext context, Object erro) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Não foi possível salvar. Verifique sua conexão e '
          'tente novamente.'),
    ),
  );
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
