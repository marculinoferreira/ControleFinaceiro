# Controle Financeiro Familiar — Design

**Data:** 2026-08-30
**Status:** aprovado no brainstorming, aguardando revisão do documento

## 1. Contexto e escopo

Aplicativo de controle financeiro doméstico para um casal (Marcos e Silvia), com
código-base Flutter único rodando em **Windows (desktop)** e **Android (mobile)**,
sincronizado por Firebase.

O modelo mental é a "Lei dos Potes": a renda do mês é dividida em categorias
percentuais ordenadas por prioridade, e o gasto real escorre por essas categorias
em cascata. O app existe para responder a uma pergunta: *até onde meu dinheiro
deste mês já foi consumido?*

**Firebase existente:** projeto `controlefinaceiro-b5a70`, plano Spark, app Android
registrado no package `controle.finaceiro` (grafia sem o "n" — intencional, precisa
bater com o console).

## 2. Decisões tomadas

| # | Decisão | Escolha | Por quê |
|---|---|---|---|
| 1 | Efeito cascata | **Cachoeira do gasto total** | O rótulo "onde estou consumindo" sai naturalmente: é o pote onde a água parou. Ver §6.1. |
| 2 | Parcelamento | **N documentos materializados** | A query mensal continua sendo um `where mesRef ==`. Editar uma parcela isolada é editar um documento. |
| 3 | Identidade | **Casa única + mapa de membros** | Trocar nome ou cor de uma pessoa é editar um documento, não recompilar o app. |
| 4 | Config dos potes | **Global, sem versionamento por mês** | Decisão do usuário: alterar uma porcentagem revaloriza todos os meses, inclusive os passados. |
| 5 | Autenticação | **E-mail/senha com os endereços Gmail** | `google_sign_in` não suporta Windows; o Google Sign-In no desktop exigiria um fluxo OAuth manual com servidor local. Ver §12.1. |

### 2.1 Correção da fórmula do spec original

O prompt original definia a cascata como:

```
Sobra(pote N)      = Previsto(pote N) − Gasto_antes(pote N)
Gasto_antes(N+1)   = Sobra(pote N)
```

Essa formulação inverte o sinal. Com Previsto(1) = 500 e gasto 600, temos
Sobra(1) = −100; a segunda linha faria Gasto_antes(2) = −100 e, portanto,
Sobra(2) = 200 − (−100) = **300** — o pote 2 *ganharia* folga por causa de um
estouro no pote 1. A formulação correta está em §6.1.

## 3. Stack

- **Flutter** 3.41.5 / Dart 3.11.3
- **Firebase**: `firebase_core`, `firebase_auth`, `cloud_firestore`
- **Gráficos**: `fl_chart`
- **Estado**: **Riverpod**
- **Utilitários**: `intl` (formatação pt-BR e R$), `uuid` (compraId)

### 3.1 Por que Riverpod

Justificativa específica deste app, não preferência genérica:

- **Todo estado aqui é "do mês X".** `Provider.family` parametriza por `mesRef`
  nativamente. Com Provider puro isso vira código manual de cache por chave.
- **`StreamProvider` + `AsyncValue`** tornam loading / erro / dados três estados
  que o compilador obriga a tratar. Isso *é* o requisito de "tratamento de erros
  e estados de carregamento", sem `if (snapshot.hasError)` espalhado por tela.
- **`autoDispose`** encerra o listener do Firestore ao sair da tela. Leitura no
  Firestore é cobrada; listener esquecido é custo recorrente.
- **Leitura sem `BuildContext`** permite testar o motor de cálculo sem widget.
- Bloc custaria três arquivos por CRUD trivial. Provider não tem `family`,
  `autoDispose` nem `AsyncValue`.

## 4. Modelo de dados — Firestore

```
casas/principal
│  nome: "Casa Marcos & Silvia"
│  membros: {
│    "marcos": { nome:"Marcos", email:"marcos.centrone@gmail.com",
│                cor:"#2E7D32", ordem:0 },
│    "silvia": { nome:"Silvia", email:"silviabborges3@gmail.com",
│                cor:"#6A1B9A", ordem:1 }
│  }
│
├─ potes/{poteId}
│    nome:String, percentual:num, ordem:int, cor:String, icone:String
│
├─ ganhos/{ganhoId}
│    mesRef:String, membroId:String, descricao:String,
│    valor:num, criadoEm:Timestamp
│
└─ gastos/{gastoId}
     mesRef:String, membroId:String, poteId:String, descricao:String,
     valor:num, criadoEm:Timestamp,
     parcelado:bool, compraId:String?, parcela:int?, totalParcelas:int?
```

**Chaves de membro são slugs curtos** (`marcos`, `silvia`), não e-mails: chaves de
mapa no Firestore com ponto exigem `FieldPath` para acesso e complicam updates.
O e-mail vive dentro do valor.

**`mesRef` é `String` no formato `"2026-08"`** — ordenável lexicograficamente,
comparável com `>=` e legível na query. Zero à esquerda no mês é obrigatório.

**Não existe coleção `meses/`.** Decorre da decisão 4: como a config dos potes é
global, não há nada por mês para congelar.

**`parcelado:bool` é redundante com `compraId != null`, e isso é proposital.** A
tela "Parcelas em aberto" precisa de `parcelado == true AND mesRef >= mesAtual`.
Com o booleano, é uma única desigualdade e um índice simples.

### 4.1 Índices compostos

| Coleção | Campos | Serve a |
|---|---|---|
| `ganhos` | `mesRef ↑, membroId ↑` | Tela de Ganhos, subtotal por pessoa |
| `gastos` | `mesRef ↑, criadoEm ↓` | Tela de Gastos do mês |
| `gastos` | `parcelado ↑, mesRef ↑` | Parcelas em aberto, comprometimento futuro |

### 4.2 Models Dart

Em `lib/dominio/models/`, todos imutáveis com `fromMap` / `toMap` e `copyWith`:

- `Membro` — id, nome, email, cor, ordem
- `Casa` — id, nome, `List<Membro>`
- `Pote` — id, nome, percentual, ordem, cor, icone
- `Ganho` — id, mesRef, membroId, descricao, valor, criadoEm
- `Gasto` — id, mesRef, membroId, poteId, descricao, valor, criadoEm,
  parcelado, compraId, parcela, totalParcelas
- `MesRef` — value object sobre a String `"2026-08"`, com `avancar(int meses)`,
  `comparar`, `formatarExtenso()` → "Agosto/2026". Concentra a aritmética de
  data para que a virada de ano exista em um lugar só.

Valores monetários são `double` em Dart e `num` no Firestore. Arredondamento
para 2 casas acontece **na formatação**, não no armazenamento.

## 5. Regras de segurança

Os e-mails autorizados ficam **nas regras**, não em um documento. Um
`get()` dentro da regra custaria uma leitura cobrada a cada requisição, e a lista
muda com a mesma frequência que a regra (praticamente nunca). Editar a regra no
console não exige recompilar o app.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

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

A regra **não** verifica `email_verified`: contas criadas manualmente no console
nascem com e-mail não verificado, e exigir verificação travaria os dois usuários
na porta.

Qualquer caminho fora de `casas/principal` é negado por omissão.

## 6. Motor de domínio

Dart puro em `lib/dominio/`, sem nenhum import de Firebase. Roda em
`flutter test` sem rede, sem emulador e sem widget.

### 6.1 Cascata (`dominio/cascata.dart`)

O gasto **total** da pessoa (ou do casal) escorre pela fila de potes na ordem de
prioridade. O pote de cada gasto individual é classificação — alimenta os
gráficos, não a cascata.

```dart
ResultadoCascata calcularCascata({
  required List<Pote> potes,     // já ordenados por `ordem`
  required double totalGanhos,
  required double totalGastos,
}) {
  var restante = totalGastos;
  final linhas = <LinhaCascata>[];
  Pote? poteAtivo;

  for (final pote in potes) {
    final previsto  = totalGanhos * pote.percentual / 100;
    final consumido = math.min(restante, previsto);
    final sobra     = previsto - consumido;
    restante -= consumido;

    if (poteAtivo == null && sobra > 0) poteAtivo = pote;
    linhas.add(LinhaCascata(pote, previsto, consumido, sobra));
  }

  return ResultadoCascata(
    linhas: linhas,
    poteAtivo: poteAtivo,            // null  => estourou todos
    excedente: restante,             // > 0   => "PARE DE GASTAR"
  );
}
```

`ResultadoCascata.rotulo` devolve o nome do pote ativo em caixa alta, ou
`"PARE DE GASTAR"` quando `poteAtivo == null`.

**Casos de teste obrigatórios:**

| Caso | Esperado |
|---|---|
| `totalGastos == 0` | pote ativo = primeiro pote; todas as sobras = previsto |
| Gasto parando no meio do pote 3 | ativo = pote 3; potes 1–2 com sobra 0; potes 4+ intactos |
| Gasto exatamente igual ao previsto do pote 1 | ativo = pote 2 (sobra do 1 é zero, não positiva) |
| Gasto > soma de todos os previstos | `poteAtivo == null`, `excedente == gasto − ganhos` |
| Lista de potes vazia | resultado vazio, `excedente == totalGastos`, sem exceção |
| `totalGanhos == 0` com gasto > 0 | todos previstos 0, `poteAtivo == null` |
| Soma de percentuais == 100 | soma dos previstos == totalGanhos (tolerância de centavo) |

### 6.2 Geração de parcelas (`dominio/parcelas.dart`)

```dart
List<Gasto> gerarParcelas(Gasto base, int quantidade)
```

Devolve `quantidade` gastos compartilhando um `compraId` (uuid v4), com
`parcela` de 1 a N, mesmo `poteId`, mesmo `membroId`, mesmo valor, e `mesRef`
avançando um mês por parcela a partir do mês do `base`. A gravação é um único
`WriteBatch` — ou entram todas, ou nenhuma.

**Casos de teste obrigatórios:**

| Caso | Esperado |
|---|---|
| 10x a partir de `2026-08` | 10 gastos, última em `2027-05`, parcelas 1..10 |
| Virada de ano: 3x a partir de `2026-12` | `2026-12`, `2027-01`, `2027-02` |
| `quantidade == 1` | 1 gasto, `parcelado == false`, `compraId == null` |
| 24x | 24 gastos, avanço de 2 anos exato |
| Todas as parcelas | mesmo `compraId`, mesmo `poteId`, mesmo `membroId` |
| `quantidade <= 0` | lança `ArgumentError` |

### 6.3 Exclusão de compra parcelada

Três modos, expostos em diálogo na UI:

- **Só esta parcela** — apaga um documento; as demais mantêm `totalParcelas`
  original, e a exibição continua "3/10" (o histórico da compra não muda porque
  uma parcela foi estornada).
- **Esta e as futuras** — batch sobre `compraId == X AND parcela >= N`.
- **Todas** — batch sobre `compraId == X`.

## 7. Estrutura de pastas

```
lib/
  main.dart
  firebase_options.dart          gerado por flutterfire configure
  dominio/
    models/                      Membro, Casa, Pote, Ganho, Gasto, MesRef
    cascata.dart                 motor da cascata + ResultadoCascata
    parcelas.dart                geração e agrupamento de parcelas
    totais.dart                  totais do mês, subtotais por pessoa
  dados/
    repositorio_potes.dart       interface + impl Firestore
    repositorio_ganhos.dart
    repositorio_gastos.dart
    repositorio_casa.dart
    servico_auth.dart
  estado/
    providers_auth.dart
    providers_mes.dart           mesSelecionadoProvider (global)
    providers_potes.dart
    providers_ganhos.dart
    providers_gastos.dart
    providers_resumo.dart        combina ganhos + gastos + potes -> cascata
  ui/
    app.dart                     rotas, tema, shell responsivo
    telas/                       login, ganhos, potes, gastos,
                                 parcelas, resumo, graficos
    widgets/                     seletor_mes, barra_totais, tabela_responsiva,
                                 estado_carregando, estado_erro, campo_moeda
    tema/                        cores, tipografia, formatadores pt-BR
test/
  dominio/                       cascata_test.dart, parcelas_test.dart,
                                 mes_ref_test.dart, totais_test.dart
```

Cada repositório expõe uma interface e uma implementação Firestore. Os providers
dependem da interface, o que mantém os testes de domínio livres de rede.

## 8. Telas

Duas coisas são globais e vivem no shell, fora das telas:

- **Seletor de mês na AppBar**, ligado a um único `mesSelecionadoProvider`.
  Trocar o mês em qualquer tela troca em todas.
- **Barra de totais do mês** (Ganhos · Gastos · Saldo para passar o mês) logo
  abaixo da AppBar, visível em todas as telas autenticadas. Corresponde ao item
  "Totais Gerais do Mês" do spec original, que não merece tela própria.

| Tela | Conteúdo e comportamento |
|---|---|
| **Login** | E-mail e senha. Se o usuário autenticar mas o e-mail não estiver na lista de membros, exibe mensagem explícita em vez de tela vazia. |
| **Ganhos** | Uma coluna por pessoa no desktop, duas seções empilhadas no mobile. CRUD de entradas, subtotal no pé de cada coluna, total geral destacado. |
| **Lei dos Potes** | `ReorderableListView` — a ordem **é** a prioridade da cascata, então arrastar é a interação correta. Indicador ao vivo da soma ("97% — faltam 3%"); botão Salvar desabilitado fora de 100%. Máximo 6 potes. Cada pote guarda uma cor, reusada em todos os gráficos. |
| **Gastos** | Lista do mês, filtrável por pessoa (Marcos / Silvia / Casal) e por pote. Itens parcelados exibem "3/10". No formulário, o switch "Parcelado" revela valor da parcela e quantidade, com preview antes de salvar: *"10x de R$ 100,00 = R$ 1.000,00 · Ago/26 → Mai/27"*. Excluir parcelado abre o diálogo de três modos (§6.3). |
| **Parcelas em Aberto** | Agrupa por `compraId` as compras com parcelas em `mesRef >= mês atual`. Formato: *"Geladeira — parcela 3/10 — R$ 100,00/mês — faltam 7 meses"*. |
| **Resumo dos Potes** | Seletor de visão Marcos / Silvia / Casal. Tabela Pote · % · Previsto · Consumido · Sobra, com barra de progresso por linha. No topo, rótulo grande do pote ativo em cor semafórica, virando **"PARE DE GASTAR"** em vermelho com o valor do excedente quando a água passa do último pote. |
| **Gráficos** | §10. |

## 9. Responsividade

Breakpoint único em **900 px de largura**.

```
Desktop (>= 900px)             Mobile (< 900px)
┌────┬──────────────────┐      ┌──────────────────┐
│ N  │ AppBar + mês     │      │ AppBar + mês     │
│ a  ├──────────────────┤      ├──────────────────┤
│ v  │ barra de totais  │      │ barra de totais  │
│ R  ├──────────────────┤      ├──────────────────┤
│ a  │                  │      │                  │
│ i  │  2 colunas       │      │  1 coluna        │
│ l  │  DataTable       │      │  cards           │
└────┴──────────────────┘      ├──────────────────┤
  formulário = Dialog          │ BottomNavigation │
                               └──────────────────┘
                            formulário = bottom sheet
```

Um widget `TabelaResponsiva` decide entre `DataTable` e lista de cards a partir
da largura, para que as telas não repitam esse `if`.

## 10. Gráficos (`fl_chart`)

Os quatro do spec original:

1. **Rosca** — distribuição de gastos por pote (individual e total)
2. **Barras agrupadas** — Previsto × Gasto por pote (individual e total)
3. **Linha** — evolução de ganhos × gastos ao longo dos meses
4. **Pizza** — proporção de ganhos entre Marcos e Silvia no mês

Mais dois propostos e aceitos:

5. **Barra da cascata** — barra horizontal empilhada com os potes na ordem de
   prioridade e um marcador de onde o gasto parou. É o modelo de cálculo
   desenhado; explica o rótulo "PARE DE GASTAR" melhor que a tabela.
6. **Comprometimento futuro** — linha do total já comprometido em parcelas nos
   próximos meses. O dado sai de graça da decisão 2 (parcelas são documentos
   reais) e é a informação mais acionável para quem parcela.

Todos usam a cor cadastrada em cada pote, de modo que a mesma categoria tenha a
mesma cor em qualquer gráfico do app.

## 11. Erros, carregamento e offline

Toda tela consome `AsyncValue.when`, sem exceção:

- **loading** → skeleton com a forma do conteúdo, não spinner centralizado
- **error** → card com mensagem legível e botão "Tentar de novo"
- **data** → conteúdo

Persistência offline do Firestore habilitada no Android: edições sem sinal são
enfileiradas e sincronizam depois.

**Limitação do Windows:** `cloud_firestore` no Windows não oferece cache offline
em disco equivalente ao do Android. Sem internet, o app abre mas não carrega
dados. Isso será exibido como aviso explícito na tela de erro, não como falha
silenciosa.

## 12. Configuração do Firebase

Projeto `controlefinaceiro-b5a70`, plano Spark (50 mil leituras e 20 mil
escritas por dia — folgado para dois usuários).

### 12.1 Passos no console (manuais)

1. **Authentication → Sign-in method** → ativar **E-mail/senha**
2. **Authentication → Users** → adicionar `marcos.centrone@gmail.com` e
   `silviabborges3@gmail.com`, cada um com uma senha de aplicativo (não é a
   senha da conta Google)
3. **Firestore Database → Criar banco** → modo produção → região
   `southamerica-east1`
4. Colar o conteúdo de `firestore.rules` em **Firestore → Regras**
5. Criar os índices de §4.1 (o console oferece o link pronto na primeira vez que
   a query falta)

O app **Web** (usado pelo Windows) **não deve ser criado à mão** — o
`flutterfire configure` o registra com o identificador que o CLI espera.

### 12.2 Passos na máquina

```
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=controlefinaceiro-b5a70
```

Gera `lib/firebase_options.dart` e posiciona `google-services.json` em
`android/app/`.

### 12.3 Semeadura inicial

Na primeira execução autenticada, se `casas/principal` não existir, o app cria
o documento com os dois membros e seis potes padrão (Custo fixo 55%, Conforto
15%, Investimento 10%, Metas/Sonho 10%, Prazer 5%, Conhecimento 5% — soma 100%).
Isso evita uma primeira tela vazia sem caminho de saída.

## 13. Builds

- **Android:** `flutter build apk --release` / `flutter build appbundle`.
  `applicationId` fixado em `controle.finaceiro` para bater com o console; o nome
  do pacote Dart é `controle_financeiro` (grafia correta), pois são independentes.
- **Windows:** `flutter build windows --release` → `build/windows/x64/runner/Release/`.
  Requer Visual Studio com a carga de trabalho "Desenvolvimento para desktop com C++".

## 14. Fases de entrega

| Fase | Entrega | Verificação |
|---|---|---|
| **1. Fundação** | scaffold, Firebase, login, tema, shell responsivo, seletor de mês | autentica e navega entre telas vazias |
| **2. Domínio** | models, cascata, parcelas, totais, repositórios | `flutter test` verde com os casos de §6.1 e §6.2 |
| **3. CRUD** | Ganhos, Lei dos Potes, Gastos, Parcelas em Aberto | lançamentos reais sincronizando entre PC e celular |
| **4. Análise** | Resumo dos Potes, Gráficos, builds Windows e Android | `.exe` e `.apk` gerados |

A fase 2 precede as telas de propósito: a cascata é a regra de negócio mais
sujeita a engano e fica provada antes de existir qualquer pixel que dependa dela.

## 15. Fora de escopo

Deliberadamente ausentes, para não inflar a primeira versão:

- Recuperação de senha (duas contas fixas; redefinição pelo console resolve)
- Terceiro usuário ou múltiplas casas
- Anexos, fotos de comprovante, importação de extrato ou OCR
- Notificações push e lembretes de vencimento
- Exportação para CSV/PDF
- Metas de longo prazo e orçamento anual
- Multi-moeda; tudo é BRL
