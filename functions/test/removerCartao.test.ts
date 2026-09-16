import { db } from "../src/admin";
import { removerCartao } from "../src/removerCartao";

function auth(email: string, uid?: string) {
  return { uid: uid ?? "uid-" + email, token: { email } } as any;
}

async function criarCasaComDoisMembros() {
  await db
    .collection("casas")
    .doc("casa-1")
    .set({
      nome: "Casa",
      donoEmail: "marcos@example.com",
      emailsAtivos: ["marcos@example.com", "silvia@example.com"],
      membros: {
        "membro-marcos": {
          nome: "Marcos",
          email: "marcos@example.com",
          cor: "#000",
          ordem: 0,
        },
        "membro-silvia": {
          nome: "Silvia",
          email: "silvia@example.com",
          cor: "#111",
          ordem: 1,
        },
      },
    });
}

async function criarCartao() {
  await db
    .collection("casas")
    .doc("casa-1")
    .collection("cartoes")
    .doc("cartao-1")
    .set({ nome: "Inter", ordem: 0 });
}

describe("removerCartao", () => {
  afterEach(async () => {
    for (const nome of ["casas"]) {
      const docs = await db.collection(nome).listDocuments();
      for (const d of docs) await db.recursiveDelete(d);
    }
  });

  it("remove o cartao quando ninguem tem vencimento cadastrado", async () => {
    await criarCasaComDoisMembros();
    await criarCartao();

    await removerCartao.run({
      data: { casaId: "casa-1", cartaoId: "cartao-1" },
      auth: auth("marcos@example.com"),
    } as any);

    const cartao = await db
      .collection("casas")
      .doc("casa-1")
      .collection("cartoes")
      .doc("cartao-1")
      .get();
    expect(cartao.exists).toBe(false);
  });

  it("remove o cartao e o proprio vencimento junto, quando so eu tenho um", async () => {
    await criarCasaComDoisMembros();
    await criarCartao();
    await db
      .collection("casas")
      .doc("casa-1")
      .collection("cartoes")
      .doc("cartao-1")
      .collection("vencimentos")
      .doc("membro-marcos")
      .set({ dia: 5 });

    await removerCartao.run({
      data: { casaId: "casa-1", cartaoId: "cartao-1" },
      auth: auth("marcos@example.com"),
    } as any);

    const cartao = await db
      .collection("casas")
      .doc("casa-1")
      .collection("cartoes")
      .doc("cartao-1")
      .get();
    expect(cartao.exists).toBe(false);
  });

  it("recusa remover quando outro integrante tem um vencimento cadastrado", async () => {
    await criarCasaComDoisMembros();
    await criarCartao();
    await db
      .collection("casas")
      .doc("casa-1")
      .collection("cartoes")
      .doc("cartao-1")
      .collection("vencimentos")
      .doc("membro-silvia")
      .set({ dia: 15 });

    await expect(
      removerCartao.run({
        data: { casaId: "casa-1", cartaoId: "cartao-1" },
        auth: auth("marcos@example.com"),
      } as any),
    ).rejects.toThrow();

    const cartao = await db
      .collection("casas")
      .doc("casa-1")
      .collection("cartoes")
      .doc("cartao-1")
      .get();
    expect(cartao.exists).toBe(true);
  });

  it("recusa quem nao e membro da casa", async () => {
    await criarCasaComDoisMembros();
    await criarCartao();

    await expect(
      removerCartao.run({
        data: { casaId: "casa-1", cartaoId: "cartao-1" },
        auth: auth("estranho@example.com"),
      } as any),
    ).rejects.toThrow();
  });
});
