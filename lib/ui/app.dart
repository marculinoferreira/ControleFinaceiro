import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/providers.dart';
import 'shell.dart';
import 'telas/tela_login.dart';
import 'tema/tema.dart';
import 'widgets/estados_async.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Controle Financeiro',
      theme: temaClaro(),
      darkTheme: temaEscuro(),
      debugShowCheckedModeBanner: false,
      // Sem isto os widgets do proprio Flutter (o calendario do
      // showDatePicker, os rotulos de acessibilidade) saem em ingles.
      // Uma unica locale suportada: o app e de uma casa brasileira, e
      // deixar o sistema escolher outra so traria uma tela meio traduzida.
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Roteador(),
    );
  }
}

class _Roteador extends ConsumerWidget {
  const _Roteador();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(emailLogadoProvider);

    return email.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: ErroComRecarregar(
          erro: e,
          aoRecarregar: () => ref.invalidate(emailLogadoProvider),
        ),
      ),
      data: (endereco) {
        if (endereco == null) return const TelaLogin();
        return const _CasaOuSemAcesso();
      },
    );
  }
}

/// Autenticar nao basta: o e-mail precisa pertencer a esta casa.
class _CasaOuSemAcesso extends ConsumerWidget {
  const _CasaOuSemAcesso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casa = ref.watch(casaProvider);

    return casa.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: ErroComRecarregar(
          erro: e,
          aoRecarregar: () => ref.invalidate(casaProvider),
        ),
      ),
      data: (_) {
        final membro = ref.watch(membroLogadoProvider);
        if (membro == null) return const _SemAcesso();
        return const Shell();
      },
    );
  }
}

class _SemAcesso extends ConsumerWidget {
  const _SemAcesso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40),
              const SizedBox(height: 12),
              Text(
                'Esta conta nao faz parte desta casa.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref.read(servicoAuthProvider).sair(),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
