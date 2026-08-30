import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dados/semeadura.dart';

void main() {
  test('os potes padrao somam exatamente 100%', () {
    final soma = potesPadrao().fold<double>(0, (a, p) => a + p.percentual);
    expect(soma, 100);
  });

  test('os potes padrao respeitam o limite de 6', () {
    expect(potesPadrao().length, lessThanOrEqualTo(6));
  });

  test('os potes padrao tem ordem sequencial a partir de zero', () {
    expect(potesPadrao().map((p) => p.ordem).toList(), [0, 1, 2, 3, 4, 5]);
  });

  test('a casa padrao tem os dois membros com os e-mails corretos', () {
    final casa = casaPadrao();
    expect(casa.membros, hasLength(2));
    expect(casa.membroPorEmail('marcos.centrone@gmail.com')?.id, 'marcos');
    expect(casa.membroPorEmail('silviabborges3@gmail.com')?.id, 'silvia');
  });

  test('semear cria casa e potes quando nao existe nada', () async {
    final casa = RepositorioCasaFake();
    final potes = RepositorioPotesFake();

    await semear(casa: casa, potes: potes);

    expect(await casa.observar().first, isNotNull);
    expect(await potes.observar().first, hasLength(6));
  });

  test('semear nao sobrescreve uma casa existente', () async {
    final casa = RepositorioCasaFake(casaPadrao());
    final potes = RepositorioPotesFake(potesPadrao());

    // Simula o usuario tendo reduzido para 2 potes.
    await potes.salvarTodos(potesPadrao().take(2).toList());
    await semear(casa: casa, potes: potes);

    expect(await potes.observar().first, hasLength(2));
  });
}
