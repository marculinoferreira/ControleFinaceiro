import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/fixo.dart';

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
}
