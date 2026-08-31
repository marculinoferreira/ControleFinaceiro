import 'package:flutter/material.dart';

/// Uma serie do grafico: o que ela representa e a cor com que foi pintada.
class ItemLegenda {
  final String rotulo;
  final Color cor;

  const ItemLegenda({required this.rotulo, required this.cor});
}

/// Quadradinho colorido mais o rotulo. Widget proprio (em vez de um Row
/// solto) para o teste conseguir contar as series e ler a cor de cada uma.
class MarcadorLegenda extends StatelessWidget {
  final ItemLegenda item;
  const MarcadorLegenda({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: item.cor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(item.rotulo, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Legenda em Wrap: com seis potes e nomes longos, uma Row estouraria a
/// largura no telefone.
class LegendaGrafico extends StatelessWidget {
  final List<ItemLegenda> itens;
  const LegendaGrafico({super.key, required this.itens});

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final item in itens) MarcadorLegenda(item: item),
      ],
    );
  }
}
