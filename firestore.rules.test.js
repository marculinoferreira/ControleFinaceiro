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
