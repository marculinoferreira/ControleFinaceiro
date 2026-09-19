/// Categoria de orcamento. A [ordem] define a prioridade na cascata.
class Pote {
  final String id;
  final String nome;
  final double percentual;
  final int ordem;
  final String cor;   // hex "#RRGGBB"
  final String icone; // chave textual mapeada para IconData na UI

  /// Marca este como o pote de reserva de emergencia da casa. No maximo um
  /// pote pode ter isto true por vez -- a UI desmarca o anterior ao marcar
  /// um novo.
  final bool ehReserva;

  /// Quanto ja esta guardado, digitado manualmente. So tem sentido quando
  /// [ehReserva] e true; nulo enquanto o usuario nao preencheu.
  final double? valorGuardado;

  /// Quanto se espera ganhar no mes seguinte ao selecionado, digitado
  /// manualmente. So tem sentido quando [ehReserva] e true. Alimenta
  /// `serieProjecaoProvider` para o mes imediatamente seguinte, so enquanto
  /// esse mes nao tiver ganho real lancado.
  final double? proximoGanhoEsperado;

  const Pote({
    required this.id,
    required this.nome,
    required this.percentual,
    required this.ordem,
    required this.cor,
    required this.icone,
    this.ehReserva = false,
    this.valorGuardado,
    this.proximoGanhoEsperado,
  });

  factory Pote.fromMap(String id, Map<String, dynamic> mapa) => Pote(
        id: id,
        nome: mapa['nome'] as String,
        // Firestore devolve int quando o valor gravado nao tem decimal.
        percentual: (mapa['percentual'] as num).toDouble(),
        ordem: (mapa['ordem'] as num).toInt(),
        cor: mapa['cor'] as String? ?? '#607D8B',
        icone: mapa['icone'] as String? ?? 'carteira',
        ehReserva: mapa['ehReserva'] as bool? ?? false,
        valorGuardado: (mapa['valorGuardado'] as num?)?.toDouble(),
        proximoGanhoEsperado:
            (mapa['proximoGanhoEsperado'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'percentual': percentual,
        'ordem': ordem,
        'cor': cor,
        'icone': icone,
        'ehReserva': ehReserva,
        if (valorGuardado != null) 'valorGuardado': valorGuardado,
        if (proximoGanhoEsperado != null)
          'proximoGanhoEsperado': proximoGanhoEsperado,
      };

  Pote copyWith({
    String? id,
    String? nome,
    double? percentual,
    int? ordem,
    String? cor,
    String? icone,
    bool? ehReserva,
    double? valorGuardado,
    double? proximoGanhoEsperado,
  }) =>
      Pote(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        percentual: percentual ?? this.percentual,
        ordem: ordem ?? this.ordem,
        cor: cor ?? this.cor,
        icone: icone ?? this.icone,
        ehReserva: ehReserva ?? this.ehReserva,
        valorGuardado: valorGuardado ?? this.valorGuardado,
        proximoGanhoEsperado:
            proximoGanhoEsperado ?? this.proximoGanhoEsperado,
      );
}
