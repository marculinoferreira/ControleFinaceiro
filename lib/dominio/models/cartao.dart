/// Cartao, conta ou carteira usada para pagar um gasto.
///
/// Nao carrega limite, fatura nem vencimento: aqui ele serve so para dizer
/// "por onde esse dinheiro saiu". Controle de fatura e outro assunto, e a
/// spec 15 o deixou fora de escopo.
class Cartao {
  final String id;
  final String nome;

  /// Define a ordem de exibicao na lista e no seletor do formulario.
  final int ordem;

  const Cartao({
    required this.id,
    required this.nome,
    required this.ordem,
  });

  factory Cartao.fromMap(String id, Map<String, dynamic> mapa) => Cartao(
        id: id,
        nome: mapa['nome'] as String,
        ordem: (mapa['ordem'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'ordem': ordem,
      };

  Cartao copyWith({String? id, String? nome, int? ordem}) => Cartao(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        ordem: ordem ?? this.ordem,
      );
}
