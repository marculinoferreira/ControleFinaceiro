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

    // Todas as leituras da migracao ANTES de qualquer escrita —
    // transacoes do Firestore exigem que leituras venham antes de escritas.
    const pendentesSnap = await tx.get(
      db.collection("removidosPendentes").where("email", "==", email),
    );
    const migracoes: {
      pendenteRef: FirebaseFirestore.DocumentReference;
      gastos: FirebaseFirestore.QueryDocumentSnapshot[];
      ganhos: FirebaseFirestore.QueryDocumentSnapshot[];
    }[] = [];

    for (const doc of pendentesSnap.docs) {
      const { dadosOrigem } = doc.data() as {
        dadosOrigem: { casaId: string; membroId: string };
      };
      const origemCasa = db.collection("casas").doc(dadosOrigem.casaId);
      const gastosSnap = await tx.get(
        origemCasa.collection("gastos").where("membroId", "==", dadosOrigem.membroId),
      );
      const ganhosSnap = await tx.get(
        origemCasa.collection("ganhos").where("membroId", "==", dadosOrigem.membroId),
      );
      migracoes.push({
        pendenteRef: doc.ref,
        gastos: gastosSnap.docs,
        ganhos: ganhosSnap.docs,
      });
    }

    // A partir daqui, so escritas.
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

    for (const pote of potesPadrao()) {
      tx.set(casaRef.collection("potes").doc(), pote);
    }

    for (const migracao of migracoes) {
      for (const doc of migracao.gastos) {
        tx.set(casaRef.collection("gastos").doc(doc.id), { ...doc.data(), membroId: uid });
        tx.delete(doc.ref);
      }
      for (const doc of migracao.ganhos) {
        tx.set(casaRef.collection("ganhos").doc(doc.id), { ...doc.data(), membroId: uid });
        tx.delete(doc.ref);
      }
      tx.delete(migracao.pendenteRef);
    }

    return casaRef.id;
  });

  return { casaId };
});
