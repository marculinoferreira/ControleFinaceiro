import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dados/repositorio_gestao_casa.dart';
import '../../estado/providers.dart';

class TelaCriarCasa extends ConsumerStatefulWidget {
  const TelaCriarCasa({super.key});

  @override
  ConsumerState<TelaCriarCasa> createState() => _TelaCriarCasaState();
}

class _TelaCriarCasaState extends ConsumerState<TelaCriarCasa> {
  final _nome = TextEditingController();
  String? _erro;
  bool _criando = false;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Informe o nome da casa.');
      return;
    }

    setState(() {
      _erro = null;
      _criando = true;
    });

    try {
      await ref.read(repositorioGestaoCasaProvider).criarCasa(nome);
      ref.invalidate(casaIdProvider);
    } on ErroGestaoCasa catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _criando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Criar sua casa',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Esta será a sua casa no Controle Financeiro. Você pode '
                  'convidar outras pessoas depois.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('campo_nome_casa'),
                  controller: _nome,
                  decoration: const InputDecoration(
                    labelText: 'Nome da casa',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _erro!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('botao_criar_casa'),
                  onPressed: _criando ? null : _criar,
                  child: _criando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Criar casa'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
