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
      parcelado: true,
      compraId: compraId,
      parcela: i + 1,
      totalParcelas: quantidade,
    );
  });
}

/// Uma compra parcelada vista do mes atual.
class CompraParcelada {
  final String compraId;
  final String descricao;
  final String membroId;
  final String poteId;
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
      valorParcela: corrente.valor,
      parcelaAtual: corrente.parcela!,
      totalParcelas: corrente.totalParcelas!,
    ));
  }

  abertas.sort((a, b) => a.parcelasRestantes.compareTo(b.parcelasRestantes));
  return abertas;
}
