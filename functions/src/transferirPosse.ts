import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";
import { normalizarEmail } from "./normalizarEmail";

export const transferirPosse = onCall(async (request) => {
  const emailDono = request.auth?.token.email as string | undefined;
  if (!emailDono) throw erroNaoAutenticado();

  const emailDonoNormalizado = normalizarEmail(emailDono);

  const casaId = request.data?.casaId as string | undefined;
  const novoDonoMembroId = request.data?.membroId as string | undefined;
  if (!casaId || !novoDonoMembroId) {
    throw erroInvalido("Informe casaId e membroId.");
  }

  const casaRef = db.collection("casas").doc(casaId);

  await db.runTransaction(async (tx) => {
    const casaSnap = await tx.get(casaRef);
    if (!casaSnap.exists) throw erroInvalido("Casa não encontrada.");
    const casa = casaSnap.data()!;
    if (casa.donoEmail !== emailDonoNormalizado) {
      throw erroSemPermissao("Só o dono atual pode transferir a posse.");
    }

    const novoDono = casa.membros?.[novoDonoMembroId];
    if (!novoDono || novoDono.removidoEm) {
      throw erroInvalido("Novo dono precisa ser um membro ativo da casa.");
    }

    const novoDonoEmailNormalizado = normalizarEmail(novoDono.email);
    tx.update(casaRef, { donoEmail: novoDonoEmailNormalizado });
  });

  return { ok: true };
});
