import { prisma } from "./prisma"
import { Response } from "express"
import { AuthRequest } from "./types"

function getStartOfUserDayInUTC(req: AuthRequest): Date {
    const offsetHeader = req.header('x-timezone-offset')
    // Se o header for -180 (Brasil), offsetMinutes será -180
    const offsetMinutes = offsetHeader ? parseInt(offsetHeader) : 0

    const now = new Date()
    // Convert to user's local time numbers but still as a UTC Date object
    // Ex: UTC 22:00 + (-180 min) = 19:00 UTC
    const userLocalNow = new Date(now.getTime() + (offsetMinutes * 60 * 1000))

    // Zera para meia-noite nesse "relógio local"
    userLocalNow.setUTCHours(0, 0, 0, 0)

    return userLocalNow
}

export async function addWater(req: AuthRequest, res: Response) {
    const { amount } = req.body
    const userId = req.userId

    if (typeof amount !== 'number' || amount <= 0) {
        return res.status(400).json({ error: "Quantidade deve ser maior que zero" })
    }

    try {
        await prisma.waterLog.create({
            data: {
                amount,
                date: new Date(),  // Sempre salva em UTC puro
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
    let startDate: Date
    let endDate: Date
    const { period, date } = req.query

    if (date) {
        // Date is like '2026-03-27'
        startDate = new Date(date as string)
        startDate.setUTCHours(0, 0, 0, 0)

        endDate = new Date(startDate.getTime() + 24 * 60 * 60 * 1000 - 1)
    } else {
        const days = 7
        startDate = getStartOfUserDayInUTC(req)
        startDate.setDate(startDate.getDate() - days)
        endDate = new Date()
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

    // Cálculo de estatísticas (ajustado para timezone)
    // Se já ajustamos na inserção, os logs estão em "hora local".
    // Mas startDate/endDate podem estar desalinhados se não tomarmos cuidado.

    const logsByDay: { [key: string]: number } = {}
    logs.forEach(log => {
        // Se a data já foi salva com o offset (no addWater), não precisamos adicionar de novo.
        // O log.date já representa a hora local do usuário.
        const day = log.date.toISOString().split('T')[0]
        logsByDay[day] = (logsByDay[day] || 0) + log.amount
    })

    const daysCount = Object.keys(logsByDay).length || 1
    const totalIntake = logs.reduce((acc, log) => acc + log.amount, 0)
    const average = Math.round(totalIntake / 7)
    const goalsMet = Object.values(logsByDay).filter(amount => amount >= dailyGoal).length

    res.json({
        logs,
        dailyGoal,
        stats: {
            average,
            goalsMet,
            totalDays: 7
        }
    })
}

export async function today(req: AuthRequest, res: Response) {
    const userId = req.userId

    const startOfDay = getStartOfUserDayInUTC(req)

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

export async function deleteWater(req: AuthRequest, res: Response) {
    const id = req.params.id as string
    const userId = req.userId

    try {
        const log = await prisma.waterLog.findUnique({
            where: { id: id }
        })

        if (!log) {
            return res.status(404).json({ error: "Registro não encontrado" })
        }

        if (log.userId !== userId) {
            return res.status(403).json({ error: "Não autorizado" })
        }

        await prisma.waterLog.delete({
            where: { id: id }
        })

        res.json({ success: true })
    } catch (error) {
        res.status(500).json({ error: "Erro ao excluir registro" })
    }
}
