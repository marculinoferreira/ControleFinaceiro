import 'package:flutter/material.dart';

import '../../dominio/models/gasto.dart';
import '../../dominio/parcelas.dart';

/// Pergunta a que parcelas aplicar o novo valor. Devolve null se cancelar.
///
/// Gemeo de `perguntarModoExclusao`, com os mesmos tres modos e a mesma
/// ordem de botoes: a escolha "so esta / esta e as futuras / todas" e a
/// mesma ideia nos dois casos, e trocar a ordem aqui faria a mao errar.
///
/// So o valor chega aqui. Descricao, pessoa e pote vao para a compra inteira
/// sem perguntar, e a quantidade tambem — nos dois casos as tres opcoes
/// fariam a mesma coisa, e um dialogo sem escolha e so um clique a mais.
Future<ModoEdicao?> perguntarModoEdicao({
  required BuildContext context,
  required Gasto gasto,
}) {
  return showDialog<ModoEdicao>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('Alterar o valor'),
      content: Text(
        '"${gasto.descricao}" é a parcela ${gasto.rotuloParcela}. '
        'O novo valor vale para quais parcelas?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const Key('edicao_somente_esta'),
          onPressed: () => Navigator.of(dialogo).pop(ModoEdicao.somenteEsta),
          child: const Text('Só esta parcela'),
        ),
        TextButton(
          key: const Key('edicao_esta_e_futuras'),
          onPressed: () => Navigator.of(dialogo).pop(ModoEdicao.estaEFuturas),
          child: const Text('Esta e as futuras'),
        ),
        TextButton(
          key: const Key('edicao_todas'),
          onPressed: () => Navigator.of(dialogo).pop(ModoEdicao.todas),
          child: const Text('Todas as parcelas'),
        ),
      ],
    ),
  );
}
