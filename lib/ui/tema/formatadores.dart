import 'package:intl/intl.dart';

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
