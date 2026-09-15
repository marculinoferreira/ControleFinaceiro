import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado } from "./erros";
import { normalizarEmail } from "./normalizarEmail";

export const minhaCasa = onCall(async (request) => {
  const email = request.auth?.token.email as string | undefined;
  if (!email) throw erroNaoAutenticado();

  const emailNormalizado = normalizarEmail(email);
  const indice = await db.collection("indiceEmail").doc(emailNormalizado).get();
  if (!indice.exists) return { casaId: null };
  return { casaId: indice.data()!.casaId as string };
});
