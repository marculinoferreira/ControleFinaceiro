import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dados/repositorio_gestao_casa.dart';
import '../../dominio/models/casa.dart';
import '../../dominio/models/membro.dart';
import '../../estado/providers.dart';

class TelaGerenciarCasa extends ConsumerWidget {
  final String casaId;

  const TelaGerenciarCasa({
    super.key,
    required this.casaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casa = ref.watch(casaProvider).value;
    final membrosAtivos =
        casa?.membros.where((m) => m.removidoEm == null).toList() ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar casa')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('botao_convidar'),
        onPressed: () => _abrirConvite(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Convidar'),
      ),
      body: ListView.builder(
        itemCount: membrosAtivos.length,
        itemBuilder: (context, i) {
          final membro = membrosAtivos[i];
          final ehDono = casa != null && Casa.emailsIguais(membro.email, casa.donoEmail);
          return ListTile(
            title: Text(membro.nome),
            subtitle: Text(membro.email),
            trailing: ehDono
                ? const Chip(label: Text('Dono'))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('transferir_${membro.id}'),
                        tooltip: 'Transferir posse',
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: () =>
                            _confirmarTransferir(context, ref, membro),
                      ),
                      IconButton(
                        key: Key('remover_${membro.id}'),
                        tooltip: 'Remover',
                        icon: const Icon(Icons.person_remove),
                        onPressed: () =>
                            _confirmarRemover(context, ref, membro),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Future<void> _abrirConvite(BuildContext context, WidgetRef ref) async {
    final email = TextEditingController();
    final nome = TextEditingController();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Convidar membro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('campo_nome_convite'),
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              key: const Key('campo_email_convite'),
              controller: email,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('botao_confirmar_convite'),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Convidar'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(repositorioGestaoCasaProvider).convidarMembro(
            casaId: casaId,
            email: email.text.trim(),
            nome: nome.text.trim(),
          );
    } on ErroGestaoCasa catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  Future<void> _confirmarRemover(
    BuildContext context,
    WidgetRef ref,
    Membro membro,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Remover membro'),
        content: Text(
          'Remover ${membro.nome} da casa? A pessoa recebe um aviso por '
          'e-mail e pode criar a própria casa depois — os dados dela ficam '
          'guardados por 30 dias.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!context.mounted) return;

    try {
      await ref
          .read(repositorioGestaoCasaProvider)
          .removerMembro(casaId: casaId, membroId: membro.id);
    } on ErroGestaoCasa catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  Future<void> _confirmarTransferir(
    BuildContext context,
    WidgetRef ref,
    Membro membro,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Transferir posse'),
        content: Text('Tornar ${membro.nome} o novo dono desta casa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(repositorioGestaoCasaProvider).transferirPosse(
            casaId: casaId,
            novoDonoMembroId: membro.id,
          );
    } on ErroGestaoCasa catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }
}
