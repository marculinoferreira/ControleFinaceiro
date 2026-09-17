import 'dart:async';

import '../dominio/models/cartao.dart';
import '../dominio/models/casa.dart';
import '../dominio/models/ganho.dart';
import '../dominio/models/gasto.dart';
import '../dominio/models/mes_ref.dart';
import '../dominio/models/pote.dart';
import '../dominio/parcelas.dart';

/// O que fazer ao excluir uma parcela de uma compra parcelada.
enum ModoExclusao { somenteEsta, estaEFuturas, todas }

abstract class RepositorioCasa {
  Stream<Casa?> observar();
}

abstract class RepositorioPotes {
  Stream<List<Pote>> observar();

  /// Substitui a configuracao inteira. A validacao de "soma 100%" e de
  /// "no maximo 6" acontece na UI antes de chamar.
  Future<void> salvarTodos(List<Pote> potes);

  Future<void> remover(String id);
}

abstract class RepositorioCartoes {
  Stream<List<Cartao>> observar();

  /// Cria quando o id vem vazio, atualiza quando vem preenchido. Devolve o
  /// id do cartao (o novo, ou o mesmo de quem editou) -- quem acabou de
  /// criar um cartao precisa dele na hora pra gravar o proprio fechamento
  /// em seguida.
  Future<String> salvar(Cartao cartao);

  // A exclusao nao mora aqui: remover um cartao pode esbarrar no fechamento
  // de outro integrante, algo que so o servidor consegue ver -- ver
  // RepositorioGestaoCasa.removerCartao.

  /// O dia de fechamento que [membroId] cadastrou para este cartao agora, ou
  /// null se ele nao cadastrou nenhum. Leitura unica (nao um stream): quem
  /// usa isto e a tela de edicao, pra pre-preencher o campo uma vez ao
  /// abrir -- nao precisa ficar observando ao vivo. Cada pessoa so consegue
  /// ler e gravar o proprio -- e reforcado pela regra do Firestore, nao so
  /// pela UI.
  Future<int?> meuFechamento(String cartaoId, String membroId);

  Future<void> definirMeuFechamento(String cartaoId, String membroId, int dia);

  Future<void> removerMeuFechamento(String cartaoId, String membroId);
}

abstract class RepositorioGanhos {
  Stream<List<Ganho>> observarMes(String mesRef);

  /// Lancamentos com mesRef entre [inicio] e [fim], ambos inclusive.
  /// Alimenta a serie mensal dos graficos de evolucao.
  ///
  /// Uma query de intervalo, e nao N assinaturas de observarMes: "YYYY-MM"
  /// ordena lexicograficamente na mesma ordem em que ordena
  /// cronologicamente, entao a comparacao de strings basta e nao custa um
  /// indice composto novo.
  Stream<List<Ganho>> observarIntervalo(String inicio, String fim);
  Future<void> adicionar(Ganho ganho);
  Future<void> atualizar(Ganho ganho);
  Future<void> remover(String id);
}

abstract class RepositorioGastos {
  Stream<List<Gasto>> observarMes(String mesRef);

  /// Lancamentos com mesRef entre [inicio] e [fim], ambos inclusive.
  /// Cada parcela conta no mes em que cai, nao no mes da compra.
  Stream<List<Gasto>> observarIntervalo(String inicio, String fim);

  /// Parcelas com mesRef >= [mesRef]. Alimenta "Parcelas em aberto" e o
  /// grafico de comprometimento futuro.
  Stream<List<Gasto>> observarParceladosDesde(String mesRef);

  /// Grava a compra. Com [quantidadeParcelas] maior que 1, expande em uma
  /// gravacao atomica de N documentos.
  Future<void> adicionar({required Gasto base, required int quantidadeParcelas});

  Future<void> atualizar(Gasto gasto);

  /// Edita uma parcela alcancando a compra conforme [alcance], e ajusta o
  /// tamanho da compra para [novaQuantidade] criando parcelas no fim ou
  /// apagando as ultimas. Tudo em uma escrita atomica.
  ///
  /// A decisao de o que escrever e de `planejarEdicaoCompra`; aqui so se
  /// executa o plano.
  Future<void> atualizarCompra({
    required Gasto editado,
    required ModoEdicao alcance,
    required int novaQuantidade,
  });

  Future<void> removerUma(String id);
  Future<void> removerDesta(String compraId, int parcela);
  Future<void> removerCompra(String compraId);
}

// ---------------------------------------------------------------------------
// Fakes em memoria. Vivem em lib/ (nao em test/) porque os testes de widget
// das proximas tarefas tambem os injetam.
// ---------------------------------------------------------------------------

/// Valor corrente seguido das atualizacoes.
///
/// Precisa ser Stream.multi, e nao um `async*` com `yield` + `yield*`: o
/// gerador so assina [atualizacoes] depois que o primeiro valor cedido e
/// consumido e, como os controladores aqui sao broadcast (nao bufferizam),
/// toda escrita nessa janela seria perdida em silencio. Stream.multi roda
/// este corpo sincronamente dentro do listen(), entao a assinatura ja existe
/// quando quem chama escreve.
Stream<T> _correnteEDepois<T>(Stream<void> atualizacoes, T Function() ler) =>
    Stream.multi((assinante) {
      assinante.add(ler());
      final assinatura = atualizacoes.listen((_) => assinante.add(ler()));
      assinante.onCancel = assinatura.cancel;
    });

/// Comparacao de janela nos fakes. Igual a do Firestore: "YYYY-MM" ordena
/// como texto na mesma ordem em que ordena no tempo, extremos inclusive.
bool _dentro(String mesRef, String inicio, String fim) =>
    mesRef.compareTo(inicio) >= 0 && mesRef.compareTo(fim) <= 0;

class RepositorioGastosFake implements RepositorioGastos {
  final List<Gasto> _gastos = [];
  final _controlador = StreamController<void>.broadcast();
  var _sequencia = 0;

  List<Gasto> get todos => List.unmodifiable(_gastos);

  void _emitir() => _controlador.add(null);

  @override
  Stream<List<Gasto>> observarMes(String mesRef) => _correnteEDepois(
        _controlador.stream,
        () => _gastos.where((g) => g.mesRef == mesRef).toList(),
      );

  @override
  Stream<List<Gasto>> observarParceladosDesde(String mesRef) =>
      _correnteEDepois(
        _controlador.stream,
        () => _gastos
            .where((g) =>
                g.parcelado &&
                MesRef.parse(g.mesRef).compareTo(MesRef.parse(mesRef)) >= 0)
            .toList(),
      );

  @override
  Stream<List<Gasto>> observarIntervalo(String inicio, String fim) =>
      _correnteEDepois(
        _controlador.stream,
        () => _gastos.where((g) => _dentro(g.mesRef, inicio, fim)).toList(),
      );

  @override
  Future<void> adicionar({
    required Gasto base,
    required int quantidadeParcelas,
  }) async {
    final compraId = 'compra-${_sequencia++}';
    final novas = gerarParcelas(
      base: base,
      quantidade: quantidadeParcelas,
      compraId: compraId,
    );
    for (final g in novas) {
      _gastos.add(g.copyWith(id: 'gasto-${_sequencia++}'));
    }
    _emitir();
  }

  @override
  Future<void> atualizar(Gasto gasto) async {
    final i = _gastos.indexWhere((g) => g.id == gasto.id);
    if (i >= 0) _gastos[i] = gasto;
    _emitir();
  }

  @override
  Future<void> atualizarCompra({
    required Gasto editado,
    required ModoEdicao alcance,
    required int novaQuantidade,
  }) async {
    final plano = planejarEdicaoCompra(
      existentes: _gastos,
      editado: editado,
      alcance: alcance,
      novaQuantidade: novaQuantidade,
    );

    for (final g in plano.atualizar) {
      final i = _gastos.indexWhere((x) => x.id == g.id);
      if (i >= 0) _gastos[i] = g;
    }
    _gastos.removeWhere((g) => plano.remover.contains(g.id));
    for (final g in plano.criar) {
      _gastos.add(g.copyWith(id: 'gasto-${_sequencia++}'));
    }
    _emitir();
  }

  @override
  Future<void> removerUma(String id) async {
    _gastos.removeWhere((g) => g.id == id);
    _emitir();
  }

  @override
  Future<void> removerDesta(String compraId, int parcela) async {
    _gastos.removeWhere(
        (g) => g.compraId == compraId && (g.parcela ?? 0) >= parcela);
    _emitir();
  }

  @override
  Future<void> removerCompra(String compraId) async {
    _gastos.removeWhere((g) => g.compraId == compraId);
    _emitir();
  }
}

class RepositorioGanhosFake implements RepositorioGanhos {
  final List<Ganho> _ganhos = [];
  final _controlador = StreamController<void>.broadcast();
  var _sequencia = 0;

  List<Ganho> get todos => List.unmodifiable(_ganhos);

  void _emitir() => _controlador.add(null);

  @override
  Stream<List<Ganho>> observarMes(String mesRef) => _correnteEDepois(
        _controlador.stream,
        () => _ganhos.where((g) => g.mesRef == mesRef).toList(),
      );

  @override
  Stream<List<Ganho>> observarIntervalo(String inicio, String fim) =>
      _correnteEDepois(
        _controlador.stream,
        () => _ganhos.where((g) => _dentro(g.mesRef, inicio, fim)).toList(),
      );

  @override
  Future<void> adicionar(Ganho ganho) async {
    _ganhos.add(ganho.copyWith(id: 'ganho-${_sequencia++}'));
    _emitir();
  }

  @override
  Future<void> atualizar(Ganho ganho) async {
    final i = _ganhos.indexWhere((g) => g.id == ganho.id);
    if (i >= 0) _ganhos[i] = ganho;
    _emitir();
  }

  @override
  Future<void> remover(String id) async {
    _ganhos.removeWhere((g) => g.id == id);
    _emitir();
  }
}

class RepositorioCartoesFake implements RepositorioCartoes {
  final List<Cartao> _cartoes = [];
  final _controlador = StreamController<void>.broadcast();
  var _sequencia = 0;

  // cartaoId -> membroId -> dia. Espelha a subcolecao fechamentos do
  // Firestore: cada par cartao+membro e uma entrada isolada.
  final Map<String, Map<String, int>> _fechamentos = {};

  RepositorioCartoesFake([List<Cartao> iniciais = const []]) {
    _cartoes.addAll(iniciais);
  }

  List<Cartao> get todos => List.unmodifiable(_cartoes);

  /// So pra teste inspecionar o que foi gravado, sem depender do stream.
  int? fechamentoDe(String cartaoId, String membroId) =>
      _fechamentos[cartaoId]?[membroId];

  @override
  Stream<List<Cartao>> observar() => _correnteEDepois(
        _controlador.stream,
        () => [..._cartoes]..sort((a, b) => a.ordem.compareTo(b.ordem)),
      );

  @override
  Future<String> salvar(Cartao cartao) async {
    final String id;
    if (cartao.id.isEmpty) {
      id = 'cartao-${_sequencia++}';
      _cartoes.add(cartao.copyWith(id: id));
    } else {
      id = cartao.id;
      final i = _cartoes.indexWhere((c) => c.id == id);
      if (i >= 0) _cartoes[i] = cartao;
    }
    _controlador.add(null);
    return id;
  }

  @override
  Future<int?> meuFechamento(String cartaoId, String membroId) async =>
      _fechamentos[cartaoId]?[membroId];

  @override
  Future<void> definirMeuFechamento(
      String cartaoId, String membroId, int dia) async {
    (_fechamentos[cartaoId] ??= {})[membroId] = dia;
  }

  @override
  Future<void> removerMeuFechamento(String cartaoId, String membroId) async {
    _fechamentos[cartaoId]?.remove(membroId);
  }
}

class RepositorioPotesFake implements RepositorioPotes {
  List<Pote> _potes = [];
  final _controlador = StreamController<void>.broadcast();

  RepositorioPotesFake([List<Pote> iniciais = const []]) {
    _potes = [...iniciais];
  }

  List<Pote> get todos => List.unmodifiable(_potes);

  @override
  Stream<List<Pote>> observar() =>
      _correnteEDepois(_controlador.stream, () => List<Pote>.unmodifiable(_potes));

  @override
  Future<void> salvarTodos(List<Pote> potes) async {
    _potes = [...potes];
    _controlador.add(null);
  }

  @override
  Future<void> remover(String id) async {
    _potes.removeWhere((p) => p.id == id);
    _controlador.add(null);
  }
}

class RepositorioCasaFake implements RepositorioCasa {
  final Casa? _casa;
  final _controlador = StreamController<void>.broadcast();

  RepositorioCasaFake([this._casa]);

  @override
  Stream<Casa?> observar() =>
      _correnteEDepois(_controlador.stream, () => _casa);
}
