import { db } from "../src/admin";
import { minhaCasa } from "../src/minhaCasa";

function auth(email: string) {
  return { uid: "uid-" + email, token: { email } } as any;
}

describe("minhaCasa", () => {
  afterEach(async () => {
    for (const nome of ["indiceEmail", "casas"]) {
      const docs = await db.collection(nome).listDocuments();
      for (const d of docs) await db.recursiveDelete(d);
    }
  });

  it("devolve null quando o e-mail nao tem casa", async () => {
    const resposta = await minhaCasa.run({
      data: {},
      auth: auth("nova@example.com"),
    } as any);
    expect(resposta.casaId).toBeNull();
  });

  it("devolve o casaId quando o indice existe e a casa existe", async () => {
    await db.collection("casas").doc("casa-1").set({
      nome: "Casa",
      donoEmail: "existente@example.com",
      emailsAtivos: ["existente@example.com"],
      membros: {},
    });
    await db.collection("indiceEmail").doc("existente@example.com").set({
      casaId: "casa-1",
    });

    const resposta = await minhaCasa.run({
      data: {},
      auth: auth("existente@example.com"),
    } as any);
    expect(resposta.casaId).toBe("casa-1");
  });

  it("autocorrige um indice orfao (apontando pra casa que nao existe mais)", async () => {
    await db.collection("indiceEmail").doc("orfao@example.com").set({
      casaId: "casa-inexistente",
    });

    const resposta = await minhaCasa.run({
      data: {},
      auth: auth("orfao@example.com"),
    } as any);
    expect(resposta.casaId).toBeNull();

    const indice = await db.collection("indiceEmail").doc("orfao@example.com").get();
    expect(indice.exists).toBe(false);
  });

  it("recusa chamada sem autenticacao", async () => {
    await expect(
      minhaCasa.run({ data: {}, auth: undefined } as any),
    ).rejects.toThrow();
  });
});
