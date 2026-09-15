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
