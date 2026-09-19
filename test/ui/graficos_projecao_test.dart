import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/widgets/graficos/linha_projecao.dart';

const casa = Casa(
  id: 'principal',
  nome: 'Casa',
  membros: [
    Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
        cor: '#2E7D32', ordem: 0),
    Membro(id: 'silvia', nome: 'Silvia', email: 's@x.com',
        cor: '#6A1B9A', ordem: 1),
  ],
);

Future<void> montar(
  WidgetTester tester, {
  double ganhoMarcos = 5000,
  List<(String mesRef, double valor)> parcelas = const [],
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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
      // quantidadeParcelas precisa ser >= 2: com 1, gerarParcelas forca
      // parcelado: false (uma compra "em 1x" nao e parcelamento), e
      // parceladosDesdeProvider so enxerga gastos com parcelado: true.
      // Os campos parcelado/compraId/parcela/totalParcelas do `base` sao
      // ignorados por gerarParcelas (ele gera os proprios), entao nao
      // precisam ser passados aqui.
      base: Gasto(
        id: '', mesRef: mesRef, membroId: 'marcos', poteId: 'p1',
        descricao: 'Parcelada', valor: valor,
        criadoEm: DateTime.utc(2026, 1, 1), parcelado: false,
      ),
      quantidadeParcelas: 2,
    );
  }

  final container = ProviderContainer(overrides: [
    repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casa)),
    repositorioPotesProvider.overrideWithValue(RepositorioPotesFake()),
    repositorioCartoesProvider.overrideWithValue(RepositorioCartoesFake()),
    repositorioGanhosProvider.overrideWithValue(ganhos),
    repositorioGastosProvider.overrideWithValue(gastos),
  ]);
  addTearDown(container.dispose);
  container.read(mesSelecionadoProvider.notifier).irPara(const MesRef(2026, 8));
  container.listen(casaProvider, (_, _) {});
  container.listen(ganhosDoMesProvider('2026-08'), (_, _) {});
  container.listen(parceladosDesdeProvider('2026-08'), (_, _) {});

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Scaffold(body: LinhaProjecao())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('LinhaProjecao', () {
    testWidgets('duas series: renda constante e gasto comprometido',
        (tester) async {
      // Uma unica compra parcelada em 2x, comecando em 2026-08: com
      // quantidadeParcelas: 2 (ver comentario em montar()) a mesma compra
      // sai integral (sem dividir o valor) em 2026-08 e 2026-09, e nao
      // sobra nada em 2026-10 -- exatamente o 100/100/0 que o teste
      // verifica. Duas compras de 100 cada (uma por mes) sobrepoem: a
      // segunda entraria com sua propria parcela em 2026-09 (spillover da
      // primeira) + a parcela propria, dando 200 em vez de 100.
      await montar(tester, ganhoMarcos: 5000, parcelas: [
        ('2026-08', 100),
      ]);

      final dados = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(dados.lineBarsData, hasLength(2));
      // Renda: reta em 5000 em todos os meses.
      expect(
        dados.lineBarsData[0].spots.every((s) => s.y == 5000),
        isTrue,
      );
      // Gasto comprometido: 100 nos dois primeiros meses, 0 depois.
      expect(dados.lineBarsData[1].spots[0].y, 100);
      expect(dados.lineBarsData[1].spots[1].y, 100);
      expect(dados.lineBarsData[1].spots[2].y, 0);
    });

    testWidgets('sem renda e sem parcela mostra a frase', (tester) async {
      await montar(tester, ganhoMarcos: 0);

      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('rodape avisa quantos meses ficam com saldo negativo',
        (tester) async {
      await montar(tester, ganhoMarcos: 1000, parcelas: [
        ('2026-08', 1500),
        ('2026-09', 1500),
      ]);

      expect(find.textContaining('saldo negativo'), findsOneWidget);
    });

    testWidgets('sem mes negativo nao mostra aviso', (tester) async {
      await montar(tester, ganhoMarcos: 5000, parcelas: [('2026-08', 100)]);

      expect(find.textContaining('saldo negativo'), findsNothing);
    });
  });
}
