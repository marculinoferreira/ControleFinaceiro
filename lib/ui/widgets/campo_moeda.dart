import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../dominio/cascata.dart' show toleranciaCentavo;
import '../tema/formatadores.dart';

/// Converte o texto digitado em valor. Os digitos sao lidos como centavos:
/// "1234" vira 12.34. Devolve null quando nao ha digito nenhum — o formulario
/// precisa distinguir "campo vazio" de "usuario digitou zero" — e tambem
/// quando ha digitos demais para caber em um int, em vez de estourar.
double? parsearMoeda(String texto) {
  final digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitos.isEmpty) return null;
  final centavos = int.tryParse(digitos);
  if (centavos == null) return null;
  return centavos / 100;
}

/// Reescreve o campo inteiro a cada tecla, em vez de aplicar uma mascara
/// posicional: mascara posicional quebra quando o usuario apaga do meio da
/// string, e aqui o texto e sempre derivado do valor.
class FormatadorMoeda extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antigo,
    TextEditingValue novo,
  ) {
    if (novo.text.isEmpty) return novo;

    final valor = parsearMoeda(novo.text);
    if (valor == null) return antigo; // tecla sem digito, ou estouro: recusa

    final texto = formatarReais(valor);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

class CampoMoeda extends StatelessWidget {
  final TextEditingController controlador;
  final String rotulo;
  final String? Function(String?)? validador;

  const CampoMoeda({
    super.key,
    required this.controlador,
    this.rotulo = 'Valor',
    this.validador,
  });

  static String? _padrao(String? texto) {
    final valor = parsearMoeda(texto ?? '');
    if (valor == null || valor <= toleranciaCentavo) {
      return 'Informe um valor maior que zero.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controlador,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FormatadorMoeda()],
        validator: validador ?? _padrao,
        decoration: InputDecoration(
          labelText: rotulo,
          border: const OutlineInputBorder(),
        ),
      );
}
