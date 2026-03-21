import { prisma } from "./prisma"

import { Response } from "express"
import { AuthRequest } from "./types"

export async function addWater(req: AuthRequest, res: Response) {
    const { amount } = req.body
    const userId = req.userId

    if (typeof amount !== 'number' || amount <= 0) {
        return res.status(400).json({ error: "Quantidade inválida" })
    }

    try {
        await prisma.waterLog.create({
            data: {
                amount,
                date: new Date(),
                userId: userId!
            }
        })

        res.json({ success: true })
    } catch (error) {
        res.status(500).json({ error: "Erro ao salvar registro de água" })
    }
}

export async function history(req: AuthRequest, res: Response) {
    const userId = req.userId
    const { period, date } = req.query

    let startDate = new Date()
    let endDate = new Date()

    if (date) {
        startDate = new Date(date as string)
        startDate.setHours(0, 0, 0, 0)
        endDate = new Date(date as string)
        endDate.setHours(23, 59, 59, 999)
    } else {
        const days = period === '30d' ? 30 : 7
        startDate.setDate(startDate.getDate() - days)
        startDate.setHours(0, 0, 0, 0)
    }

    const logs = await prisma.waterLog.findMany({
        where: {
            userId: userId!,
            date: {
                gte: startDate,
                lte: endDate
            }
        },
        orderBy: { date: 'desc' }
    })

    const user = await prisma.user.findUnique({
        where: { id: userId! },
        select: { dailyGoal: true }
    })

    if (!user) {
        return res.status(404).json({ error: "Usuário não encontrado" })
    }

    const dailyGoal = user.dailyGoal

    // Cálculo de estatísticas
    const logsByDay: { [key: string]: number } = {}
    logs.forEach(log => {
        const day = log.date.toISOString().split('T')[0]
        logsByDay[day] = (logsByDay[day] || 0) + log.amount
    })

    const daysCount = Object.keys(logsByDay).length || 1
    const totalIntake = logs.reduce((acc, log) => acc + log.amount, 0)
    const average = Math.round(totalIntake / (period === '30d' ? 30 : 7))
    const goalsMet = Object.values(logsByDay).filter(amount => amount >= dailyGoal).length

    res.json({
        logs,
        dailyGoal,
        stats: {
            average,
            goalsMet,
            totalDays: period === '30d' ? 30 : 7
        }
    })
}

export async function today(req: AuthRequest, res: Response) {
    const userId = req.userId

    const startOfDay = new Date()
    startOfDay.setHours(0, 0, 0, 0)

    const logs = await prisma.waterLog.findMany({
        where: {
            userId: userId!,
            date: { gte: startOfDay }
        }
    })

    const total = logs.reduce((acc, log) => acc + log.amount, 0)

    // Buscamos o usuário para saber a meta diária dele
    const user = await prisma.user.findUnique({
        where: { id: userId! },
        select: { dailyGoal: true, name: true }
    })

    if (!user) {
        return res.status(404).json({ error: "Usuário não encontrado" })
    }

    const dailyGoal = user.dailyGoal
    const remaining = Math.max(0, dailyGoal - total)

    res.json({
        total,
        dailyGoal,
        name: user.name,
        remaining,
        percent: total / dailyGoal,
        logs
    })
}