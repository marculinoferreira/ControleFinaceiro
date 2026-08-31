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
/// Nao calcula nada. `resumoCascataProvider` ja entrega as linhas, o pote
/// ativo, o excedente e ate o texto do rotulo; esta tela so pinta.
class TelaResumo extends ConsumerWidget {
  const TelaResumo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membros = ref.watch(membrosProvider);

    return ref.watch(resumoCascataProvider).when(
          loading: () => const CarregandoLista(),
          error: (e, _) => ErroComRecarregar(
            erro: e,
            aoRecarregar: () {
              ref.invalidate(potesProvider);
              ref.invalidate(
                  gastosDoMesProvider(ref.read(mesSelecionadoProvider).valor));
            },
          ),
          data: (resumo) => Column(
            children: [
              _SeletorVisao(membros: membros),
              _Rotulo(resumo: resumo),
              const Divider(height: 1),
              Expanded(child: _tabela(resumo)),
            ],
          ),
        );
  }

  Widget _tabela(ResultadoCascata resumo) {
    return TabelaResponsiva(
      colunas: const ['Pote', '%', 'Previsto', 'Consumido', 'Sobra'],
      vazio: 'Cadastre seus potes na Lei dos Potes.',
      linhas: [
        for (final linha in resumo.linhas)
          LinhaResponsiva(
            chave: ValueKey('resumo_${linha.pote.id}'),
            valores: [
              linha.pote.nome,
              formatarPercentual(linha.pote.percentual),
              formatarReais(linha.previsto),
              formatarReais(linha.consumido),
              formatarReais(linha.sobra),
            ],
            indicador: _BarraDoPote(linha: linha),
          ),
      ],
    );
  }
}

/// Barra de consumo de um pote, na cor dele.
class _BarraDoPote extends StatelessWidget {
  final LinhaCascata linha;
  const _BarraDoPote({required this.linha});

  @override
  Widget build(BuildContext context) {
    // Um pote de 0%, ou qualquer pote num mes sem renda, tem previsto zero.
    // Dividir aqui daria NaN e o LinearProgressIndicator lancaria assert.
    final proporcao = linha.previsto <= toleranciaCentavo
        ? 0.0
        : (linha.consumido / linha.previsto).clamp(0.0, 1.0);

    return LinearProgressIndicator(
      value: proporcao,
      color: corDeHex(linha.pote.cor),
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
