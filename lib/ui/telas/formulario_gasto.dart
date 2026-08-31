import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/gasto.dart';
import '../../dominio/models/mes_ref.dart';
import '../../dominio/models/pote.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';
import '../widgets/campo_moeda.dart';
import '../widgets/formulario_responsivo.dart';

/// Abre o formulario na moldura certa para a largura atual e grava o
/// resultado. [existente] nulo significa novo lancamento.
Future<void> abrirFormularioGasto({
  required BuildContext context,
  required WidgetRef ref,
  Gasto? existente,
}) {
  return mostrarFormulario<void>(
    context: context,
    titulo: existente == null ? 'Novo gasto' : 'Editar gasto',
    construir: (c) => FormularioGasto(existente: existente),
  );
}

class FormularioGasto extends ConsumerStatefulWidget {
  final Gasto? existente;
  const FormularioGasto({super.key, this.existente});

  @override
  ConsumerState<FormularioGasto> createState() => _FormularioGastoState();
}

class _FormularioGastoState extends ConsumerState<FormularioGasto> {
  final _chave = GlobalKey<FormState>();
  late final TextEditingController _descricao;
  late final TextEditingController _valor;
  late final TextEditingController _quantidade;
  late String _membroId;
  String? _poteId;
  late bool _parcelado;

  @override
  void initState() {
    super.initState();
    final g = widget.existente;
    _descricao = TextEditingController(text: g?.descricao ?? '');
    _valor =
        TextEditingController(text: g == null ? '' : formatarReais(g.valor));
    _quantidade =
        TextEditingController(text: (g?.totalParcelas ?? 2).toString());
    _membroId = g?.membroId ?? '';
    _poteId = g?.poteId;
    _parcelado = g?.parcelado ?? false;
    // O preview le _valor.text direto no build: sem este listener, digitar
    // um novo valor depois de ligar "Parcelado" nao teria efeito ate algum
    // outro campo forcar um rebuild.
    _valor.addListener(_aoMudarValor);
  }

  void _aoMudarValor() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _valor.removeListener(_aoMudarValor);
    _descricao.dispose();
    _valor.dispose();
    _quantidade.dispose();
    super.dispose();
  }

  int get _quantidadeParcelas => int.tryParse(_quantidade.text) ?? 0;

  Future<void> _salvar() async {
    if (!_chave.currentState!.validate()) return;

    final mes = ref.read(mesSelecionadoProvider);
    final base = widget.existente;
    final gasto = Gasto(
      id: base?.id ?? '',
      mesRef: base?.mesRef ?? mes.valor,
      membroId: _membroId,
      poteId: _poteId ?? '',
      descricao: _descricao.text.trim(),
      valor: parsearMoeda(_valor.text) ?? 0,
      criadoEm: base?.criadoEm ?? DateTime.now(),
      parcelado: base?.parcelado ?? false,
      compraId: base?.compraId,
      parcela: base?.parcela,
      totalParcelas: base?.totalParcelas,
    );

    final repo = ref.read(repositorioGastosProvider);
    if (base != null) {
      // Edicao mexe so neste documento: os tres modos da spec valem para
      // exclusao, nao para edicao.
      await repo.atualizar(gasto);
    } else {
      await repo.adicionar(
        base: gasto,
        quantidadeParcelas: _parcelado ? _quantidadeParcelas : 1,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final membros = ref.watch(membrosProvider);
    final potes = ref.watch(potesProvider).value ?? const <Pote>[];

    // Preenche os defaults na primeira construcao em que os dados chegaram.
    if (_membroId.isEmpty && membros.isNotEmpty) _membroId = membros.first.id;
    _poteId ??= potes.isEmpty ? null : potes.first.id;

    final mes = ref.watch(mesSelecionadoProvider);

    return Form(
      key: _chave,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('gasto_descricao'),
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
          DropdownButtonFormField<String>(
            key: const Key('gasto_membro'),
            initialValue: _membroId.isEmpty ? null : _membroId,
            decoration: const InputDecoration(
              labelText: 'De quem',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final m in membros)
                DropdownMenuItem(value: m.id, child: Text(m.nome)),
            ],
            onChanged: (v) => setState(() => _membroId = v ?? _membroId),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('gasto_pote'),
            initialValue: _poteId,
            decoration: const InputDecoration(
              labelText: 'Pote',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final p in potes)
                DropdownMenuItem(value: p.id, child: Text(p.nome)),
            ],
            onChanged: (v) => setState(() => _poteId = v ?? _poteId),
            validator: (v) => v == null ? 'Cadastre um pote antes.' : null,
          ),
          const SizedBox(height: 12),
          CampoMoeda(
            key: const Key('gasto_valor'),
            controlador: _valor,
            rotulo: _parcelado ? 'Valor da parcela' : 'Valor',
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('gasto_parcelado'),
            title: const Text('Parcelado'),
            value: _parcelado,
            // Editar parcelamento de um lancamento existente mudaria o
            // numero de documentos; isso e criacao, nao edicao.
            onChanged: widget.existente != null
                ? null
                : (v) => setState(() => _parcelado = v),
          ),
          if (_parcelado) ...[
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('gasto_quantidade'),
              controller: _quantidade,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantidade de parcelas',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: (_) => _quantidadeParcelas < 2
                  ? 'Um parcelamento tem pelo menos 2 parcelas.'
                  : null,
            ),
            const SizedBox(height: 12),
            Container(
              key: const Key('gasto_preview'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                resumoParcelamento(
                  valorParcela: parsearMoeda(_valor.text) ?? 0,
                  quantidade:
                      _quantidadeParcelas < 1 ? 1 : _quantidadeParcelas,
                  inicio: MesRef.parse(widget.existente?.mesRef ?? mes.valor),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('gasto_salvar'),
            onPressed: _salvar,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
