import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";
import { normalizarEmail } from "./normalizarEmail";

export const removerMembro = onCall(async (request) => {
  const emailDono = request.auth?.token.email as string | undefined;
  if (!emailDono) throw erroNaoAutenticado();

  const emailDonoNormalizado = normalizarEmail(emailDono);

  const casaId = request.data?.casaId as string | undefined;
  const membroId = request.data?.membroId as string | undefined;
  if (!casaId || !membroId) throw erroInvalido("Informe casaId e membroId.");

  const casaRef = db.collection("casas").doc(casaId);

  const emailRemovido = await db.runTransaction(async (tx) => {
    const casaSnap = await tx.get(casaRef);
    if (!casaSnap.exists) throw erroInvalido("Casa não encontrada.");
    const casa = casaSnap.data()!;
    if (casa.donoEmail !== emailDonoNormalizado) {
      throw erroSemPermissao("Só o dono pode remover membros.");
    }

    const membro = casa.membros?.[membroId];
    if (!membro) throw erroInvalido("Membro não encontrado.");

    // Comparado por e-mail, e nao por uidChamador === membroId: quem virou
    // dono por transferirPosse tendo sido convidado antes tem um membroId
    // aleatorio (de convidarMembro), nao o proprio uid — so o fundador
    // original (criarCasa) tem os dois iguais.
    if (normalizarEmail(membro.email) === emailDonoNormalizado) {
      throw erroInvalido(
        "O dono não pode remover a si mesmo por aqui — use transferir posse.",
      );
    }

    const membroEmailNormalizado = normalizarEmail(membro.email);

    tx.update(casaRef, {
      [`membros.${membroId}.removidoEm`]: FieldValue.serverTimestamp(),
      emailsAtivos: (casa.emailsAtivos ?? []).filter(
        (e: string) => e !== membroEmailNormalizado,
      ),
    });
    tx.delete(db.collection("indiceEmail").doc(membroEmailNormalizado));
    tx.set(db.collection("removidosPendentes").doc(`${casaId}_${membroId}`), {
      email: membroEmailNormalizado,
      removidoEm: FieldValue.serverTimestamp(),
      dadosOrigem: { casaId, membroId },
    });

    return membroEmailNormalizado;
  });

  await db.collection("mail").add({
    to: emailRemovido,
    message: {
      subject: "Você foi removido de uma casa no Controle Financeiro",
      text:
        "Você foi removido de uma casa. Se quiser, entre no app com este " +
        "mesmo e-mail para criar sua própria casa — seus dados ficam " +
        "guardados por 30 dias.",
    },
  });

  return { ok: true };
});
