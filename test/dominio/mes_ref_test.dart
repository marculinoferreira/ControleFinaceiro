import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';

void main() {
  group('MesRef.parse', () {
    test('aceita formato YYYY-MM', () {
      final mes = MesRef.parse('2026-08');
      expect(mes.ano, 2026);
      expect(mes.mes, 8);
    });

    test('rejeita mes sem zero a esquerda', () {
      expect(() => MesRef.parse('2026-8'), throwsFormatException);
    });

    test('rejeita mes 13', () {
      expect(() => MesRef.parse('2026-13'), throwsFormatException);
    });

    test('rejeita mes 00', () {
      expect(() => MesRef.parse('2026-00'), throwsFormatException);
    });

    test('rejeita texto livre', () {
      expect(() => MesRef.parse('agosto'), throwsFormatException);
    });
  });

  group('valor', () {
    test('sempre usa zero a esquerda', () {
      expect(const MesRef(2026, 1).valor, '2026-01');
      expect(const MesRef(2026, 12).valor, '2026-12');
    });
  });

  group('avancar', () {
    test('avanca dentro do mesmo ano', () {
      expect(const MesRef(2026, 3).avancar(2).valor, '2026-05');
    });

    test('vira o ano para frente', () {
      expect(const MesRef(2026, 12).avancar(1).valor, '2027-01');
    });

    test('vira o ano para tras', () {
      expect(const MesRef(2026, 1).avancar(-1).valor, '2025-12');
    });

    test('avanca 24 meses da exatamente dois anos', () {
      expect(const MesRef(2026, 8).avancar(24).valor, '2028-08');
    });

    test('avancar zero devolve o mesmo mes', () {
      expect(const MesRef(2026, 8).avancar(0).valor, '2026-08');
    });

    test('parcela 10 a partir de agosto de 2026 cai em maio de 2027', () {
      // parcela N usa avancar(N - 1)
      expect(const MesRef(2026, 8).avancar(9).valor, '2027-05');
    });
  });

  group('diferencaEm', () {
    test('conta meses entre dois refs', () {
      expect(const MesRef(2027, 5).diferencaEm(const MesRef(2026, 8)), 9);
    });

    test('e negativa quando o outro e posterior', () {
      expect(const MesRef(2026, 8).diferencaEm(const MesRef(2027, 5)), -9);
    });
  });

  group('ordenacao e igualdade', () {
    test('ordena cronologicamente', () {
      final lista = [
        const MesRef(2027, 1),
        const MesRef(2026, 12),
        const MesRef(2026, 2),
      ]..sort();
      expect(lista.map((m) => m.valor).toList(),
          ['2026-02', '2026-12', '2027-01']);
    });

    test('dois meses iguais sao iguais e tem o mesmo hashCode', () {
      expect(const MesRef(2026, 8), const MesRef(2026, 8));
      expect(const MesRef(2026, 8).hashCode, const MesRef(2026, 8).hashCode);
    });
  });

  group('formatacao', () {
    test('extenso', () {
      expect(const MesRef(2026, 8).formatarExtenso(), 'Agosto/2026');
    });

    test('curto', () {
      expect(const MesRef(2026, 8).formatarCurto(), 'Ago/26');
    });
  });
}
