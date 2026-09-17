import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dados/repositorio_gestao_casa.dart';
import '../../dominio/models/cartao.dart';
import '../../estado/providers.dart';
import '../widgets/dialogo_exclusao.dart';
import '../widgets/estados_async.dart';
import '../widgets/formulario_responsivo.dart';
import '../widgets/primeira_maiuscula.dart';
import '../widgets/tabela_responsiva.dart';

/// O MEU dia de fechamento deste cartao, pra mostrar na propria lista sem
/// precisar abrir o dialogo. Igual ao repositorio, so o dia de quem esta
/// logado -- nunca o de outro integrante.
final _meuFechamentoDaListaProvider =
    FutureProvider.family<int?, String>((ref, cartaoId) {
  final membroId = ref.watch(membroLogadoProvider)?.id;
  if (membroId == null) return Future.value(null);
  return ref
      .watch(repositorioCartoesProvider)
      .meuFechamento(cartaoId, membroId);
});

/// Cadastro dos cartoes, contas e carteiras usados para pagar.
///
/// CRUD simples, sem a trava de soma que a Lei dos Potes tem: nao ha
/// invariante entre cartoes, cada um vive por si.
class TelaCartoes extends ConsumerWidget {
  const TelaCartoes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('novo_cartao'),
        onPressed: () => _abrir(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Novo cartão'),
      ),
      body: ref.watch(cartoesProvider).when(
            loading: () => const CarregandoLista(),
            error: (e, _) => ErroComRecarregar(
              erro: e,
              aoRecarregar: () => ref.invalidate(cartoesProvider),
            ),
            data: (cartoes) => TabelaResponsiva(
              colunas: const ['Cartão'],
              vazio: 'Nenhum cartão cadastrado.',
              linhas: [
                for (final c in cartoes)
                  LinhaResponsiva(
                    chave: ValueKey('cartao_${c.id}'),
                    valores: [c.nome],
                    tituloEmNegrito: true,
                    aoTocar: () => _abrir(context, ref, existente: c),
                    aoExcluir: () => _excluir(context, ref, c),
                    // Texto e icone juntos, colados um no outro -- nao como
                    // colunas separadas, que o DataTable espacaria longe um
                    // do outro.
                    acaoTrailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ref.watch(_meuFechamentoDaListaProvider(c.id)).value
                            case final dia?)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              'Fechamento dia $dia',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        IconButton(
                          key: Key('fechamento_rapido_${c.id}'),
                          icon: const Icon(Icons.calendar_today, size: 20),
                          tooltip: 'Meu dia de fechamento',
                          onPressed: () =>
                              _definirFechamentoRapido(context, ref, c),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  /// Fecha o formulario antes de escrever, na mesma ordem das outras telas:
  /// com cache offline, o Future da escrita so completa quando o servidor
  /// confirma, e esperar por ele travaria o formulario aberto sem rede.
  Future<void> _abrir(
    BuildContext context,
    WidgetRef ref, {
    Cartao? existente,
  }) async {
    final cartoes = ref.read(cartoesProvider).value ?? const <Cartao>[];
    final membroId = ref.read(membroLogadoProvider)?.id;

    // So busca o fechamento de quem esta editando um cartao que ja existe;
    // um cartao novo nunca tem fechamento de ninguem ainda.
    int? fechamentoAtual;
    if (existente != null && membroId != null) {
      fechamentoAtual = await ref
          .read(repositorioCartoesProvider)
          .meuFechamento(existente.id, membroId);
    }
    if (!context.mounted) return;

    final resultado = await mostrarFormulario<(String, int?)>(
      context: context,
      titulo: existente == null ? 'Novo cartão' : 'Editar cartão',
      construir: (c) => _FormularioCartao(
        existente: existente,
        fechamentoInicial: fechamentoAtual,
      ),
    );
    if (resultado == null) return;
    final (nome, fechamento) = resultado;

    try {
      final cartaoId = await ref.read(repositorioCartoesProvider).salvar(
            existente == null
                // Entra no fim da lista; a ordem so muda se alguem editar.
                ? Cartao(id: '', nome: nome, ordem: cartoes.length)
                : existente.copyWith(nome: nome),
          );

      if (membroId != null) {
        final repo = ref.read(repositorioCartoesProvider);
        if (fechamento != null) {
          await repo.definirMeuFechamento(cartaoId, membroId, fechamento);
        } else {
          await repo.removerMeuFechamento(cartaoId, membroId);
        }
        ref.invalidate(_meuFechamentoDaListaProvider(cartaoId));
      }
    } catch (e) {
      if (!context.mounted) return;
      avisarErroDeEscrita(context, e);
    }
  }

  /// Atalho da lista: define/troca/remove o MEU dia de fechamento direto,
  /// sem abrir o dialogo inteiro de editar cartao (que tambem deixa
  /// renomear). O icone de calendario na linha e so pra isto.
  Future<void> _definirFechamentoRapido(
    BuildContext context,
    WidgetRef ref,
    Cartao cartao,
  ) async {
    final membroId = ref.read(membroLogadoProvider)?.id;
    if (membroId == null) return;

    final repo = ref.read(repositorioCartoesProvider);
    final atual = await repo.meuFechamento(cartao.id, membroId);
    if (!context.mounted) return;

    final resultado = await _escolherDiaFechamento(context, atual);
    if (resultado == null) return;

    try {
      if (resultado == _semFechamento) {
        await repo.removerMeuFechamento(cartao.id, membroId);
      } else {
        await repo.definirMeuFechamento(cartao.id, membroId, resultado);
      }
      ref.invalidate(_meuFechamentoDaListaProvider(cartao.id));
    } catch (e) {
      if (!context.mounted) return;
      avisarErroDeEscrita(context, e);
    }
  }

  Future<void> _excluir(
      BuildContext context, WidgetRef ref, Cartao cartao) async {
    // Avisa em vez de bloquear por causa dos gastos: gastos antigos guardam
    // o id, e a lista passa a exibir o id cru no lugar do nome. Impedir a
    // exclusao por isso seria pior — o cartao pode ter sido de fato
    // encerrado. Ja o fechamento de outro integrante bloqueia de verdade
    // (ver removerCartao): esse aviso quem da e o servidor, via SnackBar.
    final confirmou = await confirmarExclusao(
      context: context,
      titulo: 'Excluir cartão',
      mensagem: 'Deseja excluir "${cartao.nome}"? Ele sai da lista. Os '
          'gastos já lançados nele continuam existindo, mas deixam de '
          'mostrar o nome.',
    );
    if (!confirmou) return;

    final casaId = ref.read(casaProvider).value?.id;
    if (casaId == null) return;

    try {
      await ref
          .read(repositorioGestaoCasaProvider)
          .removerCartao(casaId: casaId, cartaoId: cartao.id);
    } on ErroGestaoCasa catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    } catch (e) {
      if (!context.mounted) return;
      avisarErroDeEscrita(context, e);
    }
  }
}

class _FormularioCartao extends StatefulWidget {
  final Cartao? existente;

  /// O MEU dia de fechamento para este cartao (nunca o de outro
  /// integrante). Null quando ainda nao cadastrei nenhum, ou quando o
  /// cartao e novo.
  final int? fechamentoInicial;

  const _FormularioCartao({this.existente, this.fechamentoInicial});

  @override
  State<_FormularioCartao> createState() => _FormularioCartaoState();
}

/// Sentinela do dialogo de escolha de dia: precisa de um valor fora de
/// 1..31 para "remover o fechamento cadastrado" nao se confundir com "o
/// dialogo fechou sem escolher nada" (os dois, ao cancelar, devolveriam
/// null a partir do proprio Navigator.pop() sem argumento).
const _semFechamento = 0;

/// Grade de 1 a 31 num dialogo, em vez de digitar o numero: um dia do mes
/// nao tem ano nem mes pra escolher, so o calendario "encolhido" faz
/// sentido aqui. Compartilhado pelo formulario de editar cartao e pelo
/// atalho de calendario na lista (`_definirFechamentoRapido`).
Future<int?> _escolherDiaFechamento(BuildContext context, int? atual) {
  return showDialog<int>(
    context: context,
    builder: (dialogo) => SimpleDialog(
      title: const Text('Dia de fechamento'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: 280,
            child: GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var dia = 1; dia <= 31; dia++)
                  InkWell(
                    key: Key('dia_fechamento_$dia'),
                    onTap: () => Navigator.of(dialogo).pop(dia),
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: dia == atual
                            ? BoxDecoration(
                                color: Theme.of(dialogo).colorScheme.primary,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          '$dia',
                          style: dia == atual
                              ? TextStyle(
                                  color:
                                      Theme.of(dialogo).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (atual != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextButton(
              key: const Key('remover_fechamento'),
              onPressed: () => Navigator.of(dialogo).pop(_semFechamento),
              child: const Text('Remover dia cadastrado'),
            ),
          ),
      ],
    ),
  );
}

class _FormularioCartaoState extends State<_FormularioCartao> {
  final _chave = GlobalKey<FormState>();
  late final TextEditingController _nome;
  int? _diaFechamento;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.existente?.nome ?? '');
    _diaFechamento = widget.fechamentoInicial;
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  void _salvar() {
    if (_salvando) return;
    if (!_chave.currentState!.validate()) return;
    _salvando = true;
    Navigator.of(context).pop((_nome.text.trim(), _diaFechamento));
  }

  Future<void> _tocarCampoFechamento() async {
    final resultado = await _escolherDiaFechamento(context, _diaFechamento);
    if (resultado == null) return;
    setState(
      () => _diaFechamento = resultado == _semFechamento ? null : resultado,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _chave,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('cartao_nome'),
            controller: _nome,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: const [PrimeiraMaiuscula()],
            decoration: const InputDecoration(
              labelText: 'Nome do cartão',
              border: OutlineInputBorder(),
            ),
            validator: (t) =>
                (t == null || t.trim().isEmpty) ? 'Informe o nome.' : null,
          ),
          const SizedBox(height: 20),
          InkWell(
            key: const Key('cartao_fechamento'),
            onTap: _tocarCampoFechamento,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Meu dia de fechamento (opcional)',
                helperText: 'Só você vê este dia — o de outra pessoa da '
                    'casa fica particular dela.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(
                _diaFechamento == null ? '' : 'Dia $_diaFechamento',
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('cartao_salvar'),
            onPressed: _salvando ? null : _salvar,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
