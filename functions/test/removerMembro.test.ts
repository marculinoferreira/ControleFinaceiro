import { db } from "../src/admin";
import { removerMembro } from "../src/removerMembro";
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

  it("recusa o novo dono (que ja era membro convidado) tentar remover a si mesmo", async () => {
    // membro-1 foi convidado por convidarMembro, entao o id dele e aleatorio
    // e diferente do proprio uid — a guarda precisa comparar por e-mail, nao
    // por membroId === uidChamador, senao esta remocao passaria.
    await criarCasaComMembro();

    await transferirPosse.run({
      data: { casaId: "casa-1", membroId: "membro-1" },
      auth: auth("dono@example.com", "dono-uid"),
    } as any);

    await expect(
      removerMembro.run({
        data: { casaId: "casa-1", membroId: "membro-1" },
        auth: auth("membro@example.com", "algum-outro-uid"),
      } as any),
    ).rejects.toThrow();
  });
});
