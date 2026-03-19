"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.addWater = addWater;
exports.history = history;
exports.today = today;
const prisma_1 = require("./prisma");
async function addWater(req, res) {
    const { amount } = req.body;
    const userId = req.userId;
    if (typeof amount !== 'number' || amount <= 0) {
        return res.status(400).json({ error: "Quantidade inválida" });
    }
    try {
        await prisma_1.prisma.waterLog.create({
            data: {
                amount,
                date: new Date(),
                userId: userId
            }
        });
        res.json({ success: true });
    }
    catch (error) {
        res.status(500).json({ error: "Erro ao salvar registro de água" });
    }
}
async function history(req, res) {
    const userId = req.userId;
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const logs = await prisma_1.prisma.waterLog.findMany({
        where: {
            userId: userId,
            date: { gte: sevenDaysAgo }
        }
    });
    res.json(logs);
}
async function today(req, res) {
    const userId = req.userId;
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    const logs = await prisma_1.prisma.waterLog.findMany({
        where: {
            userId: userId,
            date: { gte: startOfDay }
        }
    });
    const total = logs.reduce((acc, log) => acc + log.amount, 0);
    // Buscamos o usuário para saber a meta diária dele
    const user = await prisma_1.prisma.user.findUnique({
        where: { id: userId },
        select: { dailyGoal: true }
    });
    const dailyGoal = user?.dailyGoal || 2000;
    const remaining = Math.max(0, dailyGoal - total);
    res.json({
        total,
        dailyGoal,
        remaining,
        percent: total / dailyGoal,
        logs
    });
}
