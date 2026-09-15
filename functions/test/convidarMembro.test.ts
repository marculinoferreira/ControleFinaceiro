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
