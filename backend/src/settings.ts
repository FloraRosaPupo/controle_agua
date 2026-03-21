import { Request, Response } from "express";
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
        const { name, dailyGoal, theme, dailyReminder, vibration, notifications } = req.body;

        const updatedUser = await prisma.user.update({
            where: { id: userId },
            data: {
                name: name !== undefined ? String(name) : undefined,
                dailyGoal: dailyGoal !== undefined ? Number(dailyGoal) : undefined,
                theme: theme !== undefined ? String(theme) : undefined,
                dailyReminder: dailyReminder !== undefined ? Boolean(dailyReminder) : undefined,
                vibration: vibration !== undefined ? Boolean(vibration) : undefined,
                notificationSettings: notifications ? {
                    upsert: {
                        create: {
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
                        }
                    }
                } : undefined
            },
            select: {
                name: true,
                email: true,
                dailyGoal: true,
                theme: true,
                dailyReminder: true,
                vibration: true,
                notificationSettings: true,
            }
        });

        res.json({ 
            message: "Configurações atualizadas!", 
            user: {
                ...updatedUser,
                notificationSettings: updatedUser.notificationSettings
            } 
        });
    } catch (error) {
        console.error("Erro ao atualizar configurações:", error);
        res.status(500).json({ error: "Erro interno ao atualizar configurações" });
    }
}
