import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';

void main() {
  group('Ganho com o campo previsto', () {
    test('default: previsto falso', () {
      final ganho = Ganho(
        id: 'g1',
        mesRef: '2026-10',
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 3800,
        criadoEm: DateTime.utc(2026, 9, 1),
      );

      expect(ganho.previsto, isFalse);
    });

    test('toMap/fromMap fazem round-trip com previsto true', () {
      final ganho = Ganho(
        id: 'g1',
        mesRef: '2026-10',
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 3800,
        criadoEm: DateTime.utc(2026, 9, 1),
        previsto: true,
      );

      final reconstruido = Ganho.fromMap('g1', ganho.toMap());

      expect(reconstruido.previsto, isTrue);
    });

    test('fromMap sem a chave previsto (dado legado) cai em falso', () {
      final ganho = Ganho.fromMap('g1', {
        'mesRef': '2026-08',
        'membroId': 'marcos',
        'descricao': 'Salario',
        'valor': 5000,
        'criadoEm': DateTime.utc(2026, 8, 1),
      });

      expect(ganho.previsto, isFalse);
    });

    test('copyWith preserva previsto quando nao especificado', () {
      final ganho = Ganho(
        id: 'g1',
        mesRef: '2026-10',
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 3800,
        criadoEm: DateTime.utc(2026, 9, 1),
        previsto: true,
      );

      final renomeado = ganho.copyWith(descricao: 'Salario CLT');

      expect(renomeado.previsto, isTrue);
      expect(renomeado.descricao, 'Salario CLT');
    });

    test('copyWith troca previsto para false explicitamente', () {
      final ganho = Ganho(
        id: 'g1',
        mesRef: '2026-10',
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 3800,
        criadoEm: DateTime.utc(2026, 9, 1),
        previsto: true,
      );

      final atualizado = ganho.copyWith(previsto: false);

      expect(atualizado.previsto, isFalse);
    });

    test('round-trip toMap/fromMap preserva origemFixoId', () {
      final g = Ganho(
        id: '', mesRef: '2026-11', membroId: 'marcos',
        descricao: 'Salario', valor: 5000,
        criadoEm: DateTime.utc(2026, 10, 1),
        previsto: true, origemFixoId: 'f1',
      );

      final reconstruido = Ganho.fromMap('g1', g.toMap());

      expect(reconstruido.origemFixoId, 'f1');
    });

    test('origemFixoId ausente no mapa (lancamento legado) cai em null', () {
      final mapa = Ganho(
        id: '', mesRef: '2026-11', membroId: 'marcos',
        descricao: 'Salario', valor: 5000,
        criadoEm: DateTime.utc(2026, 10, 1),
      ).toMap()
        ..remove('origemFixoId');

      final reconstruido = Ganho.fromMap('g1', mapa);

      expect(reconstruido.origemFixoId, isNull);
    });
  });
}
