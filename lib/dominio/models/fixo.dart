enum TipoFixo { ganho, gasto }

/// Molde de um ganho ou gasto recorrente e previsivel (salario, aluguel,
/// assinatura): enquanto existir, gera um lancamento previsto (Ganho ou
/// Gasto, conforme [tipo]) no mes seguinte ao mes real de hoje, toda vez
/// que o app verifica (ver `garantirFixosDoMesProvider` em
/// lib/estado/providers.dart).
///
/// Excluir o Fixo so impede gerar NOVOS meses -- lancamentos que ele ja
/// gerou continuam existindo, independentes dele a partir dai.
class Fixo {
  final String id;
  final TipoFixo tipo;
  final String membroId;
  final String descricao;
  final double valor;

  /// So para `tipo == TipoFixo.gasto`. Nulo (e sem sentido) para ganho.
  final String? poteId;

  final DateTime criadoEm;

  const Fixo({
    required this.id,
    required this.tipo,
    required this.membroId,
    required this.descricao,
    required this.valor,
    required this.criadoEm,
    this.poteId,
  });

  factory Fixo.fromMap(String id, Map<String, dynamic> mapa) => Fixo(
        id: id,
        tipo: (mapa['tipo'] as String) == 'ganho'
            ? TipoFixo.ganho
            : TipoFixo.gasto,
        membroId: mapa['membroId'] as String,
        descricao: mapa['descricao'] as String,
        valor: (mapa['valor'] as num).toDouble(),
        criadoEm: _lerData(mapa['criadoEm']),
        poteId: mapa['poteId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'tipo': tipo == TipoFixo.ganho ? 'ganho' : 'gasto',
        'membroId': membroId,
        'descricao': descricao,
        'valor': valor,
        'criadoEm': criadoEm,
        'poteId': poteId,
      };
}

DateTime _lerData(dynamic bruto) {
  if (bruto is DateTime) return bruto;
  if (bruto == null) return DateTime.now();
  return (bruto as dynamic).toDate() as DateTime;
}
