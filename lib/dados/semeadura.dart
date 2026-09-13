import '../dominio/models/cartao.dart';
import '../dominio/models/casa.dart';
import '../dominio/models/membro.dart';
import '../dominio/models/pote.dart';
import 'repositorios.dart';

/// Configuracao inicial dos potes. Soma 100% — a validacao da tela de
/// Lei dos Potes depende disso.
List<Pote> potesPadrao() => const [
      Pote(id: '', nome: 'Custo fixo', percentual: 55, ordem: 0,
          cor: '#26797B', icone: 'casa'),
      Pote(id: '', nome: 'Conforto', percentual: 15, ordem: 1,
          cor: '#1565C0', icone: 'sofa'),
      Pote(id: '', nome: 'Investimento', percentual: 10, ordem: 2,
          cor: '#00838F', icone: 'grafico'),
      Pote(id: '', nome: 'Metas/Sonho', percentual: 10, ordem: 3,
          cor: '#EF6C00', icone: 'alvo'),
      Pote(id: '', nome: 'Prazer', percentual: 5, ordem: 4,
          cor: '#AD1457', icone: 'presente'),
      Pote(id: '', nome: 'Conhecimento', percentual: 5, ordem: 5,
          cor: '#4527A0', icone: 'livro'),
    ];

/// Cartoes e carteiras que a casa ja usa. E so um ponto de partida: a tela
/// de Cartoes permite renomear, remover e acrescentar.
List<Cartao> cartoesPadrao() => const [
      Cartao(id: '', nome: 'Inter', ordem: 0),
      Cartao(id: '', nome: 'Mercado Pago', ordem: 1),
      Cartao(id: '', nome: 'Nubank', ordem: 2),
      Cartao(id: '', nome: 'Magazine Luiza', ordem: 3),
      Cartao(id: '', nome: 'Sicoob', ordem: 4),
    ];

Casa casaPadrao() => const Casa(
      id: 'principal',
      nome: 'Casa Marcos & Silvia',
      membros: [
        Membro(
          id: 'marcos',
          nome: 'Marcos',
          email: 'marcos.centrone@gmail.com',
          cor: '#2E7D32',
          ordem: 0,
        ),
        Membro(
          id: 'silvia',
          nome: 'Silvia',
          email: 'silviabborges3@gmail.com',
          cor: '#6A1B9A',
          ordem: 1,
        ),
      ],
    );

/// Cria casa e potes no primeiro acesso, para que o usuario nao caia em uma
/// tela vazia sem saida: sem pote nao da para lancar gasto, e o Resumo nao
/// tem o que calcular.
///
/// Nao sobrescreve nada que ja exista.
Future<void> semear({
  required RepositorioCasa casa,
  required RepositorioPotes potes,
  RepositorioCartoes? cartoes,
}) async {
  if (await casa.observar().first == null) {
    await casa.criar(casaPadrao());
  }
  if ((await potes.observar().first).isEmpty) {
    await potes.salvarTodos(potesPadrao());
  }
  // Opcional para nao quebrar quem ja chamava semear com dois argumentos.
  if (cartoes != null && (await cartoes.observar().first).isEmpty) {
    for (final cartao in cartoesPadrao()) {
      await cartoes.salvar(cartao);
    }
  }
}
