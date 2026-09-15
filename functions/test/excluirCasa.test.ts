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
