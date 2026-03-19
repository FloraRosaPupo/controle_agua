import { prisma } from "./prisma"
import bcrypt from "bcrypt"
import jwt from "jsonwebtoken"
import { Request, Response } from "express"

export async function register(req: Request, res: Response) {
    const { name, email, password, dailyGoal } = req.body

    if (!name || !email || !password) {
        return res.status(400).json({ error: "Nome, e-mail e senha são obrigatórios" })
    }

    const hash = await bcrypt.hash(password, 10)

    try {
        const user = await prisma.user.create({
            data: {
                name,
                email,
                password: hash,
                dailyGoal: dailyGoal && dailyGoal > 0 ? dailyGoal : 2000
            }
        })
        res.json(user)
    } catch (error) {
        console.error("Erro no cadastro:", error)
        res.status(400).json({ error: "Erro ao criar usuário.", details: error instanceof Error ? error.message : "Erro desconhecido" })
    }
}

export async function login(req: Request, res: Response) {
    const { email, password } = req.body

    if (!email || !password) {
        return res.status(400).json({ error: "E-mail e senha são obrigatórios" })
    }

    const user = await prisma.user.findUnique({ where: { email } })

    if (!user) return res.status(400).json({ error: "Usuário não encontrado" })

    const valid = await bcrypt.compare(password, user.password)

    if (!valid) return res.status(400).json({ error: "Senha inválida" })

    const token = jwt.sign(
        { userId: user.id },
        process.env.JWT_SECRET!,
        { expiresIn: "7d" }
    )

    res.json({ token, user: { id: user.id, name: user.name, email: user.email } })
}