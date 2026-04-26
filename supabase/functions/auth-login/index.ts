/**
 * Login sem Supabase Auth: bcrypt em public."User" + JWT HS256 (jose).
 * Body: { "email", "password" }
 */
/// <reference path="../types-shim.d.ts" />
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import bcrypt from "npm:bcryptjs@2.4.3";

import { handleCors, json, signUserJwt } from "../_shared/auth.ts";

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return json({ error: "Método não permitido" }, 405);
  }

  const body = await req.json().catch(() => ({}));
  const email = body.email ? String(body.email).trim() : "";
  const password = body.password ? String(body.password) : "";
  if (!email || !password) {
    return json({ error: "E-mail e senha são obrigatórios" }, 400);
  }

  const secret = Deno.env.get("JWT_SECRET");
  if (!secret) {
    return json({ error: "JWT_SECRET não configurado" }, 500);
  }
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    return json({ error: "Configuração incompleta" }, 500);
  }

  const admin = createClient(url, serviceKey);
  const { data: user, error } = await admin
    .from("User")
    .select("id, name, email, password")
    .eq("email", email)
    .maybeSingle();

  if (error) {
    console.error(error);
    return json({ error: "Erro ao buscar usuário" }, 500);
  }
  if (!user?.password) {
    return json({ error: "Usuário não encontrado" }, 400);
  }

  if (!bcrypt.compareSync(password, user.password as string)) {
    return json({ error: "Senha inválida" }, 400);
  }

  const token = await signUserJwt(user.id as string, secret);

  return json({
    token,
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
    },
  });
});
