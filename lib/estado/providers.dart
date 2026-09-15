import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dados/repositorio_firestore.dart';
import '../dados/repositorio_gestao_casa.dart';
import '../dados/repositorios.dart';
import '../dados/servico_auth.dart';
import '../dominio/cascata.dart';
import '../dominio/graficos.dart';
import '../dominio/models/cartao.dart';
import '../dominio/models/casa.dart';
import '../dominio/models/ganho.dart';
import '../dominio/models/gasto.dart';
import '../dominio/models/membro.dart';
import '../dominio/models/mes_ref.dart';
import '../dominio/models/pote.dart';
import '../dominio/ordem_gastos.dart';
import '../dominio/parcelas.dart';
import '../dominio/serie_mensal.dart';
import '../dominio/totais.dart';

// --- Infraestrutura: sobrescrita em main.dart ------------------------------

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final servicoAuthProvider = Provider<ServicoAuth>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final funcoesProvider = Provider<FirebaseFunctions>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final repositorioGestaoCasaProvider = Provider<RepositorioGestaoCasa>(
  (ref) => RepositorioGestaoCasaFunctions(ref.watch(funcoesProvider)),
);

/// O casaId da pessoa logada, resolvido pela Cloud Function `minhaCasa`.
/// Null quando ainda nao tem casa (mostra a tela de criar casa) ou quando
/// nao ha ninguem logado.
final casaIdProvider = FutureProvider<String?>((ref) async {
  final email = ref.watch(emailLogadoProvider).value;
  if (email == null) return null;
  return ref.watch(repositorioGestaoCasaProvider).minhaCasa();
});

/// Os providers abaixo só são lidos depois que a tela de roteamento
/// (Task 13) já confirmou que `casaIdProvider` tem um valor não nulo.
String _casaIdResolvido(Ref ref) => ref.watch(casaIdProvider).value!;

final repositorioCasaProvider = Provider<RepositorioCasa>((ref) =>
    CasaFirestore(ref.watch(firestoreProvider), _casaIdResolvido(ref)));

final repositorioPotesProvider = Provider<RepositorioPotes>((ref) =>
    PotesFirestore(ref.watch(firestoreProvider), _casaIdResolvido(ref)));

final repositorioCartoesProvider = Provider<RepositorioCartoes>((ref) =>
    CartoesFirestore(ref.watch(firestoreProvider), _casaIdResolvido(ref)));

final repositorioGanhosProvider = Provider<RepositorioGanhos>((ref) =>
    GanhosFirestore(ref.watch(firestoreProvider), _casaIdResolvido(ref)));

final repositorioGastosProvider = Provider<RepositorioGastos>((ref) =>
    GastosFirestore(ref.watch(firestoreProvider), _casaIdResolvido(ref)));

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

/// Os membros ainda ativos (sem `removidoEm`) — para os seletores de "de
/// quem e este lancamento NOVO".
final membrosAtivosProvider = Provider<List<Membro>>((ref) {
  final membros = ref.watch(membrosProvider);
  return membros.where((m) => m.removidoEm == null).toList();
});

/// Os ids de membro com pelo menos um gasto ou ganho no mes selecionado.
final _membroIdsComHistoricoNoMesProvider = Provider<Set<String>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final gastos = ref.watch(gastosDoMesProvider(mes)).value ?? const [];
  final ganhos = ref.watch(ganhosDoMesProvider(mes)).value ?? const [];
  return {
    for (final g in gastos) g.membroId,
    for (final g in ganhos) g.membroId,
  };
});

/// Membros a oferecer nos seletores de VISUALIZACAO (colunas de Ganhos,
/// linhas de Gastos, o filtro "Pessoa", o seletor de Resumo/Graficos):
/// todos os ativos, mais os removidos que ainda tem lancamento no mes
/// selecionado — um removido com historico continua consultavel, mas um
/// removido sem nada lancado (ex: saiu no mesmo dia que entrou) nao fica
/// como uma aba/coluna vazia para sempre.
///
/// Diferente de `membrosAtivosProvider`: aquele e para "de quem e este
/// lancamento NOVO" e nunca inclui removidos, nem com historico.
final membrosParaVisaoProvider = Provider<List<Membro>>((ref) {
  final membros = ref.watch(membrosProvider);
  final comHistorico = ref.watch(_membroIdsComHistoricoNoMesProvider);
  return membros
      .where((m) => m.removidoEm == null || comHistorico.contains(m.id))
      .toList();
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

/// De quem sao os numeros que o app esta mostrando. Null significa "casal":
/// sem filtro de pessoa.
///
/// E um so para o app inteiro de proposito. O seletor do Resumo e dos
/// Graficos e o dropdown "Pessoa" de Gastos e Parcelas fazem a mesma
/// pergunta, entao respondem do mesmo lugar: escolher "Silvia" no Resumo
/// deixa Gastos e Parcelas em Silvia ao trocar de aba, que e o que se espera
/// de quem esta acompanhando os numeros de uma pessoa.
///
/// Comeca em quem esta logado: ao abrir o app a pessoa quase sempre quer ver
/// os proprios numeros primeiro, e o do outro ou o do casal fica a um toque.
///
/// A semente e aplicada duas vezes de proposito. O `read` cobre o caso de o
/// membro logado ja estar em maos quando esta visao e lida pela primeira vez
/// (trocar de aba depois do app aberto); o `listen` cobre o caso normal do
/// arranque, em que auth e casa ainda estao a caminho e o membro so chega
/// depois do primeiro build. O `_escolhido` impede que essa chegada tardia
/// desfaca uma troca manual — inclusive uma troca para "Casal", que e null e
/// nao daria para distinguir do estado inicial de outro jeito.
class VisaoNotifier extends Notifier<String?> {
  bool _escolhido = false;

  @override
  String? build() {
    ref.listen<Membro?>(membroLogadoProvider, (_, logado) {
      if (!_escolhido && logado != null) state = logado.id;
    });
    return ref.read(membroLogadoProvider)?.id;
  }

  void selecionar(String? membroId) {
    _escolhido = true;
    state = membroId;
  }
}

final visaoProvider =
    NotifierProvider<VisaoNotifier, String?>(VisaoNotifier.new);

// --- Dados ----------------------------------------------------------------

final potesProvider = StreamProvider<List<Pote>>(
  (ref) => ref.watch(repositorioPotesProvider).observar(),
);

final cartoesProvider = StreamProvider<List<Cartao>>(
  (ref) => ref.watch(repositorioCartoesProvider).observar(),
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

/// Uma janela (inicio, fim) de meses, ambos inclusive. O registro e a chave
/// da family: dois pedidos da mesma janela compartilham uma assinatura so.
typedef JanelaMeses = ({String inicio, String fim});

final ganhosDoIntervaloProvider =
    StreamProvider.autoDispose.family<List<Ganho>, JanelaMeses>(
  (ref, janela) => ref
      .watch(repositorioGanhosProvider)
      .observarIntervalo(janela.inicio, janela.fim),
);

final gastosDoIntervaloProvider =
    StreamProvider.autoDispose.family<List<Gasto>, JanelaMeses>(
  (ref, janela) => ref
      .watch(repositorioGastosProvider)
      .observarIntervalo(janela.inicio, janela.fim),
);

// --- Derivados ------------------------------------------------------------

/// Combina dois AsyncValue preservando loading e erro. Publica (nao mais
/// privada a este arquivo) porque as telas de Gastos, Parcelas e o
/// formulario de Gasto tambem precisam compor potesProvider com outro
/// AsyncValue sem violar a regra de que toda leitura assincrona passa pelos
/// tres ramos de AsyncValue.when.
AsyncValue<R> combinarAsyncValues<A, B, R>(
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

  return combinarAsyncValues(
    ref.watch(ganhosDoMesProvider(mes)),
    ref.watch(gastosDoMesProvider(mes)),
    (ganhos, gastos) =>
        calcularTotais(ganhos: ganhos, gastos: gastos, membroId: membroId),
  );
});

final resumoCascataProvider =
    Provider.autoDispose<AsyncValue<ResultadoCascata>>((ref) {
  final potes = ref.watch(potesProvider);
  final totais = ref.watch(totaisDoMesProvider);

  return combinarAsyncValues(
    potes,
    totais,
    (listaPotes, t) => calcularCascata(
      potes: listaPotes,
      totalGanhos: t.ganhos,
      totalGastos: t.gastos,
    ),
  );
});

/// Quantos meses a serie de evolucao cobre, terminando no mes selecionado.
/// Doze fecha o ciclo anual e ainda cabe no eixo sem embolar os rotulos.
const int mesesDaSerie = 12;

/// Ganhos e gastos dos ultimos [mesesDaSerie] meses, respeitando a visao.
/// Alimenta o grafico 3 da spec.
final serieMensalProvider =
    Provider.autoDispose<AsyncValue<List<PontoMensal>>>((ref) {
  final fim = ref.watch(mesSelecionadoProvider);
  final membroId = ref.watch(visaoProvider);
  final meses = janelaAte(fim, mesesDaSerie);
  final janela = (inicio: meses.first.valor, fim: fim.valor);

  return combinarAsyncValues(
    ref.watch(ganhosDoIntervaloProvider(janela)),
    ref.watch(gastosDoIntervaloProvider(janela)),
    (ganhos, gastos) => montarSerie(
      meses: meses,
      ganhos: ganhos,
      gastos: gastos,
      membroId: membroId,
    ),
  );
});

/// Gastos do mes somados por pote, ja respeitando a visao selecionada.
final gastosPorPoteProvider =
    Provider.autoDispose<AsyncValue<Map<String, double>>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);

  return ref
      .watch(gastosDoMesProvider(mes))
      .whenData((gastos) => somarGastosPorPote(gastos, membroId: membroId));
});

/// Fatias da rosca (grafico 1 da spec 10).
final fatiasPorPoteProvider =
    Provider.autoDispose<AsyncValue<List<Fatia>>>((ref) {
  return combinarAsyncValues(
    ref.watch(potesProvider),
    ref.watch(gastosPorPoteProvider),
    (potes, porPote) => fatiasPorPote(porPote: porPote, potes: potes),
  );
});

/// Barras de Previsto x Gasto (grafico 2 da spec 10).
///
/// O previsto vem das linhas da cascata, nao de uma multiplicacao refeita
/// aqui: ha um lugar so no app que sabe transformar percentual em dinheiro.
final barrasPorPoteProvider =
    Provider.autoDispose<AsyncValue<List<BarraPote>>>((ref) {
  return combinarAsyncValues(
    ref.watch(resumoCascataProvider),
    ref.watch(gastosPorPoteProvider),
    (resumo, porPote) =>
        barrasPrevistoGasto(linhas: resumo.linhas, porPote: porPote),
  );
});

/// Ganhos do mes por pessoa (grafico 4 da spec 10).
///
/// NAO le visaoProvider de proposito: "proporcao de ganhos entre Marcos e
/// Silvia" filtrado por pessoa viraria uma fatia unica de 100%, que nao
/// responde pergunta nenhuma.
final fatiasPorMembroProvider =
    Provider.autoDispose<AsyncValue<List<Fatia>>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membros = ref.watch(membrosProvider);

  return ref.watch(ganhosDoMesProvider(mes)).whenData(
        (ganhos) => fatiasPorMembro(
          porMembro: somarGanhosPorMembro(ganhos),
          membros: membros,
        ),
      );
});

/// Comprometimento futuro: os proximos [mesesDaSerie] meses a partir do
/// selecionado, inclusive, respeitando a visao (grafico 6 da spec 10).
final serieComprometimentoProvider =
    Provider.autoDispose<AsyncValue<List<PontoComprometido>>>((ref) {
  final inicio = ref.watch(mesSelecionadoProvider);
  final membroId = ref.watch(visaoProvider);
  final meses = janelaDe(inicio, mesesDaSerie);

  return ref.watch(parceladosDesdeProvider(inicio.valor)).whenData(
        (parcelas) => serieComprometimento(
          meses: meses,
          parcelas: parcelas,
          membroId: membroId,
        ),
      );
});

/// Gastos do mes somados por cartao, ja respeitando a visao selecionada.
///
/// Fora da numeracao da spec 10 (grafico extra).
final gastosPorCartaoProvider =
    Provider.autoDispose<AsyncValue<Map<String, double>>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);

  return ref
      .watch(gastosDoMesProvider(mes))
      .whenData((gastos) => somarGastosPorCartao(gastos, membroId: membroId));
});

/// Fatias da rosca de gastos por cartao (grafico extra, fora da spec 10).
final fatiasPorCartaoProvider =
    Provider.autoDispose<AsyncValue<List<Fatia>>>((ref) {
  return combinarAsyncValues(
    ref.watch(cartoesProvider),
    ref.watch(gastosPorCartaoProvider),
    (cartoes, porCartao) =>
        fatiasPorCartao(porCartao: porCartao, cartoes: cartoes),
  );
});

final parcelasEmAbertoProvider =
    Provider.autoDispose<AsyncValue<List<CompraParcelada>>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider);
  return ref.watch(parceladosDesdeProvider(mes.valor)).whenData(
        (gastos) => agruparParcelasEmAberto(gastos: gastos, mesAtual: mes),
      );
});

/// As compras em aberto passadas pelos mesmos tres filtros da tela de Gastos.
final comprasFiltradasProvider =
    Provider.autoDispose<AsyncValue<List<CompraParcelada>>>((ref) {
  final membroId = ref.watch(visaoProvider);
  final poteId = ref.watch(filtroPoteProvider);
  final cartaoId = ref.watch(filtroCartaoProvider);

  return ref.watch(parcelasEmAbertoProvider).whenData(
        (compras) => compras
            .where((c) =>
                (membroId == null || c.membroId == membroId) &&
                (poteId == null || c.poteId == poteId) &&
                _passaNoCartao(c.cartaoId, cartaoId))
            .toList(),
      );
});

/// As compras filtradas, ja agrupadas conforme `ordemGastosProvider`.
final comprasAgrupadasProvider =
    Provider.autoDispose<AsyncValue<List<Grupo<CompraParcelada>>>>((ref) {
  final ordem = ref.watch(ordemGastosProvider);

  return combinarAsyncValues(
    combinarAsyncValues(
      ref.watch(potesProvider),
      ref.watch(cartoesProvider),
      (potes, cartoes) => (potes, cartoes),
    ),
    ref.watch(comprasFiltradasProvider),
    (par, compras) => agruparCompras(
      compras: compras,
      ordem: ordem,
      potes: par.$1,
      cartoes: par.$2,
    ),
  );
});

// --- Filtros e ordem, compartilhados por Gastos e Parcelas ---------------
//
// Compartilhados de proposito: "estou olhando o Nubank" e um estado da
// pessoa, nao de uma tela. Os dropdowns aparecem nas duas, entao a escolha
// continua visivel depois de trocar de aba. O filtro de pessoa segue a mesma
// ideia, so que mais longe: mora em `visaoProvider`, junto com o seletor do
// Resumo e dos Graficos.

/// Null significa "Todos os potes".
class FiltroPoteNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void selecionar(String? poteId) => state = poteId;
}

final filtroPoteProvider =
    NotifierProvider<FiltroPoteNotifier, String?>(FiltroPoteNotifier.new);

/// Null significa "Todos os cartoes"; string vazia significa "Sem cartao",
/// que e como se olha o que saiu em dinheiro, pix ou debito.
///
/// A string vazia e um sentinela, e nao um segundo campo booleano, porque o
/// DropdownButton ja trabalha com um valor por item — dois campos exigiriam
/// manter os dois em sincronia a cada troca.
class FiltroCartaoNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void selecionar(String? cartaoId) => state = cartaoId;
}

final filtroCartaoProvider =
    NotifierProvider<FiltroCartaoNotifier, String?>(FiltroCartaoNotifier.new);

/// Como a lista de gastos e organizada. Comeca por data, que e a leitura
/// mais natural de um extrato.
class OrdemGastosNotifier extends Notifier<OrdemGastos> {
  @override
  OrdemGastos build() => OrdemGastos.data;

  void selecionar(OrdemGastos ordem) => state = ordem;
}

final ordemGastosProvider =
    NotifierProvider<OrdemGastosNotifier, OrdemGastos>(
        OrdemGastosNotifier.new);

/// Os gastos do mes ja passados pelos dois filtros. O filtro acontece aqui,
/// e nao numa query do Firestore, porque combinar duas igualdades opcionais
/// exigiria um indice para cada combinacao — e o volume de um mes cabe
/// folgado em memoria.
final gastosFiltradosProvider =
    Provider.autoDispose<AsyncValue<List<Gasto>>>((ref) {
  final mesRef = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);
  final poteId = ref.watch(filtroPoteProvider);
  final cartaoId = ref.watch(filtroCartaoProvider);

  return ref.watch(gastosDoMesProvider(mesRef)).whenData(
        (lista) => lista
            .where((g) =>
                (membroId == null || g.membroId == membroId) &&
                (poteId == null || g.poteId == poteId) &&
                _passaNoCartao(g.cartaoId, cartaoId))
            .toList(),
      );
});

/// Os gastos filtrados, ja agrupados e ordenados conforme `ordemGastosProvider`.
final gastosAgrupadosProvider =
    Provider.autoDispose<AsyncValue<List<GrupoGastos>>>((ref) {
  final ordem = ref.watch(ordemGastosProvider);

  return combinarAsyncValues(
    combinarAsyncValues(
      ref.watch(potesProvider),
      ref.watch(cartoesProvider),
      (potes, cartoes) => (potes, cartoes),
    ),
    ref.watch(gastosFiltradosProvider),
    (par, gastos) => agruparGastos(
      gastos: gastos,
      ordem: ordem,
      potes: par.$1,
      cartoes: par.$2,
    ),
  );
});

/// Null no filtro deixa tudo passar; a string vazia deixa passar so o que
/// nao tem cartao; um id deixa passar so aquele cartao.
bool _passaNoCartao(String? doGasto, String? filtro) {
  if (filtro == null) return true;
  if (filtro.isEmpty) return doGasto == null || doGasto.isEmpty;
  return doGasto == filtro;
}
