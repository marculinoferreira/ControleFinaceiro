import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dominio/cascata.dart' show toleranciaCentavo;
import '../../dominio/models/pote.dart';
import '../../estado/providers.dart';
import '../tema/formatadores.dart';
import '../tema/tema.dart';
import '../widgets/estados_async.dart';

const int maximoPotes = 6;

/// Cores oferecidas a potes novos, na ordem. Sao as mesmas da semeadura,
/// para que a paleta do app permaneca coerente nos graficos.
const List<String> _paleta = [
  '#2E7D32', '#1565C0', '#00838F', '#EF6C00', '#AD1457', '#4527A0',
];

/// A soma fecha? Comparacao com tolerancia, nunca com == em double.
bool somaFechada(double soma) => (soma - 100).abs() <= toleranciaCentavo;

/// "100%", "97% — faltam 3%" ou "103% — 3% a mais".
String rotuloSoma(double soma) {
  if (somaFechada(soma)) return '100%';
  if (soma < 100) {
    return '${formatarPercentual(soma)} — faltam '
        '${formatarPercentual(100 - soma)}';
  }
  return '${formatarPercentual(soma)} — '
      '${formatarPercentual(soma - 100)} a mais';
}

class TelaPotes extends ConsumerStatefulWidget {
  const TelaPotes({super.key});

  @override
  ConsumerState<TelaPotes> createState() => _TelaPotesState();
}

class _TelaPotesState extends ConsumerState<TelaPotes> {
  /// Rascunho local. Null enquanto os potes gravados nao chegaram.
  /// Editar direto no stream publicaria estados com soma != 100%, que a
  /// cascata leria como configuracao real.
  List<Pote>? _rascunho;
  final _controladores = <int, TextEditingController>{};
  final _controladoresNome = <int, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _controladores.values) {
      c.dispose();
    }
    for (final c in _controladoresNome.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controlador(int indice, double percentual) {
    return _controladores.putIfAbsent(
      indice,
      () => TextEditingController(text: percentual.toStringAsFixed(0)),
    );
  }

  // Mesma razao do controlador de percentual: com Key('pote_$i') sendo
  // posicional, o Element de uma linha e reaproveitado apos reordenar ou
  // remover, e TextFormField.didUpdateWidget so re-semeia o texto quando a
  // referencia do controller muda — initialValue sozinho fica obsoleto.
  TextEditingController _controladorNome(int indice, String nome) {
    return _controladoresNome.putIfAbsent(
      indice,
      () => TextEditingController(text: nome),
    );
  }

  void _resincronizarControladores() {
    for (final c in _controladores.values) {
      c.dispose();
    }
    _controladores.clear();
    for (final c in _controladoresNome.values) {
      c.dispose();
    }
    _controladoresNome.clear();
  }

  double get _soma =>
      (_rascunho ?? const []).fold<double>(0, (a, p) => a + p.percentual);

  @override
  Widget build(BuildContext context) {
    final potes = ref.watch(potesProvider);

    return Scaffold(
      body: potes.when(
        loading: () => const CarregandoLista(linhas: 6),
        error: (e, _) => ErroComRecarregar(
          erro: e,
          aoRecarregar: () => ref.invalidate(potesProvider),
        ),
        data: (gravados) {
          _rascunho ??= [...gravados];
          return _conteudo(context);
        },
      ),
    );
  }

  Widget _conteudo(BuildContext context) {
    final rascunho = _rascunho!;
    final fecha = somaFechada(_soma);

    return Column(
      children: [
        Expanded(
          child: ReorderableListView(
            key: const Key('lista_potes'),
            padding: const EdgeInsets.all(8),
            onReorder: (de, para) => setState(() {
              // O indice de destino vem deslocado quando se arrasta para
              // baixo, porque o item ainda ocupa a posicao de origem.
              final destino = para > de ? para - 1 : para;
              final movido = rascunho.removeAt(de);
              rascunho.insert(destino, movido);
              _resincronizarControladores();
            }),
            children: [
              for (var i = 0; i < rascunho.length; i++)
                _linha(context, i, rascunho[i]),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                key: const Key('adicionar_pote'),
                onPressed:
                    rascunho.length >= maximoPotes ? null : _adicionarPote,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar pote'),
              ),
              const Spacer(),
              Container(
                key: const Key('soma_potes'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  rotuloSoma(_soma),
                  style:
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: fecha
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const Key('salvar_potes'),
                onPressed: fecha ? _salvar : null,
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _linha(BuildContext context, int i, Pote pote) {
    return Card(
      key: Key('pote_$i'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: i,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_handle),
              ),
            ),
            CircleAvatar(radius: 10, backgroundColor: corDeHex(pote.cor)),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: Key('nome_$i'),
                controller: _controladorNome(i, pote.nome),
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(
                  () => _rascunho![i] = _rascunho![i].copyWith(nome: v),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: TextFormField(
                key: Key('percentual_$i'),
                controller: _controlador(i, pote.percentual),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  suffixText: '%',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(
                  () => _rascunho![i] = _rascunho![i].copyWith(
                    percentual: double.tryParse(v) ?? 0,
                  ),
                ),
              ),
            ),
            IconButton(
              key: Key('remover_$i'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remover pote',
              onPressed: () => setState(() {
                _rascunho!.removeAt(i);
                _resincronizarControladores();
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _adicionarPote() {
    setState(() {
      final i = _rascunho!.length;
      _rascunho!.add(Pote(
        id: '', // o repositorio Firestore atribui o id no salvarTodos
        nome: 'Novo pote',
        percentual: 0,
        ordem: i,
        cor: _paleta[i % _paleta.length],
        icone: 'casa',
      ));
    });
  }

  Future<void> _salvar() async {
    // A posicao na lista e a prioridade da cascata: normaliza a ordem
    // antes de gravar, para nao depender do que veio do banco.
    final normalizados = <Pote>[
      for (var i = 0; i < _rascunho!.length; i++)
        _rascunho![i].copyWith(ordem: i),
    ];
    await ref.read(repositorioPotesProvider).salvarTodos(normalizados);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Potes salvos.')),
    );
  }
}
