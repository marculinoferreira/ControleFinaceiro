import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/ui/widgets/legenda_grafico.dart';
import 'package:controle_financeiro/ui/widgets/moldura_grafico.dart';

/// Monta a moldura sobre uma lista de numeros, que faz as vezes de serie.
Future<int> montar(
  WidgetTester tester, {
  required AsyncValue<List<int>> dados,
  List<ItemLegenda> Function(List<int>)? legenda,
  String vazio = 'Nada neste mês.',
  String? subtitulo,
}) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  var recarregou = 0;

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MolduraGrafico<List<int>>(
        titulo: 'Gastos por pote',
        subtitulo: subtitulo,
        vazio: vazio,
        dados: dados,
        estaVazio: (l) => l.isEmpty,
        legenda: legenda ?? (_) => const [],
        aoRecarregar: () => recarregou++,
        construir: (l) => Text('serie com ${l.length}'),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return recarregou;
}

void main() {
  group('estados', () {
    testWidgets('com dados renderiza o filho', (tester) async {
      await montar(tester, dados: const AsyncValue.data([1, 2, 3]));

      expect(find.text('serie com 3'), findsOneWidget);
      expect(find.text('Nada neste mês.'), findsNothing);
    });

    testWidgets('lista vazia mostra a frase e nao o filho', (tester) async {
      await montar(tester, dados: const AsyncValue.data(<int>[]));

      expect(find.text('Nada neste mês.'), findsOneWidget);
      expect(find.textContaining('serie com'), findsNothing);
    });

    testWidgets('loading mostra o skeleton, nao um spinner', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MolduraGrafico<List<int>>(
            titulo: 'Gastos por pote',
            vazio: 'vazio',
            dados: AsyncValue.loading(),
            estaVazio: _sempreVazio,
            legenda: _semLegenda,
            aoRecarregar: _nada,
            construir: _nuncaConstroi,
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('serie com'), findsNothing);
    });

    testWidgets('erro mostra ErroComRecarregar', (tester) async {
      await montar(
        tester,
        dados: AsyncValue.error(Exception('sem rede'), StackTrace.empty),
      );

      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(find.textContaining('serie com'), findsNothing);
    });

    testWidgets('o botao de recarregar chama aoRecarregar', (tester) async {
      var chamou = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MolduraGrafico<List<int>>(
            titulo: 'Gastos por pote',
            vazio: 'vazio',
            dados: AsyncValue.error(Exception('x'), StackTrace.empty),
            estaVazio: (l) => l.isEmpty,
            legenda: (_) => const [],
            aoRecarregar: () => chamou++,
            construir: (l) => const Text('nunca'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(chamou, 1);
    });
  });

  group('titulo', () {
    testWidgets('sempre aparece, em qualquer estado', (tester) async {
      await montar(tester, dados: const AsyncValue.data(<int>[]));
      expect(find.text('Gastos por pote'), findsOneWidget);

      await montar(
        tester,
        dados: AsyncValue.error(Exception('x'), StackTrace.empty),
      );
      expect(find.text('Gastos por pote'), findsOneWidget);
    });

    testWidgets('o subtitulo aparece quando informado', (tester) async {
      await montar(
        tester,
        dados: const AsyncValue.data([1]),
        subtitulo: 'do casal',
      );

      expect(find.text('do casal'), findsOneWidget);
    });

    testWidgets('sem subtitulo nao sobra espaco vazio', (tester) async {
      await montar(tester, dados: const AsyncValue.data([1]));

      expect(find.text('do casal'), findsNothing);
    });
  });

  group('legenda', () {
    testWidgets('um marcador por serie, com rotulo', (tester) async {
      await montar(
        tester,
        dados: const AsyncValue.data([1, 2]),
        legenda: (_) => const [
          ItemLegenda(rotulo: 'Custo fixo', cor: Color(0xFF2E7D32)),
          ItemLegenda(rotulo: 'Conforto', cor: Color(0xFF1565C0)),
        ],
      );

      expect(find.text('Custo fixo'), findsOneWidget);
      expect(find.text('Conforto'), findsOneWidget);
      expect(find.byType(MarcadorLegenda), findsNWidgets(2));
    });

    testWidgets('o marcador usa a cor da serie', (tester) async {
      await montar(
        tester,
        dados: const AsyncValue.data([1]),
        legenda: (_) => const [
          ItemLegenda(rotulo: 'Custo fixo', cor: Color(0xFF2E7D32)),
        ],
      );

      final marcador =
          tester.widget<MarcadorLegenda>(find.byType(MarcadorLegenda));
      expect(marcador.item.cor, const Color(0xFF2E7D32));
    });

    testWidgets('nao aparece quando nao ha dado a legendar', (tester) async {
      await montar(
        tester,
        dados: const AsyncValue.data(<int>[]),
        legenda: (_) => const [
          ItemLegenda(rotulo: 'Custo fixo', cor: Color(0xFF2E7D32)),
        ],
      );

      expect(find.byType(MarcadorLegenda), findsNothing);
    });

    testWidgets('muitos itens quebram em linhas, sem estourar', (tester) async {
      await montar(
        tester,
        dados: const AsyncValue.data([1]),
        legenda: (_) => const [
          ItemLegenda(rotulo: 'Custo fixo do mês', cor: Color(0xFF2E7D32)),
          ItemLegenda(rotulo: 'Conforto da casa', cor: Color(0xFF1565C0)),
          ItemLegenda(rotulo: 'Investimento longo', cor: Color(0xFF00838F)),
          ItemLegenda(rotulo: 'Metas de viagem', cor: Color(0xFFEF6C00)),
          ItemLegenda(rotulo: 'Prazer e lazer', cor: Color(0xFFAD1457)),
          ItemLegenda(rotulo: 'Conhecimento', cor: Color(0xFF4527A0)),
        ],
      );

      expect(find.byType(Wrap), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

bool _sempreVazio(List<int> l) => l.isEmpty;
List<ItemLegenda> _semLegenda(List<int> l) => const [];
void _nada() {}
Widget _nuncaConstroi(List<int> l) => const Text('nunca');
