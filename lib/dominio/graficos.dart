import 'cascata.dart';
import 'models/pote.dart';

/// Cor de "Outros". A mesma que `corDeHex` usa quando nao entende o valor,
/// para gasto de pote apagado ficar cinza nos dois caminhos.
const String corNeutra = '#607D8B';

/// Uma fatia do grafico de rosca: um pote e quanto foi gasto nele.
///
/// Carrega [cor] como hex, e nao como Color: o dominio nao conhece Flutter.
/// Quem desenha converte com `corDeHex`.
class FatiaPote {
  final String poteId;
  final String nome;
  final String cor;
  final double valor;

  const FatiaPote({
    required this.poteId,
    required this.nome,
    required this.cor,
    required this.valor,
  });
}

/// Uma barra do grafico de Previsto x Gasto.
class BarraPote {
  final String poteId;
  final String nome;
  final String cor;
  final double previsto;
  final double gasto;

  const BarraPote({
    required this.poteId,
    required this.nome,
    required this.cor,
    required this.previsto,
    required this.gasto,
  });

  bool get estourou => gasto - previsto > toleranciaCentavo;
}

/// Junta os gastos ja somados por pote com os potes cadastrados, na ordem
/// de prioridade da cascata.
///
/// Pote sem gasto nao vira fatia: uma secao de tamanho zero num PieChart
/// nao desenha nada mas ocupa uma entrada da legenda.
///
/// Gasto cujo pote foi apagado nao pode sumir do grafico — o dinheiro saiu
/// de qualquer jeito — entao vai para uma fatia "Outros" no fim.
List<FatiaPote> fatiasPorPote({
  required Map<String, double> porPote,
  required List<Pote> potes,
}) {
  final ordenados = [...potes]..sort((a, b) => a.ordem.compareTo(b.ordem));
  final conhecidos = {for (final p in ordenados) p.id};

  final fatias = <FatiaPote>[];

  for (final pote in ordenados) {
    final valor = porPote[pote.id] ?? 0;
    if (valor <= toleranciaCentavo) continue;
    fatias.add(FatiaPote(
      poteId: pote.id,
      nome: pote.nome,
      cor: pote.cor,
      valor: valor,
    ));
  }

  var orfaos = 0.0;
  for (final entrada in porPote.entries) {
    if (conhecidos.contains(entrada.key)) continue;
    orfaos += entrada.value;
  }

  if (orfaos > toleranciaCentavo) {
    fatias.add(FatiaPote(
      poteId: '',
      nome: 'Outros',
      cor: corNeutra,
      valor: orfaos,
    ));
  }

  return fatias;
}

double totalDasFatias(List<FatiaPote> fatias) {
  var soma = 0.0;
  for (final f in fatias) {
    soma += f.valor;
  }
  return soma;
}

/// Cruza o previsto de cada pote (que a cascata ja calculou) com o gasto
/// classificado naquele pote.
///
/// Ao contrario da rosca, pote sem gasto **continua** na lista: o previsto
/// de um pote intocado e justamente a informacao que interessa ali.
///
/// O gasto nao e limitado pelo previsto. Cortar no teto esconderia o
/// estouro, que e o que o usuario precisa enxergar.
List<BarraPote> barrasPrevistoGasto({
  required List<LinhaCascata> linhas,
  required Map<String, double> porPote,
}) {
  return [
    for (final linha in linhas)
      BarraPote(
        poteId: linha.pote.id,
        nome: linha.pote.nome,
        cor: linha.pote.cor,
        previsto: linha.previsto,
        gasto: porPote[linha.pote.id] ?? 0,
      ),
  ];
}

/// O maior valor que aparece, para o eixo Y nao cortar a barra estourada.
double tetoDasBarras(List<BarraPote> barras) {
  var teto = 0.0;
  for (final b in barras) {
    if (b.previsto > teto) teto = b.previsto;
    if (b.gasto > teto) teto = b.gasto;
  }
  return teto;
}
