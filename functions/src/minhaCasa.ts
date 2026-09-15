import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado } from "./erros";
import { normalizarEmail } from "./normalizarEmail";

export const minhaCasa = onCall(async (request) => {
  const email = request.auth?.token.email as string | undefined;
  if (!email) throw erroNaoAutenticado();

  const emailNormalizado = normalizarEmail(email);
  const indiceRef = db.collection("indiceEmail").doc(emailNormalizado);
  const indice = await indiceRef.get();
  if (!indice.exists) return { casaId: null };

  const casaId = indice.data()!.casaId as string;
  const casaSnap = await db.collection("casas").doc(casaId).get();
  if (!casaSnap.exists) {
    // Indice orfao: sobrou de uma falha parcial anterior (ex.: excluirCasa
    // interrompido no meio). Autocorrige removendo o indice em vez de
    // devolver um casaId pendurado que o app nunca vai conseguir abrir.
    await indiceRef.delete();
    return { casaId: null };
  }

  return { casaId };
});
