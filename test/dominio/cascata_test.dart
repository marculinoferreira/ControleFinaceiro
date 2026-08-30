import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/cascata.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';

/// Seis potes somando 100%, na ordem de prioridade do spec.
List<Pote> potesPadrao() => const [
      Pote(id: 'p1', nome: 'Custo fixo', percentual: 55, ordem: 0,
          cor: '#2E7D32', icone: 'casa'),
      Pote(id: 'p2', nome: 'Conforto', percentual: 15, ordem: 1,
          cor: '#1565C0', icone: 'sofa'),
      Pote(id: 'p3', nome: 'Investimento', percentual: 10, ordem: 2,
          cor: '#00838F', icone: 'grafico'),
      Pote(id: 'p4', nome: 'Metas', percentual: 10, ordem: 3,
          cor: '#EF6C00', icone: 'alvo'),
      Pote(id: 'p5', nome: 'Prazer', percentual: 5, ordem: 4,
          cor: '#AD1457', icone: 'presente'),
      Pote(id: 'p6', nome: 'Conhecimento', percentual: 5, ordem: 5,
          cor: '#4527A0', icone: 'livro'),
    ];

void main() {
  const ganhos = 5000.0;

  test('sem gastos, o pote ativo e o primeiro e nada foi consumido', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 0);

    expect(r.poteAtivo?.id, 'p1');
    expect(r.rotulo, 'CUSTO FIXO');
    expect(r.excedente, 0);
    expect(r.linhas.every((l) => l.consumido == 0), isTrue);
    expect(r.linhas.first.sobra, 2750);
  });

  test('gasto de 3900 para no meio do terceiro pote', () {
    // 2750 (p1) + 750 (p2) = 3500 consumidos; sobram 400 para p3 (previsto 500)
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 3900);

    expect(r.poteAtivo?.id, 'p3');
    expect(r.rotulo, 'INVESTIMENTO');

    expect(r.linhas[0].consumido, 2750);
    expect(r.linhas[0].sobra, 0);
    expect(r.linhas[1].consumido, 750);
    expect(r.linhas[1].sobra, 0);
    expect(r.linhas[2].consumido, 400);
    expect(r.linhas[2].sobra, 100);
    // Potes seguintes intactos
    expect(r.linhas[3].consumido, 0);
    expect(r.linhas[3].sobra, 500);
    expect(r.excedente, 0);
  });

  test('gasto exatamente igual ao previsto do pote 1 joga o ativo para o 2', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 2750);

    // Sobra zero no p1 nao conta como folga: a agua ja passou dele.
    expect(r.linhas[0].sobra, 0);
    expect(r.poteAtivo?.id, 'p2');
    expect(r.rotulo, 'CONFORTO');
  });

  test('gasto acima da renda estoura todos os potes', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 5600);

    expect(r.poteAtivo, isNull);
    expect(r.estourouTudo, isTrue);
    expect(r.rotulo, 'PARE DE GASTAR');
    expect(r.excedente, closeTo(600, 0.001));
    expect(r.linhas.every((l) => l.sobra == 0), isTrue);
  });

  test('lista de potes vazia nao lanca e devolve todo o gasto como excedente', () {
    final r = calcularCascata(
        potes: const [], totalGanhos: ganhos, totalGastos: 1200);

    expect(r.linhas, isEmpty);
    expect(r.poteAtivo, isNull);
    expect(r.excedente, 1200);
    expect(r.rotulo, 'PARE DE GASTAR');
  });

  test('renda zero com gasto positivo estoura tudo', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: 0, totalGastos: 300);

    expect(r.linhas.every((l) => l.previsto == 0), isTrue);
    expect(r.poteAtivo, isNull);
    expect(r.excedente, 300);
  });

  test('renda zero e gasto zero estoura', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: 0, totalGastos: 0);

    expect(r.excedente, 0);
    expect(r.estourouTudo, isTrue); // nenhum pote tem folga: previsto e zero
  });

  test('a soma dos previstos iguala a renda quando os potes somam 100%', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 0);

    final soma = r.linhas.fold<double>(0, (a, l) => a + l.previsto);
    expect(soma, closeTo(ganhos, 0.005));
  });

  test('consumido mais sobra sempre igual ao previsto em cada linha', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 3900);

    for (final l in r.linhas) {
      expect(l.consumido + l.sobra, closeTo(l.previsto, 0.005));
    }
  });

  test('sobra de um centavo nao e engolida pela tolerancia', () {
    // previsto p1 = 2750; gasto 2749.99 deixa 1 centavo de folga
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 2749.99);

    expect(r.poteAtivo?.id, 'p1');
  });

  test('sobra menor que meio centavo conta como zero', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 2749.999);

    expect(r.poteAtivo?.id, 'p2');
  });

  test('respeita a ordem do campo ordem, nao a ordem da lista', () {
    final foraDeOrdem = [potesPadrao()[1], potesPadrao()[0]];
    final r = calcularCascata(
        potes: foraDeOrdem, totalGanhos: ganhos, totalGastos: 0);

    expect(r.linhas.first.pote.id, 'p1');
  });

  // Testes de hardening para cases não explícitos no brief

  test('percentual negativo nao inventa gasto fantasma', () {
    // CRITICAL 1: pote com percentual negativo não deve criar consumo
    final potesComNegativo = const [
      Pote(id: 'pneg', nome: 'Negativo', percentual: -10, ordem: 0,
          cor: '#000000', icone: 'x'),
      Pote(id: 'p2pos', nome: 'Positivo', percentual: 60, ordem: 1,
          cor: '#FFFFFF', icone: 'y'),
    ];
    final r = calcularCascata(
        potes: potesComNegativo, totalGanhos: 1000, totalGastos: 0);

    // Com gasto zero, nenhum pote deve consumir nada
    expect(r.linhas[0].consumido, 0);
    expect(r.linhas[1].consumido, 0);
    // O segundo pote não deve ter absorvido "spending imaginário"
    expect(r.linhas[1].sobra, closeTo(600, 0.005));
  });

  test('totalGastos negativo nao causa sobra maior que previsto', () {
    // IMPORTANT 2: gasto negativo não deve violar a invariante consumido + sobra = previsto
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: -100);

    for (final l in r.linhas) {
      // sobra nunca deve exceder previsto
      expect(l.sobra, lessThanOrEqualTo(l.previsto + toleranciaCentavo));
      // consumido nunca deve ser negativo
      expect(l.consumido, greaterThanOrEqualTo(0));
    }
  });

  test('excedente com rounding é exatamente zero quando gasto iguala renda', () {
    // IMPORTANT 3: flutuações de ponto flutuante não criam excedente fantasma
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: 1234.56, totalGastos: 1234.56);

    // excedente deve ser exatamente zero, não 1.9895e-13
    expect(r.excedente, 0.0);
  });

  test('estourouTudo retorna false quando ha pote ativo', () {
    // IMPORTANT 4: estourouTudo deve poder retornar false
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 0);

    // Com zero gasto, o primeiro pote tem folga e é ativo
    expect(r.poteAtivo, isNotNull);
    expect(r.estourouTudo, isFalse);
  });

  test('ordem com empate usa id como desempate', () {
    // MINOR 5: potes com mesmo ordem são desempatados por id
    final potesComEmpate = const [
      Pote(id: 'pz', nome: 'Z', percentual: 50, ordem: 0,
          cor: '#000000', icone: 'z'),
      Pote(id: 'pa', nome: 'A', percentual: 50, ordem: 0,
          cor: '#FFFFFF', icone: 'a'),
    ];
    final r = calcularCascata(
        potes: potesComEmpate, totalGanhos: 1000, totalGastos: 0);

    // Com desempate por id, 'pa' vem antes de 'pz'
    expect(r.linhas.first.pote.id, 'pa');
    expect(r.linhas[1].pote.id, 'pz');
  });

  test('calcularCascata nao mutacao lista de potes do chamador', () {
    // MINOR 6: a função deve não mutar a lista recebida
    final potesOriginal = [potesPadrao()[1], potesPadrao()[0]];
    final potesAntes = [potesOriginal[0].id, potesOriginal[1].id];

    calcularCascata(
        potes: potesOriginal, totalGanhos: ganhos, totalGastos: 0);

    // Ordem da lista deve ser preservada
    expect([potesOriginal[0].id, potesOriginal[1].id], potesAntes);
  });
}
