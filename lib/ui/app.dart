import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/providers.dart';
import 'shell.dart';
import 'telas/tela_criar_casa.dart';
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
        return const _CasaOuCriarCasa();
      },
    );
  }
}

/// Depois de logado, resolve em qual casa a pessoa esta (ou se ainda
/// precisa criar uma) via a Cloud Function `minhaCasa`.
class _CasaOuCriarCasa extends ConsumerWidget {
  const _CasaOuCriarCasa();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casaId = ref.watch(casaIdProvider);

    return casaId.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: ErroComRecarregar(
          erro: e,
          aoRecarregar: () => ref.invalidate(casaIdProvider),
        ),
      ),
      data: (id) => id == null ? const TelaCriarCasa() : const Shell(),
    );
  }
}
