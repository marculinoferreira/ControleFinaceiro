import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dados/repositorios.dart';
import '../dados/servico_auth.dart';
import '../dominio/cascata.dart';
import '../dominio/models/casa.dart';
import '../dominio/models/ganho.dart';
import '../dominio/models/gasto.dart';
import '../dominio/models/membro.dart';
import '../dominio/models/mes_ref.dart';
import '../dominio/models/pote.dart';
import '../dominio/parcelas.dart';
import '../dominio/totais.dart';

// --- Infraestrutura: sobrescrita em main.dart ------------------------------

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final servicoAuthProvider = Provider<ServicoAuth>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final repositorioCasaProvider = Provider<RepositorioCasa>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final repositorioPotesProvider = Provider<RepositorioPotes>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final repositorioGanhosProvider = Provider<RepositorioGanhos>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final repositorioGastosProvider = Provider<RepositorioGastos>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

// --- Sessao ---------------------------------------------------------------

final emailLogadoProvider = StreamProvider<String?>(
  (ref) => ref.watch(servicoAuthProvider).observarEmail(),
);

final casaProvider = StreamProvider<Casa?>(
  (ref) => ref.watch(repositorioCasaProvider).observar(),
);

/// Qual membro corresponde ao e-mail logado. Null quando o e-mail
/// autenticou mas nao pertence a esta casa.
final membroLogadoProvider = Provider<Membro?>((ref) {
  final email = ref.watch(emailLogadoProvider).value;
  final casa = ref.watch(casaProvider).value;
  if (email == null || casa == null) return null;
  return casa.membroPorEmail(email);
});

/// Os membros da casa, ou lista vazia enquanto a casa nao chegou. Devolver
/// vazio em vez de null poupa cada tela de um ramo de nulo — a diferenca
/// entre "carregando" e "sem membros" ja e tratada por casaProvider.
final membrosProvider = Provider<List<Membro>>((ref) {
  final casa = ref.watch(casaProvider).value;
  return casa?.membros ?? const <Membro>[];
});

// --- Mes selecionado (global, compartilhado por todas as telas) ------------

class MesNotifier extends Notifier<MesRef> {
  @override
  MesRef build() => MesRef.atual();

  void avancar(int meses) => state = state.avancar(meses);
  void irPara(MesRef mes) => state = mes;
}

final mesSelecionadoProvider =
    NotifierProvider<MesNotifier, MesRef>(MesNotifier.new);

/// Visao ativa nas telas de analise. Null significa "casal".
class VisaoNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void selecionar(String? membroId) => state = membroId;
}

final visaoProvider =
    NotifierProvider<VisaoNotifier, String?>(VisaoNotifier.new);

// --- Dados ----------------------------------------------------------------

final potesProvider = StreamProvider<List<Pote>>(
  (ref) => ref.watch(repositorioPotesProvider).observar(),
);

final ganhosDoMesProvider =
    StreamProvider.autoDispose.family<List<Ganho>, String>(
  (ref, mesRef) => ref.watch(repositorioGanhosProvider).observarMes(mesRef),
);

final gastosDoMesProvider =
    StreamProvider.autoDispose.family<List<Gasto>, String>(
  (ref, mesRef) => ref.watch(repositorioGastosProvider).observarMes(mesRef),
);

final parceladosDesdeProvider =
    StreamProvider.autoDispose.family<List<Gasto>, String>(
  (ref, mesRef) =>
      ref.watch(repositorioGastosProvider).observarParceladosDesde(mesRef),
);

// --- Derivados ------------------------------------------------------------

/// Combina dois AsyncValue preservando loading e erro.
AsyncValue<R> _combinar<A, B, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  R Function(A, B) juntar,
) {
  if (a.hasError) return AsyncValue.error(a.error!, a.stackTrace!);
  if (b.hasError) return AsyncValue.error(b.error!, b.stackTrace!);
  if (!a.hasValue || !b.hasValue) return const AsyncValue.loading();
  return AsyncValue.data(juntar(a.requireValue, b.requireValue));
}

final totaisDoMesProvider = Provider.autoDispose<AsyncValue<TotaisMes>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);

  return _combinar(
    ref.watch(ganhosDoMesProvider(mes)),
    ref.watch(gastosDoMesProvider(mes)),
    (ganhos, gastos) =>
        calcularTotais(ganhos: ganhos, gastos: gastos, membroId: membroId),
  );
});

/// Totais do casal, independentes da visao selecionada.
/// Alimenta a barra fixa de totais do mes.
final totaisDoCasalProvider =
    Provider.autoDispose<AsyncValue<TotaisMes>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;

  return _combinar(
    ref.watch(ganhosDoMesProvider(mes)),
    ref.watch(gastosDoMesProvider(mes)),
    (ganhos, gastos) => calcularTotais(ganhos: ganhos, gastos: gastos),
  );
});

final resumoCascataProvider =
    Provider.autoDispose<AsyncValue<ResultadoCascata>>((ref) {
  final potes = ref.watch(potesProvider);
  final totais = ref.watch(totaisDoMesProvider);

  return _combinar(
    potes,
    totais,
    (listaPotes, t) => calcularCascata(
      potes: listaPotes,
      totalGanhos: t.ganhos,
      totalGastos: t.gastos,
    ),
  );
});

final parcelasEmAbertoProvider =
    Provider.autoDispose<AsyncValue<List<CompraParcelada>>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider);
  return ref.watch(parceladosDesdeProvider(mes.valor)).whenData(
        (gastos) => agruparParcelasEmAberto(gastos: gastos, mesAtual: mes),
      );
});
