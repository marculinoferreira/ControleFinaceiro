import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dominio/cascata.dart';
import '../../../dominio/graficos.dart';
import '../../../estado/providers.dart';
import '../../tema/formatadores.dart';
import '../../tema/tema.dart';
import '../legenda_grafico.dart';
import '../moldura_grafico.dart';

/// Grafico 5 da spec 10: a barra da cascata.
///
/// Nao usa fl_chart. E uma regua: os potes na ordem de prioridade, cada um
/// ocupando a largura do seu previsto, e um marcador onde o gasto parou.
/// Forcar um grafico de barras empilhadas a fingir de regua daria mais
/// codigo e menos fidelidade ao desenho da spec.
class BarraCascata extends ConsumerWidget {
  const BarraCascata({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSelecionadoProvider).valor;

    return MolduraGrafico<ResultadoCascata>(
      titulo: 'Onde o gasto parou',
      vazio: 'Lance seus ganhos para ver a cascata.',
      altura: 150,
      dados: ref.watch(resumoCascataProvider),
      // Sem renda todo previsto e zero: os pesos zerariam e a barra sairia
      // como uma linha vazia. A frase diz mais.
      estaVazio: (r) => r.semRenda || r.linhas.isEmpty,
      aoRecarregar: () {
        ref.invalidate(potesProvider);
        ref.invalidate(gastosDoMesProvider(mes));
      },
      legenda: (r) => [
        for (final linha in r.linhas)
          ItemLegenda(rotulo: linha.pote.nome, cor: corDeHex(linha.pote.cor)),
      ],
      construir: (r) => _Regua(resumo: r),
    );
  }
}

class _Regua extends StatelessWidget {
  final ResultadoCascata resumo;
  const _Regua({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final pesos = pesosDaCascata(resumo);
    final posicao = posicaoDoGasto(resumo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, restricoes) {
              final largura = restricoes.maxWidth;

              return Stack(
                children: [
                  // Os potes, lado a lado, cada um do tamanho do seu previsto.
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          for (final (i, linha) in resumo.linhas.indexed)
                            if (pesos[i] > 0)
                              Expanded(
                                flex: pesos[i],
                                child: Container(
                                  color: corDeHex(linha.pote.cor)
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),

                  // A agua: o quanto ja escorreu, da esquerda ate o marcador.
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: largura * posicao,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          for (final (i, linha) in resumo.linhas.indexed)
                            if (pesos[i] > 0)
                              Expanded(
                                flex: pesos[i],
                                child: Container(
                                  color: corDeHex(linha.pote.cor),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),

                  // O marcador de onde parou.
                  Positioned(
                    left: (largura * posicao).clamp(0.0, largura - 3),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      key: const Key('cascata_marcador'),
                      width: 3,
                      color: resumo.estourouTudo
                          ? esquema.error
                          : esquema.onSurface,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          resumo.estourouTudo
              ? 'Passou ${formatarReais(resumo.excedente)} de tudo que entrou.'
              : 'Parou em ${resumo.poteAtivo?.nome ?? ''}.',
          key: const Key('cascata_texto'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: resumo.estourouTudo ? esquema.error : null,
              ),
        ),
      ],
    );
  }
}
