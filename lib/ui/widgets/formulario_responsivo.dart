import 'package:flutter/material.dart';

import '../shell.dart' show breakpointDesktop;

/// Dialog no desktop, bottom sheet no mobile (spec 9). Devolve o valor
/// passado a Navigator.pop dentro de [construir], ou null se o usuario
/// dispensar sem concluir.
Future<T?> mostrarFormulario<T>({
  required BuildContext context,
  required String titulo,
  required WidgetBuilder construir,
}) {
  final desktop = MediaQuery.sizeOf(context).width >= breakpointDesktop;

  if (desktop) {
    return showDialog<T>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(child: construir(dialogo)),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (folha) => Padding(
      // Sobe o conteudo acima do teclado virtual.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(folha).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titulo, style: Theme.of(folha).textTheme.titleLarge),
              const SizedBox(height: 16),
              construir(folha),
            ],
          ),
        ),
      ),
    ),
  );
}
