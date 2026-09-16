import 'package:flutter/services.dart';

/// Deixa a primeira letra do campo em maiuscula enquanto se digita.
///
/// So a primeira: "pneus dakar" vira "Pneus dakar", nao "Pneus Dakar".
/// Descricao de gasto e nome proprio sao coisas diferentes, e forcar
/// maiuscula em toda palavra estragaria "conta de luz".
///
/// Existe porque `TextCapitalization.sentences` so instrui o teclado
/// virtual: sem este formatter, digitar com um teclado fisico bluetooth
/// nao teria a primeira letra maiuscula automaticamente.
///
/// A selecao e o cursor sao preservados: trocar so o caractere zero nao pode
/// mandar o cursor para o fim do texto a cada tecla digitada.
class PrimeiraMaiuscula extends TextInputFormatter {
  const PrimeiraMaiuscula();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antes,
    TextEditingValue depois,
  ) {
    final texto = depois.text;
    if (texto.isEmpty) return depois;

    final inicial = texto[0];
    final maiuscula = inicial.toUpperCase();

    // Digito, espaco ou letra que ja esta maiuscula: nada a fazer, e devolver
    // o mesmo valor evita uma reconstrucao inutil do campo.
    if (inicial == maiuscula) return depois;

    return TextEditingValue(
      text: maiuscula + texto.substring(1),
      selection: depois.selection,
      composing: depois.composing,
    );
  }
}
