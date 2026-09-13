import 'models/cartao.dart';
import 'models/gasto.dart';
import 'models/pote.dart';
import 'parcelas.dart';

/// Como uma lista de lancamentos e organizada.
enum OrdemGastos {
  /// Por data, agrupada por dia.
  data,

  /// Por descricao, em lista corrida. Agrupar por letra inicial seria ruido.
  alfabetica,

  /// Por pote, agrupada, na ordem de prioridade da cascata. Dentro do grupo,
  /// por data (mais recente primeiro).
  pote,

  /// Por cartao, agrupada, na ordem em que os cartoes foram cadastrados.
  /// Dentro do grupo, por data (mais recente primeiro).
  cartao,
}

/// Um bloco da lista: um cabecalho e os itens sob ele.
///
/// [titulo] vazio significa "sem cabecalho" — e o caso da ordem alfabetica,
/// que e uma lista corrida.
class Grupo<T> {
  final String titulo;
  final List<T> itens;

  const Grupo({required this.titulo, required this.itens});
}

/// Compatibilidade: a tela de Gastos ja chamava assim.
typedef GrupoGastos = Grupo<Gasto>;

/// Organiza gastos conforme [ordem]. Data do mais recente para o mais antigo:
/// um extrato se le de tras para frente.
List<Grupo<Gasto>> agruparGastos({
  required List<Gasto> gastos,
  required OrdemGastos ordem,
  required List<Pote> potes,
  List<Cartao> cartoes = const [],
}) =>
    agruparPor<Gasto>(
      itens: gastos,
      ordem: ordem,
      potes: potes,
      cartoes: cartoes,
      data: (g) => g.data,
      descricao: (g) => g.descricao,
      poteId: (g) => g.poteId,
      cartaoId: (g) => g.cartaoId,
    );

/// Organiza compras parceladas em aberto.
///
/// Data em ordem **crescente**, ao contrario dos gastos: aqui sao contas a
/// vencer, e o que interessa primeiro e a proxima, nao a mais recente.
List<Grupo<CompraParcelada>> agruparCompras({
  required List<CompraParcelada> compras,
  required OrdemGastos ordem,
  required List<Pote> potes,
  List<Cartao> cartoes = const [],
}) =>
    agruparPor<CompraParcelada>(
      itens: compras,
      ordem: ordem,
      potes: potes,
      cartoes: cartoes,
      data: (c) => c.data,
      descricao: (c) => c.descricao,
      poteId: (c) => c.poteId,
      cartaoId: (c) => c.cartaoId,
      dataDecrescente: false,
    );

/// O agrupamento de verdade, generico sobre o que esta sendo agrupado.
///
/// Gastos e compras parceladas se organizam pelas mesmas quatro regras, e os
/// acessores evitam duas copias da mesma logica se separando com o tempo.
List<Grupo<T>> agruparPor<T>({
  required List<T> itens,
  required OrdemGastos ordem,
  required List<Pote> potes,
  required List<Cartao> cartoes,
  required DateTime Function(T) data,
  required String Function(T) descricao,
  required String Function(T) poteId,
  required String? Function(T) cartaoId,
  bool dataDecrescente = true,
}) {
  if (itens.isEmpty) return const [];

  int porDescricao(T a, T b) =>
      descricao(a).toLowerCase().compareTo(descricao(b).toLowerCase());

  // Dentro de um grupo de pote ou cartao, a data manda: mais recente primeiro
  // (ou mais antiga, seguindo dataDecrescente, para manter a mesma logica das
  // Parcelas). Descricao so desempata quando a data e igual.
  int porDataEDescricao(T a, T b) {
    final cmp = data(a).compareTo(data(b));
    final porData = dataDecrescente ? -cmp : cmp;
    return porData != 0 ? porData : porDescricao(a, b);
  }

  switch (ordem) {
    case OrdemGastos.alfabetica:
      return [Grupo(titulo: '', itens: [...itens]..sort(porDescricao))];

    case OrdemGastos.data:
      final porDia = <String, List<T>>{};
      for (final item in itens) {
        porDia.putIfAbsent(_chaveDoDia(data(item)), () => []).add(item);
      }
      // A chave e "YYYY-MM-DD", que ordena como texto na mesma ordem em que
      // ordena no tempo — o mesmo truque que mesRef ja usa.
      final dias = porDia.keys.toList()
        ..sort((a, b) => dataDecrescente ? b.compareTo(a) : a.compareTo(b));
      return [
        for (final dia in dias)
          Grupo(titulo: _formatarDia(dia), itens: porDia[dia]!..sort(porDescricao)),
      ];

    case OrdemGastos.pote:
      final ordenados = [...potes]..sort((a, b) => a.ordem.compareTo(b.ordem));
      return _agruparPorChave<T>(
        itens: itens,
        chave: (item) => poteId(item),
        ids: [for (final p in ordenados) p.id],
        nomes: {for (final p in ordenados) p.id: p.nome},
        comparar: porDataEDescricao,
      );

    case OrdemGastos.cartao:
      final ordenados =
          [...cartoes]..sort((a, b) => a.ordem.compareTo(b.ordem));
      return _agruparPorChave<T>(
        itens: itens,
        chave: (item) => cartaoId(item) ?? '',
        ids: [for (final c in ordenados) c.id],
        nomes: {for (final c in ordenados) c.id: c.nome},
        comparar: porDataEDescricao,
        // O que saiu em dinheiro tem chave vazia e ganha grupo proprio, antes
        // dos orfaos: "sem cartao" e "cartao encerrado" sao coisas distintas,
        // e juntar as duas esconderia a segunda.
        tituloDaChaveVazia: 'Sem cartão',
      );
  }
}

/// Agrupa por uma chave conhecida, com dois grupos de cauda: um para a chave
/// vazia (quando [tituloDaChaveVazia] e dado) e um "Outros" para as chaves
/// que nao existem mais.
///
/// Item cuja chave aponta para um registro removido nao pode sumir da lista:
/// o lancamento existe, e escondê-lo faria o total da tela discordar do
/// total do mes.
List<Grupo<T>> _agruparPorChave<T>({
  required List<T> itens,
  required String Function(T) chave,
  required List<String> ids,
  required Map<String, String> nomes,
  required int Function(T, T) comparar,
  String? tituloDaChaveVazia,
}) {
  final porChave = <String, List<T>>{};
  final vazios = <T>[];

  for (final item in itens) {
    final k = chave(item);
    if (k.isEmpty && tituloDaChaveVazia != null) {
      vazios.add(item);
    } else {
      porChave.putIfAbsent(k, () => []).add(item);
    }
  }

  final grupos = <Grupo<T>>[];

  for (final id in ids) {
    final doGrupo = porChave.remove(id);
    if (doGrupo == null || doGrupo.isEmpty) continue;
    grupos.add(Grupo(
      titulo: nomes[id] ?? id,
      itens: doGrupo..sort(comparar),
    ));
  }

  if (vazios.isNotEmpty) {
    grupos.add(Grupo(
      titulo: tituloDaChaveVazia!,
      itens: vazios..sort(comparar),
    ));
  }

  final orfaos = [for (final lista in porChave.values) ...lista];
  if (orfaos.isNotEmpty) {
    grupos.add(Grupo(titulo: 'Outros', itens: orfaos..sort(comparar)));
  }

  return grupos;
}

String _chaveDoDia(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// "2026-08-12" -> "12/08/2026"
String _formatarDia(String chave) {
  final partes = chave.split('-');
  return '${partes[2]}/${partes[1]}/${partes[0]}';
}
