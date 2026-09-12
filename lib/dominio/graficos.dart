import 'cascata.dart';
import 'models/cartao.dart';
import 'models/membro.dart';
import 'models/pote.dart';

/// Cor de "Outros". A mesma que `corDeHex` usa quando nao entende o valor,
/// para gasto de pote apagado ficar cinza nos dois caminhos.
const String corNeutra = '#607D8B';

/// Uma fatia de grafico circular: o que ela representa e quanto vale.
///
/// Serve tanto para pote (rosca de gastos) quanto para pessoa (pizza de
/// ganhos) — a forma e a mesma, entao o tipo tambem e.
///
/// Carrega [cor] como hex, e nao como Color: o dominio nao conhece Flutter.
/// Quem desenha converte com `corDeHex`.
class Fatia {
  /// Id do pote ou do membro. Vazio na fatia agregada "Outros".
  final String id;
  final String nome;
  final String cor;
  final double valor;

  const Fatia({
    required this.id,
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
List<Fatia> fatiasPorPote({
  required Map<String, double> porPote,
  required List<Pote> potes,
}) {
  final ordenados = [...potes]..sort((a, b) => a.ordem.compareTo(b.ordem));
  return _fatiar(
    valores: porPote,
    ids: [for (final p in ordenados) p.id],
    nome: {for (final p in ordenados) p.id: p.nome},
    cor: {for (final p in ordenados) p.id: p.cor},
  );
}

/// Ganhos por pessoa (grafico 4 da spec 10).
///
/// Ganho de um membro que foi removido da casa cai em "Outros" pela mesma
/// razao do pote apagado: o dinheiro entrou, e sumir com ele faria o total
/// da pizza discordar do total do mes.
List<Fatia> fatiasPorMembro({
  required Map<String, double> porMembro,
  required List<Membro> membros,
}) {
  final ordenados = [...membros]..sort((a, b) => a.ordem.compareTo(b.ordem));
  return _fatiar(
    valores: porMembro,
    ids: [for (final m in ordenados) m.id],
    nome: {for (final m in ordenados) m.id: m.nome},
    cor: {for (final m in ordenados) m.id: m.cor},
  );
}

/// O miolo comum das duas: fatia na ordem dada, descarta valor nao positivo
/// e junta os ids desconhecidos numa fatia "Outros" no fim.
List<Fatia> _fatiar({
  required Map<String, double> valores,
  required List<String> ids,
  required Map<String, String> nome,
  required Map<String, String> cor,
  String nomeOrfaos = 'Outros',
}) {
  final conhecidos = ids.toSet();
  final fatias = <Fatia>[];

  for (final id in ids) {
    final valor = valores[id] ?? 0;
    if (valor <= toleranciaCentavo) continue;
    fatias.add(Fatia(
      id: id,
      nome: nome[id] ?? id,
      cor: cor[id] ?? corNeutra,
      valor: valor,
    ));
  }

  var orfaos = 0.0;
  for (final entrada in valores.entries) {
    if (conhecidos.contains(entrada.key)) continue;
    orfaos += entrada.value;
  }

  if (orfaos > toleranciaCentavo) {
    fatias.add(Fatia(id: '', nome: nomeOrfaos, cor: corNeutra, valor: orfaos));
  }

  return fatias;
}

double totalDasFatias(List<Fatia> fatias) {
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

/// Onde o gasto parou na barra da cascata, como fracao de 0 a 1 do total
/// previsto (grafico 5 da spec 10).
///
/// Sem renda todo previsto e zero e a divisao daria NaN; devolve 0, e quem
/// desenha ja nao desenha barra nenhuma nesse caso.
double posicaoDoGasto(ResultadoCascata resumo) {
  var previsto = 0.0;
  var consumido = 0.0;
  for (final linha in resumo.linhas) {
    previsto += linha.previsto;
    consumido += linha.consumido;
  }
  if (previsto <= toleranciaCentavo) return 0;
  return (consumido / previsto).clamp(0.0, 1.0);
}

/// Peso inteiro de cada pote na barra da cascata, para uso como `flex`.
///
/// Multiplica por 100 antes de arredondar para nao achatar potes pequenos:
/// um pote de 5% num mes de renda baixa arredondaria para 0 e sumiria da
/// barra. Peso minimo 1 pelo mesmo motivo.
List<int> pesosDaCascata(ResultadoCascata resumo) => [
      for (final linha in resumo.linhas)
        linha.previsto <= toleranciaCentavo
            ? 0
            : (linha.previsto * 100).round().clamp(1, 1 << 30),
    ];

/// True quando tudo que seria desenhado e zero. Tres graficos precisam
/// disto para preferir a frase ao desenho: duas retas coladas no eixo, ou
/// barras de altura zero, nao dizem nada a quem olha.
bool serieVazia(Iterable<double> valores) =>
    valores.every((v) => v.abs() <= toleranciaCentavo);

/// Paleta fixa para entidades sem cor propria (Cartao). Mesmos tons de
/// `tela_potes.dart`, para a rosca de cartao nao destoar do resto do app.
const List<String> paletaCartoes = [
  '#2E7D32', '#1565C0', '#00838F', '#EF6C00', '#AD1457', '#4527A0',
];

/// Fatias da rosca de gastos por cartao (fora da numeracao da spec 10).
///
/// Cartao nao tem cor propria como Pote/Membro; a cor de cada fatia vem da
/// paleta fixa, ciclada pela ordem de cadastro.
List<Fatia> fatiasPorCartao({
  required Map<String, double> porCartao,
  required List<Cartao> cartoes,
}) {
  final ordenados = [...cartoes]..sort((a, b) => a.ordem.compareTo(b.ordem));
  return _fatiar(
    valores: porCartao,
    ids: [for (final c in ordenados) c.id],
    nome: {for (final c in ordenados) c.id: c.nome},
    cor: {
      for (final (i, c) in ordenados.indexed)
        c.id: paletaCartoes[i % paletaCartoes.length]
    },
    nomeOrfaos: 'Sem cartão',
  );
}
