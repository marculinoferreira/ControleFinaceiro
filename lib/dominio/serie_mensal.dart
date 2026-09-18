import 'models/ganho.dart';
import 'models/gasto.dart';
import 'models/mes_ref.dart';
import 'totais.dart';

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

/// Um mes e quanto dele ja esta comprometido em parcelas.
class PontoComprometido {
  final MesRef mes;
  final double valor;

  const PontoComprometido({required this.mes, required this.valor});
}

/// Quanto de cada mes de [meses] ja esta tomado por parcelas (grafico 6 da
/// spec 10), somando so as de [membroId] quando ele nao e nulo.
///
/// [parcelas] sao os gastos parcelados a partir do mes corrente; cada um ja
/// e um documento no mes em que cai, entao aqui e so somar por mes.
///
/// Meses sem parcela entram com zero: a linha precisa cair ate o chao
/// depois da ultima parcela, e nao terminar no ar.
List<PontoComprometido> serieComprometimento({
  required List<MesRef> meses,
  required List<Gasto> parcelas,
  String? membroId,
}) =>
    [
      for (final mes in meses)
        PontoComprometido(
          mes: mes,
          valor: comprometidoNoMes(parcelas, mes.valor, membroId: membroId),
        ),
    ];

/// Um mes projetado: renda repetida do mes de referencia, gasto = o que ja
/// esta comprometido em parcelas naquele mes.
class PontoProjecao {
  final MesRef mes;
  final double ganhos;
  final double gastos;

  const PontoProjecao({
    required this.mes,
    required this.ganhos,
    required this.gastos,
  });

  double get saldo => ganhos - gastos;
}

/// Projeta [meses] a frente assumindo renda constante (o ganho real do mes
/// de referencia, repetido) contra o gasto ja comprometido em parcelas.
///
/// Nao e previsao nem media: e a mesma renda de hoje, os mesmos
/// compromissos ja lancados -- a pergunta que responde e "se nada mudar,
/// sobra ou falta dinheiro nos proximos meses". Compromisso futuro sai de
/// graca de `comprometidoNoMes`, o mesmo calculo do grafico de
/// Comprometido.
List<PontoProjecao> serieProjecao({
  required List<MesRef> meses,
  required double ganhoMensalAssumido,
  required List<Gasto> parcelas,
  String? membroId,
}) =>
    [
      for (final mes in meses)
        PontoProjecao(
          mes: mes,
          ganhos: ganhoMensalAssumido,
          gastos: comprometidoNoMes(parcelas, mes.valor, membroId: membroId),
        ),
    ];
