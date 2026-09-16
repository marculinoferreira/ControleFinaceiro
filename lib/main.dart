import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  db.settings = const Settings(persistenceEnabled: true);

  runApp(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        servicoAuthProvider
            .overrideWithValue(AuthFirebase(FirebaseAuth.instance)),
        funcoesProvider.overrideWithValue(FirebaseFunctions.instance),
      ],
      child: const App(),
    ),
  );
}
