import 'models/gasto.dart';
import 'models/mes_ref.dart';

/// Expande uma compra parcelada em um gasto por mes.
///
/// O [compraId] entra por parametro em vez de ser sorteado aqui dentro para
/// que a funcao seja deterministica e testavel; quem chama gera o uuid.
///
/// Com [quantidade] igual a 1 devolve um gasto simples, sem marcas de
/// parcelamento — uma compra "em 1x" nao e um parcelamento.
List<Gasto> gerarParcelas({
  required Gasto base,
  required int quantidade,
  required String compraId,
}) {
  if (quantidade <= 0) {
    throw ArgumentError.value(
        quantidade, 'quantidade', 'precisa ser maior que zero');
  }

  final inicio = MesRef.parse(base.mesRef); // valida o formato

  if (quantidade == 1) {
    return [
      Gasto(
        id: '',
        mesRef: base.mesRef,
        membroId: base.membroId,
        poteId: base.poteId,
        descricao: base.descricao,
        valor: base.valor,
        criadoEm: base.criadoEm,
        data: base.data,
        cartaoId: base.cartaoId,
        parcelado: false,
      ),
    ];
  }

  return List.generate(quantidade, (i) {
    return Gasto(
      id: '',
      mesRef: inicio.avancar(i).valor,
      membroId: base.membroId,
      poteId: base.poteId,
      descricao: base.descricao,
      valor: base.valor,
      criadoEm: base.criadoEm,
      // Cada parcela cai no mesmo dia do mes dela, nao no dia da compra: a
      // parcela 3 de uma compra de 31/01 vence em marco, nao em janeiro.
      data: avancarMesesNoDia(base.data, i),
      cartaoId: base.cartaoId,
      parcelado: true,
      compraId: compraId,
      parcela: i + 1,
      totalParcelas: quantidade,
    );
  });
}

/// Avanca [meses] mantendo o dia, encolhendo para o ultimo dia do mes de
/// destino quando ele nao existe la.
///
/// Sem o encolhimento, 31/01 + 1 mes viraria 03/03 no DateTime do Dart, que
/// normaliza o excesso para o mes seguinte — a parcela pularia fevereiro.
DateTime avancarMesesNoDia(DateTime data, int meses) {
  final total = data.year * 12 + (data.month - 1) + meses;
  final ano = total ~/ 12;
  final mes = total % 12 + 1;
  // Dia 0 do mes seguinte e o ultimo dia deste.
  final ultimoDia = DateTime(ano, mes + 1, 0).day;
  return DateTime(ano, mes, data.day < ultimoDia ? data.day : ultimoDia);
}

/// Uma compra parcelada vista do mes atual.
class CompraParcelada {
  final String compraId;
  final String descricao;
  final String membroId;
  final String poteId;

  /// Cartao da compra. Nulo quando saiu em dinheiro, pix ou debito.
  final String? cartaoId;

  /// Data da parcela **corrente**, nao a da compra: e o vencimento que
  /// interessa a quem esta olhando o que ainda falta pagar.
  final DateTime data;

  final double valorParcela;
  final int parcelaAtual;
  final int totalParcelas;

  const CompraParcelada({
    required this.compraId,
    required this.descricao,
    required this.membroId,
    required this.poteId,
    required this.valorParcela,
    required this.parcelaAtual,
    required this.totalParcelas,
    required this.data,
    this.cartaoId,
  });

  int get parcelasRestantes => totalParcelas - parcelaAtual;

  /// "Geladeira — parcela 3/10 — R$ 100,00/mês — faltam 7 meses"
  String get resumo {
    final valor = _formatarReais(valorParcela);
    final restante = parcelasRestantes == 0
        ? 'ultima parcela'
        : parcelasRestantes == 1
            ? 'falta 1 mês'
            : 'faltam $parcelasRestantes meses';
    return '$descricao — parcela $parcelaAtual/$totalParcelas '
        '— $valor/mês — $restante';
  }
}

/// Formatacao pt-BR sem depender do intl, para manter o dominio puro.
String _formatarReais(double valor) {
  final centavos = (valor * 100).round();
  final inteiro = (centavos ~/ 100).toString();
  final resto = (centavos % 100).toString().padLeft(2, '0');

  final buffer = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    if (i > 0 && (inteiro.length - i) % 3 == 0) buffer.write('.');
    buffer.write(inteiro[i]);
  }
  return r'R$ ' '$buffer,$resto';
}

/// Agrupa parcelas por compra e devolve so as que ainda nao terminaram,
/// ordenadas da que quita primeiro para a que quita por ultimo.
List<CompraParcelada> agruparParcelasEmAberto({
  required List<Gasto> gastos,
  required MesRef mesAtual,
}) {
  final porCompra = <String, List<Gasto>>{};

  for (final gasto in gastos) {
    if (!gasto.parcelado || gasto.compraId == null) continue;
    porCompra.putIfAbsent(gasto.compraId!, () => []).add(gasto);
  }

  final abertas = <CompraParcelada>[];

  for (final entrada in porCompra.entries) {
    // A parcela "corrente" e a primeira que cai em mesAtual ou depois.
    final futuras = entrada.value
        .where((g) => MesRef.parse(g.mesRef).compareTo(mesAtual) >= 0)
        .toList()
      ..sort((a, b) => a.parcela!.compareTo(b.parcela!));

    if (futuras.isEmpty) continue; // compra ja quitada

    final corrente = futuras.first;
    abertas.add(CompraParcelada(
      compraId: entrada.key,
      descricao: corrente.descricao,
      membroId: corrente.membroId,
      poteId: corrente.poteId,
      cartaoId: corrente.cartaoId,
      data: corrente.data,
      valorParcela: corrente.valor,
      parcelaAtual: corrente.parcela!,
      totalParcelas: corrente.totalParcelas!,
    ));
  }

  abertas.sort((a, b) => a.parcelasRestantes.compareTo(b.parcelasRestantes));
  return abertas;
}

// ---------------------------------------------------------------------------
// Edicao de uma compra ja parcelada
// ---------------------------------------------------------------------------

/// A que parcelas o **valor** editado se aplica. Os mesmos tres modos da
/// exclusao, de proposito: quem ja aprendeu a escolha ao excluir nao precisa
/// aprender outra ao editar.
///
/// So o valor: descricao, pessoa e pote descrevem a compra, e uma compra nao
/// muda de nome no meio do parcelamento.
enum ModoEdicao { somenteEsta, estaEFuturas, todas }

/// As escritas necessarias para efetivar uma edicao de compra parcelada.
///
/// Existe para manter a decisao fora do repositorio: o que muda, o que nasce
/// e o que morre e aritmetica de parcelas, nao detalhe de Firestore.
class PlanoEdicaoCompra {
  /// Documentos existentes cujo conteudo mudou. Ja trazem o `id`.
  final List<Gasto> atualizar;

  /// Parcelas novas, sem `id` — quem grava atribui.
  final List<Gasto> criar;

  /// Ids a apagar.
  final List<String> remover;

  const PlanoEdicaoCompra({
    this.atualizar = const [],
    this.criar = const [],
    this.remover = const [],
  });

  bool get vazio => atualizar.isEmpty && criar.isEmpty && remover.isEmpty;
}

/// Planeja a edicao de uma parcela de [editado] sobre a compra inteira.
///
/// Descricao, pessoa, pote, cartao e data sao atributos da **compra**: mudam em
/// todas as parcelas, sempre, sem perguntar. Corrigir o nome de uma compra
/// deixando as outras onze parcelas com o nome errado nunca e o que se quis
/// fazer.
///
/// A data propaga de um jeito proprio: o DIA vale para a compra inteira, mas
/// cada parcela fica no seu proprio mes. Trocar a data da parcela 3 para
/// 17/10 poe a 1 em 17/08 e a 2 em 17/09 — a parcela editada recebe
/// exatamente a data digitada, e as irmas se alinham a ela.
///
/// [alcance] governa apenas o **valor**, que e o unico campo que pode
/// legitimamente diferir entre parcelas (o arredondamento da ultima, um mes
/// renegociado).
///
/// [novaQuantidade] vale **sempre** para a compra inteira, em qualquer modo:
/// "quantas parcelas a compra tem" nao e propriedade de uma parcela isolada.
/// Aumentar cria parcelas no fim; diminuir apaga as ultimas.
///
/// O mes da parcela 1 e a ancora, reconstruido a partir de qualquer parcela
/// sobrevivente — nao do [editado]. Editar a parcela 3 de uma compra que
/// comecou em agosto nao pode fazer a compra "recomecar" em outubro.
///
/// Encolher abaixo da parcela de [editado] apaga o proprio documento editado.
/// A funcao obedece; e a UI que impede, validando o minimo no formulario.
PlanoEdicaoCompra planejarEdicaoCompra({
  required List<Gasto> existentes,
  required Gasto editado,
  required ModoEdicao alcance,
  required int novaQuantidade,
}) {
  if (novaQuantidade < 1) {
    throw ArgumentError.value(
        novaQuantidade, 'novaQuantidade', 'precisa ser maior que zero');
  }

  final compraId = editado.compraId;
  final daCompra = compraId == null
      ? <Gasto>[]
      : (existentes
          .where((g) => g.compraId == compraId && g.parcela != null)
          .toList()
        ..sort((a, b) => a.parcela!.compareTo(b.parcela!)));

  // Sem contexto da compra nao ha o que propagar nem como ancorar: cai para
  // a edicao do documento solto, que e o comportamento honesto.
  if (daCompra.isEmpty || editado.parcela == null) {
    return PlanoEdicaoCompra(atualizar: [editado]);
  }

  final primeira = daCompra.first;
  final inicio = MesRef.parse(primeira.mesRef).avancar(-(primeira.parcela! - 1));

  // A parcela mais alta manda sobre o campo totalParcelas: se uma parcela do
  // fim ja foi apagada individualmente, o total gravado pode estar adiante
  // dela, e recriar o que foi apagado de proposito seria pior que o gap.
  var totalAtual = 0;
  for (final g in daCompra) {
    final candidatos = [g.parcela!, g.totalParcelas ?? 0];
    for (final c in candidatos) {
      if (c > totalAtual) totalAtual = c;
    }
  }

  bool herdaValor(Gasto g) => switch (alcance) {
        ModoEdicao.somenteEsta => g.parcela == editado.parcela,
        ModoEdicao.estaEFuturas => g.parcela! >= editado.parcela!,
        ModoEdicao.todas => true,
      };

  final atualizar = <Gasto>[];
  final remover = <String>[];

  for (final g in daCompra) {
    if (g.parcela! > novaQuantidade) {
      remover.add(g.id);
      continue;
    }
    // Identidade da compra e o total: valem para todas as parcelas.
    var alvo = g.copyWith(
      descricao: editado.descricao,
      membroId: editado.membroId,
      poteId: editado.poteId,
      cartaoId: editado.cartaoId,
      totalParcelas: novaQuantidade,
      // O deslocamento e relativo a parcela editada, entao ela mesma recebe
      // a data digitada sem alteracao.
      data: avancarMesesNoDia(editado.data, g.parcela! - editado.parcela!),
    );
    if (herdaValor(g)) alvo = alvo.copyWith(valor: editado.valor);

    if (!_mesmoConteudo(alvo, g)) atualizar.add(alvo);
  }

  final criar = <Gasto>[
    for (var k = totalAtual + 1; k <= novaQuantidade; k++)
      Gasto(
        id: '',
        mesRef: inicio.avancar(k - 1).valor,
        membroId: editado.membroId,
        poteId: editado.poteId,
        descricao: editado.descricao,
        valor: editado.valor,
        // Herda o carimbo da compra para as parcelas novas nao aparecerem
        // separadas das irmas na lista, que ordena por criadoEm.
        criadoEm: primeira.criadoEm,
        // Ancorada na parcela EDITADA, nao na primeira: se a data mudou
        // nesta mesma edicao, a parcela nova precisa nascer ja alinhada.
        data: avancarMesesNoDia(editado.data, k - editado.parcela!),
        cartaoId: editado.cartaoId,
        parcelado: true,
        compraId: compraId,
        parcela: k,
        totalParcelas: novaQuantidade,
      ),
  ];

  return PlanoEdicaoCompra(
      atualizar: atualizar, criar: criar, remover: remover);
}

/// Compara so o que esta edicao pode mexer, para nao gerar escrita inutil.
bool _mesmoConteudo(Gasto a, Gasto b) =>
    a.descricao == b.descricao &&
    a.membroId == b.membroId &&
    a.poteId == b.poteId &&
    a.cartaoId == b.cartaoId &&
    // Sem comparar a data, uma edicao que so mexe nela nao geraria escrita
    // nenhuma e o Salvar pareceria nao ter funcionado.
    a.data == b.data &&
    (a.valor - b.valor).abs() <= 0.005 &&
    a.totalParcelas == b.totalParcelas &&
    a.mesRef == b.mesRef;
