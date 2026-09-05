import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dados/servico_auth.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/estado/providers.dart';

const casa = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
    // Marcos e o primeiro da lista de proposito: assim o teste da Silvia
    // falha se a visao inicial voltar a ser "o primeiro membro".
    Membro(id: 'marcos', nome: 'Marcos', email: 'marcos@x.com',
        cor: '#2E7D32', ordem: 0),
    Membro(id: 'silvia', nome: 'Silvia', email: 'silvia@x.com',
        cor: '#6A1B9A', ordem: 1),
  ],
);

/// Um container com [emailLogado] autenticado, ainda sem os streams de
/// sessao ligados — e assim que o app arranca.
Future<ProviderContainer> montar(String? emailLogado) async {
  final auth = AuthFake();
  if (emailLogado != null) {
    await auth.entrar(email: emailLogado, senha: 'segredo123');
  }

  final container = ProviderContainer(overrides: [
    servicoAuthProvider.overrideWithValue(auth),
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Liga os streams de sessao e deixa o membro logado chegar.
Future<void> chegarSessao(ProviderContainer c) async {
  c.listen(casaProvider, (_, _) {});
  c.listen(emailLogadoProvider, (_, _) {});
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('a visao comeca em quem esta logado', () async {
    final c = await montar('silvia@x.com');

    // Lida antes da sessao chegar, como acontece no arranque real.
    expect(c.read(visaoProvider), isNull);

    await chegarSessao(c);
    expect(c.read(visaoProvider), 'silvia');
  });

  test('a visao semeia mesmo quando a sessao chega antes da primeira leitura',
      () async {
    final c = await montar('silvia@x.com');
    await chegarSessao(c);

    expect(c.read(visaoProvider), 'silvia');
  });

  test('a chegada do membro logado nao desfaz a escolha manual', () async {
    final c = await montar('silvia@x.com');
    c.read(visaoProvider.notifier).selecionar('marcos');

    await chegarSessao(c);
    expect(c.read(visaoProvider), 'marcos');
  });

  test('escolher Casal antes da sessao chegar continua valendo', () async {
    final c = await montar('silvia@x.com');
    // Null e o mesmo valor do estado inicial: so a escolha explicita
    // distingue os dois.
    c.read(visaoProvider.notifier).selecionar(null);

    await chegarSessao(c);
    expect(c.read(visaoProvider), isNull);
  });

  test('e-mail fora da casa deixa a visao no casal', () async {
    final c = await montar('estranho@x.com');
    await chegarSessao(c);

    expect(c.read(visaoProvider), isNull);
  });
}
