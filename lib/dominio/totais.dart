import 'models/ganho.dart';
import 'models/gasto.dart';
import 'cascata.dart' show toleranciaCentavo;

/// Totais de um mes, para uma pessoa ou para o casal.
class TotaisMes {
  final double ganhos;
  final double gastos;

  const TotaisMes({required this.ganhos, required this.gastos});

  /// "Saldo para passar o mes".
  double get saldo => ganhos - gastos;
}

/// Com [membroId] nulo, soma o casal inteiro.
TotaisMes calcularTotais({
  required List<Ganho> ganhos,
  required List<Gasto> gastos,
  String? membroId,
}) {
  var somaGanhos = 0.0;
  for (final g in ganhos) {
    if (membroId == null || g.membroId == membroId) somaGanhos += g.valor;
  }

  var somaGastos = 0.0;
  for (final g in gastos) {
    if (membroId == null || g.membroId == membroId) somaGastos += g.valor;
  }

  return TotaisMes(ganhos: somaGanhos, gastos: somaGastos);
}

Map<String, double> somarGanhosPorMembro(List<Ganho> ganhos) {
  final mapa = <String, double>{};
  for (final g in ganhos) {
    mapa[g.membroId] = (mapa[g.membroId] ?? 0) + g.valor;
  }
  return mapa;
}

Map<String, double> somarGastosPorMembro(List<Gasto> gastos) {
  final mapa = <String, double>{};
  for (final g in gastos) {
    mapa[g.membroId] = (mapa[g.membroId] ?? 0) + g.valor;
  }
  return mapa;
}

Map<String, double> somarGastosPorPote(List<Gasto> gastos, {String? membroId}) {
  final mapa = <String, double>{};
  for (final g in gastos) {
    if (membroId != null && g.membroId != membroId) continue;
    mapa[g.poteId] = (mapa[g.poteId] ?? 0) + g.valor;
  }
  return mapa;
}

/// Soma por cartao, com a mesma convencao de `_passaNoCartao`: gasto sem
/// cartao (ou com um cartao que foi apagado) cai na chave ''.
Map<String, double> somarGastosPorCartao(List<Gasto> gastos,
    {String? membroId}) {
  final mapa = <String, double>{};
  for (final g in gastos) {
    if (membroId != null && g.membroId != membroId) continue;
    final chave = g.cartaoId ?? '';
    mapa[chave] = (mapa[chave] ?? 0) + g.valor;
  }
  return mapa;
}

/// Quanto de parcela ja esta comprometido em [mesRef].
/// Alimenta o grafico de comprometimento futuro. Com [membroId] nulo, soma
/// o casal inteiro.
double comprometidoNoMes(List<Gasto> gastos, String mesRef,
    {String? membroId}) {
  var soma = 0.0;
  for (final g in gastos) {
    if (!g.parcelado || g.mesRef != mesRef) continue;
    if (membroId != null && g.membroId != membroId) continue;
    soma += g.valor;
  }
  return soma;
}

/// Fracao da renda do mes ja comprometida em parcelas. Nula sem renda, para
/// nao dividir por zero — a UI mostra "sem renda" nesse caso, nao 0% nem
/// infinito.
double? percentualComprometido({
  required double comprometido,
  required double renda,
}) {
  if (renda <= toleranciaCentavo) return null;
  return comprometido / renda;
}

/// Filtra os ganhos de UM MES para "o que efetivamente conta" na renda:
/// os ganhos reais de cada pessoa quando existir pelo menos um; senao, os
/// previstos dela. Nunca mistura real e previsto da mesma pessoa.
///
/// Assume que [ganhosDoMes] ja pertence a um unico mes — "tem ganho real"
/// precisa ser respondido mes a mes, nao ao longo de uma janela inteira
/// (ver `ganhosEfetivosPorMes` em serie_mensal.dart para o caso de varios
/// meses).
List<Ganho> ganhosEfetivos(List<Ganho> ganhosDoMes) {
  final membrosComReal = <String>{
    for (final g in ganhosDoMes)
      if (!g.previsto) g.membroId,
  };
  return [
    for (final g in ganhosDoMes)
      if (!g.previsto || !membrosComReal.contains(g.membroId)) g,
  ];
}
