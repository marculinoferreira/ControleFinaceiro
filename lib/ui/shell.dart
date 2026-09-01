import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'telas/tela_cartoes.dart';
import 'telas/tela_ganhos.dart';
import 'telas/tela_graficos.dart';
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
  _Destino('Cartões', Icons.credit_card),
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

    const telas = <Widget>[
      TelaResumo(),
      TelaGanhos(),
      TelaGastos(),
      TelaPotes(),
      TelaCartoes(),
      TelaParcelas(),
      TelaGraficos(),
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
