import { onCall } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";
import { normalizarEmail } from "./normalizarEmail";

export const sairDaCasa = onCall(async (request) => {
  const email = request.auth?.token.email as string | undefined;
  if (!email) throw erroNaoAutenticado();

  const emailNormalizado = normalizarEmail(email);

  const casaId = request.data?.casaId as string | undefined;
  if (!casaId) throw erroInvalido("Informe casaId.");

  const casaRef = db.collection("casas").doc(casaId);

  await db.runTransaction(async (tx) => {
    const casaSnap = await tx.get(casaRef);
    if (!casaSnap.exists) throw erroInvalido("Casa não encontrada.");
    const casa = casaSnap.data()!;

    if (casa.donoEmail === emailNormalizado) {
      throw erroSemPermissao(
        "O dono precisa transferir a posse (ou excluir a casa, se for o " +
          "único membro) antes de sair.",
      );
    }

    const membros = (casa.membros ?? {}) as Record<string, { email: string }>;
    const entrada = Object.entries(membros).find(([, m]) => normalizarEmail(m.email) === emailNormalizado);
    if (!entrada) throw erroInvalido("Você não é membro desta casa.");
    const [membroId] = entrada;

    tx.update(casaRef, {
      [`membros.${membroId}.removidoEm`]: FieldValue.serverTimestamp(),
      emailsAtivos: (casa.emailsAtivos ?? []).filter(
        (e: string) => normalizarEmail(e) !== emailNormalizado,
      ),
    });
    tx.delete(db.collection("indiceEmail").doc(emailNormalizado));
    tx.set(db.collection("removidosPendentes").doc(`${casaId}_${membroId}`), {
      email: emailNormalizado,
      removidoEm: FieldValue.serverTimestamp(),
      dadosOrigem: { casaId, membroId },
    });
  });

  return { ok: true };
});
