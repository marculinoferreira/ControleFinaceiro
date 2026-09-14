# Multiusuário — Várias Casas — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Abrir o app para qualquer pessoa via Google Play Store — cada uma cria sua própria casa, convida quem quiser, e o dono pode remover membros ou transferir a posse — em vez da casa única hardcoded (`casas/principal`) usada hoje só por Marcos e Silvia.

**Architecture:** Cinco Cloud Functions (Firebase Functions v2, TypeScript) centralizam toda operação de gestão de casa (criar, convidar, remover, transferir posse, purgar expirados); o app Flutter passa a resolver seu `casaId` dinamicamente via a função `minhaCasa` em vez de um valor fixo, e as regras do Firestore passam a checar pertencimento contra um campo `emailsAtivos` mantido pelas funções em vez de uma lista hardcoded no texto da regra.

**Tech Stack:** Firebase Functions v2 (Node 20, TypeScript, Jest), Firestore, `cloud_functions` (pacote Flutter), Riverpod.

## Global Constraints

- Casa única por pessoa (spec §2 decisão 1) — nenhuma tela de "escolher casa".
- Sem CPF em nenhum formulário (spec §2 decisão 2).
- Convite dá acesso imediato, sem confirmação do convidado (spec §2 decisão 3).
- Remoção de membro: carência de 30 dias com e-mail de aviso antes de apagar os dados (spec §2 decisão 4, §4.3).
- Dono só sai sozinho se for o único membro; caso contrário precisa transferir a posse antes (spec §2 decisão 5, §4.4).
- Toda escrita em `casas/{casaId}` (documento raiz) e nos índices internos passa por Cloud Function — o app nunca escreve esses campos direto no Firestore (spec §2 decisão 6, §5).
- `lib/dominio/` continua sem nenhum import de Firebase (regra já estabelecida no spec de 2026-08-30 §6).

---

## Task 1: Upgrade do projeto Firebase e inicialização das Cloud Functions (manual)

Cloud Functions não roda no plano Spark (gratuito) — exige o plano Blaze
(pay-as-you-go; a cota gratuita é a mesma do Spark, só passa a permitir
serviços como Functions). Sem isto nenhuma das próximas tarefas pode ser
implantada.

**Files:**
- Create: `functions/` (gerado pelo `firebase init`)
- Modify: `firebase.json`

- [ ] **Passo 1: Upgrade do plano**

No [Firebase Console](https://console.firebase.google.com/project/controlefinaceiro-b5a70/usage/details),
clicar em "Fazer upgrade" e escolher o plano **Blaze**. Exige cartão
cadastrado, mas o uso deste app (poucas dezenas de chamadas por dia) fica
dentro da cota gratuita mensal (2 milhões de invocações).

- [ ] **Passo 2: Inicializar Functions no projeto**

```bash
firebase init functions --project=controlefinaceiro-b5a70
```

Responder: linguagem **TypeScript**, ESLint **não** (mantém o setup enxuto),
instalar dependências agora **sim**. Isso cria `functions/` com
`package.json`, `tsconfig.json` e `src/index.ts` — as próximas tarefas
substituem o conteúdo gerado.

- [ ] **Passo 3: Confirmar a estrutura**

```bash
ls functions/src
```

Esperado: `index.ts` (o gerado pelo CLI; será sobrescrito na Tarefa 2).

---

## Task 2: Scaffold das Cloud Functions + função `minhaCasa`

**Files:**
- Modify: `functions/package.json`
- Modify: `functions/tsconfig.json`
- Create: `functions/jest.config.js`
- Create: `functions/src/admin.ts`
- Create: `functions/src/erros.ts`
- Create: `functions/src/minhaCasa.ts`
- Modify: `functions/src/index.ts`
- Create: `functions/test/minhaCasa.test.ts`

**Interfaces:**
- Produces: `db` (Firestore admin instance, `functions/src/admin.ts`), `erroNaoAutenticado()` / `erroSemPermissao(msg)` / `erroInvalido(msg)` (`functions/src/erros.ts`) — usados por todas as funções das próximas tarefas.

- [ ] **Passo 1: Substituir `functions/package.json`**

```json
{
  "name": "functions",
  "scripts": {
    "build": "tsc",
    "test": "firebase emulators:exec --only firestore \"jest\"",
    "deploy": "npm run build && firebase deploy --only functions"
  },
  "engines": { "node": "20" },
  "main": "lib/index.js",
  "dependencies": {
    "firebase-admin": "^12.6.0",
    "firebase-functions": "^6.1.0"
  },
  "devDependencies": {
    "typescript": "^5.6.3",
    "jest": "^29.7.0",
    "ts-jest": "^29.2.5",
    "@types/jest": "^29.5.13",
    "@types/node": "^20.16.11"
  },
  "private": true
}
```

- [ ] **Passo 2: Substituir `functions/tsconfig.json`**

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es2020",
    "outDir": "lib",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*.ts", "test/**/*.ts"]
}
```

- [ ] **Passo 3: Criar `functions/jest.config.js`**

```js
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testMatch: ["**/test/**/*.test.ts"],
  testTimeout: 15000,
};
```

- [ ] **Passo 4: Instalar as dependências**

```bash
cd functions && npm install
```

- [ ] **Passo 5: Criar `functions/src/admin.ts`**

```typescript
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

initializeApp();
export const db = getFirestore();
```

- [ ] **Passo 6: Criar `functions/src/erros.ts`**

```typescript
import { HttpsError } from "firebase-functions/v2/https";

export function erroNaoAutenticado(): HttpsError {
  return new HttpsError("unauthenticated", "É preciso estar logado.");
}

export function erroSemPermissao(mensagem: string): HttpsError {
  return new HttpsError("permission-denied", mensagem);
}

export function erroInvalido(mensagem: string): HttpsError {
  return new HttpsError("invalid-argument", mensagem);
}
```

- [ ] **Passo 7: Escrever o teste que falha, `functions/test/minhaCasa.test.ts`**

```typescript
import { db } from "../src/admin";
import { minhaCasa } from "../src/minhaCasa";

function auth(email: string) {
  return { uid: "uid-" + email, token: { email } } as any;
}

describe("minhaCasa", () => {
  afterEach(async () => {
    const indices = await db.collection("indiceEmail").listDocuments();
    for (const i of indices) await i.delete();
  });

  it("devolve null quando o e-mail nao tem casa", async () => {
    const resposta = await minhaCasa.run({
      data: {},
      auth: auth("nova@example.com"),
    } as any);
    expect(resposta.casaId).toBeNull();
  });

  it("devolve o casaId quando o indice existe", async () => {
    await db.collection("indiceEmail").doc("existente@example.com").set({
      casaId: "casa-1",
    });

    const resposta = await minhaCasa.run({
      data: {},
      auth: auth("existente@example.com"),
    } as any);
    expect(resposta.casaId).toBe("casa-1");
  });

  it("recusa chamada sem autenticacao", async () => {
    await expect(
      minhaCasa.run({ data: {}, auth: undefined } as any),
    ).rejects.toThrow();
  });
});
```

- [ ] **Passo 8: Rodar e confirmar que falha por falta do arquivo**

```bash
cd functions && npm test
```

Esperado: FALHA — `Cannot find module '../src/minhaCasa'`.

- [ ] **Passo 9: Criar `functions/src/minhaCasa.ts`**

```typescript
import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado } from "./erros";

export const minhaCasa = onCall(async (request) => {
  const email = request.auth?.token.email as string | undefined;
  if (!email) throw erroNaoAutenticado();

  const indice = await db.collection("indiceEmail").doc(email).get();
  if (!indice.exists) return { casaId: null };
  return { casaId: indice.data()!.casaId as string };
});
```

- [ ] **Passo 10: Criar `functions/src/index.ts`**

```typescript
export { minhaCasa } from "./minhaCasa";
```

- [ ] **Passo 11: Rodar e confirmar que passa**

```bash
cd functions && npm test
```

Esperado: os 3 testes de `minhaCasa` passam (precisa do Java instalado para
o emulador do Firestore — já presente na máquina, usado pelo Android SDK).

- [ ] **Passo 12: Commit**

```bash
git add functions/ firebase.json
git commit -m "feat: scaffold das Cloud Functions e funcao minhaCasa"
```

---

## Task 3: Cloud Function `criarCasa`

Cria a casa (com o dono como único membro), o índice de e-mail, semeia os
potes padrão, e migra dados de uma remoção pendente recente (spec §4.1 e
§4.3).

**Files:**
- Create: `functions/src/potesPadrao.ts`
- Create: `functions/src/criarCasa.ts`
- Modify: `functions/src/index.ts`
- Create: `functions/test/criarCasa.test.ts`

**Interfaces:**
- Consumes: `db`, `erroNaoAutenticado()`, `erroInvalido(msg)`, `erroSemPermissao(msg)` (Task 2).
- Produces: `criarCasa` callable — `request.data: {nome: string}` →
  `{casaId: string}`. `potesPadrao()` — usada só internamente por esta
  função.

- [ ] **Passo 1: Criar `functions/src/potesPadrao.ts`**

Espelha `potesPadrao()` de `lib/dados/semeadura.dart` — são runtimes
diferentes (Dart no app, Node nas functions), então a lista é duplicada de
propósito; são 6 linhas fixas, não vale a pena um pipeline de geração de
código para isto.

```typescript
export function potesPadrao() {
  return [
    { nome: "Custo fixo", percentual: 55, ordem: 0, cor: "#26797B", icone: "casa" },
    { nome: "Conforto", percentual: 15, ordem: 1, cor: "#1565C0", icone: "sofa" },
    { nome: "Investimento", percentual: 10, ordem: 2, cor: "#00838F", icone: "grafico" },
    { nome: "Metas/Sonho", percentual: 10, ordem: 3, cor: "#EF6C00", icone: "alvo" },
    { nome: "Prazer", percentual: 5, ordem: 4, cor: "#AD1457", icone: "presente" },
    { nome: "Conhecimento", percentual: 5, ordem: 5, cor: "#4527A0", icone: "livro" },
  ];
}
```

- [ ] **Passo 2: Escrever o teste que falha, `functions/test/criarCasa.test.ts`**

```typescript
import { db } from "../src/admin";
import { criarCasa } from "../src/criarCasa";

function auth(email: string) {
  return { uid: "uid-" + email, token: { email } } as any;
}

async function limparTudo() {
  for (const nome of ["casas", "indiceEmail", "removidosPendentes"]) {
    const docs = await db.collection(nome).listDocuments();
    for (const d of docs) await db.recursiveDelete(d);
  }
}

describe("criarCasa", () => {
  afterEach(limparTudo);

  it("cria a casa, o indice e os potes padrao", async () => {
    const resposta = await criarCasa.run({
      data: { nome: "Casa da Ana" },
      auth: auth("ana@example.com"),
    } as any);

    expect(resposta.casaId).toBeTruthy();

    const casa = await db.collection("casas").doc(resposta.casaId).get();
    expect(casa.data()?.nome).toBe("Casa da Ana");
    expect(casa.data()?.donoEmail).toBe("ana@example.com");
    expect(casa.data()?.emailsAtivos).toEqual(["ana@example.com"]);

    const indice = await db
      .collection("indiceEmail")
      .doc("ana@example.com")
      .get();
    expect(indice.data()?.casaId).toBe(resposta.casaId);

    const potes = await db
      .collection("casas")
      .doc(resposta.casaId)
      .collection("potes")
      .get();
    expect(potes.size).toBe(6);
  });

  it("recusa criar uma segunda casa para o mesmo email", async () => {
    await criarCasa.run({
      data: { nome: "Casa 1" },
      auth: auth("bruno@example.com"),
    } as any);

    await expect(
      criarCasa.run({
        data: { nome: "Casa 2" },
        auth: auth("bruno@example.com"),
      } as any),
    ).rejects.toThrow();
  });

  it("migra gastos de uma remocao pendente recente", async () => {
    const casaAntigaRef = db.collection("casas").doc("casa-antiga");
    await casaAntigaRef.set({
      nome: "Casa antiga",
      donoEmail: "dono@example.com",
      emailsAtivos: ["dono@example.com"],
      membros: {},
    });
    await casaAntigaRef.collection("gastos").doc("g1").set({
      membroId: "membro-antigo",
      mesRef: "2026-09",
      descricao: "Mercado",
      valor: 100,
    });
    await db
      .collection("removidosPendentes")
      .doc("casa-antiga_membro-antigo")
      .set({
        email: "carla@example.com",
        removidoEm: new Date(),
        dadosOrigem: { casaId: "casa-antiga", membroId: "membro-antigo" },
      });

    const resposta = await criarCasa.run({
      data: { nome: "Casa nova da Carla" },
      auth: auth("carla@example.com"),
    } as any);

    const gastosNovos = await db
      .collection("casas")
      .doc(resposta.casaId)
      .collection("gastos")
      .get();
    expect(gastosNovos.size).toBe(1);
    expect(gastosNovos.docs[0].data().descricao).toBe("Mercado");

    const gastosAntigos = await casaAntigaRef.collection("gastos").get();
    expect(gastosAntigos.size).toBe(0);

    const pendenteRestante = await db
      .collection("removidosPendentes")
      .doc("casa-antiga_membro-antigo")
      .get();
    expect(pendenteRestante.exists).toBe(false);
  });
});
```

- [ ] **Passo 3: Rodar e confirmar que falha**

```bash
cd functions && npm test -- criarCasa
```

Esperado: FALHA — `Cannot find module '../src/criarCasa'`.

- [ ] **Passo 4: Criar `functions/src/criarCasa.ts`**

```typescript
import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";
import { potesPadrao } from "./potesPadrao";

export const criarCasa = onCall(async (request) => {
  const email = request.auth?.token.email as string | undefined;
  const uid = request.auth?.uid;
  if (!email || !uid) throw erroNaoAutenticado();

  const nome = (request.data?.nome as string | undefined)?.trim();
  if (!nome) throw erroInvalido("Informe o nome da casa.");

  const indiceRef = db.collection("indiceEmail").doc(email);
  const casaRef = db.collection("casas").doc();

  const casaId = await db.runTransaction(async (tx) => {
    const indiceAtual = await tx.get(indiceRef);
    if (indiceAtual.exists) {
      throw erroSemPermissao("Este e-mail já pertence a uma casa.");
    }

    tx.set(casaRef, {
      nome,
      donoEmail: email,
      emailsAtivos: [email],
      membros: {
        [uid]: {
          nome: (request.auth?.token.name as string | undefined) ?? nome,
          email,
          cor: "#2E7D32",
          ordem: 0,
        },
      },
    });
    tx.set(indiceRef, { casaId: casaRef.id });

    return casaRef.id;
  });

  const lotePotes = db.batch();
  for (const pote of potesPadrao()) {
    lotePotes.set(casaRef.collection("potes").doc(), pote);
  }
  await lotePotes.commit();

  await migrarDadosPendentes(email, casaId);

  return { casaId };
});

async function migrarDadosPendentes(email: string, casaIdNovo: string) {
  const pendentes = await db
    .collection("removidosPendentes")
    .where("email", "==", email)
    .get();

  for (const doc of pendentes.docs) {
    const { dadosOrigem } = doc.data() as {
      dadosOrigem: { casaId: string; membroId: string };
    };
    await migrarColecao("gastos", dadosOrigem, casaIdNovo);
    await migrarColecao("ganhos", dadosOrigem, casaIdNovo);
    await doc.ref.delete();
  }
}

async function migrarColecao(
  colecao: "gastos" | "ganhos",
  origem: { casaId: string; membroId: string },
  casaIdNovo: string,
) {
  const origemCol = db
    .collection("casas")
    .doc(origem.casaId)
    .collection(colecao);
  const destinoCol = db.collection("casas").doc(casaIdNovo).collection(colecao);

  const docs = await origemCol.where("membroId", "==", origem.membroId).get();
  if (docs.empty) return;

  const lote = db.batch();
  for (const doc of docs.docs) {
    lote.set(destinoCol.doc(doc.id), doc.data());
    lote.delete(doc.ref);
  }
  await lote.commit();
}
```

- [ ] **Passo 5: Adicionar o export em `functions/src/index.ts`**

```typescript
export { minhaCasa } from "./minhaCasa";
export { criarCasa } from "./criarCasa";
```

- [ ] **Passo 6: Rodar e confirmar que passa**

```bash
cd functions && npm test -- criarCasa
```

Esperado: os 3 testes passam.

- [ ] **Passo 7: Commit**

```bash
git add functions/
git commit -m "feat: Cloud Function criarCasa com seed de potes e migracao"
```

---

## Task 4: Cloud Function `convidarMembro`

**Files:**
- Create: `functions/src/convidarMembro.ts`
- Modify: `functions/src/index.ts`
- Create: `functions/test/convidarMembro.test.ts`

**Interfaces:**
- Consumes: `db`, `erroNaoAutenticado()`, `erroInvalido(msg)`, `erroSemPermissao(msg)` (Task 2).
- Produces: `convidarMembro` callable — `request.data: {casaId, email, nome}` → `{ok: true}`.

- [ ] **Passo 1: Escrever o teste que falha, `functions/test/convidarMembro.test.ts`**

```typescript
import { db } from "../src/admin";
import { convidarMembro } from "../src/convidarMembro";

function auth(email: string) {
  return { uid: "uid-" + email, token: { email } } as any;
}

async function criarCasaDireto(id: string, donoEmail: string) {
  await db
    .collection("casas")
    .doc(id)
    .set({ nome: "Casa", donoEmail, emailsAtivos: [donoEmail], membros: {} });
}

describe("convidarMembro", () => {
  afterEach(async () => {
    for (const nome of ["casas", "indiceEmail"]) {
      const docs = await db.collection(nome).listDocuments();
      for (const d of docs) await db.recursiveDelete(d);
    }
  });

  it("adiciona o membro e o indice quando quem chama e o dono", async () => {
    await criarCasaDireto("casa-1", "dono@example.com");

    await convidarMembro.run({
      data: { casaId: "casa-1", email: "convidado@example.com", nome: "Bia" },
      auth: auth("dono@example.com"),
    } as any);

    const casa = (await db.collection("casas").doc("casa-1").get()).data()!;
    const membros = Object.values(casa.membros) as any[];
    expect(membros).toHaveLength(1);
    expect(membros[0].email).toBe("convidado@example.com");
    expect(casa.emailsAtivos).toContain("convidado@example.com");

    const indice = await db
      .collection("indiceEmail")
      .doc("convidado@example.com")
      .get();
    expect(indice.data()?.casaId).toBe("casa-1");
  });

  it("recusa quando quem chama nao e o dono", async () => {
    await criarCasaDireto("casa-2", "dono@example.com");

    await expect(
      convidarMembro.run({
        data: { casaId: "casa-2", email: "x@example.com", nome: "X" },
        auth: auth("intruso@example.com"),
      } as any),
    ).rejects.toThrow();
  });

  it("recusa convidar email que ja pertence a outra casa", async () => {
    await criarCasaDireto("casa-3", "dono@example.com");
    await db
      .collection("indiceEmail")
      .doc("ocupado@example.com")
      .set({ casaId: "outra-casa" });

    await expect(
      convidarMembro.run({
        data: { casaId: "casa-3", email: "ocupado@example.com", nome: "Y" },
        auth: auth("dono@example.com"),
      } as any),
    ).rejects.toThrow();
  });
});
```

- [ ] **Passo 2: Rodar e confirmar que falha**

```bash
cd functions && npm test -- convidarMembro
```

Esperado: FALHA — `Cannot find module '../src/convidarMembro'`.

- [ ] **Passo 3: Criar `functions/src/convidarMembro.ts`**

```typescript
import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";

export const convidarMembro = onCall(async (request) => {
  const emailDono = request.auth?.token.email as string | undefined;
  if (!emailDono) throw erroNaoAutenticado();

  const casaId = request.data?.casaId as string | undefined;
  const emailConvidado = (request.data?.email as string | undefined)
    ?.trim()
    .toLowerCase();
  const nomeConvidado = (request.data?.nome as string | undefined)?.trim();
  if (!casaId || !emailConvidado || !nomeConvidado) {
    throw erroInvalido("Informe casaId, email e nome.");
  }

  const casaRef = db.collection("casas").doc(casaId);
  const indiceRef = db.collection("indiceEmail").doc(emailConvidado);

  await db.runTransaction(async (tx) => {
    const casaSnap = await tx.get(casaRef);
    if (!casaSnap.exists) throw erroInvalido("Casa não encontrada.");
    const casa = casaSnap.data()!;
    if (casa.donoEmail !== emailDono) {
      throw erroSemPermissao("Só o dono pode convidar membros.");
    }

    const indiceAtual = await tx.get(indiceRef);
    if (indiceAtual.exists) {
      throw erroSemPermissao("Este e-mail já pertence a uma casa.");
    }

    // Gera um id novo sem precisar de uma colecao real: doc() sem
    // argumento sempre sorteia um id de 20 caracteres.
    const membroId = db.collection("_ids").doc().id;
    const membrosAtuais = casa.membros ?? {};

    tx.update(casaRef, {
      [`membros.${membroId}`]: {
        nome: nomeConvidado,
        email: emailConvidado,
        cor: "#1565C0",
        ordem: Object.keys(membrosAtuais).length,
      },
      emailsAtivos: [...(casa.emailsAtivos ?? []), emailConvidado],
    });
    tx.set(indiceRef, { casaId });
  });

  return { ok: true };
});
```

- [ ] **Passo 4: Adicionar o export em `functions/src/index.ts`**

```typescript
export { minhaCasa } from "./minhaCasa";
export { criarCasa } from "./criarCasa";
export { convidarMembro } from "./convidarMembro";
```

- [ ] **Passo 5: Rodar e confirmar que passa**

```bash
cd functions && npm test -- convidarMembro
```

Esperado: os 3 testes passam.

- [ ] **Passo 6: Commit**

```bash
git add functions/
git commit -m "feat: Cloud Function convidarMembro"
```

---

## Task 5: Cloud Function `removerMembro`

Usa a extensão **Trigger Email** do Firebase (grava um documento na coleção
`mail`; a extensão cuida do envio via SMTP configurado no console — a
instalação da extensão é um passo manual fora deste plano, no console do
Firebase, antes do deploy final da Task 9).

**Files:**
- Create: `functions/src/removerMembro.ts`
- Modify: `functions/src/index.ts`
- Create: `functions/test/removerMembro.test.ts`

**Interfaces:**
- Consumes: `db`, `erroNaoAutenticado()`, `erroInvalido(msg)`, `erroSemPermissao(msg)` (Task 2).
- Produces: `removerMembro` callable — `request.data: {casaId, membroId}` → `{ok: true}`.

- [ ] **Passo 1: Escrever o teste que falha, `functions/test/removerMembro.test.ts`**

```typescript
import { db } from "../src/admin";
import { removerMembro } from "../src/removerMembro";

function auth(email: string, uid?: string) {
  return { uid: uid ?? "uid-" + email, token: { email } } as any;
}

async function criarCasaComMembro() {
  await db
    .collection("casas")
    .doc("casa-1")
    .set({
      nome: "Casa",
      donoEmail: "dono@example.com",
      emailsAtivos: ["dono@example.com", "membro@example.com"],
      membros: {
        "dono-uid": { nome: "Dono", email: "dono@example.com", cor: "#000", ordem: 0 },
        "membro-1": { nome: "Bia", email: "membro@example.com", cor: "#111", ordem: 1 },
      },
    });
  await db.collection("indiceEmail").doc("membro@example.com").set({ casaId: "casa-1" });
}

describe("removerMembro", () => {
  afterEach(async () => {
    for (const nome of ["casas", "indiceEmail", "removidosPendentes", "mail"]) {
      const docs = await db.collection(nome).listDocuments();
      for (const d of docs) await db.recursiveDelete(d);
    }
  });

  it("marca removidoEm, tira do indice e agenda o email", async () => {
    await criarCasaComMembro();

    await removerMembro.run({
      data: { casaId: "casa-1", membroId: "membro-1" },
      auth: auth("dono@example.com", "dono-uid"),
    } as any);

    const casa = (await db.collection("casas").doc("casa-1").get()).data()!;
    expect(casa.membros["membro-1"].removidoEm).toBeTruthy();
    expect(casa.emailsAtivos).toEqual(["dono@example.com"]);

    const indice = await db.collection("indiceEmail").doc("membro@example.com").get();
    expect(indice.exists).toBe(false);

    const pendente = await db
      .collection("removidosPendentes")
      .doc("casa-1_membro-1")
      .get();
    expect(pendente.data()?.email).toBe("membro@example.com");

    const emails = await db.collection("mail").get();
    expect(emails.size).toBe(1);
    expect(emails.docs[0].data().to).toBe("membro@example.com");
  });

  it("recusa quando quem chama nao e o dono", async () => {
    await criarCasaComMembro();

    await expect(
      removerMembro.run({
        data: { casaId: "casa-1", membroId: "membro-1" },
        auth: auth("membro@example.com", "membro-1"),
      } as any),
    ).rejects.toThrow();
  });

  it("recusa o dono tentar remover a si mesmo", async () => {
    await criarCasaComMembro();

    await expect(
      removerMembro.run({
        data: { casaId: "casa-1", membroId: "dono-uid" },
        auth: auth("dono@example.com", "dono-uid"),
      } as any),
    ).rejects.toThrow();
  });
});
```

- [ ] **Passo 2: Rodar e confirmar que falha**

```bash
cd functions && npm test -- removerMembro
```

Esperado: FALHA — `Cannot find module '../src/removerMembro'`.

- [ ] **Passo 3: Criar `functions/src/removerMembro.ts`**

```typescript
import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";

export const removerMembro = onCall(async (request) => {
  const emailDono = request.auth?.token.email as string | undefined;
  const uidChamador = request.auth?.uid;
  if (!emailDono || !uidChamador) throw erroNaoAutenticado();

  const casaId = request.data?.casaId as string | undefined;
  const membroId = request.data?.membroId as string | undefined;
  if (!casaId || !membroId) throw erroInvalido("Informe casaId e membroId.");

  const casaRef = db.collection("casas").doc(casaId);

  const emailRemovido = await db.runTransaction(async (tx) => {
    const casaSnap = await tx.get(casaRef);
    if (!casaSnap.exists) throw erroInvalido("Casa não encontrada.");
    const casa = casaSnap.data()!;
    if (casa.donoEmail !== emailDono) {
      throw erroSemPermissao("Só o dono pode remover membros.");
    }
    if (membroId === uidChamador) {
      throw erroInvalido(
        "O dono não pode remover a si mesmo por aqui — use transferir posse.",
      );
    }

    const membro = casa.membros?.[membroId];
    if (!membro) throw erroInvalido("Membro não encontrado.");

    tx.update(casaRef, {
      [`membros.${membroId}.removidoEm`]: FieldValue.serverTimestamp(),
      emailsAtivos: (casa.emailsAtivos ?? []).filter(
        (e: string) => e !== membro.email,
      ),
    });
    tx.delete(db.collection("indiceEmail").doc(membro.email));
    tx.set(db.collection("removidosPendentes").doc(`${casaId}_${membroId}`), {
      email: membro.email,
      removidoEm: FieldValue.serverTimestamp(),
      dadosOrigem: { casaId, membroId },
    });

    return membro.email as string;
  });

  await db.collection("mail").add({
    to: emailRemovido,
    message: {
      subject: "Você foi removido de uma casa no Controle Financeiro",
      text:
        "Você foi removido de uma casa. Se quiser, entre no app com este " +
        "mesmo e-mail para criar sua própria casa — seus dados ficam " +
        "guardados por 30 dias.",
    },
  });

  return { ok: true };
});
```

- [ ] **Passo 4: Adicionar o export em `functions/src/index.ts`**

```typescript
export { minhaCasa } from "./minhaCasa";
export { criarCasa } from "./criarCasa";
export { convidarMembro } from "./convidarMembro";
export { removerMembro } from "./removerMembro";
```

- [ ] **Passo 5: Rodar e confirmar que passa**

```bash
cd functions && npm test -- removerMembro
```

Esperado: os 3 testes passam.

- [ ] **Passo 6: Commit**

```bash
git add functions/
git commit -m "feat: Cloud Function removerMembro com carencia e aviso por email"
```

---

## Task 6: Cloud Function `transferirPosse`

**Files:**
- Create: `functions/src/transferirPosse.ts`
- Modify: `functions/src/index.ts`
- Create: `functions/test/transferirPosse.test.ts`

**Interfaces:**
- Consumes: `db`, `erroNaoAutenticado()`, `erroInvalido(msg)`, `erroSemPermissao(msg)` (Task 2).
- Produces: `transferirPosse` callable — `request.data: {casaId, membroId}` → `{ok: true}`.

- [ ] **Passo 1: Escrever o teste que falha, `functions/test/transferirPosse.test.ts`**

```typescript
import { db } from "../src/admin";
import { transferirPosse } from "../src/transferirPosse";

function auth(email: string, uid?: string) {
  return { uid: uid ?? "uid-" + email, token: { email } } as any;
}

async function criarCasaComMembro() {
  await db
    .collection("casas")
    .doc("casa-1")
    .set({
      nome: "Casa",
      donoEmail: "dono@example.com",
      emailsAtivos: ["dono@example.com", "membro@example.com"],
      membros: {
        "dono-uid": { nome: "Dono", email: "dono@example.com", cor: "#000", ordem: 0 },
        "membro-1": { nome: "Bia", email: "membro@example.com", cor: "#111", ordem: 1 },
      },
    });
}

describe("transferirPosse", () => {
  afterEach(async () => {
    const docs = await db.collection("casas").listDocuments();
    for (const d of docs) await db.recursiveDelete(d);
  });

  it("troca donoEmail para o novo dono", async () => {
    await criarCasaComMembro();

    await transferirPosse.run({
      data: { casaId: "casa-1", membroId: "membro-1" },
      auth: auth("dono@example.com", "dono-uid"),
    } as any);

    const casa = (await db.collection("casas").doc("casa-1").get()).data()!;
    expect(casa.donoEmail).toBe("membro@example.com");
  });

  it("recusa quando quem chama nao e o dono atual", async () => {
    await criarCasaComMembro();

    await expect(
      transferirPosse.run({
        data: { casaId: "casa-1", membroId: "membro-1" },
        auth: auth("membro@example.com", "membro-1"),
      } as any),
    ).rejects.toThrow();
  });

  it("recusa transferir para um membro removido", async () => {
    await criarCasaComMembro();
    await db
      .collection("casas")
      .doc("casa-1")
      .update({ "membros.membro-1.removidoEm": new Date() });

    await expect(
      transferirPosse.run({
        data: { casaId: "casa-1", membroId: "membro-1" },
        auth: auth("dono@example.com", "dono-uid"),
      } as any),
    ).rejects.toThrow();
  });
});
```

- [ ] **Passo 2: Rodar e confirmar que falha**

```bash
cd functions && npm test -- transferirPosse
```

Esperado: FALHA — `Cannot find module '../src/transferirPosse'`.

- [ ] **Passo 3: Criar `functions/src/transferirPosse.ts`**

```typescript
import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";

export const transferirPosse = onCall(async (request) => {
  const emailDono = request.auth?.token.email as string | undefined;
  if (!emailDono) throw erroNaoAutenticado();

  const casaId = request.data?.casaId as string | undefined;
  const novoDonoMembroId = request.data?.membroId as string | undefined;
  if (!casaId || !novoDonoMembroId) {
    throw erroInvalido("Informe casaId e membroId.");
  }

  const casaRef = db.collection("casas").doc(casaId);

  await db.runTransaction(async (tx) => {
    const casaSnap = await tx.get(casaRef);
    if (!casaSnap.exists) throw erroInvalido("Casa não encontrada.");
    const casa = casaSnap.data()!;
    if (casa.donoEmail !== emailDono) {
      throw erroSemPermissao("Só o dono atual pode transferir a posse.");
    }

    const novoDono = casa.membros?.[novoDonoMembroId];
    if (!novoDono || novoDono.removidoEm) {
      throw erroInvalido("Novo dono precisa ser um membro ativo da casa.");
    }

    tx.update(casaRef, { donoEmail: novoDono.email });
  });

  return { ok: true };
});
```

- [ ] **Passo 4: Adicionar o export em `functions/src/index.ts`**

```typescript
export { minhaCasa } from "./minhaCasa";
export { criarCasa } from "./criarCasa";
export { convidarMembro } from "./convidarMembro";
export { removerMembro } from "./removerMembro";
export { transferirPosse } from "./transferirPosse";
```

- [ ] **Passo 5: Rodar e confirmar que passa**

```bash
cd functions && npm test -- transferirPosse
```

Esperado: os 3 testes passam.

- [ ] **Passo 6: Commit**

```bash
git add functions/
git commit -m "feat: Cloud Function transferirPosse"
```

---

## Task 7: Cloud Function agendada `purgarMembrosExpirados`

**Files:**
- Create: `functions/src/purgarMembrosExpirados.ts`
- Modify: `functions/src/index.ts`
- Create: `functions/test/purgarMembrosExpirados.test.ts`

**Interfaces:**
- Consumes: `db` (Task 2).
- Produces: `purgarMembrosExpirados` — função agendada, sem chamada direta do app.

- [ ] **Passo 1: Escrever o teste que falha, `functions/test/purgarMembrosExpirados.test.ts`**

A função agendada (`onSchedule`) expõe seu handler em `.run()`, assim como
as `onCall` — mesma técnica de teste direto, sem precisar do emulador de
scheduler.

```typescript
import { Timestamp } from "firebase-admin/firestore";
import { db } from "../src/admin";
import { purgarMembrosExpirados } from "../src/purgarMembrosExpirados";

async function criarPendente(id: string, diasAtras: number) {
  const removidoEm = Timestamp.fromMillis(
    Date.now() - diasAtras * 24 * 60 * 60 * 1000,
  );
  await db.collection("removidosPendentes").doc(id).set({
    email: `${id}@example.com`,
    removidoEm,
    dadosOrigem: { casaId: "casa-x", membroId: id },
  });
  await db
    .collection("casas")
    .doc("casa-x")
    .collection("gastos")
    .doc(`g-${id}`)
    .set({ membroId: id, descricao: "teste", valor: 10, mesRef: "2026-09" });
}

describe("purgarMembrosExpirados", () => {
  afterEach(async () => {
    for (const nome of ["casas", "removidosPendentes"]) {
      const docs = await db.collection(nome).listDocuments();
      for (const d of docs) await db.recursiveDelete(d);
    }
  });

  it("apaga so quem passou de 30 dias", async () => {
    await criarPendente("velho", 31);
    await criarPendente("recente", 5);

    await purgarMembrosExpirados.run(undefined as any);

    const pendentes = await db.collection("removidosPendentes").listDocuments();
    expect(pendentes.map((d) => d.id)).toEqual(["recente"]);

    const gastosVelho = await db
      .collection("casas")
      .doc("casa-x")
      .collection("gastos")
      .doc("g-velho")
      .get();
    expect(gastosVelho.exists).toBe(false);

    const gastosRecente = await db
      .collection("casas")
      .doc("casa-x")
      .collection("gastos")
      .doc("g-recente")
      .get();
    expect(gastosRecente.exists).toBe(true);
  });
});
```

- [ ] **Passo 2: Rodar e confirmar que falha**

```bash
cd functions && npm test -- purgarMembrosExpirados
```

Esperado: FALHA — `Cannot find module '../src/purgarMembrosExpirados'`.

- [ ] **Passo 3: Criar `functions/src/purgarMembrosExpirados.ts`**

```typescript
import { onSchedule } from "firebase-functions/v2/scheduler";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "./admin";

const TRINTA_DIAS_MS = 30 * 24 * 60 * 60 * 1000;

export const purgarMembrosExpirados = onSchedule(
  "every 24 hours",
  async () => {
    const limite = Timestamp.fromMillis(Date.now() - TRINTA_DIAS_MS);
    const expirados = await db
      .collection("removidosPendentes")
      .where("removidoEm", "<=", limite)
      .get();

    for (const doc of expirados.docs) {
      const { dadosOrigem } = doc.data() as {
        dadosOrigem: { casaId: string; membroId: string };
      };
      await apagarColecao("gastos", dadosOrigem);
      await apagarColecao("ganhos", dadosOrigem);
      await doc.ref.delete();
    }
  },
);

async function apagarColecao(
  colecao: "gastos" | "ganhos",
  origem: { casaId: string; membroId: string },
) {
  const col = db.collection("casas").doc(origem.casaId).collection(colecao);
  const docs = await col.where("membroId", "==", origem.membroId).get();
  if (docs.empty) return;

  const lote = db.batch();
  for (const doc of docs.docs) lote.delete(doc.ref);
  await lote.commit();
}
```

- [ ] **Passo 4: Adicionar o export em `functions/src/index.ts`**

```typescript
export { minhaCasa } from "./minhaCasa";
export { criarCasa } from "./criarCasa";
export { convidarMembro } from "./convidarMembro";
export { removerMembro } from "./removerMembro";
export { transferirPosse } from "./transferirPosse";
export { purgarMembrosExpirados } from "./purgarMembrosExpirados";
```

- [ ] **Passo 5: Rodar e confirmar que passa**

```bash
cd functions && npm test -- purgarMembrosExpirados
```

Esperado: o teste passa.

- [ ] **Passo 6: Commit**

```bash
git add functions/
git commit -m "feat: Cloud Function agendada purgarMembrosExpirados"
```

---

## Task 8: Regras do Firestore

Substitui a lista hardcoded de e-mails (spec de 2026-08-30 §5) por checagem
dinâmica contra `emailsAtivos`, e tranca a escrita de `casas/{casaId}`,
`indiceEmail/*` e `removidosPendentes/*` para só as Cloud Functions (que
usam o Admin SDK e ignoram as regras).

**Files:**
- Modify: `firestore.rules`
- Create: `firestore.rules.test.js`
- Modify: `package.json` (raiz do projeto — adiciona `@firebase/rules-unit-testing` como dependência de teste, se ainda não houver `package.json` na raiz, criar um mínimo)

**Interfaces:**
- Nenhuma — regras não têm interface Dart/TS chamável, só comportamento de leitura/escrita.

- [ ] **Passo 1: Conferir se existe `package.json` na raiz do projeto**

```bash
ls package.json 2>/dev/null || echo "nao existe"
```

Se não existir, criar um mínimo:

```json
{
  "name": "controle-financeiro-rules-tests",
  "private": true,
  "scripts": {
    "test:rules": "firebase emulators:exec --only firestore \"jest --config jest.rules.config.js\""
  },
  "devDependencies": {
    "@firebase/rules-unit-testing": "^3.0.4",
    "jest": "^29.7.0"
  }
}
```

```bash
npm install
```

- [ ] **Passo 2: Criar `jest.rules.config.js`**

```js
module.exports = {
  testEnvironment: "node",
  testMatch: ["**/firestore.rules.test.js"],
  testTimeout: 15000,
};
```

- [ ] **Passo 3: Escrever o teste que falha, `firestore.rules.test.js`**

```javascript
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const fs = require("fs");

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "regras-teste",
    firestore: { rules: fs.readFileSync("firestore.rules", "utf8") },
  });
});

afterAll(async () => testEnv.cleanup());

afterEach(async () => testEnv.clearFirestore());

async function semearCasa() {
  await testEnv.withSecurityRulesDisabled(async (contexto) => {
    await contexto
      .firestore()
      .collection("casas")
      .doc("casa-1")
      .set({
        nome: "Casa",
        donoEmail: "dono@example.com",
        emailsAtivos: ["dono@example.com"],
        membros: {},
      });
  });
}

test("membro ativo le a casa", async () => {
  await semearCasa();
  const db = testEnv
    .authenticatedContext("qualquer-uid", { email: "dono@example.com" })
    .firestore();

  await assertSucceeds(db.collection("casas").doc("casa-1").get());
});

test("quem nao e membro nao le a casa", async () => {
  await semearCasa();
  const db = testEnv
    .authenticatedContext("outro-uid", { email: "estranho@example.com" })
    .firestore();

  await assertFails(db.collection("casas").doc("casa-1").get());
});

test("app nao escreve direto no documento da casa", async () => {
  await semearCasa();
  const db = testEnv
    .authenticatedContext("qualquer-uid", { email: "dono@example.com" })
    .firestore();

  await assertFails(
    db.collection("casas").doc("casa-1").update({ nome: "Hackeada" }),
  );
});

test("membro ativo le e escreve gastos da propria casa", async () => {
  await semearCasa();
  const db = testEnv
    .authenticatedContext("qualquer-uid", { email: "dono@example.com" })
    .firestore();

  await assertSucceeds(
    db
      .collection("casas")
      .doc("casa-1")
      .collection("gastos")
      .add({ descricao: "teste", valor: 10 }),
  );
});

test("indiceEmail e removidosPendentes sao inacessiveis pelo app", async () => {
  const db = testEnv
    .authenticatedContext("qualquer-uid", { email: "dono@example.com" })
    .firestore();

  await assertFails(db.collection("indiceEmail").doc("dono@example.com").get());
  await assertFails(
    db.collection("removidosPendentes").doc("casa-1_m1").get(),
  );
});
```

- [ ] **Passo 4: Rodar e confirmar que falha**

```bash
npm run test:rules
```

Esperado: FALHA nos testes de `casas` (as regras atuais ainda checam a
lista hardcoded de dois e-mails, então `dono@example.com` não passa).

- [ ] **Passo 5: Substituir `firestore.rules`**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isMembro(casaId) {
      return request.auth != null &&
        request.auth.token.email in
          get(/databases/$(database)/documents/casas/$(casaId)).data.emailsAtivos;
    }

    match /casas/{casaId} {
      allow read: if isMembro(casaId);
      allow write: if false;

      match /{colecao}/{doc} {
        allow read, write: if isMembro(casaId);
      }
    }

    match /indiceEmail/{email} {
      allow read, write: if false;
    }

    match /removidosPendentes/{doc} {
      allow read, write: if false;
    }
  }
}
```

- [ ] **Passo 6: Rodar e confirmar que passa**

```bash
npm run test:rules
```

Esperado: os 5 testes passam.

- [ ] **Passo 7: Commit**

```bash
git add firestore.rules firestore.rules.test.js jest.rules.config.js package.json package-lock.json
git commit -m "feat: regras do Firestore dinamicas por emailsAtivos"
```

---

## Task 9: Deploy das Cloud Functions e das regras (manual)

**Files:** nenhum (operação de infraestrutura).

- [ ] **Passo 1: Instalar a extensão Trigger Email (console do Firebase)**

No [Firebase Console → Extensions](https://console.firebase.google.com/project/controlefinaceiro-b5a70/extensions),
instalar **"Trigger Email from Firestore"**, apontando para a coleção
`mail` (usada em `removerMembro`, Task 5) e configurando um provedor SMTP
(ex: SendGrid, com uma conta gratuita — até 100 e-mails/dia é mais do que
suficiente aqui).

- [ ] **Passo 2: Deploy**

```bash
firebase deploy --only functions,firestore:rules --project=controlefinaceiro-b5a70
```

- [ ] **Passo 3: Conferir no console**

Em **Functions**, as 6 funções (`minhaCasa`, `criarCasa`, `convidarMembro`,
`removerMembro`, `transferirPosse`, `purgarMembrosExpirados`) devem
aparecer com status ativo.

---

## Task 10: Modelos Dart — `Casa.donoEmail` e `Membro.removidoEm`

**Files:**
- Modify: `lib/dominio/models/casa.dart`
- Modify: `lib/dominio/models/membro.dart`
- Modify: `test/dominio/models_test.dart`

**Interfaces:**
- Produces: `Casa.donoEmail` (`String`), `Membro.removidoEm` (`DateTime?`) — consumidos pela Task 14 (tela de gestão de casa).

- [ ] **Passo 1: Escrever o teste que falha em `test/dominio/models_test.dart`**

Adicionar dentro do `group('Casa', ...)` já existente (depois do teste
`membroPorId devolve null para id inexistente`):

```dart
    test('le donoEmail do mapa', () {
      final comDono = Casa.fromMap('casa-1', {
        'nome': 'Casa X',
        'donoEmail': 'dono@example.com',
        'membros': {},
      });
      expect(comDono.donoEmail, 'dono@example.com');
    });
```

E um novo `group('Membro', ...)` logo depois do `group('Casa', ...)`:

```dart
  group('Membro', () {
    test('removidoEm e null quando ausente do mapa', () {
      final membro = Membro.fromMap('m1', {
        'nome': 'Ana',
        'email': 'ana@example.com',
        'cor': '#000',
        'ordem': 0,
      });
      expect(membro.removidoEm, isNull);
    });

    test('le removidoEm quando presente', () {
      final membro = Membro.fromMap('m1', {
        'nome': 'Ana',
        'email': 'ana@example.com',
        'cor': '#000',
        'ordem': 0,
        // Testado com DateTime puro, nao Timestamp: o parser de
        // removidoEm usa duck-typing (ver Passo 4), entao o teste do
        // dominio nao precisa importar cloud_firestore — mesmo padrao
        // de test/dominio/models_test.dart para Gasto.criadoEm.
        'removidoEm': DateTime.utc(2026, 9, 1),
      });
      expect(membro.removidoEm, DateTime.utc(2026, 9, 1));
    });
  });
```

Nenhum import novo é necessário neste arquivo de teste.

- [ ] **Passo 2: Rodar e confirmar que falha**

```bash
flutter test test/dominio/models_test.dart
```

Esperado: FALHA — `donoEmail`/`removidoEm` não existem.

- [ ] **Passo 3: Modificar `lib/dominio/models/casa.dart`**

```dart
import 'membro.dart';

/// Espaco financeiro compartilhado por um grupo de pessoas.
class Casa {
  final String id;
  final String nome;
  final String donoEmail;
  final List<Membro> membros; // sempre ordenados por Membro.ordem

  const Casa({
    required this.id,
    required this.nome,
    // Default vazio, e nao obrigatorio: 18 arquivos de teste ja existentes
    // constroem `Casa(...)` sem se importar com quem e o dono (testam
    // gastos, potes, graficos — nada relacionado a posse da casa). Exigir
    // o campo ali so adicionaria ruido sem valor de teste.
    this.donoEmail = '',
    required this.membros,
  });

  factory Casa.fromMap(String id, Map<String, dynamic> mapa) {
    final bruto = (mapa['membros'] as Map<String, dynamic>? ?? {});
    final membros = bruto.entries
        .map((e) => Membro.fromMap(e.key, e.value as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
    return Casa(
      id: id,
      nome: mapa['nome'] as String? ?? 'Casa',
      donoEmail: mapa['donoEmail'] as String? ?? '',
      membros: membros,
    );
  }

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'donoEmail': donoEmail,
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

- [ ] **Passo 4: Modificar `lib/dominio/models/membro.dart`**

```dart
/// Pessoa da casa. O id e um slug curto ("marcos") nas casas antigas, ou o
/// uid do Firebase Auth / um id gerado pela Cloud Function `convidarMembro`
/// nas casas novas — nao o e-mail: chave de mapa no Firestore com ponto
/// exige FieldPath para acesso.
class Membro {
  final String id;
  final String nome;
  final String email;
  final String cor;
  final int ordem;

  /// Presente so quando o dono removeu esta pessoa da casa (spec de
  /// 2026-09-14 §4.3): a UI usa isto para escondê-la das listagens sem
  /// apagar o registro, ate a janela de 30 dias expirar.
  final DateTime? removidoEm;

  const Membro({
    required this.id,
    required this.nome,
    required this.email,
    required this.cor,
    required this.ordem,
    this.removidoEm,
  });

  factory Membro.fromMap(String id, Map<String, dynamic> mapa) => Membro(
        id: id,
        nome: mapa['nome'] as String,
        email: mapa['email'] as String,
        cor: mapa['cor'] as String? ?? '#607D8B',
        ordem: (mapa['ordem'] as num?)?.toInt() ?? 0,
        removidoEm: _lerDataOpcional(mapa['removidoEm']),
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'email': email,
        'cor': cor,
        'ordem': ordem,
      };
}

/// Mesmo truque de `Gasto._lerData` (`lib/dominio/models/gasto.dart`): o
/// Firestore devolve um `Timestamp`, mas o dominio nao importa
/// `cloud_firestore` — entao le por duck-typing em vez do tipo.
DateTime? _lerDataOpcional(dynamic bruto) {
  if (bruto == null) return null;
  if (bruto is DateTime) return bruto;
  return (bruto as dynamic).toDate() as DateTime;
}
```

- [ ] **Passo 5: Rodar e confirmar que passa**

```bash
flutter test test/dominio/models_test.dart
```

Esperado: todos os testes passam.

- [ ] **Passo 6: Rodar `flutter analyze`**

```bash
flutter analyze
```

Esperado: sem erros — `donoEmail` tem valor padrão (`''`), então os 18
arquivos de teste que já constroem `Casa(...)` sem esse campo continuam
compilando sem alteração.

- [ ] **Passo 7: Commit**

```bash
git add lib/dominio/models/casa.dart lib/dominio/models/membro.dart test/dominio/models_test.dart
git commit -m "feat: adiciona donoEmail em Casa e removidoEm em Membro"
```

---

## Task 11: `RepositorioGestaoCasa` — wrapper das Cloud Functions no Flutter

**Files:**
- Create: `lib/dados/repositorio_gestao_casa.dart`
- Modify: `pubspec.yaml` (adiciona `cloud_functions`)
- Create: `test/dados/repositorio_gestao_casa_test.dart`

**Interfaces:**
- Produces: `RepositorioGestaoCasa` (interface), `RepositorioGestaoCasaFunctions` (impl real), `RepositorioGestaoCasaFake` (fake para testes), `ErroGestaoCasa` (exception) — usados pela Task 12 (providers) e Task 14 (telas).

- [ ] **Passo 1: Adicionar a dependência**

```bash
flutter pub add cloud_functions
```

- [ ] **Passo 2: Escrever o teste que falha, `test/dados/repositorio_gestao_casa_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorio_gestao_casa.dart';

void main() {
  group('RepositorioGestaoCasaFake', () {
    test('minhaCasa comeca nula', () async {
      final repo = RepositorioGestaoCasaFake();
      expect(await repo.minhaCasa(), isNull);
    });

    test('criarCasa define o casaId e registra a chamada', () async {
      final repo = RepositorioGestaoCasaFake();
      final casaId = await repo.criarCasa('Minha Casa');
      expect(casaId, isNotEmpty);
      expect(await repo.minhaCasa(), casaId);
      expect(repo.chamadas, ['criarCasa:Minha Casa']);
    });

    test('lanca ErroGestaoCasa quando erro esta configurado', () async {
      final repo = RepositorioGestaoCasaFake()..erro = 'Este e-mail já pertence a uma casa.';
      expect(
        () => repo.criarCasa('Casa'),
        throwsA(isA<ErroGestaoCasa>()),
      );
    });

    test('convidarMembro, removerMembro e transferirPosse registram a chamada', () async {
      final repo = RepositorioGestaoCasaFake();
      await repo.convidarMembro(casaId: 'c1', email: 'a@b.com', nome: 'A');
      await repo.removerMembro(casaId: 'c1', membroId: 'm1');
      await repo.transferirPosse(casaId: 'c1', novoDonoMembroId: 'm2');
      expect(repo.chamadas, [
        'convidarMembro:a@b.com',
        'removerMembro:m1',
        'transferirPosse:m2',
      ]);
    });
  });
}
```

- [ ] **Passo 3: Rodar e confirmar que falha**

```bash
flutter test test/dados/repositorio_gestao_casa_test.dart
```

Esperado: FALHA — o arquivo `lib/dados/repositorio_gestao_casa.dart` não
existe.

- [ ] **Passo 4: Criar `lib/dados/repositorio_gestao_casa.dart`**

```dart
import 'package:cloud_functions/cloud_functions.dart';

/// Erro de gestao de casa ja traduzido para exibicao ao usuario — a
/// mensagem vem direto da Cloud Function (ver functions/src/erros.ts).
class ErroGestaoCasa implements Exception {
  final String mensagem;
  const ErroGestaoCasa(this.mensagem);

  @override
  String toString() => mensagem;
}

/// Operacoes de gestao de casa que passam por Cloud Functions, nunca por
/// escrita direta do Firestore (spec de 2026-09-14 §2 decisao 6).
abstract class RepositorioGestaoCasa {
  /// O casaId da pessoa logada, ou null se ela ainda nao tem casa.
  Future<String?> minhaCasa();

  /// Cria a casa e devolve o casaId novo.
  Future<String> criarCasa(String nome);

  Future<void> convidarMembro({
    required String casaId,
    required String email,
    required String nome,
  });

  Future<void> removerMembro({
    required String casaId,
    required String membroId,
  });

  Future<void> transferirPosse({
    required String casaId,
    required String novoDonoMembroId,
  });
}

class RepositorioGestaoCasaFunctions implements RepositorioGestaoCasa {
  final FirebaseFunctions funcoes;
  RepositorioGestaoCasaFunctions(this.funcoes);

  Future<T> _chamar<T>(
    String nome,
    Map<String, dynamic> dados,
    T Function(dynamic) ler,
  ) async {
    try {
      final resultado = await funcoes.httpsCallable(nome).call(dados);
      return ler(resultado.data);
    } on FirebaseFunctionsException catch (e) {
      throw ErroGestaoCasa(
        e.message ?? 'Não foi possível completar a operação.',
      );
    }
  }

  @override
  Future<String?> minhaCasa() =>
      _chamar('minhaCasa', const {}, (d) => d['casaId'] as String?);

  @override
  Future<String> criarCasa(String nome) =>
      _chamar('criarCasa', {'nome': nome}, (d) => d['casaId'] as String);

  @override
  Future<void> convidarMembro({
    required String casaId,
    required String email,
    required String nome,
  }) =>
      _chamar(
        'convidarMembro',
        {'casaId': casaId, 'email': email, 'nome': nome},
        (_) {},
      );

  @override
  Future<void> removerMembro({
    required String casaId,
    required String membroId,
  }) =>
      _chamar(
        'removerMembro',
        {'casaId': casaId, 'membroId': membroId},
        (_) {},
      );

  @override
  Future<void> transferirPosse({
    required String casaId,
    required String novoDonoMembroId,
  }) =>
      _chamar(
        'transferirPosse',
        {'casaId': casaId, 'membroId': novoDonoMembroId},
        (_) {},
      );
}

/// Usado nos testes de widget e para rodar a UI sem Cloud Functions.
class RepositorioGestaoCasaFake implements RepositorioGestaoCasa {
  String? casaIdAtual;
  String? erro;
  var _sequencia = 0;
  final List<String> chamadas = [];

  @override
  Future<String?> minhaCasa() async => casaIdAtual;

  @override
  Future<String> criarCasa(String nome) async {
    chamadas.add('criarCasa:$nome');
    if (erro != null) throw ErroGestaoCasa(erro!);
    casaIdAtual = 'casa-fake-${_sequencia++}';
    return casaIdAtual!;
  }

  @override
  Future<void> convidarMembro({
    required String casaId,
    required String email,
    required String nome,
  }) async {
    chamadas.add('convidarMembro:$email');
    if (erro != null) throw ErroGestaoCasa(erro!);
  }

  @override
  Future<void> removerMembro({
    required String casaId,
    required String membroId,
  }) async {
    chamadas.add('removerMembro:$membroId');
    if (erro != null) throw ErroGestaoCasa(erro!);
  }

  @override
  Future<void> transferirPosse({
    required String casaId,
    required String novoDonoMembroId,
  }) async {
    chamadas.add('transferirPosse:$novoDonoMembroId');
    if (erro != null) throw ErroGestaoCasa(erro!);
  }
}
```

- [ ] **Passo 5: Rodar e confirmar que passa**

```bash
flutter test test/dados/repositorio_gestao_casa_test.dart
```

Esperado: os 4 testes passam.

- [ ] **Passo 6: Commit**

```bash
git add lib/dados/repositorio_gestao_casa.dart test/dados/repositorio_gestao_casa_test.dart pubspec.yaml pubspec.lock
git commit -m "feat: RepositorioGestaoCasa (wrapper das Cloud Functions)"
```

---

## Task 12: `casaId` dinâmico — repositórios, providers e remoção da semeadura antiga

Esta é a mudança de encanamento: hoje `casaId` é a constante fixa
`'principal'` (`lib/dados/repositorio_firestore.dart:12`) e os repositórios
são instanciados uma vez em `main.dart`. Agora o `casaId` só é conhecido
depois do login, então os repositórios passam a ser construídos a partir de
um `casaIdProvider` resolvido em tempo de execução.

**Files:**
- Modify: `lib/dados/repositorio_firestore.dart`
- Modify: `lib/estado/providers.dart`
- Modify: `lib/main.dart`
- Delete: `lib/dados/semeadura.dart`
- Delete: `test/dados/semeadura_test.dart` (se existir)
- Modify: `test/ui/tela_cartoes_test.dart` — remove o `group('semeadura', ...)`
  que testava `cartoesPadrao()`/`semear()`, apagados no Passo 6.

**Interfaces:**
- Consumes: `RepositorioGestaoCasa` (Task 11).
- Produces: `casaIdProvider` (`FutureProvider<String?>`) — consumido pela
  Task 13 (roteamento em `app.dart`) e Task 14 (telas de gestão de casa).

- [ ] **Passo 1: Confirmar se `semeadura.dart` tem teste dedicado**

```bash
grep -rl "semeadura" test/
```

Se existir `test/dados/semeadura_test.dart`, será apagado no Passo 6.

- [ ] **Passo 2: Modificar `lib/dados/repositorio_firestore.dart`**

Trocar a constante global por um parâmetro de construtor em cada classe.

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../dominio/models/cartao.dart';
import '../dominio/models/casa.dart';
import '../dominio/models/ganho.dart';
import '../dominio/models/gasto.dart';
import '../dominio/models/pote.dart';
import '../dominio/parcelas.dart';
import 'repositorios.dart';

DocumentReference<Map<String, dynamic>> _casaDoc(
  FirebaseFirestore db,
  String casaId,
) =>
    db.collection('casas').doc(casaId);

class CasaFirestore implements RepositorioCasa {
  final FirebaseFirestore db;
  final String casaId;
  CasaFirestore(this.db, this.casaId);

  @override
  Stream<Casa?> observar() => _casaDoc(db, casaId)
      .snapshots()
      .map((d) => d.exists ? Casa.fromMap(d.id, d.data()!) : null);

  @override
  Future<void> criar(Casa casa) => _casaDoc(db, casaId).set(casa.toMap());
}

class PotesFirestore implements RepositorioPotes {
  final FirebaseFirestore db;
  final String casaId;
  PotesFirestore(this.db, this.casaId);

  CollectionReference<Map<String, dynamic>> get _col =>
      _casaDoc(db, casaId).collection('potes');

  @override
  Stream<List<Pote>> observar() => _col.orderBy('ordem').snapshots().map(
      (s) => s.docs.map((d) => Pote.fromMap(d.id, d.data())).toList());

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

class CartoesFirestore implements RepositorioCartoes {
  final FirebaseFirestore db;
  final String casaId;
  CartoesFirestore(this.db, this.casaId);

  CollectionReference<Map<String, dynamic>> get _col =>
      _casaDoc(db, casaId).collection('cartoes');

  @override
  Stream<List<Cartao>> observar() => _col
      .orderBy('ordem')
      .snapshots()
      .map((s) => s.docs.map((d) => Cartao.fromMap(d.id, d.data())).toList());

  @override
  Future<void> salvar(Cartao cartao) => cartao.id.isEmpty
      ? _col.add(cartao.toMap())
      : _col.doc(cartao.id).update(cartao.toMap());

  @override
  Future<void> remover(String id) => _col.doc(id).delete();
}

class GanhosFirestore implements RepositorioGanhos {
  final FirebaseFirestore db;
  final String casaId;
  GanhosFirestore(this.db, this.casaId);

  CollectionReference<Map<String, dynamic>> get _col =>
      _casaDoc(db, casaId).collection('ganhos');

  @override
  Stream<List<Ganho>> observarMes(String mesRef) => _col
      .where('mesRef', isEqualTo: mesRef)
      .snapshots()
      .map((s) => s.docs.map((d) => Ganho.fromMap(d.id, d.data())).toList());

  @override
  Stream<List<Ganho>> observarIntervalo(String inicio, String fim) => _col
      .where('mesRef', isGreaterThanOrEqualTo: inicio)
      .where('mesRef', isLessThanOrEqualTo: fim)
      .orderBy('mesRef')
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
  final String casaId;
  final Uuid _uuid = const Uuid();

  GastosFirestore(this.db, this.casaId);

  CollectionReference<Map<String, dynamic>> get _col =>
      _casaDoc(db, casaId).collection('gastos');

  @override
  Stream<List<Gasto>> observarMes(String mesRef) => _col
      .where('mesRef', isEqualTo: mesRef)
      .orderBy('criadoEm', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Gasto.fromMap(d.id, d.data())).toList());

  @override
  Stream<List<Gasto>> observarIntervalo(String inicio, String fim) => _col
      .where('mesRef', isGreaterThanOrEqualTo: inicio)
      .where('mesRef', isLessThanOrEqualTo: fim)
      .orderBy('mesRef')
      .snapshots()
      .map((s) => s.docs.map((d) => Gasto.fromMap(d.id, d.data())).toList());

  @override
  Stream<List<Gasto>> observarParceladosDesde(String mesRef) => _col
      .where('parcelado', isEqualTo: true)
      .where('mesRef', isGreaterThanOrEqualTo: mesRef)
      .orderBy('mesRef')
      .snapshots()
      .map((s) => s.docs.map((d) => Gasto.fromMap(d.id, d.data())).toList());

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
  Future<void> atualizarCompra({
    required Gasto editado,
    required ModoEdicao alcance,
    required int novaQuantidade,
  }) async {
    final compraId = editado.compraId;
    if (compraId == null) return atualizar(editado);

    final snap = await _col.where('compraId', isEqualTo: compraId).get();
    final existentes =
        snap.docs.map((d) => Gasto.fromMap(d.id, d.data())).toList();

    final plano = planejarEdicaoCompra(
      existentes: existentes,
      editado: editado,
      alcance: alcance,
      novaQuantidade: novaQuantidade,
    );
    if (plano.vazio) return;

    final lote = db.batch();
    for (final g in plano.atualizar) {
      lote.update(_col.doc(g.id), g.toMap());
    }
    for (final id in plano.remover) {
      lote.delete(_col.doc(id));
    }
    for (final g in plano.criar) {
      lote.set(_col.doc(), g.toMap());
    }
    await lote.commit();
  }

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

- [ ] **Passo 3: Modificar `lib/estado/providers.dart`**

No topo do arquivo, adicionar o import de `repositorio_gestao_casa.dart`.
Substituir o bloco de infraestrutura (linhas 20–48 do arquivo atual) por:

```dart
// --- Infraestrutura: sobrescrita em main.dart ------------------------------

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final servicoAuthProvider = Provider<ServicoAuth>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final funcoesProvider = Provider<FirebaseFunctions>(
  (ref) => throw UnimplementedError('sobrescrito em main.dart'),
);

final repositorioGestaoCasaProvider = Provider<RepositorioGestaoCasa>(
  (ref) => RepositorioGestaoCasaFunctions(ref.watch(funcoesProvider)),
);

/// O casaId da pessoa logada, resolvido pela Cloud Function `minhaCasa`.
/// Null quando ainda nao tem casa (mostra a tela de criar casa) ou quando
/// nao ha ninguem logado.
final casaIdProvider = FutureProvider<String?>((ref) async {
  final email = ref.watch(emailLogadoProvider).value;
  if (email == null) return null;
  return ref.watch(repositorioGestaoCasaProvider).minhaCasa();
});

/// Os providers abaixo só são lidos depois que a tela de roteamento
/// (Task 13) já confirmou que `casaIdProvider` tem um valor não nulo.
String _casaIdResolvido(Ref ref) => ref.watch(casaIdProvider).value!;

final repositorioCasaProvider = Provider<RepositorioCasa>((ref) =>
    CasaFirestore(ref.watch(firestoreProvider), _casaIdResolvido(ref)));

final repositorioPotesProvider = Provider<RepositorioPotes>((ref) =>
    PotesFirestore(ref.watch(firestoreProvider), _casaIdResolvido(ref)));

final repositorioCartoesProvider = Provider<RepositorioCartoes>((ref) =>
    CartoesFirestore(ref.watch(firestoreProvider), _casaIdResolvido(ref)));

final repositorioGanhosProvider = Provider<RepositorioGanhos>((ref) =>
    GanhosFirestore(ref.watch(firestoreProvider), _casaIdResolvido(ref)));

final repositorioGastosProvider = Provider<RepositorioGastos>((ref) =>
    GastosFirestore(ref.watch(firestoreProvider), _casaIdResolvido(ref)));
```

Adicionar também os imports que faltam no topo do arquivo:

```dart
import 'package:cloud_functions/cloud_functions.dart';
import '../dados/repositorio_firestore.dart';
import '../dados/repositorio_gestao_casa.dart';
```

(`repositorio_firestore.dart` provavelmente já não estava importado aqui
porque main.dart fazia a ligação; agora os providers instanciam direto,
então o import passa a ser necessário.)

- [ ] **Passo 4: Modificar `lib/main.dart`**

Remove a construção antecipada dos repositórios e o `_SemearAoLogar`
(a semeadura de potes passa a acontecer dentro da Cloud Function
`criarCasa`, Task 3):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  runApp(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        servicoAuthProvider
            .overrideWithValue(AuthFirebase(FirebaseAuth.instance)),
        funcoesProvider.overrideWithValue(FirebaseFunctions.instance),
      ],
      child: const App(),
    ),
  );
}
```

- [ ] **Passo 5: Rodar `flutter analyze`**

```bash
flutter analyze
```

Esperado: sem erros de compilação — `semeadura.dart` ainda compila (usa só
as interfaces de `repositorios.dart`, não os construtores concretos que
mudaram no Passo 2), mas fica **funcionalmente obsoleto**: depois do
Passo 4, nada mais chama `semear()`, e mesmo que chamasse, `casa.criar()`
seria negado em tempo de execução pelas novas regras (Task 8), que
proíbem o cliente escrever em `casas/{casaId}`. Por isso ele é apagado no
próximo passo, não só desativado.

- [ ] **Passo 6: Apagar `lib/dados/semeadura.dart` e seu teste**

```bash
rm lib/dados/semeadura.dart
rm -f test/dados/semeadura_test.dart
```

A lista `potesPadrao()` continua existindo — só que agora só em
`functions/src/potesPadrao.ts` (Task 3), porque a semeadura de uma casa
nova (potes **e** cartões) passou a ser responsabilidade da Cloud Function
`criarCasa`, não do cliente. Este plano não porta o seed de cartões para a
função (spec §8 não pede isso — uma casa nova nasce sem cartões
pré-cadastrados, e a pessoa adiciona os que usa pela tela de Cartões, que
já suporta isso).

- [ ] **Passo 7: Remover o grupo de testes de semeadura em `test/ui/tela_cartoes_test.dart`**

Esse arquivo importa `package:controle_financeiro/dados/semeadura.dart` e
tem um `group('semeadura', ...)` com 3 testes (`traz os cinco cartoes da
casa, na ordem`, `semear cria os cartoes quando nao ha nenhum`, `semear
nao duplica quando ja existe cartao`) que testam exatamente o
comportamento apagado no Passo 6. Remover:
- a linha `import 'package:controle_financeiro/dados/semeadura.dart';`
- o `group('semeadura', () { ... })` inteiro (linhas 48–88 no arquivo
  atual), mantendo os demais grupos (`listagem`, etc.) intactos.

- [ ] **Passo 8: Rodar `flutter analyze` de novo**

```bash
flutter analyze
```

Esperado: sem erros.

- [ ] **Passo 9: Rodar a suite inteira**

```bash
flutter test
```

Esperado: todos os testes continuam passando — os testes de widget
sobrescrevem `repositorioCasaProvider` etc. com fakes via
`overrideWithValue`, o que continua funcionando independente de como o
provider é construído por baixo (ver `test/ui/shell_test.dart:19`).

- [ ] **Passo 10: Commit**

```bash
git add lib/dados/repositorio_firestore.dart lib/estado/providers.dart lib/main.dart
git add test/ui/tela_cartoes_test.dart
git rm lib/dados/semeadura.dart
git rm -f test/dados/semeadura_test.dart
git commit -m "feat: casaId dinamico via Cloud Function minhaCasa, remove semeadura fixa"
```

---

## Task 13: Roteamento e tela "Criar sua casa"

Troca a tela `_SemAcesso` (usada hoje quando o e-mail autentica mas não é
membro da casa fixa) pela lógica nova: casaId nulo → criar casa; casaId
resolvido → abre a casa normalmente.

**Files:**
- Modify: `lib/ui/app.dart`
- Create: `lib/ui/telas/tela_criar_casa.dart`
- Create: `test/ui/tela_criar_casa_test.dart`
- Modify: `test/ui/*` — nenhum teste hoje cobre o roteamento (`_Roteador`),
  então não há testes existentes para ajustar aqui, só o novo.

**Interfaces:**
- Consumes: `casaIdProvider` (Task 12), `RepositorioGestaoCasa` (Task 11).

- [ ] **Passo 1: Escrever o teste que falha, `test/ui/tela_criar_casa_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorio_gestao_casa.dart';
import 'package:controle_financeiro/dados/servico_auth.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/app.dart';

void main() {
  testWidgets('sem casa mostra a tela de criar casa, com casa mostra o shell',
      (tester) async {
    final auth = AuthFake()..entrar(email: 'nova@example.com', senha: 'x');
    final gestao = RepositorioGestaoCasaFake();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicoAuthProvider.overrideWithValue(auth),
          repositorioGestaoCasaProvider.overrideWithValue(gestao),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criar sua casa'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_nome_casa')), 'Casa da Ana');
    await tester.tap(find.byKey(const Key('botao_criar_casa')));
    await tester.pumpAndSettle();

    expect(find.text('Criar sua casa'), findsNothing);
    expect(gestao.chamadas, ['criarCasa:Casa da Ana']);
  });
}
```

- [ ] **Passo 2: Rodar e confirmar que falha**

```bash
flutter test test/ui/tela_criar_casa_test.dart
```

Esperado: FALHA — texto "Criar sua casa" não encontrado (a tela ainda não
existe, e `app.dart` ainda roteia pela lógica antiga).

- [ ] **Passo 3: Criar `lib/ui/telas/tela_criar_casa.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/providers.dart';

class TelaCriarCasa extends ConsumerStatefulWidget {
  const TelaCriarCasa({super.key});

  @override
  ConsumerState<TelaCriarCasa> createState() => _TelaCriarCasaState();
}

class _TelaCriarCasaState extends ConsumerState<TelaCriarCasa> {
  final _nome = TextEditingController();
  String? _erro;
  bool _criando = false;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Informe o nome da casa.');
      return;
    }

    setState(() {
      _erro = null;
      _criando = true;
    });

    try {
      await ref.read(repositorioGestaoCasaProvider).criarCasa(nome);
      ref.invalidate(casaIdProvider);
    } on ErroGestaoCasa catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _criando = false);
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
                  'Criar sua casa',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Esta será a sua casa no Controle Financeiro. Você pode '
                  'convidar outras pessoas depois.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('campo_nome_casa'),
                  controller: _nome,
                  decoration: const InputDecoration(
                    labelText: 'Nome da casa',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _erro!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('botao_criar_casa'),
                  onPressed: _criando ? null : _criar,
                  child: _criando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Criar casa'),
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

- [ ] **Passo 4: Modificar `lib/ui/app.dart`**

Substituir `_CasaOuSemAcesso` e `_SemAcesso` pela lógica baseada em
`casaIdProvider`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/providers.dart';
import 'shell.dart';
import 'telas/tela_criar_casa.dart';
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
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
        return const _CasaOuCriarCasa();
      },
    );
  }
}

/// Depois de logado, resolve em qual casa a pessoa esta (ou se ainda
/// precisa criar uma) via a Cloud Function `minhaCasa`.
class _CasaOuCriarCasa extends ConsumerWidget {
  const _CasaOuCriarCasa();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casaId = ref.watch(casaIdProvider);

    return casaId.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: ErroComRecarregar(
          erro: e,
          aoRecarregar: () => ref.invalidate(casaIdProvider),
        ),
      ),
      data: (id) => id == null ? const TelaCriarCasa() : const Shell(),
    );
  }
}
```

- [ ] **Passo 5: Rodar e confirmar que passa**

```bash
flutter test test/ui/tela_criar_casa_test.dart
```

Esperado: passa.

- [ ] **Passo 6: Rodar a suite inteira**

```bash
flutter test
```

Esperado: todos os testes passam (nenhum teste existente cobria
`_SemAcesso`, então não há regressão a corrigir).

- [ ] **Passo 7: Commit**

```bash
git add lib/ui/app.dart lib/ui/telas/tela_criar_casa.dart test/ui/tela_criar_casa_test.dart
git commit -m "feat: tela de criar casa e roteamento por casaId dinamico"
```

---

## Task 14: Tela "Gerenciar casa" (convidar, remover, transferir)

**Files:**
- Create: `lib/ui/telas/tela_gerenciar_casa.dart`
- Modify: `lib/ui/shell.dart`
- Create: `test/ui/tela_gerenciar_casa_test.dart`

**Interfaces:**
- Consumes: `RepositorioGestaoCasa` (Task 11), `casaProvider`,
  `membroLogadoProvider` (já existentes), `Casa.donoEmail`,
  `Membro.removidoEm` (Task 10).

- [ ] **Passo 1: Escrever o teste que falha, `test/ui/tela_gerenciar_casa_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/dados/repositorio_gestao_casa.dart';
import 'package:controle_financeiro/dados/repositorios.dart';
import 'package:controle_financeiro/dominio/models/casa.dart';
import 'package:controle_financeiro/dominio/models/membro.dart';
import 'package:controle_financeiro/estado/providers.dart';
import 'package:controle_financeiro/ui/telas/tela_gerenciar_casa.dart';

void main() {
  Casa casaComDono() => const Casa(
        id: 'casa-1',
        nome: 'Casa X',
        donoEmail: 'dono@example.com',
        membros: [
          Membro(id: 'm-dono', nome: 'Dono', email: 'dono@example.com', cor: '#000', ordem: 0),
          Membro(id: 'm-bia', nome: 'Bia', email: 'bia@example.com', cor: '#111', ordem: 1),
        ],
      );

  testWidgets('dono ve o botao de convidar e a lista de membros ativos',
      (tester) async {
    final gestao = RepositorioGestaoCasaFake();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casaComDono())),
          repositorioGestaoCasaProvider.overrideWithValue(gestao),
        ],
        child: MaterialApp(home: TelaGerenciarCasa(donoEmail: 'dono@example.com', casaId: 'casa-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bia'), findsOneWidget);
    expect(find.byKey(const Key('botao_convidar')), findsOneWidget);
  });

  testWidgets('convidar chama o repositorio com o email digitado', (tester) async {
    final gestao = RepositorioGestaoCasaFake();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casaComDono())),
          repositorioGestaoCasaProvider.overrideWithValue(gestao),
        ],
        child: MaterialApp(home: TelaGerenciarCasa(donoEmail: 'dono@example.com', casaId: 'casa-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('botao_convidar')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_email_convite')), 'novo@example.com');
    await tester.enterText(find.byKey(const Key('campo_nome_convite')), 'Novo');
    await tester.tap(find.byKey(const Key('botao_confirmar_convite')));
    await tester.pumpAndSettle();

    expect(gestao.chamadas, ['convidarMembro:novo@example.com']);
  });

  testWidgets('remover chama o repositorio com o membroId', (tester) async {
    final gestao = RepositorioGestaoCasaFake();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioCasaProvider.overrideWithValue(RepositorioCasaFake(casaComDono())),
          repositorioGestaoCasaProvider.overrideWithValue(gestao),
        ],
        child: MaterialApp(home: TelaGerenciarCasa(donoEmail: 'dono@example.com', casaId: 'casa-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('remover_m-bia')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await tester.pumpAndSettle();

    expect(gestao.chamadas, ['removerMembro:m-bia']);
  });
}
```

- [ ] **Passo 2: Rodar e confirmar que falha**

```bash
flutter test test/ui/tela_gerenciar_casa_test.dart
```

Esperado: FALHA — `tela_gerenciar_casa.dart` não existe.

- [ ] **Passo 3: Criar `lib/ui/telas/tela_gerenciar_casa.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dados/repositorio_gestao_casa.dart';
import '../../dominio/models/membro.dart';
import '../../estado/providers.dart';

class TelaGerenciarCasa extends ConsumerWidget {
  final String casaId;
  final String donoEmail;

  const TelaGerenciarCasa({
    super.key,
    required this.casaId,
    required this.donoEmail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casa = ref.watch(casaProvider).value;
    final membrosAtivos =
        casa?.membros.where((m) => m.removidoEm == null).toList() ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar casa')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('botao_convidar'),
        onPressed: () => _abrirConvite(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Convidar'),
      ),
      body: ListView.builder(
        itemCount: membrosAtivos.length,
        itemBuilder: (context, i) {
          final membro = membrosAtivos[i];
          final ehDono = membro.email == donoEmail;
          return ListTile(
            title: Text(membro.nome),
            subtitle: Text(membro.email),
            trailing: ehDono
                ? const Chip(label: Text('Dono'))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const Key('transferir_${membro.id}'),
                        tooltip: 'Transferir posse',
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: () =>
                            _confirmarTransferir(context, ref, membro),
                      ),
                      IconButton(
                        key: Key('remover_${membro.id}'),
                        tooltip: 'Remover',
                        icon: const Icon(Icons.person_remove),
                        onPressed: () =>
                            _confirmarRemover(context, ref, membro),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Future<void> _abrirConvite(BuildContext context, WidgetRef ref) async {
    final email = TextEditingController();
    final nome = TextEditingController();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Convidar membro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('campo_nome_convite'),
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              key: const Key('campo_email_convite'),
              controller: email,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('botao_confirmar_convite'),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Convidar'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(repositorioGestaoCasaProvider).convidarMembro(
            casaId: casaId,
            email: email.text.trim(),
            nome: nome.text.trim(),
          );
    } on ErroGestaoCasa catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  Future<void> _confirmarRemover(
    BuildContext context,
    WidgetRef ref,
    Membro membro,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Remover membro'),
        content: Text(
          'Remover ${membro.nome} da casa? A pessoa recebe um aviso por '
          'e-mail e pode criar a própria casa depois — os dados dela ficam '
          'guardados por 30 dias.',
        ),
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

    if (confirmou != true) return;
    if (!context.mounted) return;

    try {
      await ref
          .read(repositorioGestaoCasaProvider)
          .removerMembro(casaId: casaId, membroId: membro.id);
    } on ErroGestaoCasa catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  Future<void> _confirmarTransferir(
    BuildContext context,
    WidgetRef ref,
    Membro membro,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Transferir posse'),
        content: Text('Tornar ${membro.nome} o novo dono desta casa?'),
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

    if (confirmou != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(repositorioGestaoCasaProvider).transferirPosse(
            casaId: casaId,
            novoDonoMembroId: membro.id,
          );
    } on ErroGestaoCasa catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }
}
```

- [ ] **Passo 4: Rodar e confirmar que passa**

```bash
flutter test test/ui/tela_gerenciar_casa_test.dart
```

Esperado: os 3 testes passam.

- [ ] **Passo 5: Adicionar o acesso em `lib/ui/shell.dart`**

No `AppBar.actions`, antes do botão de Sair, adicionar um botão visível só
para o dono. Modificar o import e o array `actions`:

```dart
import '../dados/repositorio_gestao_casa.dart'; // so se necessario para tipos; normalmente nao precisa
import 'telas/tela_gerenciar_casa.dart';
```

```dart
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
```

(O import de `repositorio_gestao_casa.dart` não é necessário aqui — remova
se o analyzer acusar import não usado; ele já fica disponível
transitivamente através dos providers.)

- [ ] **Passo 6: Rodar a suite inteira**

```bash
flutter analyze && flutter test
```

Esperado: sem erros, todos os testes passam.

- [ ] **Passo 7: Commit**

```bash
git add lib/ui/telas/tela_gerenciar_casa.dart lib/ui/shell.dart test/ui/tela_gerenciar_casa_test.dart
git commit -m "feat: tela de gerenciar casa (convidar, remover, transferir posse)"
```

---

## Task 15: Migração dos dados de Marcos e Silvia (manual)

Sem código — só passos de infraestrutura, feitos uma vez. Ver spec de
2026-09-14 §7.

- [ ] **Passo 1: Apagar as duas contas antigas**

No [Firebase Console → Authentication → Users](https://console.firebase.google.com/project/controlefinaceiro-b5a70/authentication/users),
apagar as contas de e-mail/senha de `marcos.centrone@gmail.com` e
`silviabborges3@gmail.com`. Isto não afeta os dados no Firestore — o
vínculo é por e-mail (`Casa.membroPorEmail`), não pela conta de auth.

- [ ] **Passo 2: Adicionar `donoEmail` na casa existente**

A casa `principal` foi criada antes deste plano e não tem `donoEmail`. Via
Firebase Console → Firestore → `casas/principal`, adicionar manualmente o
campo `donoEmail: "marcos.centrone@gmail.com"` e o campo
`emailsAtivos: ["marcos.centrone@gmail.com", "silviabborges3@gmail.com"]`
(as novas regras da Task 8 exigem esse campo para autorizar leitura).

- [ ] **Passo 3: Seed do índice de e-mail**

Ainda no Console → Firestore, criar a coleção `indiceEmail` com dois
documentos:
- id `marcos.centrone@gmail.com`, campo `casaId: "principal"`
- id `silviabborges3@gmail.com`, campo `casaId: "principal"`

- [ ] **Passo 4: Testar o login com Google pros dois emails reais**

Repetir o teste manual já feito nesta sessão com a conta de teste
(`marcoscentronef@gmail.com`), agora com `marcos.centrone@gmail.com` e o
e-mail da Silvia: login com Google deve abrir a casa `principal`
normalmente, sem `permission-denied`.

- [ ] **Passo 5: Remover o login por senha do app**

Só depois do Passo 4 confirmado — remover o formulário de e-mail/senha de
`lib/ui/telas/tela_login.dart` e o método `entrar()` de
`lib/dados/servico_auth.dart`, deixando só "Entrar com Google". Este passo
fica registrado aqui como lembrete; não faz parte do escopo de código
deste plano (é a última etapa, e só deve rodar depois que o Passo 4 for
confirmado manualmente por Marcos).

---

## Task 16: Cloud Functions `sairDaCasa` e `excluirCasa`

Fecha uma lacuna da spec §4.4 não coberta pelas Tasks 3–7: um membro comum
(não dono) precisa conseguir sair da casa por conta própria, e o dono
precisa conseguir excluir a casa quando é o único membro restante. Reusa
exatamente o mesmo mecanismo de carência de 30 dias de `removerMembro`
(Task 5) para `sairDaCasa` — a pessoa que sai também tem direito à janela
de recuperação de dados, e não só quem é removido por outra pessoa.

**Files:**
- Create: `functions/src/sairDaCasa.ts`
- Create: `functions/src/excluirCasa.ts`
- Modify: `functions/src/index.ts`
- Create: `functions/test/sairDaCasa.test.ts`
- Create: `functions/test/excluirCasa.test.ts`

**Interfaces:**
- Consumes: `db`, `erroNaoAutenticado()`, `erroInvalido(msg)`, `erroSemPermissao(msg)` (Task 2).
- Produces: `sairDaCasa` callable — `request.data: {casaId}` → `{ok: true}`. `excluirCasa` callable — `request.data: {casaId}` → `{ok: true}`.

- [ ] **Passo 1: Escrever o teste que falha, `functions/test/sairDaCasa.test.ts`**

```typescript
import { db } from "../src/admin";
import { sairDaCasa } from "../src/sairDaCasa";

function auth(email: string, uid?: string) {
  return { uid: uid ?? "uid-" + email, token: { email } } as any;
}

async function criarCasaComMembro() {
  await db
    .collection("casas")
    .doc("casa-1")
    .set({
      nome: "Casa",
      donoEmail: "dono@example.com",
      emailsAtivos: ["dono@example.com", "membro@example.com"],
      membros: {
        "dono-uid": { nome: "Dono", email: "dono@example.com", cor: "#000", ordem: 0 },
        "membro-1": { nome: "Bia", email: "membro@example.com", cor: "#111", ordem: 1 },
      },
    });
  await db.collection("indiceEmail").doc("membro@example.com").set({ casaId: "casa-1" });
}

describe("sairDaCasa", () => {
  afterEach(async () => {
    for (const nome of ["casas", "indiceEmail", "removidosPendentes"]) {
      const docs = await db.collection(nome).listDocuments();
      for (const d of docs) await db.recursiveDelete(d);
    }
  });

  it("remove o proprio membro e guarda os dados por 30 dias", async () => {
    await criarCasaComMembro();

    await sairDaCasa.run({
      data: { casaId: "casa-1" },
      auth: auth("membro@example.com", "membro-1"),
    } as any);

    const casa = (await db.collection("casas").doc("casa-1").get()).data()!;
    expect(casa.membros["membro-1"].removidoEm).toBeTruthy();
    expect(casa.emailsAtivos).toEqual(["dono@example.com"]);

    const indice = await db.collection("indiceEmail").doc("membro@example.com").get();
    expect(indice.exists).toBe(false);

    const pendente = await db
      .collection("removidosPendentes")
      .doc("casa-1_membro-1")
      .get();
    expect(pendente.exists).toBe(true);
  });

  it("recusa o dono sair por aqui", async () => {
    await criarCasaComMembro();

    await expect(
      sairDaCasa.run({
        data: { casaId: "casa-1" },
        auth: auth("dono@example.com", "dono-uid"),
      } as any),
    ).rejects.toThrow();
  });
});
```

- [ ] **Passo 2: Rodar e confirmar que falha**

```bash
cd functions && npm test -- sairDaCasa
```

Esperado: FALHA — `Cannot find module '../src/sairDaCasa'`.

- [ ] **Passo 3: Criar `functions/src/sairDaCasa.ts`**

```typescript
import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";

export const sairDaCasa = onCall(async (request) => {
  const email = request.auth?.token.email as string | undefined;
  if (!email) throw erroNaoAutenticado();

  const casaId = request.data?.casaId as string | undefined;
  if (!casaId) throw erroInvalido("Informe casaId.");

  const casaRef = db.collection("casas").doc(casaId);

  await db.runTransaction(async (tx) => {
    const casaSnap = await tx.get(casaRef);
    if (!casaSnap.exists) throw erroInvalido("Casa não encontrada.");
    const casa = casaSnap.data()!;

    if (casa.donoEmail === email) {
      throw erroSemPermissao(
        "O dono precisa transferir a posse (ou excluir a casa, se for o " +
          "único membro) antes de sair.",
      );
    }

    const membros = (casa.membros ?? {}) as Record<string, { email: string }>;
    const entrada = Object.entries(membros).find(([, m]) => m.email === email);
    if (!entrada) throw erroInvalido("Você não é membro desta casa.");
    const [membroId] = entrada;

    tx.update(casaRef, {
      [`membros.${membroId}.removidoEm`]: FieldValue.serverTimestamp(),
      emailsAtivos: (casa.emailsAtivos ?? []).filter(
        (e: string) => e !== email,
      ),
    });
    tx.delete(db.collection("indiceEmail").doc(email));
    tx.set(db.collection("removidosPendentes").doc(`${casaId}_${membroId}`), {
      email,
      removidoEm: FieldValue.serverTimestamp(),
      dadosOrigem: { casaId, membroId },
    });
  });

  return { ok: true };
});
```

- [ ] **Passo 4: Rodar e confirmar que passa**

```bash
cd functions && npm test -- sairDaCasa
```

Esperado: os 2 testes passam.

- [ ] **Passo 5: Escrever o teste que falha, `functions/test/excluirCasa.test.ts`**

```typescript
import { db } from "../src/admin";
import { excluirCasa } from "../src/excluirCasa";

function auth(email: string, uid?: string) {
  return { uid: uid ?? "uid-" + email, token: { email } } as any;
}

describe("excluirCasa", () => {
  afterEach(async () => {
    for (const nome of ["casas", "indiceEmail"]) {
      const docs = await db.collection(nome).listDocuments();
      for (const d of docs) await db.recursiveDelete(d);
    }
  });

  it("apaga a casa e o indice quando o dono e o unico membro", async () => {
    await db.collection("casas").doc("casa-1").set({
      nome: "Casa",
      donoEmail: "dono@example.com",
      emailsAtivos: ["dono@example.com"],
      membros: { "dono-uid": { nome: "Dono", email: "dono@example.com", cor: "#000", ordem: 0 } },
    });
    await db.collection("indiceEmail").doc("dono@example.com").set({ casaId: "casa-1" });

    await excluirCasa.run({
      data: { casaId: "casa-1" },
      auth: auth("dono@example.com", "dono-uid"),
    } as any);

    const casa = await db.collection("casas").doc("casa-1").get();
    expect(casa.exists).toBe(false);
    const indice = await db.collection("indiceEmail").doc("dono@example.com").get();
    expect(indice.exists).toBe(false);
  });

  it("recusa excluir com outros membros ativos", async () => {
    await db.collection("casas").doc("casa-2").set({
      nome: "Casa",
      donoEmail: "dono@example.com",
      emailsAtivos: ["dono@example.com", "outro@example.com"],
      membros: {},
    });

    await expect(
      excluirCasa.run({
        data: { casaId: "casa-2" },
        auth: auth("dono@example.com", "dono-uid"),
      } as any),
    ).rejects.toThrow();
  });

  it("recusa quem nao e o dono", async () => {
    await db.collection("casas").doc("casa-3").set({
      nome: "Casa",
      donoEmail: "dono@example.com",
      emailsAtivos: ["dono@example.com"],
      membros: {},
    });

    await expect(
      excluirCasa.run({
        data: { casaId: "casa-3" },
        auth: auth("intruso@example.com"),
      } as any),
    ).rejects.toThrow();
  });
});
```

- [ ] **Passo 6: Rodar e confirmar que falha**

```bash
cd functions && npm test -- excluirCasa
```

Esperado: FALHA — `Cannot find module '../src/excluirCasa'`.

- [ ] **Passo 7: Criar `functions/src/excluirCasa.ts`**

```typescript
import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";

export const excluirCasa = onCall(async (request) => {
  const email = request.auth?.token.email as string | undefined;
  if (!email) throw erroNaoAutenticado();

  const casaId = request.data?.casaId as string | undefined;
  if (!casaId) throw erroInvalido("Informe casaId.");

  const casaRef = db.collection("casas").doc(casaId);
  const casaSnap = await casaRef.get();
  if (!casaSnap.exists) throw erroInvalido("Casa não encontrada.");
  const casa = casaSnap.data()!;

  if (casa.donoEmail !== email) {
    throw erroSemPermissao("Só o dono pode excluir a casa.");
  }
  const ativos = (casa.emailsAtivos ?? []) as string[];
  if (ativos.length > 1) {
    throw erroInvalido(
      "Transfira a posse ou remova os outros membros antes de excluir.",
    );
  }

  await db.recursiveDelete(casaRef);
  await db.collection("indiceEmail").doc(email).delete();

  return { ok: true };
});
```

- [ ] **Passo 8: Adicionar os exports em `functions/src/index.ts`**

```typescript
export { minhaCasa } from "./minhaCasa";
export { criarCasa } from "./criarCasa";
export { convidarMembro } from "./convidarMembro";
export { removerMembro } from "./removerMembro";
export { transferirPosse } from "./transferirPosse";
export { purgarMembrosExpirados } from "./purgarMembrosExpirados";
export { sairDaCasa } from "./sairDaCasa";
export { excluirCasa } from "./excluirCasa";
```

- [ ] **Passo 9: Rodar a suite inteira das functions**

```bash
cd functions && npm test
```

Esperado: todos os testes passam.

- [ ] **Passo 10: Deploy**

```bash
firebase deploy --only functions --project=controlefinaceiro-b5a70
```

- [ ] **Passo 11: Commit**

```bash
git add functions/
git commit -m "feat: Cloud Functions sairDaCasa e excluirCasa"
```

---

## Task 17: UI de "Sair da casa" e "Excluir casa"

**Files:**
- Modify: `lib/dados/repositorio_gestao_casa.dart`
- Modify: `test/dados/repositorio_gestao_casa_test.dart`
- Modify: `lib/ui/shell.dart`
- Modify: `test/ui/shell_test.dart` (se algum teste existente colidir com a
  nova entrada de menu — conferir ao rodar)

**Interfaces:**
- Consumes: `casaProvider`, `membroLogadoProvider` (já existentes).
- Produces: `RepositorioGestaoCasa.sairDaCasa`, `RepositorioGestaoCasa.excluirCasa` — dois métodos novos na interface já usada pela Task 14.

- [ ] **Passo 1: Escrever o teste que falha em `test/dados/repositorio_gestao_casa_test.dart`**

Adicionar dentro do `group('RepositorioGestaoCasaFake', ...)` existente:

```dart
    test('sairDaCasa e excluirCasa registram a chamada', () async {
      final repo = RepositorioGestaoCasaFake();
      await repo.sairDaCasa(casaId: 'c1');
      await repo.excluirCasa(casaId: 'c1');
      expect(repo.chamadas, ['sairDaCasa', 'excluirCasa']);
    });
```

- [ ] **Passo 2: Rodar e confirmar que falha**

```bash
flutter test test/dados/repositorio_gestao_casa_test.dart
```

Esperado: FALHA — `sairDaCasa`/`excluirCasa` não existem na interface.

- [ ] **Passo 3: Adicionar os dois métodos em `lib/dados/repositorio_gestao_casa.dart`**

Na interface `RepositorioGestaoCasa`, depois de `transferirPosse`:

```dart
  Future<void> sairDaCasa({required String casaId});
  Future<void> excluirCasa({required String casaId});
```

Em `RepositorioGestaoCasaFunctions`, depois de `transferirPosse`:

```dart
  @override
  Future<void> sairDaCasa({required String casaId}) =>
      _chamar('sairDaCasa', {'casaId': casaId}, (_) {});

  @override
  Future<void> excluirCasa({required String casaId}) =>
      _chamar('excluirCasa', {'casaId': casaId}, (_) {});
```

Em `RepositorioGestaoCasaFake`, depois de `transferirPosse`:

```dart
  @override
  Future<void> sairDaCasa({required String casaId}) async {
    chamadas.add('sairDaCasa');
    if (erro != null) throw ErroGestaoCasa(erro!);
  }

  @override
  Future<void> excluirCasa({required String casaId}) async {
    chamadas.add('excluirCasa');
    if (erro != null) throw ErroGestaoCasa(erro!);
  }
```

- [ ] **Passo 4: Rodar e confirmar que passa**

```bash
flutter test test/dados/repositorio_gestao_casa_test.dart
```

Esperado: os 5 testes passam.

- [ ] **Passo 5: Adicionar a ação em `lib/ui/shell.dart`**

Substituir o botão único de "Sair" por um `PopupMenuButton` que mostra
"Sair da conta" (logout, o `_confirmarSair` já existente) e, condicionalmente,
"Sair da casa" (não-dono) ou "Excluir casa" (dono e único membro ativo):

```dart
          Builder(builder: (context) {
            final casa = ref.watch(casaProvider).value;
            final membro = ref.watch(membroLogadoProvider);
            final ehDono = casa != null && membro?.email == casa.donoEmail;
            final unicoMembro = casa != null &&
                casa.membros.where((m) => m.removidoEm == null).length == 1;

            return PopupMenuButton<String>(
              key: const Key('menu_conta'),
              icon: const Icon(Icons.more_vert),
              onSelected: (opcao) {
                switch (opcao) {
                  case 'sair_conta':
                    _confirmarSair(context, ref);
                  case 'sair_casa':
                    _confirmarSairDaCasa(context, ref, casa!.id);
                  case 'excluir_casa':
                    _confirmarExcluirCasa(context, ref, casa!.id);
                }
              },
              itemBuilder: (context) => [
                if (!ehDono)
                  const PopupMenuItem(
                    key: Key('opcao_sair_casa'),
                    value: 'sair_casa',
                    child: Text('Sair da casa'),
                  ),
                if (ehDono && unicoMembro)
                  const PopupMenuItem(
                    key: Key('opcao_excluir_casa'),
                    value: 'excluir_casa',
                    child: Text('Excluir casa'),
                  ),
                const PopupMenuItem(
                  key: Key('opcao_sair_conta'),
                  value: 'sair_conta',
                  child: Text('Sair da conta'),
                ),
              ],
            );
          }),
```

Isso substitui o `IconButton` de logout que a Task feature anterior
(botão "Sair") havia colocado direto no `actions` — remover aquele
`IconButton(key: Key('botao_sair'), ...)` do array `actions` e manter só o
`Builder` acima (mais o de "Gerenciar casa" da Task 14, que continua
separado).

Adicionar os dois métodos de confirmação na classe `_ShellState`, ao lado
de `_confirmarSair`:

```dart
  Future<void> _confirmarSairDaCasa(
    BuildContext context,
    WidgetRef ref,
    String casaId,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Sair da casa'),
        content: const Text(
          'Você vai perder acesso aos dados desta casa. Seus lançamentos '
          'ficam guardados por 30 dias, caso você crie uma casa nova com '
          'este mesmo e-mail.',
        ),
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
      await ref.read(repositorioGestaoCasaProvider).sairDaCasa(casaId: casaId);
    }
  }

  Future<void> _confirmarExcluirCasa(
    BuildContext context,
    WidgetRef ref,
    String casaId,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Excluir casa'),
        content: const Text(
          'Isso apaga a casa e todos os dados dela para sempre. Esta ação '
          'não pode ser desfeita.',
        ),
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
      await ref.read(repositorioGestaoCasaProvider).excluirCasa(casaId: casaId);
    }
  }
```

- [ ] **Passo 6: Ajustar `test/ui/shell_test.dart`**

```bash
flutter test test/ui/shell_test.dart
```

Se algum teste existente procurava `find.byKey(const Key('botao_sair'))`
diretamente, trocar para abrir o menu primeiro:
`await tester.tap(find.byKey(const Key('menu_conta'))); await tester.pumpAndSettle();`
antes de procurar `find.byKey(const Key('opcao_sair_conta'))`.

- [ ] **Passo 7: Rodar a suite inteira**

```bash
flutter analyze && flutter test
```

Esperado: sem erros, todos os testes passam.

- [ ] **Passo 8: Commit**

```bash
git add lib/dados/repositorio_gestao_casa.dart lib/ui/shell.dart test/dados/repositorio_gestao_casa_test.dart test/ui/shell_test.dart
git commit -m "feat: UI de sair da casa e excluir casa"
```

---

## Fora de escopo deste plano

Herdado da spec (2026-09-14 §8): suporte a mais de uma casa por pessoa,
confirmação de convite, cobrança, CPF, recuperação de senha do login
antigo, iOS. Também fora daqui: a página de política de privacidade
exigida pela Play Store (spec §7) — é conteúdo estático, não código deste
app, e pode ser feita em paralelo por qualquer um dos dois.
