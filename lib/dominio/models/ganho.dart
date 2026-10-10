/// Entrada de renda de uma pessoa em um mes.
class Ganho {
  final String id;
  final String mesRef;
  final String membroId;
  final String descricao;
  final double valor;
  final DateTime criadoEm;

  /// Marca que este ganho e uma previsao ("eu sei que vou ganhar X"), nao
  /// um ganho ja recebido. So conta nos calculos de renda quando a mesma
  /// pessoa nao tiver nenhum ganho real (previsto == false) no mesmo mes —
  /// ver `ganhosEfetivos` em totais.dart.
  final bool previsto;

  /// Id do Fixo que gerou este lancamento, se veio de um -- null para
  /// lancamentos avulsos (a maioria). Usado por `travadoPorFixo` para
  /// travar edicao/exclusao ate o mes chegar.
  final String? origemFixoId;

  const Ganho({
    required this.id,
    required this.mesRef,
    required this.membroId,
    required this.descricao,
    required this.valor,
    required this.criadoEm,
    this.previsto = false,
    this.origemFixoId,
  });

  factory Ganho.fromMap(String id, Map<String, dynamic> mapa) => Ganho(
        id: id,
        mesRef: mapa['mesRef'] as String,
        membroId: mapa['membroId'] as String,
        descricao: mapa['descricao'] as String,
        valor: (mapa['valor'] as num).toDouble(),
        criadoEm: _lerData(mapa['criadoEm']),
        previsto: mapa['previsto'] as bool? ?? false,
        origemFixoId: mapa['origemFixoId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'mesRef': mesRef,
        'membroId': membroId,
        'descricao': descricao,
        'valor': valor,
        'criadoEm': criadoEm,
        'previsto': previsto,
        'origemFixoId': origemFixoId,
      };

  Ganho copyWith({
    String? id,
    String? mesRef,
    String? membroId,
    String? descricao,
    double? valor,
    DateTime? criadoEm,
    bool? previsto,
    String? origemFixoId,
  }) =>
      Ganho(
        id: id ?? this.id,
        mesRef: mesRef ?? this.mesRef,
        membroId: membroId ?? this.membroId,
        descricao: descricao ?? this.descricao,
        valor: valor ?? this.valor,
        criadoEm: criadoEm ?? this.criadoEm,
        previsto: previsto ?? this.previsto,
        origemFixoId: origemFixoId ?? this.origemFixoId,
      );
}

/// O Firestore devolve Timestamp; os testes de dominio passam DateTime.
/// Converter aqui mantem o dominio livre de import do cloud_firestore:
/// Timestamp expoe toDate() e e aceito via duck typing dinamico.
DateTime _lerData(dynamic bruto) {
  if (bruto is DateTime) return bruto;
  if (bruto == null) return DateTime.now();
  return (bruto as dynamic).toDate() as DateTime;
}
