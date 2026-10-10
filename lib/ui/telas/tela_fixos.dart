import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/fixo.dart';
import '../../dominio/models/membro.dart';
import '../../dominio/models/pote.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('novo_fixo'),
        onPressed: membrosAtivos.isEmpty
            ? null
            : () => _perguntarTipo(context, ref,
                membros: membrosAtivos, potes: potes.value ?? const []),
        icon: const Icon(Icons.add),
        label: const Text('Novo fixo'),
      ),
      body: combinado.when(
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
                leading: Icon(ehGanho ? Icons.trending_up : Icons.receipt_long),
                title: Text(fixo.descricao),
                subtitle: Text(
                  ehGanho
                      ? '${nomeDoMembro(membros, fixo.membroId)} · ${formatarReais(fixo.valor)}'
                      : '${nomeDoMembro(membros, fixo.membroId)} · '
                          '${nomeDoPote(listaPotes, fixo.poteId!)} · '
                          '${formatarReais(fixo.valor)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Excluir',
                  onPressed: () async {
                    final confirmou = await confirmarExclusao(
                      context: context,
                      titulo: 'Excluir fixo',
                      mensagem: 'Deseja excluir "${fixo.descricao}"? '
                          'Lançamentos já gerados por ele não são apagados.',
                    );
                    if (!confirmou) return;
                    try {
                      await ref.read(repositorioFixosProvider).remover(fixo.id);
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

  const _Formulario({
    required this.tipo,
    required this.membros,
    required this.potes,
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
    _descricao = TextEditingController();
    _valor = TextEditingController();
    _membroId = widget.membros.first.id;
    _poteId = widget.tipo == TipoFixo.gasto && widget.potes.isNotEmpty
        ? widget.potes.first.id
        : null;
  }

  @override
  void dispose() {
    _descricao.dispose();
    _valor.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!_chave.currentState!.validate()) return;

    final fixo = Fixo(
      id: '',
      tipo: widget.tipo,
      membroId: _membroId,
      descricao: _descricao.text.trim(),
      valor: parsearMoeda(_valor.text) ?? 0,
      criadoEm: DateTime.now(),
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
