import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/dominio/serie_mensal.dart';
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
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
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
      repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
      repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
      repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
    ]);

    expect(c.read(resumoCascataProvider).isLoading, isTrue);
    c.dispose();
  });

  group('serieMensalProvider', () {
    /// Assina a serie e tambem as duas familias de intervalo que ela compoe.
    /// Escutar so o provider derivado nao basta: os StreamProviders da
    /// janela corrente precisam de um listener para emitir, e a janela muda
    /// quando o mes selecionado muda.
    Future<void> assinarSerie(ProviderContainer c) async {
      final fim = c.read(mesSelecionadoProvider);
      final janela = (
        inicio: janelaAte(fim, mesesDaSerie).first.valor,
        fim: fim.valor,
      );
      c.listen(ganhosDoIntervaloProvider(janela), (_, _) {});
      c.listen(gastosDoIntervaloProvider(janela), (_, _) {});
      c.listen(serieMensalProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
    }

    /// Ganhos e gastos espalhados em tres meses, para a janela ter o que
    /// agrupar e tambem um mes vazio no meio.
    Future<ProviderContainer> montarSerie() async {
      final ganhos = RepositorioGanhosFake();
      final gastos = RepositorioGastosFake();

      for (final (mes, valor) in [('2026-06', 4000.0), ('2026-08', 5000.0)]) {
        await ganhos.adicionar(Ganho(
          id: '',
          mesRef: mes,
          membroId: 'marcos',
          descricao: 'Salario',
          valor: valor,
          criadoEm: DateTime.utc(2026, 1, 1),
        ));
      }
      await gastos.adicionar(
        base: Gasto(
          id: '',
          mesRef: '2026-08',
          membroId: 'marcos',
          poteId: 'p1',
          descricao: 'Aluguel',
          valor: 3900,
          criadoEm: DateTime.utc(2026, 8, 2),
          parcelado: false,
        ),
        quantidadeParcelas: 1,
      );

      final c = ProviderContainer(overrides: [
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(ganhos),
        repositorioGastosProvider.overrideWithValue(gastos),
      ]);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      await assinarSerie(c);
      return c;
    }

    test('devolve 12 pontos terminando no mes selecionado', () async {
      final c = await montarSerie();
      final serie = c.read(serieMensalProvider);

      expect(serie.hasValue, isTrue);
      expect(serie.requireValue, hasLength(mesesDaSerie));
      expect(serie.requireValue.last.mes.valor, '2026-08');
      expect(serie.requireValue.first.mes.valor, '2025-09');
      c.dispose();
    });

    test('os meses sem lancamento vem com zero, sem buraco', () async {
      final c = await montarSerie();
      final serie = c.read(serieMensalProvider).requireValue;

      final julho = serie.firstWhere((p) => p.mes.valor == '2026-07');
      expect(julho.ganhos, 0);
      expect(julho.gastos, 0);

      final junho = serie.firstWhere((p) => p.mes.valor == '2026-06');
      expect(junho.ganhos, 4000);
      c.dispose();
    });

    test('acompanha a visao selecionada', () async {
      final c = await montarSerie();
      c.read(visaoProvider.notifier).selecionar('silvia');
      await Future<void>.delayed(Duration.zero);

      final serie = c.read(serieMensalProvider).requireValue;
      expect(serie.every((p) => p.ganhos == 0 && p.gastos == 0), isTrue);
      c.dispose();
    });

    test('a janela anda junto com o mes selecionado', () async {
      final c = await montarSerie();
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 12));
      await assinarSerie(c);

      final serie = c.read(serieMensalProvider).requireValue;
      expect(serie.last.mes.valor, '2026-12');
      expect(serie.first.mes.valor, '2026-01');
      c.dispose();
    });

    test('enquanto o repositorio nao emitiu, fica em loading', () {
      final c = ProviderContainer(overrides: [
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ]);
      expect(c.read(serieMensalProvider).isLoading, isTrue);
      c.dispose();
    });
  });

  group('membrosProvider', () {
    test('sem casa carregada devolve lista vazia, nao null', () {
      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
      ]);
      expect(c.read(membrosProvider), isEmpty);
      c.dispose();
    });

    test('com casa carregada devolve os membros', () async {
      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          const Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              Membro(
                  id: 'marcos',
                  nome: 'Marcos',
                  email: 'm@x.com',
                  cor: '#2E7D32',
                  ordem: 0),
              Membro(
                  id: 'silvia',
                  nome: 'Silvia',
                  email: 's@x.com',
                  cor: '#6A1B9A',
                  ordem: 1),
            ],
          ),
        )),
      ]);
      c.listen(casaProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(c.read(membrosProvider).map((m) => m.id).toList(),
          ['marcos', 'silvia']);
      c.dispose();
    });
  });

  group('tipoVisaoGraficosProvider', () {
    test('comeca em geral', () {
      final c = ProviderContainer();
      expect(c.read(tipoVisaoGraficosProvider), TipoVisaoGraficos.geral);
      c.dispose();
    });

    test('selecionar muda o tipo', () {
      final c = ProviderContainer();
      c.read(tipoVisaoGraficosProvider.notifier)
          .selecionar(TipoVisaoGraficos.projecao);
      expect(c.read(tipoVisaoGraficosProvider), TipoVisaoGraficos.projecao);
      c.dispose();
    });
  });

  group('duplaComparativaProvider', () {
    test('casa com 2 membros ativos devolve os dois, na ordem cadastrada', () async {
      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          const Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              Membro(id: 'silvia', nome: 'Silvia', email: 's@x.com',
                  cor: '#6A1B9A', ordem: 1),
              Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                  cor: '#2E7D32', ordem: 0),
            ],
          ),
        )),
      ]);
      c.listen(casaProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final dupla = c.read(duplaComparativaProvider);
      expect(dupla.map((m) => m.id).toList(), ['marcos', 'silvia']);
      c.dispose();
    });

    test('casa com 1 membro ativo devolve lista vazia', () async {
      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          const Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                  cor: '#2E7D32', ordem: 0),
            ],
          ),
        )),
      ]);
      c.listen(casaProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(c.read(duplaComparativaProvider), isEmpty);
      c.dispose();
    });

    test('membro removido nao entra na dupla', () async {
      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              const Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                  cor: '#2E7D32', ordem: 0),
              Membro(id: 'silvia', nome: 'Silvia', email: 's@x.com',
                  cor: '#6A1B9A', ordem: 1, removidoEm: DateTime.utc(2026, 1, 1)),
            ],
          ),
        )),
      ]);
      c.listen(casaProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(c.read(duplaComparativaProvider), isEmpty);
      c.dispose();
    });
  });

  group('dados do Comparativo', () {
    Future<ProviderContainer> montarComparativo({
      List<(String membroId, String poteId, double valor)> gastosDoMes = const [],
      List<(String membroId, String mesRef, double valor)> parcelas = const [],
    }) async {
      final gastos = RepositorioGastosFake();

      for (final (membroId, poteId, valor) in gastosDoMes) {
        await gastos.adicionar(
          base: Gasto(
            id: '', mesRef: '2026-08', membroId: membroId, poteId: poteId,
            descricao: 'Compra', valor: valor,
            criadoEm: DateTime.utc(2026, 8, 2), parcelado: false,
          ),
          quantidadeParcelas: 1,
        );
      }
      for (final (membroId, mesRef, valor) in parcelas) {
        // quantidadeParcelas precisa ser >= 2: com 1, gerarParcelas devolve
        // um gasto simples (parcelado: false), que observarParceladosDesde
        // nao enxerga.
        await gastos.adicionar(
          base: Gasto(
            id: '', mesRef: mesRef, membroId: membroId, poteId: 'p1',
            descricao: 'Parcelada', valor: valor,
            criadoEm: DateTime.utc(2026, 1, 1), parcelado: false,
          ),
          quantidadeParcelas: 2,
        );
      }

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          const Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                  cor: '#2E7D32', ordem: 0),
              Membro(id: 'silvia', nome: 'Silvia', email: 's@x.com',
                  cor: '#6A1B9A', ordem: 1),
            ],
          ),
        )),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(gastos),
      ]);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      c.listen(casaProvider, (_, _) {});
      c.listen(potesProvider, (_, _) {});
      c.listen(cartoesProvider, (_, _) {});
      c.listen(gastosDoMesProvider('2026-08'), (_, _) {});
      c.listen(parceladosDesdeProvider('2026-08'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('barrasPoteComparativo soma o gasto de cada pessoa por pote', () async {
      final c = await montarComparativo(gastosDoMes: [
        ('marcos', 'p1', 700),
        ('silvia', 'p1', 300),
      ]);

      final barras = c.read(barrasPoteComparativoProvider).requireValue;
      expect(barras.single.valorA, 700); // marcos, ordem 0
      expect(barras.single.valorB, 300); // silvia, ordem 1
      c.dispose();
    });

    test('barrasCartaoComparativo soma o gasto de cada pessoa por cartao', () async {
      final c = await montarComparativo();
      // Sem cartoes cadastrados e sem gasto, a lista vem vazia -- so
      // confirma que o provider resolve sem erro.
      expect(c.read(barrasCartaoComparativoProvider).hasValue, isTrue);
      c.dispose();
    });

    test('serieComprometimentoComparativo devolve uma serie por pessoa', () async {
      final c = await montarComparativo(parcelas: [
        ('marcos', '2026-08', 100),
        ('silvia', '2026-08', 250),
      ]);

      final (serieA, serieB) =
          c.read(serieComprometimentoComparativoProvider).requireValue;
      expect(serieA.first.valor, 100);
      expect(serieB.first.valor, 250);
      c.dispose();
    });

    test('com casa de 1 pessoa, os tres providers devolvem vazio', () async {
      final gastos = RepositorioGastosFake();
      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(
          const Casa(
            id: 'principal',
            nome: 'Casa',
            membros: [
              Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
                  cor: '#2E7D32', ordem: 0),
            ],
          ),
        )),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(gastos),
      ]);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      c.listen(casaProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(c.read(barrasPoteComparativoProvider).requireValue, isEmpty);
      expect(c.read(barrasCartaoComparativoProvider).requireValue, isEmpty);
      final (serieA, serieB) =
          c.read(serieComprometimentoComparativoProvider).requireValue;
      expect(serieA, isEmpty);
      expect(serieB, isEmpty);
      c.dispose();
    });
  });

  group('dados da Projecao', () {
    Future<ProviderContainer> montarProjecao({
      double ganhoMarcos = 5000,
      List<(String mesRef, double valor)> parcelas = const [],
    }) async {
      final ganhos = RepositorioGanhosFake();
      final gastos = RepositorioGastosFake();

      if (ganhoMarcos > 0) {
        await ganhos.adicionar(Ganho(
          id: '', mesRef: '2026-08', membroId: 'marcos',
          descricao: 'Salario', valor: ganhoMarcos,
          criadoEm: DateTime.utc(2026, 8, 1),
        ));
      }
      for (final (mesRef, valor) in parcelas) {
        // quantidadeParcelas precisa ser >= 2: com 1, gerarParcelas devolve
        // um gasto simples (parcelado: false), que observarParceladosDesde
        // nao enxerga.
        await gastos.adicionar(
          base: Gasto(
            id: '', mesRef: mesRef, membroId: 'marcos', poteId: 'p1',
            descricao: 'Parcelada', valor: valor,
            criadoEm: DateTime.utc(2026, 1, 1), parcelado: false,
          ),
          quantidadeParcelas: 2,
        );
      }

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(ganhos),
        repositorioGastosProvider.overrideWithValue(gastos),
      ]);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      c.listen(ganhosDoMesProvider('2026-08'), (_, _) {});
      c.listen(parceladosDesdeProvider('2026-08'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('ganhoAssumidoProjecao e o total de ganhos do mes selecionado', () async {
      final c = await montarProjecao(ganhoMarcos: 5000);
      expect(c.read(ganhoAssumidoProjecaoProvider).requireValue, 5000);
      c.dispose();
    });

    test('ganhoAssumidoProjecao respeita a visao selecionada', () async {
      final c = await montarProjecao(ganhoMarcos: 5000);
      c.read(visaoProvider.notifier).selecionar('silvia');
      expect(c.read(ganhoAssumidoProjecaoProvider).requireValue, 0);
      c.dispose();
    });

    test('serieProjecao repete a renda e usa o comprometido por mes', () async {
      // Uma unica compra de 2 parcelas comecando em 2026-08 cai em 2026-08 e
      // 2026-09 (spillover de gerarParcelas com quantidade >= 2), deixando
      // 2026-10 sem nenhum comprometimento -- exatamente os tres pontos que
      // o teste quer distinguir.
      final c = await montarProjecao(
        ganhoMarcos: 5000,
        parcelas: [('2026-08', 100)],
      );

      final serie = c.read(serieProjecaoProvider).requireValue;
      expect(serie, hasLength(mesesDaSerie));
      expect(serie.every((p) => p.ganhos == 5000), isTrue);
      expect(serie[0].gastos, 100);
      expect(serie[1].gastos, 100);
      expect(serie[2].gastos, 0);
      c.dispose();
    });
  });

  group('percentualComprometidoProvider', () {
    Future<ProviderContainer> montarComprometimento({
      double ganhoMarcos = 0,
      List<(String mesRef, double valor)> parcelas = const [],
    }) async {
      final ganhos = RepositorioGanhosFake();
      final gastos = RepositorioGastosFake();

      if (ganhoMarcos > 0) {
        await ganhos.adicionar(Ganho(
          id: '', mesRef: '2026-08', membroId: 'marcos',
          descricao: 'Salario', valor: ganhoMarcos,
          criadoEm: DateTime.utc(2026, 8, 1),
        ));
      }
      for (final (mesRef, valor) in parcelas) {
        await gastos.adicionar(
          base: Gasto(
            id: '', mesRef: mesRef, membroId: 'marcos', poteId: 'p1',
            descricao: 'Parcelada', valor: valor,
            criadoEm: DateTime.utc(2026, 1, 1), parcelado: true,
            compraId: 'c1', parcela: 1, totalParcelas: 2,
          ),
          quantidadeParcelas: 2,
        );
      }

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(ganhos),
        repositorioGastosProvider.overrideWithValue(gastos),
      ]);
      addTearDown(c.dispose);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      c.listen(ganhosDoMesProvider('2026-08'), (_, _) {});
      c.listen(parceladosDesdeProvider('2026-08'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('sem renda devolve nulo', () async {
      final c = await montarComprometimento(
        ganhoMarcos: 0,
        parcelas: [('2026-08', 100)],
      );

      expect(c.read(percentualComprometidoProvider).requireValue, isNull);
    });

    test('calcula a fracao do comprometido de 2026-08 sobre a renda', () async {
      // Uma compra de 2 parcelas de 100 gera uma em 2026-08 e outra em
      // 2026-09; comprometidoNoMes('2026-08') pega so a primeira.
      final c = await montarComprometimento(
        ganhoMarcos: 1000,
        parcelas: [('2026-08', 100)],
      );

      expect(
        c.read(percentualComprometidoProvider).requireValue,
        closeTo(0.1, 0.0001),
      );
    });
  });

  group('estouroProjetadoProvider', () {
    Future<ProviderContainer> montarEstouro({
      required MesRef mesSelecionado,
      double ganhoMarcos = 1000,
      double gastoNoPote = 0,
    }) async {
      final ganhos = RepositorioGanhosFake();
      final gastos = RepositorioGastosFake();
      final mesRef = mesSelecionado.valor;

      if (ganhoMarcos > 0) {
        await ganhos.adicionar(Ganho(
          id: '', mesRef: mesRef, membroId: 'marcos',
          descricao: 'Salario', valor: ganhoMarcos,
          criadoEm: DateTime.utc(2026, 1, 1),
        ));
      }
      if (gastoNoPote > 0) {
        await gastos.adicionar(
          base: Gasto(
            id: '', mesRef: mesRef, membroId: 'marcos', poteId: 'p1',
            descricao: 'Compra', valor: gastoNoPote,
            criadoEm: DateTime.utc(2026, 1, 2), parcelado: false,
          ),
          quantidadeParcelas: 1,
        );
      }

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(ganhos),
        repositorioGastosProvider.overrideWithValue(gastos),
      ]);
      addTearDown(c.dispose);
      c.read(mesSelecionadoProvider.notifier).irPara(mesSelecionado);
      c.listen(ganhosDoMesProvider(mesRef), (_, _) {});
      c.listen(gastosDoMesProvider(mesRef), (_, _) {});
      c.listen(potesProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('mes selecionado diferente de hoje: mapa vazio', () async {
      // Janeiro de 2020 nunca vai ser "hoje" de novo.
      final c = await montarEstouro(mesSelecionado: const MesRef(2020, 1));

      expect(c.read(estouroProjetadoProvider).requireValue, isEmpty);
    });

    test('mes selecionado e hoje, gasto no ritmo do previsto: sem excesso',
        () async {
      // potes = [p1 60%, p2 40%] sobre 1000 de renda -> previsto p1 = 600.
      // Gasta so uma fracao pequena, sempre abaixo do previsto projetado.
      final c = await montarEstouro(
        mesSelecionado: MesRef.atual(),
        ganhoMarcos: 1000,
        gastoNoPote: 1,
      );

      expect(c.read(estouroProjetadoProvider).requireValue, isEmpty);
    });

    test('mes selecionado e hoje, ritmo de gasto estoura o previsto',
        () async {
      final hoje = DateTime.now();
      final diasDoMes = DateTime(hoje.year, hoje.month + 1, 0).day;
      // previsto p1 = 600 (60% de 1000). Gasta o suficiente no dia de hoje
      // para que a extrapolacao linear passe de 600.
      final gastoNoPote = 600.0 / diasDoMes * hoje.day + 50;

      final c = await montarEstouro(
        mesSelecionado: MesRef.atual(),
        ganhoMarcos: 1000,
        gastoNoPote: gastoNoPote,
      );

      final excessos = c.read(estouroProjetadoProvider).requireValue;
      expect(excessos.containsKey('p1'), isTrue);
      expect(excessos['p1'], greaterThan(0));
    });
  });

  group('tendenciaPoteProvider', () {
    Future<ProviderContainer> montarTendencia({
      List<(String mesRef, String poteId, double valor)> gastos = const [],
    }) async {
      final repoGastos = RepositorioGastosFake();
      for (final (mesRef, poteId, valor) in gastos) {
        await repoGastos.adicionar(
          base: Gasto(
            id: '', mesRef: mesRef, membroId: 'marcos', poteId: poteId,
            descricao: 'Compra', valor: valor,
            criadoEm: DateTime.utc(2026, 1, 1), parcelado: false,
          ),
          quantidadeParcelas: 1,
        );
      }

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake(potes)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(repoGastos),
      ]);
      addTearDown(c.dispose);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      final janela = (
        inicio: janelaAte(const MesRef(2026, 8), mesesDaTendencia).first.valor,
        fim: '2026-08',
      );
      c.listen(gastosDoIntervaloProvider(janela), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('serie de 6 meses terminando no mes selecionado', () async {
      final c = await montarTendencia(gastos: [('2026-08', 'p1', 400)]);

      final serie = c.read(tendenciaPoteProvider('p1')).requireValue;
      expect(serie, hasLength(mesesDaTendencia));
      expect(serie.last.valor, 400);
    });

    test('filtra pelo poteId pedido', () async {
      final c = await montarTendencia(gastos: [
        ('2026-08', 'p1', 400),
        ('2026-08', 'p2', 999),
      ]);

      final serie = c.read(tendenciaPoteProvider('p1')).requireValue;
      expect(serie.last.valor, 400);
    });

    test('mes sem gasto no pote entra com zero', () async {
      final c = await montarTendencia();

      final serie = c.read(tendenciaPoteProvider('p1')).requireValue;
      expect(serie.every((p) => p.valor == 0), isTrue);
    });
  });

  group('poteReservaProvider e mesesCoberturaReservaProvider', () {
    const potesSemReserva = [
      Pote(id: 'p1', nome: 'Custo fixo', percentual: 60, ordem: 0,
          cor: '#2E7D32', icone: 'casa'),
      Pote(id: 'p2', nome: 'Reserva', percentual: 40, ordem: 1,
          cor: '#1565C0', icone: 'cofre'),
    ];

    Future<ProviderContainer> montarReserva({
      List<Pote> potesDaCasa = potesSemReserva,
      double gastoDoMes = 0,
    }) async {
      final repoGastos = RepositorioGastosFake();
      if (gastoDoMes > 0) {
        await repoGastos.adicionar(
          base: Gasto(
            id: '', mesRef: '2026-08', membroId: 'marcos', poteId: 'p1',
            descricao: 'Compra', valor: gastoDoMes,
            criadoEm: DateTime.utc(2026, 8, 2), parcelado: false,
          ),
          quantidadeParcelas: 1,
        );
      }

      final c = ProviderContainer(overrides: [
        repositorioCasaProvider.overrideWithValue(RepositorioCasaFake()),
        repositorioPotesProvider
            .overrideWithValue(RepositorioPotesFake(potesDaCasa)),
        repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(repoGastos),
      ]);
      addTearDown(c.dispose);
      c.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
      c.listen(potesProvider, (_, _) {});
      c.listen(gastosDoMesProvider('2026-08'), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    test('sem pote marcado como reserva, os dois providers sao nulos',
        () async {
      final c = await montarReserva(gastoDoMes: 1000);

      expect(c.read(poteReservaProvider).requireValue, isNull);
      expect(c.read(mesesCoberturaReservaProvider).requireValue, isNull);
    });

    test('com pote marcado e valor guardado, calcula meses de cobertura',
        () async {
      final potesComReserva = [
        potesSemReserva[0],
        potesSemReserva[1].copyWith(ehReserva: true, valorGuardado: 6000),
      ];
      final c = await montarReserva(
        potesDaCasa: potesComReserva,
        gastoDoMes: 1500,
      );

      expect(c.read(poteReservaProvider).requireValue?.id, 'p2');
      expect(c.read(mesesCoberturaReservaProvider).requireValue, 4);
    });

    test('pote marcado mas sem valor guardado preenchido: cobertura nula',
        () async {
      final potesComReserva = [
        potesSemReserva[0],
        potesSemReserva[1].copyWith(ehReserva: true),
      ];
      final c = await montarReserva(
        potesDaCasa: potesComReserva,
        gastoDoMes: 1500,
      );

      expect(c.read(poteReservaProvider).requireValue, isNotNull);
      expect(c.read(mesesCoberturaReservaProvider).requireValue, isNull);
    });
  });
}
