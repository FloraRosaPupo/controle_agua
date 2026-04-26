/// <reference path="../types-shim.d.ts" />
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { handleCors, json, requireUser } from "../_shared/auth.ts";

function getUserTimezoneOffsetMinutes(req: Request): number {
  const offsetHeader = req.headers.get("x-timezone-offset");
  if (!offsetHeader) return 0;
  const parsed = Number(offsetHeader);
  return Number.isFinite(parsed) ? parsed : 0;
}

function getStartOfUserDayInUTC(req: Request): Date {
  const offsetMinutes = getUserTimezoneOffsetMinutes(req);
  const now = new Date();
  const userLocalNow = new Date(now.getTime() + offsetMinutes * 60 * 1000);
  userLocalNow.setUTCHours(0, 0, 0, 0);
  return new Date(userLocalNow.getTime() - offsetMinutes * 60 * 1000);
}

function getEndOfUserDayInUTC(req: Request): Date {
  const start = getStartOfUserDayInUTC(req);
  return new Date(start.getTime() + 24 * 60 * 60 * 1000 - 1);
}

function toDbLocalShiftedIso(req: Request, source?: Date): string {
  const base = source ?? new Date();
  const offsetMinutes = getUserTimezoneOffsetMinutes(req);
  // Banco está sem timezone efetivo para o app; aplicamos deslocamento
  // para persistir no relógio local do usuário (ex.: Brasil -03:00).
  const shifted = new Date(base.getTime() + offsetMinutes * 60 * 1000);
  return shifted.toISOString();
}

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

  const url = new URL(req.url);
  const op = url.searchParams.get("op") ?? "today";

  if (req.method === "GET" && op === "today") {
    const start = getStartOfUserDayInUTC(req);
    const end = getEndOfUserDayInUTC(req);

    const { data: logs, error: logsErr } = await admin
      .from("WaterLog")
      .select("id, amount, date")
      .eq("userId", userId)
      .gte("date", start.toISOString())
      .lte("date", end.toISOString())
      .order("date", { ascending: false });

    if (logsErr) {
      console.error(logsErr);
      return json({ error: "Erro ao buscar registros de água" }, 500);
    }

    const { data: user, error: userErr } = await admin
      .from("User")
      .select("dailyGoal, name")
      .eq("id", userId)
      .maybeSingle();

    if (userErr) {
      console.error(userErr);
      return json({ error: "Erro ao buscar usuário" }, 500);
    }
    if (!user) return json({ error: "Usuário não encontrado" }, 404);

    const total = (logs ?? []).reduce((acc, item) => acc + Number(item.amount), 0);
    const dailyGoal = Number(user.dailyGoal ?? 2000);
    const remaining = Math.max(0, dailyGoal - total);

    return json({
      total,
      dailyGoal,
      name: user.name,
      remaining,
      percent: dailyGoal > 0 ? total / dailyGoal : 0,
      logs: logs ?? [],
    });
  }

  if (req.method === "GET" && op === "history") {
    const period = url.searchParams.get("period") ?? "15d";
    const dateParam = url.searchParams.get("date");
    const offsetMinutes = getUserTimezoneOffsetMinutes(req);

    const now = new Date();
    let statsDays = 15;
    let startDate: Date;
    let endDate: Date = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    if (dateParam) {
      const [y, m, d] = dateParam.split("-").map(Number);
      const localStart = new Date(Date.UTC(y, m - 1, d, 0, 0, 0, 0));
      startDate = new Date(localStart.getTime() - offsetMinutes * 60 * 1000);
      endDate = new Date(startDate.getTime() + 24 * 60 * 60 * 1000 - 1);
      statsDays = 1;
    } else {
      if (period.endsWith("d")) {
        const p = Number(period.slice(0, -1));
        if (Number.isFinite(p) && p > 0) statsDays = p;
      }
      const startOfToday = getStartOfUserDayInUTC(req);
      startDate = new Date(
        startOfToday.getTime() - (statsDays - 1) * 24 * 60 * 60 * 1000,
      );
    }

    const { data: logs, error: logsErr } = await admin
      .from("WaterLog")
      .select("id, amount, date")
      .eq("userId", userId)
      .gte("date", startDate.toISOString())
      .lte("date", endDate.toISOString())
      .order("date", { ascending: false });
    if (logsErr) {
      console.error(logsErr);
      return json({ error: "Erro ao buscar histórico" }, 500);
    }

    const { data: user, error: userErr } = await admin
      .from("User")
      .select("dailyGoal")
      .eq("id", userId)
      .maybeSingle();
    if (userErr) {
      console.error(userErr);
      return json({ error: "Erro ao buscar usuário" }, 500);
    }

    const dailyGoal = Number(user?.dailyGoal ?? 2000);
    const logsByDay: Record<string, number> = {};
    for (const log of logs ?? []) {
      const dt = new Date(new Date(String(log.date)).getTime() + offsetMinutes * 60000);
      const day = dt.toISOString().split("T")[0];
      logsByDay[day] = (logsByDay[day] ?? 0) + Number(log.amount);
    }

    const totalIntake = (logs ?? []).reduce(
      (acc, item) => acc + Number(item.amount),
      0,
    );
    const daysWithLogs = Object.keys(logsByDay).length;
    const average = daysWithLogs > 0 ? Math.round(totalIntake / daysWithLogs) : 0;
    const goalsMet = Object.values(logsByDay).filter((v) => v >= dailyGoal).length;

    return json({
      logs: logs ?? [],
      dailyGoal,
      stats: {
        average,
        goalsMet,
        totalDays: statsDays,
      },
    });
  }

  if (req.method === "POST") {
    const body = await req.json().catch(() => ({}));
    const amount = Number(body.amount);
    const dateValue = body.date ? String(body.date) : null;
    const isManual = op === "manual";

    if (!Number.isFinite(amount) || amount <= 0) {
      return json({ error: "Quantidade deve ser maior que zero" }, 400);
    }

    if (isManual && !dateValue) {
      return json({ error: "Data é obrigatória para registro manual" }, 400);
    }

    const payload: Record<string, unknown> = {
      amount: Math.round(amount),
      userId,
      // A coluna WaterLog.date é NOT NULL no banco.
      // Persistimos com deslocamento local (offset do dispositivo).
      date: toDbLocalShiftedIso(req),
    };
    if (dateValue) {
      const parsed = new Date(dateValue);
      if (Number.isNaN(parsed.getTime())) {
        return json({ error: "Data inválida" }, 400);
      }
      payload.date = toDbLocalShiftedIso(req, parsed);
    }

    const { error } = await admin.from("WaterLog").insert(payload);
    if (error) {
      console.error(error);
      return json({ error: "Erro ao salvar registro de água" }, 500);
    }
    return json({ success: true });
  }

  if (req.method === "DELETE") {
    const id = url.searchParams.get("id");
    if (!id) return json({ error: "ID do registro é obrigatório" }, 400);

    const { data: log, error: findErr } = await admin
      .from("WaterLog")
      .select("id, userId")
      .eq("id", id)
      .maybeSingle();
    if (findErr) {
      console.error(findErr);
      return json({ error: "Erro ao buscar registro" }, 500);
    }
    if (!log) return json({ error: "Registro não encontrado" }, 404);
    if (log.userId !== userId) return json({ error: "Não autorizado" }, 403);

    const { error: delErr } = await admin.from("WaterLog").delete().eq("id", id);
    if (delErr) {
      console.error(delErr);
      return json({ error: "Erro ao excluir registro" }, 500);
    }
    return json({ success: true });
  }

  return json({ error: "Método não permitido" }, 405);
});
