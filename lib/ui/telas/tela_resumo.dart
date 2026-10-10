import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/cascata.dart';
import '../../dominio/models/membro.dart';
import '../../estado/providers.dart';
import '../shell.dart' show breakpointDesktop;
import '../tema/formatadores.dart';
import '../tema/tema.dart';
import '../widgets/estados_async.dart';
import '../widgets/graficos/barra_cascata.dart';
import '../widgets/graficos/barras_cartao_comparativo.dart';
import '../widgets/graficos/barras_pote_comparativo.dart';
import '../widgets/graficos/barras_previsto_gasto.dart';
import '../widgets/graficos/linha_comprometimento.dart';
import '../widgets/graficos/linha_comprometimento_comparativo.dart';
import '../widgets/graficos/linha_evolucao.dart';
import '../widgets/graficos/linha_projecao.dart';
import '../widgets/graficos/pizza_ganhos.dart';
import '../widgets/graficos/rosca_por_cartao.dart';
import '../widgets/graficos/rosca_por_pote.dart';
import '../widgets/graficos/tendencia_pote.dart';
import '../widgets/tabela_responsiva.dart';

/// Resumo: a cascata dos Potes (spec 8) e os graficos que antes viviam numa
/// tela propria (spec 10), agora juntos sob os mesmos dois seletores --
/// Marcos/Silvia/Casal (`_SeletorVisao`) e Visao Geral/Comparativo/Projecao
/// (`_SeletorTipoVisao`).
///
/// Visao Geral mostra a cascata E os graficos de sempre, um debaixo do
/// outro -- as duas informacoes "juntas" de verdade. Comparativo e
/// Projecao SUBSTITUEM o conteudo pelos proprios graficos, sem a cascata:
/// nao ha "a cascata de quem" quando o grafico ja compara as duas pessoas
/// lado a lado, nem quando ele projeta o futuro independente de quem esta
/// selecionado.
class TelaResumo extends ConsumerWidget {
  const TelaResumo({super.key});

  /// Os seis primeiros na ordem da spec 10; o setimo (cartao) vem depois.
  static const _graficosGeral = <Widget>[
    RoscaPorPote(),
    BarrasPrevistoGasto(),
    LinhaEvolucao(),
    PizzaGanhos(),
    BarraCascata(),
    LinhaComprometimento(),
    RoscaPorCartao(),
    TendenciaPote(),
  ];

  static const _graficosComparativo = <Widget>[
    BarrasPoteComparativo(),
    BarrasCartaoComparativo(),
    LinhaComprometimentoComparativo(),
  ];

  static const _graficosProjecao = <Widget>[LinhaProjecao()];

  List<Widget> _graficosDoTipo(TipoVisaoGraficos tipo) => switch (tipo) {
        TipoVisaoGraficos.geral => _graficosGeral,
        TipoVisaoGraficos.comparativo => _graficosComparativo,
        TipoVisaoGraficos.projecao => _graficosProjecao,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = MediaQuery.sizeOf(context).width >= breakpointDesktop;
    final membros = ref.watch(membrosParaVisaoProvider);
    final tipo = ref.watch(tipoVisaoGraficosProvider);
    final graficos = _graficosDoTipo(tipo);

    return Column(
      children: [
        if (tipo != TipoVisaoGraficos.comparativo) _SeletorVisao(membros: membros),
        const _SeletorTipoVisao(),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('resumo_rolagem'),
            child: Column(
              children: [
                if (tipo == TipoVisaoGraficos.geral) const _ResumoCascata(),
                desktop && graficos.length > 1
                    ? _duasColunas(graficos)
                    : _colunaUnica(graficos),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// No desktop os graficos ficam pequenos demais ocupando a largura toda;
  /// duas colunas aproveitam o espaco e encurtam a rolagem.
  Widget _duasColunas(List<Widget> graficos) {
    final esquerda = <Widget>[];
    final direita = <Widget>[];
    for (final (i, g) in graficos.indexed) {
      (i.isEven ? esquerda : direita).add(g);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            key: const Key('graficos_coluna_esquerda'),
            children: esquerda,
          ),
        ),
        Expanded(
          child: Column(
            key: const Key('graficos_coluna_direita'),
            children: direita,
          ),
        ),
      ],
    );
  }

  Widget _colunaUnica(List<Widget> graficos) => Column(
        key: const Key('graficos_coluna_unica'),
        children: graficos,
      );
}

/// A cascata da Fase 2 (spec 8): o previsto de cada pote, o pote ativo, o
/// excedente e o texto do rotulo vem de `resumoCascataProvider`. O
/// consumido da tabela, porem, vem de `gastosPorPoteProvider` -- o gasto
/// real classificado naquele pote, sem o teto do previsto -- para a
/// tabela responder "quanto gastei em Lazer" e nao "quanto da cascata
/// sobrou pra Lazer depois dos potes anteriores absorverem".
class _ResumoCascata extends ConsumerWidget {
  const _ResumoCascata();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = combinarAsyncValues(
      ref.watch(resumoCascataProvider),
      ref.watch(gastosPorPoteProvider),
      (resumo, porPote) => (resumo, porPote),
    );

    return dados.when(
      loading: () => const CarregandoLista(dentroDeOutraRolagem: true),
      error: (e, _) => ErroComRecarregar(
        erro: e,
        aoRecarregar: () {
          ref.invalidate(potesProvider);
          ref.invalidate(
              gastosDoMesProvider(ref.read(mesSelecionadoProvider).valor));
        },
      ),
      data: (par) => Column(
        children: [
          _Rotulo(resumo: par.$1),
          const Divider(height: 1),
          _tabela(par.$1, par.$2),
        ],
      ),
    );
  }

  Widget _tabela(ResultadoCascata resumo, Map<String, double> porPote) {
    return TabelaResponsiva(
      key: const Key('resumo_tabela'),
      colunas: const [
        'Pote',
        '%',
        'Previsto',
        'Consumido',
        'Ultrapassou',
        'Sobra',
      ],
      vazio: 'Cadastre seus potes na Lei dos Potes.',
      // Agora vive dentro do SingleChildScrollView da Visao Geral (junto
      // com os graficos), nao mais sozinha num Expanded proprio.
      dentroDeOutraRolagem: true,
      linhas: [
        for (final linha in resumo.linhas) _linha(linha, porPote),
      ],
    );
  }

  LinhaResponsiva _linha(LinhaCascata linha, Map<String, double> porPote) {
    final consumido = porPote[linha.pote.id] ?? 0;
    final ultrapassou = math.max(0.0, consumido - linha.previsto);
    final sobra = math.max(0.0, linha.previsto - consumido);

    return LinhaResponsiva(
      chave: ValueKey('resumo_${linha.pote.id}'),
      valores: [
        linha.pote.nome,
        formatarPercentual(linha.pote.percentual),
        formatarReais(linha.previsto),
        formatarReais(consumido),
        formatarReais(ultrapassou),
        formatarReais(sobra),
      ],
      indicador: _IndicadorDoPote(
        previsto: linha.previsto,
        consumido: consumido,
        cor: linha.pote.cor,
        poteId: linha.pote.id,
      ),
    );
  }
}

/// Barra de consumo do pote mais o alerta de estouro projetado quando
/// existir. `ConsumerWidget` proprio porque `_linha` continua um metodo
/// puro (sem `WidgetRef`) -- so este widget composto precisa ler o
/// provider.
class _IndicadorDoPote extends ConsumerWidget {
  final double previsto;
  final double consumido;
  final String cor;
  final String poteId;

  const _IndicadorDoPote({
    required this.previsto,
    required this.consumido,
    required this.cor,
    required this.poteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excesso = ref.watch(estouroProjetadoProvider).value?[poteId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BarraDoPote(previsto: previsto, consumido: consumido, cor: cor),
        if (excesso != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'No ritmo atual, vai passar ${formatarReais(excesso)} do previsto',
              key: Key('estouro_$poteId'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// Barra de consumo de um pote, na cor dele.
class _BarraDoPote extends StatelessWidget {
  final double previsto;
  final double consumido;
  final String cor;
  const _BarraDoPote({
    required this.previsto,
    required this.consumido,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    // Um pote de 0%, ou qualquer pote num mes sem renda, tem previsto zero.
    // Dividir aqui daria NaN e o LinearProgressIndicator lancaria assert.
    final proporcao = previsto <= toleranciaCentavo
        ? 0.0
        : (consumido / previsto).clamp(0.0, 1.0);

    return LinearProgressIndicator(
      value: proporcao,
      color: corDeHex(cor),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

/// Marcos / Silvia / Casal. Escreve em `visaoProvider`, que ja e lido por
/// totaisDoMesProvider e resumoCascataProvider. Some quando a visao
/// Comparativo esta ativa (as duas pessoas ja aparecem lado a lado nos
/// graficos daquela visao -- escolher uma so nao faria sentido ali).
class _SeletorVisao extends ConsumerWidget {
  final List<Membro> membros;
  const _SeletorVisao({required this.membros});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Com um so integrante ativo na casa, "Marcos" e "Casal" seriam a mesma
    // coisa -- o seletor todo some, nao so um dos dois.
    if (membros.where((m) => m.removidoEm == null).length <= 1) {
      return const SizedBox.shrink();
    }

    final visao = ref.watch(visaoProvider);

    // Coage para null quando a visao aponta para um membro que sumiu (a
    // outra pessoa o removeu com esta aba aberta): sem isso o SegmentedButton
    // derruba o assert de selecao fora do conjunto de segmentos.
    final valida =
        visao == null || membros.any((m) => m.id == visao) ? visao : null;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SegmentedButton<String?>(
        key: const Key('resumo_visao'),
        showSelectedIcon: false,
        segments: [
          for (final m in membros)
            ButtonSegment(value: m.id, label: Text(m.nome)),
          const ButtonSegment(value: null, label: Text('Casal')),
        ],
        selected: {valida},
        onSelectionChanged: (s) =>
            ref.read(visaoProvider.notifier).selecionar(s.first),
      ),
    );
  }
}

/// As 3 abas: Visao Geral / Comparativo / Projecao. "Comparativo" so entra
/// na lista quando a casa tem os dois integrantes ativos -- ver
/// `duplaComparativaProvider`. Se a dupla encolher com a aba Comparativo
/// ja selecionada (alguem saiu da casa com a tela aberta), volta sozinho
/// pra Visao Geral.
class _SeletorTipoVisao extends ConsumerWidget {
  const _SeletorTipoVisao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipo = ref.watch(tipoVisaoGraficosProvider);
    final temDupla = ref.watch(duplaComparativaProvider).length == 2;

    if (tipo == TipoVisaoGraficos.comparativo && !temDupla) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(tipoVisaoGraficosProvider.notifier).selecionar(TipoVisaoGraficos.geral);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SegmentedButton<TipoVisaoGraficos>(
        key: const Key('graficos_tipo_visao'),
        showSelectedIcon: false,
        segments: [
          const ButtonSegment(
            value: TipoVisaoGraficos.geral,
            label: _RotuloSegmento('Visão Geral'),
            icon: Icon(Icons.donut_large),
          ),
          if (temDupla)
            const ButtonSegment(
              value: TipoVisaoGraficos.comparativo,
              label: _RotuloSegmento('Comparativo'),
              icon: Icon(Icons.bar_chart),
            ),
          const ButtonSegment(
            value: TipoVisaoGraficos.projecao,
            label: _RotuloSegmento('Projeção'),
            icon: Icon(Icons.trending_up),
          ),
        ],
        selected: {
          tipo == TipoVisaoGraficos.comparativo && !temDupla
              ? TipoVisaoGraficos.geral
              : tipo,
        },
        onSelectionChanged: (s) =>
            ref.read(tipoVisaoGraficosProvider.notifier).selecionar(s.first),
      ),
    );
  }
}

/// Rotulo de segmento que encolhe a fonte pra caber na largura do botao em
/// vez de quebrar linha -- num segmento estreito (3 abas dividindo a tela
/// de um telefone), o texto quebrado deixa os botoes mais altos e
/// desalinhados; encolhido, continua legivel numa linha so.
class _RotuloSegmento extends StatelessWidget {
  final String texto;
  const _RotuloSegmento(this.texto);

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(texto, maxLines: 1, softWrap: false),
    );
  }
}

/// O rotulo grande em cor semaforica, e o excedente quando estourou.
class _Rotulo extends StatelessWidget {
  final ResultadoCascata resumo;
  const _Rotulo({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    // Precedencia identica a de ResultadoCascata.rotulo, para o texto e a
    // cor nunca discordarem.
    final cor = resumo.semRenda
        ? esquema.outline
        : resumo.poteAtivo != null
            ? corDeHex(resumo.poteAtivo!.cor)
            : esquema.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Text(
            resumo.rotulo,
            key: const Key('resumo_rotulo'),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: cor, fontWeight: FontWeight.bold),
          ),
          if (resumo.estourouTudo && !resumo.semRenda) ...[
            const SizedBox(height: 4),
            Text(
              'Você passou ${formatarReais(resumo.excedente)} do que entrou.',
              key: const Key('resumo_excedente'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: esquema.error),
            ),
          ],
        ],
      ),
    );
  }
}
