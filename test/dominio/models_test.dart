import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';

void main() {
  group('Pote', () {
    final mapa = {
      'nome': 'Custo fixo',
      'percentual': 55,
      'ordem': 0,
      'cor': '#2E7D32',
      'icone': 'casa',
    };

    test('fromMap le o id de fora do mapa', () {
      final pote = Pote.fromMap('p1', mapa);
      expect(pote.id, 'p1');
      expect(pote.nome, 'Custo fixo');
      expect(pote.percentual, 55.0);
      expect(pote.ordem, 0);
    });

    test('aceita percentual gravado como int pelo Firestore', () {
      expect(Pote.fromMap('p1', mapa).percentual, isA<double>());
    });

    test('toMap nao inclui o id', () {
      expect(Pote.fromMap('p1', mapa).toMap().containsKey('id'), isFalse);
    });

    test('round-trip preserva os campos', () {
      final original = Pote.fromMap('p1', mapa);
      final volta = Pote.fromMap('p1', original.toMap());
      expect(volta.nome, original.nome);
      expect(volta.percentual, original.percentual);
      expect(volta.cor, original.cor);
    });

    test('copyWith troca so o campo pedido', () {
      final pote = Pote.fromMap('p1', mapa).copyWith(percentual: 40);
      expect(pote.percentual, 40.0);
      expect(pote.nome, 'Custo fixo');
    });
  });

  group('Casa', () {
    final casa = Casa.fromMap('principal', {
      'nome': 'Casa Marcos & Silvia',
      'membros': {
        'marcos': {
          'nome': 'Marcos',
          'email': 'marcos.centrone@gmail.com',
          'cor': '#2E7D32',
          'ordem': 0,
        },
        'silvia': {
          'nome': 'Silvia',
          'email': 'silviabborges3@gmail.com',
          'cor': '#6A1B9A',
          'ordem': 1,
        },
      },
    });

    test('membros vem ordenados por ordem', () {
      expect(casa.membros.map((m) => m.id).toList(), ['marcos', 'silvia']);
    });

    test('membroPorEmail encontra ignorando maiuscula', () {
      expect(casa.membroPorEmail('MARCOS.CENTRONE@GMAIL.COM')?.id, 'marcos');
    });

    test('membroPorEmail devolve null para desconhecido', () {
      expect(casa.membroPorEmail('outro@gmail.com'), isNull);
    });

    test('membroPorId devolve null para id inexistente', () {
      expect(casa.membroPorId('joao'), isNull);
    });
  });

  group('Ganho', () {
    test('round-trip preserva valor e mesRef', () {
      final ganho = Ganho(
        id: 'g1',
        mesRef: '2026-08',
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 4200.50,
        criadoEm: DateTime.utc(2026, 8, 5),
      );
      final volta = Ganho.fromMap('g1', ganho.toMap());
      expect(volta.valor, 4200.50);
      expect(volta.mesRef, '2026-08');
      expect(volta.membroId, 'marcos');
    });
  });

  group('Gasto', () {
    Gasto base({
      bool parcelado = false,
      String? compraId,
      int? parcela,
      int? total,
    }) =>
        Gasto(
          id: 'x1',
          mesRef: '2026-08',
          membroId: 'marcos',
          poteId: 'p1',
          descricao: 'Geladeira',
          valor: 100,
          criadoEm: DateTime.utc(2026, 8, 5),
          parcelado: parcelado,
          compraId: compraId,
          parcela: parcela,
          totalParcelas: total,
        );

    test('rotuloParcela vazio quando nao e parcelado', () {
      expect(base().rotuloParcela, '');
    });

    test('rotuloParcela mostra parcela sobre total', () {
      final g = base(parcelado: true, compraId: 'c1', parcela: 3, total: 10);
      expect(g.rotuloParcela, '3/10');
    });

    test('round-trip preserva os campos de parcelamento', () {
      final g = base(parcelado: true, compraId: 'c1', parcela: 3, total: 10);
      final volta = Gasto.fromMap('x1', g.toMap());
      expect(volta.parcelado, isTrue);
      expect(volta.compraId, 'c1');
      expect(volta.parcela, 3);
      expect(volta.totalParcelas, 10);
    });

    test('round-trip de gasto simples mantem campos de parcela nulos', () {
      final volta = Gasto.fromMap('x1', base().toMap());
      expect(volta.parcelado, isFalse);
      expect(volta.compraId, isNull);
      expect(volta.parcela, isNull);
    });
  });
}
