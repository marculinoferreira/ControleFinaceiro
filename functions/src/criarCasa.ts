import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";
import { potesPadrao } from "./potesPadrao";

export const criarCasa = onCall(async (request) => {
  const email = request.auth?.token.email as string | undefined;
  const uid = request.auth?.uid;
  if (!email || !uid) throw erroNaoAutenticado();

  const nome = (request.data?.nome as string | undefined)?.trim();
  if (!nome) throw erroInvalido("Informe o nome da casa.");

  const indiceRef = db.collection("indiceEmail").doc(email);
  const casaRef = db.collection("casas").doc();

  const casaId = await db.runTransaction(async (tx) => {
    const indiceAtual = await tx.get(indiceRef);
    if (indiceAtual.exists) {
      throw erroSemPermissao("Este e-mail já pertence a uma casa.");
    }

    tx.set(casaRef, {
      nome,
      donoEmail: email,
      emailsAtivos: [email],
      membros: {
        [uid]: {
          nome: (request.auth?.token.name as string | undefined) ?? nome,
          email,
          cor: "#2E7D32",
          ordem: 0,
        },
      },
    });
    tx.set(indiceRef, { casaId: casaRef.id });

    return casaRef.id;
  });

  const lotePotes = db.batch();
  for (const pote of potesPadrao()) {
    lotePotes.set(casaRef.collection("potes").doc(), pote);
  }
  await lotePotes.commit();

  await migrarDadosPendentes(email, casaId);

  return { casaId };
});

async function migrarDadosPendentes(email: string, casaIdNovo: string) {
  const pendentes = await db
    .collection("removidosPendentes")
    .where("email", "==", email)
    .get();

  for (const doc of pendentes.docs) {
    const { dadosOrigem } = doc.data() as {
      dadosOrigem: { casaId: string; membroId: string };
    };
    await migrarColecao("gastos", dadosOrigem, casaIdNovo);
    await migrarColecao("ganhos", dadosOrigem, casaIdNovo);
    await doc.ref.delete();
  }
}

async function migrarColecao(
  colecao: "gastos" | "ganhos",
  origem: { casaId: string; membroId: string },
  casaIdNovo: string,
) {
  const origemCol = db
    .collection("casas")
    .doc(origem.casaId)
    .collection(colecao);
  const destinoCol = db.collection("casas").doc(casaIdNovo).collection(colecao);

  const docs = await origemCol.where("membroId", "==", origem.membroId).get();
  if (docs.empty) return;

  const lote = db.batch();
  for (const doc of docs.docs) {
    lote.set(destinoCol.doc(doc.id), doc.data());
    lote.delete(doc.ref);
  }
  await lote.commit();
}
