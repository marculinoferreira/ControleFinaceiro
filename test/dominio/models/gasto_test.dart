import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';

void main() {
  group('Gasto', () {
    test('round-trip toMap/fromMap preserva previsto e origemFixoId', () {
      final g = Gasto(
        id: '', mesRef: '2026-11', membroId: 'marcos', poteId: 'p1',
        descricao: 'Aluguel', valor: 1200,
        criadoEm: DateTime.utc(2026, 10, 1), parcelado: false,
        previsto: true, origemFixoId: 'f2',
      );

      final reconstruido = Gasto.fromMap('g1', g.toMap());

      expect(reconstruido.previsto, isTrue);
      expect(reconstruido.origemFixoId, 'f2');
    });

    test(
        'previsto e origemFixoId ausentes no mapa (gasto legado) caem no default',
        () {
      final mapa = Gasto(
        id: '', mesRef: '2026-11', membroId: 'marcos', poteId: 'p1',
        descricao: 'Mercado', valor: 100,
        criadoEm: DateTime.utc(2026, 10, 1), parcelado: false,
      ).toMap()
        ..remove('previsto')
        ..remove('origemFixoId');

      final reconstruido = Gasto.fromMap('g1', mapa);

      expect(reconstruido.previsto, isFalse);
      expect(reconstruido.origemFixoId, isNull);
    });
  });
}
