# Controle Financeiro Familiar — Fases 1 e 2 (Fundação e Domínio)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o projeto Flutter rodando em Windows e Android, com login funcionando e o motor de cálculo (cascata dos potes, geração de parcelas, totais) implementado e provado por testes.

**Architecture:** Três camadas. `lib/dominio/` é Dart puro — models imutáveis e funções de cálculo, sem nenhum import de Firebase ou Flutter, testável com `flutter test` sem rede. `lib/dados/` expõe repositórios como interfaces abstratas com implementação Firestore. `lib/estado/` são providers Riverpod que ligam os dois e entregam `AsyncValue` para a UI. As Fases 1 e 2 constroem essas três camadas mais o shell de navegação; as telas de CRUD ficam para o plano seguinte.

**Tech Stack:** Flutter 3.41.5, Dart 3.11.3, Firebase (core/auth/firestore), Riverpod, fl_chart, intl, uuid.

**Spec:** `docs/superpowers/specs/2026-08-30-controle-financeiro-familiar-design.md`

## Global Constraints

Estas valem para **todas** as tarefas. Os requisitos de cada tarefa incluem esta seção implicitamente.

- **`lib/dominio/` não pode importar `package:flutter`, `package:firebase_*` ou `package:cloud_firestore`.** Só `dart:core`, `dart:math` e outros arquivos de `dominio/`. Se um teste de domínio precisar de `flutter test` com binding, a camada foi violada.
- **`applicationId` do Android é exatamente `controle.finaceiro`** — sem o "n" de "financeiro". Precisa bater com o app já registrado no console Firebase. O nome do pacote Dart é `controle_financeiro` (grafia correta); são independentes.
- **Projeto Firebase:** `controlefinaceiro-b5a70`.
- **`mesRef` é sempre `String` no formato `"YYYY-MM"`** com zero à esquerda no mês (`"2026-08"`, nunca `"2026-8"`).
- **Comparação de dinheiro usa tolerância de meio centavo** (`0.005`). Nunca `==` entre doubles monetários, nunca `> 0` puro para decidir se sobrou dinheiro.
- **Máximo 6 potes**, e a soma dos percentuais precisa ser exatamente 100 (dentro da tolerância).
- **Moeda BRL, formatação pt-BR** (`R$ 1.234,56`).
- **Breakpoint responsivo: 900 px.**
- **Nomes de identificadores em português** (`calcularCascata`, `poteAtivo`, `mesRef`), seguindo o vocabulário do spec.
- **Um commit por tarefa**, com a mensagem indicada no último passo.

## Estrutura de arquivos

Criados nestas duas fases:

| Arquivo | Responsabilidade |
|---|---|
| `lib/dominio/models/mes_ref.dart` | Value object do mês; toda aritmética de data vive aqui |
| `lib/dominio/models/pote.dart` | Categoria de orçamento |
| `lib/dominio/models/membro.dart` | Pessoa da casa |
| `lib/dominio/models/casa.dart` | Espaço financeiro compartilhado |
| `lib/dominio/models/ganho.dart` | Entrada de renda |
| `lib/dominio/models/gasto.dart` | Lançamento de gasto, parcelado ou não |
| `lib/dominio/cascata.dart` | Motor da cascata + `ResultadoCascata` |
| `lib/dominio/parcelas.dart` | Geração de parcelas + agrupamento de compras em aberto |
| `lib/dominio/totais.dart` | Totais do mês, subtotais por pessoa, gasto por pote |
| `lib/dados/repositorios.dart` | Interfaces abstratas dos quatro repositórios |
| `lib/dados/repositorio_firestore.dart` | Implementação Firestore das quatro interfaces |
| `lib/dados/servico_auth.dart` | Login, logout, stream do usuário |
| `lib/dados/semeadura.dart` | Cria casa + 6 potes padrão no primeiro acesso |
| `lib/estado/providers.dart` | Providers Riverpod |
| `lib/ui/tema/formatadores.dart` | `R$`, percentual, mês por extenso |
| `lib/ui/tema/tema.dart` | ColorScheme e tipografia |
| `lib/ui/widgets/estados_async.dart` | Widgets de loading e erro reusados por toda tela |
| `lib/ui/widgets/seletor_mes.dart` | Navegação de mês na AppBar |
| `lib/ui/widgets/barra_totais.dart` | Faixa Ganhos · Gastos · Saldo |
| `lib/ui/telas/tela_login.dart` | Login e-mail/senha |
| `lib/ui/shell.dart` | NavigationRail (desktop) / BottomNavigationBar (mobile) |
| `lib/ui/app.dart` | MaterialApp, roteamento por estado de auth |
| `lib/main.dart` | Inicialização do Firebase + ProviderScope |
| `firestore.rules` | Regras de segurança |
| `firestore.indexes.json` | Os três índices compostos |

---

### Task 1: Scaffold do projeto Flutter

Cria o projeto no diretório que já contém `.git`, `README.md` e `docs/`. Ao final, o app padrão do Flutter roda no Windows.

**Files:**
- Create: estrutura completa do `flutter create` (`lib/`, `android/`, `windows/`, `pubspec.yaml`, `analysis_options.yaml`)
- Modify: `android/app/build.gradle.kts`
- Modify: `.gitignore`
- Move: `app/google-services.json` → `android/app/google-services.json`

**Interfaces:**
- Consumes: nada — é a primeira tarefa.
- Produces: projeto Flutter compilável chamado `controle_financeiro`, com as dependências `firebase_core`, `firebase_auth`, `cloud_firestore`, `flutter_riverpod`, `fl_chart`, `intl`, `uuid` resolvidas.

- [ ] **Step 1: Confirmar que o ambiente compila para as duas plataformas**

```powershell
flutter doctor -v
```

Esperado: seção "Windows Version" OK e "Visual Studio - develop Windows apps" com check verde. Se o Visual Studio aparecer com X, instale a carga de trabalho **"Desenvolvimento para desktop com C++"** antes de continuar — sem ela `flutter build windows` falha, e falha tarde.

- [ ] **Step 2: Gerar o projeto no diretório atual**

```powershell
flutter create --project-name controle_financeiro --org controle --platforms=windows,android .
```

O `.` no fim é intencional: gera dentro do diretório existente sem apagar `.git`, `docs/` ou `README.md`.

- [ ] **Step 3: Adicionar as dependências**

```powershell
flutter pub add firebase_core firebase_auth cloud_firestore flutter_riverpod fl_chart intl uuid
```

Use `pub add` em vez de editar `pubspec.yaml` à mão — ele resolve as versões compatíveis entre si e com o SDK instalado.

- [ ] **Step 4: Corrigir o applicationId do Android**

Em `android/app/build.gradle.kts`, dentro de `defaultConfig`, troque a linha do `applicationId` por:

```kotlin
applicationId = "controle.finaceiro"
```

Deixe o `namespace` como o `flutter create` gerou. `applicationId` e `namespace` são independentes; só o primeiro precisa bater com o Firebase.

- [ ] **Step 5: Posicionar o google-services.json**

```powershell
Move-Item app\google-services.json android\app\google-services.json -Force
Remove-Item app -Recurse
```

- [ ] **Step 6: Ignorar os artefatos que não vão para o repositório**

Acrescente ao final de `.gitignore`:

```gitignore
# Firebase — gerados por flutterfire configure
lib/firebase_options.dart
android/app/google-services.json
.firebase/
```

Esses arquivos carregam chaves específicas do projeto e são regenerados pelo CLI em qualquer máquina.

- [ ] **Step 7: Verificar que compila e roda**

```powershell
flutter analyze
flutter run -d windows
```

Esperado: `analyze` sem erros, e a janela do contador padrão do Flutter abrindo. Feche a janela.

- [ ] **Step 8: Commit**

```powershell
git add -A
git commit -m "chore: scaffold do projeto Flutter para Windows e Android"
```

---

### Task 2: MesRef — value object do mês

Toda aritmética de mês do app passa por aqui. É a primeira tarefa com teste porque a virada de ano em parcelamento é o erro mais provável do projeto inteiro.

**Files:**
- Create: `lib/dominio/models/mes_ref.dart`
- Test: `test/dominio/mes_ref_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `class MesRef implements Comparable<MesRef>` com `MesRef(int ano, int mes)`, `MesRef.parse(String)`, `MesRef.atual()`, `MesRef.deDateTime(DateTime)`, `String get valor`, `MesRef avancar(int meses)`, `int diferencaEm(MesRef outro)`, `String formatarExtenso()`, `String formatarCurto()`. Usado por `Ganho`, `Gasto`, `parcelas.dart`, `seletor_mes.dart`.

- [ ] **Step 1: Escrever os testes que falham**

Crie `test/dominio/mes_ref_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';

void main() {
  group('MesRef.parse', () {
    test('aceita formato YYYY-MM', () {
      final mes = MesRef.parse('2026-08');
      expect(mes.ano, 2026);
      expect(mes.mes, 8);
    });

    test('rejeita mes sem zero a esquerda', () {
      expect(() => MesRef.parse('2026-8'), throwsFormatException);
    });

    test('rejeita mes 13', () {
      expect(() => MesRef.parse('2026-13'), throwsFormatException);
    });

    test('rejeita mes 00', () {
      expect(() => MesRef.parse('2026-00'), throwsFormatException);
    });

    test('rejeita texto livre', () {
      expect(() => MesRef.parse('agosto'), throwsFormatException);
    });
  });

  group('valor', () {
    test('sempre usa zero a esquerda', () {
      expect(const MesRef(2026, 1).valor, '2026-01');
      expect(const MesRef(2026, 12).valor, '2026-12');
    });
  });

  group('avancar', () {
    test('avanca dentro do mesmo ano', () {
      expect(const MesRef(2026, 3).avancar(2).valor, '2026-05');
    });

    test('vira o ano para frente', () {
      expect(const MesRef(2026, 12).avancar(1).valor, '2027-01');
    });

    test('vira o ano para tras', () {
      expect(const MesRef(2026, 1).avancar(-1).valor, '2025-12');
    });

    test('avanca 24 meses da exatamente dois anos', () {
      expect(const MesRef(2026, 8).avancar(24).valor, '2028-08');
    });

    test('avancar zero devolve o mesmo mes', () {
      expect(const MesRef(2026, 8).avancar(0).valor, '2026-08');
    });

    test('parcela 10 a partir de agosto de 2026 cai em maio de 2027', () {
      // parcela N usa avancar(N - 1)
      expect(const MesRef(2026, 8).avancar(9).valor, '2027-05');
    });
  });

  group('diferencaEm', () {
    test('conta meses entre dois refs', () {
      expect(const MesRef(2027, 5).diferencaEm(const MesRef(2026, 8)), 9);
    });

    test('e negativa quando o outro e posterior', () {
      expect(const MesRef(2026, 8).diferencaEm(const MesRef(2027, 5)), -9);
    });
  });

  group('ordenacao e igualdade', () {
    test('ordena cronologicamente', () {
      final lista = [
        const MesRef(2027, 1),
        const MesRef(2026, 12),
        const MesRef(2026, 2),
      ]..sort();
      expect(lista.map((m) => m.valor).toList(),
          ['2026-02', '2026-12', '2027-01']);
    });

    test('dois meses iguais sao iguais e tem o mesmo hashCode', () {
      expect(const MesRef(2026, 8), const MesRef(2026, 8));
      expect(const MesRef(2026, 8).hashCode, const MesRef(2026, 8).hashCode);
    });
  });

  group('formatacao', () {
    test('extenso', () {
      expect(const MesRef(2026, 8).formatarExtenso(), 'Agosto/2026');
    });

    test('curto', () {
      expect(const MesRef(2026, 8).formatarCurto(), 'Ago/26');
    });
  });
}
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

```powershell
flutter test test/dominio/mes_ref_test.dart
```

Esperado: falha de compilação — `Target of URI doesn't exist: 'package:controle_financeiro/dominio/models/mes_ref.dart'`.

- [ ] **Step 3: Implementar MesRef**

Crie `lib/dominio/models/mes_ref.dart`:

```dart
/// Referencia de mes/ano no formato "YYYY-MM".
///
/// Concentra toda a aritmetica de meses do app. A virada de ano acontece
/// aqui e em nenhum outro lugar.
class MesRef implements Comparable<MesRef> {
  final int ano;
  final int mes; // 1..12

  const MesRef(this.ano, this.mes);

  static final RegExp _formato = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

  static const List<String> _nomes = [
    'Janeiro', 'Fevereiro', 'Marco', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  factory MesRef.parse(String valor) {
    if (!_formato.hasMatch(valor)) {
      throw FormatException('mesRef invalido, esperado "YYYY-MM"', valor);
    }
    return MesRef(
      int.parse(valor.substring(0, 4)),
      int.parse(valor.substring(5, 7)),
    );
  }

  factory MesRef.deDateTime(DateTime data) => MesRef(data.year, data.month);

  factory MesRef.atual() => MesRef.deDateTime(DateTime.now());

  String get valor => '$ano-${mes.toString().padLeft(2, '0')}';

  /// Avanca [meses] meses. Aceita valores negativos.
  MesRef avancar(int meses) {
    final total = ano * 12 + (mes - 1) + meses;
    return MesRef(total ~/ 12, total % 12 + 1);
  }

  /// Quantos meses este ref esta a frente de [outro]. Negativo se atras.
  int diferencaEm(MesRef outro) =>
      (ano * 12 + mes) - (outro.ano * 12 + outro.mes);

  /// "Agosto/2026"
  String formatarExtenso() => '${_nomes[mes - 1]}/$ano';

  /// "Ago/26"
  String formatarCurto() =>
      '${_nomes[mes - 1].substring(0, 3)}/${ano.toString().substring(2)}';

  @override
  int compareTo(MesRef outro) => diferencaEm(outro);

  @override
  bool operator ==(Object outro) =>
      outro is MesRef && outro.ano == ano && outro.mes == mes;

  @override
  int get hashCode => Object.hash(ano, mes);

  @override
  String toString() => valor;
}
```

Note o `_nomes` como lista constante em vez de `DateFormat` do `intl`: `DateFormat` com locale pt-BR exige `initializeDateFormatting()` assíncrono, o que tornaria o domínio dependente de inicialização e os testes não-determinísticos.

- [ ] **Step 4: Rodar os testes e confirmar que passam**

```powershell
flutter test test/dominio/mes_ref_test.dart
```

Esperado: `All tests passed!`, 17 testes.

- [ ] **Step 5: Commit**

```powershell
git add lib/dominio/models/mes_ref.dart test/dominio/mes_ref_test.dart
git commit -m "feat: MesRef com aritmetica de meses e virada de ano"
```

---

### Task 3: Models do domínio

Cinco models imutáveis com serialização de ida e volta para o Firestore.

**Files:**
- Create: `lib/dominio/models/pote.dart`, `membro.dart`, `casa.dart`, `ganho.dart`, `gasto.dart`
- Test: `test/dominio/models_test.dart`

**Interfaces:**
- Consumes: `MesRef` (Task 2).
- Produces:
  - `Pote({required String id, required String nome, required double percentual, required int ordem, required String cor, required String icone})` com `Pote.fromMap(String id, Map<String, dynamic>)`, `Map<String, dynamic> toMap()`, `copyWith`.
  - `Membro({required String id, required String nome, required String email, required String cor, required int ordem})` com `Membro.fromMap(String id, Map<String, dynamic>)`, `toMap()`.
  - `Casa({required String id, required String nome, required List<Membro> membros})` com `Casa.fromMap`, `Membro? membroPorEmail(String)`, `Membro? membroPorId(String)`.
  - `Ganho({required String id, required String mesRef, required String membroId, required String descricao, required double valor, required DateTime criadoEm})` com `fromMap`/`toMap`/`copyWith`.
  - `Gasto({required String id, required String mesRef, required String membroId, required String poteId, required String descricao, required double valor, required DateTime criadoEm, required bool parcelado, String? compraId, int? parcela, int? totalParcelas})` com `fromMap`/`toMap`/`copyWith` e `String get rotuloParcela` devolvendo `"3/10"` ou `""`.

- [ ] **Step 1: Escrever os testes que falham**

Crie `test/dominio/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';

void main() {
  group('Pote', () {
    final mapa = {
      'nome': 'Custo fixo',
      'percentual': 55,
      'ordem': 0,
      'cor': '#2E7D32',
      'icone': 'casa',
    };

    test('fromMap le o id de fora do mapa', () {
      final pote = Pote.fromMap('p1', mapa);
      expect(pote.id, 'p1');
      expect(pote.nome, 'Custo fixo');
      expect(pote.percentual, 55.0);
      expect(pote.ordem, 0);
    });

    test('aceita percentual gravado como int pelo Firestore', () {
      expect(Pote.fromMap('p1', mapa).percentual, isA<double>());
    });

    test('toMap nao inclui o id', () {
      expect(Pote.fromMap('p1', mapa).toMap().containsKey('id'), isFalse);
    });

    test('round-trip preserva os campos', () {
      final original = Pote.fromMap('p1', mapa);
      final volta = Pote.fromMap('p1', original.toMap());
      expect(volta.nome, original.nome);
      expect(volta.percentual, original.percentual);
      expect(volta.cor, original.cor);
    });

    test('copyWith troca so o campo pedido', () {
      final pote = Pote.fromMap('p1', mapa).copyWith(percentual: 40);
      expect(pote.percentual, 40.0);
      expect(pote.nome, 'Custo fixo');
    });
  });

  group('Casa', () {
    final casa = Casa.fromMap('principal', {
      'nome': 'Casa Marcos & Silvia',
      'membros': {
        'marcos': {
          'nome': 'Marcos',
          'email': 'marcos.centrone@gmail.com',
          'cor': '#2E7D32',
          'ordem': 0,
        },
        'silvia': {
          'nome': 'Silvia',
          'email': 'silviabborges3@gmail.com',
          'cor': '#6A1B9A',
          'ordem': 1,
        },
      },
    });

    test('membros vem ordenados por ordem', () {
      expect(casa.membros.map((m) => m.id).toList(), ['marcos', 'silvia']);
    });

    test('membroPorEmail encontra ignorando maiuscula', () {
      expect(casa.membroPorEmail('MARCOS.CENTRONE@GMAIL.COM')?.id, 'marcos');
    });

    test('membroPorEmail devolve null para desconhecido', () {
      expect(casa.membroPorEmail('outro@gmail.com'), isNull);
    });

    test('membroPorId devolve null para id inexistente', () {
      expect(casa.membroPorId('joao'), isNull);
    });
  });

  group('Ganho', () {
    test('round-trip preserva valor e mesRef', () {
      final ganho = Ganho(
        id: 'g1',
        mesRef: '2026-08',
        membroId: 'marcos',
        descricao: 'Salario',
        valor: 4200.50,
        criadoEm: DateTime.utc(2026, 8, 5),
      );
      final volta = Ganho.fromMap('g1', ganho.toMap());
      expect(volta.valor, 4200.50);
      expect(volta.mesRef, '2026-08');
      expect(volta.membroId, 'marcos');
    });
  });

  group('Gasto', () {
    Gasto base({
      bool parcelado = false,
      String? compraId,
      int? parcela,
      int? total,
    }) =>
        Gasto(
          id: 'x1',
          mesRef: '2026-08',
          membroId: 'marcos',
          poteId: 'p1',
          descricao: 'Geladeira',
          valor: 100,
          criadoEm: DateTime.utc(2026, 8, 5),
          parcelado: parcelado,
          compraId: compraId,
          parcela: parcela,
          totalParcelas: total,
        );

    test('rotuloParcela vazio quando nao e parcelado', () {
      expect(base().rotuloParcela, '');
    });

    test('rotuloParcela mostra parcela sobre total', () {
      final g = base(parcelado: true, compraId: 'c1', parcela: 3, total: 10);
      expect(g.rotuloParcela, '3/10');
    });

    test('round-trip preserva os campos de parcelamento', () {
      final g = base(parcelado: true, compraId: 'c1', parcela: 3, total: 10);
      final volta = Gasto.fromMap('x1', g.toMap());
      expect(volta.parcelado, isTrue);
      expect(volta.compraId, 'c1');
      expect(volta.parcela, 3);
      expect(volta.totalParcelas, 10);
    });

    test('round-trip de gasto simples mantem campos de parcela nulos', () {
      final volta = Gasto.fromMap('x1', base().toMap());
      expect(volta.parcelado, isFalse);
      expect(volta.compraId, isNull);
      expect(volta.parcela, isNull);
    });
  });
}
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

```powershell
flutter test test/dominio/models_test.dart
```

Esperado: falhas de URI inexistente para os cinco arquivos de model.

- [ ] **Step 3: Implementar os models**

`lib/dominio/models/pote.dart`:

```dart
/// Categoria de orcamento. A [ordem] define a prioridade na cascata.
class Pote {
  final String id;
  final String nome;
  final double percentual;
  final int ordem;
  final String cor;   // hex "#RRGGBB"
  final String icone; // chave textual mapeada para IconData na UI

  const Pote({
    required this.id,
    required this.nome,
    required this.percentual,
    required this.ordem,
    required this.cor,
    required this.icone,
  });

  factory Pote.fromMap(String id, Map<String, dynamic> mapa) => Pote(
        id: id,
        nome: mapa['nome'] as String,
        // Firestore devolve int quando o valor gravado nao tem decimal.
        percentual: (mapa['percentual'] as num).toDouble(),
        ordem: (mapa['ordem'] as num).toInt(),
        cor: mapa['cor'] as String? ?? '#607D8B',
        icone: mapa['icone'] as String? ?? 'carteira',
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'percentual': percentual,
        'ordem': ordem,
        'cor': cor,
        'icone': icone,
      };

  Pote copyWith({
    String? id,
    String? nome,
    double? percentual,
    int? ordem,
    String? cor,
    String? icone,
  }) =>
      Pote(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        percentual: percentual ?? this.percentual,
        ordem: ordem ?? this.ordem,
        cor: cor ?? this.cor,
        icone: icone ?? this.icone,
      );
}
```

`lib/dominio/models/membro.dart`:

```dart
/// Pessoa da casa. O id e um slug curto ("marcos"), nao o e-mail:
/// chave de mapa no Firestore com ponto exige FieldPath para acesso.
class Membro {
  final String id;
  final String nome;
  final String email;
  final String cor;
  final int ordem;

  const Membro({
    required this.id,
    required this.nome,
    required this.email,
    required this.cor,
    required this.ordem,
  });

  factory Membro.fromMap(String id, Map<String, dynamic> mapa) => Membro(
        id: id,
        nome: mapa['nome'] as String,
        email: mapa['email'] as String,
        cor: mapa['cor'] as String? ?? '#607D8B',
        ordem: (mapa['ordem'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'email': email,
        'cor': cor,
        'ordem': ordem,
      };
}
```

`lib/dominio/models/casa.dart`:

```dart
import 'membro.dart';

/// Espaco financeiro compartilhado pelo casal.
class Casa {
  final String id;
  final String nome;
  final List<Membro> membros; // sempre ordenados por Membro.ordem

  const Casa({required this.id, required this.nome, required this.membros});

  factory Casa.fromMap(String id, Map<String, dynamic> mapa) {
    final bruto = (mapa['membros'] as Map<String, dynamic>? ?? {});
    final membros = bruto.entries
        .map((e) => Membro.fromMap(e.key, e.value as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
    return Casa(id: id, nome: mapa['nome'] as String? ?? 'Casa', membros: membros);
  }

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'membros': {for (final m in membros) m.id: m.toMap()},
      };

  Membro? membroPorEmail(String email) {
    final alvo = email.trim().toLowerCase();
    for (final m in membros) {
      if (m.email.toLowerCase() == alvo) return m;
    }
    return null;
  }

  Membro? membroPorId(String id) {
    for (final m in membros) {
      if (m.id == id) return m;
    }
    return null;
  }
}
```

`lib/dominio/models/ganho.dart`:

```dart
/// Entrada de renda de uma pessoa em um mes.
class Ganho {
  final String id;
  final String mesRef;
  final String membroId;
  final String descricao;
  final double valor;
  final DateTime criadoEm;

  const Ganho({
    required this.id,
    required this.mesRef,
    required this.membroId,
    required this.descricao,
    required this.valor,
    required this.criadoEm,
  });

  factory Ganho.fromMap(String id, Map<String, dynamic> mapa) => Ganho(
        id: id,
        mesRef: mapa['mesRef'] as String,
        membroId: mapa['membroId'] as String,
        descricao: mapa['descricao'] as String,
        valor: (mapa['valor'] as num).toDouble(),
        criadoEm: _lerData(mapa['criadoEm']),
      );

  Map<String, dynamic> toMap() => {
        'mesRef': mesRef,
        'membroId': membroId,
        'descricao': descricao,
        'valor': valor,
        'criadoEm': criadoEm,
      };

  Ganho copyWith({
    String? id,
    String? mesRef,
    String? membroId,
    String? descricao,
    double? valor,
    DateTime? criadoEm,
  }) =>
      Ganho(
        id: id ?? this.id,
        mesRef: mesRef ?? this.mesRef,
        membroId: membroId ?? this.membroId,
        descricao: descricao ?? this.descricao,
        valor: valor ?? this.valor,
        criadoEm: criadoEm ?? this.criadoEm,
      );
}

/// O Firestore devolve Timestamp; os testes de dominio passam DateTime.
/// Converter aqui mantem o dominio livre de import do cloud_firestore:
/// Timestamp expoe toDate() e e aceito via duck typing dinamico.
DateTime _lerData(dynamic bruto) {
  if (bruto is DateTime) return bruto;
  if (bruto == null) return DateTime.now();
  return (bruto as dynamic).toDate() as DateTime;
}
```

`lib/dominio/models/gasto.dart`:

```dart
/// Lancamento de gasto. Quando [parcelado], compartilha [compraId] com as
/// demais parcelas da mesma compra.
class Gasto {
  final String id;
  final String mesRef;
  final String membroId;
  final String poteId;
  final String descricao;
  final double valor;
  final DateTime criadoEm;
  final bool parcelado;
  final String? compraId;
  final int? parcela;
  final int? totalParcelas;

  const Gasto({
    required this.id,
    required this.mesRef,
    required this.membroId,
    required this.poteId,
    required this.descricao,
    required this.valor,
    required this.criadoEm,
    required this.parcelado,
    this.compraId,
    this.parcela,
    this.totalParcelas,
  });

  factory Gasto.fromMap(String id, Map<String, dynamic> mapa) => Gasto(
        id: id,
        mesRef: mapa['mesRef'] as String,
        membroId: mapa['membroId'] as String,
        poteId: mapa['poteId'] as String,
        descricao: mapa['descricao'] as String,
        valor: (mapa['valor'] as num).toDouble(),
        criadoEm: _lerData(mapa['criadoEm']),
        parcelado: mapa['parcelado'] as bool? ?? false,
        compraId: mapa['compraId'] as String?,
        parcela: (mapa['parcela'] as num?)?.toInt(),
        totalParcelas: (mapa['totalParcelas'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        'mesRef': mesRef,
        'membroId': membroId,
        'poteId': poteId,
        'descricao': descricao,
        'valor': valor,
        'criadoEm': criadoEm,
        'parcelado': parcelado,
        'compraId': compraId,
        'parcela': parcela,
        'totalParcelas': totalParcelas,
      };

  /// "3/10" quando parcelado, string vazia caso contrario.
  String get rotuloParcela =>
      parcelado && parcela != null && totalParcelas != null
          ? '$parcela/$totalParcelas'
          : '';

  Gasto copyWith({
    String? id,
    String? mesRef,
    String? membroId,
    String? poteId,
    String? descricao,
    double? valor,
    DateTime? criadoEm,
    bool? parcelado,
    String? compraId,
    int? parcela,
    int? totalParcelas,
  }) =>
      Gasto(
        id: id ?? this.id,
        mesRef: mesRef ?? this.mesRef,
        membroId: membroId ?? this.membroId,
        poteId: poteId ?? this.poteId,
        descricao: descricao ?? this.descricao,
        valor: valor ?? this.valor,
        criadoEm: criadoEm ?? this.criadoEm,
        parcelado: parcelado ?? this.parcelado,
        compraId: compraId ?? this.compraId,
        parcela: parcela ?? this.parcela,
        totalParcelas: totalParcelas ?? this.totalParcelas,
      );
}

DateTime _lerData(dynamic bruto) {
  if (bruto is DateTime) return bruto;
  if (bruto == null) return DateTime.now();
  return (bruto as dynamic).toDate() as DateTime;
}
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

```powershell
flutter test test/dominio/models_test.dart
```

Esperado: `All tests passed!`, 15 testes.

- [ ] **Step 5: Commit**

```powershell
git add lib/dominio/models test/dominio/models_test.dart
git commit -m "feat: models do dominio com serializacao Firestore"
```

---

### Task 4: Motor da cascata

A regra de negócio central. O gasto **total** escorre pela fila de potes na ordem de prioridade; o pote de cada gasto individual é classificação para gráficos, não entra aqui.

**Files:**
- Create: `lib/dominio/cascata.dart`
- Test: `test/dominio/cascata_test.dart`

**Interfaces:**
- Consumes: `Pote` (Task 3).
- Produces:
  - `const double toleranciaCentavo = 0.005;`
  - `class LinhaCascata { final Pote pote; final double previsto, consumido, sobra; }`
  - `class ResultadoCascata { final List<LinhaCascata> linhas; final Pote? poteAtivo; final double excedente; bool get estourouTudo; String get rotulo; }`
  - `ResultadoCascata calcularCascata({required List<Pote> potes, required double totalGanhos, required double totalGastos})`

- [ ] **Step 1: Escrever os testes que falham**

Crie `test/dominio/cascata_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/cascata.dart';
import 'package:controle_financeiro/dominio/models/pote.dart';

/// Seis potes somando 100%, na ordem de prioridade do spec.
List<Pote> potesPadrao() => const [
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

void main() {
  const ganhos = 5000.0;

  test('sem gastos, o pote ativo e o primeiro e nada foi consumido', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 0);

    expect(r.poteAtivo?.id, 'p1');
    expect(r.rotulo, 'CUSTO FIXO');
    expect(r.excedente, 0);
    expect(r.linhas.every((l) => l.consumido == 0), isTrue);
    expect(r.linhas.first.sobra, 2750);
  });

  test('gasto de 3900 para no meio do terceiro pote', () {
    // 2750 (p1) + 750 (p2) = 3500 consumidos; sobram 400 para p3 (previsto 500)
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 3900);

    expect(r.poteAtivo?.id, 'p3');
    expect(r.rotulo, 'INVESTIMENTO');

    expect(r.linhas[0].consumido, 2750);
    expect(r.linhas[0].sobra, 0);
    expect(r.linhas[1].consumido, 750);
    expect(r.linhas[1].sobra, 0);
    expect(r.linhas[2].consumido, 400);
    expect(r.linhas[2].sobra, 100);
    // Potes seguintes intactos
    expect(r.linhas[3].consumido, 0);
    expect(r.linhas[3].sobra, 500);
    expect(r.excedente, 0);
  });

  test('gasto exatamente igual ao previsto do pote 1 joga o ativo para o 2', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 2750);

    // Sobra zero no p1 nao conta como folga: a agua ja passou dele.
    expect(r.linhas[0].sobra, 0);
    expect(r.poteAtivo?.id, 'p2');
    expect(r.rotulo, 'CONFORTO');
  });

  test('gasto acima da renda estoura todos os potes', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 5600);

    expect(r.poteAtivo, isNull);
    expect(r.estourouTudo, isTrue);
    expect(r.rotulo, 'PARE DE GASTAR');
    expect(r.excedente, closeTo(600, 0.001));
    expect(r.linhas.every((l) => l.sobra == 0), isTrue);
  });

  test('lista de potes vazia nao lanca e devolve todo o gasto como excedente', () {
    final r = calcularCascata(
        potes: const [], totalGanhos: ganhos, totalGastos: 1200);

    expect(r.linhas, isEmpty);
    expect(r.poteAtivo, isNull);
    expect(r.excedente, 1200);
    expect(r.rotulo, 'PARE DE GASTAR');
  });

  test('renda zero com gasto positivo estoura tudo', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: 0, totalGastos: 300);

    expect(r.linhas.every((l) => l.previsto == 0), isTrue);
    expect(r.poteAtivo, isNull);
    expect(r.excedente, 300);
  });

  test('renda zero e gasto zero nao estoura', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: 0, totalGastos: 0);

    expect(r.excedente, 0);
    expect(r.estourouTudo, isTrue); // nenhum pote tem folga: previsto e zero
  });

  test('a soma dos previstos iguala a renda quando os potes somam 100%', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 0);

    final soma = r.linhas.fold<double>(0, (a, l) => a + l.previsto);
    expect(soma, closeTo(ganhos, 0.005));
  });

  test('consumido mais sobra sempre igual ao previsto em cada linha', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 3900);

    for (final l in r.linhas) {
      expect(l.consumido + l.sobra, closeTo(l.previsto, 0.005));
    }
  });

  test('sobra de um centavo nao e engolida pela tolerancia', () {
    // previsto p1 = 2750; gasto 2749.99 deixa 1 centavo de folga
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 2749.99);

    expect(r.poteAtivo?.id, 'p1');
  });

  test('sobra menor que meio centavo conta como zero', () {
    final r = calcularCascata(
        potes: potesPadrao(), totalGanhos: ganhos, totalGastos: 2749.999);

    expect(r.poteAtivo?.id, 'p2');
  });

  test('respeita a ordem do campo ordem, nao a ordem da lista', () {
    final foraDeOrdem = [potesPadrao()[1], potesPadrao()[0]];
    final r = calcularCascata(
        potes: foraDeOrdem, totalGanhos: ganhos, totalGastos: 0);

    expect(r.linhas.first.pote.id, 'p1');
  });
}
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

```powershell
flutter test test/dominio/cascata_test.dart
```

Esperado: falha de URI inexistente para `cascata.dart`.

- [ ] **Step 3: Implementar o motor**

Crie `lib/dominio/cascata.dart`:

```dart
import 'dart:math' as math;

import 'models/pote.dart';

/// Meio centavo. Comparacao de dinheiro em double nunca usa == nem > 0 puro.
const double toleranciaCentavo = 0.005;

/// Uma linha da tabela de resumo: quanto o pote previa, quanto a cascata
/// consumiu dele e quanto restou.
class LinhaCascata {
  final Pote pote;
  final double previsto;
  final double consumido;
  final double sobra;

  const LinhaCascata({
    required this.pote,
    required this.previsto,
    required this.consumido,
    required this.sobra,
  });
}

class ResultadoCascata {
  final List<LinhaCascata> linhas;

  /// Pote onde o gasto parou. Null quando o gasto passou de todos.
  final Pote? poteAtivo;

  /// Quanto de gasto sobrou depois de esgotar todos os potes.
  final double excedente;

  const ResultadoCascata({
    required this.linhas,
    required this.poteAtivo,
    required this.excedente,
  });

  bool get estourouTudo => poteAtivo == null;

  /// Rotulo exibido em destaque na tela de Resumo.
  String get rotulo => poteAtivo?.nome.toUpperCase() ?? 'PARE DE GASTAR';
}

/// Faz o gasto **total** escorrer pela fila de potes na ordem de prioridade.
///
/// Cada pote absorve ate o seu valor previsto; o que passar disso escorre
/// para o proximo. O pote ativo e o primeiro que ainda tem folga — e o que
/// a pessoa esta consumindo agora.
///
/// O pote de cada gasto individual NAO participa deste calculo; ele e
/// classificacao, usada nos graficos.
ResultadoCascata calcularCascata({
  required List<Pote> potes,
  required double totalGanhos,
  required double totalGastos,
}) {
  final ordenados = [...potes]..sort((a, b) => a.ordem.compareTo(b.ordem));

  var restante = totalGastos;
  final linhas = <LinhaCascata>[];
  Pote? poteAtivo;

  for (final pote in ordenados) {
    final previsto = totalGanhos * pote.percentual / 100;
    final consumido = math.min(restante, previsto);
    final sobra = previsto - consumido;
    restante -= consumido;

    if (poteAtivo == null && sobra > toleranciaCentavo) {
      poteAtivo = pote;
    }

    linhas.add(LinhaCascata(
      pote: pote,
      previsto: previsto,
      consumido: consumido,
      sobra: sobra,
    ));
  }

  return ResultadoCascata(
    linhas: linhas,
    poteAtivo: poteAtivo,
    excedente: restante,
  );
}
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

```powershell
flutter test test/dominio/cascata_test.dart
```

Esperado: `All tests passed!`, 12 testes.

- [ ] **Step 5: Commit**

```powershell
git add lib/dominio/cascata.dart test/dominio/cascata_test.dart
git commit -m "feat: motor da cascata dos potes com rotulo de pote ativo"
```

---

### Task 5: Geração e agrupamento de parcelas

**Files:**
- Create: `lib/dominio/parcelas.dart`
- Test: `test/dominio/parcelas_test.dart`

**Interfaces:**
- Consumes: `Gasto` (Task 3), `MesRef` (Task 2).
- Produces:
  - `List<Gasto> gerarParcelas({required Gasto base, required int quantidade, required String compraId})` — o `compraId` entra por parâmetro, e não é gerado dentro, para que a função seja determinística e testável; quem chama (o repositório) gera o uuid.
  - `class CompraParcelada { final String compraId, descricao, membroId, poteId; final double valorParcela; final int parcelaAtual, totalParcelas; int get parcelasRestantes; String get resumo; }`
  - `List<CompraParcelada> agruparParcelasEmAberto({required List<Gasto> gastos, required MesRef mesAtual})`

- [ ] **Step 1: Escrever os testes que falham**

Crie `test/dominio/parcelas_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/dominio/parcelas.dart';

Gasto gastoBase({String mesRef = '2026-08', double valor = 100}) => Gasto(
      id: '',
      mesRef: mesRef,
      membroId: 'marcos',
      poteId: 'p2',
      descricao: 'Geladeira',
      valor: valor,
      criadoEm: DateTime.utc(2026, 8, 5),
      parcelado: false,
    );

void main() {
  group('gerarParcelas', () {
    test('10x a partir de agosto de 2026 termina em maio de 2027', () {
      final ps = gerarParcelas(
          base: gastoBase(), quantidade: 10, compraId: 'c1');

      expect(ps, hasLength(10));
      expect(ps.first.mesRef, '2026-08');
      expect(ps.last.mesRef, '2027-05');
    });

    test('numera as parcelas de 1 a N', () {
      final ps = gerarParcelas(
          base: gastoBase(), quantidade: 10, compraId: 'c1');

      expect(ps.map((g) => g.parcela).toList(),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(ps.every((g) => g.totalParcelas == 10), isTrue);
    });

    test('vira o ano corretamente', () {
      final ps = gerarParcelas(
          base: gastoBase(mesRef: '2026-12'), quantidade: 3, compraId: 'c1');

      expect(ps.map((g) => g.mesRef).toList(),
          ['2026-12', '2027-01', '2027-02']);
    });

    test('24x avanca exatamente dois anos', () {
      final ps = gerarParcelas(
          base: gastoBase(), quantidade: 24, compraId: 'c1');

      expect(ps.last.mesRef, '2028-07'); // parcela 24 = avancar(23)
    });

    test('todas compartilham compraId, pote e pessoa', () {
      final ps = gerarParcelas(
          base: gastoBase(), quantidade: 10, compraId: 'c1');

      expect(ps.every((g) => g.compraId == 'c1'), isTrue);
      expect(ps.every((g) => g.poteId == 'p2'), isTrue);
      expect(ps.every((g) => g.membroId == 'marcos'), isTrue);
      expect(ps.every((g) => g.parcelado), isTrue);
    });

    test('cada parcela vale o valor da parcela, nao o total', () {
      final ps = gerarParcelas(
          base: gastoBase(valor: 100), quantidade: 10, compraId: 'c1');

      expect(ps.every((g) => g.valor == 100), isTrue);
    });

    test('quantidade 1 devolve um gasto simples, nao parcelado', () {
      final ps = gerarParcelas(
          base: gastoBase(), quantidade: 1, compraId: 'c1');

      expect(ps, hasLength(1));
      expect(ps.single.parcelado, isFalse);
      expect(ps.single.compraId, isNull);
      expect(ps.single.parcela, isNull);
      expect(ps.single.totalParcelas, isNull);
    });

    test('quantidade zero lanca ArgumentError', () {
      expect(
        () => gerarParcelas(base: gastoBase(), quantidade: 0, compraId: 'c1'),
        throwsArgumentError,
      );
    });

    test('quantidade negativa lanca ArgumentError', () {
      expect(
        () => gerarParcelas(base: gastoBase(), quantidade: -3, compraId: 'c1'),
        throwsArgumentError,
      );
    });

    test('mesRef invalido no base lanca FormatException', () {
      expect(
        () => gerarParcelas(
            base: gastoBase(mesRef: '2026-8'), quantidade: 3, compraId: 'c1'),
        throwsFormatException,
      );
    });
  });

  group('agruparParcelasEmAberto', () {
    final compra = gerarParcelas(
        base: gastoBase(), quantidade: 10, compraId: 'c1');

    test('agrupa pela compra e usa a parcela mais proxima do mes atual', () {
      final abertas = agruparParcelasEmAberto(
        gastos: compra,
        mesAtual: const MesRef(2026, 10), // parcela 3
      );

      expect(abertas, hasLength(1));
      expect(abertas.single.parcelaAtual, 3);
      expect(abertas.single.totalParcelas, 10);
      expect(abertas.single.parcelasRestantes, 7);
      expect(abertas.single.valorParcela, 100);
    });

    test('formata o resumo como no spec', () {
      final abertas = agruparParcelasEmAberto(
        gastos: compra,
        mesAtual: const MesRef(2026, 10),
      );

      expect(abertas.single.resumo,
          'Geladeira — parcela 3/10 — R\$ 100,00/mês — faltam 7 meses');
    });

    test('usa singular quando falta um mes', () {
      final abertas = agruparParcelasEmAberto(
        gastos: compra,
        mesAtual: const MesRef(2027, 4), // parcela 9, falta 1
      );

      expect(abertas.single.resumo, endsWith('falta 1 mês'));
    });

    test('ignora compras ja quitadas', () {
      final abertas = agruparParcelasEmAberto(
        gastos: compra,
        mesAtual: const MesRef(2027, 6), // depois da ultima parcela
      );

      expect(abertas, isEmpty);
    });

    test('inclui a ultima parcela quando ela e o mes atual', () {
      final abertas = agruparParcelasEmAberto(
        gastos: compra,
        mesAtual: const MesRef(2027, 5),
      );

      expect(abertas.single.parcelaAtual, 10);
      expect(abertas.single.parcelasRestantes, 0);
      expect(abertas.single.resumo, endsWith('ultima parcela'));
    });

    test('ignora gastos nao parcelados', () {
      final abertas = agruparParcelasEmAberto(
        gastos: [gastoBase().copyWith(id: 'g9')],
        mesAtual: const MesRef(2026, 8),
      );

      expect(abertas, isEmpty);
    });

    test('separa compras diferentes', () {
      final outra = gerarParcelas(
        base: gastoBase(mesRef: '2026-09', valor: 250)
            .copyWith(descricao: 'Sofa'),
        quantidade: 4,
        compraId: 'c2',
      );

      final abertas = agruparParcelasEmAberto(
        gastos: [...compra, ...outra],
        mesAtual: const MesRef(2026, 10),
      );

      expect(abertas, hasLength(2));
      expect(abertas.map((c) => c.compraId).toSet(), {'c1', 'c2'});
    });

    test('ordena da compra que termina primeiro para a que termina por ultimo', () {
      final outra = gerarParcelas(
        base: gastoBase(mesRef: '2026-09', valor: 250)
            .copyWith(descricao: 'Sofa'),
        quantidade: 4,
        compraId: 'c2',
      );

      final abertas = agruparParcelasEmAberto(
        gastos: [...compra, ...outra],
        mesAtual: const MesRef(2026, 10),
      );

      // Sofa: 4 parcelas desde 09, no mes 10 esta na 2, faltam 2.
      // Geladeira: faltam 7.
      expect(abertas.first.compraId, 'c2');
    });
  });
}
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

```powershell
flutter test test/dominio/parcelas_test.dart
```

Esperado: falha de URI inexistente para `parcelas.dart`.

- [ ] **Step 3: Implementar**

Crie `lib/dominio/parcelas.dart`:

```dart
import 'models/gasto.dart';
import 'models/mes_ref.dart';

/// Expande uma compra parcelada em um gasto por mes.
///
/// O [compraId] entra por parametro em vez de ser sorteado aqui dentro para
/// que a funcao seja deterministica e testavel; quem chama gera o uuid.
///
/// Com [quantidade] igual a 1 devolve um gasto simples, sem marcas de
/// parcelamento — uma compra "em 1x" nao e um parcelamento.
List<Gasto> gerarParcelas({
  required Gasto base,
  required int quantidade,
  required String compraId,
}) {
  if (quantidade <= 0) {
    throw ArgumentError.value(
        quantidade, 'quantidade', 'precisa ser maior que zero');
  }

  final inicio = MesRef.parse(base.mesRef); // valida o formato

  if (quantidade == 1) {
    return [
      Gasto(
        id: '',
        mesRef: base.mesRef,
        membroId: base.membroId,
        poteId: base.poteId,
        descricao: base.descricao,
        valor: base.valor,
        criadoEm: base.criadoEm,
        parcelado: false,
      ),
    ];
  }

  return List.generate(quantidade, (i) {
    return Gasto(
      id: '',
      mesRef: inicio.avancar(i).valor,
      membroId: base.membroId,
      poteId: base.poteId,
      descricao: base.descricao,
      valor: base.valor,
      criadoEm: base.criadoEm,
      parcelado: true,
      compraId: compraId,
      parcela: i + 1,
      totalParcelas: quantidade,
    );
  });
}

/// Uma compra parcelada vista do mes atual.
class CompraParcelada {
  final String compraId;
  final String descricao;
  final String membroId;
  final String poteId;
  final double valorParcela;
  final int parcelaAtual;
  final int totalParcelas;

  const CompraParcelada({
    required this.compraId,
    required this.descricao,
    required this.membroId,
    required this.poteId,
    required this.valorParcela,
    required this.parcelaAtual,
    required this.totalParcelas,
  });

  int get parcelasRestantes => totalParcelas - parcelaAtual;

  /// "Geladeira — parcela 3/10 — R$ 100,00/mês — faltam 7 meses"
  String get resumo {
    final valor = _formatarReais(valorParcela);
    final restante = parcelasRestantes == 0
        ? 'ultima parcela'
        : parcelasRestantes == 1
            ? 'falta 1 mês'
            : 'faltam $parcelasRestantes meses';
    return '$descricao — parcela $parcelaAtual/$totalParcelas '
        '— $valor/mês — $restante';
  }
}

/// Formatacao pt-BR sem depender do intl, para manter o dominio puro.
String _formatarReais(double valor) {
  final centavos = (valor * 100).round();
  final inteiro = (centavos ~/ 100).toString();
  final resto = (centavos % 100).toString().padLeft(2, '0');

  final buffer = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    if (i > 0 && (inteiro.length - i) % 3 == 0) buffer.write('.');
    buffer.write(inteiro[i]);
  }
  return r'R$ ' '$buffer,$resto';
}

/// Agrupa parcelas por compra e devolve so as que ainda nao terminaram,
/// ordenadas da que quita primeiro para a que quita por ultimo.
List<CompraParcelada> agruparParcelasEmAberto({
  required List<Gasto> gastos,
  required MesRef mesAtual,
}) {
  final porCompra = <String, List<Gasto>>{};

  for (final gasto in gastos) {
    if (!gasto.parcelado || gasto.compraId == null) continue;
    porCompra.putIfAbsent(gasto.compraId!, () => []).add(gasto);
  }

  final abertas = <CompraParcelada>[];

  for (final entrada in porCompra.entries) {
    // A parcela "corrente" e a primeira que cai em mesAtual ou depois.
    final futuras = entrada.value
        .where((g) => MesRef.parse(g.mesRef).compareTo(mesAtual) >= 0)
        .toList()
      ..sort((a, b) => a.parcela!.compareTo(b.parcela!));

    if (futuras.isEmpty) continue; // compra ja quitada

    final corrente = futuras.first;
    abertas.add(CompraParcelada(
      compraId: entrada.key,
      descricao: corrente.descricao,
      membroId: corrente.membroId,
      poteId: corrente.poteId,
      valorParcela: corrente.valor,
      parcelaAtual: corrente.parcela!,
      totalParcelas: corrente.totalParcelas!,
    ));
  }

  abertas.sort((a, b) => a.parcelasRestantes.compareTo(b.parcelasRestantes));
  return abertas;
}
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

```powershell
flutter test test/dominio/parcelas_test.dart
```

Esperado: `All tests passed!`, 18 testes.

- [ ] **Step 5: Commit**

```powershell
git add lib/dominio/parcelas.dart test/dominio/parcelas_test.dart
git commit -m "feat: geracao de parcelas e agrupamento de compras em aberto"
```

---

### Task 6: Totais e agregações do mês

**Files:**
- Create: `lib/dominio/totais.dart`
- Test: `test/dominio/totais_test.dart`

**Interfaces:**
- Consumes: `Ganho`, `Gasto`, `Pote` (Task 3).
- Produces:
  - `class TotaisMes { final double ganhos, gastos; double get saldo; }`
  - `TotaisMes calcularTotais({required List<Ganho> ganhos, required List<Gasto> gastos, String? membroId})` — com `membroId` nulo soma o casal.
  - `Map<String, double> somarGanhosPorMembro(List<Ganho>)`
  - `Map<String, double> somarGastosPorPote(List<Gasto> gastos, {String? membroId})`
  - `Map<String, double> somarGastosPorMembro(List<Gasto>)`
  - `double comprometidoNoMes(List<Gasto> gastos, String mesRef)` — total de parcelas caindo naquele mês, para o gráfico de comprometimento futuro.

- [ ] **Step 1: Escrever os testes que falham**

Crie `test/dominio/totais_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dominio/models/ganho.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';
import 'package:controle_financeiro/dominio/totais.dart';

Ganho ganho(String membroId, double valor, {String mesRef = '2026-08'}) =>
    Ganho(
      id: 'g${valor.toInt()}',
      mesRef: mesRef,
      membroId: membroId,
      descricao: 'Renda',
      valor: valor,
      criadoEm: DateTime.utc(2026, 8, 1),
    );

Gasto gasto(
  String membroId,
  String poteId,
  double valor, {
  String mesRef = '2026-08',
  bool parcelado = false,
}) =>
    Gasto(
      id: 'x${valor.toInt()}',
      mesRef: mesRef,
      membroId: membroId,
      poteId: poteId,
      descricao: 'Compra',
      valor: valor,
      criadoEm: DateTime.utc(2026, 8, 1),
      parcelado: parcelado,
      compraId: parcelado ? 'c1' : null,
      parcela: parcelado ? 1 : null,
      totalParcelas: parcelado ? 5 : null,
    );

void main() {
  final ganhos = [
    ganho('marcos', 4000),
    ganho('marcos', 500),
    ganho('silvia', 3000),
  ];

  final gastos = [
    gasto('marcos', 'p1', 1200),
    gasto('marcos', 'p2', 300),
    gasto('silvia', 'p1', 800),
  ];

  group('calcularTotais', () {
    test('sem membroId soma o casal', () {
      final t = calcularTotais(ganhos: ganhos, gastos: gastos);
      expect(t.ganhos, 7500);
      expect(t.gastos, 2300);
      expect(t.saldo, 5200);
    });

    test('com membroId filtra a pessoa', () {
      final t = calcularTotais(
          ganhos: ganhos, gastos: gastos, membroId: 'marcos');
      expect(t.ganhos, 4500);
      expect(t.gastos, 1500);
      expect(t.saldo, 3000);
    });

    test('membro sem lancamento devolve zeros, nao erro', () {
      final t = calcularTotais(
          ganhos: ganhos, gastos: gastos, membroId: 'joao');
      expect(t.ganhos, 0);
      expect(t.gastos, 0);
      expect(t.saldo, 0);
    });

    test('listas vazias devolvem zeros', () {
      final t = calcularTotais(ganhos: const [], gastos: const []);
      expect(t.saldo, 0);
    });

    test('saldo negativo quando gasta mais do que ganha', () {
      final t = calcularTotais(
        ganhos: [ganho('marcos', 1000)],
        gastos: [gasto('marcos', 'p1', 1600)],
      );
      expect(t.saldo, -600);
    });
  });

  group('somarGanhosPorMembro', () {
    test('soma as entradas de cada pessoa', () {
      expect(somarGanhosPorMembro(ganhos),
          {'marcos': 4500.0, 'silvia': 3000.0});
    });

    test('lista vazia devolve mapa vazio', () {
      expect(somarGanhosPorMembro(const []), isEmpty);
    });
  });

  group('somarGastosPorPote', () {
    test('agrupa por pote somando o casal', () {
      expect(somarGastosPorPote(gastos), {'p1': 2000.0, 'p2': 300.0});
    });

    test('filtra por membro quando pedido', () {
      expect(somarGastosPorPote(gastos, membroId: 'marcos'),
          {'p1': 1200.0, 'p2': 300.0});
    });
  });

  group('somarGastosPorMembro', () {
    test('agrupa por pessoa', () {
      expect(somarGastosPorMembro(gastos),
          {'marcos': 1500.0, 'silvia': 800.0});
    });
  });

  group('comprometidoNoMes', () {
    final futuros = [
      gasto('marcos', 'p2', 100, mesRef: '2026-09', parcelado: true),
      gasto('silvia', 'p2', 250, mesRef: '2026-09', parcelado: true),
      gasto('marcos', 'p2', 100, mesRef: '2026-10', parcelado: true),
      gasto('marcos', 'p1', 900, mesRef: '2026-09'), // nao parcelado
    ];

    test('soma so as parcelas do mes pedido', () {
      expect(comprometidoNoMes(futuros, '2026-09'), 350);
    });

    test('ignora gastos nao parcelados', () {
      expect(comprometidoNoMes(futuros, '2026-09'), isNot(1250));
    });

    test('mes sem parcelas devolve zero', () {
      expect(comprometidoNoMes(futuros, '2027-01'), 0);
    });
  });
}
```

- [ ] **Step 2: Rodar os testes e confirmar que falham**

```powershell
flutter test test/dominio/totais_test.dart
```

Esperado: falha de URI inexistente para `totais.dart`.

- [ ] **Step 3: Implementar**

Crie `lib/dominio/totais.dart`:

```dart
import 'models/ganho.dart';
import 'models/gasto.dart';

/// Totais de um mes, para uma pessoa ou para o casal.
class TotaisMes {
  final double ganhos;
  final double gastos;

  const TotaisMes({required this.ganhos, required this.gastos});

  /// "Saldo para passar o mes".
  double get saldo => ganhos - gastos;
}

/// Com [membroId] nulo, soma o casal inteiro.
TotaisMes calcularTotais({
  required List<Ganho> ganhos,
  required List<Gasto> gastos,
  String? membroId,
}) {
  var somaGanhos = 0.0;
  for (final g in ganhos) {
    if (membroId == null || g.membroId == membroId) somaGanhos += g.valor;
  }

  var somaGastos = 0.0;
  for (final g in gastos) {
    if (membroId == null || g.membroId == membroId) somaGastos += g.valor;
  }

  return TotaisMes(ganhos: somaGanhos, gastos: somaGastos);
}

Map<String, double> somarGanhosPorMembro(List<Ganho> ganhos) {
  final mapa = <String, double>{};
  for (final g in ganhos) {
    mapa[g.membroId] = (mapa[g.membroId] ?? 0) + g.valor;
  }
  return mapa;
}

Map<String, double> somarGastosPorMembro(List<Gasto> gastos) {
  final mapa = <String, double>{};
  for (final g in gastos) {
    mapa[g.membroId] = (mapa[g.membroId] ?? 0) + g.valor;
  }
  return mapa;
}

Map<String, double> somarGastosPorPote(List<Gasto> gastos, {String? membroId}) {
  final mapa = <String, double>{};
  for (final g in gastos) {
    if (membroId != null && g.membroId != membroId) continue;
    mapa[g.poteId] = (mapa[g.poteId] ?? 0) + g.valor;
  }
  return mapa;
}

/// Quanto de parcela ja esta comprometido em [mesRef].
/// Alimenta o grafico de comprometimento futuro.
double comprometidoNoMes(List<Gasto> gastos, String mesRef) {
  var soma = 0.0;
  for (final g in gastos) {
    if (g.parcelado && g.mesRef == mesRef) soma += g.valor;
  }
  return soma;
}
```

- [ ] **Step 4: Rodar os testes e confirmar que passam**

```powershell
flutter test test/dominio/totais_test.dart
```

Esperado: `All tests passed!`, 14 testes.

- [ ] **Step 5: Rodar a suíte inteira do domínio**

```powershell
flutter test test/dominio
flutter analyze
```

Esperado: todos os testes das Tasks 2–6 passando juntos, `analyze` limpo.

- [ ] **Step 6: Commit**

```powershell
git add lib/dominio/totais.dart test/dominio/totais_test.dart
git commit -m "feat: totais do mes e agregacoes por membro e por pote"
```

---

**Fim da Fase 2 do domínio.** Neste ponto toda a regra de negócio do app está implementada e provada, sem uma linha de Firebase ou de UI. As tarefas seguintes ligam isso ao mundo.

---

### Task 7: Interfaces dos repositórios e regras do Firestore

Define os contratos que a UI vai consumir e as regras de segurança, antes de qualquer implementação. As interfaces são o que permite testar providers com fakes.

**Files:**
- Create: `lib/dados/repositorios.dart`
- Create: `firestore.rules`
- Create: `firestore.indexes.json`
- Test: `test/dados/repositorios_fake_test.dart`

**Interfaces:**
- Consumes: models do domínio (Task 3), `gerarParcelas` (Task 5).
- Produces:
  - `abstract class RepositorioCasa { Stream<Casa?> observar(); Future<void> criar(Casa casa); }`
  - `abstract class RepositorioPotes { Stream<List<Pote>> observar(); Future<void> salvarTodos(List<Pote> potes); Future<void> remover(String id); }`
  - `abstract class RepositorioGanhos { Stream<List<Ganho>> observarMes(String mesRef); Future<void> adicionar(Ganho ganho); Future<void> atualizar(Ganho ganho); Future<void> remover(String id); }`
  - `abstract class RepositorioGastos { Stream<List<Gasto>> observarMes(String mesRef); Stream<List<Gasto>> observarParceladosDesde(String mesRef); Future<void> adicionar({required Gasto base, required int quantidadeParcelas}); Future<void> atualizar(Gasto gasto); Future<void> removerUma(String id); Future<void> removerDesta(String compraId, int parcela); Future<void> removerCompra(String compraId); }`
  - `enum ModoExclusao { somenteEsta, estaEFuturas, todas }`
  - `class RepositoriosFake` implementando as quatro interfaces em memória, usado pelos testes desta e das próximas tarefas.

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/dados/repositorios_fake_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/gasto.dart';

Gasto base({String mesRef = '2026-08'}) => Gasto(
      id: '',
      mesRef: mesRef,
      membroId: 'marcos',
      poteId: 'p2',
      descricao: 'Geladeira',
      valor: 100,
      criadoEm: DateTime.utc(2026, 8, 5),
      parcelado: false,
    );

void main() {
  group('RepositorioGastosFake', () {
    test('adicionar com 1 parcela grava um gasto simples', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 1);

      final gastos = await repo.observarMes('2026-08').first;
      expect(gastos, hasLength(1));
      expect(gastos.single.parcelado, isFalse);
    });

    test('adicionar com 10 parcelas grava uma em cada mes', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 10);

      expect(await repo.observarMes('2026-08').first, hasLength(1));
      expect(await repo.observarMes('2027-05').first, hasLength(1));
      expect(await repo.observarMes('2027-06').first, isEmpty);
    });

    test('todas as parcelas recebem ids distintos e o mesmo compraId',
        () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 10);

      final todos = repo.todos;
      expect(todos.map((g) => g.id).toSet(), hasLength(10));
      expect(todos.map((g) => g.compraId).toSet(), hasLength(1));
      expect(todos.first.compraId, isNotNull);
    });

    test('removerUma apaga so aquela parcela', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 10);
      final alvo = repo.todos.firstWhere((g) => g.parcela == 3);

      await repo.removerUma(alvo.id);

      expect(repo.todos, hasLength(9));
      expect(repo.todos.any((g) => g.parcela == 3), isFalse);
      expect(repo.todos.any((g) => g.parcela == 4), isTrue);
    });

    test('removerDesta apaga a parcela e as futuras', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 10);
      final compraId = repo.todos.first.compraId!;

      await repo.removerDesta(compraId, 4);

      expect(repo.todos, hasLength(3));
      expect(repo.todos.map((g) => g.parcela).toList(), [1, 2, 3]);
    });

    test('removerCompra apaga a compra inteira', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 10);
      final compraId = repo.todos.first.compraId!;

      await repo.removerCompra(compraId);

      expect(repo.todos, isEmpty);
    });

    test('observarParceladosDesde traz so parcelas do mes em diante', () async {
      final repo = RepositorioGastosFake();
      await repo.adicionar(base: base(), quantidadeParcelas: 10);
      await repo.adicionar(base: base(), quantidadeParcelas: 1); // simples

      final abertas = await repo.observarParceladosDesde('2026-10').first;

      expect(abertas, hasLength(8)); // parcelas 3..10
      expect(abertas.every((g) => g.parcelado), isTrue);
    });

    test('o stream reemite depois de cada escrita', () async {
      final repo = RepositorioGastosFake();
      final emissoes = <int>[];
      final assinatura =
          repo.observarMes('2026-08').listen((l) => emissoes.add(l.length));

      await repo.adicionar(base: base(), quantidadeParcelas: 1);
      await repo.adicionar(base: base(), quantidadeParcelas: 1);
      await Future<void>.delayed(Duration.zero);
      await assinatura.cancel();

      expect(emissoes.last, 2);
    });
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

```powershell
flutter test test/dados/repositorios_fake_test.dart
```

Esperado: falha de URI inexistente para `repositorios.dart`.

- [ ] **Step 3: Implementar as interfaces e os fakes**

Crie `lib/dados/repositorios.dart`:

```dart
import 'dart:async';

import '../dominio/models/casa.dart';
import '../dominio/models/ganho.dart';
import '../dominio/models/gasto.dart';
import '../dominio/models/mes_ref.dart';
import '../dominio/models/pote.dart';
import '../dominio/parcelas.dart';

/// O que fazer ao excluir uma parcela de uma compra parcelada.
enum ModoExclusao { somenteEsta, estaEFuturas, todas }

abstract class RepositorioCasa {
  Stream<Casa?> observar();
  Future<void> criar(Casa casa);
}

abstract class RepositorioPotes {
  Stream<List<Pote>> observar();

  /// Substitui a configuracao inteira. A validacao de "soma 100%" e de
  /// "no maximo 6" acontece na UI antes de chamar.
  Future<void> salvarTodos(List<Pote> potes);

  Future<void> remover(String id);
}

abstract class RepositorioGanhos {
  Stream<List<Ganho>> observarMes(String mesRef);
  Future<void> adicionar(Ganho ganho);
  Future<void> atualizar(Ganho ganho);
  Future<void> remover(String id);
}

abstract class RepositorioGastos {
  Stream<List<Gasto>> observarMes(String mesRef);

  /// Parcelas com mesRef >= [mesRef]. Alimenta "Parcelas em aberto" e o
  /// grafico de comprometimento futuro.
  Stream<List<Gasto>> observarParceladosDesde(String mesRef);

  /// Grava a compra. Com [quantidadeParcelas] maior que 1, expande em uma
  /// gravacao atomica de N documentos.
  Future<void> adicionar({required Gasto base, required int quantidadeParcelas});

  Future<void> atualizar(Gasto gasto);
  Future<void> removerUma(String id);
  Future<void> removerDesta(String compraId, int parcela);
  Future<void> removerCompra(String compraId);
}

// ---------------------------------------------------------------------------
// Fakes em memoria. Vivem em lib/ (nao em test/) porque os testes de widget
// das proximas tarefas tambem os injetam.
// ---------------------------------------------------------------------------

class RepositorioGastosFake implements RepositorioGastos {
  final List<Gasto> _gastos = [];
  final _controlador = StreamController<List<Gasto>>.broadcast();
  var _sequencia = 0;

  List<Gasto> get todos => List.unmodifiable(_gastos);

  void _emitir() => _controlador.add(List.unmodifiable(_gastos));

  Stream<List<Gasto>> _comValorInicial(List<Gasto> Function() filtro) async* {
    yield filtro();
    yield* _controlador.stream.map((_) => filtro());
  }

  @override
  Stream<List<Gasto>> observarMes(String mesRef) => _comValorInicial(
      () => _gastos.where((g) => g.mesRef == mesRef).toList());

  @override
  Stream<List<Gasto>> observarParceladosDesde(String mesRef) =>
      _comValorInicial(() => _gastos
          .where((g) =>
              g.parcelado &&
              MesRef.parse(g.mesRef).compareTo(MesRef.parse(mesRef)) >= 0)
          .toList());

  @override
  Future<void> adicionar({
    required Gasto base,
    required int quantidadeParcelas,
  }) async {
    final compraId = 'compra-${_sequencia++}';
    final novas = gerarParcelas(
      base: base,
      quantidade: quantidadeParcelas,
      compraId: compraId,
    );
    for (final g in novas) {
      _gastos.add(g.copyWith(id: 'gasto-${_sequencia++}'));
    }
    _emitir();
  }

  @override
  Future<void> atualizar(Gasto gasto) async {
    final i = _gastos.indexWhere((g) => g.id == gasto.id);
    if (i >= 0) _gastos[i] = gasto;
    _emitir();
  }

  @override
  Future<void> removerUma(String id) async {
    _gastos.removeWhere((g) => g.id == id);
    _emitir();
  }

  @override
  Future<void> removerDesta(String compraId, int parcela) async {
    _gastos.removeWhere(
        (g) => g.compraId == compraId && (g.parcela ?? 0) >= parcela);
    _emitir();
  }

  @override
  Future<void> removerCompra(String compraId) async {
    _gastos.removeWhere((g) => g.compraId == compraId);
    _emitir();
  }
}

class RepositorioGanhosFake implements RepositorioGanhos {
  final List<Ganho> _ganhos = [];
  final _controlador = StreamController<List<Ganho>>.broadcast();
  var _sequencia = 0;

  List<Ganho> get todos => List.unmodifiable(_ganhos);

  void _emitir() => _controlador.add(List.unmodifiable(_ganhos));

  @override
  Stream<List<Ganho>> observarMes(String mesRef) async* {
    List<Ganho> filtrar() =>
        _ganhos.where((g) => g.mesRef == mesRef).toList();
    yield filtrar();
    yield* _controlador.stream.map((_) => filtrar());
  }

  @override
  Future<void> adicionar(Ganho ganho) async {
    _ganhos.add(ganho.copyWith(id: 'ganho-${_sequencia++}'));
    _emitir();
  }

  @override
  Future<void> atualizar(Ganho ganho) async {
    final i = _ganhos.indexWhere((g) => g.id == ganho.id);
    if (i >= 0) _ganhos[i] = ganho;
    _emitir();
  }

  @override
  Future<void> remover(String id) async {
    _ganhos.removeWhere((g) => g.id == id);
    _emitir();
  }
}

class RepositorioPotesFake implements RepositorioPotes {
  List<Pote> _potes = [];
  final _controlador = StreamController<List<Pote>>.broadcast();

  RepositorioPotesFake([List<Pote> iniciais = const []]) {
    _potes = [...iniciais];
  }

  @override
  Stream<List<Pote>> observar() async* {
    yield List.unmodifiable(_potes);
    yield* _controlador.stream;
  }

  @override
  Future<void> salvarTodos(List<Pote> potes) async {
    _potes = [...potes];
    _controlador.add(List.unmodifiable(_potes));
  }

  @override
  Future<void> remover(String id) async {
    _potes.removeWhere((p) => p.id == id);
    _controlador.add(List.unmodifiable(_potes));
  }
}

class RepositorioCasaFake implements RepositorioCasa {
  Casa? _casa;
  final _controlador = StreamController<Casa?>.broadcast();

  RepositorioCasaFake([this._casa]);

  @override
  Stream<Casa?> observar() async* {
    yield _casa;
    yield* _controlador.stream;
  }

  @override
  Future<void> criar(Casa casa) async {
    _casa = casa;
    _controlador.add(casa);
  }
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

```powershell
flutter test test/dados/repositorios_fake_test.dart
```

Esperado: `All tests passed!`, 8 testes.

- [ ] **Step 5: Escrever as regras de segurança**

Crie `firestore.rules`:

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // Os dois e-mails autorizados vivem aqui, e nao em um documento:
    // um get() dentro da regra custaria uma leitura cobrada por requisicao,
    // e esta lista muda com a mesma frequencia que a propria regra.
    function autorizado() {
      return request.auth != null
          && request.auth.token.email in [
               'marcos.centrone@gmail.com',
               'silviabborges3@gmail.com'
             ];
    }

    match /casas/principal/{documento=**} {
      allow read, write: if autorizado();
    }
  }
}
```

Não há checagem de `email_verified`: contas criadas manualmente no console nascem não verificadas, e exigir verificação travaria os dois usuários na porta. Qualquer caminho fora de `casas/principal` é negado por omissão.

- [ ] **Step 6: Declarar os índices compostos**

Crie `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "ganhos",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "mesRef", "order": "ASCENDING" },
        { "fieldPath": "membroId", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "gastos",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "mesRef", "order": "ASCENDING" },
        { "fieldPath": "criadoEm", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "gastos",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "parcelado", "order": "ASCENDING" },
        { "fieldPath": "mesRef", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

- [ ] **Step 7: Commit**

```powershell
git add lib/dados/repositorios.dart test/dados firestore.rules firestore.indexes.json
git commit -m "feat: contratos dos repositorios, fakes em memoria e regras do Firestore"
```

---

### Task 8: Implementação Firestore dos repositórios

**Files:**
- Create: `lib/dados/repositorio_firestore.dart`
- Test: nenhum teste unitário novo — a corretude da expansão de parcelas já está coberta pela Task 5 (`gerarParcelas`) e pela Task 7 (fake). Esta tarefa é tradução para a API do Firestore, verificada em execução no Step 4.

**Interfaces:**
- Consumes: interfaces da Task 7, `gerarParcelas` (Task 5), models (Task 3).
- Produces: `CasaFirestore`, `PotesFirestore`, `GanhosFirestore`, `GastosFirestore`, todos recebendo `FirebaseFirestore` no construtor, e `const casaId = 'principal';`

- [ ] **Step 1: Implementar**

Crie `lib/dados/repositorio_firestore.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../dominio/models/casa.dart';
import '../dominio/models/ganho.dart';
import '../dominio/models/gasto.dart';
import '../dominio/models/pote.dart';
import '../dominio/parcelas.dart';
import 'repositorios.dart';

const String casaId = 'principal';

DocumentReference<Map<String, dynamic>> _casaDoc(FirebaseFirestore db) =>
    db.collection('casas').doc(casaId);

class CasaFirestore implements RepositorioCasa {
  final FirebaseFirestore db;
  CasaFirestore(this.db);

  @override
  Stream<Casa?> observar() => _casaDoc(db).snapshots().map(
      (d) => d.exists ? Casa.fromMap(d.id, d.data()!) : null);

  @override
  Future<void> criar(Casa casa) => _casaDoc(db).set(casa.toMap());
}

class PotesFirestore implements RepositorioPotes {
  final FirebaseFirestore db;
  PotesFirestore(this.db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _casaDoc(db).collection('potes');

  @override
  Stream<List<Pote>> observar() => _col.orderBy('ordem').snapshots().map(
      (s) => s.docs.map((d) => Pote.fromMap(d.id, d.data())).toList());

  /// Substitui a configuracao inteira em uma unica escrita atomica:
  /// apaga os potes que sumiram e grava os atuais com a ordem corrente.
  @override
  Future<void> salvarTodos(List<Pote> potes) async {
    final atuais = await _col.get();
    final mantidos = potes.map((p) => p.id).toSet();
    final lote = db.batch();

    for (final doc in atuais.docs) {
      if (!mantidos.contains(doc.id)) lote.delete(doc.reference);
    }
    for (var i = 0; i < potes.length; i++) {
      final pote = potes[i].copyWith(ordem: i);
      final ref = pote.id.isEmpty ? _col.doc() : _col.doc(pote.id);
      lote.set(ref, pote.toMap());
    }
    await lote.commit();
  }

  @override
  Future<void> remover(String id) => _col.doc(id).delete();
}

class GanhosFirestore implements RepositorioGanhos {
  final FirebaseFirestore db;
  GanhosFirestore(this.db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _casaDoc(db).collection('ganhos');

  @override
  Stream<List<Ganho>> observarMes(String mesRef) => _col
      .where('mesRef', isEqualTo: mesRef)
      .snapshots()
      .map((s) => s.docs.map((d) => Ganho.fromMap(d.id, d.data())).toList());

  @override
  Future<void> adicionar(Ganho ganho) => _col.add(ganho.toMap());

  @override
  Future<void> atualizar(Ganho ganho) =>
      _col.doc(ganho.id).update(ganho.toMap());

  @override
  Future<void> remover(String id) => _col.doc(id).delete();
}

class GastosFirestore implements RepositorioGastos {
  final FirebaseFirestore db;
  final Uuid _uuid = const Uuid();

  GastosFirestore(this.db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _casaDoc(db).collection('gastos');

  @override
  Stream<List<Gasto>> observarMes(String mesRef) => _col
      .where('mesRef', isEqualTo: mesRef)
      .orderBy('criadoEm', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Gasto.fromMap(d.id, d.data())).toList());

  @override
  Stream<List<Gasto>> observarParceladosDesde(String mesRef) => _col
      .where('parcelado', isEqualTo: true)
      .where('mesRef', isGreaterThanOrEqualTo: mesRef)
      .orderBy('mesRef')
      .snapshots()
      .map((s) => s.docs.map((d) => Gasto.fromMap(d.id, d.data())).toList());

  /// Ou entram todas as parcelas, ou nenhuma.
  @override
  Future<void> adicionar({
    required Gasto base,
    required int quantidadeParcelas,
  }) async {
    final novas = gerarParcelas(
      base: base,
      quantidade: quantidadeParcelas,
      compraId: _uuid.v4(),
    );
    final lote = db.batch();
    for (final g in novas) {
      lote.set(_col.doc(), g.toMap());
    }
    await lote.commit();
  }

  @override
  Future<void> atualizar(Gasto gasto) =>
      _col.doc(gasto.id).update(gasto.toMap());

  @override
  Future<void> removerUma(String id) => _col.doc(id).delete();

  @override
  Future<void> removerDesta(String compraId, int parcela) async {
    final alvo = await _col
        .where('compraId', isEqualTo: compraId)
        .where('parcela', isGreaterThanOrEqualTo: parcela)
        .get();
    await _apagarEmLote(alvo.docs);
  }

  @override
  Future<void> removerCompra(String compraId) async {
    final alvo = await _col.where('compraId', isEqualTo: compraId).get();
    await _apagarEmLote(alvo.docs);
  }

  /// Um WriteBatch aceita no maximo 500 operacoes.
  Future<void> _apagarEmLote(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    for (var i = 0; i < docs.length; i += 400) {
      final fatia = docs.skip(i).take(400);
      final lote = db.batch();
      for (final d in fatia) {
        lote.delete(d.reference);
      }
      await lote.commit();
    }
  }
}
```

- [ ] **Step 2: Verificar que compila**

```powershell
flutter analyze
```

Esperado: sem erros. Warnings de `unused_import` significam que algo ficou de fora.

- [ ] **Step 3: Rodar a suíte inteira**

```powershell
flutter test
```

Esperado: todos os testes das Tasks 2–7 continuam passando.

- [ ] **Step 4: Commit**

```powershell
git add lib/dados/repositorio_firestore.dart
git commit -m "feat: implementacao Firestore dos repositorios com escrita em lote"
```

> A verificação de que essas queries realmente funcionam contra o Firestore acontece na Task 12, depois que o Firebase estiver conectado. É lá que os índices compostos serão exigidos pelo servidor.

---

### Task 9: Autenticação e tela de Login

**Files:**
- Create: `lib/dados/servico_auth.dart`
- Create: `lib/ui/telas/tela_login.dart`
- Create: `lib/ui/tema/formatadores.dart`
- Test: `test/ui/tela_login_test.dart`

**Interfaces:**
- Consumes: nada do domínio.
- Produces:
  - `abstract class ServicoAuth { Stream<String?> observarEmail(); Future<void> entrar({required String email, required String senha}); Future<void> sair(); }` — o stream emite o e-mail do usuário logado, ou `null` quando deslogado.
  - `class AuthFirebase implements ServicoAuth`, `class AuthFake implements ServicoAuth`
  - `class ErroAuth implements Exception { final String mensagem; }`
  - `String formatarReais(double)`, `String formatarPercentual(double)` em `formatadores.dart`
  - `class TelaLogin extends ConsumerStatefulWidget`

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/ui/tela_login_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/servico_auth.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/telas/tela_login.dart';

Widget montar(ServicoAuth auth) => ProviderScope(
      overrides: [servicoAuthProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: TelaLogin()),
    );

void main() {
  testWidgets('mostra erro quando a senha esta errada', (tester) async {
    final auth = AuthFake(erroAoEntrar: 'Senha incorreta.');
    await tester.pumpWidget(montar(auth));

    await tester.enterText(
        find.byKey(const Key('campo_email')), 'marcos.centrone@gmail.com');
    await tester.enterText(find.byKey(const Key('campo_senha')), 'errada');
    await tester.tap(find.byKey(const Key('botao_entrar')));
    await tester.pumpAndSettle();

    expect(find.text('Senha incorreta.'), findsOneWidget);
  });

  testWidgets('nao chama o servico com campos vazios', (tester) async {
    final auth = AuthFake();
    await tester.pumpWidget(montar(auth));

    await tester.tap(find.byKey(const Key('botao_entrar')));
    await tester.pumpAndSettle();

    expect(auth.tentativas, 0);
    expect(find.text('Informe o e-mail.'), findsOneWidget);
  });

  testWidgets('chama o servico com os dados digitados', (tester) async {
    final auth = AuthFake();
    await tester.pumpWidget(montar(auth));

    await tester.enterText(
        find.byKey(const Key('campo_email')), 'marcos.centrone@gmail.com');
    await tester.enterText(find.byKey(const Key('campo_senha')), 'segredo123');
    await tester.tap(find.byKey(const Key('botao_entrar')));
    await tester.pumpAndSettle();

    expect(auth.tentativas, 1);
    expect(auth.ultimoEmail, 'marcos.centrone@gmail.com');
  });

  testWidgets('desabilita o botao enquanto autentica', (tester) async {
    final auth = AuthFake(demora: const Duration(milliseconds: 200));
    await tester.pumpWidget(montar(auth));

    await tester.enterText(
        find.byKey(const Key('campo_email')), 'marcos.centrone@gmail.com');
    await tester.enterText(find.byKey(const Key('campo_senha')), 'segredo123');
    await tester.tap(find.byKey(const Key('botao_entrar')));
    await tester.pump(); // inicia, ainda nao terminou

    final botao = tester.widget<FilledButton>(
        find.byKey(const Key('botao_entrar')));
    expect(botao.onPressed, isNull);

    await tester.pumpAndSettle();
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

```powershell
flutter test test/ui/tela_login_test.dart
```

Esperado: falhas de URI inexistente para `servico_auth.dart`, `providers.dart` e `tela_login.dart`.

- [ ] **Step 3: Implementar o serviço de autenticação**

Crie `lib/dados/servico_auth.dart`:

```dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Erro de autenticacao ja traduzido para exibicao ao usuario.
class ErroAuth implements Exception {
  final String mensagem;
  const ErroAuth(this.mensagem);

  @override
  String toString() => mensagem;
}

abstract class ServicoAuth {
  /// E-mail do usuario logado, ou null quando deslogado.
  Stream<String?> observarEmail();

  Future<void> entrar({required String email, required String senha});
  Future<void> sair();
}

class AuthFirebase implements ServicoAuth {
  final FirebaseAuth auth;
  AuthFirebase(this.auth);

  @override
  Stream<String?> observarEmail() =>
      auth.authStateChanges().map((u) => u?.email);

  @override
  Future<void> entrar({required String email, required String senha}) async {
    try {
      await auth.signInWithEmailAndPassword(
          email: email.trim(), password: senha);
    } on FirebaseAuthException catch (e) {
      throw ErroAuth(_traduzir(e.code));
    }
  }

  @override
  Future<void> sair() => auth.signOut();

  /// Os codigos do Firebase sao em ingles e nao servem para exibir.
  static String _traduzir(String codigo) {
    switch (codigo) {
      case 'invalid-email':
        return 'E-mail em formato invalido.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos.';
      case 'network-request-failed':
        return 'Sem conexao com a internet.';
      default:
        return 'Nao foi possivel entrar. Tente novamente.';
    }
  }
}

/// Usado nos testes de widget e para rodar a UI sem Firebase.
class AuthFake implements ServicoAuth {
  final String? erroAoEntrar;
  final Duration demora;
  final _controlador = StreamController<String?>.broadcast();

  int tentativas = 0;
  String? ultimoEmail;

  AuthFake({this.erroAoEntrar, this.demora = Duration.zero});

  @override
  Stream<String?> observarEmail() async* {
    yield null;
    yield* _controlador.stream;
  }

  @override
  Future<void> entrar({required String email, required String senha}) async {
    tentativas++;
    ultimoEmail = email;
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (erroAoEntrar != null) throw ErroAuth(erroAoEntrar!);
    _controlador.add(email);
  }

  @override
  Future<void> sair() async => _controlador.add(null);
}
```

- [ ] **Step 4: Implementar os formatadores**

Crie `lib/ui/tema/formatadores.dart`:

```dart
import 'package:intl/intl.dart';

/// NumberFormat nao exige initializeDateFormatting: os dados de formatacao
/// numerica ja vem compilados no intl. Isso vale so para DateFormat.
final NumberFormat _reais =
    NumberFormat.currency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 2);

/// "R$ 1.234,56"
String formatarReais(double valor) => _reais.format(valor);

/// "55%" ou "12,5%"
String formatarPercentual(double valor) {
  final texto = valor == valor.roundToDouble()
      ? valor.toStringAsFixed(0)
      : valor.toStringAsFixed(1).replaceAll('.', ',');
  return '$texto%';
}
```

- [ ] **Step 5: Implementar a tela de login**

Crie `lib/ui/telas/tela_login.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dados/servico_auth.dart';
import '../../estado/providers.dart';

class TelaLogin extends ConsumerStatefulWidget {
  const TelaLogin({super.key});

  @override
  ConsumerState<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends ConsumerState<TelaLogin> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  String? _erro;
  bool _entrando = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _erro = 'Informe o e-mail.');
      return;
    }
    if (_senha.text.isEmpty) {
      setState(() => _erro = 'Informe a senha.');
      return;
    }

    setState(() {
      _erro = null;
      _entrando = true;
    });

    try {
      await ref.read(servicoAuthProvider).entrar(
            email: _email.text,
            senha: _senha.text,
          );
    } on ErroAuth catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Controle Financeiro',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  key: const Key('campo_email'),
                  controller: _email,
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('campo_senha'),
                  controller: _senha,
                  obscureText: true,
                  onSubmitted: (_) => _entrando ? null : _entrar(),
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _erro!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('botao_entrar'),
                  onPressed: _entrando ? null : _entrar,
                  child: _entrando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Rodar o teste e confirmar que passa**

O teste depende de `providers.dart`, criado na Task 10. Se estiver executando estritamente em ordem, crie agora apenas a linha necessária em `lib/estado/providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dados/servico_auth.dart';

final servicoAuthProvider = Provider<ServicoAuth>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);
```

A Task 10 acrescenta os demais providers a este mesmo arquivo.

```powershell
flutter test test/ui/tela_login_test.dart
```

Esperado: `All tests passed!`, 4 testes.

- [ ] **Step 7: Commit**

```powershell
git add lib/dados/servico_auth.dart lib/ui/telas/tela_login.dart lib/ui/tema/formatadores.dart lib/estado/providers.dart test/ui
git commit -m "feat: autenticacao email/senha com erros traduzidos e tela de login"
```

---

### Task 10: Providers Riverpod

Liga domínio e dados. Todo provider de mês usa `autoDispose` para fechar o listener do Firestore ao sair da tela.

**Files:**
- Modify: `lib/estado/providers.dart` (criado parcialmente na Task 9)
- Test: `test/estado/providers_test.dart`

**Interfaces:**
- Consumes: repositórios (Tasks 7–8), `ServicoAuth` (Task 9), `calcularCascata` (Task 4), `calcularTotais` (Task 6), `agruparParcelasEmAberto` (Task 5).
- Produces:
  - `firestoreProvider`, `servicoAuthProvider`, `repositorioCasaProvider`, `repositorioPotesProvider`, `repositorioGanhosProvider`, `repositorioGastosProvider` — todos `Provider` sobrescritos em `main.dart`
  - `emailLogadoProvider` : `StreamProvider<String?>`
  - `casaProvider` : `StreamProvider<Casa?>`
  - `membroLogadoProvider` : `Provider<Membro?>`
  - `mesSelecionadoProvider` : `NotifierProvider<MesNotifier, MesRef>` com `avancar(int)` e `irPara(MesRef)`
  - `visaoProvider` : `NotifierProvider<VisaoNotifier, String?>` — `null` significa "casal"
  - `potesProvider` : `StreamProvider<List<Pote>>`
  - `ganhosDoMesProvider`, `gastosDoMesProvider` : `StreamProvider.autoDispose.family<..., String>`
  - `parceladosDesdeProvider` : `StreamProvider.autoDispose.family<List<Gasto>, String>`
  - `totaisDoMesProvider` : `Provider.autoDispose<AsyncValue<TotaisMes>>`
  - `resumoCascataProvider` : `Provider.autoDispose<AsyncValue<ResultadoCascata>>`
  - `parcelasEmAbertoProvider` : `Provider.autoDispose<AsyncValue<List<CompraParcelada>>>`

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/estado/providers_test.dart`:

```dart
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
  container.listen(potesProvider, (_, __) {});
  container.listen(ganhosDoMesProvider('2026-08'), (_, __) {});
  container.listen(gastosDoMesProvider('2026-08'), (_, __) {});
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
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

```powershell
flutter test test/estado/providers_test.dart
```

Esperado: erros de identificador não definido para `repositorioPotesProvider`, `mesSelecionadoProvider` e os demais.

- [ ] **Step 3: Implementar os providers**

Substitua o conteúdo de `lib/estado/providers.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dados/repositorios.dart';
import '../dados/servico_auth.dart';
import '../dominio/cascata.dart';
import '../dominio/models/casa.dart';
import '../dominio/models/ganho.dart';
import '../dominio/models/gasto.dart';
import '../dominio/models/membro.dart';
import '../dominio/models/mes_ref.dart';
import '../dominio/models/pote.dart';
import '../dominio/parcelas.dart';
import '../dominio/totais.dart';

// --- Infraestrutura: sobrescrita em main.dart ------------------------------

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final servicoAuthProvider = Provider<ServicoAuth>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final repositorioCasaProvider = Provider<RepositorioCasa>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final repositorioPotesProvider = Provider<RepositorioPotes>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final repositorioGanhosProvider = Provider<RepositorioGanhos>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final repositorioGastosProvider = Provider<RepositorioGastos>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

// --- Sessao ---------------------------------------------------------------

final emailLogadoProvider = StreamProvider<String?>(
  (ref) => ref.watch(servicoAuthProvider).observarEmail(),
);

final casaProvider = StreamProvider<Casa?>(
  (ref) => ref.watch(repositorioCasaProvider).observar(),
);

/// Qual membro corresponde ao e-mail logado. Null quando o e-mail
/// autenticou mas nao pertence a esta casa.
final membroLogadoProvider = Provider<Membro?>((ref) {
  final email = ref.watch(emailLogadoProvider).valueOrNull;
  final casa = ref.watch(casaProvider).valueOrNull;
  if (email == null || casa == null) return null;
  return casa.membroPorEmail(email);
});

// --- Mes selecionado (global, compartilhado por todas as telas) ------------

class MesNotifier extends Notifier<MesRef> {
  @override
  MesRef build() => MesRef.atual();

  void avancar(int meses) => state = state.avancar(meses);
  void irPara(MesRef mes) => state = mes;
}

final mesSelecionadoProvider =
    NotifierProvider<MesNotifier, MesRef>(MesNotifier.new);

/// Visao ativa nas telas de analise. Null significa "casal".
class VisaoNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void selecionar(String? membroId) => state = membroId;
}

final visaoProvider = NotifierProvider<VisaoNotifier, String?>(VisaoNotifier.new);

// --- Dados ----------------------------------------------------------------

final potesProvider = StreamProvider<List<Pote>>(
  (ref) => ref.watch(repositorioPotesProvider).observar(),
);

final ganhosDoMesProvider =
    StreamProvider.autoDispose.family<List<Ganho>, String>(
  (ref, mesRef) => ref.watch(repositorioGanhosProvider).observarMes(mesRef),
);

final gastosDoMesProvider =
    StreamProvider.autoDispose.family<List<Gasto>, String>(
  (ref, mesRef) => ref.watch(repositorioGastosProvider).observarMes(mesRef),
);

final parceladosDesdeProvider =
    StreamProvider.autoDispose.family<List<Gasto>, String>(
  (ref, mesRef) =>
      ref.watch(repositorioGastosProvider).observarParceladosDesde(mesRef),
);

// --- Derivados ------------------------------------------------------------

/// Combina dois AsyncValue preservando loading e erro.
AsyncValue<R> _combinar<A, B, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  R Function(A, B) juntar,
) {
  if (a.hasError) return AsyncValue.error(a.error!, a.stackTrace!);
  if (b.hasError) return AsyncValue.error(b.error!, b.stackTrace!);
  if (!a.hasValue || !b.hasValue) return const AsyncValue.loading();
  return AsyncValue.data(juntar(a.requireValue, b.requireValue));
}

final totaisDoMesProvider = Provider.autoDispose<AsyncValue<TotaisMes>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;
  final membroId = ref.watch(visaoProvider);

  return _combinar(
    ref.watch(ganhosDoMesProvider(mes)),
    ref.watch(gastosDoMesProvider(mes)),
    (ganhos, gastos) =>
        calcularTotais(ganhos: ganhos, gastos: gastos, membroId: membroId),
  );
});

/// Totais do casal, independentes da visao selecionada.
/// Alimenta a barra fixa de totais do mes.
final totaisDoCasalProvider = Provider.autoDispose<AsyncValue<TotaisMes>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider).valor;

  return _combinar(
    ref.watch(ganhosDoMesProvider(mes)),
    ref.watch(gastosDoMesProvider(mes)),
    (ganhos, gastos) => calcularTotais(ganhos: ganhos, gastos: gastos),
  );
});

final resumoCascataProvider =
    Provider.autoDispose<AsyncValue<ResultadoCascata>>((ref) {
  final potes = ref.watch(potesProvider);
  final totais = ref.watch(totaisDoMesProvider);

  return _combinar(
    potes,
    totais,
    (listaPotes, t) => calcularCascata(
      potes: listaPotes,
      totalGanhos: t.ganhos,
      totalGastos: t.gastos,
    ),
  );
});

final parcelasEmAbertoProvider =
    Provider.autoDispose<AsyncValue<List<CompraParcelada>>>((ref) {
  final mes = ref.watch(mesSelecionadoProvider);
  return ref.watch(parceladosDesdeProvider(mes.valor)).whenData(
        (gastos) => agruparParcelasEmAberto(gastos: gastos, mesAtual: mes),
      );
});
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

```powershell
flutter test test/estado/providers_test.dart
```

Esperado: `All tests passed!`, 6 testes.

- [ ] **Step 5: Rodar a suíte inteira**

```powershell
flutter test
flutter analyze
```

Esperado: tudo verde.

- [ ] **Step 6: Commit**

```powershell
git add lib/estado/providers.dart test/estado
git commit -m "feat: providers Riverpod ligando dominio, dados e cascata"
```

---

### Task 11: Shell responsivo, seletor de mês e barra de totais

**Files:**
- Create: `lib/ui/tema/tema.dart`
- Create: `lib/ui/widgets/estados_async.dart`
- Create: `lib/ui/widgets/seletor_mes.dart`
- Create: `lib/ui/widgets/barra_totais.dart`
- Create: `lib/ui/shell.dart`
- Test: `test/ui/shell_test.dart`

**Interfaces:**
- Consumes: providers (Task 10), `formatarReais` (Task 9).
- Produces:
  - `ThemeData temaClaro()`, `ThemeData temaEscuro()`, `Color corDeHex(String)`
  - `class CarregandoLista extends StatelessWidget`, `class ErroComRecarregar extends StatelessWidget { const ErroComRecarregar({required Object erro, required VoidCallback aoRecarregar}) }`
  - `class SeletorMes extends ConsumerWidget`
  - `class BarraTotais extends ConsumerWidget`
  - `class Shell extends ConsumerStatefulWidget` — `NavigationRail` acima de 900 px, `NavigationBar` abaixo
  - `const double breakpointDesktop = 900;`

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/ui/shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/mes_ref.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/shell.dart';

Widget montar() => ProviderScope(
      overrides: [
        repositorioPotesProvider.overrideWithValue(RepositorioPotesFake()),
        repositorioGanhosProvider.overrideWithValue(RepositorioGanhosFake()),
        repositorioGastosProvider.overrideWithValue(RepositorioGastosFake()),
      ],
      child: const MaterialApp(home: Shell()),
    );

Future<void> comLargura(WidgetTester tester, double largura) async {
  tester.view.physicalSize = Size(largura, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('usa NavigationRail no desktop', (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montar());
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('usa NavigationBar no mobile', (tester) async {
    await comLargura(tester, 420);
    await tester.pumpWidget(montar());
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('seletor de mes avanca e volta', (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montar());
    await tester.pump();

    final container = ProviderScope.containerOf(
        tester.element(find.byType(Shell)));
    container.read(mesSelecionadoProvider.notifier)
        .irPara(const MesRef(2026, 8));
    await tester.pump();

    expect(find.text('Agosto/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mes_proximo')));
    await tester.pump();
    expect(find.text('Setembro/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mes_anterior')));
    await tester.tap(find.byKey(const Key('mes_anterior')));
    await tester.pump();
    expect(find.text('Julho/2026'), findsOneWidget);
  });

  testWidgets('barra de totais mostra zeros com repositorios vazios',
      (tester) async {
    await comLargura(tester, 1400);
    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('total_ganhos')), findsOneWidget);
    expect(find.byKey(const Key('total_gastos')), findsOneWidget);
    expect(find.byKey(const Key('total_saldo')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

```powershell
flutter test test/ui/shell_test.dart
```

Esperado: falha de URI inexistente para `shell.dart`.

- [ ] **Step 3: Implementar tema e widgets de estado**

Crie `lib/ui/tema/tema.dart`:

```dart
import 'package:flutter/material.dart';

const Color _semente = Color(0xFF2E7D32);

ThemeData temaClaro() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _semente),
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

ThemeData temaEscuro() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
          seedColor: _semente, brightness: Brightness.dark),
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

/// Converte "#RRGGBB" (formato gravado em Pote.cor e Membro.cor) em Color.
Color corDeHex(String hex) {
  final limpo = hex.replaceFirst('#', '');
  final valor = int.tryParse(limpo, radix: 16);
  if (valor == null || limpo.length != 6) return const Color(0xFF607D8B);
  return Color(0xFF000000 | valor);
}
```

Crie `lib/ui/widgets/estados_async.dart`:

```dart
import 'package:flutter/material.dart';

/// Skeleton com a forma do conteudo, em vez de um spinner centralizado:
/// o layout nao pula quando os dados chegam.
class CarregandoLista extends StatelessWidget {
  final int linhas;
  const CarregandoLista({super.key, this.linhas = 5});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: linhas,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 56,
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class ErroComRecarregar extends StatelessWidget {
  final Object erro;
  final VoidCallback aoRecarregar;

  const ErroComRecarregar({
    super.key,
    required this.erro,
    required this.aoRecarregar,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 40, color: esquema.error),
            const SizedBox(height: 12),
            Text(
              'Nao foi possivel carregar os dados.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '$erro',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: aoRecarregar,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implementar seletor de mês e barra de totais**

Crie `lib/ui/widgets/seletor_mes.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/providers.dart';

class SeletorMes extends ConsumerWidget {
  const SeletorMes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSelecionadoProvider);
    final notifier = ref.read(mesSelecionadoProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('mes_anterior'),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Mes anterior',
          onPressed: () => notifier.avancar(-1),
        ),
        SizedBox(
          width: 150,
          child: Text(
            mes.formatarExtenso(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const Key('mes_proximo'),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Proximo mes',
          onPressed: () => notifier.avancar(1),
        ),
      ],
    );
  }
}
```

Crie `lib/ui/widgets/barra_totais.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/providers.dart';
import '../tema/formatadores.dart';

/// Faixa fixa abaixo da AppBar: Ganhos, Gastos e Saldo do casal no mes.
/// Fica visivel em todas as telas autenticadas.
class BarraTotais extends ConsumerWidget {
  const BarraTotais({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totais = ref.watch(totaisDoCasalProvider);
    final esquema = Theme.of(context).colorScheme;

    return Container(
      color: esquema.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: totais.when(
        loading: () => const SizedBox(
          height: 34,
          child: Center(
            child: SizedBox(
              height: 16, width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, _) => SizedBox(
          height: 34,
          child: Center(
            child: Text('Totais indisponiveis',
                style: TextStyle(color: esquema.error)),
          ),
        ),
        data: (t) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Item(
              chave: 'total_ganhos',
              rotulo: 'Ganhos',
              valor: t.ganhos,
              cor: esquema.primary,
            ),
            _Item(
              chave: 'total_gastos',
              rotulo: 'Gastos',
              valor: t.gastos,
              cor: esquema.error,
            ),
            _Item(
              chave: 'total_saldo',
              rotulo: 'Saldo do mes',
              valor: t.saldo,
              cor: t.saldo < 0 ? esquema.error : esquema.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String chave;
  final String rotulo;
  final double valor;
  final Color cor;

  const _Item({
    required this.chave,
    required this.rotulo,
    required this.valor,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key(chave),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rotulo, style: Theme.of(context).textTheme.labelSmall),
        Text(
          formatarReais(valor),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: cor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Implementar o shell**

Crie `lib/ui/shell.dart`. As telas de CRUD ainda não existem (são o próximo plano), então cada destino mostra um placeholder nomeado — isso é intencional e temporário, e o teste desta tarefa verifica a navegação, não o conteúdo.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  _Destino('Graficos', Icons.insights),
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
    final desktop =
        MediaQuery.sizeOf(context).width >= breakpointDesktop;

    // Substituido pelas telas reais no plano das Fases 3 e 4.
    final conteudo = Center(
      child: Text(
        _destinos[_indice].rotulo,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );

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
```

- [ ] **Step 6: Rodar o teste e confirmar que passa**

```powershell
flutter test test/ui/shell_test.dart
```

Esperado: `All tests passed!`, 4 testes.

- [ ] **Step 7: Commit**

```powershell
git add lib/ui test/ui/shell_test.dart
git commit -m "feat: shell responsivo com seletor de mes e barra de totais"
```

---

### Task 12: Conectar o Firebase e fechar a Fase 1

Última tarefa: `main.dart` real, semeadura do primeiro acesso, e a primeira verificação contra o Firestore de verdade.

**Files:**
- Create: `lib/dados/semeadura.dart`
- Create: `lib/ui/app.dart`
- Modify: `lib/main.dart` (substitui o gerado pelo `flutter create`)
- Delete: `test/widget_test.dart` (o teste do contador padrão)
- Test: `test/dados/semeadura_test.dart`

**Interfaces:**
- Consumes: tudo das Tasks 3–11.
- Produces:
  - `Casa casaPadrao()`, `List<Pote> potesPadrao()`, `Future<void> semear({required RepositorioCasa casa, required RepositorioPotes potes})`
  - `class App extends ConsumerWidget` — roteia entre `TelaLogin`, `Shell` e a tela de "sem acesso"

- [ ] **Step 1: Escrever o teste que falha**

Crie `test/dados/semeadura_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dados/semeadura.dart';

void main() {
  test('os potes padrao somam exatamente 100%', () {
    final soma = potesPadrao().fold<double>(0, (a, p) => a + p.percentual);
    expect(soma, 100);
  });

  test('os potes padrao respeitam o limite de 6', () {
    expect(potesPadrao().length, lessThanOrEqualTo(6));
  });

  test('os potes padrao tem ordem sequencial a partir de zero', () {
    expect(potesPadrao().map((p) => p.ordem).toList(), [0, 1, 2, 3, 4, 5]);
  });

  test('a casa padrao tem os dois membros com os e-mails corretos', () {
    final casa = casaPadrao();
    expect(casa.membros, hasLength(2));
    expect(casa.membroPorEmail('marcos.centrone@gmail.com')?.id, 'marcos');
    expect(casa.membroPorEmail('silviabborges3@gmail.com')?.id, 'silvia');
  });

  test('semear cria casa e potes quando nao existe nada', () async {
    final casa = RepositorioCasaFake();
    final potes = RepositorioPotesFake();

    await semear(casa: casa, potes: potes);

    expect(await casa.observar().first, isNotNull);
    expect(await potes.observar().first, hasLength(6));
  });

  test('semear nao sobrescreve uma casa existente', () async {
    final casa = RepositorioCasaFake(casaPadrao());
    final potes = RepositorioPotesFake(potesPadrao());

    // Simula o usuario tendo reduzido para 2 potes.
    await potes.salvarTodos(potesPadrao().take(2).toList());
    await semear(casa: casa, potes: potes);

    expect(await potes.observar().first, hasLength(2));
  });
}
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

```powershell
flutter test test/dados/semeadura_test.dart
```

Esperado: falha de URI inexistente para `semeadura.dart`.

- [ ] **Step 3: Implementar a semeadura**

Crie `lib/dados/semeadura.dart`:

```dart
import '../dominio/models/casa.dart';
import '../dominio/models/membro.dart';
import '../dominio/models/pote.dart';
import 'repositorios.dart';

/// Configuracao inicial dos potes. Soma 100% — a validacao da tela de
/// Lei dos Potes depende disso.
List<Pote> potesPadrao() => const [
      Pote(id: '', nome: 'Custo fixo', percentual: 55, ordem: 0,
          cor: '#2E7D32', icone: 'casa'),
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
}) async {
  if (await casa.observar().first == null) {
    await casa.criar(casaPadrao());
  }
  if ((await potes.observar().first).isEmpty) {
    await potes.salvarTodos(potesPadrao());
  }
}
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

```powershell
flutter test test/dados/semeadura_test.dart
```

Esperado: `All tests passed!`, 6 testes.

- [ ] **Step 5: Implementar o roteamento por estado de autenticação**

Crie `lib/ui/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/providers.dart';
import 'shell.dart';
import 'telas/tela_login.dart';
import 'tema/tema.dart';
import 'widgets/estados_async.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Controle Financeiro',
      theme: temaClaro(),
      darkTheme: temaEscuro(),
      debugShowCheckedModeBanner: false,
      home: const _Roteador(),
    );
  }
}

class _Roteador extends ConsumerWidget {
  const _Roteador();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(emailLogadoProvider);

    return email.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: ErroComRecarregar(
          erro: e,
          aoRecarregar: () => ref.invalidate(emailLogadoProvider),
        ),
      ),
      data: (endereco) {
        if (endereco == null) return const TelaLogin();
        return const _CasaOuSemAcesso();
      },
    );
  }
}

/// Autenticar nao basta: o e-mail precisa pertencer a esta casa.
class _CasaOuSemAcesso extends ConsumerWidget {
  const _CasaOuSemAcesso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casa = ref.watch(casaProvider);

    return casa.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: ErroComRecarregar(
          erro: e,
          aoRecarregar: () => ref.invalidate(casaProvider),
        ),
      ),
      data: (_) {
        final membro = ref.watch(membroLogadoProvider);
        if (membro == null) return const _SemAcesso();
        return const Shell();
      },
    );
  }
}

class _SemAcesso extends ConsumerWidget {
  const _SemAcesso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40),
              const SizedBox(height: 12),
              Text(
                'Esta conta nao faz parte desta casa.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref.read(servicoAuthProvider).sair(),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Reescrever o main.dart**

Substitua todo o conteúdo de `lib/main.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dados/repositorio_firestore.dart';
import 'dados/repositorios.dart';
import 'dados/semeadura.dart';
import 'dados/servico_auth.dart';
import 'estado/providers.dart';
import 'firebase_options.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final db = FirebaseFirestore.instance;

  // Cache offline so no Android e iOS. No Windows o cloud_firestore nao
  // oferece persistencia em disco equivalente; sem internet o app abre mas
  // nao carrega dados, e a tela de erro informa isso.
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    db.settings = const Settings(persistenceEnabled: true);
  }

  final repoCasa = CasaFirestore(db);
  final repoPotes = PotesFirestore(db);

  runApp(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        servicoAuthProvider
            .overrideWithValue(AuthFirebase(FirebaseAuth.instance)),
        repositorioCasaProvider.overrideWithValue(repoCasa),
        repositorioPotesProvider.overrideWithValue(repoPotes),
        repositorioGanhosProvider.overrideWithValue(GanhosFirestore(db)),
        repositorioGastosProvider.overrideWithValue(GastosFirestore(db)),
      ],
      child: _SemearAoLogar(
        casa: repoCasa,
        potes: repoPotes,
        child: const App(),
      ),
    ),
  );
}

/// A semeadura roda depois do login, nao no boot: as regras do Firestore
/// negam leitura e escrita para quem nao esta autenticado.
class _SemearAoLogar extends ConsumerStatefulWidget {
  final RepositorioCasa casa;
  final RepositorioPotes potes;
  final Widget child;

  const _SemearAoLogar({
    required this.casa,
    required this.potes,
    required this.child,
  });

  @override
  ConsumerState<_SemearAoLogar> createState() => _SemearAoLogarState();
}

class _SemearAoLogarState extends ConsumerState<_SemearAoLogar> {
  bool _semeado = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(emailLogadoProvider, (_, proximo) async {
      final email = proximo.valueOrNull;
      if (email == null) {
        _semeado = false;
        return;
      }
      if (_semeado) return;
      _semeado = true;
      await semear(casa: widget.casa, potes: widget.potes);
    });

    return widget.child;
  }
}
```

- [ ] **Step 7: Remover o teste do contador padrão**

```powershell
Remove-Item test\widget_test.dart
```

Ele testa o app gerado pelo `flutter create`, que não existe mais.

- [ ] **Step 8: Configurar o Firebase na máquina**

```powershell
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=controlefinaceiro-b5a70
```

Quando o CLI perguntar as plataformas, marque **android** e **windows**. Ele registra o app Web usado pelo Windows automaticamente e gera `lib/firebase_options.dart`.

Antes disso, no console do Firebase (são passos que nenhuma CLI faz):

1. **Authentication → Sign-in method** → ativar **E-mail/senha**
2. **Authentication → Users** → adicionar `marcos.centrone@gmail.com` e `silviabborges3@gmail.com`, cada um com uma senha de aplicativo
3. **Firestore Database → Criar banco** → modo produção → região `southamerica-east1`
4. **Firestore → Regras** → colar o conteúdo de `firestore.rules` e publicar

- [ ] **Step 9: Verificar a suíte inteira**

```powershell
flutter analyze
flutter test
```

Esperado: `analyze` limpo e todos os testes das Tasks 2–12 passando.

- [ ] **Step 10: Verificar contra o Firebase real no Windows**

```powershell
flutter run -d windows
```

Confirme, nesta ordem:

1. A tela de login aparece.
2. Senha errada mostra "E-mail ou senha incorretos.", não um stack trace.
3. Login correto entra no Shell.
4. No console do Firebase, `casas/principal` foi criado com os dois membros, e `casas/principal/potes` tem 6 documentos somando 100%.
5. A barra de totais mostra `R$ 0,00` nos três campos.
6. As setas do seletor de mês mudam o rótulo, e redimensionar a janela abaixo de 900 px troca o `NavigationRail` pela `NavigationBar`.

Se alguma query reclamar de índice faltando, o erro no console traz um link direto que cria o índice — clique nele. Os três índices esperados estão em `firestore.indexes.json`.

- [ ] **Step 11: Verificar no Android**

```powershell
flutter build apk --debug
flutter install
```

Confirme que o login funciona e que os potes criados no Windows aparecem no celular. É esta verificação que prova a sincronização entre os dois dispositivos.

- [ ] **Step 12: Commit**

```powershell
git add -A
git commit -m "feat: conecta Firebase, semeia a casa no primeiro acesso e roteia por autenticacao"
```

---

## Estado ao fim deste plano

Entregue e verificado:

- Projeto Flutter compilando para Windows e Android
- Autenticação e-mail/senha com mensagens em português
- Casa e potes criados automaticamente no primeiro acesso
- Shell responsivo com navegação, seletor de mês global e barra de totais
- Motor da cascata, geração de parcelas e agregações — **todos com testes**
- Repositórios Firestore com escrita em lote e regras de segurança publicadas

Pendente para o próximo plano (Fases 3 e 4):

- Telas de Ganhos, Lei dos Potes, Gastos e Parcelas em Aberto
- Tela de Resumo dos Potes com a tabela e o rótulo do pote ativo
- Os seis gráficos
- Substituição dos placeholders do `Shell` pelas telas reais
- Builds de release (`--release`) para as duas plataformas
