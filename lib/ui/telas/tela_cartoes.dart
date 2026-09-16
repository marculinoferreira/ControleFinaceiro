import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dados/repositorio_gestao_casa.dart';
import '../../dominio/models/cartao.dart';
import '../../estado/providers.dart';
import '../widgets/dialogo_exclusao.dart';
import '../widgets/estados_async.dart';
import '../widgets/formulario_responsivo.dart';
import '../widgets/primeira_maiuscula.dart';
import '../widgets/tabela_responsiva.dart';

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
                    aoTocar: () => _abrir(context, ref, existente: c),
                    aoExcluir: () => _excluir(context, ref, c),
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

    // So busca o vencimento de quem esta editando um cartao que ja existe;
    // um cartao novo nunca tem vencimento de ninguem ainda.
    int? vencimentoAtual;
    if (existente != null && membroId != null) {
      vencimentoAtual = await ref
          .read(repositorioCartoesProvider)
          .meuVencimento(existente.id, membroId);
    }
    if (!context.mounted) return;

    final resultado = await mostrarFormulario<(String, int?)>(
      context: context,
      titulo: existente == null ? 'Novo cartão' : 'Editar cartão',
      construir: (c) => _FormularioCartao(
        existente: existente,
        vencimentoInicial: vencimentoAtual,
      ),
    );
    if (resultado == null) return;
    final (nome, vencimento) = resultado;

    try {
      final cartaoId = await ref.read(repositorioCartoesProvider).salvar(
            existente == null
                // Entra no fim da lista; a ordem so muda se alguem editar.
                ? Cartao(id: '', nome: nome, ordem: cartoes.length)
                : existente.copyWith(nome: nome),
          );

      if (membroId != null) {
        final repo = ref.read(repositorioCartoesProvider);
        if (vencimento != null) {
          await repo.definirMeuVencimento(cartaoId, membroId, vencimento);
        } else {
          await repo.removerMeuVencimento(cartaoId, membroId);
        }
      }
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
    // encerrado. Ja o vencimento de outro integrante bloqueia de verdade
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

  /// O MEU dia de vencimento para este cartao (nunca o de outro
  /// integrante). Null quando ainda nao cadastrei nenhum, ou quando o
  /// cartao e novo.
  final int? vencimentoInicial;

  const _FormularioCartao({this.existente, this.vencimentoInicial});

  @override
  State<_FormularioCartao> createState() => _FormularioCartaoState();
}

class _FormularioCartaoState extends State<_FormularioCartao> {
  final _chave = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _vencimento;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.existente?.nome ?? '');
    _vencimento = TextEditingController(
      text: widget.vencimentoInicial?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nome.dispose();
    _vencimento.dispose();
    super.dispose();
  }

  void _salvar() {
    if (_salvando) return;
    if (!_chave.currentState!.validate()) return;
    _salvando = true;
    final texto = _vencimento.text.trim();
    final dia = texto.isEmpty ? null : int.parse(texto);
    Navigator.of(context).pop((_nome.text.trim(), dia));
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
          TextFormField(
            key: const Key('cartao_vencimento'),
            controller: _vencimento,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Meu dia de vencimento (opcional)',
              helperText: 'Só você vê este dia — o de outra pessoa da casa '
                  'fica particular dela.',
              helperMaxLines: 2,
              border: OutlineInputBorder(),
            ),
            validator: (t) {
              if (t == null || t.trim().isEmpty) return null;
              final dia = int.tryParse(t.trim());
              if (dia == null || dia < 1 || dia > 31) {
                return 'Informe um dia entre 1 e 31.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _salvar(),
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
