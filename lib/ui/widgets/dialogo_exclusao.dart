import 'package:flutter/material.dart';

import '../../dados/repositorios.dart';
import '../../dominio/models/gasto.dart';

/// Pergunta como excluir uma parcela (spec 6.3). Devolve null se cancelar.
Future<ModoExclusao?> perguntarModoExclusao({
  required BuildContext context,
  required Gasto gasto,
}) {
  return showDialog<ModoExclusao>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('Excluir parcela'),
      content: Text(
        '"${gasto.descricao}" é a parcela ${gasto.rotuloParcela}. '
        'O que você quer excluir?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogo).pop(ModoExclusao.somenteEsta),
          child: const Text('Só esta parcela'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogo).pop(ModoExclusao.estaEFuturas),
          child: const Text('Esta e as futuras'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(ModoExclusao.todas),
          child: const Text('Todas as parcelas'),
        ),
      ],
    ),
  );
}

/// Traduz o modo escolhido na chamada certa do repositorio.
///
/// Um gasto sem compraId nao e parcelado — nesse caso qualquer modo significa
/// apagar aquele documento, e nao ha o que agrupar.
Future<void> aplicarExclusao({
  required RepositorioGastos repo,
  required Gasto gasto,
  required ModoExclusao modo,
}) {
  final compraId = gasto.compraId;
  if (!gasto.parcelado || compraId == null) {
    return repo.removerUma(gasto.id);
  }

  switch (modo) {
    case ModoExclusao.somenteEsta:
      // Nao renumera as demais: o historico da compra nao muda porque uma
      // parcela foi estornada (spec 6.3).
      return repo.removerUma(gasto.id);
    case ModoExclusao.estaEFuturas:
      return repo.removerDesta(compraId, gasto.parcela ?? 1);
    case ModoExclusao.todas:
      return repo.removerCompra(compraId);
  }
}
