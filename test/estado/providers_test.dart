import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/estado/providers.dart';

const potes = [
  Pote(id: 'p1', nome: 'Custo fixo', percentual: 55, ordem: 0,
      cor: '#2E7D32', icone: 'casa'),
  Pote(id: 'p2', nome: 'Conforto', percentual: 15, ordem: 1,
      cor: '#1565C0', icone: 'sofa'),
  Pote(id: 'p3', nome: 'Investimento', percentual: 10, ordem: 2,
      cor: '#00838F', icone: 'grafico'),
  Pote(id: 'p4', nome: 'Metas', percentual: 10, ordem: 3,
      cor: '#EF6C00', icone: 'alvo'),
  Pote(id: 'p5', nome: 'Prazer', percentual: 5, ordem: 4,
      cor: '#AD1457', icone: 'presente'),
  Pote(id: 'p6', nome: 'Conhecimento', percentual: 5, ordem: 5,
      cor: '#4527A0', icone: 'livro'),
];

Future<ProviderContainer> montar() async {
  final ganhos = RepositorioGanhosFake();
  final gastos = RepositorioGastosFake();

  await ganhos.adicionar(Ganho(
    id: '', mesRef: '2026-08', membroId: 'marcos',
    descricao: 'Salario', valor: 5000, criadoEm: DateTime.utc(2026, 8, 1),
  ));
  await gastos.adicionar(
    base: Gasto(
      id: '', mesRef: '2026-08', membroId: 'marcos', poteId: 'p1',
      descricao: 'Aluguel', valor: 3900,
      criadoEm: DateTime.utc(2026, 8, 2), parcelado: false,
    ),
    quantidadeParcelas: 1,
  );

  final container = ProviderContainer(overrides: [
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
    repositorioGanhosProvider.overrideWithValue(ganhos),
    repositorioGastosProvider.overrideWithValue(gastos),
  ]);

  container.read(mesSelecionadoProvider.notifier)
      .irPara(const MesRef(2026, 8));

  // Deixa os streams emitirem o primeiro valor.
  container.listen(potesProvider, (_, _) {});
  container.listen(ganhosDoMesProvider('2026-08'), (_, _) {});
  container.listen(gastosDoMesProvider('2026-08'), (_, _) {});
  await Future<void>.delayed(Duration.zero);

  return container;
}

void main() {
  test('mesSelecionado comeca no mes corrente', () {
    final c = ProviderContainer();
    expect(c.read(mesSelecionadoProvider), MesRef.atual());
    c.dispose();
  });

  test('avancar muda o mes selecionado', () {
    final c = ProviderContainer();
    c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 12));
    c.read(mesSelecionadoProvider.notifier).avancar(1);
    expect(c.read(mesSelecionadoProvider).valor, '2027-01');
    c.dispose();
  });

  test('totaisDoMes soma ganhos e gastos do mes selecionado', () async {
    final c = await montar();
    final totais = c.read(totaisDoMesProvider);

    expect(totais.hasValue, isTrue);
    expect(totais.requireValue.ganhos, 5000);
    expect(totais.requireValue.gastos, 3900);
    expect(totais.requireValue.saldo, 1100);
    c.dispose();
  });

  test('resumoCascata usa o motor da cascata e aponta o pote ativo', () async {
    final c = await montar();
    final resumo = c.read(resumoCascataProvider);

    expect(resumo.hasValue, isTrue);
    // 5000 de renda, 3900 de gasto: agua para no terceiro pote.
    expect(resumo.requireValue.poteAtivo?.id, 'p3');
    expect(resumo.requireValue.rotulo, 'INVESTIMENTO');
    c.dispose();
  });

  test('visao por membro filtra o calculo', () async {
    final c = await montar();
    c.read(visaoProvider.notifier).selecionar('silvia');

    final totais = c.read(totaisDoMesProvider);
    expect(totais.requireValue.ganhos, 0);
    expect(totais.requireValue.gastos, 0);
    c.dispose();
  });

  test('enquanto o repositorio nao emitiu, o resumo fica em loading', () {
    final c = ProviderContainer(overrides: [
      repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
      repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
      repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
    ]);

    expect(c.read(resumoCascataProvider).isLoading, isTrue);
    c.dispose();
  });
}
