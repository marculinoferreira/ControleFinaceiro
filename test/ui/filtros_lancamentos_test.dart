import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/cartao.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';
import 'package:controle_financeiro/dominio/ordem_gastos.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/widgets/filtros_lancamentos.dart';

const membros = [
  Membro(id: 'marcos', nome: 'Marcos', email: 'm@x.com',
      cor: '#2E7D32', ordem: 0),
  Membro(id: 'silvia', nome: 'Silvia', email: 's@x.com',
      cor: '#6A1B9A', ordem: 1),
];

const potes = [
  Pote(id: 'p1', nome: 'Custo fixo', percentual: 60, ordem: 0,
      cor: '#2E7D32', icone: 'casa'),
  Pote(id: 'p2', nome: 'Conforto', percentual: 40, ordem: 1,
      cor: '#1565C0', icone: 'sofa'),
];

const cartoes = [
  Cartao(id: 'ct1', nome: 'Nubank', ordem: 0),
];

Widget montarFiltros() => const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: FiltrosLancamentos(
            membros: membros,
            potes: potes,
            cartoes: cartoes,
          ),
        ),
      ),
    );

void main() {
  group('FiltrosLancamentos', () {
    testWidgets('as tres caixas ficam lado a lado, na mesma linha',
        (tester) async {
      await tester.pumpWidget(montarFiltros());

      expect(find.byKey(const Key('filtro_membro')), findsOneWidget);
      expect(find.byKey(const Key('filtro_cartao')), findsOneWidget);
      expect(find.byKey(const Key('filtro_pote')), findsOneWidget);

      final pessoaY =
          tester.getTopLeft(find.byKey(const Key('filtro_membro'))).dy;
      final cartaoY =
          tester.getTopLeft(find.byKey(const Key('filtro_cartao'))).dy;
      final poteY = tester.getTopLeft(find.byKey(const Key('filtro_pote'))).dy;

      expect(pessoaY, closeTo(cartaoY, 1));
      expect(cartaoY, closeTo(poteY, 1));
    });

    testWidgets(
        'o rotulo do campo (com icone) fica acima do valor atual, dentro da mesma caixa',
        (tester) async {
      await tester.pumpWidget(montarFiltros());

      final campo = find.byKey(const Key('filtro_membro'));
      expect(find.descendant(of: campo, matching: find.textContaining('Pessoa')),
          findsOneWidget);
      final rotuloY = tester
          .getTopLeft(find.descendant(
              of: campo, matching: find.textContaining('Pessoa')))
          .dy;
      final valorY = tester
          .getTopLeft(
              find.descendant(of: campo, matching: find.text('Casal')))
          .dy;
      expect(rotuloY, lessThan(valorY));

      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_cartao')),
              matching: find.textContaining('Cartão')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_cartao')),
              matching: find.text('Todos')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_pote')),
              matching: find.textContaining('Pote')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_pote')),
              matching: find.text('Todos')),
          findsOneWidget);
    });

    testWidgets(
        'o rotulo fica sobre a linha da borda (estilo campo com legenda flutuante), nao dentro da caixa',
        (tester) async {
      await tester.pumpWidget(montarFiltros());

      // InputDecorator com OutlineInputBorder e o mesmo padrao ja usado no
      // campo de data do formulario de gasto: a legenda "quebra" a linha de
      // cima da borda, em vez de ficar dentro da caixa acima do valor.
      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_membro')),
              matching: find.byType(InputDecorator)),
          findsOneWidget);
    });

    testWidgets(
        'cada pilula tem um icone proprio, pra distinguir Cartao de Pote quando os dois dizem "Todos"',
        (tester) async {
      await tester.pumpWidget(montarFiltros());

      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_membro')),
              matching: find.byIcon(Icons.person_outline)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_cartao')),
              matching: find.byIcon(Icons.credit_card)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_pote')),
              matching: find.byIcon(Icons.pie_chart_outline)),
          findsOneWidget);
    });

    testWidgets('tocar na pilula Pessoa abre um menu com as opcoes',
        (tester) async {
      await tester.pumpWidget(montarFiltros());

      await tester.tap(find.byKey(const Key('filtro_membro')));
      await tester.pumpAndSettle();

      expect(find.text('Marcos'), findsWidgets);
      expect(find.text('Silvia'), findsWidgets);
    });

    testWidgets('escolher no menu da pilula Pessoa muda o provider e o rotulo',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FiltrosLancamentos(
              membros: membros,
              potes: potes,
              cartoes: cartoes,
            ),
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('filtro_membro')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcos').last);
      await tester.pumpAndSettle();

      expect(container.read(visaoProvider), 'marcos');
      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_membro')),
              matching: find.text('Marcos')),
          findsOneWidget);
    });

    testWidgets(
        'com um so membro ativo, a pilula Pessoa some e as outras ficam',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: FiltrosLancamentos(
              membros: [membros[0]],
              potes: potes,
              cartoes: cartoes,
            ),
          ),
        ),
      ));

      expect(find.byKey(const Key('filtro_membro')), findsNothing);
      expect(find.byKey(const Key('filtro_cartao')), findsOneWidget);
      expect(find.byKey(const Key('filtro_pote')), findsOneWidget);
    });

    testWidgets('pilula Cartao mostra "Sem cartão" quando selecionado',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(filtroCartaoProvider.notifier).selecionar('');
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FiltrosLancamentos(
              membros: membros,
              potes: potes,
              cartoes: cartoes,
            ),
          ),
        ),
      ));

      expect(
          find.descendant(
              of: find.byKey(const Key('filtro_cartao')),
              matching: find.text('Sem cartão')),
          findsOneWidget);
    });
  });

  group('SeletorOrdem', () {
    Widget montarOrdem() => const ProviderScope(
          child: MaterialApp(home: Scaffold(body: SeletorOrdem())),
        );

    testWidgets(
        'mostra as quatro opcoes separadas por linhas finas, sem SegmentedButton',
        (tester) async {
      await tester.pumpWidget(montarOrdem());

      final seletor = find.byKey(const Key('ordem_gastos'));
      for (final rotulo in ['Data', 'A–Z', 'Pote', 'Cartão']) {
        expect(find.descendant(of: seletor, matching: find.text(rotulo)),
            findsOneWidget,
            reason: 'faltou $rotulo');
      }
      // Widget proprio (divisores finos entre as opcoes, pilula so na
      // selecionada), nao o SegmentedButton do Material.
      expect(find.byType(SegmentedButton<OrdemGastos>), findsNothing);
      expect(find.text('Ordenar por'), findsOneWidget);
    });

    testWidgets('a opcao selecionada vem dentro de uma pilula com fundo',
        (tester) async {
      await tester.pumpWidget(montarOrdem());

      // Data e o valor inicial de ordemGastosProvider.
      final containers = tester.widgetList<Container>(find.ancestor(
        of: find.text('Data'),
        matching: find.byType(Container),
      ));
      final comFundo = containers
          .where((c) => (c.decoration as BoxDecoration?)?.color != null);

      expect(comFundo, isNotEmpty);

      // A–Z (nao selecionada) nao tem nenhum Container com fundo colorido.
      final containersAZ = tester.widgetList<Container>(find.ancestor(
        of: find.text('A–Z'),
        matching: find.byType(Container),
      ));
      final semFundo = containersAZ
          .where((c) => (c.decoration as BoxDecoration?)?.color != null);
      expect(semFundo, isEmpty);
    });

    testWidgets('a pilula selecionada usa a cor de destaque #26797B',
        (tester) async {
      await tester.pumpWidget(montarOrdem());

      final containers = tester.widgetList<Container>(find.ancestor(
        of: find.text('Data'),
        matching: find.byType(Container),
      ));
      final comFundo = containers
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .where((cor) => cor != null);

      expect(comFundo, contains(const Color(0xFF26797B)));
    });

    testWidgets('uma borda envolve a barra inteira, de Data ate Cartao',
        (tester) async {
      await tester.pumpWidget(montarOrdem());

      final seletor = find.byKey(const Key('ordem_gastos'));
      // O Container com a borda e ancestral do Row inteiro (key
      // 'ordem_gastos'), nao so de uma opcao.
      final comBorda = tester
          .widgetList<Container>(
              find.ancestor(of: seletor, matching: find.byType(Container)))
          .where((c) => (c.decoration as BoxDecoration?)?.border != null);

      expect(comBorda, isNotEmpty);
    });

    testWidgets('tocar numa opcao troca o provider direto, sem menu',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SeletorOrdem())),
      ));

      await tester.tap(find.descendant(
        of: find.byKey(const Key('ordem_gastos')),
        matching: find.text('A–Z'),
      ));
      await tester.pump();

      expect(container.read(ordemGastosProvider), OrdemGastos.alfabetica);
    });
  });
}
