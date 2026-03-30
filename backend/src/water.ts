import { prisma } from "./prisma"
import { Response } from "express"
import { AuthRequest } from "./types"

function getUserTimezoneOffsetMinutes(req: AuthRequest): number {
    const offsetHeader = req.header('x-timezone-offset')
    return offsetHeader ? parseInt(offsetHeader) : 0
}

function getStartOfUserDayInUTC(req: AuthRequest): Date {
    // x-timezone-offset vem do app como local - UTC (ex.: Brasil = -180)
    const offsetMinutes = getUserTimezoneOffsetMinutes(req)

    const now = new Date()
    // Converte para "relógio local do usuário" em um objeto Date UTC
    const userLocalNow = new Date(now.getTime() + (offsetMinutes * 60 * 1000))

    // Define meia-noite local do usuário
    userLocalNow.setUTCHours(0, 0, 0, 0)

    // Converte de volta para UTC real para filtrar no banco
    return new Date(userLocalNow.getTime() - (offsetMinutes * 60 * 1000))
}

function getEndOfUserDayInUTC(req: AuthRequest): Date {
    const startOfDay = getStartOfUserDayInUTC(req)
    return new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000 - 1)
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
    const endOfDay = getEndOfUserDayInUTC(req)

    const logs = await prisma.waterLog.findMany({
        where: {
            userId: userId!,
            date: {
                gte: startOfDay,
                lte: endOfDay
            }
        },
        orderBy: { date: 'desc' }
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

