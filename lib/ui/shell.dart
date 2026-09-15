import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/providers.dart';
import 'telas/tela_cartoes.dart';
import 'telas/tela_ganhos.dart';
import 'telas/tela_gerenciar_casa.dart';
import 'telas/tela_graficos.dart';
import 'telas/tela_gastos.dart';
import 'telas/tela_parcelas.dart';
import 'telas/tela_potes.dart';
import 'telas/tela_resumo.dart';
import 'tema/tema.dart';
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
        actions: [
          const SeletorMes(),
          Builder(builder: (context) {
            final casa = ref.watch(casaProvider).value;
            final membro = ref.watch(membroLogadoProvider);
            if (casa == null || membro == null || membro.email != casa.donoEmail) {
              return const SizedBox.shrink();
            }
            return IconButton(
              key: const Key('botao_gerenciar_casa'),
              tooltip: 'Gerenciar casa',
              icon: const Icon(Icons.group),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TelaGerenciarCasa(
                  casaId: casa.id,
                  donoEmail: casa.donoEmail,
                ),
              )),
            );
          }),
          IconButton(
            key: const Key('botao_sair'),
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmarSair(context, ref),
          ),
        ],
      ),
      body: desktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _indice,
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: corDestaque,
                  selectedIconTheme: const IconThemeData(color: Colors.white),
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
      bottomNavigationBar: desktop ? null : _barraInferior(context),
    );
  }

  Future<void> _confirmarSair(BuildContext context, WidgetRef ref) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );
    if (confirmou ?? false) {
      await ref.read(servicoAuthProvider).sair();
    }
  }

  // Sao 7 destinos dividindo a largura da tela, entao em aparelhos estreitos
  // (ou com fonte do sistema aumentada) rotulos como "Parcelas" quebravam em
  // duas linhas enquanto "Gastos" e "Potes" ficavam em uma so, desalinhando os
  // itens. Aqui o rotulo e dimensionado para caber sempre em uma unica linha.
  Widget _barraInferior(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final larguraItem = MediaQuery.sizeOf(context).width / _destinos.length;
    // ~4,2 em de largura para o rotulo mais longo, menos uma folga entre itens.
    final tamanhoRotulo = ((larguraItem - 6) / 4.2).clamp(9.0, 12.0);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: DefaultTextStyle.merge(
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            iconTheme: WidgetStateProperty.resolveWith((estados) {
              final selecionado = estados.contains(WidgetState.selected);
              return IconThemeData(
                color: selecionado ? Colors.white : esquema.onSurfaceVariant,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((estados) {
              final selecionado = estados.contains(WidgetState.selected);
              return tema.textTheme.labelMedium!.copyWith(
                fontSize: tamanhoRotulo,
                height: 1.1,
                color:
                    selecionado ? esquema.onSurface : esquema.onSurfaceVariant,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _indice,
            indicatorColor: corDestaque,
            onDestinationSelected: (i) => setState(() => _indice = i),
            destinations: [
              for (final d in _destinos)
                NavigationDestination(
                  icon: Icon(d.icone),
                  label: d.rotulo,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
