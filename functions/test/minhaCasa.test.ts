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
