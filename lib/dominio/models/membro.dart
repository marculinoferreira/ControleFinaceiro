/// Pessoa da casa. O id e um slug curto ("marcos"), nao o e-mail:
/// chave de mapa no Firestore com ponto exige FieldPath para acesso.
class Membro {
  final String id;
  final String nome;
  final String email;
  final String cor;
  final int ordem;

  const Membro({
    required this.id,
    required this.nome,
    required this.email,
    required this.cor,
    required this.ordem,
  });

  factory Membro.fromMap(String id, Map<String, dynamic> mapa) => Membro(
        id: id,
        nome: mapa['nome'] as String,
        email: mapa['email'] as String,
        cor: mapa['cor'] as String? ?? '#607D8B',
        ordem: (mapa['ordem'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'email': email,
        'cor': cor,
        'ordem': ordem,
      };
}
