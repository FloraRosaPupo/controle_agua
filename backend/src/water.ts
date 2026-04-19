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

    const offsetMinutes = getUserTimezoneOffsetMinutes(req)

    if (date) {
        // Date is like '2026-03-27'
        const [year, month, day] = (date as string).split('-').map(Number)
        
        const localStart = new Date(Date.UTC(year, month - 1, day, 0, 0, 0, 0))
        startDate = new Date(localStart.getTime() - offsetMinutes * 60 * 1000)
        
        endDate = new Date(startDate.getTime() + 24 * 60 * 60 * 1000 - 1)
    } else if (period && typeof period === 'string' && period.endsWith('d')) {
        const days = parseInt(period.replace('d', ''))
        const userLocalNow = new Date(Date.now() + offsetMinutes * 60 * 1000)
        
        const localEnd = new Date(userLocalNow.getTime())
        localEnd.setUTCHours(23, 59, 59, 999)
        endDate = new Date(localEnd.getTime() - offsetMinutes * 60 * 1000)

        const localStart = new Date(localEnd.getTime())
        localStart.setUTCDate(localStart.getUTCDate() - (days - 1))
        localStart.setUTCHours(0, 0, 0, 0)
        startDate = new Date(localStart.getTime() - offsetMinutes * 60 * 1000)
    } else {
        // Default to last 30 days instead of just current week
        // This ensures the list has enough data even if period is not sent
        const days = 30;
        const userLocalNow = new Date(Date.now() + offsetMinutes * 60 * 1000)
        
        const localEnd = new Date(userLocalNow.getTime())
        localEnd.setUTCHours(23, 59, 59, 999)
        endDate = new Date(localEnd.getTime() - offsetMinutes * 60 * 1000)

        const localStart = new Date(localEnd.getTime())
        localStart.setUTCDate(localStart.getUTCDate() - (days - 1))
        localStart.setUTCHours(0, 0, 0, 0)
        startDate = new Date(localStart.getTime() - offsetMinutes * 60 * 1000)
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

    // Calculation adjusted for timezone
    const logsByDay: { [key: string]: number } = {}
    logs.forEach(log => {
        const localDate = new Date(log.date.getTime() + offsetMinutes * 60 * 1000)
        const day = localDate.toISOString().split('T')[0]
        logsByDay[day] = (logsByDay[day] || 0) + log.amount
    })

    const totalIntake = logs.reduce((acc, log) => acc + log.amount, 0)
    
    // Average by days elapsed this week to be more accurate, or by 7 if the week is done
    let daysElapsed = 7
    if (!date) {
        const userLocalNow = new Date(Date.now() + offsetMinutes * 60 * 1000)
        daysElapsed = userLocalNow.getUTCDay() + 1
    } else {
        daysElapsed = 1
    }
    const average = daysElapsed > 0 ? Math.round(totalIntake / daysElapsed) : 0

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

