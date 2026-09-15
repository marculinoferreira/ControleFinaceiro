/// Pessoa da casa. O id e um slug curto ("marcos") nas casas antigas, ou o
/// uid do Firebase Auth / um id gerado pela Cloud Function `convidarMembro`
/// nas casas novas — nao o e-mail: chave de mapa no Firestore com ponto
/// exige FieldPath para acesso.
class Membro {
  final String id;
  final String nome;
  final String email;
  final String cor;
  final int ordem;

  /// Presente so quando o dono removeu esta pessoa da casa (spec de
  /// 2026-09-14 §4.3): a UI usa isto para escondê-la das listagens sem
  /// apagar o registro, ate a janela de 30 dias expirar.
  final DateTime? removidoEm;

  const Membro({
    required this.id,
    required this.nome,
    required this.email,
    required this.cor,
    required this.ordem,
    this.removidoEm,
  });

  factory Membro.fromMap(String id, Map<String, dynamic> mapa) => Membro(
        id: id,
        nome: mapa['nome'] as String,
        email: mapa['email'] as String,
        cor: mapa['cor'] as String? ?? '#607D8B',
        ordem: (mapa['ordem'] as num?)?.toInt() ?? 0,
        removidoEm: _lerDataOpcional(mapa['removidoEm']),
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'email': email,
        'cor': cor,
        'ordem': ordem,
      };
}

/// Mesmo truque de `Gasto._lerData` (`lib/dominio/models/gasto.dart`): o
/// Firestore devolve um `Timestamp`, mas o dominio nao importa
/// `cloud_firestore` — entao le por duck-typing em vez do tipo.
DateTime? _lerDataOpcional(dynamic bruto) {
  if (bruto == null) return null;
  if (bruto is DateTime) return bruto;
  return (bruto as dynamic).toDate() as DateTime;
}
