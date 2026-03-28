import { prisma } from "./prisma"
import { Response } from "express"
import { AuthRequest } from "./types"

function getStartOfUserDayInUTC(req: AuthRequest): Date {
    const offsetHeader = req.header('x-timezone-offset')
    // offset in minutes from client, e.g. -180 for Brazil
    const offsetMinutes = offsetHeader ? parseInt(offsetHeader) : 0

    const now = new Date()
    // adjust now to user's local "day" (User clock = UTC + offset)
    const userLocalNow = new Date(now.getTime() + (offsetMinutes * 60 * 1000))

    // reset to midnight in that offset's "world"
    userLocalNow.setUTCHours(0, 0, 0, 0)

    // convert back to UTC for DB query
    return new Date(userLocalNow.getTime() - (offsetMinutes * 60 * 1000))
}

export async function addWater(req: AuthRequest, res: Response) {
    const { amount } = req.body
    const userId = req.userId

    if (typeof amount !== 'number' || amount === 0) {
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
    let startDate: Date
    let endDate: Date
    const { period, date } = req.query

    if (date) {
        startDate = new Date(date as string)
        startDate.setUTCHours(0, 0, 0, 0)
        // If the date is passed, we should ideally still apply the offset, but since it's a fixed date string (e.g. 2026-03-27),
        // we'll treat it as midnight UTC + offset.
        const offsetHeader = req.header('x-timezone-offset')
        const offsetMinutes = offsetHeader ? parseInt(offsetHeader) : 0
        startDate = new Date(startDate.getTime() - (offsetMinutes * 60 * 1000))

        endDate = new Date(startDate.getTime() + 24 * 60 * 60 * 1000 - 1)
    } else {
        const days = period === '30d' ? 30 : 7
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
    const offsetHeader = req.header('x-timezone-offset')
    const offsetMinutes = offsetHeader ? parseInt(offsetHeader) : 0

    const logsByDay: { [key: string]: number } = {}
    logs.forEach(log => {
        const localDate = new Date(log.date.getTime() + (offsetMinutes * 60 * 1000))
        const day = localDate.toISOString().split('T')[0]
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
