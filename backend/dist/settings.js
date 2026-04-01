"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSettings = getSettings;
exports.updateSettings = updateSettings;
exports.changePassword = changePassword;
const bcrypt_1 = __importDefault(require("bcrypt"));
const prisma_1 = require("./prisma");
async function getSettings(req, res) {
    try {
        const userId = req.userId;
        if (!userId) {
            return res.status(401).json({ error: "Usuário não autenticado" });
        }
        const user = await prisma_1.prisma.user.findUnique({
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
    }
    catch (error) {
        console.error("Erro ao buscar configurações:", error);
        res.status(500).json({ error: "Erro interno no servidor" });
    }
}
async function updateSettings(req, res) {
    try {
        const userId = req.userId;
        if (!userId) {
            return res.status(401).json({ error: "Usuário não autenticado" });
        }
        // Pega do body os campos que o app enviar (todos são opcionais para o update)
        const { name, dailyGoal, quickAddAmount, theme, dailyReminder, vibration, notificationSettings: reqNotifications } = req.body;
        // Suporta tanto a chave antiga "notifications" quanto a nova "notificationSettings" do app
        const appNotificationsPayload = reqNotifications || req.body.notifications;
        // Update user fields (without notificationSettings - handled separately)
        const updatedUser = await prisma_1.prisma.user.update({
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
        let dbNotificationSettings = null;
        if (appNotificationsPayload) {
            dbNotificationSettings = await prisma_1.prisma.notificationSetting.upsert({
                where: { userId },
                create: {
                    userId,
                    type: appNotificationsPayload.type || "hourly",
                    intervalInMinutes: appNotificationsPayload.intervalInMinutes || 60,
                    daysOfWeek: appNotificationsPayload.daysOfWeek || [0, 1, 2, 3, 4, 5, 6],
                    startTime: appNotificationsPayload.startTime || "08:00",
                    endTime: appNotificationsPayload.endTime || "22:00",
                    enabled: appNotificationsPayload.enabled !== undefined ? appNotificationsPayload.enabled : true,
                },
                update: {
                    type: appNotificationsPayload.type,
                    intervalInMinutes: appNotificationsPayload.intervalInMinutes,
                    daysOfWeek: appNotificationsPayload.daysOfWeek,
                    startTime: appNotificationsPayload.startTime,
                    endTime: appNotificationsPayload.endTime,
                    enabled: appNotificationsPayload.enabled,
                },
            });
        }
        else {
            // Fetch existing notification settings
            dbNotificationSettings = await prisma_1.prisma.notificationSetting.findUnique({
                where: { userId },
            });
        }
        res.json({
            message: "Configurações atualizadas!",
            user: {
                ...updatedUser,
                notificationSettings: dbNotificationSettings,
            }
        });
    }
    catch (error) {
        console.error("Erro ao atualizar configurações:", error);
        res.status(500).json({ error: "Erro interno ao atualizar configurações" });
    }
}
async function changePassword(req, res) {
    try {
        const userId = req.userId;
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
        const user = await prisma_1.prisma.user.findUnique({ where: { id: userId } });
        if (!user) {
            return res.status(404).json({ error: "Usuário não encontrado" });
        }
        // Comparação com bcrypt
        const valid = await bcrypt_1.default.compare(curPass, user.password);
        if (!valid) {
            return res.status(400).json({ error: "Senha atual incorreta" });
        }
        // Gerar novo hash e salvar
        const hash = await bcrypt_1.default.hash(newPass, 10);
        await prisma_1.prisma.user.update({
            where: { id: userId },
            data: { password: hash },
        });
        res.json({ message: "Senha alterada com sucesso" });
    }
    catch (error) {
        console.error("Erro ao alterar senha:", error);
        res.status(500).json({ error: "Erro interno ao alterar senha" });
    }
}
