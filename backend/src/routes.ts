import jwt from "jsonwebtoken"
import { register, login } from "./auth"
import { addWater, history, today } from "./water"
import { Router, Request, Response, NextFunction } from "express"

import { AuthRequest } from "./types"

const router = Router()

function authMiddleware(req: Request, res: Response, next: NextFunction) {
    const auth = req.headers.authorization
    if (!auth) return res.status(401).json({ error: "Token inválido" })

    const token = auth.split(" ")[1]

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET!) as { userId: string }
        (req as AuthRequest).userId = decoded.userId
        next()
    } catch {
        return res.status(401).json({ error: "Token inválido" })
    }
}

router.post("/register", register)
router.post("/login", login)

router.post("/water", authMiddleware, addWater)
router.get("/water/history", authMiddleware, history)
router.get("/water/today", authMiddleware, today)

export default router