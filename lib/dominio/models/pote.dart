/// Categoria de orcamento. A [ordem] define a prioridade na cascata.
class Pote {
  final String id;
  final String nome;
  final double percentual;
  final int ordem;
  final String cor;   // hex "#RRGGBB"
  final String icone; // chave textual mapeada para IconData na UI

  const Pote({
    required this.id,
    required this.nome,
    required this.percentual,
    required this.ordem,
    required this.cor,
    required this.icone,
  });

  factory Pote.fromMap(String id, Map<String, dynamic> mapa) => Pote(
        id: id,
        nome: mapa['nome'] as String,
        // Firestore devolve int quando o valor gravado nao tem decimal.
        percentual: (mapa['percentual'] as num).toDouble(),
        ordem: (mapa['ordem'] as num).toInt(),
        cor: mapa['cor'] as String? ?? '#607D8B',
        icone: mapa['icone'] as String? ?? 'carteira',
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'percentual': percentual,
        'ordem': ordem,
        'cor': cor,
        'icone': icone,
      };

  Pote copyWith({
    String? id,
    String? nome,
    double? percentual,
    int? ordem,
    String? cor,
    String? icone,
  }) =>
      Pote(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        percentual: percentual ?? this.percentual,
        ordem: ordem ?? this.ordem,
        cor: cor ?? this.cor,
        icone: icone ?? this.icone,
      );
}
