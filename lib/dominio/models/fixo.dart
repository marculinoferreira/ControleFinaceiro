import 'mes_ref.dart';

enum TipoFixo { ganho, gasto }

/// Molde de um ganho ou gasto recorrente e previsivel (salario, aluguel,
/// assinatura): enquanto existir, gera um lancamento previsto (Ganho ou
/// Gasto, conforme [tipo]) no mes seguinte ao mes real de hoje, toda vez
/// que o app verifica (ver `garantirFixosDoMesProvider` em
/// lib/estado/providers.dart).
///
/// Excluir o Fixo so impede gerar NOVOS meses -- lancamentos que ele ja
/// gerou continuam existindo, independentes dele a partir dai.
class Fixo {
  final String id;
  final TipoFixo tipo;
  final String membroId;
  final String descricao;
  final double valor;

  /// So para `tipo == TipoFixo.gasto`. Nulo (e sem sentido) para ganho.
  final String? poteId;

  final DateTime criadoEm;

  const Fixo({
    required this.id,
    required this.tipo,
    required this.membroId,
    required this.descricao,
    required this.valor,
    required this.criadoEm,
    this.poteId,
  });

  factory Fixo.fromMap(String id, Map<String, dynamic> mapa) => Fixo(
        id: id,
        tipo: (mapa['tipo'] as String) == 'ganho'
            ? TipoFixo.ganho
            : TipoFixo.gasto,
        membroId: mapa['membroId'] as String,
        descricao: mapa['descricao'] as String,
        valor: (mapa['valor'] as num).toDouble(),
        criadoEm: _lerData(mapa['criadoEm']),
        poteId: mapa['poteId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'tipo': tipo == TipoFixo.ganho ? 'ganho' : 'gasto',
        'membroId': membroId,
        'descricao': descricao,
        'valor': valor,
        'criadoEm': criadoEm,
        'poteId': poteId,
      };
}

DateTime _lerData(dynamic bruto) {
  if (bruto is DateTime) return bruto;
  if (bruto == null) return DateTime.now();
  return (bruto as dynamic).toDate() as DateTime;
}

/// Mes-alvo da geracao: sempre o mes seguinte ao mes REAL de hoje (nao o
/// mes selecionado na tela).
MesRef mesAlvoDosFixos() => MesRef.atual().avancar(1);

/// Os Fixos que AINDA NAO tem um lancamento gerado para [mesAlvo]
/// (comparando o id do Fixo contra `origemFixoId` dos lancamentos ja
/// existentes naquele mes, em [origensJaGeradasNoMes]). [mesAlvo] nao
/// entra na comparacao em si -- quem monta `origensJaGeradasNoMes` ja
/// filtrou pelo mes certo antes de chamar esta funcao.
List<Fixo> fixosParaGerar({
  required List<Fixo> fixos,
  required MesRef mesAlvo,
  required Set<String> origensJaGeradasNoMes,
}) =>
    [
      for (final f in fixos)
        if (!origensJaGeradasNoMes.contains(f.id)) f,
    ];

/// Verdadeiro quando o lancamento veio de um Fixo E o mes dele ainda nao
/// chegou (mesRef depois do mes real de hoje) -- so entao fica travado
/// para edicao/exclusao. Lancamentos sem origemFixoId (previsto manual,
/// ou qualquer lancamento normal) nunca travam.
bool travadoPorFixo({required String? origemFixoId, required String mesRef}) =>
    origemFixoId != null && MesRef.parse(mesRef).compareTo(MesRef.atual()) > 0;
