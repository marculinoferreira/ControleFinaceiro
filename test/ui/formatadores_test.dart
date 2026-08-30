import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/ui/tema/formatadores.dart';

void main() {
  group('resumoParcelamento', () {
    test('monta a linha de preview com inicio e fim', () {
      final texto = resumoParcelamento(
        valorParcela: 100,
        quantidade: 10,
        inicio: const MesRef(2026, 8),
      );

      expect(texto, startsWith('10x de '));
      expect(texto, contains(formatarReais(100)));
      expect(texto, contains(formatarReais(1000)));
      expect(texto, contains('Ago/26'));
      expect(texto, contains('Mai/27'));
      expect(texto, contains('→'));
    });

    test('uma parcela nao e parcelamento: sem "x" e sem seta', () {
      final texto = resumoParcelamento(
        valorParcela: 250,
        quantidade: 1,
        inicio: const MesRef(2026, 8),
      );

      expect(texto, contains(formatarReais(250)));
      expect(texto, contains('Ago/26'));
      expect(texto, isNot(contains('→')));
      expect(texto, isNot(contains('1x')));
    });

    test('o total e a parcela vezes a quantidade', () {
      final texto = resumoParcelamento(
        valorParcela: 33.33,
        quantidade: 3,
        inicio: const MesRef(2026, 1),
      );

      expect(texto, contains(formatarReais(99.99)));
    });

    test('a virada de ano aparece no mes final', () {
      final texto = resumoParcelamento(
        valorParcela: 50,
        quantidade: 6,
        inicio: const MesRef(2026, 11),
      );

      expect(texto, contains('Nov/26'));
      expect(texto, contains('Abr/27'));
    });
  });

  group('nomeDoMembro e nomeDoPote', () {
    const membros = [
      Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
          cor: '#2E7D32', ordem: 0),
    ];
    const potes = [
      Pote(id: 'p1', nome: 'Custo fixo', percentual: 100, ordem: 0,
          cor: '#2E7D32', icone: 'casa'),
    ];

    test('traduz o id em nome', () {
      expect(nomeDoMembro(membros, 'marcos'), 'Marcos');
      expect(nomeDoPote(potes, 'p1'), 'Custo fixo');
    });

    test('id desconhecido devolve o proprio id, nao vazio', () {
      // Um lancamento cujo pote foi apagado ainda precisa aparecer na
      // lista; sumir com a linha esconderia dinheiro do usuario.
      expect(nomeDoMembro(membros, 'fantasma'), 'fantasma');
      expect(nomeDoPote(potes, 'pX'), 'pX');
    });

    test('lista vazia devolve o id', () {
      expect(nomeDoMembro(const [], 'marcos'), 'marcos');
      expect(nomeDoPote(const [], 'p1'), 'p1');
    });
  });
}
