import 'models/ganho.dart';
import 'models/gasto.dart';

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
