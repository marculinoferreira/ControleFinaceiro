import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/parcelas.dart';

/// Uma compra de [total] parcelas comecando em [inicio], ja com ids.
List<Gasto> compraDe({
  int total = 5,
  String inicio = '2026-08',
  double valor = 126,
  String descricao = 'pneus dakar',
  String membroId = 'marcos',
  String poteId = 'custo-fixo',
  String compraId = 'c1',
  String prefixoId = 'g',
}) {
  final inicioRef = MesRef.parse(inicio);
  return List.generate(
    total,
    (i) => Gasto(
      id: '$prefixoId${i + 1}',
      mesRef: inicioRef.avancar(i).valor,
      membroId: membroId,
      poteId: poteId,
      descricao: descricao,
      valor: valor,
      criadoEm: DateTime(2026, 8, 1),
      data: DateTime(inicioRef.avancar(i).ano, inicioRef.avancar(i).mes, 12),
      parcelado: true,
      cartaoId: 'ct1',
      compraId: compraId,
      parcela: i + 1,
      totalParcelas: total,
    ),
  );
}

void main() {
  group('planejarEdicaoCompra — quantidade', () {
    test('aumentar de 5 para 6 cria uma parcela no fim e renumera o total', () {
      final existentes = compraDe(total: 5);

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: existentes.first,
        alcance: ModoEdicao.todas,
        novaQuantidade: 6,
      );

      expect(plano.remover, isEmpty);
      expect(plano.criar, hasLength(1));
      expect(plano.criar.single.parcela, 6);
      expect(plano.criar.single.mesRef, '2027-01'); // Ago/26 + 5
      expect(plano.criar.single.totalParcelas, 6);
      expect(plano.criar.single.compraId, 'c1');
      expect(plano.criar.single.valor, 126);

      // As 5 antigas mudam so porque o total virou 6.
      expect(plano.atualizar, hasLength(5));
      expect(plano.atualizar.every((g) => g.totalParcelas == 6), isTrue);
    });

    test('diminuir de 5 para 4 apaga a ultima e renumera o total', () {
      final existentes = compraDe(total: 5);

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: existentes.first,
        alcance: ModoEdicao.todas,
        novaQuantidade: 4,
      );

      expect(plano.remover, ['g5']);
      expect(plano.criar, isEmpty);
      expect(plano.atualizar, hasLength(4));
      expect(plano.atualizar.every((g) => g.totalParcelas == 4), isTrue);
    });

    test('aumentar em tres cria as tres, em meses consecutivos', () {
      final existentes = compraDe(total: 5);

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: existentes.first,
        alcance: ModoEdicao.todas,
        novaQuantidade: 8,
      );

      expect(plano.criar.map((g) => g.mesRef).toList(),
          ['2027-01', '2027-02', '2027-03']);
      expect(plano.criar.map((g) => g.parcela).toList(), [6, 7, 8]);
    });

    test('quantidade igual e campos iguais nao geram escrita nenhuma', () {
      final existentes = compraDe(total: 5);

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: existentes[2],
        alcance: ModoEdicao.todas,
        novaQuantidade: 5,
      );

      expect(plano.vazio, isTrue);
    });

    test('a ancora e a parcela 1, mesmo editando uma parcela do meio', () {
      final existentes = compraDe(total: 5); // Ago/26..Dez/26

      // Editando a parcela 3 (Out/26): a 6a cai em Jan/27, nao em Mar/27.
      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: existentes[2],
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 6,
      );

      expect(plano.criar.single.mesRef, '2027-01');
    });

    test('a ancora sobrevive a exclusao da parcela 1', () {
      final existentes = compraDe(total: 5).sublist(1); // parcelas 2..5

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: existentes.first, // parcela 2, Set/26
        alcance: ModoEdicao.todas,
        novaQuantidade: 6,
      );

      // A compra ainda comecou em Ago/26, entao a 6a cai em Jan/27.
      expect(plano.criar.single.mesRef, '2027-01');
    });

    test('nao recria uma parcela do fim que foi apagada de proposito', () {
      // Compra de 5 com a 5a ja estornada: os docs dizem totalParcelas 5.
      final existentes = compraDe(total: 5).sublist(0, 4);

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: existentes.first,
        alcance: ModoEdicao.todas,
        novaQuantidade: 6,
      );

      // So a 6a nasce; a 5a apagada continua apagada.
      expect(plano.criar.map((g) => g.parcela).toList(), [6]);
    });
  });

  group('planejarEdicaoCompra — alcance dos campos', () {
    test('somenteEsta muda o valor so da parcela editada', () {
      final existentes = compraDe(total: 5);
      final editado = existentes[2].copyWith(valor: 200);

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 5,
      );

      expect(plano.atualizar, hasLength(1));
      expect(plano.atualizar.single.id, 'g3');
      expect(plano.atualizar.single.valor, 200);
    });

    test('estaEFuturas muda da parcela editada em diante', () {
      final existentes = compraDe(total: 5);
      final editado = existentes[2].copyWith(valor: 200);

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.estaEFuturas,
        novaQuantidade: 5,
      );

      expect(plano.atualizar.map((g) => g.id).toList(), ['g3', 'g4', 'g5']);
      expect(plano.atualizar.every((g) => g.valor == 200), isTrue);
    });

    test('todas muda o valor da compra inteira', () {
      final existentes = compraDe(total: 5);
      final editado = existentes[2].copyWith(valor: 200);

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.todas,
        novaQuantidade: 5,
      );

      expect(plano.atualizar, hasLength(5));
      expect(plano.atualizar.every((g) => g.valor == 200), isTrue);
    });

    test('a descricao vai para todas mesmo com alcance somenteEsta', () {
      final existentes = compraDe(total: 5);
      final editado = existentes[2].copyWith(descricao: 'pneus novos');

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 5,
      );

      expect(plano.atualizar, hasLength(5));
      expect(
          plano.atualizar.every((g) => g.descricao == 'pneus novos'), isTrue);
    });

    test('pote e pessoa vao para todas mesmo com alcance somenteEsta', () {
      final existentes = compraDe(total: 5);
      final editado =
          existentes[2].copyWith(poteId: 'lazer', membroId: 'ana');

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 5,
      );

      expect(plano.atualizar, hasLength(5));
      expect(plano.atualizar.every((g) => g.poteId == 'lazer'), isTrue);
      expect(plano.atualizar.every((g) => g.membroId == 'ana'), isTrue);
    });

    test('mudar descricao e valor junto separa os alcances', () {
      final existentes = compraDe(total: 5);
      final editado =
          existentes[2].copyWith(descricao: 'pneus novos', valor: 200);

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 5,
      );

      // Descricao em todas; valor so na 3a.
      expect(
          plano.atualizar.every((g) => g.descricao == 'pneus novos'), isTrue);
      expect(plano.atualizar.where((g) => g.valor == 200), hasLength(1));
      expect(plano.atualizar.firstWhere((g) => g.id == 'g3').valor, 200);
    });

    test('somenteEsta ainda propaga o total novo para as irmas', () {
      final existentes = compraDe(total: 5);
      final editado = existentes.first.copyWith(valor: 200);

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 6,
      );

      // Todas mudam o total; so a primeira muda o valor.
      expect(plano.atualizar, hasLength(5));
      expect(plano.atualizar.every((g) => g.totalParcelas == 6), isTrue);
      expect(plano.atualizar.where((g) => g.valor == 200), hasLength(1));
      // A parcela nova nasce com o valor editado, como o preview promete.
      expect(plano.criar.single.valor, 200);
    });

    test('pessoa e pote ignoram o alcance e vao para a compra inteira', () {
      final existentes = compraDe(total: 3);
      final editado = existentes[1].copyWith(membroId: 'ana', poteId: 'lazer');

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.estaEFuturas,
        novaQuantidade: 3,
      );

      expect(plano.atualizar.map((g) => g.id).toList(), ['g1', 'g2', 'g3']);
      expect(plano.atualizar.every((g) => g.membroId == 'ana'), isTrue);
      expect(plano.atualizar.every((g) => g.poteId == 'lazer'), isTrue);
    });

    test('o mes de cada parcela nunca e reescrito pela edicao', () {
      final existentes = compraDe(total: 5);
      final editado = existentes[2].copyWith(valor: 200);

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.todas,
        novaQuantidade: 5,
      );

      expect(plano.atualizar.map((g) => g.mesRef).toList(),
          ['2026-08', '2026-09', '2026-10', '2026-11', '2026-12']);
    });
  });

  group('planejarEdicaoCompra — bordas', () {
    test('gasto sem compra vira edicao de documento solto', () {
      final solto = Gasto(
        id: 'x1',
        mesRef: '2026-08',
        membroId: 'marcos',
        poteId: 'custo-fixo',
        descricao: 'padaria',
        valor: 20,
        criadoEm: DateTime(2026, 8, 1),
        parcelado: false,
      );

      final plano = planejarEdicaoCompra(
        existentes: [solto],
        editado: solto.copyWith(valor: 25),
        alcance: ModoEdicao.todas,
        novaQuantidade: 1,
      );

      expect(plano.atualizar.single.valor, 25);
      expect(plano.criar, isEmpty);
      expect(plano.remover, isEmpty);
    });

    test('nao mexe em parcelas de outra compra', () {
      final alvo = compraDe(total: 3);
      final outra = compraDe(total: 2, compraId: 'c2', prefixoId: 'z');

      final plano = planejarEdicaoCompra(
        existentes: [...alvo, ...outra],
        editado: alvo.first.copyWith(valor: 999),
        alcance: ModoEdicao.todas,
        novaQuantidade: 3,
      );

      expect(plano.atualizar.every((g) => g.compraId == 'c1'), isTrue);
      expect(plano.atualizar.map((g) => g.id), isNot(contains('z1')));
      expect(plano.remover, isEmpty);
    });

    test('quantidade zero e recusada', () {
      final existentes = compraDe(total: 3);
      expect(
        () => planejarEdicaoCompra(
          existentes: existentes,
          editado: existentes.first,
          alcance: ModoEdicao.todas,
          novaQuantidade: 0,
        ),
        throwsArgumentError,
      );
    });

    test('encolher abaixo da parcela editada apaga o proprio documento', () {
      final existentes = compraDe(total: 5);

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: existentes[4], // parcela 5
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 3,
      );

      expect(plano.remover, containsAll(['g4', 'g5']));
    });
  });

  group('planejarEdicaoCompra — data', () {
    test('mudar a data propaga o dia para todas, cada uma no seu mes', () {
      final existentes = compraDe(total: 3); // Ago, Set, Out, todas dia 12
      final editado = existentes.first.copyWith(data: DateTime(2026, 8, 17));

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 3,
      );

      expect(plano.atualizar, hasLength(3));
      expect(plano.atualizar.map((g) => g.data).toList(), [
        DateTime(2026, 8, 17),
        DateTime(2026, 9, 17),
        DateTime(2026, 10, 17),
      ]);
    });

    test('editar a parcela do meio ancora nela, e as irmas se alinham', () {
      final existentes = compraDe(total: 3);
      // Parcela 2 (Set) passa para 17/09.
      final editado = existentes[1].copyWith(data: DateTime(2026, 9, 17));

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 3,
      );

      expect(plano.atualizar.map((g) => g.data).toList(), [
        DateTime(2026, 8, 17),
        DateTime(2026, 9, 17), // a editada, exatamente como digitada
        DateTime(2026, 10, 17),
      ]);
    });

    test('dia 31 encolhe para o ultimo dia dos meses curtos', () {
      final existentes = compraDe(total: 4, inicio: '2026-01'); // Jan..Abr
      final editado = existentes.first.copyWith(data: DateTime(2026, 1, 31));

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 4,
      );

      expect(plano.atualizar.map((g) => g.data).toList(), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28), // fevereiro nao tem 31
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30), // abril tem 30
      ]);
    });

    test('so mudar a data ja gera escrita, sem mexer no valor', () {
      final existentes = compraDe(total: 2);
      final editado = existentes.first.copyWith(data: DateTime(2026, 8, 20));

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 2,
      );

      expect(plano.atualizar, isNotEmpty);
      expect(plano.atualizar.every((g) => g.valor == 126), isTrue);
    });

    test('parcela nova nasce alinhada a data editada', () {
      final existentes = compraDe(total: 2);
      final editado = existentes.first.copyWith(data: DateTime(2026, 8, 17));

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 3,
      );

      expect(plano.criar.single.data, DateTime(2026, 10, 17));
    });

    test('a data nao muda quando nao foi tocada', () {
      final existentes = compraDe(total: 3);
      final editado = existentes.first.copyWith(descricao: 'pneus novos');

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 3,
      );

      expect(plano.atualizar.map((g) => g.data.day).toList(), [12, 12, 12]);
    });
  });

  group('planejarEdicaoCompra — cartao', () {
    test('trocar o cartao vale para a compra inteira, sem perguntar', () {
      final existentes = compraDe(total: 3);
      final editado = existentes[1].copyWith(cartaoId: 'ct2');

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        // Mesmo com o alcance mais restrito: cartao e da compra, nao da
        // parcela. Um parcelamento nao troca de cartao no meio.
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 3,
      );

      expect(plano.atualizar, hasLength(3));
      expect(plano.atualizar.every((g) => g.cartaoId == 'ct2'), isTrue);
    });

    test('parcela nova nasce no cartao da compra', () {
      final existentes = compraDe(total: 2);
      final editado = existentes.first.copyWith(cartaoId: 'ct2');

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 3,
      );

      expect(plano.criar.single.cartaoId, 'ct2');
    });

    test('so mudar o cartao ja gera escrita', () {
      final existentes = compraDe(total: 2);
      final editado = existentes.first.copyWith(cartaoId: 'ct9');

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 2,
      );

      expect(plano.atualizar, isNotEmpty);
    });

    test('o cartao nao muda quando nao foi tocado', () {
      final existentes = compraDe(total: 3);
      final editado = existentes.first.copyWith(descricao: 'outro nome');

      final plano = planejarEdicaoCompra(
        existentes: existentes,
        editado: editado,
        alcance: ModoEdicao.somenteEsta,
        novaQuantidade: 3,
      );

      expect(plano.atualizar.every((g) => g.cartaoId == 'ct1'), isTrue);
    });
  });
}
