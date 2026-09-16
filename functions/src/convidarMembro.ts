import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
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

    const membrosAtuais = casa.membros ?? {};

    const membrosAtivos = Object.values(membrosAtuais).filter(
      (m: any) => !m.removidoEm,
    );
    if (membrosAtivos.length >= 2) {
      throw erroInvalido("Uma casa pode ter no máximo 2 pessoas.");
    }

    // Se este e-mail ja tem uma entrada removida nesta casa, reativa em vez
    // de sortear um membroId novo: sem isto, convidar de volta alguem que
    // ja saiu criaria um segundo registro fantasma, e o pendente de 30 dias
    // do registro antigo continuaria de pe pra ser apagado pela purga
    // mesmo a pessoa ja estando ativa de novo.
    const idRemovidoExistente = Object.entries(membrosAtuais).find(
      ([, m]: [string, any]) =>
        normalizarEmail(m.email) === emailConvidado && m.removidoEm,
    )?.[0];

    // Toda leitura da transacao vem antes de qualquer escrita — inclusive a
    // do pendente, que so existe no caminho de reativacao.
    const pendenteRef = idRemovidoExistente
      ? db.collection("removidosPendentes").doc(`${casaId}_${idRemovidoExistente}`)
      : undefined;
    const pendenteSnap = pendenteRef ? await tx.get(pendenteRef) : undefined;

    const membroId = idRemovidoExistente ?? db.collection("_ids").doc().id;

    if (idRemovidoExistente) {
      tx.update(casaRef, {
        [`membros.${membroId}.nome`]: nomeConvidado,
        [`membros.${membroId}.removidoEm`]: FieldValue.delete(),
        emailsAtivos: [...(casa.emailsAtivos ?? []), emailConvidado],
      });
    } else {
      tx.update(casaRef, {
        [`membros.${membroId}`]: {
          nome: nomeConvidado,
          email: emailConvidado,
          cor: "#1565C0",
          ordem: Object.keys(membrosAtuais).length,
        },
        emailsAtivos: [...(casa.emailsAtivos ?? []), emailConvidado],
      });
    }

    if (pendenteSnap?.exists) {
      tx.delete(pendenteRef!);
    }

    tx.set(indiceRef, { casaId });
  });

  return { ok: true };
});
