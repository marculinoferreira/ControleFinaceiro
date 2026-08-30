# Prompt: Desenvolvimento de App de Controle Financeiro Familiar

## Contexto e Objetivo

Quero que você construa um aplicativo de controle financeiro doméstico/familiar, com CRUD completo e visualizações gráficas de ganhos e gastos. O aplicativo deve rodar em **duas pessoas** (casal), controlando entradas de dinheiro, divisão em categorias de orçamento ("potes") e lançamentos de gastos vinculados a essas categorias.

O app precisa funcionar tanto em **Windows (desktop)** quanto em **Android (mobile)**, a partir de um único código-base.

## Stack Tecnológica

- **Framework**: Flutter (Dart) — gerar build nativo para Windows (`flutter build windows`) e Android (`flutter build apk` / `appbundle`)
- **Backend/Banco de dados**: Firebase
  - **Firestore** como banco de dados na nuvem (sincronização entre dispositivos)
  - **Firebase Authentication** para login (email/senha; considerar suporte a 2 usuários fixos do casal)
- **Gráficos**: pacote `fl_chart`
- **Gerenciamento de estado**: sugerir a melhor opção (Provider, Riverpod ou Bloc) e justificar a escolha

## Usuários

O sistema tem exatamente **2 usuários fixos** (ex: Marcos e Silvia), cada um com login próprio, mas compartilhando os mesmos dados financeiros da casa (mesmo "espaço financeiro" no Firestore).

---

## Funcionalidades

### 1. Tela de Ganhos (Entradas de Renda)

- Cada mês/ano tem seu próprio registro de ganhos.
- Cada pessoa pode cadastrar **múltiplas entradas de renda** no mês, cada uma com:
  - Descrição/label (texto livre — ex: "Salário", "Vale", "Freelance")
  - Valor (R$)
- O sistema calcula automaticamente:
  - **Subtotal por pessoa** (soma das entradas dela naquele mês)
  - **Total geral** (soma dos subtotais das duas pessoas)
- CRUD completo: adicionar, editar, remover entradas de renda.

### 2. Tela "Lei dos Potes" (Configuração de Categorias de Orçamento)

- Cadastro de **até 6 potes** (categorias), cada um com:
  - Nome (texto livre — ex: "Custo fixo", "Conforto", "Investimento", "Metas/Sonho", "Prazer", "Conhecimento")
  - Porcentagem (%)
- **Validação obrigatória**: a soma das porcentagens de todos os potes cadastrados deve ser **exatamente 100%**. O sistema não deve permitir salvar/ativar uma configuração fora disso.
- A **ordem de cadastro dos potes define a ordem de prioridade** usada no efeito cascata (ver seção 4).
- Essa configuração deve poder ser reaproveitada mês a mês (não precisa recadastrar todo mês, mas deve permitir alteração caso o usuário queira mudar a distribuição).
- CRUD completo dos potes.

### 3. Tela de Gastos (Lançamentos)

- Cada lançamento de gasto tem:
  - Descrição (texto livre — ex: "Conta de água")
  - Valor (R$)
  - Pote ao qual pertence (seleção entre os 6 cadastrados)
  - Pessoa responsável pelo gasto (Marcos ou Silvia)
  - Mês/ano de referência
  - Flag "Parcelado" (sim/não)
    - Se marcado como parcelado: informar **valor da parcela** e **quantidade total de parcelas**
    - Ao salvar, o sistema deve **gerar automaticamente um lançamento em cada um dos meses seguintes**, um por parcela, com o valor da parcela, mantendo o mesmo pote e mesma pessoa. Ex: parcelado em 10x de R$ 100 lançado em Janeiro → cria lançamentos de R$ 100 em Jan, Fev, Mar... até Out.
    - Cada parcela deve manter referência à compra original e ao número da parcela (ex: "3/10") para exibição.
- CRUD completo dos gastos (incluindo editar/excluir — ao excluir uma compra parcelada, perguntar se deve excluir só aquela parcela ou todas as futuras).
- **Tela/lista de "Parcelas em aberto"**: mostrar compras parceladas ainda não finalizadas, com formato tipo "Geladeira — parcela 3/10 — R$ 100,00/mês — faltam 7 meses".
- **Visualizações de gastos**:
  - **Individual**: gastos de cada pessoa separadamente, filtráveis por mês e por pote
  - **Total**: soma dos gastos das duas pessoas juntas

### 4. Tela de Resumo dos Potes (Previsto x Gasto x Sobra, com efeito cascata)

Para cada mês, mostrar uma tabela por pote contendo:
- Nome do pote
- Porcentagem definida
- **Valor previsto** = porcentagem × total de ganhos da pessoa (ou do casal, na visão total)
- **Valor gasto** naquele pote
- **Sobra** (previsto − gasto)

**Regra de negócio — Efeito Cascata:**
Os potes são processados na **ordem em que foram cadastrados** (ordem de prioridade). O saldo (sobra ou déficit) de cada pote é somado ao previsto do próximo pote da lista, "invadindo" o saldo seguinte quando há estouro:

- `Gasto_antes(pote 1)` = gasto real acumulado da pessoa até aquele ponto
- `Sobra(pote N)` = `Valor_previsto(pote N)` − `Gasto_antes(pote N)`
- `Gasto_antes(pote N+1)` = `Sobra(pote N)` (se negativo, o excedente de gasto "come" o próximo pote; se positivo, sobra folga)

Isso deve ser calculado tanto na:
- **Visão individual** (usando o gasto real de cada pessoa)
- **Visão total** (usando o gasto combinado do casal)

Além da tabela numérica, exibir um **indicador visual/rótulo** mostrando em qual pote a pessoa "está consumindo no momento" (ex: rótulos como "CUSTO FIXO", "CONFORTO", "RESERVA", "METAS", "PARE DE GASTAR" conforme o exemplo de referência), sinalizando visualmente o nível de estouro do orçamento.

### 5. Totais Gerais do Mês

- Total de Ganhos (do casal)
- Total de Gastos (do casal)
- Saldo para passar o mês (Total de Ganhos − Total de Gastos)

### 6. Gráficos Informativos

Usando `fl_chart`, criar visualizações para:
- Distribuição de gastos por pote (gráfico de pizza/rosca) — individual e total
- Comparação Previsto x Gasto por pote (gráfico de barras) — individual e total
- Evolução de ganhos x gastos ao longo dos meses (gráfico de linha), permitindo comparar meses anteriores
- Proporção de ganhos entre Marcos e Silvia no mês (pizza ou barras)

Sugestões adicionais de gráficos são bem-vindas caso façam sentido para o contexto.

---

## Requisitos Técnicos e de Entrega

1. Projeto Flutter único, com build funcional para:
   - **Windows**: gerar executável (`flutter build windows`)
   - **Android**: gerar APK/AAB (`flutter build apk` / `flutter build appbundle`)
2. Estrutura de dados no Firestore que suporte:
   - Histórico mensal (mês/ano) de ganhos, gastos e configuração de potes
   - Consultas eficientes por mês e por pessoa
3. Autenticação via Firebase Authentication (login para as 2 pessoas da casa).
4. Organização do código em camadas (models, services/repositories, providers/controllers, telas/widgets), seguindo boas práticas de Flutter.
5. Tratamento de erros e estados de carregamento (loading) nas telas que dependem do Firestore.
6. Interface limpa e responsiva, adaptando o layout entre desktop (janela redimensionável) e mobile.

## Entregáveis Esperados

- Estrutura completa do projeto Flutter
- Modelagem de dados (models Dart + estrutura de coleções no Firestore)
- Implementação das 5 telas descritas (Ganhos, Lei dos Potes, Gastos, Parcelas em Aberto, Resumo dos Potes) + tela de Gráficos
- Lógica de cálculo do efeito cascata implementada e testável
- Lógica de geração automática de parcelas implementada
- Instruções de como configurar o projeto Firebase (Firestore + Auth) e rodar nos dois ambientes (Windows e Android)
