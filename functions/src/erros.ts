import { HttpsError } from "firebase-functions/v2/https";

export function erroNaoAutenticado(): HttpsError {
  return new HttpsError("unauthenticated", "É preciso estar logado.");
}

export function erroSemPermissao(mensagem: string): HttpsError {
  return new HttpsError("permission-denied", mensagem);
}

export function erroInvalido(mensagem: string): HttpsError {
  return new HttpsError("invalid-argument", mensagem);
}
