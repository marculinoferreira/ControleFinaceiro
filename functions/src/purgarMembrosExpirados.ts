import { onSchedule } from "firebase-functions/v2/scheduler";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "./admin";

const TRINTA_DIAS_MS = 30 * 24 * 60 * 60 * 1000;

export const purgarMembrosExpirados = onSchedule(
  "every 24 hours",
  async () => {
    const limite = Timestamp.fromMillis(Date.now() - TRINTA_DIAS_MS);
    const expirados = await db
      .collection("removidosPendentes")
      .where("removidoEm", "<=", limite)
      .get();

    for (const doc of expirados.docs) {
      const { dadosOrigem } = doc.data() as {
        dadosOrigem: { casaId: string; membroId: string };
      };
      await apagarColecao("gastos", dadosOrigem);
      await apagarColecao("ganhos", dadosOrigem);
      await doc.ref.delete();
    }
  },
);

async function apagarColecao(
  colecao: "gastos" | "ganhos",
  origem: { casaId: string; membroId: string },
) {
  const col = db.collection("casas").doc(origem.casaId).collection(colecao);
  const docs = await col.where("membroId", "==", origem.membroId).get();
  if (docs.empty) return;

  const lote = db.batch();
  for (const doc of docs.docs) lote.delete(doc.ref);
  await lote.commit();
}
