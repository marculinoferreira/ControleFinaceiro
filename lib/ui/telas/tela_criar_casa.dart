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
  static const _tamanhoMaximoNome = 12;

  final _nomeMembro = TextEditingController();
  final _nome = TextEditingController();
  String? _erro;
  bool _criando = false;

  @override
  void initState() {
    super.initState();
    // O botao so habilita com os dois campos preenchidos; sem o listener,
    // digitar neles nao reconstruiria o FilledButton pra reavaliar isso.
    _nomeMembro.addListener(_aoMudarCampos);
    _nome.addListener(_aoMudarCampos);
  }

  void _aoMudarCampos() {
    if (mounted) setState(() {});
  }

  bool get _podeCriar =>
      _nomeMembro.text.trim().isNotEmpty && _nome.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nomeMembro.removeListener(_aoMudarCampos);
    _nome.removeListener(_aoMudarCampos);
    _nomeMembro.dispose();
    _nome.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    setState(() {
      _erro = null;
      _criando = true;
    });

    try {
      await ref.read(repositorioGestaoCasaProvider).criarCasa(
            _nome.text.trim(),
            nomeMembro: _nomeMembro.text.trim(),
          );
      ref.invalidate(casaIdProvider);
    } on ErroGestaoCasa catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _criando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saiuDaCasa = ref.watch(saiuDaCasaProvider);

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
                if (saiuDaCasa) ...[
                  const SizedBox(height: 16),
                  const _AvisoSaiuDaCasa(key: Key('aviso_saiu_da_casa')),
                ],
                const SizedBox(height: 24),
                TextField(
                  key: const Key('campo_nome_membro'),
                  controller: _nomeMembro,
                  maxLength: _tamanhoMaximoNome,
                  decoration: const InputDecoration(
                    labelText: 'Seu nome ou apelido',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('campo_nome_casa'),
                  controller: _nome,
                  maxLength: _tamanhoMaximoNome,
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
                  onPressed: _criando || !_podeCriar ? null : _criar,
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

/// Mostrado so depois de sair (sem excluir) de uma casa, pra deixar claro
/// que os dados nao sumiram e como recupera-los criando uma casa nova com o
/// mesmo nome/e-mail. Quem esta criando a primeira casa nunca ve isto.
class _AvisoSaiuDaCasa extends StatelessWidget {
  const _AvisoSaiuDaCasa({super.key});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: esquema.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: esquema.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Você acabou de sair de uma casa. Seus dados ainda estão '
              'salvos: basta colocar seu nome e um nome para a casa nova '
              'que tudo aparece para você.\n\nSe você não fizer isso agora, '
              'seus dados ficam guardados por 30 dias e depois disso são '
              'excluídos, sem forma de recuperação.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: esquema.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
