/// <reference path="../types-shim.d.ts" />
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.49.4";
import * as jose from "npm:jose@5.9.6";

declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

export type AuthedClient = { userId: string; admin: SupabaseClient };

/** HS256, payload `{ userId }`, exp 7d — compatível com tokens do Express (jsonwebtoken). */
export async function signUserJwt(userId: string, secret: string): Promise<string> {
  const key = new TextEncoder().encode(secret);
  return await new jose.SignJWT({ userId })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("7d")
    .sign(key);
}

/**
 * Valida JWT HS256 com `userId` no payload (Express ou Edge auth-login).
 */
export async function requireUser(req: Request): Promise<AuthedClient | Response> {
  const auth = req.headers.get("x-app-auth") ?? req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    return json({ error: "Token inválido" }, 401);
  }
  const token = auth.slice(7);
  const secret = Deno.env.get("JWT_SECRET");
  if (!secret) {
    console.error("JWT_SECRET ausente nas secrets da função");
    return json({ error: "Servidor não configurado (JWT_SECRET)" }, 500);
  }

  let userId: string;
  try {
    const key = new TextEncoder().encode(secret);
    const { payload } = await jose.jwtVerify(token, key, {
      algorithms: ["HS256"],
    });
    const uid = payload.userId;
    if (typeof uid !== "string" || !uid) {
      return json({ error: "Token inválido" }, 401);
    }
    userId = uid;
  } catch {
    return json({ error: "Token inválido" }, 401);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    console.error("SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY ausente");
    return json({ error: "Configuração do servidor incompleta" }, 500);
  }
  const admin = createClient(url, serviceKey);
  return { userId, admin };
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(),
    },
  });
}

export function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-app-auth, x-client-info, apikey, content-type, x-timezone-offset",
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  };
}

export function handleCors(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }
  return null;
}
