/// Entrada de renda de uma pessoa em um mes.
class Ganho {
  final String id;
  final String mesRef;
  final String membroId;
  final String descricao;
  final double valor;
  final DateTime criadoEm;

  const Ganho({
    required this.id,
    required this.mesRef,
    required this.membroId,
    required this.descricao,
    required this.valor,
    required this.criadoEm,
  });

  factory Ganho.fromMap(String id, Map<String, dynamic> mapa) => Ganho(
        id: id,
        mesRef: mapa['mesRef'] as String,
        membroId: mapa['membroId'] as String,
        descricao: mapa['descricao'] as String,
        valor: (mapa['valor'] as num).toDouble(),
        criadoEm: _lerData(mapa['criadoEm']),
      );

  Map<String, dynamic> toMap() => {
        'mesRef': mesRef,
        'membroId': membroId,
        'descricao': descricao,
        'valor': valor,
        'criadoEm': criadoEm,
      };

  Ganho copyWith({
    String? id,
    String? mesRef,
    String? membroId,
    String? descricao,
    double? valor,
    DateTime? criadoEm,
  }) =>
      Ganho(
        id: id ?? this.id,
        mesRef: mesRef ?? this.mesRef,
        membroId: membroId ?? this.membroId,
        descricao: descricao ?? this.descricao,
        valor: valor ?? this.valor,
        criadoEm: criadoEm ?? this.criadoEm,
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
