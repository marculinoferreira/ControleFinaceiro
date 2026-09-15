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

  /// Prefere um membro ATIVO com este e-mail; so cai para um removido se
  /// nao houver ativo. Evita que `membroLogadoProvider` resolva para um
  /// fantasma quando um convite reativa a entrada de alguem que ja foi
  /// removido e depois convidado de novo (o e-mail pode, por um instante,
  /// bater com as duas entradas antes da reativacao gravar).
  Membro? membroPorEmail(String email) {
    final alvo = email.trim().toLowerCase();
    Membro? removido;
    for (final m in membros) {
      if (m.email.toLowerCase() != alvo) continue;
      if (m.removidoEm == null) return m;
      removido ??= m;
    }
    return removido;
  }

  Membro? membroPorId(String id) {
    for (final m in membros) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Compara dois e-mails ignorando maiusculas/minusculas e espacos nas
  /// pontas — mesmo criterio usado em membroPorEmail.
  static bool emailsIguais(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
