import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorio_gestao_casa.dart';

void main() {
  group('RepositorioGestaoCasaFake', () {
    test('minhaCasa comeca nula', () async {
      final repo = RepositorioGestaoCasaFake();
      expect(await repo.minhaCasa(), isNull);
    });

    test('criarCasa define o casaId e registra a chamada', () async {
      final repo = RepositorioGestaoCasaFake();
      final casaId = await repo.criarCasa('Minha Casa', nomeMembro: 'Ana');
      expect(casaId, isNotEmpty);
      expect(await repo.minhaCasa(), casaId);
      expect(repo.chamadas, ['criarCasa:Minha Casa:Ana']);
    });

    test('lanca ErroGestaoCasa quando erro esta configurado', () async {
      final repo = RepositorioGestaoCasaFake()..erro = 'Este e-mail já pertence a uma casa.';
      expect(
        () => repo.criarCasa('Casa', nomeMembro: 'Ana'),
        throwsA(isA<ErroGestaoCasa>()),
      );
    });

    test('convidarMembro, removerMembro e transferirPosse registram a chamada', () async {
      final repo = RepositorioGestaoCasaFake();
      await repo.convidarMembro(casaId: 'c1', email: 'a@b.com', nome: 'A');
      await repo.removerMembro(casaId: 'c1', membroId: 'm1');
      await repo.transferirPosse(casaId: 'c1', novoDonoMembroId: 'm2');
      expect(repo.chamadas, [
        'convidarMembro:a@b.com',
        'removerMembro:m1',
        'transferirPosse:m2',
      ]);
    });

    test('sairDaCasa e excluirCasa registram a chamada', () async {
      final repo = RepositorioGestaoCasaFake();
      await repo.sairDaCasa(casaId: 'c1');
      await repo.excluirCasa(casaId: 'c1');
      expect(repo.chamadas, ['sairDaCasa', 'excluirCasa']);
    });
  });
}
