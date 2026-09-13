import 'package:flutter/material.dart';

const Color _semente = Color(0xFF2E7D32);

/// Cor de destaque pedida pelo usuario para estados selecionados/ativos:
/// pilula do "Ordenar por", indicador do item selecionado no menu (Resumo a
/// Graficos). Fixa (nao derivada do ColorScheme) porque o pedido foi por um
/// hex exato, nao por "algo na linha do verde do tema".
const Color corDestaque = Color(0xFF26797B);

ThemeData temaClaro() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _semente),
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

ThemeData temaEscuro() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
          seedColor: _semente, brightness: Brightness.dark),
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

/// Converte "#RRGGBB" (formato gravado em Pote.cor e Membro.cor) em Color.
Color corDeHex(String hex) {
  final limpo = hex.replaceFirst('#', '');
  final valor = int.tryParse(limpo, radix: 16);
  if (valor == null || limpo.length != 6) return const Color(0xFF607D8B);
  return Color(0xFF000000 | valor);
}
