import 'membro.dart';

/// Espaco financeiro compartilhado por um grupo de pessoas.
class Casa {
  final String id;
  final String nome;
  final String donoEmail;
  final List<Membro> membros; // sempre ordenados por Membro.ordem

  const Casa({
    required this.id,
    required this.nome,
    // Default vazio, e nao obrigatorio: 18 arquivos de teste ja existentes
    // constroem `Casa(...)` sem se importar com quem e o dono (testam
    // gastos, potes, graficos — nada relacionado a posse da casa). Exigir
    // o campo ali so adicionaria ruido sem valor de teste.
    this.donoEmail = '',
    required this.membros,
  });

  factory Casa.fromMap(String id, Map<String, dynamic> mapa) {
    final bruto = (mapa['membros'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final membros = bruto.entries
        .map((e) => Membro.fromMap(e.key, e.value as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
    return Casa(
      id: id,
      nome: mapa['nome'] as String? ?? 'Casa',
      donoEmail: mapa['donoEmail'] as String? ?? '',
      membros: membros,
    );
  }

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'donoEmail': donoEmail,
        'membros': {for (final m in membros) m.id: m.toMap()},
      };

  Membro? membroPorEmail(String email) {
    final alvo = email.trim().toLowerCase();
    for (final m in membros) {
      if (m.email.toLowerCase() == alvo) return m;
    }
    return null;
  }

  Membro? membroPorId(String id) {
    for (final m in membros) {
      if (m.id == id) return m;
    }
    return null;
  }
}
