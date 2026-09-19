import 'cascata.dart' show toleranciaCentavo;

/// Quantos meses o valor guardado no pote de reserva cobre, dado o gasto
/// de um mes de referencia. Nula sem valor guardado (pote marcado como
/// reserva mas ainda sem o campo preenchido) ou sem gasto no mes (divisao
/// por zero nao faz sentido: "cobre infinitos meses" nao e uma resposta
/// util).
double? mesesDeCobertura({
  required double? valorGuardado,
  required double gastoDoMes,
}) {
  if (valorGuardado == null) return null;
  if (gastoDoMes <= toleranciaCentavo) return null;
  return valorGuardado / gastoDoMes;
}
