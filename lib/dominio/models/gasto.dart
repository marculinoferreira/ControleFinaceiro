/// Lancamento de gasto. Quando [parcelado], compartilha [compraId] com as
/// demais parcelas da mesma compra.
class Gasto {
  final String id;
  final String mesRef;
  final String membroId;
  final String poteId;
  final String descricao;
  final double valor;
  final DateTime criadoEm;
  final bool parcelado;
  final String? compraId;
  final int? parcela;
  final int? totalParcelas;

  const Gasto({
    required this.id,
    required this.mesRef,
    required this.membroId,
    required this.poteId,
    required this.descricao,
    required this.valor,
    required this.criadoEm,
    required this.parcelado,
    this.compraId,
    this.parcela,
    this.totalParcelas,
  });

  factory Gasto.fromMap(String id, Map<String, dynamic> mapa) => Gasto(
        id: id,
        mesRef: mapa['mesRef'] as String,
        membroId: mapa['membroId'] as String,
        poteId: mapa['poteId'] as String,
        descricao: mapa['descricao'] as String,
        valor: (mapa['valor'] as num).toDouble(),
        criadoEm: _lerData(mapa['criadoEm']),
        parcelado: mapa['parcelado'] as bool? ?? false,
        compraId: mapa['compraId'] as String?,
        parcela: (mapa['parcela'] as num?)?.toInt(),
        totalParcelas: (mapa['totalParcelas'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        'mesRef': mesRef,
        'membroId': membroId,
        'poteId': poteId,
        'descricao': descricao,
        'valor': valor,
        'criadoEm': criadoEm,
        'parcelado': parcelado,
        'compraId': compraId,
        'parcela': parcela,
        'totalParcelas': totalParcelas,
      };

  /// "3/10" quando parcelado, string vazia caso contrario.
  String get rotuloParcela =>
      parcelado && parcela != null && totalParcelas != null
          ? '$parcela/$totalParcelas'
          : '';

  Gasto copyWith({
    String? id,
    String? mesRef,
    String? membroId,
    String? poteId,
    String? descricao,
    double? valor,
    DateTime? criadoEm,
    bool? parcelado,
    String? compraId,
    int? parcela,
    int? totalParcelas,
  }) =>
      Gasto(
        id: id ?? this.id,
        mesRef: mesRef ?? this.mesRef,
        membroId: membroId ?? this.membroId,
        poteId: poteId ?? this.poteId,
        descricao: descricao ?? this.descricao,
        valor: valor ?? this.valor,
        criadoEm: criadoEm ?? this.criadoEm,
        parcelado: parcelado ?? this.parcelado,
        compraId: compraId ?? this.compraId,
        parcela: parcela ?? this.parcela,
        totalParcelas: totalParcelas ?? this.totalParcelas,
      );
}

DateTime _lerData(dynamic bruto) {
  if (bruto is DateTime) return bruto;
  if (bruto == null) return DateTime.now();
  return (bruto as dynamic).toDate() as DateTime;
}
