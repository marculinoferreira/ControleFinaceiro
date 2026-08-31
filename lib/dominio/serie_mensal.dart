import 'models/ganho.dart';
import 'models/gasto.dart';
import 'models/mes_ref.dart';

/// Um ponto da serie: um mes e os dois totais daquele mes.
///
/// Existe separado de [TotaisMes] porque carrega o mes junto — a serie
/// precisa saber onde cada ponto cai no eixo, e um TotaisMes solto nao sabe.
class PontoMensal {
  final MesRef mes;
  final double ganhos;
  final double gastos;

  const PontoMensal({
    required this.mes,
    required this.ganhos,
    required this.gastos,
  });

  double get saldo => ganhos - gastos;
}

/// Os [quantidade] meses terminando em [fim], do mais antigo para o mais
/// novo. [fim] e o ultimo elemento.
List<MesRef> janelaAte(MesRef fim, int quantidade) {
  _exigirPositivo(quantidade);
  return List.generate(quantidade, (i) => fim.avancar(i - (quantidade - 1)));
}

/// Os [quantidade] meses comecando em [inicio], que e o primeiro elemento.
List<MesRef> janelaDe(MesRef inicio, int quantidade) {
  _exigirPositivo(quantidade);
  return List.generate(quantidade, (i) => inicio.avancar(i));
}

void _exigirPositivo(int quantidade) {
  if (quantidade < 1) {
    throw ArgumentError.value(
        quantidade, 'quantidade', 'precisa ser maior que zero');
  }
}

/// Agrupa lancamentos soltos na serie de [meses], somando so os de
/// [membroId] quando ele nao e nulo.
///
/// Meses sem lancamento entram com zero em vez de sumir: um buraco na linha
/// do grafico leria como "nao sei", quando o que houve foi "nao teve nada".
/// Lancamento fora de [meses] e ignorado, entao quem chama pode passar uma
/// lista maior sem filtrar antes.
List<PontoMensal> montarSerie({
  required List<MesRef> meses,
  required List<Ganho> ganhos,
  required List<Gasto> gastos,
  String? membroId,
}) {
  final somaGanhos = <String, double>{};
  final somaGastos = <String, double>{};

  for (final g in ganhos) {
    if (membroId != null && g.membroId != membroId) continue;
    somaGanhos[g.mesRef] = (somaGanhos[g.mesRef] ?? 0) + g.valor;
  }

  for (final g in gastos) {
    if (membroId != null && g.membroId != membroId) continue;
    somaGastos[g.mesRef] = (somaGastos[g.mesRef] ?? 0) + g.valor;
  }

  return [
    for (final mes in meses)
      PontoMensal(
        mes: mes,
        ganhos: somaGanhos[mes.valor] ?? 0,
        gastos: somaGastos[mes.valor] ?? 0,
      ),
  ];
}
