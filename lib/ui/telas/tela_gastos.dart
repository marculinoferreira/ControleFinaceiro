import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/cartao.dart';
import '../../dominio/models/gasto.dart';
import '../../dominio/models/membro.dart';
import '../../dominio/models/pote.dart';
import '../../dominio/ordem_gastos.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';
import '../tema/tema.dart';
import '../widgets/dialogo_exclusao.dart';
import '../widgets/faixa_potes.dart' show FaixaPotes, iconeDoPote;
import '../widgets/filtros_lancamentos.dart';
import '../widgets/estados_async.dart';
import '../widgets/subtitulo_lancamento.dart';
import '../widgets/tabela_responsiva.dart';
import 'formulario_gasto.dart';

class TelaGastos extends ConsumerWidget {
  const TelaGastos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FiltrosLancamentos e a coluna "Pessoa" das linhas usam todo mundo
    // (um removido ainda pode ser filtrado/rotulado nos gastos antigos
    // dele); so o gatilho de "novo gasto" via FaixaPotes exige gente ativa.
    final membros = ref.watch(membrosProvider);
    final membrosAtivos = ref.watch(membrosAtivosProvider);
    final mesRef = ref.watch(mesSelecionadoProvider).valor;

    // Potes entra na combinacao (em vez de `.value ?? []`) porque a regra
    // global e "toda leitura assincrona passa pelo AsyncValue.when com os
    // tres ramos, sem excecao": um erro em potesProvider nao pode renderizar
    // ids crus silenciosamente, e o loading dele nao pode ser mascarado de
    // "zero potes cadastrados".
    final combinado = combinarAsyncValues(
      combinarAsyncValues(
        ref.watch(potesProvider),
        ref.watch(cartoesProvider),
        (potes, cartoes) => (potes, cartoes),
      ),
      ref.watch(gastosAgrupadosProvider),
      (par, grupos) => (par.$1, par.$2, grupos),
    );

    return Scaffold(
      body: combinado.when(
        loading: () => const CarregandoLista(),
        error: (e, _) => ErroComRecarregar(
          erro: e,
          aoRecarregar: () {
            ref.invalidate(potesProvider);
            ref.invalidate(cartoesProvider);
            ref.invalidate(gastosDoMesProvider(mesRef));
          },
        ),
        data: (trio) {
          final (potes, cartoes, grupos) = trio;
          return Column(
            children: [
              FaixaPotes(
                potes: potes,
                habilitado: membrosAtivos.isNotEmpty,
                aoTocar: (pote) => abrirFormularioGasto(
                  context: context,
                  ref: ref,
                  poteIdInicial: pote.id,
                ),
              ),
              FiltrosLancamentos(membros: membros, potes: potes, cartoes: cartoes),
              const SeletorOrdem(),
              const Divider(height: 1),
              Expanded(
                child:
                    _tabela(context, ref, grupos, membros, potes, cartoes),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabela(
    BuildContext context,
    WidgetRef ref,
    List<GrupoGastos> grupos,
    List<Membro> membros,
    List<Pote> potes,
    List<Cartao> cartoes,
  ) {
    return TabelaResponsiva.agrupada(
      colunas: const [
        'Descrição',
        'Data',
        'Pessoa',
        'Pote',
        'Cartão',
        'Parcela',
        'Valor',
      ],
      vazio: 'Nenhum gasto neste mês.',
      colunaDoTotal: 6,
      somatoriaGeral: grupos
          .expand((g) => g.itens)
          .fold<double>(0.0, (soma, g) => soma + g.valor),
      grupos: [
        for (final grupo in grupos)
          GrupoResponsivo(
            titulo: grupo.titulo,
            linhas: [
              for (final g in grupo.itens)
                _linhaDoGasto(context, ref, g, membros, potes, cartoes),
            ],
            total: grupo.titulo.isEmpty
                ? null
                : grupo.itens.fold<double>(0.0, (soma, g) => soma + g.valor),
          ),
      ],
    );
  }

  LinhaResponsiva _linhaDoGasto(
    BuildContext context,
    WidgetRef ref,
    Gasto g,
    List<Membro> membros,
    List<Pote> potes,
    List<Cartao> cartoes,
  ) {
    // null quando o pote foi apagado enquanto o gasto continua existindo --
    // nesse caso o icone/cor ficam de fora (leading nulo), em vez de
    // inventar um icone generico pra um pote que nao existe mais.
    Pote? pote;
    for (final p in potes) {
      if (p.id == g.poteId) {
        pote = p;
        break;
      }
    }

    return LinhaResponsiva(
      chave: ValueKey('gasto_${g.id}'),
      valores: [
        g.descricao,
        formatarData(g.data),
        nomeDoMembro(membros, g.membroId),
        nomeDoPote(potes, g.poteId),
        nomeDoCartao(cartoes, g.cartaoId),
        g.rotuloParcela,
        formatarReais(g.valor),
      ],
      iconePrincipal: pote == null ? null : iconeDoPote(pote.icone),
      corIconePrincipal: pote == null ? null : corDeHex(pote.cor),
      subtitulo: subtituloDoLancamento(
        context: context,
        nomeMembro: nomeDoMembro(membros, g.membroId),
        nomePote: nomeDoPote(potes, g.poteId),
        nomeCartao: nomeDoCartao(cartoes, g.cartaoId),
        rotuloParcela: g.rotuloParcela,
      ),
      valorDestacado: formatarReais(g.valor),
      aoTocar: () => abrirFormularioGasto(context: context, ref: ref, existente: g),
      aoExcluir: () => _excluir(context, ref, g),
    );
  }

  /// Gasto simples pede um sim/nao; parcelado ja pergunta o modo, que faz o
  /// papel da confirmacao — encadear os dois dialogos so atrapalharia.
  Future<void> _excluir(
      BuildContext context, WidgetRef ref, Gasto gasto) async {
    final repo = ref.read(repositorioGastosProvider);

    try {
      if (!gasto.parcelado) {
        final confirmou = await confirmarExclusao(
          context: context,
          titulo: 'Excluir gasto',
          mensagem: 'Deseja excluir "${gasto.descricao}"?',
        );
        if (!confirmou) return;
        await repo.removerUma(gasto.id);
        return;
      }

      final modo =
          await perguntarModoExclusao(context: context, gasto: gasto);
      if (modo == null) return;
      await aplicarExclusao(repo: repo, gasto: gasto, modo: modo);
    } catch (e) {
      if (!context.mounted) return;
      avisarErroDeEscrita(context, e);
    }
  }
}
