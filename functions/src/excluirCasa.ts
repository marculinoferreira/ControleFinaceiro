import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";
import { normalizarEmail } from "./normalizarEmail";

export const excluirCasa = onCall(async (request) => {
  const email = request.auth?.token.email as string | undefined;
  if (!email) throw erroNaoAutenticado();

  const emailNormalizado = normalizarEmail(email);

  const casaId = request.data?.casaId as string | undefined;
  if (!casaId) throw erroInvalido("Informe casaId.");

  const casaRef = db.collection("casas").doc(casaId);
  const casaSnap = await casaRef.get();
  if (!casaSnap.exists) throw erroInvalido("Casa não encontrada.");
  const casa = casaSnap.data()!;

  if (casa.donoEmail !== emailNormalizado) {
    throw erroSemPermissao("Só o dono pode excluir a casa.");
  }
  const ativos = (casa.emailsAtivos ?? []) as string[];
  if (ativos.length > 1) {
    throw erroInvalido(
      "Transfira a posse ou remova os outros membros antes de excluir.",
    );
  }

  // Pendencias de gente removida DESTA casa que ainda esta dentro da janela
  // de 30 dias: sem apaga-las aqui elas ficariam orfas, apontando para uma
  // casa que nao existe mais.
  const pendentesSnap = await db
    .collection("removidosPendentes")
    .where("dadosOrigem.casaId", "==", casaId)
    .get();
  for (const doc of pendentesSnap.docs) {
    await doc.ref.delete();
  }

  // O indice do dono some ANTES do recursiveDelete de proposito: se a
  // exclusao recursiva falhar pela metade, o indice ja nao aponta mais pra
  // esta casa, entao o proximo criarCasa do dono funciona (autorrecuperacao)
  // em vez de deixa-lo permanentemente preso a uma casa quebrada.
  await db.collection("indiceEmail").doc(emailNormalizado).delete();
  await db.recursiveDelete(casaRef);

  return { ok: true };
});
