"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const auth_1 = require("./auth");
const water_1 = require("./water");
const settings_1 = require("./settings");
const express_1 = require("express");
const router = (0, express_1.Router)();
function authMiddleware(req, res, next) {
    const auth = req.headers.authorization;
    if (!auth)
        return res.status(401).json({ error: "Token inválido" });
    const token = auth.split(" ")[1];
    try {
        const decoded = jsonwebtoken_1.default.verify(token, process.env.JWT_SECRET);
        req.userId = decoded.userId;
        next();
    }
    catch {
        return res.status(401).json({ error: "Token inválido" });
    }
}
router.post("/register", auth_1.register);
router.post("/login", auth_1.login);
router.post("/water", authMiddleware, water_1.addWater);
router.get("/water/history", authMiddleware, water_1.history);
router.get("/water/today", authMiddleware, water_1.today);
router.get("/settings", authMiddleware, settings_1.getSettings);
router.put("/settings", authMiddleware, settings_1.updateSettings);
exports.default = router;
