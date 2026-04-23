import { prisma } from "./prisma"
import { Response } from "express"
import { AuthRequest } from "./types"

function getUserTimezoneOffsetMinutes(req: AuthRequest): number {
    const offsetHeader = req.header('x-timezone-offset')
    return offsetHeader ? parseInt(offsetHeader) : 0
}

function getStartOfUserDayInUTC(req: AuthRequest): Date {
    const offsetMinutes = getUserTimezoneOffsetMinutes(req)
    const now = new Date()
    const userLocalNow = new Date(now.getTime() + (offsetMinutes * 60 * 1000))
    userLocalNow.setUTCHours(0, 0, 0, 0)
    return new Date(userLocalNow.getTime() - (offsetMinutes * 60 * 1000))
}

function getEndOfUserDayInUTC(req: AuthRequest): Date {
    const startOfDay = getStartOfUserDayInUTC(req)
    return new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000 - 1)
}

export async function addWater(req: AuthRequest, res: Response) {
    const { amount, date } = req.body
    const userId = req.userId

    if (typeof amount !== 'number' || amount <= 0) {
        return res.status(400).json({ error: "Quantidade deve ser maior que zero" })
    }

    const offsetMinutes = getUserTimezoneOffsetMinutes(req)

    try {
        await prisma.waterLog.create({
            data: {
                amount,
                date: date
                    ? new Date(date as string)
                    : new Date(),
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
    const offsetMinutes = getUserTimezoneOffsetMinutes(req)

    const now = new Date()
    let statsDays = 15
    let startDate: Date
    let endDate: Date = new Date(now.getTime() + 24 * 60 * 60 * 1000)

    if (date) {
        const [year, month, day] = (date as string).split('-').map(Number)
        const localStart = new Date(Date.UTC(year, month - 1, day, 0, 0, 0, 0))
        startDate = new Date(localStart.getTime() - offsetMinutes * 60 * 1000)
        endDate = new Date(startDate.getTime() + 24 * 60 * 60 * 1000 - 1)
        statsDays = 1
    } else {
        if (period && typeof period === 'string' && period.endsWith('d')) {
            statsDays = parseInt(period.replace('d', ''))
        }
        const startOfToday = getStartOfUserDayInUTC(req)
        startDate = new Date(startOfToday.getTime() - (statsDays - 1) * 24 * 60 * 60 * 1000)
    }

    const logs = await prisma.waterLog.findMany({
        where: {
            userId: userId!,
            date: { gte: startDate, lte: endDate }
        },
        orderBy: { date: 'desc' }
    })
    const statsLogs = logs; // They are the same now since they use the same range


    // logs is already ordered desc from Prisma


    const user = await prisma.user.findUnique({
        where: { id: userId! },
        select: { dailyGoal: true }
    })
    const dailyGoal = user?.dailyGoal || 2000

    const logsByDay: { [key: string]: number } = {}
    statsLogs.forEach(log => {
        const localDate = new Date(log.date.getTime() + offsetMinutes * 60 * 1000)
        const day = localDate.toISOString().split('T')[0]
        logsByDay[day] = (logsByDay[day] || 0) + log.amount
    })

    const totalIntake = statsLogs.reduce((acc, log) => acc + log.amount, 0)
    const daysWithLogs = Object.keys(logsByDay).length
    const average = daysWithLogs > 0 ? Math.round(totalIntake / daysWithLogs) : 0
    const goalsMet = Object.values(logsByDay).filter(amount => amount >= dailyGoal).length

    res.json({
        logs,
        dailyGoal,
        stats: {
            average,
            goalsMet,
            totalDays: statsDays
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