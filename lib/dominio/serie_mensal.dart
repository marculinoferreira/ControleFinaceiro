import 'models/ganho.dart';
import 'models/gasto.dart';
import 'models/membro.dart';
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

/// Projeta [meses] a frente somando, mes a mes, a renda de cada membro de
/// [membros]: quem lancou algo (real ou previsto, ver `ganhosEfetivos` em
/// totais.dart) naquele mes usa o que lancou; quem nao lancou nada continua
/// com a propria renda assumida (`ganhoAssumidoPorMembro`), mesmo que outra
/// pessoa ja tenha dado dado para aquele mes.
///
/// Isso e o que evita o bug de "mais dado piora a projecao": resolver so
/// pelo mes inteiro (um previsto so de uma pessoa "preenchendo" o mes)
/// faria a renda da outra pessoa sumir da conta em vez de cair na media
/// dela. Aqui cada membro e resolvido de forma independente, e so depois
/// os resultados sao somados.
///
/// Nao e previsao nem media: e a mesma renda de hoje (ou o previsto ja
/// lancado), os mesmos compromissos ja lancados -- a pergunta que responde
/// e "se nada mudar, sobra ou falta dinheiro nos proximos meses".
/// Compromisso futuro sai de graca de `comprometidoNoMes`, o mesmo calculo
/// do grafico de Comprometido.
///
/// Com [membroId] informado, so aquele membro entra na soma de ganhos (e
/// `comprometidoNoMes` tambem filtra os gastos por ele); com nulo, soma
/// todo mundo em [membros] (visao Casal).
List<PontoProjecao> serieProjecao({
  required List<MesRef> meses,
  required List<Membro> membros,
  required Map<String, double> ganhoAssumidoPorMembro,
  required Map<String, Map<String, double>> ganhosConhecidosPorMembro,
  required List<Gasto> parcelas,
  String? membroId,
}) {
  final consideradas =
      membroId == null ? membros : membros.where((m) => m.id == membroId);
  return [
    for (final mes in meses)
      PontoProjecao(
        mes: mes,
        ganhos: [
          for (final m in consideradas)
            ganhosConhecidosPorMembro[m.id]?[mes.valor] ??
                (ganhoAssumidoPorMembro[m.id] ?? 0),
        ].fold(0.0, (a, b) => a + b),
        gastos: comprometidoNoMes(parcelas, mes.valor, membroId: membroId),
      ),
  ];
}

/// Gasto classificado num pote especifico, mes a mes, nos [meses] dados.
/// Mesma forma de `serieComprometimento`, mas soma gasto real classificado
/// no pote (nao parcela em aberto) — as duas series sao "um mes, um valor",
/// so a origem do valor muda, entao reaproveitam `PontoComprometido`.
List<PontoComprometido> serieGastoPote({
  required List<MesRef> meses,
  required List<Gasto> gastos,
  required String poteId,
  String? membroId,
}) {
  final somaPorMes = <String, double>{};
  for (final g in gastos) {
    if (g.poteId != poteId) continue;
    if (membroId != null && g.membroId != membroId) continue;
    somaPorMes[g.mesRef] = (somaPorMes[g.mesRef] ?? 0) + g.valor;
  }
  return [
    for (final mes in meses)
      PontoComprometido(mes: mes, valor: somaPorMes[mes.valor] ?? 0),
  ];
}

/// Ganho efetivo (real-ou-previsto, ver `ganhosEfetivos` em totais.dart) de
/// UM membro especifico, mes a mes, a partir de uma janela com varios meses
/// misturados (ex.: `ganhosDoIntervaloProvider`).
///
/// So entra no mapa nos meses em que [membroId] ELE MESMO lancou algo (real
/// ou previsto) — quem nao lancou nada naquele mes fica de fora, para que
/// quem consome caia na renda assumida dele (`serieProjecao`). Diferente de
/// decidir "o mes tem dado" olhando a janela inteira: aqui a pergunta e
/// sempre por pessoa, entao o previsto de uma pessoa nunca faz a renda
/// assumida de outra sumir da conta.
Map<String, double> ganhoEfetivoDoMembroPorMes({
  required List<Ganho> ganhosDoIntervalo,
  required List<MesRef> meses,
  required String membroId,
}) {
  final porMes = <String, List<Ganho>>{};
  for (final g in ganhosDoIntervalo) {
    if (g.membroId != membroId) continue;
    (porMes[g.mesRef] ??= []).add(g);
  }

  return {
    for (final mes in meses)
      if (porMes[mes.valor] != null)
        mes.valor: calcularTotais(
          ganhos: ganhosEfetivos(porMes[mes.valor]!),
          gastos: const [],
          membroId: membroId,
        ).ganhos,
  };
}
