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
    const { period, date } = req.query;
    let startDate = new Date();
    let endDate = new Date();
    if (date) {
        startDate = new Date(date);
        startDate.setHours(0, 0, 0, 0);
        endDate = new Date(date);
        endDate.setHours(23, 59, 59, 999);
    }
    else {
        const days = period === '30d' ? 30 : 7;
        startDate.setDate(startDate.getDate() - days);
        startDate.setHours(0, 0, 0, 0);
    }
    const logs = await prisma_1.prisma.waterLog.findMany({
        where: {
            userId: userId,
            date: {
                gte: startDate,
                lte: endDate
            }
        },
        orderBy: { date: 'desc' }
    });
    const user = await prisma_1.prisma.user.findUnique({
        where: { id: userId },
        select: { dailyGoal: true }
    });
    if (!user) {
        return res.status(404).json({ error: "Usuário não encontrado" });
    }
    const dailyGoal = user.dailyGoal;
    // Cálculo de estatísticas
    const logsByDay = {};
    logs.forEach(log => {
        const day = log.date.toISOString().split('T')[0];
        logsByDay[day] = (logsByDay[day] || 0) + log.amount;
    });
    const daysCount = Object.keys(logsByDay).length || 1;
    const totalIntake = logs.reduce((acc, log) => acc + log.amount, 0);
    const average = Math.round(totalIntake / (period === '30d' ? 30 : 7));
    const goalsMet = Object.values(logsByDay).filter(amount => amount >= dailyGoal).length;
    res.json({
        logs,
        dailyGoal,
        stats: {
            average,
            goalsMet,
            totalDays: period === '30d' ? 30 : 7
        }
    });
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
        select: { dailyGoal: true, name: true }
    });
    if (!user) {
        return res.status(404).json({ error: "Usuário não encontrado" });
    }
    const dailyGoal = user.dailyGoal;
    const remaining = Math.max(0, dailyGoal - total);
    res.json({
        total,
        dailyGoal,
        name: user.name,
        remaining,
        percent: total / dailyGoal,
        logs
    });
}
