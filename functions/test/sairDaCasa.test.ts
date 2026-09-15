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
