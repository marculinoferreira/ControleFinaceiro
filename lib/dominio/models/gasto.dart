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

  /// Dia em que o gasto aconteceu, que nao e o mesmo que [criadoEm] (quando
  /// o lancamento foi digitado). Usada para agrupar e ordenar a lista.
  ///
  /// **Nao decide o mes do orcamento.** Quem decide e [mesRef], que vem do
  /// mes selecionado na tela: um gasto datado de 31/07 lancado em agosto
  /// conta em agosto. A data serve para a pessoa se localizar, nao para
  /// mover dinheiro entre meses.
  final DateTime data;

  final bool parcelado;

  /// Por onde o dinheiro saiu. Nulo quando foi dinheiro, pix ou debito —
  /// nem todo gasto passa por um cartao, entao o campo e opcional.
  final String? cartaoId;

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
    // Ausente cai para criadoEm: e o que os lancamentos gravados antes deste
    // campo existir tem de mais proximo do dia da compra.
    DateTime? data,
    this.cartaoId,
    this.compraId,
    this.parcela,
    this.totalParcelas,
  }) : data = data ?? criadoEm;

  factory Gasto.fromMap(String id, Map<String, dynamic> mapa) => Gasto(
        id: id,
        mesRef: mapa['mesRef'] as String,
        membroId: mapa['membroId'] as String,
        poteId: mapa['poteId'] as String,
        descricao: mapa['descricao'] as String,
        valor: (mapa['valor'] as num).toDouble(),
        criadoEm: _lerData(mapa['criadoEm']),
        data: mapa['data'] == null ? null : _lerData(mapa['data']),
        parcelado: mapa['parcelado'] as bool? ?? false,
        cartaoId: mapa['cartaoId'] as String?,
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
        'data': data,
        'parcelado': parcelado,
        'cartaoId': cartaoId,
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
    DateTime? data,
    bool? parcelado,
    String? cartaoId,
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
        data: data ?? this.data,
        parcelado: parcelado ?? this.parcelado,
        cartaoId: cartaoId ?? this.cartaoId,
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
