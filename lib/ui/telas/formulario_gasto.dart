import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/cascata.dart';
import '../../dominio/models/gasto.dart';
import '../../dominio/models/cartao.dart';
import '../../dominio/models/membro.dart';
import '../../dominio/models/mes_ref.dart';
import '../../dominio/models/pote.dart';
import '../../dominio/parcelas.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';
import '../widgets/campo_moeda.dart';
import '../widgets/dialogo_edicao.dart';
import '../widgets/estados_async.dart';
import '../widgets/formulario_responsivo.dart';
import '../widgets/primeira_maiuscula.dart';

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
/// mente sem rede. A pergunta do alcance tambem vem depois do fechamento,
/// para nao empilhar um dialogo sobre o outro.
Future<void> abrirFormularioGasto({
  required BuildContext context,
  required WidgetRef ref,
  Gasto? existente,
  String? poteIdInicial,
}) async {
  final resultado = await mostrarFormulario<_ResultadoFormularioGasto>(
    context: context,
    titulo: existente == null ? 'Novo gasto' : 'Editar gasto',
    construir: (c) => FormularioGasto(
      existente: existente,
      poteIdInicial: poteIdInicial,
    ),
  );
  if (resultado == null) return;

  final repo = ref.read(repositorioGastosProvider);
  try {
    if (existente == null) {
      await repo.adicionar(
        base: resultado.gasto,
        quantidadeParcelas: resultado.quantidadeParcelas,
      );
      return;
    }

    // Gasto simples: o documento ja e a compra inteira, nao ha alcance a
    // escolher.
    if (!existente.parcelado || existente.compraId == null) {
      await repo.atualizar(resultado.gasto);
      return;
    }

    // So o valor abre a pergunta. Descricao, pessoa e pote descrevem a
    // compra e vao para todas as parcelas sozinhos; a quantidade tambem vale
    // para a compra inteira em qualquer modo. Perguntar nesses casos seria um
    // dialogo cujas tres opcoes fazem a mesma coisa.
    var alcance = ModoEdicao.todas;
    if (_valorMudou(existente, resultado.gasto)) {
      if (!context.mounted) return;
      final escolhido =
          await perguntarModoEdicao(context: context, gasto: existente);
      if (escolhido == null) return;
      alcance = escolhido;
    }

    await repo.atualizarCompra(
      editado: resultado.gasto,
      alcance: alcance,
      novaQuantidade: resultado.quantidadeParcelas,
    );
  } catch (e) {
    if (!context.mounted) return;
    avisarErroDeEscrita(context, e);
  }
}

/// O unico campo cuja propagacao e uma escolha do usuario. Os demais ja
/// tem resposta: descricao, pessoa e pote vao para a compra inteira; mes,
/// parcela e total sao aritmetica, nao edicao.
bool _valorMudou(Gasto antes, Gasto depois) =>
    (antes.valor - depois.valor).abs() > toleranciaCentavo;

class FormularioGasto extends ConsumerStatefulWidget {
  final Gasto? existente;
  final String? poteIdInicial;
  const FormularioGasto({super.key, this.existente, this.poteIdInicial});

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
  late DateTime _data;
  String? _cartaoId;

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
    _data = g?.data ?? _hojeOuInicioDoMes();
    _cartaoId = g?.cartaoId;
    // O preview le _valor.text direto no build: sem este listener, digitar
    // um novo valor depois de ligar "Parcelado" nao teria efeito ate algum
    // outro campo forcar um rebuild.
    _valor.addListener(_aoMudarValor);
  }

  void _aoMudarValor() {
    if (mounted) setState(() {});
  }

  /// Hoje quando o mes exibido e o corrente; dia 1 do mes exibido nos demais.
  ///
  /// Sugerir "hoje" enquanto a pessoa navega em marco de um ano atras daria
  /// uma data que quase nunca e a que ela quer.
  DateTime _hojeOuInicioDoMes() {
    final mes = ref.read(mesSelecionadoProvider);
    final agora = DateTime.now();
    if (mes.ano == agora.year && mes.mes == agora.month) {
      return DateTime(agora.year, agora.month, agora.day);
    }
    return DateTime(mes.ano, mes.mes, 1);
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      // Cinco anos para tras e um para a frente cobre lancamento atrasado e
      // agendamento, sem oferecer um calendario infinito.
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      helpText: 'Data do gasto',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );
    if (escolhida != null && mounted) setState(() => _data = escolhida);
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

  /// O menor total que a compra pode ter. Encolher abaixo da parcela aberta
  /// apagaria o documento que esta sendo editado — a lista e o lugar de
  /// apagar parcelas, com o dialogo de tres modos que ja existe la.
  int get _minimoParcelas {
    final parcela = widget.existente?.parcela ?? 1;
    return parcela < 2 ? 2 : parcela;
  }

  /// O mes da parcela 1, que e onde a compra realmente comeca. Editar a
  /// parcela 3 nao pode fazer o preview dizer que a compra comeca nela.
  MesRef _inicioDaCompra(MesRef mesSelecionado) {
    final g = widget.existente;
    if (g == null) return mesSelecionado;
    return MesRef.parse(g.mesRef).avancar(-((g.parcela ?? 1) - 1));
  }

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
      data: _data,
      cartaoId: _cartaoId,
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
    // Ativos para o seletor "de quem": quem foi removido nao pode ganhar um
    // lancamento novo. `_formulario` reintroduz a pessoa removida na lista
    // so quando o gasto editado ja era dela (ver comentario la).
    final membrosAtivos = ref.watch(membrosAtivosProvider);
    final todosMembros = ref.watch(membrosProvider);

    // AsyncValue.when com os tres ramos, sem excecao: `.value ?? []` faria o
    // validador do pote acusar "Cadastre um pote antes." enquanto os potes
    // ainda estao carregando, mesmo quando eles existem.
    // Cartao entra na combinacao para o seletor nao aparecer vazio enquanto
    // a lista ainda esta chegando, o que faria o usuario achar que nao ha
    // cartao cadastrado.
    return combinarAsyncValues(
      ref.watch(potesProvider),
      ref.watch(cartoesProvider),
      (potes, cartoes) => (potes, cartoes),
    ).when(
      // Altura fixa: CarregandoLista e um ListView, e o formulario abre
      // dentro de um dialogo, onde a altura e ilimitada. Sem o limite o
      // viewport nao consegue se dimensionar e o layout quebra.
      loading: () => const SizedBox(
        height: 180,
        child: CarregandoLista(linhas: 3),
      ),
      error: (e, _) => ErroComRecarregar(
        erro: e,
        aoRecarregar: () {
          ref.invalidate(potesProvider);
          ref.invalidate(cartoesProvider);
        },
      ),
      data: (par) {
        // O gasto editado pode pertencer a alguem que ja foi removido da
        // casa: sem reincluir essa pessoa aqui, o DropdownButtonFormField
        // derrubaria o assert de "exactly one item with value" so por abrir
        // a edicao — e trocar o membro so porque o formulario abriu seria
        // pior ainda, reatribuindo um gasto historico sem a pessoa pedir.
        final membroDoGasto = widget.existente?.membroId;
        final membros = membroDoGasto != null &&
                membrosAtivos.every((m) => m.id != membroDoGasto)
            ? [
                ...membrosAtivos,
                ...todosMembros.where((m) => m.id == membroDoGasto),
              ]
            : membrosAtivos;
        return _formulario(context, membros, par.$1, par.$2);
      },
    );
  }

  Widget _formulario(
    BuildContext context,
    List<Membro> membros,
    List<Pote> potes,
    List<Cartao> cartoes,
  ) {
    // Preenche os defaults na primeira construcao em que os dados chegaram.
    //
    // "De quem" comeca em quem esta logado: quem abre o formulario quase
    // sempre esta lancando o proprio gasto. E `read` de proposito — isto
    // semeia o valor inicial uma vez so; trocar de conta com o formulario
    // aberto nao deve reescrever o que a pessoa ja escolheu no seletor.
    if (_membroId.isEmpty && membros.isNotEmpty) {
      final logado = ref.read(membroLogadoProvider);
      // Confere que o logado esta mesmo nesta lista antes de usar o id: um
      // valor sem item correspondente derruba o assert de "exactly one item
      // with [DropdownButton]'s value".
      final daCasa = logado != null && membros.any((m) => m.id == logado.id);
      _membroId = daCasa ? logado.id : membros.first.id;
    }

    // Se o pote apontado nao existe mais (foi apagado enquanto o formulario
    // estava aberto, ou o lancamento editado aponta para um pote ja
    // removido), reseta em vez de manter um id orfao: sem isso o
    // DropdownButtonFormField derruba o assert de "exactly one item with
    // [DropdownButton]'s value", e reenviar o id orfao no Salvar deixaria o
    // gasto preso a um pote que nao existe mais.
    if (_poteId != null && !potes.any((p) => p.id == _poteId)) {
      _poteId = null;
    }
    // poteIdInicial (a faixa de potes de Gastos) so vale se ainda existir
    // na lista -- mesma cautela do pote de um lancamento existente, acima.
    _poteId ??= (widget.poteIdInicial != null &&
            potes.any((p) => p.id == widget.poteIdInicial))
        ? widget.poteIdInicial
        : (potes.isEmpty ? null : potes.first.id);

    // Mesmo tratamento de id orfao do pote: um cartao removido enquanto o
    // formulario estava aberto derrubaria o assert do DropdownButton.
    if (_cartaoId != null && !cartoes.any((c) => c.id == _cartaoId)) {
      _cartaoId = null;
    }

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
          InkWell(
            key: const Key('gasto_data'),
            onTap: _escolherData,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data do gasto',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(formatarData(_data)),
            ),
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
          DropdownButtonFormField<String?>(
            key: const Key('gasto_cartao'),
            initialValue: _cartaoId,
            decoration: const InputDecoration(
              labelText: 'Cartão',
              border: OutlineInputBorder(),
            ),
            items: [
              // Nem todo gasto passa por cartao: dinheiro, pix e debito
              // caem aqui, e por isso nao ha validador exigindo escolha.
              const DropdownMenuItem(
                  value: null, child: Text('Nenhum / dinheiro')),
              for (final c in cartoes)
                DropdownMenuItem(value: c.id, child: Text(c.nome)),
            ],
            onChanged: (v) => setState(() => _cartaoId = v),
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
            // A quantidade de parcelas e editavel, mas o interruptor nao:
            // transformar um gasto simples em parcelado (ou o contrario)
            // troca o significado do lancamento, nao o seu tamanho. Para
            // isso, apague e lance de novo.
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
              validator: (_) {
                if (_quantidadeParcelas >= _minimoParcelas) return null;
                return _minimoParcelas > 2
                    ? 'Você está editando a parcela $_minimoParcelas; '
                        'use a lista para apagar parcelas.'
                    : 'Um parcelamento tem pelo menos 2 parcelas.';
              },
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
                  inicio: _inicioDaCompra(mes),
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
