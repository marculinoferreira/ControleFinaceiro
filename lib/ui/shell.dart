import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'telas/tela_ganhos.dart';
import 'telas/tela_gastos.dart';
import 'telas/tela_parcelas.dart';
import 'telas/tela_potes.dart';
import 'telas/tela_resumo.dart';
import 'widgets/barra_totais.dart';
import 'widgets/seletor_mes.dart';

const double breakpointDesktop = 900;

class _Destino {
  final String rotulo;
  final IconData icone;
  const _Destino(this.rotulo, this.icone);
}

const List<_Destino> _destinos = [
  _Destino('Resumo', Icons.donut_large),
  _Destino('Ganhos', Icons.trending_up),
  _Destino('Gastos', Icons.receipt_long),
  _Destino('Potes', Icons.pie_chart_outline),
  _Destino('Parcelas', Icons.event_repeat),
  _Destino('Gráficos', Icons.insights),
];

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= breakpointDesktop;

    // Graficos ainda entra nesta fase; o resto ja e real.
    const telas = <Widget>[
      TelaResumo(),
      TelaGanhos(),
      TelaGastos(),
      TelaPotes(),
      TelaParcelas(),
      _ProximaFase('Gráficos'),
    ];
    final conteudo = telas[_indice];

    final corpo = Column(
      children: [
        const BarraTotais(),
        Expanded(child: conteudo),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle Financeiro'),
        centerTitle: false,
        actions: const [SeletorMes(), SizedBox(width: 8)],
      ),
      body: desktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _indice,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _indice = i),
                  destinations: [
                    for (final d in _destinos)
                      NavigationRailDestination(
                        icon: Icon(d.icone),
                        label: Text(d.rotulo),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: corpo),
              ],
            )
          : corpo,
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: _indice,
              onDestinationSelected: (i) => setState(() => _indice = i),
              destinations: [
                for (final d in _destinos)
                  NavigationDestination(
                    icon: Icon(d.icone),
                    label: d.rotulo,
                  ),
              ],
            ),
    );
  }
}

/// Placeholder honesto: diz que a tela existe e quando chega, em vez de
/// mostrar so o nome do destino e parecer uma tela quebrada.
class _ProximaFase extends StatelessWidget {
  final String nome;
  const _ProximaFase(this.nome);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction,
                size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(nome, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Esta tela chega na próxima fase.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
