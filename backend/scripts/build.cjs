"use strict";

const { spawnSync } = require("child_process");
const path = require("path");

const root = path.join(__dirname, "..");

if (!process.env.DATABASE_URL) {
  process.env.DATABASE_URL =
    "postgresql://127.0.0.1:5432/prisma_build?schema=public";
}

function runNode(scriptPath, args) {
  const r = spawnSync(process.execPath, [scriptPath, ...args], {
    stdio: "inherit",
    cwd: root,
    env: process.env,
  });
  if (r.status !== 0) process.exit(r.status ?? 1);
}

const prismaCli = path.join(root, "node_modules", "prisma", "build", "index.js");
const tscCli = path.join(root, "node_modules", "typescript", "bin", "tsc");

runNode(prismaCli, ["generate"]);
runNode(tscCli, []);
