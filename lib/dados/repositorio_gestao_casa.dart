import 'package:cloud_functions/cloud_functions.dart';

/// Erro de gestao de casa ja traduzido para exibicao ao usuario — a
/// mensagem vem direto da Cloud Function (ver functions/src/erros.ts).
class ErroGestaoCasa implements Exception {
  final String mensagem;
  const ErroGestaoCasa(this.mensagem);

  @override
  String toString() => mensagem;
}

/// Operacoes de gestao de casa que passam por Cloud Functions, nunca por
/// escrita direta do Firestore (spec de 2026-09-14 §2 decisao 6).
abstract class RepositorioGestaoCasa {
  /// O casaId da pessoa logada, ou null se ela ainda nao tem casa.
  Future<String?> minhaCasa();

  /// Cria a casa e devolve o casaId novo. [nomeMembro] e o nome ou apelido
  /// de quem esta criando, usado como o nome dela dentro da casa.
  Future<String> criarCasa(String nome, {required String nomeMembro});

  Future<void> convidarMembro({
    required String casaId,
    required String email,
    required String nome,
  });

  Future<void> removerMembro({
    required String casaId,
    required String membroId,
  });

  Future<void> transferirPosse({
    required String casaId,
    required String novoDonoMembroId,
  });

  Future<void> sairDaCasa({required String casaId});
  Future<void> excluirCasa({required String casaId});
}

class RepositorioGestaoCasaFunctions implements RepositorioGestaoCasa {
  final FirebaseFunctions funcoes;
  RepositorioGestaoCasaFunctions(this.funcoes);

  Future<T> _chamar<T>(
    String nome,
    Map<String, dynamic> dados,
    T Function(dynamic) ler,
  ) async {
    try {
      final resultado = await funcoes.httpsCallable(nome).call(dados);
      return ler(resultado.data);
    } on FirebaseFunctionsException catch (e) {
      throw ErroGestaoCasa(
        e.message ?? 'Não foi possível completar a operação.',
      );
    }
  }

  @override
  Future<String?> minhaCasa() =>
      _chamar('minhaCasa', const {}, (d) => d['casaId'] as String?);

  @override
  Future<String> criarCasa(String nome, {required String nomeMembro}) =>
      _chamar(
        'criarCasa',
        {'nome': nome, 'nomeMembro': nomeMembro},
        (d) => d['casaId'] as String,
      );

  @override
  Future<void> convidarMembro({
    required String casaId,
    required String email,
    required String nome,
  }) =>
      _chamar(
        'convidarMembro',
        {'casaId': casaId, 'email': email, 'nome': nome},
        (_) {},
      );

  @override
  Future<void> removerMembro({
    required String casaId,
    required String membroId,
  }) =>
      _chamar(
        'removerMembro',
        {'casaId': casaId, 'membroId': membroId},
        (_) {},
      );

  @override
  Future<void> transferirPosse({
    required String casaId,
    required String novoDonoMembroId,
  }) =>
      _chamar(
        'transferirPosse',
        {'casaId': casaId, 'membroId': novoDonoMembroId},
        (_) {},
      );

  @override
  Future<void> sairDaCasa({required String casaId}) =>
      _chamar('sairDaCasa', {'casaId': casaId}, (_) {});

  @override
  Future<void> excluirCasa({required String casaId}) =>
      _chamar('excluirCasa', {'casaId': casaId}, (_) {});
}

/// Usado nos testes de widget e para rodar a UI sem Cloud Functions.
class RepositorioGestaoCasaFake implements RepositorioGestaoCasa {
  String? casaIdAtual;
  String? erro;
  var _sequencia = 0;
  final List<String> chamadas = [];

  @override
  Future<String?> minhaCasa() async => casaIdAtual;

  @override
  Future<String> criarCasa(String nome, {required String nomeMembro}) async {
    chamadas.add('criarCasa:$nome:$nomeMembro');
    if (erro != null) throw ErroGestaoCasa(erro!);
    casaIdAtual = 'casa-fake-${_sequencia++}';
    return casaIdAtual!;
  }

  @override
  Future<void> convidarMembro({
    required String casaId,
    required String email,
    required String nome,
  }) async {
    chamadas.add('convidarMembro:$email');
    if (erro != null) throw ErroGestaoCasa(erro!);
  }

  @override
  Future<void> removerMembro({
    required String casaId,
    required String membroId,
  }) async {
    chamadas.add('removerMembro:$membroId');
    if (erro != null) throw ErroGestaoCasa(erro!);
  }

  @override
  Future<void> transferirPosse({
    required String casaId,
    required String novoDonoMembroId,
  }) async {
    chamadas.add('transferirPosse:$novoDonoMembroId');
    if (erro != null) throw ErroGestaoCasa(erro!);
  }

  @override
  Future<void> sairDaCasa({required String casaId}) async {
    chamadas.add('sairDaCasa');
    if (erro != null) throw ErroGestaoCasa(erro!);
    // Espelha o efeito real: sair apaga o indiceEmail da pessoa, entao a
    // proxima minhaCasa() dela devolve null.
    casaIdAtual = null;
  }

  @override
  Future<void> excluirCasa({required String casaId}) async {
    chamadas.add('excluirCasa');
    if (erro != null) throw ErroGestaoCasa(erro!);
    // Mesmo raciocinio de sairDaCasa: a casa (e o indice do dono) some.
    casaIdAtual = null;
  }
}
