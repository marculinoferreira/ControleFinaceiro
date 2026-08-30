import 'package:intl/intl.dart';

import '../../dominio/models/membro.dart';
import '../../dominio/models/mes_ref.dart';
import '../../dominio/models/pote.dart';

/// NumberFormat nao exige initializeDateFormatting: os dados de formatacao
/// numerica ja vem compilados no intl. Isso vale so para DateFormat.
final NumberFormat _reais =
    NumberFormat.currency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 2);

/// "R$ 1.234,56"
String formatarReais(double valor) => _reais.format(valor);

/// "55%" ou "12,5%"
String formatarPercentual(double valor) {
  final texto = valor == valor.roundToDouble()
      ? valor.toStringAsFixed(0)
      : valor.toStringAsFixed(1).replaceAll('.', ',');
  return '$texto%';
}

/// Preview do parcelamento, mostrado antes de salvar (spec 8):
/// "10x de R$ 100,00 = R$ 1.000,00 · Ago/26 → Mai/27".
///
/// Com [quantidade] igual a 1 devolve so valor e mes: uma compra "em 1x"
/// nao e um parcelamento, e escrever "1x ... Ago/26 -> Ago/26" confundiria.
String resumoParcelamento({
  required double valorParcela,
  required int quantidade,
  required MesRef inicio,
}) {
  if (quantidade <= 1) {
    return '${formatarReais(valorParcela)} · ${inicio.formatarCurto()}';
  }

  final fim = inicio.avancar(quantidade - 1);
  return '${quantidade}x de ${formatarReais(valorParcela)} '
      '= ${formatarReais(valorParcela * quantidade)} '
      '· ${inicio.formatarCurto()} → ${fim.formatarCurto()}';
}

/// Nome exibivel de um membro. Devolve o proprio id quando nao encontra:
/// um lancamento cujo membro foi apagado ainda precisa aparecer na lista, e
/// mostrar o id e melhor do que sumir com a linha ou exibir vazio.
String nomeDoMembro(List<Membro> membros, String id) {
  for (final m in membros) {
    if (m.id == id) return m.nome;
  }
  return id;
}

/// Idem para potes. Mesma razao: gasto de pote apagado nao pode desaparecer.
String nomeDoPote(List<Pote> potes, String id) {
  for (final p in potes) {
    if (p.id == id) return p.nome;
  }
  return id;
}
