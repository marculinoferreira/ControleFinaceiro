import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/cascata.dart';
import '../../dominio/models/membro.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';
import '../tema/tema.dart';
import '../widgets/estados_async.dart';
import '../widgets/tabela_responsiva.dart';

/// Resumo dos Potes (spec 8): a cascata da Fase 2 finalmente visivel.
///
/// A cascata (`resumoCascataProvider`) entrega o previsto de cada pote, o
/// pote ativo, o excedente e o texto do rotulo. O consumido da tabela, porem,
/// vem de `gastosPorPoteProvider` -- o gasto real classificado naquele pote,
/// sem o teto do previsto -- para a tabela responder "quanto gastei em
/// Lazer" e nao "quanto da cascata sobrou pra Lazer depois dos potes
/// anteriores absorverem".
class TelaResumo extends ConsumerWidget {
  const TelaResumo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membros = ref.watch(membrosParaVisaoProvider);
    final dados = combinarAsyncValues(
      ref.watch(resumoCascataProvider),
      ref.watch(gastosPorPoteProvider),
      (resumo, porPote) => (resumo, porPote),
    );

    return dados.when(
      loading: () => const CarregandoLista(),
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
          _SeletorVisao(membros: membros),
          _Rotulo(resumo: par.$1),
          const Divider(height: 1),
          Expanded(child: _tabela(par.$1, par.$2)),
        ],
      ),
    );
  }

  Widget _tabela(ResultadoCascata resumo, Map<String, double> porPote) {
    return TabelaResponsiva(
      colunas: const [
        'Pote',
        '%',
        'Previsto',
        'Consumido',
        'Ultrapassou',
        'Sobra',
      ],
      vazio: 'Cadastre seus potes na Lei dos Potes.',
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
/// totaisDoMesProvider e resumoCascataProvider.
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
