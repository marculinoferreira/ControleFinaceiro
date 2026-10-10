import 'package:flutter/material.dart';

/// Botao fixo de "adicionar", no topo da tela -- mesma margem e cantos
/// arredondados de um Card comum de conteudo, com o texto alinhado a
/// esquerda, em vez de um FloatingActionButton flutuante sobre a lista.
class BotaoNovo extends StatelessWidget {
  final String rotulo;
  final VoidCallback? aoTocar;

  const BotaoNovo({super.key, required this.rotulo, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final habilitado = aoTocar != null;
    final corDesabilitada = Theme.of(context).disabledColor;

    return Card(
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.add, color: habilitado ? null : corDesabilitada),
              const SizedBox(width: 8),
              Text(
                rotulo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: habilitado ? null : corDesabilitada,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
