import { onCall } from "firebase-functions/v2/https";
import { db } from "./admin";
import { erroNaoAutenticado, erroInvalido, erroSemPermissao } from "./erros";
import { normalizarEmail } from "./normalizarEmail";

/// Remove um cartao da casa, mas so quando nenhum outro integrante tem um
/// dia de fechamento cadastrado nele. O cliente nunca consegue checar isso
/// sozinho -- a regra de seguranca que garante o sigilo do fechamento de
/// cada pessoa (ver firestore.rules) e a mesma que impede o Marcos de ler
/// se a Silvia tem um fechamento aqui. So o servidor, com o Admin SDK, ve
/// os dois lados pra decidir.
export const removerCartao = onCall(async (request) => {
  const email = request.auth?.token.email as string | undefined;
  if (!email) throw erroNaoAutenticado();

  const emailNormalizado = normalizarEmail(email);

  const casaId = request.data?.casaId as string | undefined;
  const cartaoId = request.data?.cartaoId as string | undefined;
  if (!casaId || !cartaoId) throw erroInvalido("Informe casaId e cartaoId.");

  const casaRef = db.collection("casas").doc(casaId);
  const casaSnap = await casaRef.get();
  if (!casaSnap.exists) throw erroInvalido("Casa não encontrada.");
  const casa = casaSnap.data()!;

  const membros = (casa.membros ?? {}) as Record<string, { email: string }>;
  const entrada = Object.entries(membros).find(
    ([, m]) => normalizarEmail(m.email) === emailNormalizado,
  );
  if (!entrada) throw erroSemPermissao("Você não é membro desta casa.");
  const [meuMembroId] = entrada;

  const cartaoRef = casaRef.collection("cartoes").doc(cartaoId);
  const fechamentosSnap = await cartaoRef.collection("fechamentos").get();

  const deOutroMembro = fechamentosSnap.docs.filter(
    (doc) => doc.id !== meuMembroId,
  );
  if (deOutroMembro.length > 0) {
    throw erroSemPermissao(
      "Não é possível remover: outro integrante da casa ainda tem um dia " +
        "de fechamento cadastrado para este cartão.",
    );
  }

  const lote = db.batch();
  for (const doc of fechamentosSnap.docs) {
    lote.delete(doc.ref);
  }
  lote.delete(cartaoRef);
  await lote.commit();

  return { ok: true };
});
