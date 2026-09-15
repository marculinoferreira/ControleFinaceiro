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

  await db.recursiveDelete(casaRef);
  await db.collection("indiceEmail").doc(emailNormalizado).delete();

  return { ok: true };
});
