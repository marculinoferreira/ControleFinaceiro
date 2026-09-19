import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';

Pote poteBase({
  bool ehReserva = false,
  double? valorGuardado,
}) =>
    Pote(
      id: 'p1',
      nome: 'Reserva',
      percentual: 10,
      ordem: 0,
      cor: '#2E7D32',
      icone: 'cofre',
      ehReserva: ehReserva,
      valorGuardado: valorGuardado,
    );

void main() {
  group('Pote com campos de reserva', () {
    test('default: ehReserva falso, guardado e vaiGanhar nulos', () {
      const pote = Pote(
        id: 'p1',
        nome: 'Custo fixo',
        percentual: 60,
        ordem: 0,
        cor: '#2E7D32',
        icone: 'casa',
      );

      expect(pote.ehReserva, isFalse);
      expect(pote.valorGuardado, isNull);
    });

    test('toMap/fromMap fazem round-trip com os campos preenchidos', () {
      final pote = poteBase(
        ehReserva: true,
        valorGuardado: 6000,
      );

      final reconstruido = Pote.fromMap('p1', pote.toMap());

      expect(reconstruido.ehReserva, isTrue);
      expect(reconstruido.valorGuardado, 6000);
    });

    test('fromMap sem os campos novos (dado legado) cai nos defaults', () {
      final pote = Pote.fromMap('p1', const {
        'nome': 'Custo fixo',
        'percentual': 60,
        'ordem': 0,
        'cor': '#2E7D32',
        'icone': 'casa',
      });

      expect(pote.ehReserva, isFalse);
      expect(pote.valorGuardado, isNull);
    });

    test('toMap de pote sem reserva nao inclui guardado', () {
      final mapa = poteBase().toMap();

      expect(mapa.containsKey('valorGuardado'), isFalse);
      expect(mapa['ehReserva'], isFalse);
    });

    test('copyWith preserva os campos de reserva quando nao especificados',
        () {
      final pote = poteBase(ehReserva: true, valorGuardado: 6000);
      final renomeado = pote.copyWith(nome: 'Reserva de emergencia');

      expect(renomeado.ehReserva, isTrue);
      expect(renomeado.valorGuardado, 6000);
    });

    test('copyWith troca ehReserva para false explicitamente', () {
      final pote = poteBase(ehReserva: true);
      final desmarcado = pote.copyWith(ehReserva: false);

      expect(desmarcado.ehReserva, isFalse);
    });
  });
}
