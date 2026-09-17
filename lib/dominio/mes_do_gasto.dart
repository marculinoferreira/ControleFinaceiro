import 'models/mes_ref.dart';

/// Em qual mes-referencia um gasto novo deve cair, dado o cartao escolhido.
///
/// PIX/debito nunca segue a fatura -- o dinheiro sai na hora, entao sempre
/// conta no mes da data de hoje, seja qual for o mes selecionado na tela.
///
/// Credito sem [diaFechamento] cadastrado (o campo e opcional por pessoa,
/// em cada cartao) nao tem como calcular a fatura sozinho, e cai no mes
/// que a tela ja tinha selecionado -- o comportamento de sempre.
///
/// Credito com [diaFechamento] cadastrado: se hoje ja passou do dia de
/// fechamento, a compra caiu na fatura do mes que vem.
MesRef calcularMesDoGasto({
  required DateTime hoje,
  required bool pixDebito,
  required int? diaFechamento,
  required MesRef mesSelecionado,
}) {
  if (pixDebito) return MesRef.deDateTime(hoje);
  if (diaFechamento == null) return mesSelecionado;

  final mesDeHoje = MesRef.deDateTime(hoje);
  return hoje.day > diaFechamento ? mesDeHoje.avancar(1) : mesDeHoje;
}
