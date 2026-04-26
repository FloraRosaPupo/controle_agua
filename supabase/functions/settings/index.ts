/// <reference path="../types-shim.d.ts" />
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import bcrypt from "npm:bcryptjs@2.4.3";
import { handleCors, json, requireUser } from "../_shared/auth.ts";

type NotificationPayload = {
  type?: string;
  intervalInMinutes?: number;
  daysOfWeek?: number[];
  startTime?: string;
  endTime?: string;
  enabled?: boolean;
};

const DEFAULT_NOTIFICATION = {
  type: "hourly",
  intervalInMinutes: 60,
  daysOfWeek: [0, 1, 2, 3, 4, 5, 6],
  startTime: "08:00",
  endTime: "22:00",
  enabled: true,
};

function getAdminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return null;
  return createClient(url, serviceKey);
}

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  const auth = await requireUser(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const admin = getAdminClient();
  if (!admin) return json({ error: "Configuração incompleta" }, 500);

  if (req.method === "GET") {
    const { data: user, error: userErr } = await admin
      .from("User")
      .select(
        "name, email, dailyGoal, quickAddAmount, theme, dailyReminder, vibration",
      )
      .eq("id", userId)
      .maybeSingle();

    if (userErr) {
      console.error(userErr);
      return json({ error: "Erro ao buscar configurações" }, 500);
    }
    if (!user) return json({ error: "Usuário não encontrado" }, 404);

    const { data: notif, error: notifErr } = await admin
      .from("NotificationSetting")
      .select("type, intervalInMinutes, daysOfWeek, startTime, endTime, enabled")
      .eq("userId", userId)
      .maybeSingle();

    if (notifErr) {
      console.error(notifErr);
      return json({ error: "Erro ao buscar notificações" }, 500);
    }

    return json({
      ...user,
      notificationSettings: notif ?? DEFAULT_NOTIFICATION,
    });
  }

  if (req.method === "PUT") {
    const op = new URL(req.url).searchParams.get("op");
    const body = await req.json().catch(() => ({}));

    if (op === "password") {
      const currentPassword = body.currentPassword
        ? String(body.currentPassword).trim()
        : "";
      const newPassword = body.newPassword
        ? String(body.newPassword).trim()
        : "";

      if (!currentPassword || !newPassword) {
        return json(
          { error: "Senha atual e nova senha são obrigatórias" },
          400,
        );
      }
      if (newPassword.length < 6) {
        return json({ error: "A nova senha deve ter pelo menos 6 caracteres" }, 400);
      }

      const { data: user, error: userErr } = await admin
        .from("User")
        .select("id, password")
        .eq("id", userId)
        .maybeSingle();
      if (userErr) {
        console.error(userErr);
        return json({ error: "Erro ao validar usuário" }, 500);
      }
      if (!user) return json({ error: "Usuário não encontrado" }, 404);

      const valid = bcrypt.compareSync(currentPassword, user.password as string);
      if (!valid) return json({ error: "Senha atual incorreta" }, 400);

      const hash = bcrypt.hashSync(newPassword, 10);
      const { error: updErr } = await admin
        .from("User")
        .update({ password: hash })
        .eq("id", userId);
      if (updErr) {
        console.error(updErr);
        return json({ error: "Erro ao atualizar senha" }, 500);
      }

      return json({ message: "Senha alterada com sucesso" });
    }

    const {
      name,
      dailyGoal,
      quickAddAmount,
      theme,
      dailyReminder,
      vibration,
      notificationSettings,
      notifications,
    } = body;

    const updateData: Record<string, unknown> = {};
    if (name !== undefined) updateData.name = String(name);
    if (dailyGoal !== undefined) updateData.dailyGoal = Number(dailyGoal);
    if (quickAddAmount !== undefined) {
      updateData.quickAddAmount = Number(quickAddAmount);
    }
    if (theme !== undefined) updateData.theme = String(theme);
    if (dailyReminder !== undefined) updateData.dailyReminder = Boolean(dailyReminder);
    if (vibration !== undefined) updateData.vibration = Boolean(vibration);

    if (Object.keys(updateData).length > 0) {
      const { error: updUserErr } = await admin
        .from("User")
        .update(updateData)
        .eq("id", userId);
      if (updUserErr) {
        console.error(updUserErr);
        return json({ error: "Erro ao atualizar configurações" }, 500);
      }
    }

    const appNotif = (notificationSettings ?? notifications) as
      | NotificationPayload
      | undefined;
    if (appNotif) {
      const upsertPayload = {
        id: crypto.randomUUID(),
        userId,
        type: appNotif.type ?? DEFAULT_NOTIFICATION.type,
        intervalInMinutes:
          appNotif.intervalInMinutes ?? DEFAULT_NOTIFICATION.intervalInMinutes,
        daysOfWeek: appNotif.daysOfWeek ?? DEFAULT_NOTIFICATION.daysOfWeek,
        startTime: appNotif.startTime ?? DEFAULT_NOTIFICATION.startTime,
        endTime: appNotif.endTime ?? DEFAULT_NOTIFICATION.endTime,
        enabled: appNotif.enabled ?? DEFAULT_NOTIFICATION.enabled,
      };

      const { error: notifErr } = await admin
        .from("NotificationSetting")
        .upsert(upsertPayload, { onConflict: "userId" });
      if (notifErr) {
        console.error(notifErr);
        return json({ error: "Erro ao atualizar notificações" }, 500);
      }
    }

    return json({ message: "Configurações atualizadas!" });
  }

  return json({ error: "Método não permitido" }, 405);
});
