import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dados/repositorio_firestore.dart';
import 'dados/repositorios.dart';
import 'dados/semeadura.dart';
import 'dados/servico_auth.dart';
import 'estado/providers.dart';
import 'firebase_options.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final db = FirebaseFirestore.instance;

  // Cache offline so no Android e iOS. No Windows o cloud_firestore nao
  // oferece persistencia em disco equivalente; sem internet o app abre mas
  // nao carrega dados, e a tela de erro informa isso.
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    db.settings = const Settings(persistenceEnabled: true);
  }

  final repoCasa = CasaFirestore(db);
  final repoPotes = PotesFirestore(db);
  final repoCartoes = CartoesFirestore(db);

  runApp(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        servicoAuthProvider
            .overrideWithValue(AuthFirebase(FirebaseAuth.instance)),
        repositorioCasaProvider.overrideWithValue(repoCasa),
        repositorioPotesProvider.overrideWithValue(repoPotes),
        repositorioCartoesProvider.overrideWithValue(repoCartoes),
        repositorioGanhosProvider.overrideWithValue(GanhosFirestore(db)),
        repositorioGastosProvider.overrideWithValue(GastosFirestore(db)),
      ],
      child: _SemearAoLogar(
        casa: repoCasa,
        potes: repoPotes,
        cartoes: repoCartoes,
        child: const App(),
      ),
    ),
  );
}

/// A semeadura roda depois do login, nao no boot: as regras do Firestore
/// negam leitura e escrita para quem nao esta autenticado.
class _SemearAoLogar extends ConsumerStatefulWidget {
  final RepositorioCasa casa;
  final RepositorioPotes potes;
  final RepositorioCartoes cartoes;
  final Widget child;

  const _SemearAoLogar({
    required this.casa,
    required this.potes,
    required this.cartoes,
    required this.child,
  });

  @override
  ConsumerState<_SemearAoLogar> createState() => _SemearAoLogarState();
}

class _SemearAoLogarState extends ConsumerState<_SemearAoLogar> {
  bool _semeado = false;

  @override
  Widget build(BuildContext context) {
    // `value`, e nao `valueOrNull`: o getter foi removido no Riverpod 3.
    ref.listen(emailLogadoProvider, (_, proximo) async {
      final email = proximo.value;
      if (email == null) {
        _semeado = false;
        return;
      }
      if (_semeado) return;
      _semeado = true;
      await semear(
        casa: widget.casa,
        potes: widget.potes,
        cartoes: widget.cartoes,
      );
    });

    return widget.child;
  }
}
