import 'package:flutter/material.dart';

/// Subtitulo do card de um lancamento (Gastos, Parcelas): pessoa | pote |
/// cartao · parcela, cada um com um icone pequeno na frente. Usa "|" pra
/// separar pessoa/pote/cartao (pedido do usuario) e "·" so pra colar a
/// parcela ao cartao, ja que os dois vem do mesmo pagamento.
///
/// Cartao e parcela sao omitidos quando vazios (gasto em dinheiro, ou nao
/// parcelado) -- sem isso a versao antiga (juntar tudo com " · ") deixava
/// pontos duplicados na tela ("Custo fixo ·  · ").
///
/// A linha inteira fica dentro de um `FittedBox`: numa tela estreita, ela
/// encolhe pra caber numa unica linha em vez de estourar ou quebrar --
/// exatamente o "o texto se redimensiona conforme a largura do celular"
/// pedido.
Widget subtituloDoLancamento({
  required BuildContext context,
  required String nomeMembro,
  required String nomePote,
  required String nomeCartao,
  required String rotuloParcela,
  // So Parcelas usa: quantos meses faltam, colado no fim da linha. Gastos
  // nunca passa isso (nao tem "quanto falta" pra um gasto avulso).
  String? extra,
}) {
  final esquema = Theme.of(context).colorScheme;
  final estilo = Theme.of(context).textTheme.bodyMedium;

  Widget item(IconData icone, String texto) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: esquema.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(texto, style: estilo),
        ],
      );

  Widget separador() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('|', style: estilo?.copyWith(color: esquema.outlineVariant)),
      );

  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        item(Icons.person_outline, nomeMembro),
        separador(),
        item(Icons.sell_outlined, nomePote),
        if (nomeCartao.isNotEmpty) ...[
          separador(),
          item(
            Icons.credit_card,
            rotuloParcela.isEmpty ? nomeCartao : '$nomeCartao · $rotuloParcela',
          ),
        ] else if (rotuloParcela.isNotEmpty) ...[
          separador(),
          Text(rotuloParcela, style: estilo),
        ],
        if (extra != null && extra.isNotEmpty) ...[
          separador(),
          Text(extra, style: estilo),
        ],
      ],
    ),
  );
}
