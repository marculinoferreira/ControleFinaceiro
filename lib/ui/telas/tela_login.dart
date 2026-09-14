import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dados/servico_auth.dart';
import '../../estado/providers.dart';

class TelaLogin extends ConsumerStatefulWidget {
  const TelaLogin({super.key});

  @override
  ConsumerState<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends ConsumerState<TelaLogin> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  String? _erro;
  bool _entrando = false;
  bool _entrandoComGoogle = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _erro = 'Informe o e-mail.');
      return;
    }
    if (_senha.text.isEmpty) {
      setState(() => _erro = 'Informe a senha.');
      return;
    }

    setState(() {
      _erro = null;
      _entrando = true;
    });

    try {
      await ref.read(servicoAuthProvider).entrar(
            email: _email.text,
            senha: _senha.text,
          );
    } on ErroAuth catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  Future<void> _entrarComGoogle() async {
    setState(() {
      _erro = null;
      _entrandoComGoogle = true;
    });

    try {
      await ref.read(servicoAuthProvider).entrarComGoogle();
    } on ErroAuth catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _entrandoComGoogle = false);
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
                  'Controle Financeiro',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  key: const Key('campo_email'),
                  controller: _email,
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('campo_senha'),
                  controller: _senha,
                  obscureText: true,
                  onSubmitted: (_) => _entrando ? null : _entrar(),
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _erro!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('botao_entrar'),
                  onPressed: _entrando ? null : _entrar,
                  child: _entrando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('ou'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('botao_entrar_google'),
                  onPressed: _entrandoComGoogle ? null : _entrarComGoogle,
                  icon: _entrandoComGoogle
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Entrar com Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
