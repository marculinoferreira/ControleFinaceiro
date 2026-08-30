/// Referencia de mes/ano no formato "YYYY-MM".
///
/// Concentra toda a aritmetica de meses do app. A virada de ano acontece
/// aqui e em nenhum outro lugar.
class MesRef implements Comparable<MesRef> {
  final int ano;
  final int mes; // 1..12

  const MesRef(this.ano, this.mes);

  static final RegExp _formato = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

  static const List<String> _nomes = [
    'Janeiro', 'Fevereiro', 'Marco', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  factory MesRef.parse(String valor) {
    if (!_formato.hasMatch(valor)) {
      throw FormatException('mesRef invalido, esperado "YYYY-MM"', valor);
    }
    return MesRef(
      int.parse(valor.substring(0, 4)),
      int.parse(valor.substring(5, 7)),
    );
  }

  factory MesRef.deDateTime(DateTime data) => MesRef(data.year, data.month);

  factory MesRef.atual() => MesRef.deDateTime(DateTime.now());

  String get valor => '$ano-${mes.toString().padLeft(2, '0')}';

  /// Avanca [meses] meses. Aceita valores negativos.
  MesRef avancar(int meses) {
    final total = ano * 12 + (mes - 1) + meses;
    return MesRef(total ~/ 12, total % 12 + 1);
  }

  /// Quantos meses este ref esta a frente de [outro]. Negativo se atras.
  int diferencaEm(MesRef outro) =>
      (ano * 12 + mes) - (outro.ano * 12 + outro.mes);

  /// "Agosto/2026"
  String formatarExtenso() => '${_nomes[mes - 1]}/$ano';

  /// "Ago/26"
  String formatarCurto() =>
      '${_nomes[mes - 1].substring(0, 3)}/${ano.toString().substring(2)}';

  @override
  int compareTo(MesRef outro) => diferencaEm(outro);

  @override
  bool operator ==(Object outro) =>
      outro is MesRef && outro.ano == ano && outro.mes == mes;

  @override
  int get hashCode => Object.hash(ano, mes);

  @override
  String toString() => valor;
}
