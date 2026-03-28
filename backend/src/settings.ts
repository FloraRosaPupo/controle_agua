import { Request, Response } from "express";
import bcrypt from "bcrypt";
import { prisma } from "./prisma";
import { AuthRequest } from "./types";

export async function getSettings(req: Request, res: Response) {
    try {
        const userId = (req as AuthRequest).userId;
        if (!userId) {
            return res.status(401).json({ error: "Usuário não autenticado" });
        }

        const user = await prisma.user.findUnique({
            where: { id: userId },
            select: {
                name: true,
                email: true,
                dailyGoal: true,
                quickAddAmount: true,
                theme: true,
                dailyReminder: true,
                vibration: true,
                notificationSettings: true,
            }
        });

        if (!user) {
            return res.status(404).json({ error: "Usuário não encontrado" });
        }

        res.json({
            ...user,
            notificationSettings: user.notificationSettings || {
                type: "hourly",
                intervalInMinutes: 60,
                daysOfWeek: [0, 1, 2, 3, 4, 5, 6],
                startTime: "08:00",
                endTime: "22:00",
                enabled: true
            }
        });
    } catch (error) {
        console.error("Erro ao buscar configurações:", error);
        res.status(500).json({ error: "Erro interno no servidor" });
    }
}

export async function updateSettings(req: Request, res: Response) {
    try {
        const userId = (req as AuthRequest).userId;
        if (!userId) {
            return res.status(401).json({ error: "Usuário não autenticado" });
        }

        // Pega do body os campos que o app enviar (todos são opcionais para o update)
        const { name, dailyGoal, quickAddAmount, theme, dailyReminder, vibration, notifications } = req.body;

        // Update user fields (without notificationSettings - handled separately)
        const updatedUser = await prisma.user.update({
            where: { id: userId },
            data: {
                name: name !== undefined ? String(name) : undefined,
                dailyGoal: dailyGoal !== undefined ? Number(dailyGoal) : undefined,
                quickAddAmount: quickAddAmount !== undefined ? Number(quickAddAmount) : undefined,
                theme: theme !== undefined ? String(theme) : undefined,
                dailyReminder: dailyReminder !== undefined ? Boolean(dailyReminder) : undefined,
                vibration: vibration !== undefined ? Boolean(vibration) : undefined,
            },
            select: {
                name: true,
                email: true,
                dailyGoal: true,
                quickAddAmount: true,
                theme: true,
                dailyReminder: true,
                vibration: true,
            }
        });

        // Handle notification settings separately with upsert
        let notificationSettings = null;
        if (notifications) {
            notificationSettings = await prisma.notificationSetting.upsert({
                where: { userId },
                create: {
                    userId,
                    type: notifications.type || "hourly",
                    intervalInMinutes: notifications.intervalInMinutes || 60,
                    daysOfWeek: notifications.daysOfWeek || [0, 1, 2, 3, 4, 5, 6],
                    startTime: notifications.startTime || "08:00",
                    endTime: notifications.endTime || "22:00",
                    enabled: notifications.enabled !== undefined ? notifications.enabled : true,
                },
                update: {
                    type: notifications.type,
                    intervalInMinutes: notifications.intervalInMinutes,
                    daysOfWeek: notifications.daysOfWeek,
                    startTime: notifications.startTime,
                    endTime: notifications.endTime,
                    enabled: notifications.enabled,
                },
            });
        } else {
            // Fetch existing notification settings
            notificationSettings = await prisma.notificationSetting.findUnique({
                where: { userId },
            });
        }

        res.json({ 
            message: "Configurações atualizadas!", 
            user: {
                ...updatedUser,
                notificationSettings: notificationSettings,
            } 
        });
    } catch (error) {
        console.error("Erro ao atualizar configurações:", error);
        res.status(500).json({ error: "Erro interno ao atualizar configurações" });
    }
}

export async function changePassword(req: Request, res: Response) {
    try {
        const userId = (req as AuthRequest).userId;
        if (!userId) {
            return res.status(401).json({ error: "Usuário não autenticado" });
        }

        const { currentPassword, newPassword } = req.body;

        // Garantir que recebemos strings e remover espaços extras acidentais
        const curPass = currentPassword ? String(currentPassword).trim() : "";
        const newPass = newPassword ? String(newPassword).trim() : "";

        if (!curPass || !newPass) {
            return res.status(400).json({ error: "Senha atual e nova senha são obrigatórias" });
        }

        if (newPass.length < 6) {
            return res.status(400).json({ error: "A nova senha deve ter pelo menos 6 caracteres" });
        }

        const user = await prisma.user.findUnique({ where: { id: userId } });
        if (!user) {
            return res.status(404).json({ error: "Usuário não encontrado" });
        }

        // Comparação com bcrypt
        const valid = await bcrypt.compare(curPass, user.password);
        if (!valid) {
            return res.status(400).json({ error: "Senha atual incorreta" });
        }

        // Gerar novo hash e salvar
        const hash = await bcrypt.hash(newPass, 10);
        await prisma.user.update({
            where: { id: userId },
            data: { password: hash },
        });

        res.json({ message: "Senha alterada com sucesso" });
    } catch (error) {
        console.error("Erro ao alterar senha:", error);
        res.status(500).json({ error: "Erro interno ao alterar senha" });
    }
}
