"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.register = register;
exports.login = login;
const prisma_1 = require("./prisma");
const bcrypt_1 = __importDefault(require("bcrypt"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
async function register(req, res) {
    const { name, email, password, dailyGoal } = req.body;
    if (!name || !email || !password) {
        return res.status(400).json({ error: "Nome, e-mail e senha são obrigatórios" });
    }
    const hash = await bcrypt_1.default.hash(password, 10);
    try {
        const user = await prisma_1.prisma.user.create({
            data: {
                name,
                email,
                password: hash,
                dailyGoal: dailyGoal && dailyGoal > 0 ? dailyGoal : 2000
            }
        });
        res.json(user);
    }
    catch (error) {
        console.error("Erro no cadastro:", error);
        res.status(400).json({ error: "Erro ao criar usuário.", details: error instanceof Error ? error.message : "Erro desconhecido" });
    }
}
async function login(req, res) {
    const { email, password } = req.body;
    if (!email || !password) {
        return res.status(400).json({ error: "E-mail e senha são obrigatórios" });
    }
    const user = await prisma_1.prisma.user.findUnique({ where: { email } });
    if (!user)
        return res.status(400).json({ error: "Usuário não encontrado" });
    const valid = await bcrypt_1.default.compare(password, user.password);
    if (!valid)
        return res.status(400).json({ error: "Senha inválida" });
    const token = jsonwebtoken_1.default.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: "7d" });
    res.json({ token, user: { id: user.id, name: user.name, email: user.email } });
}
