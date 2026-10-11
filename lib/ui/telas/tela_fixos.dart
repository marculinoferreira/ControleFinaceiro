import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/fixo.dart';
import '../../dominio/models/membro.dart';
import '../../dominio/models/pote.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';
import '../widgets/botao_novo.dart';
import '../widgets/campo_moeda.dart';
import '../widgets/dialogo_exclusao.dart';
import '../widgets/estados_async.dart';
import '../widgets/formulario_responsivo.dart';
import '../widgets/primeira_maiuscula.dart';

class TelaFixos extends ConsumerWidget {
  const TelaFixos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membrosAtivos = ref.watch(membrosAtivosProvider);
    final membros = ref.watch(membrosParaVisaoProvider);
    final potes = ref.watch(potesProvider);
    final fixos = ref.watch(fixosProvider);

    final combinado = combinarAsyncValues(
      potes,
      fixos,
      (listaPotes, listaFixos) => (listaPotes, listaFixos),
    );

    return Scaffold(
      body: Column(
        children: [
          BotaoNovo(
            key: const Key('novo_fixo'),
            rotulo: 'Novo fixo',
            aoTocar: membrosAtivos.isEmpty
                ? null
                : () => _perguntarTipo(context, ref,
                    membros: membrosAtivos, potes: potes.value ?? const []),
          ),
          Expanded(
            child: combinado.when(
              loading: () => const CarregandoLista(),
              error: (e, _) => ErroComRecarregar(
                erro: e,
                aoRecarregar: () {
                  ref.invalidate(potesProvider);
                  ref.invalidate(fixosProvider);
                },
              ),
              data: (par) {
                final (listaPotes, listaFixos) = par;
                if (listaFixos.isEmpty) {
                  return const Center(child: Text('Nenhum fixo cadastrado.'));
                }
                return ListView.builder(
                  itemCount: listaFixos.length,
                  itemBuilder: (context, i) {
                    final fixo = listaFixos[i];
                    final ehGanho = fixo.tipo == TipoFixo.ganho;
                    return ListTile(
                      key: Key('fixo_${fixo.id}'),
                      leading: Icon(
                          ehGanho ? Icons.trending_up : Icons.receipt_long),
                      title: Text(fixo.descricao),
                      subtitle: Text(
                        ehGanho
                            ? '${nomeDoMembro(membros, fixo.membroId)} · ${formatarReais(fixo.valor)}'
                            : '${nomeDoMembro(membros, fixo.membroId)} · '
                                '${nomeDoPote(listaPotes, fixo.poteId!)} · '
                                '${formatarReais(fixo.valor)}',
                      ),
                      // Mesmo raciocinio de _ColunaMembro em
                      // tela_ganhos.dart: se quem o Fixo pertence foi
                      // removido, ele entra no dropdown mesmo assim (senao
                      // o formulario quebraria por faltar o valor
                      // selecionado como opcao).
                      onTap: () => _editar(context, ref,
                          membros: membrosAtivos
                                  .any((m) => m.id == fixo.membroId)
                              ? membrosAtivos
                              : [
                                  ...membrosAtivos,
                                  membros.firstWhere(
                                      (m) => m.id == fixo.membroId),
                                ],
                          potes: listaPotes,
                          fixo: fixo),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Excluir',
                        onPressed: () async {
                          final confirmou = await confirmarExclusao(
                            context: context,
                            titulo: 'Excluir fixo',
                            mensagem: 'Deseja excluir "${fixo.descricao}"? '
                                'O lançamento previsto do mês seguinte '
                                'também é apagado; lançamentos de meses '
                                'anteriores não são afetados.',
                          );
                          if (!confirmou) return;
                          try {
                            await ref
                                .read(repositorioFixosProvider)
                                .remover(fixo.id);
                            await removerLancamentoDoFixo(
                              fixo: fixo,
                              mesAlvo: mesAlvoDosFixos(),
                              repoGanhos: ref.read(repositorioGanhosProvider),
                              repoGastos: ref.read(repositorioGastosProvider),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            avisarErroDeEscrita(context, e);
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _perguntarTipo(
    BuildContext context,
    WidgetRef ref, {
    required List<Membro> membros,
    required List<Pote> potes,
  }) async {
    final tipo = await showDialog<TipoFixo>(
      context: context,
      builder: (dialogo) => SimpleDialog(
        title: const Text('Novo fixo'),
        children: [
          SimpleDialogOption(
            key: const Key('tipo_fixo_ganho'),
            onPressed: () => Navigator.of(dialogo).pop(TipoFixo.ganho),
            child: const Text('Ganho'),
          ),
          SimpleDialogOption(
            key: const Key('tipo_fixo_gasto'),
            onPressed: () => Navigator.of(dialogo).pop(TipoFixo.gasto),
            child: const Text('Gasto'),
          ),
        ],
      ),
    );
    if (tipo == null || !context.mounted) return;

    final resultado = await mostrarFormulario<Fixo>(
      context: context,
      titulo: tipo == TipoFixo.ganho ? 'Novo ganho fixo' : 'Novo gasto fixo',
      construir: (c) =>
          _Formulario(tipo: tipo, membros: membros, potes: potes),
    );
    if (resultado == null || !context.mounted) return;

    try {
      await ref.read(repositorioFixosProvider).adicionar(resultado);
      // Sem isto, o lancamento previsto deste Fixo so apareceria na proxima
      // vez que o app abrisse (garantirFixosDoMesProvider, watchado uma vez
      // soh a partir do Shell, ja rodou antes deste Fixo existir) -- chama a
      // mesma logica direto (nao via provider) para gerar agora. E
      // idempotente (ids deterministicos), entao nao duplica os Fixos ja
      // gerados antes.
      await garantirFixosDoMes(
        repoFixos: ref.read(repositorioFixosProvider),
        repoGanhos: ref.read(repositorioGanhosProvider),
        repoGastos: ref.read(repositorioGastosProvider),
      );
    } catch (e) {
      if (!context.mounted) return;
      avisarErroDeEscrita(context, e);
    }
  }

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref, {
    required List<Membro> membros,
    required List<Pote> potes,
    required Fixo fixo,
  }) async {
    final resultado = await mostrarFormulario<Fixo>(
      context: context,
      titulo: fixo.tipo == TipoFixo.ganho
          ? 'Editar ganho fixo'
          : 'Editar gasto fixo',
      construir: (c) => _Formulario(
        tipo: fixo.tipo,
        membros: membros,
        potes: potes,
        existente: fixo,
      ),
    );
    if (resultado == null || !context.mounted) return;

    try {
      await ref.read(repositorioFixosProvider).atualizar(resultado);
      // Sincroniza o lancamento do mes seguinte com os novos valores na
      // hora -- combinado com a decisao do usuario de que editar o Fixo
      // tambem altera esse lancamento, sem esperar a proxima geracao.
      await definirLancamentoDoFixo(
        fixo: resultado,
        mesAlvo: mesAlvoDosFixos(),
        repoGanhos: ref.read(repositorioGanhosProvider),
        repoGastos: ref.read(repositorioGastosProvider),
      );
    } catch (e) {
      if (!context.mounted) return;
      avisarErroDeEscrita(context, e);
    }
  }
}

class _Formulario extends StatefulWidget {
  final TipoFixo tipo;
  final List<Membro> membros;
  final List<Pote> potes;
  final Fixo? existente;

  const _Formulario({
    required this.tipo,
    required this.membros,
    required this.potes,
    this.existente,
  });

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  final _chave = GlobalKey<FormState>();
  late final TextEditingController _descricao;
  late final TextEditingController _valor;
  late String _membroId;
  String? _poteId;

  @override
  void initState() {
    super.initState();
    final f = widget.existente;
    _descricao = TextEditingController(text: f?.descricao ?? '');
    _valor = TextEditingController(
      text: f == null ? '' : formatarReais(f.valor),
    );
    _membroId = f?.membroId ?? widget.membros.first.id;
    _poteId = f?.poteId ??
        (widget.tipo == TipoFixo.gasto && widget.potes.isNotEmpty
            ? widget.potes.first.id
            : null);
  }

  @override
  void dispose() {
    _descricao.dispose();
    _valor.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!_chave.currentState!.validate()) return;

    final base = widget.existente;
    final fixo = Fixo(
      id: base?.id ?? '',
      tipo: widget.tipo,
      membroId: _membroId,
      descricao: _descricao.text.trim(),
      valor: parsearMoeda(_valor.text) ?? 0,
      criadoEm: base?.criadoEm ?? DateTime.now(),
      poteId: widget.tipo == TipoFixo.gasto ? _poteId : null,
    );
    Navigator.of(context).pop(fixo);
  }

  @override
  Widget build(BuildContext context) {
    final ehGasto = widget.tipo == TipoFixo.gasto;

    return Form(
      key: _chave,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('fixo_form_descricao'),
            controller: _descricao,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: const [PrimeiraMaiuscula()],
            decoration: const InputDecoration(
              labelText: 'Descrição',
              border: OutlineInputBorder(),
            ),
            validator: (t) => (t == null || t.trim().isEmpty)
                ? 'Informe a descrição.'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('fixo_form_membro'),
            initialValue: _membroId,
            decoration: const InputDecoration(
              labelText: 'De quem',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final m in widget.membros)
                DropdownMenuItem(value: m.id, child: Text(m.nome)),
            ],
            onChanged: (v) => setState(() => _membroId = v ?? _membroId),
          ),
          if (ehGasto) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('fixo_form_pote'),
              initialValue: _poteId,
              decoration: const InputDecoration(
                labelText: 'Pote',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final p in widget.potes)
                  DropdownMenuItem(value: p.id, child: Text(p.nome)),
              ],
              onChanged: (v) => setState(() => _poteId = v),
              validator: (_) =>
                  _poteId == null ? 'Escolha um pote.' : null,
            ),
          ],
          const SizedBox(height: 12),
          CampoMoeda(controlador: _valor),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('fixo_form_salvar'),
            onPressed: _salvar,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
