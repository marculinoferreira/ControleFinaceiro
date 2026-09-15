import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";
import { normalizarEmail } from "./normalizarEmail";

export const convidarMembro = onCall(async (request) => {
  const emailDono = request.auth?.token.email as string | undefined;
  if (!emailDono) throw erroNaoAutenticado();

  const emailDonoNormalizado = normalizarEmail(emailDono);

  const casaId = request.data?.casaId as string | undefined;
  const emailConvidado = (request.data?.email as string | undefined)
    ? normalizarEmail(request.data.email as string)
    : undefined;
  const nomeConvidado = (request.data?.nome as string | undefined)?.trim();
  if (!casaId || !emailConvidado || !nomeConvidado) {
    throw erroInvalido("Informe casaId, email e nome.");
  }

  const casaRef = db.collection("casas").doc(casaId);
  const indiceRef = db.collection("indiceEmail").doc(emailConvidado);

  await db.runTransaction(async (tx) => {
    const casaSnap = await tx.get(casaRef);
    if (!casaSnap.exists) throw erroInvalido("Casa não encontrada.");
    const casa = casaSnap.data()!;
    if (casa.donoEmail !== emailDonoNormalizado) {
      throw erroSemPermissao("Só o dono pode convidar membros.");
    }

    const indiceAtual = await tx.get(indiceRef);
    if (indiceAtual.exists) {
      throw erroSemPermissao("Este e-mail já pertence a uma casa.");
    }

    // Gera um id novo sem precisar de uma colecao real: doc() sem
    // argumento sempre sorteia um id de 20 caracteres.
    const membroId = db.collection("_ids").doc().id;
    const membrosAtuais = casa.membros ?? {};

    tx.update(casaRef, {
      [`membros.${membroId}`]: {
        nome: nomeConvidado,
        email: emailConvidado,
        cor: "#1565C0",
        ordem: Object.keys(membrosAtuais).length,
      },
      emailsAtivos: [...(casa.emailsAtivos ?? []), emailConvidado],
    });
    tx.set(indiceRef, { casaId });
  });

  return { ok: true };
});
