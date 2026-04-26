/**
 * Cadastro: bcrypt + insert "User" / "NotificationSetting" + JWT (jose).
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
  const name = body.name ? String(body.name).trim() : "";
  const email = body.email ? String(body.email).trim() : "";
  const password = body.password ? String(body.password) : "";
  const dailyGoalRaw = body.dailyGoal;
  const dailyGoal =
    typeof dailyGoalRaw === "number" && dailyGoalRaw > 0
      ? Math.round(dailyGoalRaw)
      : 2000;

  if (!name || !email || !password) {
    return json({ error: "Nome, e-mail e senha são obrigatórios" }, 400);
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
  const id = crypto.randomUUID();
  const hash = bcrypt.hashSync(password, 10);

  const { error: insUser } = await admin.from("User").insert({
    id,
    name,
    email,
    password: hash,
    dailyGoal,
    quickAddAmount: 200,
    theme: "system",
    dailyReminder: true,
    vibration: true,
  });

  if (insUser) {
    const msg = insUser.message?.includes("duplicate") ||
        insUser.code === "23505"
      ? "E-mail já cadastrado"
      : "Erro ao criar usuário.";
    return json({ error: msg }, 400);
  }

  const { error: insNs } = await admin.from("NotificationSetting").insert({
    id: crypto.randomUUID(),
    userId: id,
    type: "hourly",
    intervalInMinutes: 60,
    daysOfWeek: [0, 1, 2, 3, 4, 5, 6],
    startTime: "08:00",
    endTime: "22:00",
    enabled: true,
  });

  if (insNs) {
    console.error(insNs);
    await admin.from("User").delete().eq("id", id);
    return json({ error: "Erro ao criar preferências de notificação" }, 500);
  }

  const token = await signUserJwt(id, secret);

  return json({
    token,
    user: { id, name, email },
  });
});
