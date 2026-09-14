# Multiusuário — Várias Casas — Design

**Data:** 2026-09-14
**Status:** aprovado no brainstorming, aguardando revisão do documento

## 1. Contexto e escopo

O app hoje atende só Marcos e Silvia, com uma única casa hardcoded
(`casas/principal`) e dois e-mails fixos nas regras de segurança (ver
[2026-08-30-controle-financeiro-familiar-design.md](2026-08-30-controle-financeiro-familiar-design.md)
§5). O objetivo desta fase é abrir o app para qualquer pessoa via Google
Play Store, permitindo que cada uma crie sua própria casa e convide quem
quiser (cônjuge, filhos), sem depender de configuração manual no Firebase
Console a cada novo usuário.

**Já implementado e testado nesta sessão** (fora do escopo deste documento,
citado aqui por já fazer parte do código):

- Login com Google (`google_sign_in`) adicionado como método **extra** ao
  login por e-mail/senha existente, em `lib/dados/servico_auth.dart` e
  `lib/ui/telas/tela_login.dart`. O login por senha continua intocado.
- `android/app/google-services.json` atualizado com o cliente OAuth do
  Google Sign-In (client_type 1 e 3).
- Testado no emulador Android: login por senha (`marcos.centrone@gmail.com`)
  continua funcionando; login por Google com uma conta de teste
  (`marcoscentronef@gmail.com`) autentica corretamente e recebe
  `permission-denied` do Firestore — esperado, pois essa conta ainda não
  está na lista fixa de e-mails autorizados. Corrigir isso de forma
  definitiva é justamente o que este documento especifica.

## 2. Decisões tomadas

| # | Decisão | Escolha | Por quê |
|---|---|---|---|
| 1 | Vínculo pessoa–casa | **Uma casa por pessoa** | Simplifica login (sem tela de "escolher casa") e o modelo de dados. Quem quiser participar de outra casa precisa sair da atual primeiro. |
| 2 | Dado de identificação da casa | **Nome + e-mail do Google, sem CPF** | CPF é dado sensível pela LGPD e não há uso definido para ele; exigir sem necessidade só aumenta atrito e responsabilidade legal. |
| 3 | Convite de membro | **Acesso direto, sem confirmação** | Combina com o uso familiar do app: o dono digita o e-mail e a pessoa já entra ao logar com aquele e-mail. |
| 4 | Remoção de membro | **Carência de 30 dias com e-mail de aviso** | Ver §4.3. Evita perda acidental de dados de quem foi removido por engano, sem manter acesso indefinido à casa antiga. |
| 5 | Dono sair da casa | **Precisa transferir a posse antes**, a menos que seja o único membro | Uma casa nunca fica órfã enquanto tiver mais de um membro. |
| 6 | Operações de gestão de casa (criar/convidar/remover/transferir) | **Cloud Functions**, não escrita direta do app | Dados agora são de terceiros, não só da família. Lógica sensível (unicidade de 1 casa por pessoa, migração de dados na remoção, troca de dono) fica centralizada e testável no servidor, em vez de espalhada em regras do Firestore. |
| 7 | Distribuição | **Google Play Store** | Exige política de privacidade publicada (ver §7). |

## 3. Modelo de dados — Firestore

```
casas/{casaId}                         # antes: casas/principal fixo
│  nome: String
│  donoEmail: String
│  emailsAtivos: [String]              # novo — espelha os e-mails dos membros
│                                       # ativos, usado pelas regras de segurança
│  membros: {
│    "{membroId}": {
│      nome: String, email: String, cor: String, ordem: int,
│      removidoEm: Timestamp?          # novo — presente só quando removido
│    }
│  }
│
├─ potes/{poteId}        (sem mudança)
├─ ganhos/{ganhoId}       (sem mudança)
└─ gastos/{gastoId}       (sem mudança)

indiceEmail/{email}                    # nova coleção, só as Cloud Functions
│  casaId: String                      # acessam — resolve "essa pessoa é
                                        # membro de qual casa" no login
                                        # (o e-mail cabe como ID de documento
                                        # sem escape: Firestore só proíbe "/"
                                        # e IDs iguais a "." ou "..")

removidosPendentes/{casaId}_{membroId} # nova coleção interna — controla a
│  email: String                       # janela de 30 dias e os dados a
│  removidoEm: Timestamp               # migrar/apagar (§4.3)
│  dadosOrigem: { casaId, membroId }
```

`emailsAtivos` existe só para a regra de segurança conseguir checar
pertencimento com um `in` simples (ver §5), como a lista hardcoded de hoje —
só que agora mantida pelas funções em vez de escrita à mão.

## 4. Fluxos

### 4.1 Criar casa (primeiro acesso)

1. Login com Google.
2. App consulta `indiceEmail/{email}`. Se não existir, mostra a tela "Criar
   sua casa" (só pede o nome).
3. Chama `criarCasa(nome)`. Dentro de uma transação, a função:
   - confere de novo que o e-mail não tem casa (evita corrida de duplo clique
     ou dois aparelhos);
   - confere se há um registro em `removidosPendentes` para esse e-mail
     dentro dos últimos 30 dias — se houver, migra os gastos/ganhos daquele
     membro para a casa nova antes de apagar o registro pendente (§4.3);
   - cria `casas/{novoId}` com esse e-mail como único membro e dono;
   - escreve `indiceEmail/{email} → {casaId: novoId}`.

### 4.2 Convidar membro

1. Na tela "Gerenciar casa" (só o dono vê), digita-se e-mail e nome.
2. Chama `convidarMembro(email, nome)`. A função confere que quem chama é o
   dono, confere que o e-mail não pertence a outra casa (decisão 1 — recusa
   com mensagem clara se pertencer), adiciona ao mapa `membros` e a
   `emailsAtivos`, e escreve o índice.
3. Acesso liberado na hora — sem convite pendente nem confirmação (decisão 3).

### 4.3 Remover membro

1. O dono toca "Remover" num membro na tela de gestão.
2. `removerMembro(membroId)`:
   - marca o membro com `removidoEm` (não apaga o registro) e tira o e-mail
     de `emailsAtivos` — os gastos/ganhos dele somem da visão do dono
     imediatamente, pois a leitura passa a barrar aquele e-mail;
   - apaga `indiceEmail/{email}` — no próximo login, essa pessoa cai direto
     na tela de criar casa nova;
   - cria um registro em `removidosPendentes` apontando pros dados dela;
   - grava um documento na coleção `mail` (extensão *Trigger Email* do
     Firebase) avisando a remoção por e-mail.
3. Se a pessoa criar uma casa nova dentro de 30 dias, `criarCasa` migra o
   histórico automaticamente (§4.1).
4. Uma função agendada (`purgarMembrosExpirados`, 1x/dia) apaga em definitivo
   os dados de quem passou 30 dias em `removidosPendentes` sem voltar.

### 4.4 Sair da casa / transferir posse

- Dono com a casa só pra ele: "sair" é excluir a casa inteira.
- Dono com outros membros: precisa escolher um novo dono numa tela de
  transferência antes. `transferirPosse(novoDonoId)` troca `donoEmail`; o
  ex-dono vira membro comum e pode se remover depois pelo fluxo normal.

## 5. Regras de segurança

```
function isMembro(casaId) {
  return request.auth != null &&
    request.auth.token.email in
      get(/databases/$(database)/documents/casas/$(casaId)).data.emailsAtivos;
}

match /casas/{casaId} {
  allow read: if isMembro(casaId);
  allow write: if false;                     // só as Cloud Functions escrevem
  match /{colecao}/{doc} {
    allow read, write: if isMembro(casaId);  // gastos/potes/cartões/ganhos, como hoje
  }
}
match /indiceEmail/{email} {
  allow read, write: if false;               // só as Cloud Functions
}
match /removidosPendentes/{doc} {
  allow read, write: if false;               // só as Cloud Functions
}
```

Diferença chave em relação à regra atual (que compara com uma lista fixa no
próprio texto da regra): o `get()` custa uma leitura extra por operação, mas é
necessário porque a lista de membros agora muda em tempo real — o comentário
da regra atual ("a lista muda com a mesma frequência que a regra") deixa de
valer.

## 6. Cloud Functions

| Função | Tipo | Quem chama | Faz |
|---|---|---|---|
| `criarCasa(nome)` | callable | qualquer usuário autenticado sem casa | §4.1 |
| `convidarMembro(email, nome)` | callable | dono | §4.2 |
| `removerMembro(membroId)` | callable | dono | §4.3 |
| `transferirPosse(novoDonoId)` | callable | dono | §4.4 |
| `purgarMembrosExpirados` | agendada (1x/dia) | — | §4.3 passo 4 |

O envio de e-mail usa a extensão oficial **Trigger Email** do Firebase (grava
um documento na coleção `mail`, a extensão envia via SMTP configurado) em vez
de integração própria com um provedor — menos código e credenciais para
manter.

## 7. Migração dos dados atuais e distribuição

- **Dados de Marcos e Silvia:** sem migração — o vínculo já é por e-mail
  (`Casa.membroPorEmail`), não pela conta de autenticação. Passos manuais
  únicos, fora do código: apagar as duas contas de e-mail/senha atuais no
  Firebase Console e semear `indiceEmail` apontando os dois e-mails para a
  casa `principal` já existente, antes de remover o login por senha.
- **Google Play Store:** exige política de privacidade publicada (link),
  obrigatória para passar na revisão já que o app passa a coletar e-mail e
  nome de terceiros. Fica como entrega desta fase, hospedada como página
  estática simples.

## 8. Fora de escopo

- Pessoa participar de mais de uma casa ao mesmo tempo (decisão 1)
- Confirmação/aceite de convite (decisão 3)
- Cobrança ou planos pagos (mencionado como possibilidade futura, sem desenho
  agora — YAGNI)
- CPF ou qualquer outro dado de identificação civil (decisão 2)
- Recuperação de senha do login antigo (o login por senha será desativado
  após a migração de §7)
- Suporte a iOS (distribuição é só Android/Play Store nesta fase)
