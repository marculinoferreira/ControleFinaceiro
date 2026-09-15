import { Timestamp } from "firebase-admin/firestore";
import { db } from "../src/admin";
import { purgarMembrosExpirados } from "../src/purgarMembrosExpirados";

async function criarPendente(id: string, diasAtras: number) {
  const removidoEm = Timestamp.fromMillis(
    Date.now() - diasAtras * 24 * 60 * 60 * 1000,
  );
  await db.collection("removidosPendentes").doc(id).set({
    email: `${id}@example.com`,
    removidoEm,
    dadosOrigem: { casaId: "casa-x", membroId: id },
  });
  await db
    .collection("casas")
    .doc("casa-x")
    .collection("gastos")
    .doc(`g-${id}`)
    .set({ membroId: id, descricao: "teste", valor: 10, mesRef: "2026-09" });
}

describe("purgarMembrosExpirados", () => {
  afterEach(async () => {
    for (const nome of ["casas", "removidosPendentes"]) {
      const docs = await db.collection(nome).listDocuments();
      for (const d of docs) await db.recursiveDelete(d);
    }
  });

  it("apaga so quem passou de 30 dias", async () => {
    await criarPendente("velho", 31);
    await criarPendente("recente", 5);

    await purgarMembrosExpirados.run(undefined as any);

    const pendentes = await db.collection("removidosPendentes").listDocuments();
    expect(pendentes.map((d) => d.id)).toEqual(["recente"]);

    const gastosVelho = await db
      .collection("casas")
      .doc("casa-x")
      .collection("gastos")
      .doc("g-velho")
      .get();
    expect(gastosVelho.exists).toBe(false);

    const gastosRecente = await db
      .collection("casas")
      .doc("casa-x")
      .collection("gastos")
      .doc("g-recente")
      .get();
    expect(gastosRecente.exists).toBe(true);
  });
});
