import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/ganho.dart';
import '../../dominio/models/membro.dart';
import '../../dominio/totais.dart';
import '../../estado/providers.dart';
import '../shell.dart' show breakpointDesktop;
import '../tema/formatadores.dart';
import '../tema/tema.dart';
import '../widgets/campo_moeda.dart';
import '../widgets/estados_async.dart';
import '../widgets/formulario_responsivo.dart';

class TelaGanhos extends ConsumerWidget {
  const TelaGanhos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesRef = ref.watch(mesSelecionadoProvider).valor;
    final membros = ref.watch(membrosProvider);
    final ganhos = ref.watch(ganhosDoMesProvider(mesRef));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('novo_ganho'),
        onPressed: membros.isEmpty
            ? null
            : () => _abrir(context, ref, membros: membros, mesRef: mesRef),
        icon: const Icon(Icons.add),
        label: const Text('Novo ganho'),
      ),
      body: ganhos.when(
        loading: () => const CarregandoLista(),
        error: (e, _) => ErroComRecarregar(
          erro: e,
          aoRecarregar: () => ref.invalidate(ganhosDoMesProvider(mesRef)),
        ),
        data: (lista) => _Conteudo(membros: membros, ganhos: lista),
      ),
    );
  }
}

/// Abre o formulario e grava. [existente] nulo significa novo lancamento.
Future<void> _abrir(
  BuildContext context,
  WidgetRef ref, {
  required List<Membro> membros,
  required String mesRef,
  Ganho? existente,
}) async {
  final resultado = await mostrarFormulario<Ganho>(
    context: context,
    titulo: existente == null ? 'Novo ganho' : 'Editar ganho',
    construir: (c) => _Formulario(
      membros: membros,
      mesRef: mesRef,
      existente: existente,
    ),
  );
  if (resultado == null) return;

  final repo = ref.read(repositorioGanhosProvider);
  if (existente == null) {
    await repo.adicionar(resultado);
  } else {
    await repo.atualizar(resultado);
  }
}

class _Conteudo extends ConsumerWidget {
  final List<Membro> membros;
  final List<Ganho> ganhos;

  const _Conteudo({required this.membros, required this.ganhos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final porMembro = somarGanhosPorMembro(ganhos);
    final total = porMembro.values.fold<double>(0, (a, b) => a + b);
    final desktop = MediaQuery.sizeOf(context).width >= breakpointDesktop;

    final colunas = [
      for (final m in membros)
        _ColunaMembro(
          membro: m,
          ganhos: ganhos.where((g) => g.membroId == m.id).toList(),
          subtotal: porMembro[m.id] ?? 0,
        ),
    ];

    return Column(
      children: [
        Expanded(
          child: desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final c in colunas) Expanded(child: c)],
                )
              : ListView(
                  key: const Key('secoes_empilhadas'),
                  children: [
                    for (final c in colunas)
                      SizedBox(height: 320, child: c),
                  ],
                ),
        ),
        const Divider(height: 1),
        Container(
          key: const Key('total_geral_ganhos'),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total do mês',
                  style: Theme.of(context).textTheme.titleMedium),
              Text(
                formatarReais(total),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColunaMembro extends ConsumerWidget {
  final Membro membro;
  final List<Ganho> ganhos;
  final double subtotal;

  const _ColunaMembro({
    required this.membro,
    required this.ganhos,
    required this.subtotal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesRef = ref.watch(mesSelecionadoProvider).valor;
    final membros = ref.watch(membrosProvider);

    // O subtotal fica FORA do Card com a chave coluna_<id>, e nao aninhado
    // dentro dele: quando a pessoa tem um so lancamento, o valor da linha e
    // o subtotal coincidem, e find.descendant(of: coluna_<id>) encontraria
    // os dois textos iguais — o subtotal precisa da sua propria chave, sem
    // ficar dentro do escopo de busca da coluna.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Card(
            key: Key('coluna_${membro.id}'),
            margin: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                          radius: 8, backgroundColor: corDeHex(membro.cor)),
                      const SizedBox(width: 8),
                      Text(membro.nome,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ganhos.isEmpty
                      ? const Center(child: Text('Nenhum ganho neste mês.'))
                      : ListView.builder(
                          itemCount: ganhos.length,
                          itemBuilder: (context, i) {
                            final g = ganhos[i];
                            return ListTile(
                              key: Key('ganho_${g.id}'),
                              title: Text(g.descricao),
                              subtitle: Text(formatarReais(g.valor)),
                              onTap: () => _abrir(
                                context,
                                ref,
                                membros: membros,
                                mesRef: mesRef,
                                existente: g,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Excluir',
                                onPressed: () => ref
                                    .read(repositorioGanhosProvider)
                                    .remover(g.id),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          key: Key('subtotal_${membro.id}'),
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal'),
              Text(
                formatarReais(subtotal),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Formulario extends StatefulWidget {
  final List<Membro> membros;
  final String mesRef;
  final Ganho? existente;

  const _Formulario({
    required this.membros,
    required this.mesRef,
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

  @override
  void initState() {
    super.initState();
    final g = widget.existente;
    _descricao = TextEditingController(text: g?.descricao ?? '');
    _valor = TextEditingController(
      text: g == null ? '' : formatarReais(g.valor),
    );
    _membroId = g?.membroId ?? widget.membros.first.id;
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
    final ganho = Ganho(
      id: base?.id ?? '',
      mesRef: widget.mesRef,
      membroId: _membroId,
      descricao: _descricao.text.trim(),
      valor: parsearMoeda(_valor.text) ?? 0,
      criadoEm: base?.criadoEm ?? DateTime.now(),
    );
    Navigator.of(context).pop(ganho);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _chave,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('form_membro'),
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
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('form_descricao'),
            controller: _descricao,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              border: OutlineInputBorder(),
            ),
            validator: (t) => (t == null || t.trim().isEmpty)
                ? 'Informe a descrição.'
                : null,
          ),
          const SizedBox(height: 12),
          CampoMoeda(controlador: _valor),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('form_salvar'),
            onPressed: _salvar,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
