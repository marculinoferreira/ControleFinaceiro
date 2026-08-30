import 'dart:async';

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
  Future<void> criar(Casa casa);
}

abstract class RepositorioPotes {
  Stream<List<Pote>> observar();

  /// Substitui a configuracao inteira. A validacao de "soma 100%" e de
  /// "no maximo 6" acontece na UI antes de chamar.
  Future<void> salvarTodos(List<Pote> potes);

  Future<void> remover(String id);
}

abstract class RepositorioGanhos {
  Stream<List<Ganho>> observarMes(String mesRef);
  Future<void> adicionar(Ganho ganho);
  Future<void> atualizar(Ganho ganho);
  Future<void> remover(String id);
}

abstract class RepositorioGastos {
  Stream<List<Gasto>> observarMes(String mesRef);

  /// Parcelas com mesRef >= [mesRef]. Alimenta "Parcelas em aberto" e o
  /// grafico de comprometimento futuro.
  Stream<List<Gasto>> observarParceladosDesde(String mesRef);

  /// Grava a compra. Com [quantidadeParcelas] maior que 1, expande em uma
  /// gravacao atomica de N documentos.
  Future<void> adicionar({required Gasto base, required int quantidadeParcelas});

  Future<void> atualizar(Gasto gasto);
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
  Casa? _casa;
  final _controlador = StreamController<void>.broadcast();

  RepositorioCasaFake([this._casa]);

  @override
  Stream<Casa?> observar() =>
      _correnteEDepois(_controlador.stream, () => _casa);

  @override
  Future<void> criar(Casa casa) async {
    _casa = casa;
    _controlador.add(null);
  }
}
