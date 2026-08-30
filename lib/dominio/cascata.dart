import 'dart:math' as math;

import 'models/pote.dart';

/// Meio centavo. Comparacao de dinheiro em double nunca usa == nem > 0 puro.
const double toleranciaCentavo = 0.005;

/// Uma linha da tabela de resumo: quanto o pote previa, quanto a cascata
/// consumiu dele e quanto restou.
class LinhaCascata {
  final Pote pote;
  final double previsto;
  final double consumido;
  final double sobra;

  const LinhaCascata({
    required this.pote,
    required this.previsto,
    required this.consumido,
    required this.sobra,
  });
}

class ResultadoCascata {
  final List<LinhaCascata> linhas;

  /// Pote onde o gasto parou. Null quando o gasto passou de todos.
  final Pote? poteAtivo;

  /// Quanto de gasto sobrou depois de esgotar todos os potes.
  final double excedente;

  const ResultadoCascata({
    required this.linhas,
    required this.poteAtivo,
    required this.excedente,
  });

  bool get estourouTudo => poteAtivo == null;

  /// Rotulo exibido em destaque na tela de Resumo.
  String get rotulo => poteAtivo?.nome.toUpperCase() ?? 'PARE DE GASTAR';
}

/// Faz o gasto **total** escorrer pela fila de potes na ordem de prioridade.
///
/// Cada pote absorve ate o seu valor previsto; o que passar disso escorre
/// para o proximo. O pote ativo e o primeiro que ainda tem folga — e o que
/// a pessoa esta consumindo agora.
///
/// O pote de cada gasto individual NAO participa deste calculo; ele e
/// classificacao, usada nos graficos.
ResultadoCascata calcularCascata({
  required List<Pote> potes,
  required double totalGanhos,
  required double totalGastos,
}) {
  final ordenados = [...potes]..sort((a, b) => a.ordem.compareTo(b.ordem));

  var restante = totalGastos;
  final linhas = <LinhaCascata>[];
  Pote? poteAtivo;

  for (final pote in ordenados) {
    final previsto = totalGanhos * pote.percentual / 100;
    final consumido = math.min(restante, previsto);
    final sobra = previsto - consumido;
    restante -= consumido;

    if (poteAtivo == null && sobra > toleranciaCentavo) {
      poteAtivo = pote;
    }

    linhas.add(LinhaCascata(
      pote: pote,
      previsto: previsto,
      consumido: consumido,
      sobra: sobra,
    ));
  }

  return ResultadoCascata(
    linhas: linhas,
    poteAtivo: poteAtivo,
    excedente: restante,
  );
}
