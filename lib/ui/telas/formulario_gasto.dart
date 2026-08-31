import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/models/gasto.dart';
import '../../dominio/models/membro.dart';
import '../../dominio/models/mes_ref.dart';
import '../../dominio/models/pote.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';
import '../widgets/campo_moeda.dart';
import '../widgets/estados_async.dart';
import '../widgets/formulario_responsivo.dart';

/// O que o formulario devolve ao ser fechado: os dados prontos para gravar,
/// sem que o formulario em si precise saber de repositorio. [existente] nulo
/// no `abrirFormularioGasto` que chamou decide entre adicionar e atualizar.
class _ResultadoFormularioGasto {
  final Gasto gasto;
  final int quantidadeParcelas;
  const _ResultadoFormularioGasto(this.gasto, this.quantidadeParcelas);
}

/// Abre o formulario na moldura certa para a largura atual e grava o
/// resultado. [existente] nulo significa novo lancamento.
///
/// Fecha o dialogo/folha PRIMEIRO e so entao escreve no repositorio — mesma
/// ordem de `_abrir` em tela_ganhos.dart. Com persistencia offline habilitada
/// (main.dart), o Future da escrita so completa quando o servidor confirma;
/// esperar por ele antes de fechar travaria o formulario aberto indefinida-
/// mente sem rede.
Future<void> abrirFormularioGasto({
  required BuildContext context,
  required WidgetRef ref,
  Gasto? existente,
}) async {
  final resultado = await mostrarFormulario<_ResultadoFormularioGasto>(
    context: context,
    titulo: existente == null ? 'Novo gasto' : 'Editar gasto',
    construir: (c) => FormularioGasto(existente: existente),
  );
  if (resultado == null) return;

  final repo = ref.read(repositorioGastosProvider);
  try {
    if (existente != null) {
      // Edicao mexe so neste documento: os tres modos da spec valem para
      // exclusao, nao para edicao.
      await repo.atualizar(resultado.gasto);
    } else {
      await repo.adicionar(
        base: resultado.gasto,
        quantidadeParcelas: resultado.quantidadeParcelas,
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    avisarErroDeEscrita(context, e);
  }
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

  /// Guarda de reentrancia: sem ela, dois toques rapidos no Salvar antes do
  /// primeiro pop surtir efeito na arvore de widgets chamariam validate() e
  /// Navigator.pop() duas vezes -- o classico bug do "duplo pop" que fecha
  /// uma tela a mais, ou (antes desta correcao mover a escrita para depois
  /// do fechamento) enfileiraria dois commits offline duplicando o lancamento.
  bool _salvando = false;

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

  void _salvar() {
    if (_salvando) return;
    if (!_chave.currentState!.validate()) return;
    _salvando = true;

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

    Navigator.of(context).pop(
      _ResultadoFormularioGasto(
        gasto,
        _parcelado ? _quantidadeParcelas : 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membros = ref.watch(membrosProvider);

    // AsyncValue.when com os tres ramos, sem excecao: `.value ?? []` faria o
    // validador do pote acusar "Cadastre um pote antes." enquanto os potes
    // ainda estao carregando, mesmo quando eles existem.
    return ref.watch(potesProvider).when(
          loading: () => const CarregandoLista(linhas: 3),
          error: (e, _) => ErroComRecarregar(
            erro: e,
            aoRecarregar: () => ref.invalidate(potesProvider),
          ),
          data: (potes) => _formulario(context, membros, potes),
        );
  }

  Widget _formulario(
    BuildContext context,
    List<Membro> membros,
    List<Pote> potes,
  ) {
    // Preenche os defaults na primeira construcao em que os dados chegaram.
    if (_membroId.isEmpty && membros.isNotEmpty) _membroId = membros.first.id;

    // Se o pote apontado nao existe mais (foi apagado enquanto o formulario
    // estava aberto, ou o lancamento editado aponta para um pote ja
    // removido), reseta em vez de manter um id orfao: sem isso o
    // DropdownButtonFormField derruba o assert de "exactly one item with
    // [DropdownButton]'s value", e reenviar o id orfao no Salvar deixaria o
    // gasto preso a um pote que nao existe mais.
    if (_poteId != null && !potes.any((p) => p.id == _poteId)) {
      _poteId = null;
    }
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
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Selecione quem gastou.' : null,
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
            onPressed: _salvando ? null : _salvar,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
