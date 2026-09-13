import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'estados_async.dart';
import 'legenda_grafico.dart';

/// Moldura comum aos graficos da tela (os seis da spec 10 mais o de cartao).
///
/// Resolve os quatro estados num lugar so — carregando, erro, sem dado e
/// dado — para que nenhum grafico repita o AsyncValue.when nem invente o
/// proprio jeito de dizer "nao ha nada aqui".
///
/// O estado "sem dado" existe separado do "carregando" de proposito: um
/// PieChart sem secoes desenha um circulo em branco que parece defeito, e
/// um LineChart sem pontos desenha eixos vazios. A frase e mais honesta.
///
/// Cada moldura resolve o SEU AsyncValue. Um `when` no topo da tela de
/// graficos derrubaria os sete por causa de um; assim, um gráfico com
/// problema nao apaga os outros seis.
class MolduraGrafico<T> extends StatelessWidget {
  final String titulo;

  /// Ex.: "do casal" no grafico de ganhos, que ignora a visao selecionada.
  final String? subtitulo;

  /// Frase mostrada quando [estaVazio] devolve true.
  final String vazio;

  final double altura;
  final AsyncValue<T> dados;
  final bool Function(T) estaVazio;
  final List<ItemLegenda> Function(T) legenda;

  /// Widget opcional abaixo da legenda, ex.: um total resumindo a serie.
  /// `null` (o padrao) nao desenha nada.
  final Widget Function(T)? rodape;

  final Widget Function(T) construir;
  final VoidCallback aoRecarregar;

  const MolduraGrafico({
    super.key,
    required this.titulo,
    required this.vazio,
    required this.dados,
    required this.estaVazio,
    required this.legenda,
    required this.construir,
    required this.aoRecarregar,
    this.subtitulo,
    this.rodape,
    this.altura = 240,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titulo, style: tema.textTheme.titleMedium),
            if (subtitulo != null)
              Text(
                subtitulo!,
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.outline),
              ),
            const SizedBox(height: 12),
            // O erro fica FORA da altura fixa: ele tem icone, duas linhas de
            // texto e um botao, e nao cabe no slot de um grafico baixo como
            // a barra da cascata. Espremer a explicacao da falha e o pior
            // lugar para economizar pixel.
            if (dados.hasError)
              ErroComRecarregar(erro: dados.error!, aoRecarregar: aoRecarregar)
            else
              SizedBox(height: altura, child: _corpo(context)),
            ..._legendaERodape(),
          ],
        ),
      ),
    );
  }

  /// Sem o ramo de erro: ele e tratado antes, fora da altura fixa.
  Widget _corpo(BuildContext context) => dados.when(
        loading: () => const CarregandoLista(linhas: 3),
        error: (e, _) => const SizedBox.shrink(),
        data: (valor) => estaVazio(valor)
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    vazio,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            : construir(valor),
      );

  /// Legenda e rodape, quando os dois existem, ficam na MESMA linha --
  /// legenda a esquerda, rodape a direita -- em vez de empilhados, pra
  /// aproveitar a largura do card em vez de gastar duas linhas de altura.
  /// Sem dado (ou vazio), nenhum dos dois faz sentido: a legenda apontaria
  /// pra um grafico que nem esta na tela, e o rodape nao teria o que somar.
  List<Widget> _legendaERodape() {
    final valor = dados.value;
    if (valor == null || estaVazio(valor)) return const [];

    final itens = legenda(valor);
    final rodapeWidget = rodape?.call(valor);

    if (itens.isEmpty && rodapeWidget == null) return const [];

    if (itens.isNotEmpty && rodapeWidget != null) {
      return [
        const SizedBox(height: 12),
        // Wrap (nao Row/Expanded): se a legenda for longa e nao sobrar
        // espaco pro rodape na mesma linha, ele quebra pra linha de baixo em
        // vez de espremer a legenda ate estourar (Row com Expanded forcava
        // a legenda num espaco menor que o texto precisava).
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [LegendaGrafico(itens: itens), rodapeWidget],
          ),
        ),
      ];
    }

    if (itens.isNotEmpty) {
      return [const SizedBox(height: 12), LegendaGrafico(itens: itens)];
    }

    return [const SizedBox(height: 8), rodapeWidget!];
  }
}
