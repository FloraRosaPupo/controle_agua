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

    const sevenDaysAgo = new Date()
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)

    const logs = await prisma.waterLog.findMany({
        where: {
            userId: userId!,
            date: { gte: sevenDaysAgo }
        }
    })

    res.json(logs)
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

    res.json({ total, logs })
}