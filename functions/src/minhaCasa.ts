import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado } from "./erros";

export const minhaCasa = onCall(async (request) => {
  const email = request.auth?.token.email as string | undefined;
  if (!email) throw erroNaoAutenticado();

  const indice = await db.collection("indiceEmail").doc(email).get();
  if (!indice.exists) return { casaId: null };
  return { casaId: indice.data()!.casaId as string };
});
