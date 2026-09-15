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
    expect(gastosNovos.docs[0].data().membroId).toBe("uid-carla@example.com");

    const gastosAntigos = await casaAntigaRef.collection("gastos").get();
    expect(gastosAntigos.size).toBe(0);

    const pendenteRestante = await db
      .collection("removidosPendentes")
      .doc("casa-antiga_membro-antigo")
      .get();
    expect(pendenteRestante.exists).toBe(false);
  });
});
