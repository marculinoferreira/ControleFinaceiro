import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Erro de autenticacao ja traduzido para exibicao ao usuario.
class ErroAuth implements Exception {
  final String mensagem;
  const ErroAuth(this.mensagem);

  @override
  String toString() => mensagem;
}

abstract class ServicoAuth {
  /// E-mail do usuario logado, ou null quando deslogado.
  Stream<String?> observarEmail();

  Future<void> entrar({required String email, required String senha});
  Future<void> entrarComGoogle();
  Future<void> sair();
}

class AuthFirebase implements ServicoAuth {
  final FirebaseAuth auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInicializado = false;

  AuthFirebase(this.auth);

  @override
  Stream<String?> observarEmail() =>
      auth.authStateChanges().map((u) => u?.email);

  @override
  Future<void> entrar({required String email, required String senha}) async {
    try {
      await auth.signInWithEmailAndPassword(
          email: email.trim(), password: senha);
    } on FirebaseAuthException catch (e) {
      throw ErroAuth(_traduzir(e.code));
    }
  }

  @override
  Future<void> entrarComGoogle() async {
    try {
      if (!_googleInicializado) {
        await _googleSignIn.initialize();
        _googleInicializado = true;
      }
      final conta = await _googleSignIn.authenticate();
      final idToken = conta.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      throw const ErroAuth('Nao foi possivel entrar com o Google.');
    } on FirebaseAuthException catch (e) {
      throw ErroAuth(_traduzir(e.code));
    }
  }

  @override
  Future<void> sair() async {
    await auth.signOut();
    if (_googleInicializado) await _googleSignIn.signOut();
  }

  /// Os codigos do Firebase sao em ingles e nao servem para exibir.
  static String _traduzir(String codigo) {
    switch (codigo) {
      case 'invalid-email':
        return 'E-mail em formato invalido.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'network-request-failed':
        return 'Sem conexao com a internet.';
      default:
        return 'Nao foi possivel entrar. Tente novamente.';
    }
  }
}

/// Usado nos testes de widget e para rodar a UI sem Firebase.
class AuthFake implements ServicoAuth {
  final String? erroAoEntrar;
  final Duration demora;
  final _controlador = StreamController<String?>.broadcast();

  String? _email;
  int tentativas = 0;
  String? ultimoEmail;

  AuthFake({this.erroAoEntrar, this.demora = Duration.zero});

  /// Stream.multi, e nao `async*`: o gerador so assinaria o controlador
  /// broadcast depois que o primeiro valor fosse consumido, e um login
  /// nessa janela seria descartado — o roteamento por estado de auth
  /// deixaria o usuario preso na tela de login. Ver a mesma nota em
  /// dados/repositorios.dart.
  @override
  Stream<String?> observarEmail() => Stream.multi((assinante) {
        assinante.add(_email);
        final assinatura = _controlador.stream.listen(assinante.add);
        assinante.onCancel = assinatura.cancel;
      });

  @override
  Future<void> entrar({required String email, required String senha}) async {
    tentativas++;
    ultimoEmail = email;
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (erroAoEntrar != null) throw ErroAuth(erroAoEntrar!);
    _email = email;
    _controlador.add(email);
  }

  /// E-mail simulado devolvido por [entrarComGoogle] nos testes.
  String? emailGoogleSimulado;

  @override
  Future<void> entrarComGoogle() async {
    tentativas++;
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (erroAoEntrar != null) throw ErroAuth(erroAoEntrar!);
    final email = emailGoogleSimulado ?? 'google@teste.com';
    ultimoEmail = email;
    _email = email;
    _controlador.add(email);
  }

  @override
  Future<void> sair() async {
    _email = null;
    _controlador.add(null);
  }
}
