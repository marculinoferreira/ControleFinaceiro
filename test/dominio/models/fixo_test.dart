import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/fixo.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';

Fixo fixoDe(String id, {TipoFixo tipo = TipoFixo.gasto}) => Fixo(
      id: id,
      tipo: tipo,
      membroId: 'marcos',
      descricao: 'Aluguel',
      valor: 1200,
      criadoEm: DateTime.utc(2026, 10, 1),
      poteId: tipo == TipoFixo.gasto ? 'p1' : null,
    );

void main() {
  group('Fixo', () {
    test('round-trip toMap/fromMap de um ganho', () {
      final fixo = Fixo(
        id: 'f1',
        tipo: TipoFixo.ganho,
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 5000,
        criadoEm: DateTime.utc(2026, 10, 1),
      );

      final reconstruido = Fixo.fromMap('f1', fixo.toMap());

      expect(reconstruido.id, 'f1');
      expect(reconstruido.tipo, TipoFixo.ganho);
      expect(reconstruido.membroId, 'marcos');
      expect(reconstruido.descricao, 'Salario');
      expect(reconstruido.valor, 5000);
      expect(reconstruido.poteId, isNull);
    });

    test('round-trip toMap/fromMap de um gasto, com poteId', () {
      final fixo = Fixo(
        id: 'f2',
        tipo: TipoFixo.gasto,
        membroId: 'silvia',
        descricao: 'Aluguel',
        valor: 1200,
        criadoEm: DateTime.utc(2026, 10, 1),
        poteId: 'p1',
      );

      final reconstruido = Fixo.fromMap('f2', fixo.toMap());

      expect(reconstruido.tipo, TipoFixo.gasto);
      expect(reconstruido.poteId, 'p1');
    });

    test('toMap grava o tipo como string "ganho" ou "gasto"', () {
      final ganho = Fixo(
        id: '', tipo: TipoFixo.ganho, membroId: 'marcos',
        descricao: 'x', valor: 1, criadoEm: DateTime.utc(2026, 1, 1),
      );
      final gasto = Fixo(
        id: '', tipo: TipoFixo.gasto, membroId: 'marcos',
        descricao: 'x', valor: 1, criadoEm: DateTime.utc(2026, 1, 1),
      );

      expect(ganho.toMap()['tipo'], 'ganho');
      expect(gasto.toMap()['tipo'], 'gasto');
    });
  });

  group('mesAlvoDosFixos', () {
    test('e o mes real de hoje avancado em 1', () {
      final esperado = MesRef.atual().avancar(1);
      expect(mesAlvoDosFixos(), esperado);
    });
  });

  group('idLancamentoDoFixo', () {
    test('junta o id do fixo com o mes, separados por underline', () {
      final id = idLancamentoDoFixo(fixoDe('f1'), const MesRef(2026, 11));
      expect(id, 'f1_2026-11');
    });

    test('fixos diferentes no mesmo mes dao ids diferentes', () {
      final mes = const MesRef(2026, 11);
      final idA = idLancamentoDoFixo(fixoDe('f1'), mes);
      final idB = idLancamentoDoFixo(fixoDe('f2'), mes);
      expect(idA, isNot(idB));
    });

    test('o mesmo fixo em meses diferentes da ids diferentes', () {
      final fixo = fixoDe('f1');
      final idOutubro = idLancamentoDoFixo(fixo, const MesRef(2026, 10));
      final idNovembro = idLancamentoDoFixo(fixo, const MesRef(2026, 11));
      expect(idOutubro, isNot(idNovembro));
    });
  });

  group('fixosParaGerar', () {
    test('Fixo sem lancamento gerado ainda entra na lista', () {
      final aGerar = fixosParaGerar(
        fixos: [fixoDe('f1')],
        mesAlvo: MesRef.atual().avancar(1),
        origensJaGeradasNoMes: {},
      );
      expect(aGerar, hasLength(1));
    });

    test('Fixo cuja origem ja esta em origensJaGeradasNoMes nao entra', () {
      final aGerar = fixosParaGerar(
        fixos: [fixoDe('f1'), fixoDe('f2')],
        mesAlvo: MesRef.atual().avancar(1),
        origensJaGeradasNoMes: {'f1'},
      );
      expect(aGerar.map((f) => f.id), ['f2']);
    });
  });

  group('travadoPorFixo', () {
    test('sem origemFixoId nunca trava', () {
      final futuro = MesRef.atual().avancar(1).valor;
      expect(travadoPorFixo(origemFixoId: null, mesRef: futuro), isFalse);
    });

    test('com origemFixoId e mes futuro, trava', () {
      final futuro = MesRef.atual().avancar(1).valor;
      expect(
        travadoPorFixo(origemFixoId: 'f1', mesRef: futuro),
        isTrue,
      );
    });

    test('com origemFixoId e mes igual ao atual, nao trava', () {
      final atual = MesRef.atual().valor;
      expect(
        travadoPorFixo(origemFixoId: 'f1', mesRef: atual),
        isFalse,
      );
    });

    test('com origemFixoId e mes passado, nao trava', () {
      final passado = MesRef.atual().avancar(-1).valor;
      expect(
        travadoPorFixo(origemFixoId: 'f1', mesRef: passado),
        isFalse,
      );
    });
  });
}
